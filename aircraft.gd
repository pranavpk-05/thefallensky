extends CharacterBody3D

signal landed(at: Vector3)
signal crashed

const Airframe := preload("res://aircraft_art.gd")
const GEAR_HEIGHT := 0.98
const TAKEOFF_SPEED := 14.0
const STALL_SPEED := 10.0
const CRUISE_SPEED := 44.0
const BRAKE_LIMIT := 4.0
const ACTIONS := {
	"flight_engine": KEY_I,
	"flight_throttle_up": KEY_R,
	"flight_throttle_down": KEY_F,
	"flight_pitch_up": KEY_S,
	"flight_pitch_down": KEY_W,
	"flight_bank_left": KEY_A,
	"flight_bank_right": KEY_D,
	"flight_rudder_left": KEY_Q,
	"flight_rudder_right": KEY_C,
	"flight_brake": KEY_SPACE,
	"flight_camera_reset": KEY_V,
}

var speed := 0.0
var throttle := 0.0
var engine_running := false
var wind_strength := 0.0

var _parked_at := Vector3.ZERO
var _parked_yaw := 0.0
var _pilot: CharacterBody3D
var _pilot_camera: Camera3D
var _pilot_layer := 0
var _grounded := true
var _air_time := 0.0
var _heading := 0.0
var _lift_angle := 0.0
var _bank := 0.0
var _altitude := 0.0
var _propeller: Node3D
var _beacon: MeshInstance3D
var _wheel_nodes: Array[Node3D] = []
var _wind_time := 0.0

@onready var camera: Camera3D = $FlightCamera
@onready var _model: Node3D = $Airframe
@onready var _engine: AudioStreamPlayer3D = $EngineLoop


func _ready() -> void:
	_install_flight_actions()
	var built := Airframe.build(_model)
	_propeller = built.propeller
	_beacon = built.beacon
	_wheel_nodes.assign(built.wheels)
	if DisplayServer.get_name() != "headless":
		_engine.stream = Airframe.engine_loop()
	_parked_at = global_position - Vector3.UP * GEAR_HEIGHT
	_parked_yaw = rotation.y
	_heading = _parked_yaw


func configure_spawn(at: Vector3, yaw: float) -> void:
	if is_piloted():
		_restore_pilot(_pilot.global_position)
	_parked_at = at
	_parked_yaw = yaw
	_reset_flight()


func is_piloted() -> bool:
	return is_instance_valid(_pilot)


func is_grounded() -> bool:
	return _grounded


func altitude() -> float:
	return _altitude


func board(pilot: CharacterBody3D) -> bool:
	if is_piloted() or not _grounded or speed >= BRAKE_LIMIT:
		return false
	if global_position.distance_squared_to(pilot.global_position) > 36.0:
		return false
	_pilot = pilot
	_pilot_camera = pilot.get_viewport().get_camera_3d()
	_pilot_layer = pilot.collision_layer
	pilot.collision_layer = 0
	pilot.velocity = Vector3.ZERO
	pilot.hide()
	pilot.set_physics_process(false)
	pilot.set_process_unhandled_input(false)
	camera.make_current()
	_update_camera(1.0)
	return true


func disembark() -> bool:
	if not is_piloted() or not _grounded or speed >= BRAKE_LIMIT:
		return false
	var side := Basis(Vector3.UP, _heading).x
	var from := global_position + side * 4.5 + Vector3.UP * 2.0
	var surface := _ground_below(from, 10.0)
	if surface.is_empty():
		return false
	_restore_pilot((surface.position as Vector3) + Vector3.UP * 0.12)
	_set_engine(false)
	speed = 0.0
	return true


func _physics_process(delta: float) -> void:
	if not is_piloted():
		return
	_wind_time += delta
	if Input.is_action_just_pressed("flight_engine"):
		_set_engine(not engine_running)
	var power_input := Input.get_axis("flight_throttle_down", "flight_throttle_up")
	if engine_running:
		throttle = clampf(throttle + power_input * delta * 0.8, 0.0, 1.0)
	var pitch := Input.get_axis("flight_pitch_down", "flight_pitch_up")
	var roll := Input.get_axis("flight_bank_left", "flight_bank_right")
	var rudder := Input.get_axis("flight_rudder_left", "flight_rudder_right")
	var braking := Input.is_action_pressed("flight_brake")
	_align_attitude(pitch, roll, rudder, delta)
	var was_grounded := _grounded
	if _grounded:
		_ground_roll(braking, delta)
	else:
		_air_motion(delta)
	var impact := velocity.y
	move_and_slide()
	if is_on_floor():
		_grounded = true
		if not was_grounded and _air_time > 0.24:
			if not _safe_touchdown(impact):
				_crash()
				return
			landed.emit(global_position)
		_air_time = 0.0
	elif was_grounded:
		_grounded = false
	if (is_on_wall() and speed > 8.0) or global_position.y < -12.0:
		_crash()
		return
	var surface := _ground_below(global_position + Vector3.UP * 0.4, 240.0)
	_altitude = maxf(0.0, global_position.y - GEAR_HEIGHT - (surface.position as Vector3).y) if not surface.is_empty() else maxf(0.0, global_position.y)
	var motion_weight := 1.0 - exp(-delta * 8.5)
	if Input.is_action_just_pressed("flight_camera_reset"):
		motion_weight = 1.0
	_update_camera(motion_weight)
	_animate(delta)


func _align_attitude(pitch: float, roll: float, rudder: float, delta: float) -> void:
	var pitch_limit := 0.19 if _grounded else 0.37
	_lift_angle = move_toward(_lift_angle, pitch * pitch_limit, delta * 1.45)
	_bank = move_toward(_bank, 0.0 if _grounded else -roll * 0.72, delta * 2.1)
	if _grounded:
		_heading -= clampf(roll + rudder, -1.0, 1.0) * 0.92 * smoothstep(0.2, 7.0, speed) * delta
	else:
		_heading += (_bank * 0.96 - rudder * 0.48) * delta
	rotation.y = _heading
	_model.rotation = Vector3(_lift_angle, 0.0, _bank)


func _ground_roll(braking: bool, delta: float) -> void:
	var thrust := throttle * 11.5
	var drag := 0.5 + speed * speed * 0.005
	speed = clampf(speed + (thrust - drag - (17.0 if braking else 0.0)) * delta, 0.0, CRUISE_SPEED)
	var forward := -global_basis.z
	velocity = forward * speed + Vector3.DOWN * 3.5
	floor_snap_length = 0.25
	if speed >= TAKEOFF_SPEED and _lift_angle >= 0.115 and not braking:
		floor_snap_length = 0.0
		_grounded = false
		_air_time = 0.0
		velocity.y = 3.3


func _air_motion(delta: float) -> void:
	_air_time += delta
	floor_snap_length = 0.0
	var thrust := throttle * 8.7
	var drag := 0.4 + speed * speed * 0.0045
	speed = clampf(speed + (thrust - drag - sin(_lift_angle) * 4.6) * delta, 2.5, CRUISE_SPEED)
	var airflow := smoothstep(STALL_SPEED - 3.0, TAKEOFF_SPEED + 1.0, speed)
	var lift := 9.8 * airflow * cos(_bank)
	var climb_target := sin(_lift_angle) * speed * 0.91
	var pitch_force := clampf((climb_target - velocity.y) * 2.7, -10.0, 9.0) * airflow
	var wind := sin(_wind_time * 1.9) * wind_strength
	var vertical_speed := clampf(velocity.y + (lift - 9.8 + pitch_force + wind * 1.2) * delta, -24.0, 17.0)
	velocity = -global_basis.z * speed + global_basis.x * wind * 1.4
	velocity.y = vertical_speed


func _safe_touchdown(impact: float) -> bool:
	return impact > -8.2 and speed < 30.0 and absf(_bank) < 0.43 and _lift_angle > -0.29


func _ground_below(from: Vector3, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * depth)
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_ray(query)


func _update_camera(weight: float) -> void:
	var forward := -global_basis.z
	var focus := global_position + Vector3.UP * 0.9 + forward * 3.7
	var chase := global_position - forward * (9.2 + speed * 0.067) + Vector3.UP * 4.6
	var query := PhysicsRayQueryParameters3D.create(focus, chase)
	query.collision_mask = collision_mask
	var blocked := get_world_3d().direct_space_state.intersect_ray(query)
	if not blocked.is_empty():
		chase = (blocked.position as Vector3).move_toward(focus, 0.28)
	camera.global_position = camera.global_position.lerp(chase, weight)
	camera.look_at(focus, Vector3.UP.rotated(forward, _bank * 0.18))
	camera.fov = lerpf(camera.fov, 65.0 + speed * 0.27, weight * 0.55)


func _animate(delta: float) -> void:
	var rpm := 27.0 + throttle * 99.0 if engine_running else speed * 2.2
	_propeller.rotate_z(rpm * delta)
	_beacon.visible = not engine_running or fmod(_wind_time, 1.45) < 0.24
	if _grounded:
		for wheel in _wheel_nodes:
			wheel.rotate_x(-speed * delta * 2.9)
	if _engine.playing:
		_engine.pitch_scale = 0.79 + throttle * 0.52
		_engine.volume_db = -28.0 + throttle * 8.0


func _set_engine(running: bool) -> void:
	engine_running = running
	throttle = 0.38 if running else 0.0
	if running and _engine.stream != null:
		_engine.play()
	else:
		_engine.stop()


func _crash() -> void:
	_reset_flight()
	_restore_pilot(_parked_at + Basis(Vector3.UP, _parked_yaw).x * 4.5 + Vector3.UP * 0.2)
	crashed.emit()


func _reset_flight() -> void:
	global_position = _parked_at + Vector3.UP * GEAR_HEIGHT
	_heading = _parked_yaw
	rotation.y = _heading
	_model.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	speed = 0.0
	_altitude = 0.0
	_bank = 0.0
	_lift_angle = 0.0
	_grounded = true
	_air_time = 0.0
	_beacon.show()
	_set_engine(false)
	reset_physics_interpolation()


func _restore_pilot(at: Vector3) -> void:
	if not is_piloted():
		return
	if _pilot.has_method("respawn"):
		_pilot.call("respawn", at)
	else:
		_pilot.global_position = at
		_pilot.velocity = Vector3.ZERO
		_pilot.reset_physics_interpolation()
	_pilot.collision_layer = _pilot_layer
	_pilot.show()
	_pilot.set_physics_process(true)
	_pilot.set_process_unhandled_input(true)
	if is_instance_valid(_pilot_camera):
		_pilot_camera.make_current()
	else:
		camera.clear_current()
	_pilot = null
	_pilot_camera = null


func _install_flight_actions() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = ACTIONS[action]
			InputMap.action_add_event(action, event)
