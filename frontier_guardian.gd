extends CharacterBody3D

signal struck
signal alert_changed(state: int)

const QUIET := 0
const SUSPICIOUS := 1
const HUNTING := 2

var pilot
var origin: Vector3
var enabled := false
var awareness := 0.0
var state := QUIET
var stun_time := 0.0
var cooloff := 0.0
var gait := 0.0
var last_seen := Vector3.ZERO
var frame: Node3D
var eye: StandardMaterial3D
var limbs: Array[Node3D] = []


func setup(target: CharacterBody3D, at: Vector3) -> void:
	pilot = target
	origin = at
	last_seen = at
	global_position = at + Vector3.UP * 0.25
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.48
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.43
	collision.shape = capsule
	add_child(collision)
	collision.position.y = 0.9
	_build_sentinel()


func repel() -> void:
	stun_time = 8.0
	awareness = 0.0


func reset_guard() -> void:
	global_position = origin + Vector3.UP * 0.25
	velocity = Vector3.ZERO
	last_seen = origin
	repel()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var target: Vector3 = pilot.global_position
	var gap := global_position.distance_to(target)
	var see := false
	stun_time = maxf(0.0, stun_time - delta)
	cooloff = maxf(0.0, cooloff - delta)
	if stun_time <= 0.0 and pilot.visible and target.distance_to(origin) < 43.0:
		var reach := 8.0 if pilot.crouching else (23.0 if state == HUNTING else 17.0)
		if gap < reach:
			var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.32,
				target + Vector3.UP * (0.6 if pilot.crouching else 1.05), 1, [get_rid()])
			see = get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	if see:
		last_seen = target
		awareness = minf(1.0, awareness + delta * (0.90 if gap < 6.0 else 0.50))
	else:
		awareness = maxf(0.0, awareness - delta * 0.29)
	var next := QUIET
	if awareness >= 0.96 or (state == HUNTING and awareness > 0.37):
		next = HUNTING
	elif awareness > 0.19:
		next = SUSPICIOUS
	if next != state:
		state = next
		alert_changed.emit(state)
		eye.emission = Color("#ff685b") if state == HUNTING else (Color("#ffd187") if state == SUSPICIOUS else Color("#61dbd3"))
	var destination := last_seen
	if state == QUIET:
		gait += delta * 0.26
		destination = origin + Vector3(cos(gait) * 3.6, 0, sin(gait) * 3.6)
	var direction := destination - global_position
	direction.y = 0.0
	var pace := 6.8 if state == HUNTING else (2.5 if state == SUSPICIOUS else 1.46)
	var desired := direction.normalized() * pace if direction.length_squared() > 0.75 and stun_time <= 0.0 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, delta * 16.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 16.0)
	velocity.y -= delta * 18.0
	move_and_slide()
	if desired.length_squared() > 0.1:
		frame.rotation.y = lerp_angle(frame.rotation.y, atan2(-desired.x, -desired.z), delta * 7.0)
		var swing := sin(Time.get_ticks_msec() * 0.008 * clampf(pace * 0.32, 0.7, 2.0)) * 0.34
		for i in limbs.size():
			limbs[i].rotation.x = swing * (-1 if i % 2 == 0 else 1)
	if state == HUNTING and see and gap < 1.9 and cooloff <= 0.0:
		cooloff = 1.22
		struck.emit()
	if global_position.y < -1.0:
		reset_guard()


func _build_sentinel() -> void:
	frame = Node3D.new()
	add_child(frame)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#313944")
	stone.roughness = 0.91
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("#747264")
	bronze.metallic = 0.35
	eye = StandardMaterial3D.new()
	eye.albedo_color = Color("#4ce1da")
	eye.emission_enabled = true
	eye.emission = eye.albedo_color
	eye.emission_energy_multiplier = 2.9
	_plate(frame, Vector3(0, 1.06, 0), Vector3(0.85, 1.0, 0.56), stone)
	_plate(frame, Vector3(0, 1.78, -0.10), Vector3(0.51, 0.57, 0.43), bronze)
	_plate(frame, Vector3(0, 1.78, -0.31), Vector3(0.35, 0.105, 0.07), eye)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		frame.add_child(leg)
		leg.position = Vector3(side * 0.27, 0.84, 0)
		_plate(leg, Vector3(0, -0.41, 0), Vector3(0.36, 0.85, 0.30), stone)
		limbs.append(leg)
		var arm := Node3D.new()
		frame.add_child(arm)
		arm.position = Vector3(side * 0.55, 1.37, 0)
		_plate(arm, Vector3(side * 0.07, -0.28, 0), Vector3(0.29, 0.88, 0.39), stone)
		_plate(arm, Vector3(0, 0.02, -0.02), Vector3(0.38, 0.37, 0.43), bronze)


func _plate(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 6
	shape.rings = 3
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.scale = size
	part.material_override = material
	parent.add_child(part)
	part.position = at
