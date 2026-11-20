extends SceneTree

const FloodGauge = preload("res://frontier_incident.gd")

var _game
var _campaign
var _pilot
var _incident: FloodGauge
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_campaign = _game.campaign
	_pilot = _game.pilot
	_incident = _campaign.incident
	_campaign.save_path = "user://flood-gauge-qa-%d.cfg" % OS.get_process_id()
	_game.valley.set_process(false)
	_campaign.start_new_game(false)
	_check(not _incident.visible, "The incident stays hidden before the camp has been investigated")
	_open_lead()
	await _visit(FloodGauge.TRACE)
	_check(_incident.started and not _incident.can_interact(FloodGauge.DISPATCH, _campaign.case_file),
		"Approaching activates a robbery with no shortcut to the dispatch")
	_check(_game.objective.text == FloodGauge.TITLE, "Normal gameplay HUD shows the nearby robbery")
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture()
	await _place(Vector3(-4.65, 0, -45.75))
	await _walk_to(_incident.point(FloodGauge.TRACE), 2.15, "The signed approach reaches the survey case on foot")
	await _inspect()
	_check(_campaign.case_file.collected.has(FloodGauge.TRACE), "E collects the dry tally seal")
	await _walk_to_dispatch()
	await _inspect()
	_check(_campaign.case_file.collected.has(FloodGauge.DISPATCH) and
		not _campaign.case_file.collected.has(FloodGauge.WITNESS) and
		_campaign.case_file.discoveries.has("The old flood gauge"), "The physical clue alone leads to the dispatch and closes the robbery")
	_check(not _campaign.case_file.deduction_available(), "The optional dispatch cannot substitute for the main case records")
	var before_round := _incident.point(FloodGauge.WITNESS)
	for i in 25:
		_incident.advance(1.0, _pilot, 0.0, _campaign.case_file)
	var at_gauge := _incident.point(FloodGauge.WITNESS)
	_check(at_gauge.distance_to(before_round) > 3.0 and at_gauge.distance_to(_incident.point(FloodGauge.DISPATCH)) < 1.6,
		"Iven inspects the recommissioned gauge during his routine")
	if OS.get_cmdline_user_args().has("--capture"):
		await _frame("03-repaired-gauge", at_gauge + Vector3(2.1, 0, 2.5), _incident.point(FloodGauge.DISPATCH), 275.0)
	for i in 28:
		_incident.advance(1.0, _pilot, 0.0, _campaign.case_file)
	_check(_incident.point(FloodGauge.WITNESS).distance_to(at_gauge) > 9.0,
		"Iven checks the landing after his gauge round")

	_campaign.start_new_game(false)
	_open_lead()
	await _visit(FloodGauge.TRACE)
	await _inspect()
	await _visit(FloodGauge.WITNESS)
	await _inspect()
	_check(_incident.discussed_trace and _campaign.ui._toast.text.contains("Vesper seal"),
		"Iven acknowledges the physical evidence in conversation")
	var saved_station := _incident.point(FloodGauge.WITNESS)
	var checkpoint := ConfigFile.new()
	_incident.save_to(checkpoint)
	_incident.reset()
	_incident.load_from(checkpoint)
	_check(_incident.discussed_trace and _incident.conversations == 1 and
		_incident.point(FloodGauge.WITNESS).is_equal_approx(saved_station),
		"Iven remembers the prior discussion and resumes at the saved position")

	_campaign.start_new_game(false)
	_open_lead()
	var witness := _incident.point(FloodGauge.WITNESS)
	var start := witness + Vector3(3.0, 0, 3.0)
	await _place(start)
	_pilot.orbit.rotation.y = atan2(start.x - witness.x, start.z - witness.z)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(14)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check(_incident.retreat >= 0.0 and not _incident.can_interact(FloodGauge.WITNESS, _campaign.case_file),
		"Sprinting at Iven sends him toward cover and delays conversation")
	await _place(_game.opening_spawn())
	for i in 25:
		_incident.advance(1.0, _pilot, 0.94, _campaign.case_file, false)
	_check(_incident.wash == 1.0 and not _incident.can_interact(FloodGauge.TRACE, _campaign.case_file),
		"Prolonged heavy rain removes the uncollected physical evidence")
	_check(_incident.point(FloodGauge.WITNESS).distance_to(witness) > 5.0,
		"Iven relocated to a reachable place near the gauge")
	_campaign.persistence_enabled = true
	_campaign.save_progress()
	_campaign.start_new_game(false)
	_check(_incident.wash == 0.0 and _incident.retreat == -1.0, "New Game clears the incident state")
	_check(_campaign.load_progress() and _incident.wash == 1.0 and _incident.retreat == FloodGauge.RETREAT_TIME,
		"Continue restores the weather loss and Iven's location")
	var cover := _incident.point(FloodGauge.WITNESS)
	await _place(cover + Vector3(1.45, 0, 1.50))
	_pilot.orbit.rotation.y = atan2(1.45, 1.50)
	await _inspect()
	_check(_campaign.case_file.collected.has(FloodGauge.WITNESS), "E records Iven's testimony after the seal is lost")
	_check(_campaign.ui._toast.text.contains("rain took") and _pilot._conversation_time > 0.0,
		"Late testimony explains the missing trace and focuses the conversation camera")
	if OS.get_cmdline_user_args().has("--capture"):
		await _frame("04-iven-storm", cover, cover, 268.0, true)
	await _visit(FloodGauge.WITNESS)
	await _inspect()
	_check(_campaign.ui._toast.text.contains("You're back"), "Iven recognizes the player in follow-up dialogue")
	await _visit(FloodGauge.DISPATCH)
	await _inspect()
	_campaign.start_new_game(false)
	_check(_campaign.load_progress() and _campaign.case_file.collected.has(FloodGauge.DISPATCH) and
		_campaign.case_file.collected.has(FloodGauge.WITNESS), "The testimony route closes the robbery and survives Continue")
	_check(_incident._gauge_face.text.contains("LOGGING") and
		_incident._gauge_indicator.material_override == _incident._gauge_on and _incident.conversations == 2,
		"Continue restores the working gauge and Iven's conversation memory")
	await _visit(FloodGauge.WITNESS)
	await _inspect()
	_check(_campaign.ui._toast.text.contains("wired the gauge back in"), "Iven confirms the repaired gauge after Continue")

	var old_save := ConfigFile.new()
	old_save.set_value("state", "format", 1)
	old_save.set_value("state", "checkpoint", _game.opening_spawn())
	old_save.set_value("state", "clues", PackedStringArray(["journal", "radio", "tracks", "manifest"]))
	_check(old_save.save(_campaign.save_path) == OK and _campaign.load_progress() and
		_campaign.case_file.collected.has("manifest") and not _incident.started and _incident.visible,
		"A format 1 save without the robbery fields keeps its original evidence and unlocks the incident")
	for suffix in ["", ".previous", ".next"]:
		var path: String = ProjectSettings.globalize_path(_campaign.save_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Flood gauge incident finished with %d failures" % _failures)
	quit(1 if _failures else 0)


func _open_lead() -> void:
	for id in ["journal", "radio", "tracks"]:
		_campaign._collect(id)


func _visit(id: String) -> void:
	await _place(_incident.point(id))


func _place(at: Vector3) -> void:
	var ground: float = _game.valley.surface_height_at(at.x, at.z)
	_pilot.respawn(Vector3(at.x, ground + 0.22, at.z))
	await _ticks(26)


func _walk_to_dispatch() -> void:
	await _walk_to(_incident.point(FloodGauge.DISPATCH), 1.8,
		"The dispatch is reachable on foot from the damaged survey case")


func _walk_to(target: Vector3, reach: float, message: String) -> void:
	Input.action_press("move_forward")
	for frame in range(125):
		var direction: Vector3 = target - _pilot.global_position
		if direction.length() < reach:
			break
		_pilot.orbit.rotation.y = atan2(-direction.x, -direction.z)
		await physics_frame
	Input.action_release("move_forward")
	await _ticks(5)
	_check(_pilot.is_on_floor() and _pilot.global_position.distance_to(target) < reach + 0.85, message)


func _inspect() -> void:
	Input.action_press("restore")
	await _ticks(2)
	Input.action_release("restore")
	await _ticks(2)


func _capture() -> void:
	var trace := _incident.point(FloodGauge.TRACE)
	await _frame("01-windgate-approach", Vector3(-4.75, 0, -46.15), trace, 260.0)
	await _frame("02-survey-case", trace + Vector3(2.0, 0, 2.4), trace, 252.0)
	await _visit(FloodGauge.TRACE)


func _frame(name: String, at: Vector3, target: Vector3, world_time: float, keep_camera := false) -> void:
	var incident_state := ConfigFile.new()
	_incident.save_to(incident_state)
	var previous_storm: float = _game.valley.storm_strength
	var previous_time: float = _game.valley._world_time
	var previous_mood: float = _game.valley._story_mood
	if not keep_camera:
		await _place(at)
		_pilot.orbit.rotation.y = atan2(at.x - target.x, at.z - target.z)
		_pilot.figure.rotation.y = _pilot.orbit.rotation.y
		_pilot.pitch.rotation.x = -0.24
	else:
		_pilot.focus_conversation(target + Vector3.UP * 0.68)
	_game.valley._story_mood = 0.82
	_game.valley._world_time = world_time
	_game.valley._update_weather()
	_game.valley._rain.global_position = _pilot.camera.global_position + Vector3.UP * 12.0
	await _ticks(24)
	if name == "02-survey-case":
		await _sample_quality()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://build/screenshots/flood-gauge/%s.png" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var lit_samples := 0
	if not image.is_empty():
		for x in range(0, image.get_width(), 32):
			for y in range(0, image.get_height(), 32):
				if image.get_pixel(x, y).get_luminance() > 0.09:
					lit_samples += 1
	_check(lit_samples > 30 and image.save_png(path) == OK, "Forward+ renders a nonblank crime scene at " + path)
	print("Capture: %s | %dx%d | %d draw calls | %d primitives | %d FPS" % [RenderingServer.get_current_rendering_method(),
		image.get_width(), image.get_height(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), Engine.get_frames_per_second()])
	_game.valley._world_time = previous_time
	_game.valley._story_mood = previous_mood
	_game.valley._update_weather()
	_game.valley.storm_strength = previous_storm
	_incident.load_from(incident_state)
	_incident.refresh(_campaign.case_file)


func _sample_quality() -> void:
	var original: int = _game.valley._quality
	var original_process: bool = _game.is_physics_processing()
	_game.set_physics_process(false)
	for level in 4:
		_game.valley.set_quality(level)
		_incident._shelter_lamp.shadow_enabled = level >= 2
		for warmup in 18:
			await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		for frame in 45:
			await RenderingServer.frame_post_draw
		var fps := 45.0 * 1000000.0 / maxf(1.0, Time.get_ticks_usec() - start)
		print("Flood Gauge preset %s: %.1f FPS (45 rendered frames at %s viewport)" %
			[["Low", "Medium", "High", "Ultra"][level], fps, str(root.size)])
	_game.valley.set_quality(original)
	_incident._shelter_lamp.shadow_enabled = original >= 2
	_game.set_physics_process(original_process)
	await RenderingServer.frame_post_draw


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
