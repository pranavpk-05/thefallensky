extends SceneTree

const Windgate = preload("res://frontier_disappearance.gd")

var failures := 0
var game
var frontier
var pilot


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	frontier = game.campaign
	pilot = game.pilot
	frontier.save_path = "user://frontier-qa-%d.cfg" % OS.get_process_id()
	frontier.ui.show()
	frontier.ui.return_to_title()
	_press_button("New Game")
	_check(frontier.ui._modal == "opening", "New Game opens the expedition prologue")
	await _capture("dark-frontier-opening")
	_press_button("Follow Mara's Signal")
	await _ticks(35)
	_check(pilot.is_on_floor(), "New Game uses the live overlook spawn")
	await _capture("dark-frontier-overlook")
	await _restore(0)
	_check(game.step == 0 and frontier._chapter_index() == 0, "seals wait for the lost expedition investigation")
	pilot.respawn(game.checkpoint)
	for id in ["journal", "radio", "tracks", "kit"]:
		await _visit(id)
		_check(frontier.case_file.collected.has(id), "E inspects " + id)
	_check(frontier.case_file.camp_complete() and frontier.supplies == 2 and frontier.flares == 1,
		"camp provides three lead clues and tangible supplies")
	pilot.respawn(pilot.global_position + Vector3(0, -60, 0))
	await _ticks(4)
	_check(frontier.health == 75.0 and pilot.global_position.distance_to(game.checkpoint) < 1.0,
		"fall applies damage and triggers checkpoint")
	await _action("heal")
	_check(frontier.health == 100.0 and frontier.supplies == 1, "healing spends exactly one dressing")
	var stamina: float = pilot.stamina
	Input.action_press("sprint")
	Input.action_press("move_back")
	await _ticks(14)
	Input.action_release("sprint")
	Input.action_release("move_back")
	_check(pilot.stamina < stamina, "sprinting spends stamina")
	Input.action_press("crouch")
	await _ticks(3)
	_check(pilot.crouching, "crouch enters the stealth state")
	Input.action_release("crouch")
	await _visit("camp_rest")
	_check(pilot.stamina == 100.0 and frontier.exposure == 0.0, "camp rest restores stamina and warmth")

	var guard = frontier.guardian
	var at: Vector3 = guard.origin
	pilot.respawn(at + Vector3(0.0, 0.55, 1.1))
	guard.reset_guard()
	guard.stun_time = 0.0
	await _ticks(95)
	_check(guard.state == 2 and frontier.health < 100.0, "sentinel detects, pursues and strikes")
	await _action("flare")
	_check(frontier.flares == 0 and guard.stun_time > 5.0 and guard.state == 0, "flare interrupts pursuit")
	pilot.respawn(game.checkpoint)
	await _ticks(10)
	_check(guard.state == 0, "breaking contact disengages the sentinel")

	await _walk_into_tunnel()
	_check(frontier.case_file.collected.has("relay"), "river tunnel relay is reachable and inspectable")
	await _visit("manifest")
	_check(frontier.case_file.collected.has("manifest"), "river tunnel manifest is reachable and inspectable")
	await _capture("dark-frontier-tunnel")
	await _visit("vault_hint")
	await _visit("rune_sun")
	_check(frontier.cache_steps == 0, "incorrect rune resets the cache")
	for id in ["rune_moon", "rune_sun", "rune_current"]:
		await _visit(id)
	_check(frontier.cache_open and frontier.supplies == 3, "correct rune sequence grants two dressings")
	_check(frontier._chapter_index() == 1, "expedition evidence unlocks chapter II")
	await _restore(0)
	await _glide_to_seal(1, 18.3)
	await _action("restore")
	await _glide_to_seal(2, 16.0)
	await _action("restore")
	_check(game.step == 3 and frontier._chapter_index() == 2 and frontier.windgate.vanished_at >= 0.0,
		"three seals unlock chapter III and guarantee the Windgate investigation can begin")
	await _visit("spire_start")
	_check(frontier.relay_time == 0.0, "final relay is gated by the investigation")
	for id in [Windgate.LEDGER, Windgate.RADIO, Windgate.SEAL]:
		await _visit_windgate(id)
		_check(frontier.case_file.collected.has(id), "Windgate evidence is reachable: " + id)
	await _visit_windgate(Windgate.BOARD)
	_press_button(Windgate.RECONSTRUCTION["key_first"])
	await _visit_windgate(Windgate.BOARD)
	_press_button(Windgate.ACCUSATION["vale"])
	_check(frontier.windgate.wrong == 1 and not frontier.windgate.exposed, "wrong accusation loses trust and allows a retry")
	await _visit_windgate(Windgate.BOARD)
	_press_button(Windgate.ACCUSATION["orrin"])
	await _visit_windgate(Windgate.RESCUE)
	_check(frontier.windgate.rescued and frontier._chapter_index() == 3, "rescuing Lysa unlocks the Hanging Court record")
	_press_button("Return to the Valley")
	await _restore(0)
	_check(pilot.launched, "the restored Windgate updraft remains available")
	await _glide_to_seal(1, 18.3)
	await _walk_to("court")
	_check(frontier.case_file.collected.has("court"), "Lysa's stamp unlocks Mara's recording")
	_submit_journal(["relay", "manifest", "radio"])
	_check(not frontier.case_file.solved and frontier.wrong_links == 1 and frontier.exposure >= 12.0,
		"unsupported main deduction adds exposure and preserves progress")
	_submit_journal(["relay", "manifest", "court"])
	_check(frontier.case_file.solved and frontier._chapter_index() == 4, "the journal deduction unlocks chapter V")
	_press_button("Close Journal")

	await _visit("spire_start")
	_check(frontier.relay_time > 0.0 and not frontier.relay_ready, "Mara opens the final relay challenge")
	await _visit("anchor_core")
	_check(frontier.relay_time == 0.0 and pilot.global_position.distance_to(game.checkpoint) < 1.0,
		"wrong anchor returns to the console checkpoint")
	await _visit("spire_start")
	frontier.relay_time = 0.01
	await _ticks(5)
	_check(frontier.relay_time == 0.0 and not frontier.relay_ready, "surge timeout resets the challenge")
	await _visit("spire_start")
	frontier._damage(200.0)
	_check(frontier.relay_time == 0.0 and frontier.health == 100.0, "death resets the encounter and restores health")
	await _visit("spire_start")
	for id in frontier.RELAY_ORDER:
		await _walk_to(id)
	_check(frontier.relay_ready and frontier.relay_time == 0.0, "all three anchors can be reached on foot within the surge window")
	frontier.save_progress()
	await _capture("dark-frontier-final-spire")

	await _visit("publish")
	_check(frontier.case_file.ending == "publish", "restore console commits the restored Spires outcome")
	await create_timer(2.6, true).timeout
	_check(paused and frontier.ui._ending_title == "The Spires Awaken", "the story displays the restoration victory")
	await _capture("dark-frontier-ending")
	_press_button("Credits")
	_check(frontier.ui._modal == "credits", "victory opens the credits")
	_press_button("Return to Ending")
	frontier.ui.return_to_title()
	_press_button("Continue")
	_check(game.step == 3 and frontier.case_file.solved and frontier.case_file.ending == "publish"
		and frontier.case_file.collected.has("kit") and frontier.supplies == 3 and frontier.flares == 0
		and frontier.cache_open and frontier.ui._modal == "ending" and frontier.wrong_links == 1,
		"Continue preserves clues, inventory, seals, deduction penalties and the chosen victory")
	var unusable := ConfigFile.new()
	unusable.set_value("state", "format", 2)
	unusable.set_value("state", "checkpoint", "invalid position")
	_check(unusable.save(frontier.save_path) == OK, "invalid checkpoint fixture saved")
	frontier.ui.return_to_title()
	_press_button("Continue")
	_check(frontier.relay_ready and frontier.case_file.ending.is_empty() and not paused,
		"Continue falls back to the last valid pre-choice checkpoint")
	await _visit("rescue")
	_check(frontier.case_file.ending == "rescue", "the other console commits the safe shutdown")
	await create_timer(2.6, true).timeout
	_check(paused and frontier.ui._ending_title == "A Sky of Our Own", "the shutdown victory is presented")
	await _capture("dark-frontier-shutdown")
	frontier.ui.return_to_title()
	_press_button("Continue")
	_check(frontier.case_file.ending == "rescue" and frontier.ui._modal == "ending", "Continue restores the shutdown victory")
	frontier.ui._show("")
	frontier.start_new_game(false)
	_check(game.step == 0 and frontier.case_file.collected.is_empty() and not frontier.relay_ready,
		"New Game resets case, seals and relay")
	frontier.audio.stop_all()
	await create_timer(0.2, true).timeout
	for suffix: String in ["", ".next", ".previous"]:
		var path: String = ProjectSettings.globalize_path(frontier.save_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Dark Frontier story test finished with %d failures" % failures)
	current_scene = null
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)


func _visit(id: String) -> void:
	var at: Vector3 = frontier.sites.points[id]
	pilot.respawn(at + Vector3(0, 0.27, 0))
	await _ticks(15)
	await _action("restore")


func _visit_windgate(id: String) -> void:
	pilot.respawn(frontier.windgate.point(id))
	await _ticks(2)
	_check(frontier._nearest_interaction() == id, "E selects " + id)
	Input.action_press("restore")
	await _ticks(2)
	Input.action_release("restore")
	await process_frame


func _submit_journal(ids: Array[String]) -> void:
	if frontier.ui._modal != "journal":
		var event := InputEventKey.new()
		event.physical_keycode = KEY_J
		event.pressed = true
		frontier.ui._input(event)
	for index in frontier.ui._evidence.size():
		frontier.ui._evidence_list.item_selected.emit(index)
		frontier.ui._link_check.button_pressed = false
	for index in frontier.ui._evidence.size():
		if frontier.ui._evidence[index]["id"] in ids:
			frontier.ui._evidence_list.item_selected.emit(index)
			frontier.ui._link_check.button_pressed = true
	_press_button("Test deduction   3 / 3")


func _press_button(label: String) -> void:
	for button: Button in frontier.ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text == label:
			button.pressed.emit()
			return
	_check(false, "expected active button " + label)


func _walk_to(id: String) -> void:
	var target: Vector3 = frontier.sites.points[id]
	Input.action_press("move_forward")
	for i in 210:
		var offset: Vector3 = target - pilot.global_position
		if Vector2(offset.x, offset.z).length() < 1.1:
			break
		pilot.orbit.rotation.y = atan2(-offset.x, -offset.z)
		await physics_frame
	Input.action_release("move_forward")
	_check(frontier._nearest_interaction() == id, "walking reaches " + id)
	await _action("restore")


func _glide_to_seal(index: int, cut_distance: float) -> void:
	var target: Vector3 = game.shrines[index].global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 380:
		var offset: Vector3 = target - pilot.global_position
		if Vector2(offset.x, offset.z).length() < cut_distance:
			break
		pilot.orbit.rotation.y = atan2(-offset.x, -offset.z)
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _ticks(120)
	_check(pilot.is_on_floor() and pilot.global_position.distance_to(target) < 6.0,
		"glider lands in range of " + game.SITE_NAMES[index])


func _walk_into_tunnel() -> void:
	var entry := Vector3(-42.0, game.valley.height_at(-42.0, -63.8) + 0.35, -63.8)
	var target: Vector3 = frontier.sites.points["relay"]
	pilot.respawn(entry)
	await _ticks(35)
	pilot.orbit.rotation.y = PI / 2.0
	await _ticks(16)
	await _capture("dark-frontier-forest")
	Input.action_press("move_forward")
	for i in 140:
		var offset: Vector3 = target - pilot.global_position
		if Vector2(offset.x, offset.z).length() < 1.2:
			break
		pilot.orbit.rotation.y = atan2(-offset.x, -offset.z)
		await physics_frame
	Input.action_release("move_forward")
	await _ticks(5)
	await _action("restore")


func _restore(index: int) -> void:
	var site: Node3D = game.shrines[index]
	pilot.respawn(site.global_position + Vector3(0, 0.4, 0.5))
	await _ticks(18)
	await _action("restore")


func _capture(stem: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(not frame.is_empty() and frame.save_png("res://.godot/%s.png" % stem) == OK, stem + " is captured")


func _action(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(4)
	Input.action_release(action)
	await _ticks(3)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
