extends CharacterBody3D

const RUN_SPEED := 9.0
const GLIDE_SPEED := 24.0

var gliding := false
var launched := false
var flight_time := 0.0
var stride := 0.0
var canopy: Node3D
var mantle: MeshInstance3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var sail_amount := 0.0
var survival_enabled := false
var stamina := 100.0
var crouching := false
var sprinting := false
var in_shelter := false
var _conversation_target := Vector3.ZERO
var _conversation_time := 0.0

@onready var figure: Node3D = $Figure
@onready var orbit: Node3D = $Orbit
@onready var pitch: Node3D = $Orbit/Pitch
@onready var camera: Camera3D = $Orbit/Pitch/Boom/Camera3D
@onready var boom: SpringArm3D = $Orbit/Pitch/Boom


func _ready() -> void:
	$Orbit/Pitch/Boom.add_excluded_object(get_rid())
	_build_figure()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not survival_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_conversation_time = 0.0
		orbit.rotation.y -= event.relative.x * 0.0026
		pitch.rotation.x = clampf(pitch.rotation.x - event.relative.y * 0.0026, -1.1, 0.6)


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := orbit.basis * Vector3(input.x, 0, input.y)
	if input.length_squared() > 0.05 or Input.is_action_pressed("jump"):
		_conversation_time = 0.0
	_conversation_time = maxf(0.0, _conversation_time - delta)
	var conversing := _conversation_time > 0.0 and grounded
	if conversing:
		var focus := _conversation_target - orbit.global_position
		var blend := 1.0 - exp(-delta * 4.0)
		if focus.length_squared() > 0.5:
			var heading := atan2(-focus.x, -focus.z)
			orbit.rotation.y = lerp_angle(orbit.rotation.y, heading, blend)
			figure.rotation.y = lerp_angle(figure.rotation.y, heading, blend)
		pitch.rotation.x = lerpf(pitch.rotation.x, -0.12, blend)
	crouching = survival_enabled and grounded and Input.is_action_pressed("crouch")
	sprinting = survival_enabled and grounded and not crouching and stamina > 8.0 and input.length_squared() > 0.2 and Input.is_action_pressed("sprint")
	var run_speed := 3.65 if crouching else (12.6 if sprinting else RUN_SPEED)
	if survival_enabled:
		var stamina_rate := -19.0 if sprinting else (15.0 if grounded else 6.0)
		stamina = clampf(stamina + stamina_rate * delta, 0.0, 100.0)
	if grounded:
		if velocity.y <= 0.0:
			launched = false
		flight_time = 0.0
	else:
		flight_time += delta
	gliding = not grounded and flight_time > 0.14 and Input.is_action_pressed("jump") and velocity.y < 9.0
	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y = 8.8
	elif gliding:
		velocity.y = move_toward(velocity.y, -3.0, delta * 25.0)
	elif not grounded:
		velocity.y = maxf(velocity.y - delta * 22.0, -42.0)

	var target := direction * run_speed
	if gliding:
		var heading := direction.normalized() if direction.length_squared() > 0.05 else -orbit.basis.z
		target = heading * GLIDE_SPEED
	elif launched and not grounded:
		target = Vector3(velocity.x, 0.0, velocity.z).lerp(direction * RUN_SPEED, 0.35)
	var acceleration := 11.0 if gliding else (42.0 if grounded else 16.0)
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()

	var lateral := Vector2(velocity.x, velocity.z)
	if lateral.length_squared() > 0.7:
		figure.rotation.y = lerp_angle(figure.rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-delta * 10.0))
	var openness := 1.0 if gliding else 0.0
	sail_amount = move_toward(sail_amount, openness, delta * 4.5)
	canopy.visible = sail_amount > 0.02
	canopy.scale = Vector3(maxf(0.02, sail_amount), 0.55 + sail_amount * 0.45, 0.7 + sail_amount * 0.3)
	canopy.rotation.z = lerpf(canopy.rotation.z, -input.x * 0.24, delta * 6.0)
	mantle.rotation.x = lerpf(mantle.rotation.x, -sail_amount * 0.77 + sin(stride * 0.7) * 0.10, delta * 7.0)
	figure.scale.y = lerpf(figure.scale.y, 0.71 if crouching else 1.0, delta * 12.0)
	var camera_height := 1.42 if in_shelter else 2.02
	orbit.position.y = lerpf(orbit.position.y, 1.05 if crouching else camera_height, delta * 9.0)
	var boom_length := 2.85 if conversing else (2.35 if in_shelter else 5.8)
	boom.spring_length = lerpf(boom.spring_length, boom_length, delta * 9.0)
	# The camera can be pushed through the coat by walls in the narrow shelter.
	var view_distance := boom.get_hit_length()
	figure.visible = view_distance > (0.96 if figure.visible else 1.16)
	camera.fov = lerpf(camera.fov, 61.0 if conversing else (77.0 if gliding else 68.0), delta * 3.5)
	camera.h_offset = lerpf(camera.h_offset, 0.56 if conversing else 0.0, delta * 7.0)
	stride += lateral.length() * delta * 1.35
	var swing := sin(stride) * minf(lateral.length() * 0.075, 0.7) if is_on_floor() else -0.18
	for side in 2:
		var phase := 1.0 if side == 0 else -1.0
		legs[side].rotation.x = lerpf(legs[side].rotation.x, phase * swing, delta * 13.0)
		arms[side].rotation.x = lerpf(arms[side].rotation.x, -phase * swing, delta * 11.0)
		arms[side].rotation.z = phase * lerpf(0.14, 1.32, sail_amount)


func focus_conversation(at: Vector3) -> void:
	_conversation_target = at
	_conversation_time = 4.8


func respawn(at: Vector3) -> void:
	_conversation_time = 0.0
	global_position = at
	velocity = Vector3.ZERO
	orbit.rotation.y = 0.0
	pitch.rotation.x = -0.16
	figure.rotation.y = 0.0
	launched = false
	gliding = false
	flight_time = 0.0
	sail_amount = 0.0
	crouching = false
	sprinting = false
	in_shelter = false
	reset_physics_interpolation()


func ride_updraft() -> void:
	launched = true
	velocity.y = 40.0
	velocity.z = -11.0
	global_position.y += 0.12


func _build_figure() -> void:
	var leather := _material(Color("#44352f"))
	var boot := _material(Color("#28262a"))
	var brass := _material(Color("#b99362"))
	brass.metallic = 0.68
	var wool := _material(Color("#283c45"))
	var hood := _material(Color("#794637"))
	var lining := _material(Color("#242529"))
	var gloves := _material(Color("#755744"))
	var cyan := _material(Color("#47edd9"))
	cyan.emission_enabled = true
	cyan.emission = cyan.albedo_color
	cyan.emission_energy_multiplier = 1.8
	_loft(figure, Vector3.ZERO, [
		Vector4(0.79, 0.18, 0.12, 0.0), Vector4(0.88, 0.26, 0.17, 0.0),
		Vector4(1.08, 0.24, 0.17, 0.0), Vector4(1.36, 0.30, 0.19, 0.01),
		Vector4(1.51, 0.27, 0.16, 0.01), Vector4(1.58, 0.12, 0.12, -0.01)
	], wool)
	_loft(figure, Vector3(0, 1.48, 0), [
		Vector4(0.0, 0.15, 0.15, 0.0), Vector4(0.13, 0.183, 0.22, -0.005),
		Vector4(0.30, 0.178, 0.212, 0.015), Vector4(0.40, 0.116, 0.135, 0.058),
		Vector4(0.45, 0.035, 0.065, 0.082), Vector4(0.46, 0.001, 0.001, 0.08)
	], hood)
	_loft(figure, Vector3(0, 1.56, -0.175), [
		Vector4(0, 0.091, 0.04, 0), Vector4(0.07, 0.124, 0.061, 0),
		Vector4(0.212, 0.10, 0.045, 0), Vector4(0.226, 0.021, 0.016, 0)
	], lining)
	_loft(figure, Vector3.ZERO, [
		Vector4(0.97, 0.252, 0.178, 0), Vector4(1.056, 0.254, 0.18, 0)
	], leather)
	_plaque(figure, Vector3(0, 1.013, -0.179), Vector3(0.105, 0.069, 0.046), brass)
	mantle = _make_mantle()
	_loft(figure, Vector3(0, 1.12, 0.213), [
		Vector4(0, 0.13, 0.06, 0), Vector4(0.07, 0.183, 0.112, 0),
		Vector4(0.32, 0.179, 0.115, 0), Vector4(0.39, 0.13, 0.08, -0.02),
		Vector4(0.415, 0.03, 0.02, -0.024)
	], leather)
	_plaque(figure, Vector3(0, 1.39, 0.327), Vector3(0.105, 0.153, 0.032), brass).rotation.z = 0.22
	_plaque(figure, Vector3(0, 1.39, 0.348), Vector3(0.064, 0.108, 0.023), cyan).rotation.z = 0.22
	for sign_x: float in [-1.0, 1.0]:
		_plaque(figure, Vector3(sign_x * 0.114, 1.31, 0.321), Vector3(0.045, 0.246, 0.027), brass).rotation.z = sign_x * 0.16
		_plaque(figure, Vector3(sign_x * 0.248, 0.98, 0.095), Vector3(0.13, 0.19, 0.167), leather).rotation.z = sign_x * 0.12
		var hip := Node3D.new()
		figure.add_child(hip)
		hip.position = Vector3(sign_x * 0.16, 0.85, 0)
		legs.append(hip)
		_loft(hip, Vector3.ZERO, [
			Vector4(-0.55, 0.085, 0.086, 0.01), Vector4(-0.35, 0.113, 0.112, -0.027),
			Vector4(-0.12, 0.128, 0.137, 0.0), Vector4(0.055, 0.126, 0.138, 0.0)
		], wool)
		_loft(hip, Vector3.ZERO, [
			Vector4(-0.83, 0.083, 0.155, -0.049), Vector4(-0.80, 0.108, 0.182, -0.065),
			Vector4(-0.72, 0.107, 0.171, -0.060), Vector4(-0.65, 0.084, 0.102, -0.01),
			Vector4(-0.41, 0.098, 0.104, 0.009), Vector4(-0.37, 0.101, 0.105, 0.009)
		], boot)
		_plaque(hip, Vector3(0, -0.47, -0.082), Vector3(0.12, 0.042, 0.025), brass)
		var shoulder := Node3D.new()
		figure.add_child(shoulder)
		shoulder.position = Vector3(sign_x * 0.31, 1.44, 0)
		arms.append(shoulder)
		_loft(shoulder, Vector3.ZERO, [
			Vector4(-0.46, 0.064, 0.066, 0.0), Vector4(-0.25, 0.084, 0.090, 0.019),
			Vector4(-0.06, 0.118, 0.122, 0), Vector4(0.041, 0.092, 0.105, 0)
		], hood)
		_loft(shoulder, Vector3.ZERO, [
			Vector4(-0.618, 0.034, 0.06, -0.016), Vector4(-0.56, 0.067, 0.069, -0.02),
			Vector4(-0.39, 0.067, 0.075, 0.009)
		], gloves)
		_plaque(shoulder, Vector3(sign_x * 0.067, -0.41, 0), Vector3(0.03, 0.087, 0.11), brass)

	canopy = Node3D.new()
	figure.add_child(canopy)
	canopy.position = Vector3(0, 1.8, 0)
	canopy.visible = false
	var sail := ShaderMaterial.new()
	sail.shader = preload("res://wayfarer_cloth.gdshader")
	sail.set_shader_parameter("sail", true)
	var canvas := SurfaceTool.new()
	canvas.begin(Mesh.PRIMITIVE_TRIANGLES)
	var keel := Vector3(0, 0.93, -0.93)
	var tail := Vector3(0, 0.35, 1.45)
	for sign_x: float in [-1.0, 1.0]:
		var edge := Vector3(sign_x * 1.22, 0.81, -0.58)
		var tip := Vector3(sign_x * 2.60, 0.17, 0.86)
		var fold := Vector3(sign_x * 0.94, 0.58, 1.10)
		for vertex: Vector3 in [keel, edge, fold, edge, tip, fold, keel, fold, tail]:
			canvas.set_uv(Vector2(vertex.x / 5.20 + 0.5, (vertex.z + 0.93) / 2.38))
			canvas.add_vertex(vertex)
		_spar(keel, edge, brass)
		_spar(edge, tip, brass)
		_spar(tip, fold, brass)
		_spar(fold, tail, brass)
		_spar(keel, fold, cyan)
		_spar(fold, Vector3(sign_x * 0.53, -0.05, 0), brass)
	canvas.generate_normals()
	var wing := MeshInstance3D.new()
	wing.mesh = canvas.commit()
	wing.material_override = sail
	canopy.add_child(wing)


func _make_mantle() -> MeshInstance3D:
	var panels := SurfaceTool.new()
	panels.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 7:
		for column in 10:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
					Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(column + corner.x) / 10.0
				var down := float(row + corner.y) / 7.0
				var edge := u * 2.0 - 1.0
				var width := 0.271 + 0.108 * down
				var folds := cos(u * 19.0) * (down * 0.027 + 0.016)
				var split := smoothstep(0.65, 1.0, down) * (1.0 - absf(edge)) * 0.12
				panels.set_uv(Vector2(u, down))
				panels.add_vertex(Vector3(edge * width, -down * 0.97 + split,
					sin(down * 1.4) * 0.31 - edge * edge * 0.096 + folds))
	panels.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = panels.commit()
	var fabric := ShaderMaterial.new()
	fabric.shader = preload("res://wayfarer_cloth.gdshader")
	mesh.material_override = fabric
	figure.add_child(mesh)
	mesh.position = Vector3(0, 1.51, 0.171)
	return mesh


func _spar(from: Vector3, to: Vector3, material: Material) -> void:
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.035
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	rod.mesh = mesh
	rod.material_override = material
	canopy.add_child(rod)
	rod.position = (from + to) * 0.5
	rod.quaternion = Quaternion(Vector3.UP, (to - from).normalized())


func _loft(parent: Node3D, at: Vector3, rings: Array[Vector4], material: Material) -> void:
	const SIDES := 10
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rings.size() - 1:
		for side in SIDES:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
					Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var phase := float(side + corner.x) * TAU / SIDES
				var ring := rings[row + corner.y]
				surface.add_vertex(Vector3(cos(phase) * ring.y, ring.x, sin(phase) * ring.z + ring.w))
	surface.index()
	surface.generate_normals()
	var part := MeshInstance3D.new()
	part.mesh = surface.commit()
	part.material_override = material
	parent.add_child(part)
	part.position = at


func _plaque(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	part.position = at
	return part


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
