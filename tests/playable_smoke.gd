extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var pilot = game.get_node("Wayfarer")
	await _ticks(40)
	_check(pilot.is_on_floor(), "spawn lands on the starting overlook")
	var spawn: Vector3 = pilot.global_position
	Input.action_press("move_forward")
	await _ticks(40)
	_check(pilot.global_position.z < spawn.z - 3.0, "forward input moves the character")
	Input.action_press("jump")
	await _ticks(29)
	_check(pilot.gliding and not pilot.is_on_floor(), "holding jump opens the glider")
	_check(pilot.velocity.z < -10.0, "glider accelerates forward")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		_check(shot.get_width() > 0 and not shot.is_empty(), "rendered viewport is readable")
		if not shot.is_empty():
			var total := 0.0
			for y in range(0, shot.get_height(), 32):
				for x in range(0, shot.get_width(), 32):
					total += shot.get_pixel(x, y).get_luminance()
			_check(total > 3.0, "rendered viewport is nonblank")
			_check(shot.save_png("res://.godot/solstice-glide.png") == OK, "glide screenshot saves")
		print("Renderer %s | %d draw calls | %d primitives" % [
			RenderingServer.get_current_rendering_method(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _ticks(2)
	_check(not pilot.gliding, "releasing jump retracts the sail")
	Input.action_press("restart")
	await _ticks(2)
	Input.action_release("restart")
	_check(pilot.global_position.distance_to(game.checkpoint) < 1.0, "restart returns to the checkpoint")
	for i in 3:
		var site: Node3D = game.shrines[i]
		if i == 0:
			await _ticks(30)
		await _fly_to_site(pilot, site.global_position, 18.3 if i != 2 else 16.0)
		_check(pilot.is_on_floor() and pilot.global_position.distance_to(site.global_position) < 6.0,
			"glider lands at %s (distance %.1f m)" % [game.SITE_NAMES[i], pilot.global_position.distance_to(site.global_position)])
		Input.action_press("restore")
		await _ticks(3)
		Input.action_release("restore")
		_check(game.step == i + 1, "seal %d advances the objective" % (i + 1))
		if i < 2:
			_check(pilot.velocity.y > 15.0, "restored seal launches the player")
	_check(game.objective.text == "The valley remembers the sun", "completion updates the HUD")
	pilot.global_position.y = -10.0
	await _ticks(2)
	_check(pilot.global_position.distance_to(game.checkpoint) < 1.0, "fall recovery uses the latest checkpoint")
	print("Playable smoke test finished with %d failures" % failures)
	quit(1 if failures else 0)


func _fly_to_site(pilot: CharacterBody3D, target: Vector3, cut_distance: float) -> void:
	var orbit: Node3D = pilot.get_node("Orbit")
	var offset := target - pilot.global_position
	orbit.rotation.y = atan2(-offset.x, -offset.z)
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 380:
		offset = target - pilot.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance < cut_distance:
			break
		orbit.rotation.y = atan2(-offset.x, -offset.z)
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _ticks(120)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
