extends SceneTree

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
	frontier.start_new_game(false)
	frontier.persistence_enabled = true
	await _ticks(35)
	_check(pilot.is_on_floor(), "New Game uses the live overlook spawn")
	await _capture("dark-frontier-overlook")
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
	await _restore(0)
	await _restore(1)
	_check(game.step == 2 and frontier.case_file.collected.has("court"), "Hanging Court preserves the seal and yields Mara's record")
	frontier.submit_deduction(PackedStringArray(["relay", "manifest", "radio"]))
	_check(not frontier.case_file.solved, "unsupported deductions are rejected")
	frontier.submit_deduction(PackedStringArray(["relay", "manifest", "court"]))
	_check(frontier.case_file.solved, "the three substantiating records solve the case")
	await _restore(2)
	_check(game.step == 3, "final seal still restores through E")
	await _visit("publish")
	_check(frontier.case_file.ending == "publish", "the Spire transmits the evidence")
	await create_timer(2.6, true).timeout
	_check(paused, "the story displays the chosen ending")
	await _capture("dark-frontier-ending")
	frontier.ui._show("")
	frontier.start_new_game(false)
	_check(game.step == 0 and frontier.case_file.collected.is_empty(), "New Game resets case and seal state")
	_check(frontier.load_progress(), "Continue reads the saved checkpoint")
	_check(game.step == 3 and frontier.case_file.solved and frontier.case_file.ending == "publish"
		and frontier.case_file.collected.has("kit") and frontier.supplies == 3 and frontier.flares == 0 and frontier.cache_open,
		"save round-trip preserves clues, ending, inventory and seals")
	frontier.case_file.ending = ""
	await _visit("rescue")
	_check(frontier.case_file.ending == "rescue", "the other console commits the rescue outcome")
	await create_timer(2.6, true).timeout
	_check(paused, "the rescue ending is presented")
	frontier.audio.stop_all()
	await create_timer(0.2, true).timeout
	for suffix: String in ["", ".next", ".previous"]:
		var path: String = ProjectSettings.globalize_path(frontier.save_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Dark Frontier story test finished with %d failures" % failures)
	quit(1 if failures else 0)


func _visit(id: String) -> void:
	var at: Vector3 = frontier.sites.points[id]
	pilot.respawn(at + Vector3(0, 0.27, 0))
	await _ticks(15)
	await _action("restore")


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
