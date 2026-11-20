extends SceneTree

const Case = preload("res://frontier_disappearance.gd")
var game
var campaign
var windgate: Case
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	campaign = game.campaign
	windgate = campaign.windgate
	campaign.save_path = "user://windgate-qa-%s.cfg" % OS.get_process_id()
	game.valley.set_process(false)
	campaign.start_new_game(false)
	for id in ["journal", "radio", "tracks"]:
		campaign._collect(id)
	_check(windgate.actors.size() == 8 and windgate.actors["lysa"].visible, "Eight residents and the pre-disappearance victim")
	await _visit("lysa")
	_check(int(windgate.met.get("lysa", 0)) == 1 and campaign.ui._toast.text.contains("two copies"), "Pre-event testimony and interaction memory")
	var moved_from := windgate.point("ada")
	windgate.advance(56.0, 0.0, windgate.point("ada"), campaign.case_file)
	_check(windgate.point("ada").distance_to(moved_from) > 0.5, "Ada travels on her schedule")
	windgate.advance(18.0, 0.88, game.opening_spawn(), campaign.case_file)
	_check(windgate.vanished_at >= 0.0 and not windgate.actors["lysa"].visible, "Heavy weather triggers the disappearance offscreen")
	_check(not windgate.can_use(Case.RESCUE, campaign.case_file), "The rescue is locked until the case is proven")
	campaign.persistence_enabled = true
	campaign.save_progress()
	var first_event := windgate.vanished_at
	campaign.start_new_game(false)
	_check(campaign.load_progress() and windgate.vanished_at == first_event and int(windgate.met.get("lysa", 0)) == 1,
		"Continue restores the event timeline and personal memory")
	windgate.advance(120.0, 0.91, game.opening_spawn(), campaign.case_file)
	_check(windgate.vanished_at == first_event, "Late arrival cannot repeat the disappearance")
	await _visit(Case.LEDGER)
	await _visit(Case.RADIO)
	await _visit("noah")
	_check(windgate.ready_to_reconstruct(campaign.case_file) and not campaign.case_file.collected.has(Case.SEAL),
		"Late players can use Noah's evidence instead of the satchel")
	await _visit(Case.BOARD)
	_check(campaign.ui._modal == "windgate", "The board opens the reconstruction decision")
	campaign.ui._select_windgate("alarm_first")
	_check(not windgate.reconstructed, "An inconsistent chronology cannot advance")
	await _visit(Case.BOARD)
	campaign.ui._select_windgate("key_first")
	_check(windgate.reconstructed, "The correct chronology unlocks the accusation")
	await _visit(Case.BOARD)
	campaign.ui._select_windgate("vale")
	_check(windgate.wrong == 1 and int(windgate.trust["vale"]) == -2 and not windgate.exposed,
		"A wrong accusation costs trust and leaves the case open")
	await _visit(Case.BOARD)
	campaign.ui._select_windgate("orrin")
	_check(windgate.exposed and not windgate.actors["orrin"].visible, "The correct accusation makes Pike flee")
	await _visit(Case.RESCUE)
	_check(windgate.rescued and campaign.case_file.collected.has("windgate_end") and campaign.ui._modal == "ending",
		"Intake Four rescue resolves the chapter and gives Mara's lead")
	campaign.ui._show("")
	campaign.start_new_game(false)
	_check(campaign.load_progress() and windgate.rescued and windgate.wrong == 1 and
		campaign.station._intake_gate.position.y > campaign.station._closed_gate_y + 1.5,
		"Continue preserves the rescue, open shutter, and wrong-accusation consequence")
	campaign.audio.start()
	for cue in campaign.audio.SCORE:
		campaign.audio.set_score(cue)
		_check(campaign.audio._score.playing and campaign.audio._score.stream is AudioStreamOggVorbis and
			campaign.audio._score.stream.get_length() > 15.0, "Playable original cue: " + campaign.audio.SCORE[cue])
	campaign.audio.stop_all()
	await process_frame
	await process_frame
	for suffix in ["", ".next", ".previous"]:
		var path: String = ProjectSettings.globalize_path(campaign.save_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Windgate chapter finished with %d failures" % failures)
	current_scene = null
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)


func _visit(id: String) -> void:
	var at := windgate.point(id)
	game.pilot.respawn(at)
	await physics_frame
	await physics_frame
	_check(campaign._nearest_interaction() == id, "Normal interaction prompt selects " + id)
	Input.action_press("restore")
	await physics_frame
	await physics_frame
	Input.action_release("restore")
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)
