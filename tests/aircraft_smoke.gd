extends SceneTree

const AIRCRAFT := preload("res://aircraft.tscn")

var failures := 0
var touch_down := Vector3.INF
var crash_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var departure := Vector3(0, 20, -70)
	var destination := Vector3(0, 26, -225)
	var flight_over_valley := "--valley" in OS.get_cmdline_user_args()
	var aircraft
	var pilot: CharacterBody3D
	var campaign
	if flight_over_valley:
		var game = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		current_scene = game
		campaign = game.get("campaign")
		if not is_instance_valid(campaign):
			_check(false, "production scene initializes campaign")
			quit(1)
			return
		campaign.start_new_game(false)
		departure = campaign.sites.departure
		destination = campaign.sites.observatory
		aircraft = campaign.aircraft
		pilot = game.get_node("Wayfarer")
	else:
		var field := Node3D.new()
		root.add_child(field)
		current_scene = field
		_runway(field, departure - Vector3.UP * 0.5, Vector3(26, 1, 115))
		_runway(field, destination - Vector3.UP * 0.5, Vector3(30, 1, 118))
		aircraft = AIRCRAFT.instantiate()
		field.add_child(aircraft)
		aircraft.configure_spawn(departure + Vector3.BACK * 42.0, 0.0)
		pilot = CharacterBody3D.new()
		field.add_child(pilot)
		var fixture_camera := Camera3D.new()
		pilot.add_child(fixture_camera)
		fixture_camera.make_current()
	var start: Vector3 = aircraft.global_position - Vector3.UP * aircraft.GEAR_HEIGHT
	pilot.global_position = start + Vector3(3, 0.1, 0)
	aircraft.landed.connect(func(at: Vector3): touch_down = at)
	aircraft.crashed.connect(func(): crash_count += 1)
	var observer := root.get_camera_3d()
	await physics_frame

	if flight_over_valley:
		Input.action_press("restore")
		await _ticks(3)
		Input.action_release("restore")
	else:
		aircraft.board(pilot)
	_check(aircraft.is_piloted(), "boarding a stopped aircraft succeeds")
	_check(aircraft.camera.current and not pilot.visible, "boarding selects aircraft camera")
	Input.action_press("flight_engine")
	await _ticks(3)
	Input.action_release("flight_engine")
	_check(aircraft.engine_running, "ignition starts the engine")
	Input.action_press("flight_throttle_up")
	Input.action_press("flight_pitch_up")
	for i in 220:
		if aircraft.speed > 24.0:
			Input.action_release("flight_throttle_up")
			break
		await physics_frame
	_check(not aircraft.is_grounded() and aircraft.global_position.y > start.y + 1.5, "ground roll and elevator achieve takeoff")
	_check(not aircraft.disembark(), "exit is locked in flight")

	var captured := false
	var passed_spire := false
	for i in 260:
		if aircraft.global_position.y < maxf(destination.y + 8.5, departure.y + 11.0):
			_set_action("flight_pitch_up", true)
		else:
			_set_action("flight_pitch_up", false)
		_trim(aircraft, 22.0)
		if flight_over_valley:
			_steer_course(aircraft, destination)
			if aircraft.global_position.z < -163.0 and aircraft.global_position.z > -168.0:
				passed_spire = passed_spire or aircraft.global_position.x > -3.0
		if flight_over_valley and not captured and DisplayServer.get_name() != "headless" and aircraft.global_position.z < departure.z - 26.0:
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			_check(frame.save_png("res://.godot/dark-frontier-flight.png") == OK, "Forward+ flight screenshot saved")
			captured = true
		if aircraft.global_position.z < destination.z + 46.0:
			break
		await physics_frame
	Input.action_release("flight_pitch_up")
	if flight_over_valley:
		_check(passed_spire, "bank controls steer clear of the spire's eastern face")
	_check(aircraft.global_position.z < destination.z + 55.0, "aircraft crosses the gap under player controls")
	_check(aircraft.global_position.y >= destination.y + 3.0, "climb clears destination deck")

	for i in 400:
		if touch_down != Vector3.INF or crash_count > 0:
			break
		_trim(aircraft, 21.0)
		if flight_over_valley:
			_steer_course(aircraft, destination)
		_set_action("flight_pitch_down", aircraft.global_position.y > destination.y + 3.5 or aircraft.velocity.y > -1.8)
		_set_action("flight_pitch_up", aircraft.global_position.y < destination.y + 3.2 and aircraft.velocity.y < -4.0)
		await physics_frame
	_release_controls()
	_check(touch_down != Vector3.INF and absf(touch_down.z - destination.z) < 50.0,
		"safe touchdown occurs on the destination runway at %s" % str(touch_down))
	_check(crash_count == 0, "flight never uses crash reset")
	Input.action_press("flight_brake")
	Input.action_press("flight_throttle_down")
	await _ticks(110)
	_release_controls()
	_check(aircraft.speed < 4.0, "braking reduces taxi speed below the exit limit")
	if flight_over_valley:
		await _interact()
	else:
		aircraft.disembark()
	_check(not aircraft.is_piloted(), "the pilot can disembark")
	_check(observer.current and pilot.visible, "disembarking restores the on-foot camera and character")
	if flight_over_valley and not aircraft.is_piloted():
		_check(campaign.landed_observatory, "campaign recognizes the observatory landing")
		await _find_recorder(pilot, campaign.sites.points["flight_log"])
		_check(campaign.case_file.collected.has("flight_log"), "walking to the observatory and inspecting records flight evidence")
	elif not flight_over_valley:
		_check(aircraft.board(pilot), "parked aircraft can be boarded again")
		var returning_position := pilot.global_position
		aircraft.configure_spawn(start, 0.0)
		_check(not aircraft.is_piloted() and observer.current and pilot.visible,
			"resetting a boarded aircraft restores the pilot and camera")
		_check(pilot.global_position.is_equal_approx(returning_position), "aircraft reset preserves the pilot checkpoint")
	print("Aircraft smoke test finished with %d failures" % failures)
	quit(0 if failures == 0 else 1)


func _steer_course(aircraft, destination: Vector3) -> void:
	var at: Vector3 = aircraft.global_position
	var aim := Vector2(3, -146)
	if at.z < -139.0:
		aim.y = -180.0
	if at.z < -174.0:
		aim = Vector2(destination.x, minf(destination.z - 3.0, at.z - 20.0))
	var desired := atan2(at.x - aim.x, at.z - aim.y)
	var error := angle_difference(aircraft.rotation.y, desired)
	_set_analog("flight_bank_left", clampf(error * 2.0, 0.0, 1.0))
	_set_analog("flight_bank_right", clampf(-error * 2.0, 0.0, 1.0))


func _set_analog(action: StringName, strength: float) -> void:
	if strength > 0.025:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _find_recorder(pilot: CharacterBody3D, target: Vector3) -> void:
	var orbit := pilot.get_node("Orbit") as Node3D
	Input.action_press("move_forward")
	for i in 420:
		var offset := target - pilot.global_position
		if offset.length() < 2.0:
			break
		orbit.rotation.y = atan2(-offset.x, -offset.z)
		await physics_frame
	Input.action_release("move_forward")
	await _interact()


func _interact() -> void:
	Input.action_press("restore")
	await _ticks(3)
	Input.action_release("restore")


func _runway(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var runway := StaticBody3D.new()
	runway.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	runway.add_child(shape)
	parent.add_child(runway)


func _trim(aircraft, target: float) -> void:
	_set_action("flight_throttle_up", aircraft.speed < target - 0.7 and aircraft.throttle < 0.43)
	_set_action("flight_throttle_down", aircraft.speed > target + 0.5 and aircraft.throttle > 0.09)


func _release_controls() -> void:
	for action: StringName in ["flight_throttle_up", "flight_throttle_down", "flight_pitch_up", "flight_pitch_down",
			"flight_brake", "flight_bank_left", "flight_bank_right"]:
		Input.action_release(action)


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


func _ticks(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
