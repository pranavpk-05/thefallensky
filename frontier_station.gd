extends Node3D

var valley
var door_points: Dictionary[String, Vector3] = {}
var doors: Dictionary[String, Node3D] = {}
var _wood: ShaderMaterial
var _roof: ShaderMaterial
var _concrete: ShaderMaterial
var _iron: Material
var _warm: StandardMaterial3D
var _red: StandardMaterial3D
var _lights: Array[Light3D] = []
var _door_tweens: Dictionary[String, Tween] = {}
var _intake_gate: Node3D
var _closed_gate_y := 0.0


func build(terrain: Node3D, intake: Vector3) -> void:
	valley = terrain
	_wood = _finish(Color("#56463c"), Color("#232829"), 0.0, 4.0)
	_roof = _finish(Color("#544946"), Color("#2d353c"), 0.54, 1.0)
	_concrete = _finish(Color("#515554"), Color("#2a3433"), 0.0, 1.0)
	_iron = valley.material(Color("#343b3a"))
	_warm = _emissive(Color("#ffb467"), 1.8)
	_red = _emissive(Color("#eb674a"), 1.8)
	_cabin("weather_door", "WEATHER STATION 07", _ground(8.1, 7.5), Vector2(4.8, 4.1), true)
	_cabin("bunk_door", "EXPEDITION BUNKHOUSE", _ground(12.1, 11.1), Vector2(2.75, 3.22), false)
	_cabin("relay_door", "WINDGATE PUMP HOUSE", _ground(-8.3, -64.8), Vector2(4.1, 3.6), true)
	_cabin("store_door", "RIVER WORKS STORES", _ground(-2.4, -60.8), Vector2(3.45, 3.2), false)
	_tower(_ground(6.1, 0.8))
	_tower(_ground(-5.5, -65.5))
	_utility_line(Vector2(4.1, 5.5), Vector2(5.4, -5.3))
	_utility_line(Vector2(-8.25, -49.1), Vector2(-9.35, -63.4))
	_intake(intake)
	_forest_edge()


func set_live(active: bool) -> void:
	# Title framing uses the same structures without enabling interaction.
	for child in get_children():
		if child is StaticBody3D:
			child.collision_layer = 1 if active else 0
	for leaf in doors.values():
		leaf.get_node("Barrier").collision_layer = 1 if active and not leaf.get_meta("open", false) else 0


func update_weather(storm: float, quality: int) -> void:
	for finish in [_wood, _roof, _concrete]:
		finish.set_shader_parameter("wetness", storm)
	for source in _lights:
		source.shadow_enabled = quality >= 2


func toggle_door(id: String) -> bool:
	var leaf := doors[id]
	if _door_tweens.has(id):
		_door_tweens[id].kill()
	var opened := not bool(leaf.get_meta("open", false))
	leaf.set_meta("open", opened)
	var barrier := leaf.get_node("Barrier") as StaticBody3D
	barrier.set_deferred("collision_layer", 0 if opened else 1)
	var tween := create_tween()
	tween.tween_property(leaf, "rotation:y", -1.42 if opened else 0.0, 0.43).set_trans(Tween.TRANS_SINE)
	_door_tweens[id] = tween
	return opened


func set_rescue_open(opened: bool) -> void:
	_intake_gate.position.y = _closed_gate_y + (1.80 if opened else 0.0)


func _cabin(id: String, title: String, base: Vector3, size: Vector2, occupied: bool) -> void:
	var front := base.z + size.y * 0.5
	var floor_y := -INF
	for x: float in [-1.0, 0.0, 1.0]:
		for z: float in [-1.0, 0.0, 1.0]:
			floor_y = maxf(floor_y, _ground(base.x + size.x * 0.5 * x, base.z + size.y * 0.5 * z).y)
	var slab := Vector3(base.x, floor_y + 0.10, base.z)
	var left := -size.x * 0.5
	var right := size.x * 0.5
	const WALL := 2.39
	var entry := slab + Vector3(-0.56, 0, size.y * 0.5)
	_solid(slab - Vector3.UP * 0.08, Vector3(size.x + 0.12, 0.22, size.y + 0.11), _wood)
	for x: float in [left + 0.18, right - 0.18]:
		for z: float in [-size.y * 0.5 + 0.16, size.y * 0.5 - 0.16]:
			var foot := _ground(base.x + x, base.z + z)
			_solid(foot.lerp(slab + Vector3(x, 0, z), 0.5),
				Vector3(0.31, maxf(0.22, slab.y - foot.y), 0.35), _concrete)
	var high := slab + Vector3.UP * (WALL * 0.5)
	for x: float in [left, right]:
		_solid(high + Vector3(x, 0, 0), Vector3(0.16, WALL, size.y), _wood)
	_solid(high + Vector3(0, 0, -size.y * 0.5), Vector3(size.x, WALL, 0.17), _wood)
	var face := Vector3(base.x, high.y, front)
	_front_panel(face, left, -1.10, WALL)
	_front_panel(face, 0.0, right, WALL)
	_solid(entry + Vector3.UP * 2.27, Vector3(1.12, 0.27, 0.19), _wood)
	var opening := Node3D.new()
	add_child(opening)
	opening.position = entry + Vector3(-0.55, 0, 0.08)
	var panel := _box(opening, Vector3(0.53, 1.04, 0), Vector3(1.06, 2.08, 0.117), _roof)
	_box(opening, Vector3(0.9, 1.02, 0.082), Vector3(0.12, 0.065, 0.064), _iron)
	var barrier := StaticBody3D.new()
	barrier.name = "Barrier"
	opening.add_child(barrier)
	barrier.position = panel.position
	_shape(barrier, Vector3(1.06, 2.08, 0.118))
	opening.set_meta("open", false)
	doors[id] = opening
	door_points[id] = entry + Vector3(0, 0.96, 0.34)
	var foot_landing := _ground(entry.x, front + 2.9)
	var start := Vector3(entry.x, slab.y - 0.025, front + 0.18)
	var end := foot_landing + Vector3.UP * 0.14
	_span(start, end, 1.45, 0.14, _wood, true)
	for z: float in [0.29, 0.68, 1.04, 1.4, 1.78, 2.16, 2.54]:
		var at := start.lerp(end, z / 2.72)
		_box(self, at + Vector3.UP * 0.056, Vector3(1.43, 0.044, 0.041), _iron)
	var window := face + Vector3(size.x * 0.26, 0.11, 0.112)
	_window(window, minf(1.53, size.x * 0.39), occupied)
	for rail in 6:
		var line_y := slab.y + 0.24 + rail * 0.38
		for x: float in [left, right]:
			_box(self, Vector3(base.x + x, line_y, base.z), Vector3(0.185, 0.033, size.y), _iron)
	var ridge := slab + Vector3.UP * (WALL + 0.94)
	var eave := slab.y + WALL - 0.04
	for side: float in [-1.0, 1.0]:
		var outer := Vector3(base.x + side * (right + 0.38), eave, base.z)
		var roof := _span(ridge, outer, size.y + 0.79, 0.125, _roof)
		for i in 9:
			var rib := _span(ridge + Vector3(0, 0.082, -size.y * 0.5 + i * size.y / 8.0),
				outer + Vector3(0, 0.082, -size.y * 0.5 + i * size.y / 8.0), 0.054, 0.045, _iron)
			rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gable(slab + Vector3(0, WALL, size.y * 0.5), size.x, 0.93)
	_gable(slab + Vector3(0, WALL, -size.y * 0.5), size.x, 0.93)
	_sign(title, entry + Vector3(0.52, 2.26, 0.204), 0.0038)
	_lantern(entry + Vector3(-0.77, 1.93, 0.26), false, 6.7, 2.25, true)
	if occupied:
		_lantern(slab + Vector3(0.73, 2.23, -0.64), false, 4.3, 1.45)
		_instrument(slab + Vector3(0.72, 0.0, -size.y * 0.30))
	for j in 3:
		_box(self, _ground(base.x + right + 0.34, front - j * 0.54) + Vector3.UP * 0.24,
			Vector3(0.59, 0.49, 0.46), _wood)


func _front_panel(at: Vector3, a: float, b: float, height: float) -> void:
	_solid(at + Vector3((a + b) * 0.5, 0, 0), Vector3(b - a, height, 0.17), _wood)


func _gable(at: Vector3, width: float, height: float) -> void:
	var triangle := PrismMesh.new()
	triangle.size = Vector3(width, height, 0.17)
	valley.place_mesh(self, triangle, _wood, at + Vector3.UP * height * 0.5)


func _window(at: Vector3, width: float, occupied: bool) -> void:
	_box(self, at, Vector3(width + 0.12, 0.79, 0.106), _iron)
	_box(self, at + Vector3.FORWARD * -0.061, Vector3(width, 0.67, 0.034), _warm if occupied else _roof)
	for i in 3:
		_box(self, at + Vector3(-width * 0.35 + i * width * 0.35, 0, 0.093), Vector3(0.043, 0.70, 0.051), _iron)
	_box(self, at + Vector3(0, -0.025, 0.091), Vector3(width, 0.044, 0.052), _iron)
	_box(self, at + Vector3(0, -0.39, 0.08), Vector3(width + 0.11, 0.067, 0.21), _wood)


func _tower(at: Vector3) -> void:
	var top := at + Vector3.UP * 7.45
	var feet := [Vector3(-0.93, 0, -0.85), Vector3(0.93, 0, -0.85), Vector3(0.93, 0, 0.85), Vector3(-0.93, 0, 0.85)]
	for i in feet.size():
		var foot := _ground(at.x + feet[i].x, at.z + feet[i].z)
		var rail: Vector3 = top + feet[i] * 0.27
		_span(foot, rail, 0.105, 0.105, _iron)
		var next: Vector3 = feet[(i + 1) % feet.size()]
		for level in 3:
			var from := foot.lerp(rail, float(level) * 0.28 + 0.05)
			var cross: Vector3 = at + next.lerp(next * 0.27, float(level + 1) * 0.28)
			cross.y = at.y + float(level + 1) * 2.12
			_span(from, cross, 0.055, 0.055, _roof)
	_box(self, top + Vector3.UP * 0.31, Vector3(0.055, 0.76, 0.055), _iron)
	_lantern(top, true, 2.8, 1.5)
	for i in 4:
		_span(top + Vector3.UP * (i * 0.13), top + Vector3(-1.05 + 0.09 * i, i * 0.13, 0),
			0.035, 0.035, _iron)


func _utility_line(first: Vector2, last: Vector2) -> void:
	var terminals: Array[Vector3] = []
	for point in [first, (first + last) * 0.5, last]:
		var at := _ground(point.x, point.y)
		var height := 4.65
		_box(self, at + Vector3.UP * height * 0.5, Vector3(0.16, height, 0.18), _wood)
		var top := at + Vector3.UP * (height - 0.20)
		_box(self, top, Vector3(0.86, 0.088, 0.093), _wood)
		terminals.append(top)
	for wire: float in [-0.32, 0.32]:
		for pole in terminals.size() - 1:
			var a := terminals[pole] + Vector3(wire, 0.09, 0.0)
			var b := terminals[pole + 1] + Vector3(wire, 0.09, 0.0)
			var prior := a
			for j in range(1, 9):
				var weight := j / 8.0
				var point := a.lerp(b, weight) - Vector3.UP * (sin(weight * PI) * 0.63)
				var cable := _span(prior, point, 0.024, 0.024, _iron)
				cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				prior = point


func _intake(center: Vector3) -> void:
	var end := center + Vector3(-3.78, 1.29, 0)
	_box(self, end, Vector3(0.14, 2.54, 4.08), _concrete)
	_intake_gate = Node3D.new()
	add_child(_intake_gate)
	_intake_gate.position = end + Vector3(0.11, -0.10, 0)
	_closed_gate_y = _intake_gate.position.y
	_box(_intake_gate, Vector3.ZERO, Vector3(0.19, 1.93, 1.62), _roof)
	for i in 12:
		_box(_intake_gate, Vector3(0.106, -0.72 + i * 0.135, 0), Vector3(0.05, 0.04, 1.60), _iron)
	for side: float in [-1.0, 1.0]:
		var conduit := center + Vector3(0.0, 2.55, side * 1.95)
		_span(conduit + Vector3.LEFT * 3.45, conduit + Vector3.RIGHT * 3.45, 0.11, 0.13, _roof)
		for i in 5:
			_box(self, conduit + Vector3(-3.1 + i * 1.45, 0, 0), Vector3(0.093, 0.22, 0.22), _iron)
		_lantern(end + Vector3(0.54, 0.83, side * 0.94), true, 4.6, 2.0)
	_instrument(center + Vector3(-2.72, 0, -1.54))
	_instrument(center + Vector3(-2.72, 0, 1.54))
	_sign("INTAKE FOUR   /   PRESSURE CONTROL", end + Vector3(0.19, 0.985, 0), 0.0039, PI * 0.5)


func _instrument(at: Vector3) -> void:
	_box(self, at + Vector3.UP * 0.57, Vector3(0.79, 1.10, 0.51), _roof)
	_box(self, at + Vector3(0, 0.84, 0.268), Vector3(0.54, 0.26, 0.046), _iron)
	for j in 5:
		_box(self, at + Vector3(-0.21 + j * 0.105, 0.85, 0.299), Vector3(0.038, 0.033, 0.023), _red if j == 2 else _warm)
	for j in 4:
		_box(self, at + Vector3(-0.235 + j * 0.155, 0.40, 0.272), Vector3(0.08, 0.25, 0.03), _iron)


func _forest_edge() -> void:
	var wood := CylinderMesh.new()
	wood.height = 1.0
	wood.top_radius = 0.14
	wood.bottom_radius = 0.22
	wood.radial_segments = 9
	for pair: Vector4 in [Vector4(-39.8, -67.2, -44.1, -66.6), Vector4(-47.3, -60.3, -51.2, -59.4),
			Vector4(4.4, 0.8, 7.1, 1.35), Vector4(-2.9, -53.8, 0.05, -55.7)]:
		var start := _ground(pair.x, pair.y) + Vector3.UP * 0.19
		var end := _ground(pair.z, pair.w) + Vector3.UP * 0.17
		var stem: MeshInstance3D = valley.place_mesh(self, wood, _wood, (start + end) * 0.5)
		stem.basis = Basis.looking_at((end - start).normalized()).rotated(
			Basis.looking_at((end - start).normalized()).x, PI * 0.5)
		stem.scale.y = start.distance_to(end)


func _span(start: Vector3, end: Vector3, width: float, thickness: float, material: Material,
		collidable := false) -> MeshInstance3D:
	var length := start.distance_to(end)
	var size := Vector3(width, thickness, length)
	var orientation := Basis.looking_at((end - start).normalized())
	var center := (start + end) * 0.5
	var part := _box(self, center, size, material)
	part.basis = orientation
	if collidable:
		var body := StaticBody3D.new()
		add_child(body)
		body.transform = Transform3D(orientation, center)
		_shape(body, size)
	return part


func _sign(text: String, at: Vector3, pixel: float, yaw := 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color("#efe1be")
	add_child(label)
	label.position = at
	label.rotation.y = yaw


func _lantern(at: Vector3, emergency: bool, reach: float, energy: float, shadow := false) -> void:
	var glass := _red if emergency else _warm
	_box(self, at, Vector3(0.14, 0.17, 0.13), glass)
	_box(self, at + Vector3.UP * 0.11, Vector3(0.23, 0.06, 0.23), _iron)
	var source := OmniLight3D.new()
	source.omni_range = reach
	source.light_color = glass.albedo_color
	source.light_energy = energy
	source.distance_fade_enabled = true
	source.distance_fade_begin = 28.0
	source.distance_fade_shadow = 18.0
	source.distance_fade_length = 13.0
	add_child(source)
	source.position = at + Vector3(0, -0.04, 0.10)
	if shadow:
		_lights.append(source)


func _solid(at: Vector3, size: Vector3, material: Material) -> void:
	_box(self, at, size, material)
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	_shape(body, size)


func _shape(body: StaticBody3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collision.shape = volume
	body.add_child(collision)


func _box(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	return valley.box(parent, at, size, surface)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, valley.surface_height_at(x, z), z)


func _emissive(tint: Color, strength: float) -> StandardMaterial3D:
	var finish: StandardMaterial3D = valley.material(tint)
	finish.emission_enabled = true
	finish.emission = tint
	finish.emission_energy_multiplier = strength
	return finish


func _finish(base: Color, wear: Color, metal: float, grain: float) -> ShaderMaterial:
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://frontier_station.gdshader")
	finish.set_shader_parameter("base_tint", base)
	finish.set_shader_parameter("wear_tint", wear)
	finish.set_shader_parameter("metalness", metal)
	finish.set_shader_parameter("grain", grain)
	return finish
