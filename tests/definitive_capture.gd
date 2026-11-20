extends SceneTree

var game
var traveler
var valley
var folder := ""
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	folder = "res://build/definitive/" + ("before" if OS.get_cmdline_user_args().has("--before") else "after")
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--output="):
			folder = option.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	traveler = game.pilot
	valley = game.valley
	game.campaign.save_path = "user://definitive-capture-unused.cfg"
	await _ticks(8)
	valley.set_process(false)
	valley.set_quality(2)
	var profiling := OS.get_cmdline_user_args().has("--profile")
	if not profiling:
		await _shot("01-main-menu", Vector3.ZERO, Vector3.ZERO, 232.0, 0.82, false)
	game.campaign.ui._show("")
	game.campaign.start_new_game(false)
	if not profiling:
		await _shot("02-opening", game.opening_spawn(), Vector3(5.0, 0.0, 3.4), 58.0, 0.48)
	for id in ["journal", "radio", "tracks"]:
		game.campaign._collect(id)
	if profiling:
		await _profile_route()
		quit(0)
		return
	await _shot("03-settlement", Vector3(-4.55, 0, -45.5), Vector3(-6.8, 0, -58.4), 260.0, 0.82)
	await _shot("04-night-forest", Vector3(-41.2, 0, -63.4), Vector3(-48, 0, -64), 270.0, 0.68)
	var witness: Vector3 = game.campaign.incident.point("intake_witness")
	await _shot("05-iven", witness + Vector3(1.6, 0, 1.6), witness, 250.0, 0.82)
	await _shot("06-crime-scene", Vector3(-4.5, 0, -52.1), Vector3(-6.4, 0, -54.6), 252.0, 0.82)
	var tunnel: Vector3 = game.campaign.sites.tunnel_center
	var interior := Camera3D.new()
	root.add_child(interior)
	interior.global_position = tunnel + Vector3(2.95, 1.58, 0.45)
	interior.look_at(tunnel + Vector3(-3.20, 1.29, 0.0))
	interior.fov = 73.0
	interior.make_current()
	await _shot("07-intake-interior", Vector3.ZERO, Vector3.ZERO, 247.0, 0.82, false)
	traveler.camera.make_current()
	interior.queue_free()
	await _flight()
	quit(1 if failed else 0)


func _shot(name: String, at: Vector3, toward: Vector3, time: float, mood: float,
		place := true, interior := false) -> void:
	if place:
		at.y = maxf(at.y, valley.surface_height_at(at.x, at.z)) + 0.27
		traveler.respawn(at)
		traveler.orbit.rotation.y = atan2(at.x - toward.x, at.z - toward.z)
		traveler.figure.rotation.y = traveler.orbit.rotation.y
		traveler.pitch.rotation.x = -0.16 if interior else -0.22
	await _weather(time, mood)
	await _capture(name)


func _flight() -> void:
	var plane: CharacterBody3D = game.campaign.aircraft
	traveler.respawn(plane.global_position + Vector3.RIGHT * 3.0)
	if not plane.board(traveler):
		push_error("Could not board the Peregrine for visual comparison.")
		failed = true
		return
	plane.set_physics_process(false)
	plane.global_position = Vector3(21, 39, -126)
	plane.rotation = Vector3(-0.04, -0.15, 0.10)
	plane.reset_physics_interpolation()
	plane._update_camera(1.0)
	await _weather(253.0, 0.88)
	await _capture("08-peregrine")


func _weather(time: float, mood: float) -> void:
	valley._world_time = time
	valley._story_mood = mood
	valley._update_weather()
	await _ticks(20)
	var camera := root.get_camera_3d()
	if camera:
		valley._rain.global_position = camera.global_position + Vector3.UP * 12.0
	await _ticks(18)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _profile_route() -> void:
	await _weather(260.0, 0.82)
	for cycle in ["first approach", "repeat approach"]:
		await _shotless_position(Vector3(-4.55, 0, -45.5))
		var times: Array[float] = []
		var start := Time.get_ticks_usec()
		var last := start
		Input.action_press("move_forward")
		while Time.get_ticks_usec() - start < 4500000:
			var at: Vector3 = traveler.global_position
			var aim := Vector3(-5.1, 0, -58.0) if int((Time.get_ticks_usec() - start) / 1500000) % 2 == 0 else Vector3(-4.55, 0, -46.1)
			traveler.orbit.rotation.y = atan2(at.x - aim.x, at.z - aim.z)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
		Input.action_release("move_forward")
		times.sort()
		print("PROFILE | %s | %s High | %s frames | p50 %.2f ms | p95 %.2f ms | worst %.2f ms | draw %s | tris %s" %
			[cycle, str(root.get_texture().get_image().get_size()), times.size(), times[times.size() / 2],
			times[floori((times.size() - 1) * 0.95)], times.back(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _shotless_position(at: Vector3) -> void:
	at.y = valley.surface_height_at(at.x, at.z) + 0.27
	traveler.respawn(at)
	await _ticks(6)
	valley._rain.global_position = traveler.camera.global_position + Vector3.UP * 12.0


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var camera := root.get_camera_3d()
	if image.is_empty() or image.save_png(folder + "/" + name + ".png") != OK:
		failed = true
		push_error("Capture failed: " + name)
	print("%s | camera %s | storm %.3f | High | %dx%d | %d draws | %d triangles" % [
		name, str(camera.global_transform) if camera else "none", valley.storm_strength,
		image.get_width(), image.get_height(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
