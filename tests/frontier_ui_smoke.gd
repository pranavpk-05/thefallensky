extends SceneTree

var _failures := 0
var _started := false
var _deduced := PackedStringArray()
var _saved := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui = load("res://frontier_ui.gd").new()
	var audio = load("res://frontier_audio.gd").new()
	root.add_child(audio)
	audio.start()
	root.add_child(ui)
	ui.new_game_requested.connect(func() -> void: _started = true)
	ui.deduction_submitted.connect(func(ids: PackedStringArray) -> void: _deduced = ids)
	ui.save_requested.connect(func() -> void: _saved = true)
	ui.cue_requested.connect(audio.play_cue)
	ui.configure(true, false)
	await process_frame
	await process_frame
	_check(paused, "title pauses gameplay")
	_check(_button(ui, "Continue").disabled, "Continue unavailable with no save")
	_check(root.gui_get_focus_owner() == _button(ui, "New Game"), "New Game receives keyboard focus")
	_check_visible(ui)
	_button(ui, "Settings").pressed.emit()
	await process_frame
	await process_frame
	_check_visible(ui)
	_button(ui, "Back").pressed.emit()
	_button(ui, "New Game").pressed.emit()
	_check(_started and not paused, "New Game starts the expedition")

	var clues: Array[Dictionary] = [
		{"id": "log", "title": "Expedition Log", "text": "A second crew traveled down the valley."},
		{"id": "wire", "title": "Radio Coil", "text": "The coil bears a Commission repair stamp."},
		{"id": "note", "title": "Maintenance Note", "text": "Telemetry was deliberately severed."}
	]
	ui.set_journal("The Last Transmission", "What happened to the missing crew?", clues,
		PackedStringArray(["Gloam Camp", "Sunken Spire"]), "Test a link between three clues.", true)
	var journal := InputEventKey.new()
	journal.physical_keycode = KEY_J
	journal.pressed = true
	ui._input(journal)
	await process_frame
	await process_frame
	_check(paused, "J opens journal")
	for i in clues.size():
		ui._evidence_list.item_selected.emit(i)
		ui._link_check.button_pressed = true
	_button(ui, "Test deduction   3 / 3").pressed.emit()
	_check(_deduced == PackedStringArray(["log", "wire", "note"]), "journal submits selected clue IDs")
	_check_visible(ui)
	_button(ui, "Close Journal").pressed.emit()
	_check(not paused, "closing journal resumes gameplay")
	ui.set_flight(true, 25.0, 46.0, 0.4, true, false)
	await process_frame
	await process_frame
	_check_visible(ui)
	_check(root.get_visible_rect().grow(0.5).encloses(ui._flight_hud.get_global_rect()), "flight panel on screen")
	_check(ui._flight_data.text.contains("090 km/h"), "flight HUD displays converted airspeed")
	_check(AudioServer.get_bus_index(&"Ambience") > 0, "ambience bus created")
	_check(audio._ambience.playing, "ambient bed playing")
	_check(AudioServer.get_bus_index(&"Music") > 0 and audio._score.playing, "adaptive score playing")
	audio.play_cue(&"evidence")
	_check(audio._tones.any(func(player: AudioStreamPlayer) -> bool: return player.playing),
		"evidence sound triggers through a player")
	ui.show_ending("The Spire Awakes", "Mara brought a copy of the evidence to the valley.")
	_check(paused, "revelation pauses gameplay for reading")
	_button(ui, "Return to the Valley").pressed.emit()
	_check(not paused, "revelation returns to the same expedition")
	var pause_event := InputEventAction.new()
	pause_event.action = &"ui_cancel"
	pause_event.pressed = true
	ui._input(pause_event)
	_button(ui, "Save and Return to Title").pressed.emit()
	_check(_saved and paused, "save-and-title menu emits save and shows title")
	ui.set_continue_available(true)
	_check(not _button(ui, "Continue").disabled, "Continue enabled when save becomes available")
	print("Frontier UI checks: %d failures" % _failures)
	audio.stop_all()
	await create_timer(0.2).timeout
	quit(_failures)


func _button(ui: Node, words: String) -> Button:
	for button: Button in ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text == words:
			return button
	push_error("Button unavailable: " + words)
	quit(1)
	return null


func _check_visible(ui: Node) -> void:
	var screen := root.get_visible_rect().grow(0.5)
	for button: Button in ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			_check(screen.encloses(button.get_global_rect()), "button on screen " + button.text)


func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	_failures += int(not ok)
