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

@onready var figure: Node3D = $Figure
@onready var orbit: Node3D = $Orbit
@onready var pitch: Node3D = $Orbit/Pitch
@onready var camera: Camera3D = $Orbit/Pitch/Boom/Camera3D


func _ready() -> void:
	$Orbit/Pitch/Boom.add_excluded_object(get_rid())
	_build_figure()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		orbit.rotation.y -= event.relative.x * 0.0026
		pitch.rotation.x = clampf(pitch.rotation.x - event.relative.y * 0.0026, -1.1, 0.6)


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := orbit.basis * Vector3(input.x, 0, input.y)
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

	var target := direction * RUN_SPEED
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
	camera.fov = lerpf(camera.fov, 77.0 if gliding else 68.0, delta * 3.5)
	stride += lateral.length() * delta * 1.35
	var swing := sin(stride) * minf(lateral.length() * 0.075, 0.7) if is_on_floor() else -0.18
	for side in 2:
		var phase := 1.0 if side == 0 else -1.0
		legs[side].rotation.x = lerpf(legs[side].rotation.x, phase * swing, delta * 13.0)
		arms[side].rotation.x = lerpf(arms[side].rotation.x, -phase * swing, delta * 11.0)
		arms[side].rotation.z = phase * lerpf(0.14, 1.32, sail_amount)


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	orbit.rotation.y = 0.0
	pitch.rotation.x = -0.16
	figure.rotation.y = 0.0
	launched = false
	gliding = false
	flight_time = 0.0
	sail_amount = 0.0
	reset_physics_interpolation()


func ride_updraft() -> void:
	launched = true
	velocity.y = 40.0
	velocity.z = -11.0
	global_position.y += 0.12


func _build_figure() -> void:
	var leather := _material(Color("#24333e"))
	var gold := _material(Color("#bb8b4d"))
	var cloth := _material(Color("#a44536"))
	var hood := _material(Color("#dfb880"))
	var cyan := _material(Color("#47edd9"))
	cyan.emission_enabled = true
	cyan.emission = cyan.albedo_color
	cyan.emission_energy_multiplier = 1.8
	_piece(figure, Vector3(0, 1.20, 0), Vector3(0.59, 0.73, 0.37), leather)
	_piece(figure, Vector3(0, 1.68, -0.04), Vector3(0.39, 0.42, 0.38), hood)
	_piece(figure, Vector3(0, 1.64, -0.18), Vector3(0.28, 0.23, 0.15), leather)
	_piece(figure, Vector3(0, 1.01, 0), Vector3(0.61, 0.13, 0.40), gold)
	mantle = _make_mantle(cloth)
	_piece(figure, Vector3(0, 1.29, 0.20), Vector3(0.31, 0.38, 0.23), leather)
	_piece(figure, Vector3(0, 1.32, 0.31), Vector3(0.12, 0.19, 0.07), cyan)
	for sign_x: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		figure.add_child(hip)
		hip.position = Vector3(sign_x * 0.16, 0.85, 0)
		legs.append(hip)
		_piece(hip, Vector3(0, -0.32, 0), Vector3(0.25, 0.72, 0.26), leather)
		_piece(hip, Vector3(0, -0.70, -0.06), Vector3(0.235, 0.24, 0.39), gold)
		var shoulder := Node3D.new()
		figure.add_child(shoulder)
		shoulder.position = Vector3(sign_x * 0.31, 1.44, 0)
		arms.append(shoulder)
		_piece(shoulder, Vector3(0, -0.27, 0), Vector3(0.20, 0.61, 0.23), cloth)
		_piece(shoulder, Vector3(0, -0.52, 0), Vector3(0.17, 0.22, 0.18), gold)

	canopy = Node3D.new()
	figure.add_child(canopy)
	canopy.position = Vector3(0, 1.8, 0)
	canopy.visible = false
	var sail := _material(Color("#e0ac56"))
	sail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canvas := SurfaceTool.new()
	canvas.begin(Mesh.PRIMITIVE_TRIANGLES)
	var keel := Vector3(0, 0.93, -0.93)
	var tail := Vector3(0, 0.35, 1.45)
	for sign_x: float in [-1.0, 1.0]:
		var edge := Vector3(sign_x * 1.45, 0.78, -0.55)
		var tip := Vector3(sign_x * 3.05, 0.16, 0.88)
		var fold := Vector3(sign_x * 1.10, 0.56, 0.90)
		for vertex: Vector3 in [keel, edge, fold, edge, tip, fold, keel, fold, tail]:
			canvas.add_vertex(vertex)
		_spar(keel, edge, gold)
		_spar(edge, tip, gold)
		_spar(tip, fold, gold)
		_spar(keel, fold, cyan)
		_spar(fold, Vector3(sign_x * 0.53, -0.05, 0), gold)
	canvas.generate_normals()
	var wing := MeshInstance3D.new()
	wing.mesh = canvas.commit()
	wing.material_override = sail
	canopy.add_child(wing)


func _make_mantle(cloth: StandardMaterial3D) -> MeshInstance3D:
	var panels := SurfaceTool.new()
	panels.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := Vector3(-0.27, 0.0, 0.0)
	var right := Vector3(0.27, 0.0, 0.0)
	var ridge := Vector3(0, -0.38, 0.14)
	var hem_left := Vector3(-0.33, -0.69, 0.24)
	var hem_right := Vector3(0.28, -0.77, 0.26)
	for point: Vector3 in [left, right, ridge, left, ridge, hem_left,
			right, hem_right, ridge, ridge, hem_right, hem_left]:
		panels.add_vertex(point)
	panels.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = panels.commit()
	var fabric := cloth.duplicate() as StandardMaterial3D
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = fabric
	figure.add_child(mesh)
	mesh.position = Vector3(0, 1.51, 0.16)
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


func _piece(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	part.mesh = mesh
	part.material_override = material
	part.scale = size
	parent.add_child(part)
	part.position = at


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
