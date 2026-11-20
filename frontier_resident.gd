extends Node3D

var _body := Node3D.new()
var _head := Node3D.new()
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _blend := 0.0
var _phase := 0.0
var _last := Vector3.ZERO


func build(valley: Node3D, coat_tint: Color, skin_tint: Color, build_index: int) -> void:
	add_child(_body)
	_body.add_child(_head)
	_head.position.y = 1.49
	var coat: Material = valley.material(coat_tint)
	var dark: Material = valley.material(coat_tint.darkened(0.58))
	var trim: Material = valley.material(coat_tint.lightened(0.26))
	var face: Material = valley.material(skin_tint)
	var wool: Material = valley.material(Color("#222a2b"))
	var leather: Material = valley.material(Color("#262529"))
	var torso := SurfaceTool.new()
	torso.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector3] = [Vector3(0.26, 0.76, 0.15), Vector3(0.22, 0.99, 0.15),
		Vector3(0.25 + (build_index % 3) * 0.031, 1.32, 0.17), Vector3(0.10, 1.46, 0.09)]
	for ring in rings.size() - 1:
		for i in 12:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
					Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var at: Vector3 = rings[ring + corner.y]
				var angle := (i + corner.x) * TAU / 12.0
				torso.add_vertex(Vector3(cos(angle) * at.x, at.y, sin(angle) * at.z))
	torso.generate_normals()
	valley.place_mesh(_body, torso.commit(), coat, Vector3.ZERO)
	_shape(valley, _head, Vector3(0, 0.147, 0), Vector3(0.235, 0.30, 0.23), face)
	_shape(valley, _head, Vector3(0, 0.089, -0.026), Vector3(0.193, 0.18, 0.211), face)
	_shape(valley, _head, Vector3(0, 0.145, -0.115), Vector3(0.06, 0.086, 0.072), face)
	for side: float in [-1.0, 1.0]:
		_shape(valley, _head, Vector3(side * 0.05, 0.173, -0.104), Vector3(0.035, 0.018, 0.019), wool)
		_shape(valley, _head, Vector3(side * 0.108, 0.143, 0.01), Vector3(0.046, 0.087, 0.039), face)
		var arm := Node3D.new()
		_body.add_child(arm)
		arm.position = Vector3(side * (0.263 + (build_index % 3) * 0.015), 1.31, 0)
		arm.rotation.z = side * 0.10
		_arms.append(arm)
		_shape(valley, arm, Vector3(0, -0.224, 0), Vector3(0.181, 0.52, 0.17), coat)
		_shape(valley, arm, Vector3(0, -0.48, -0.007), Vector3(0.113, 0.155, 0.106), leather)
		var leg := Node3D.new()
		add_child(leg)
		leg.position = Vector3(side * 0.13, 0.80, 0)
		_legs.append(leg)
		_shape(valley, leg, Vector3(0, -0.335, 0), Vector3(0.198, 0.71, 0.205), dark)
		_shape(valley, leg, Vector3(0, -0.69, -0.045), Vector3(0.224, 0.205, 0.322), leather)
		valley.box(_body, Vector3(side * 0.128, 1.13, -0.153), Vector3(0.113, 0.14, 0.033), trim)
	valley.box(_body, Vector3(0, 1.08, -0.169), Vector3(0.023, 0.51, 0.016), trim)
	var hat := build_index % 4
	_shape(valley, _head, Vector3(0, 0.232, 0.019), Vector3(0.261, 0.18, 0.265), trim if hat == 0 else dark)
	match hat:
		0:
			valley.box(_head, Vector3(0, 0.215, -0.11), Vector3(0.225, 0.035, 0.106), dark)
		1:
			_shape(valley, _head, Vector3(0, 0.11, 0.095), Vector3(0.237, 0.29, 0.15), wool)
		2:
			_shape(valley, _head, Vector3(0, 0.094, 0.009), Vector3(0.29, 0.366, 0.31), coat)
			_shape(valley, _head, Vector3(0, 0.15, -0.114), Vector3(0.19, 0.25, 0.085), face)
		3:
			_shape(valley, _head, Vector3(0, 0.079, -0.071), Vector3(0.20, 0.11, 0.11), wool)
	if build_index in [0, 2, 5]:
		valley.box(_body, Vector3(0.19, 0.99, 0.171), Vector3(0.21, 0.38, 0.22), leather)
	scale = Vector3.ONE * (0.935 + (build_index % 5) * 0.027)


func pose(at: Vector3, facing: Vector3, delta: float, talking: bool, working: bool) -> void:
	var movement := at - _last
	movement.y = 0.0
	var walking := delta > 0.0 and movement.length_squared() > 0.00003 and movement.length_squared() < 4.0
	_last = at
	position = at
	var direction := movement if walking else facing - at
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 9.0)) if delta > 0.0 else yaw
	_phase = fposmod(_phase + (movement.length() * 6.8 if walking else delta * 2.8), TAU)
	_blend = move_toward(_blend, float(walking), delta * 8.0)
	var gait := sin(_phase) * _blend
	for i in 2:
		var sign_value := -1.0 if i == 0 else 1.0
		_legs[i].rotation.x = gait * 0.48 * sign_value
		var gesture := 0.64 + sin(_phase) * 0.19 if i == 0 and (talking or working) else 0.0
		_arms[i].rotation.x = -gait * 0.34 * sign_value + gesture * (1.0 - _blend)
	_body.position.y = 0.027 * absf(gait) + sin(_phase) * 0.006
	_head.rotation.y = sin(_phase * 0.75) * (0.13 if talking else 0.28) * (1.0 - _blend)


func _shape(valley: Node3D, parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var part := SphereMesh.new()
	part.radial_segments = 9
	part.rings = 5
	var instance: MeshInstance3D = valley.place_mesh(parent, part, material, at)
	instance.scale = size
