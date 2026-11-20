extends CanvasLayer

signal new_game_requested
signal continue_requested
signal save_requested
signal quit_requested
signal quality_changed(level: int)
signal deduction_submitted(ids: PackedStringArray)
signal cue_requested(id: StringName)
signal modal_changed(active: bool)
signal windgate_choice(choice: String)
signal ending_requested

const INK := Color("#081618")
const BONE := Color("#f1e5ce")
const CYAN := Color("#91d9cb")
const MUTED := Color("#aebeb8")
const AMBER := Color("#eab778")
const DANGER := Color("#e88977")
const SETTINGS_PATH := "user://frontier_settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Cinematic"]

var _root: Control
var _modal_host: Control
var _modal := ""
var _settings_from := "title"
var _play_hud: PanelContainer
var _flight_hud: PanelContainer
var _health: ProgressBar
var _stamina: ProgressBar
var _exposure: ProgressBar
var _supply_text: Label
var _danger_text: Label
var _flight_data: Label
var _flight_hint: Label
var _toast: Label
var _toast_anchor: CenterContainer
var _toast_animation: Tween
var _has_save := false
var _quality := 2
var _volume := 0.8
var _fullscreen := false
var _supplies := 0
var _case_title := "Field journal"
var _case_question := ""
var _evidence: Array[Dictionary] = []
var _discoveries := PackedStringArray()
var _deduction_status := ""
var _can_deduce := false
var _checked := PackedStringArray()
var _evidence_list: ItemList
var _evidence_title: Label
var _evidence_text: Label
var _link_check: CheckButton
var _deduce_button: Button
var _selected_evidence := -1
var _ending_title := ""
var _decision_question := ""
var _decision_options := {}
var _ending_text := ""
var campaign_complete := false
var _victory := false
var _heading_font: SystemFont
var _quitting := false


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_heading_font = SystemFont.new()
	_heading_font.font_names = PackedStringArray(["Georgia", "Cambria", "Liberation Serif"])
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	_build_hud()
	_modal_host = Control.new()
	_root.add_child(_modal_host)
	_modal_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_anchor = CenterContainer.new()
	_root.add_child(_toast_anchor)
	_toast_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_toast(false)
	var toast_panel := PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.027, 0.073, 0.08, 0.93), CYAN.darkened(0.48), 10))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_anchor.add_child(toast_panel)
	_toast = _label(toast_panel, "", 17, BONE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.modulate.a = 0.0


func configure(show_title: bool, can_continue: bool) -> void:
	_has_save = can_continue
	_read_settings()
	_apply_audio_and_display()
	quality_changed.emit(_quality)
	if show_title:
		get_tree().auto_accept_quit = false
		_show("title")


func set_continue_available(available: bool) -> void:
	if available == _has_save:
		return
	_has_save = available
	if _modal == "title":
		_show("title")


func set_status(health: float, stamina: float, exposure: float, supplies: int, danger := "") -> void:
	_health.value = health
	_stamina.value = stamina
	_exposure.value = exposure
	_supplies = supplies
	_supply_text.text = "MEDICAL SUPPLIES  %02d" % supplies
	_danger_text.text = danger
	_danger_text.visible = not danger.is_empty()


func set_flight(active: bool, speed: float, altitude: float, throttle: float, engine_on: bool, grounded: bool) -> void:
	_flight_hud.visible = active and _modal.is_empty()
	_play_hud.visible = not active and _modal.is_empty()
	if active:
		_flight_data.text = "%03d km/h     %03d m     %02d%%" % [roundi(speed * 3.6), roundi(altitude), roundi(throttle * 100)]
		_flight_hint.text = "Engine off   ·   I  Start" if not engine_on else ("On the ground   ·   Space  Brake" if grounded else "Airborne   ·   V  Camera")


func set_journal(case_title: String, case_question: String, entries: Array[Dictionary],
		discoveries: PackedStringArray, deduction_status: String, can_deduce: bool) -> void:
	_case_title = case_title
	_case_question = case_question
	_evidence = entries.duplicate(true)
	_discoveries = discoveries.duplicate()
	_deduction_status = deduction_status
	_can_deduce = can_deduce
	if not can_deduce:
		_checked.clear()
	if _modal == "journal":
		_show("journal")


func notify(message: String, duration := 3.5) -> void:
	_toast.text = message
	var panel := _toast.get_parent() as Control
	if _toast_animation and _toast_animation.is_running():
		_toast_animation.kill()
	panel.modulate.a = 1.0
	_toast_animation = create_tween()
	_toast_animation.tween_interval(duration)
	_toast_animation.tween_property(panel, "modulate:a", 0.0, 0.45)


func show_opening() -> void:
	_show("opening")


func show_ending(title: String, revelation: String, victory := false) -> void:
	_ending_title = title
	_ending_text = revelation
	_victory = victory
	_show("ending")


func return_to_title() -> void:
	_show("title")


func ask_windgate(question: String, options: Dictionary) -> void:
	_decision_question = question
	_decision_options = options
	_show("windgate")


func _build_windgate(shade: Control) -> void:
	var panel := _centered_panel(shade, 555)
	_label(panel, "The People Who Disappeared", 30, BONE, true, true)
	_label(panel, _decision_question, 19, BONE, false, true)
	for choice: String in _decision_options:
		_button(panel, _decision_options[choice], _select_windgate.bind(choice))
	_focus(_button(panel, "Return to Windgate", _show.bind("")))


func _select_windgate(choice: String) -> void:
	_show("")
	windgate_choice.emit(choice)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _modal.is_empty():
			_show("pause")
		elif _modal == "settings":
			_show(_settings_from)
		elif _modal == "title":
			return
		elif _modal == "credits":
			_show("ending")
		else:
			_show("")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		if _modal.is_empty() or _modal == "journal":
			_show("journal" if _modal.is_empty() else "")
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not get_tree().auto_accept_quit:
		_quit_game()


func _show(screen: String) -> void:
	for child in _modal_host.get_children():
		child.hide()
		child.queue_free()
	_modal = screen
	var blocked := not screen.is_empty()
	get_tree().paused = blocked
	modal_changed.emit(blocked)
	_place_toast(blocked)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if blocked else Input.MOUSE_MODE_CAPTURED
	_play_hud.visible = not blocked
	_flight_hud.hide()
	if not blocked:
		return

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.040, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_host.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match screen:
		"title":
			shade.color.a = 0.0
			_build_title(shade)
		"pause":
			_build_pause(shade)
		"settings":
			_build_settings(shade)
		"journal":
			_build_journal(shade)
		"ending":
			_build_ending(shade)
		"opening":
			_build_opening(shade)
		"credits":
			_build_credits(shade)
		"windgate":
			_build_windgate(shade)


func _place_toast(modal: bool) -> void:
	if modal:
		_toast_anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_toast_anchor.offset_top = 16
		_toast_anchor.offset_bottom = 55
	else:
		_toast_anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_toast_anchor.offset_top = -145
		_toast_anchor.offset_bottom = -105


func _build_title(shade: Control) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.010, 0.013, 0.019, 0.99), Color(0.018, 0.023, 0.031, 0.87),
		Color(0.014, 0.026, 0.041, 0.12)])
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_to = Vector2(1, 0)
	var backing := TextureRect.new()
	backing.texture = fade
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 11)
	shade.add_child(menu)
	menu.anchor_left = 0.075
	menu.anchor_top = 0.20
	menu.anchor_right = 0.075
	menu.anchor_bottom = 0.20
	menu.offset_right = 370
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	var heading := _label(menu, "Solstice of the\nSunken Spire", 47, BONE)
	heading.add_theme_font_override("font", serif)
	_label(menu, "D A R K   F R O N T I E R", 17, AMBER, true)
	_rule(menu)
	var resume := _button(menu, "Continue", _continue_game)
	resume.disabled = not _has_save
	var begin := _button(menu, "New Game", _start_game)
	_button(menu, "Settings", _open_settings.bind("title"))
	_button(menu, "Quit", _quit_game)
	_focus(resume if _has_save else begin)


func _build_pause(shade: Control) -> void:
	var menu := _centered_panel(shade, 360)
	_label(menu, "Expedition paused", 31, BONE, true)
	_rule(menu)
	var resume := _button(menu, "Resume", _show.bind(""))
	_button(menu, "Field Journal", _show.bind("journal"))
	_button(menu, "Settings", _open_settings.bind("pause"))
	if campaign_complete:
		_button(menu, "View Ending", func() -> void: ending_requested.emit())
	_button(menu, "Save and Return to Title", _save_to_title)
	_focus(resume)


func _build_settings(shade: Control) -> void:
	var menu := _centered_panel(shade, 450)
	_label(menu, "Settings", 35, BONE, true)
	_rule(menu)
	_label(menu, "Graphics quality", 16, CYAN)
	var quality := OptionButton.new()
	quality.custom_minimum_size.y = 42
	for level: String in QUALITY_NAMES:
		quality.add_item(level)
	quality.select(_quality)
	quality.item_selected.connect(_set_quality)
	menu.add_child(quality)
	_label(menu, "Master volume", 16, CYAN)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = _volume
	volume.custom_minimum_size.y = 27
	volume.value_changed.connect(_set_volume)
	menu.add_child(volume)
	var screen := CheckButton.new()
	screen.text = "Fullscreen"
	screen.button_pressed = _fullscreen
	screen.toggled.connect(_set_fullscreen)
	menu.add_child(screen)
	_button(menu, "Back", _show.bind(_settings_from))
	_focus(quality)


func _build_journal(shade: Control) -> void:
	var content := _centered_panel(shade, 774)
	_label(content, _case_title, 35, BONE, true)
	_label(content, _case_question, 17, MUTED, false, true)
	_rule(content)
	var pages := TabContainer.new()
	pages.custom_minimum_size = Vector2(718, 308)
	content.add_child(pages)
	var case_file := HBoxContainer.new()
	case_file.name = "Evidence (%d)" % _evidence.size()
	case_file.add_theme_constant_override("separation", 17)
	pages.add_child(case_file)

	_evidence_list = ItemList.new()
	_evidence_list.custom_minimum_size.x = 248
	_evidence_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	case_file.add_child(_evidence_list)
	for entry in _evidence:
		_evidence_list.add_item(_clue_heading(entry))
	_evidence_list.item_selected.connect(_view_evidence)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 9)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_file.add_child(right)
	_evidence_title = _label(right, "", 25, BONE, true, true)
	var details := ScrollContainer.new()
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(details)
	_evidence_text = _label(details, "", 16, MUTED, false, true)
	_evidence_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_link_check = CheckButton.new()
	_link_check.text = "Link this clue"
	_link_check.toggled.connect(_toggle_link)
	right.add_child(_link_check)
	_deduce_button = _button(right, "Test deduction", _deduce)
	_deduce_button.visible = _can_deduce
	_refresh_deduce_button()

	var discoveries := VBoxContainer.new()
	discoveries.name = "Discovered sites"
	pages.add_child(discoveries)
	var sites := "Uncharted" if _discoveries.is_empty() else "\n".join(_discoveries)
	_label(discoveries, sites, 18, BONE, false, true)
	var kit := VBoxContainer.new()
	kit.name = "Inventory"
	pages.add_child(kit)
	_label(kit, "Medical supplies     %02d" % _supplies, 19, BONE)
	_label(kit, "Press H while exploring to use a medical supply.", 16, MUTED, false, true)
	_rule(content)
	_label(content, _deduction_status, 16, CYAN, false, true)
	_button(content, "Close Journal", _show.bind(""))
	if _evidence.is_empty():
		_evidence_title.text = "No evidence filed"
		_evidence_text.text = "Inspect expedition objects with E to record a clue."
		_link_check.hide()
		_focus(pages)
	else:
		_selected_evidence = clampi(_selected_evidence, 0, _evidence.size() - 1)
		_evidence_list.select(_selected_evidence)
		_view_evidence(_selected_evidence)
		_focus(_evidence_list)


func _build_opening(shade: Control) -> void:
	var panel := _centered_panel(shade, 622)
	_label(panel, "The Lost Expedition", 36, BONE, true, true)
	_rule(panel)
	_label(panel, "For centuries the Spires held the Frontier above the valley. Then all three rang in the same night, and the storms began. Mara Vale went looking for the hand that rang them.", 19, BONE, false, true)
	_label(panel, "Six days later, a broken transmission reaches your camp. “Wayfarer, they have our route. Begin where we left the fire.”", 19, MUTED, false, true)
	_focus(_button(panel, "Follow Mara's Signal", _show.bind("")))


func _build_ending(shade: Control) -> void:
	var panel := _centered_panel(shade, 622)
	if _victory:
		_label(panel, "CAMPAIGN COMPLETE", 14, CYAN)
	_label(panel, _ending_title, 36, BONE, true, true)
	_rule(panel)
	_label(panel, _ending_text, 19, MUTED, false, true)
	var explore := _button(panel, "Return to the Valley", _show.bind(""))
	if _victory:
		_button(panel, "Credits", _show.bind("credits"))
	_button(panel, "Save and Return to Title", _save_to_title)
	_focus(explore)


func _build_credits(shade: Control) -> void:
	var panel := _centered_panel(shade, 622)
	_label(panel, "Solstice of the Sunken Spire", 34, BONE, true, true)
	_label(panel, "Dark Frontier", 21, CYAN)
	_rule(panel)
	_label(panel, "Built with Godot Engine", 18, BONE)
	_label(panel, "Godot Engine contributors  ·  MIT License", 16, MUTED)
	_focus(_button(panel, "Return to Ending", _show.bind("ending")))


func _build_hud() -> void:
	_play_hud = _corner_panel()
	var status := VBoxContainer.new()
	_play_hud.add_child(status)
	status.add_theme_constant_override("separation", 4)
	_health = _status_meter(status, "HEALTH", DANGER)
	_stamina = _status_meter(status, "STAMINA", AMBER)
	_exposure = _status_meter(status, "EXPOSURE", CYAN)
	_supply_text = _label(status, "MEDICAL SUPPLIES  00", 13, MUTED)
	_danger_text = _label(status, "", 15, DANGER)
	_danger_text.hide()

	_flight_hud = _corner_panel()
	_flight_hud.hide()
	var cockpit := VBoxContainer.new()
	_flight_hud.add_child(cockpit)
	_label(cockpit, "AIRSPEED       ALTITUDE       THROTTLE", 13, CYAN)
	_flight_data = _label(cockpit, "", 22, BONE)
	_flight_hint = _label(cockpit, "", 14, AMBER)
	_label(cockpit, "R/F  Throttle    S/W  Pitch    A/D  Bank", 13, MUTED)
	_label(cockpit, "Q/C  Yaw    Space  Brake    E  Exit", 13, MUTED)


func _status_meter(parent: Control, title: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var caption := _label(row, title, 12, BONE)
	caption.custom_minimum_size.x = 79
	var meter := ProgressBar.new()
	meter.custom_minimum_size = Vector2(100, 4)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", _panel_style(Color("#294043"), Color.TRANSPARENT, 0))
	meter.add_theme_stylebox_override("fill", _panel_style(color, Color.TRANSPARENT, 0))
	row.add_child(meter)
	return meter


func _corner_panel() -> PanelContainer:
	var corner := MarginContainer.new()
	_root.add_child(corner)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -30
	corner.offset_bottom = -33
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.06, 0.07, 0.83), Color("#315454"), 10))
	corner.add_child(panel)
	return panel


func _centered_panel(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.022, 0.054, 0.062, 0.98), Color("#406261"), 24))
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 11)
	panel.add_child(stack)
	return stack


func _start_game() -> void:
	_show("")
	new_game_requested.emit()


func _continue_game() -> void:
	_show("")
	continue_requested.emit()


func _save_to_title() -> void:
	save_requested.emit()
	_show("title")


func _quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	quit_requested.emit()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()


func _open_settings(from: String) -> void:
	_settings_from = from
	_show("settings")


func _set_quality(level: int) -> void:
	_quality = level
	quality_changed.emit(level)
	_write_settings()


func _set_volume(value: float) -> void:
	_volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value)))
	AudioServer.set_bus_mute(0, value == 0.0)
	_write_settings()


func _set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_audio_and_display()
	_write_settings()


func _read_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	_quality = clampi(int(settings.get_value("display", "quality", 2)), 0, QUALITY_NAMES.size() - 1)
	_fullscreen = bool(settings.get_value("display", "fullscreen", false))
	_volume = clampf(float(settings.get_value("audio", "volume", 0.8)), 0.0, 1.0)


func _write_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("display", "quality", _quality)
	settings.set_value("display", "fullscreen", _fullscreen)
	settings.set_value("audio", "volume", _volume)
	if settings.save(SETTINGS_PATH) != OK:
		notify("Settings could not be saved.")


func _apply_audio_and_display() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, _volume)))
	AudioServer.set_bus_mute(0, _volume == 0.0)
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN if _fullscreen else Window.MODE_WINDOWED


func _view_evidence(index: int) -> void:
	_selected_evidence = index
	var entry := _evidence[index]
	_evidence_title.text = String(entry.get("title", "Evidence"))
	_evidence_text.text = String(entry.get("text", ""))
	_link_check.visible = _can_deduce
	_link_check.set_pressed_no_signal(_checked.has(String(entry.get("id", ""))))


func _toggle_link(checked: bool) -> void:
	var entry := _evidence[_selected_evidence]
	var id := String(entry.get("id", ""))
	if checked and _checked.size() < 3:
		_checked.append(id)
	elif checked:
		_link_check.set_pressed_no_signal(false)
		notify("Unlink a clue before adding another.")
	else:
		var index := _checked.find(id)
		if index >= 0:
			_checked.remove_at(index)
	_evidence_list.set_item_text(_selected_evidence, _clue_heading(entry))
	_refresh_deduce_button()


func _clue_heading(entry: Dictionary) -> String:
	var title := String(entry.get("title", "Evidence"))
	return "◆  " + title if _checked.has(String(entry.get("id", ""))) else title


func _refresh_deduce_button() -> void:
	_deduce_button.text = "Test deduction   %d / 3" % _checked.size()
	_deduce_button.disabled = _checked.size() != 3


func _deduce() -> void:
	deduction_submitted.emit(_checked.duplicate())


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 43
	button.pressed.connect(func() -> void:
		cue_requested.emit(&"menu")
		action.call())
	parent.add_child(button)
	return button


func _label(parent: Control, words: String, pixels: int, color: Color, heading := false, wrap := false) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = words
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	if heading:
		label.add_theme_font_override("font", _heading_font)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _rule(parent: Control) -> void:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = CYAN.darkened(0.6)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _focus(control: Control) -> void:
	control.grab_focus.call_deferred()


func _panel_style(color: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	if border.a > 0.0:
		style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(padding)
	return style


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _panel_style(INK.lightened(0.035), Color("#365655"), 8))
		theme.set_stylebox("hover", type, _panel_style(Color("#204544"), CYAN.darkened(0.3), 8))
		theme.set_stylebox("pressed", type, _panel_style(Color("#275953"), CYAN, 8))
		theme.set_stylebox("disabled", type, _panel_style(INK, Color("#203432"), 8))
		theme.set_stylebox("focus", type, _panel_style(Color.TRANSPARENT, CYAN, 8))
		theme.set_color("font_color", type, BONE)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.38))
		theme.set_color("font_focus_color", type, BONE)
	theme.set_stylebox("panel", "ItemList", _panel_style(INK, Color("#315453"), 6))
	theme.set_stylebox("selected", "ItemList", _panel_style(Color("#244b47"), CYAN.darkened(0.45), 5))
	theme.set_stylebox("selected_focus", "ItemList", _panel_style(Color("#244b47"), CYAN, 5))
	theme.set_color("font_color", "ItemList", BONE)
	theme.set_color("font_selected_color", "ItemList", BONE)
	theme.set_constant("v_separation", "ItemList", 13)
	theme.set_stylebox("panel", "TabContainer", _panel_style(Color("#0d2022"), Color("#315453"), 9))
	theme.set_stylebox("tab_selected", "TabContainer", _panel_style(Color("#244b47"), Color("#467470"), 9))
	theme.set_stylebox("tab_unselected", "TabContainer", _panel_style(INK, Color("#315453"), 9))
	theme.set_color("font_selected_color", "TabContainer", BONE)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)
	return theme
