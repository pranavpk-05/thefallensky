extends RefCounted

const HULL_RINGS := [
	Vector3(-2.16, 0.36, 0.36), Vector3(-1.88, 0.53, 0.52),
	Vector3(-1.15, 0.65, 0.62), Vector3(-0.32, 0.62, 0.61),
	Vector3(0.59, 0.51, 0.52), Vector3(1.48, 0.37, 0.35),
	Vector3(2.50, 0.22, 0.21), Vector3(3.20, 0.09, 0.12),
]


static func build(model: Node3D) -> Dictionary:
	var canvas := _finish(Color("#bca46e"), 0.84, 0.02)
	var alloy := _finish(Color("#475856"), 0.43, 0.61)
	var gunmetal := _finish(Color("#253336"), 0.38, 0.67)
	var copper := _finish(Color("#9e643b"), 0.38, 0.52)
	var leather := _finish(Color("#312826"), 0.84, 0.03)
	var timber := _finish(Color("#785343"), 0.54, 0.08)
	var enamel := _finish(Color("#3c6665"), 0.51, 0.28)
	var glass := _finish(Color("#347875"), 0.22, 0.55)
	var tyre := _finish(Color("#202326"), 0.84, 0.0)
	var lantern_red := _glow(Color("#ff5334"))
	var lantern_cyan := _glow(Color("#56ffe1"))
	var lantern_back := _glow(Color("#ffdfa4"))

	_put(model, _fuselage(), alloy, Vector3.ZERO)
	for z: float in [-1.93, -1.72, -1.01]:
		var band := TorusMesh.new()
		band.inner_radius = 0.48 if z < -1.5 else 0.59
		band.outer_radius = band.inner_radius + 0.10
		band.rings = 24
		band.ring_segments = 8
		_put(model, band, copper, Vector3(0, 0, z)).rotation.x = PI * 0.5
	_cylinder(model, Vector3(0, 0, -2.13), Vector3(0, 0, -1.68), 0.52, 0.55, gunmetal)
	for i in 8:
		var angle := i * TAU / 8.0
		var radial := Vector3(sin(angle), cos(angle), 0.0)
		_cylinder(model, radial * 0.21 + Vector3(0, 0, -1.91), radial * 0.53 + Vector3(0, 0, -1.91), 0.083, 0.098, copper)

	var propeller := Node3D.new()
	model.add_child(propeller)
	propeller.position.z = -2.47
	_cylinder(propeller, Vector3(0, 0, 0.21), Vector3(0, 0, -0.12), 0.22, 0.10, alloy)
	for side: float in [-1.0, 1.0]:
		var blade := _put(propeller, _propeller_blade(), timber, Vector3.ZERO)
		if side < 0:
			blade.rotation.z = PI
		_cylinder(propeller, Vector3(0.13 * side, 1.09 * side, 0), Vector3(0.18 * side, 1.19 * side, 0), 0.065, 0.043, copper)

	_ellipsoid(model, Vector3(0.83, 0.66, 1.25), leather, Vector3(0, 0.54, 0.13))
	_ellipsoid(model, Vector3(0.76, 0.44, 0.57), glass, Vector3(0, 0.79, -0.29))
	_ellipsoid(model, Vector3(0.37, 0.38, 0.36), timber, Vector3(0, 0.84, 0.22))
	_ellipsoid(model, Vector3(0.49, 0.26, 0.41), leather, Vector3(0, 0.69, 0.28))
	_cylinder(model, Vector3(0, 0.62, -0.12), Vector3(0, 0.87, -0.10), 0.045, 0.041, gunmetal)

	var wheels: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		_put(model, _wing(side, 4.1, 1.48, false), canvas, Vector3(0, -0.03, -0.22))
		_put(model, _wing(side, 1.40, 0.75, true), enamel, Vector3(0, 0.14, 2.58))
		_cylinder(model, Vector3(side * 0.64, -0.02, -0.94), Vector3(side * 3.9, 0.15, -0.34), 0.033, 0.024, copper)
		for i in 6:
			var span := 0.85 + float(i) * 0.53
			var fraction := span / 4.1
			var z := -0.18 + fraction * fraction * 0.62
			var y := 0.104 + fraction * 0.20
			var rib := _ellipsoid(model, Vector3(0.041, 0.045, 1.33 - fraction * 0.47), timber, Vector3(side * span, y, z))
			rib.rotation.x = 0.018 * side
		_cylinder(model, Vector3(side * 0.34, -0.37, 0.37), Vector3(side * 1.35, -0.66, -0.43), 0.061, 0.046, gunmetal)
		_cylinder(model, Vector3(side * 0.30, -0.37, -0.80), Vector3(side * 1.35, -0.66, -0.43), 0.065, 0.058, copper)
		var wheel := Node3D.new()
		model.add_child(wheel)
		wheel.position = Vector3(side * 1.35, -0.66, -0.43)
		wheels.append(wheel)
		_cylinder(wheel, Vector3(-0.10, 0, 0), Vector3(0.10, 0, 0), 0.315, 0.315, tyre)
		_cylinder(wheel, Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), 0.19, 0.19, copper)
		var strobe := lantern_cyan if side > 0 else lantern_red
		_ellipsoid(model, Vector3(0.17, 0.11, 0.26), strobe, Vector3(side * 4.035, 0.24, 0.42))
		_ellipsoid(model, Vector3(0.10, 0.10, 0.25), enamel, Vector3(side * 3.67, 0.31, 0.42))
		for i in 3:
			_ellipsoid(model, Vector3(0.04, 0.04, 0.04), copper, Vector3(side * 0.52, 0.15, 0.55 + i * 0.25))

	_put(model, _tail_fin(), enamel, Vector3(0, 0.12, 2.43))
	_cylinder(model, Vector3(0, -0.09, 2.67), Vector3(0, -0.51, 2.88), 0.044, 0.034, copper)
	_cylinder(model, Vector3(-0.05, -0.51, 2.88), Vector3(0.05, -0.51, 2.88), 0.135, 0.135, tyre)
	var beacon := _ellipsoid(model, Vector3(0.13, 0.13, 0.17), lantern_back, Vector3(0, 0.19, 3.20))
	return {"propeller": propeller, "wheels": wheels, "beacon": beacon}


static func engine_loop() -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var data := PackedByteArray()
	data.resize(SAMPLE_RATE * 2)
	for i in SAMPLE_RATE:
		var t := float(i) / SAMPLE_RATE
		var firing := sin(TAU * 47.0 * t) * 0.42 + sin(TAU * 94.0 * t) * 0.18
		var resonant := sin(TAU * 141.0 * t + sin(TAU * 47.0 * t) * 0.73) * 0.26
		var grit := sin(TAU * 611.0 * t) * sin(TAU * 47.0 * t) * 0.06
		data.encode_s16(i * 2, roundi(clampf(firing + resonant + grit, -1.0, 1.0) * 22000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = SAMPLE_RATE
	stream.data = data
	return stream


static func _fuselage() -> ArrayMesh:
	const SIDES := 24
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in HULL_RINGS.size() - 1:
		var lower: Vector3 = HULL_RINGS[r]
		var upper: Vector3 = HULL_RINGS[r + 1]
		for i in SIDES:
			var a := float(i) * TAU / SIDES
			var b := float(i + 1) * TAU / SIDES
			_triangle(builder, _hull_vertex(lower, a), _hull_vertex(upper, a), _hull_vertex(lower, b))
			_triangle(builder, _hull_vertex(lower, b), _hull_vertex(upper, a), _hull_vertex(upper, b))
	builder.index()
	builder.generate_normals()
	return builder.commit()


static func _hull_vertex(ring: Vector3, angle: float) -> Vector3:
	return Vector3(cos(angle) * ring.y, sin(angle) * ring.z + maxf(0.0, ring.x) * 0.025, ring.x)


static func _wing(side: float, span: float, chord: float, swept: bool) -> ArrayMesh:
	var loops: Array[PackedVector3Array] = []
	for station: Vector2 in [Vector2(0, 1.0), Vector2(0.21, 1.0), Vector2(0.74, 0.82),
			Vector2(0.94, 0.65), Vector2(1.0, 0.43)]:
		var airfoil := PackedVector3Array()
		var offset := station.x * station.x * (0.74 if not swept else 0.52)
		var lift := station.x * (0.22 if not swept else 0.12)
		for point: Vector2 in [Vector2(-0.48, 0.02), Vector2(-0.27, 0.12), Vector2(0.03, 0.11),
				Vector2(0.52, 0.01), Vector2(0.29, -0.055), Vector2(-0.25, -0.07)]:
			airfoil.append(Vector3(station.x * span * side, lift + point.y * station.y, offset + point.x * station.y * chord))
		loops.append(airfoil)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in loops.size() - 1:
		for i in loops[j].size():
			var next := (i + 1) % loops[j].size()
			_triangle(builder, loops[j][i], loops[j + 1][i], loops[j][next], side < 0.0)
			_triangle(builder, loops[j][next], loops[j + 1][i], loops[j + 1][next], side < 0.0)
	var end := loops[-1]
	for i in range(1, end.size() - 1):
		_triangle(builder, end[0], end[i], end[i + 1], side < 0.0)
	builder.index()
	builder.generate_normals()
	return builder.commit()


static func _tail_fin() -> ArrayMesh:
	var shape := PackedVector2Array([Vector2(-0.62, 0), Vector2(-0.02, 1.13),
		Vector2(0.38, 1.22), Vector2(0.56, 0.98), Vector2(0.69, 0.01)])
	return _extrude(shape, 0.095, true)


static func _propeller_blade() -> ArrayMesh:
	var shape := PackedVector2Array([Vector2(-0.10, 0.09), Vector2(-0.09, 0.72), Vector2(0.02, 1.07),
		Vector2(0.12, 1.20), Vector2(0.22, 1.14), Vector2(0.14, 0.54), Vector2(0.06, 0.10)])
	return _extrude(shape, 0.065, false)


static func _extrude(profile: PackedVector2Array, depth: float, is_fin: bool) -> ArrayMesh:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for point in profile:
		a.append(Vector3(depth, point.y, point.x) if is_fin else Vector3(point.x, point.y, depth))
		b.append(Vector3(-depth, point.y, point.x) if is_fin else Vector3(point.x, point.y, -depth))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, profile.size() - 1):
		_triangle(builder, a[0], a[i], a[i + 1], not is_fin)
		_triangle(builder, b[0], b[i], b[i + 1], is_fin)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		_triangle(builder, a[i], b[i], a[j], not is_fin)
		_triangle(builder, a[j], b[i], b[j], not is_fin)
	builder.generate_normals()
	return builder.commit()


static func _triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, reverse := false) -> void:
	builder.add_vertex(a)
	builder.add_vertex(c if reverse else b)
	builder.add_vertex(b if reverse else c)


static func _ellipsoid(parent: Node3D, size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 7
	var node := _put(parent, sphere, material, at)
	node.scale = size
	return node


static func _put(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node


static func _cylinder(parent: Node3D, tail: Vector3, nose: Vector3, base: float, top: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = base
	mesh.top_radius = top
	mesh.height = tail.distance_to(nose)
	mesh.radial_segments = 14
	mesh.rings = 0
	var part := _put(parent, mesh, material, (tail + nose) * 0.5)
	part.quaternion = Quaternion(Vector3.UP, (nose - tail).normalized())
	return part


static func _finish(tint: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _glow(tint: Color) -> StandardMaterial3D:
	var material := _finish(tint, 0.4, 0.0)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.8
	return material
