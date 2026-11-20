extends SceneTree

const OUT := "res://.godot"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual evidence requires a Forward+ window.")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--1080p") else Vector2i(1280, 720)
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	var traveler = scene.get_node("Wayfarer")
	var valley = scene.get_node("Valley")
	scene.campaign.start_new_game(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await _physics_ticks(85)
	await _capture("frontier-01-overlook")
	Input.action_press("move_forward")
	await _physics_ticks(40)
	Input.action_press("jump")
	await _physics_ticks(29)
	await _capture("frontier-02-glide")
	Input.action_release("jump")
	Input.action_release("move_forward")

	for id in ["journal", "radio", "tracks"]:
		scene.campaign._collect(id)
	var relay: Vector3 = scene.campaign.sites.points["relay"]
	var entry := Vector3(-44.6, valley.height_at(-44.6, -63.8) + 0.27, -63.8)
	traveler.respawn(entry)
	traveler.orbit.rotation.y = atan2(entry.x - relay.x, entry.z - relay.z)
	traveler.figure.rotation.y = traveler.orbit.rotation.y
	traveler.pitch.rotation.x = 0.12
	await _physics_ticks(28)
	await _capture("frontier-03-forest")

	valley._world_time = 260.0
	traveler.respawn(valley.HANGING_COURT + Vector3(0, 0.5, 2.0))
	await _physics_ticks(65)
	await _capture("frontier-04-moonrise")
	quit(1 if failed else 0)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Empty viewport: " + name)
		failed = true
		return
	var path := "%s/%s.png" % [OUT, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save screenshot: " + path)
		failed = true
	print("%s | %s | %dx%d | %d draws | %d primitives | %d FPS" % [path,
		RenderingServer.get_current_rendering_method(), image.get_width(), image.get_height(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Engine.get_frames_per_second()])


func _physics_ticks(count: int) -> void:
	for i in count:
		await physics_frame
