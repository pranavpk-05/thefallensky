extends Node3D

const STRIP_X := -17.0
const STRIP_WIDTH := 13.0
const STRIP_LENGTH := 104.0
const DEPARTURE_Z := -70.0
const OBSERVATORY_Z := -229.0

var points: Dictionary[String, Vector3] = {}
var beacons: Dictionary[String, Node3D] = {}
var departure: Vector3
var observatory: Vector3
var guardian_origin: Vector3
var tunnel_center: Vector3
var cache_lid: MeshInstance3D
var valley
var metals: StandardMaterial3D
var canvas: StandardMaterial3D
var timber: StandardMaterial3D
var dark: StandardMaterial3D
var amber: StandardMaterial3D


func build(terrain: Node3D) -> void:
	valley = terrain
	metals = valley.material(Color("#3d5051"))
	canvas = valley.material(Color("#6f7052"))
	timber = valley.material(Color("#513e2b"))
	dark = valley.material(Color("#242e37"))
	amber = valley.material(Color("#ffb266"))
	amber.emission_enabled = true
	amber.emission = Color("#ff9d53")
	amber.emission_energy_multiplier = 2.5
	_build_camp()
	_build_tunnel()
	_build_court()
	_build_relay()
	_flight_obstacle(-20, -158, 5.0, 58.0)
	_flight_obstacle(-34, -168, 2.9, 32.0)
	_flight_obstacle(-9, -168, 2.9, 32.0)
	departure = _build_airstrip(DEPARTURE_Z, false)
	observatory = _build_airstrip(OBSERVATORY_Z, true)


func _build_camp() -> void:
	var desk := _ground(5.0, 9.6)
	_crate(desk, Vector3(1.15, 0.61, 0.79))
	_block(desk + Vector3(0, 0.64, 0), Vector3(0.42, 0.07, 0.30), amber)
	_point("journal", desk + Vector3.UP * 0.68)
	var radio := _ground(9.6, 5.6)
	_crate(radio, Vector3(0.75, 0.65, 0.50))
	_block(radio + Vector3.UP * 0.72, Vector3(0.64, 0.37, 0.38), metals)
	_block(radio + Vector3(0.18, 1.17, 0), Vector3(0.025, 0.68, 0.025), metals)
	_point("radio", radio + Vector3.UP * 0.89)
	var tracks := _ground(4.9, 2.8)
	for i in 8:
		var at := _ground(tracks.x + (i % 2 - 0.5) * 0.37 - i * 0.28, tracks.z - i * 0.41)
		_block(at + Vector3.UP * 0.024, Vector3(0.14, 0.035, 0.34), timber).rotation.y = 0.38
	_point("tracks", tracks)
	_crate(_ground(12, 7.6), Vector3(0.89, 0.43, 0.67))
	_point("kit", _ground(12, 7.6) + Vector3.UP * 0.47)
	var fire := _ground(6.3, 13.1)
	_campfire(fire)
	_point("camp_rest", fire)
	_lantern(_ground(4.5, 7.1), amber, Color("#ffb369"))


func _build_tunnel() -> void:
	var approach := _ground(-47.5, -63.5)
	var floor_y := approach.y + 0.24
	var center := Vector3(-51.0, floor_y, -64)
	tunnel_center = center
	_solid(center + Vector3(0, -0.24, 0), Vector3(8.5, 0.48, 5.4), valley.masonry)
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var at := center + Vector3(i * 2.0 - 3.15, 0.75 + (i % 2) * 0.45, side * 2.72)
			_boulder(at, Vector3(2.5, 2.6, 2.1), i * 0.71)
		_solid(center + Vector3(0, 1.23, side * 2.18), Vector3(8.3, 2.45, 0.36), valley.masonry)
	for i in 4:
		_boulder(center + Vector3(i * 1.87 - 2.75, 3.85, 0.05), Vector3(3.1, 2.8, 5.2), i * 0.47)
	_solid(center + Vector3(0, 3.04, 0), Vector3(8.1, 0.38, 5.05), valley.trim)
	_solid(center + Vector3(-4.0, 1.22, 0), Vector3(0.26, 2.6, 4.64), dark)
	for z in [-1.95, 1.95]:
		_solid(center + Vector3(3.68, 1.12, z), Vector3(0.6, 2.28, 0.66), valley.trim)
	_block(center + Vector3(3.68, 2.43, 0), Vector3(0.61, 0.48, 4.55), valley.trim)
	var relay := center + Vector3(1.0, 0.0, 1.05)
	_crate(relay, Vector3(0.96, 0.58, 0.77))
	_block(relay + Vector3.UP * 0.67, Vector3(0.47, 0.12, 0.33), valley.rune_material)
	_point("relay", relay + Vector3.UP * 0.6)
	var manifest := center + Vector3(1.3, 0, -1.16)
	_crate(manifest, Vector3(0.89, 0.65, 0.51))
	_block(manifest + Vector3.UP * 0.68, Vector3(0.30, 0.05, 0.34), amber)
	_point("manifest", manifest + Vector3.UP * 0.66)
	_campfire(_ground(-43.5, -65))
	_point("tunnel_rest", _ground(-43.5, -65))
	_lantern(center + Vector3(2.2, 0, 1.8), amber, Color("#ffb669"))
	guardian_origin = _ground(-33.3, -71.5)
	_build_cache()
	for i in 4:
		var x := -38.0 - i * 2.35
		var at := _ground(x, -64 - cos(i) * 0.7)
		_block(at - Vector3.UP * 0.07, Vector3(1.65, 0.19, 1.23), valley.trim).rotation.y = i * 0.37


func _build_cache() -> void:
	var hint := _ground(-44.0, -69.3)
	_console(hint, amber)
	_point("vault_hint", hint + Vector3.UP * 0.88)
	var anchors := [Vector2(-45.0, -72.7), Vector2(-42.1, -73.6), Vector2(-40.1, -76.5)]
	var symbols := ["rune_current", "rune_moon", "rune_sun"]
	var glyphs := ["≈", "☾", "☀"]
	for i in anchors.size():
		var at := _ground(anchors[i].x, anchors[i].y)
		_console(at, valley.rune_material)
		var plate := Label3D.new()
		plate.text = glyphs[i]
		plate.font_size = 35
		plate.pixel_size = 0.018
		plate.modulate = Color("#9bf7e4")
		plate.outline_size = 6
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(plate)
		plate.position = at + Vector3.UP * 1.28
		_point(symbols[i], at + Vector3.UP * 0.84)
	var cache := _ground(-46, -74.7)
	_crate(cache, Vector3(1.36, 0.55, 0.83))
	cache_lid = _block(cache + Vector3.UP * 0.54, Vector3(1.41, 0.15, 0.88), metals)


func _build_court() -> void:
	var center: Vector3 = valley.HANGING_COURT
	var stand := center + Vector3(-4.1, -0.19, 0.35)
	_console(stand, valley.rune_material)
	_point("court", stand + Vector3.UP * 0.9)
	var relief := center + Vector3(4.2, -0.28, -0.65)
	_console(relief, amber)
	_point("runes", relief + Vector3.UP * 0.9)


func _build_relay() -> void:
	var center := _ground(-26.0, -150.0)
	for side: float in [-1.0, 1.0]:
		var foot := _ground(center.x + side * 1.8, center.z - 1.8)
		_block(foot + Vector3.UP * 1.62, Vector3(0.52, 3.24, 0.51), valley.trim)
		_block(foot + Vector3(0, 1.72, 0.27), Vector3(0.10, 2.36, 0.045), valley.rune_material)
	_block(center + Vector3(0, 3.39, -1.8), Vector3(4.2, 0.32, 0.57), valley.masonry)
	_console(center, valve_color(false))
	_point("publish", center + Vector3.UP * 0.93)
	var rescue := _ground(center.x + 5.3, center.z - 1.1)
	_console(rescue, valve_color(true))
	_point("rescue", rescue + Vector3.UP * 0.93)
	points["spire_start"] = points["publish"]
	points["anchor_east"] = points["rescue"]
	var west := _ground(center.x - 4.0, center.z + 1.9)
	_console(west, amber)
	_point("anchor_west", west + Vector3.UP * 0.93)
	points["anchor_core"] = points["publish"]


func valve_color(warm: bool) -> Material:
	return amber if warm else valley.rune_material


func _build_airstrip(z: float, is_observatory: bool) -> Vector3:
	var top := -1000.0
	for line in range(-52, 53, 2):
		for lateral in range(-7, 8, 2):
			top = maxf(top, valley.height_at(STRIP_X + lateral, z + line))
	top = ceilf(top + 0.80)
	var center := Vector3(STRIP_X, top, z)
	_solid(center - Vector3.UP * 0.37, Vector3(STRIP_WIDTH, 0.74, STRIP_LENGTH), timber)
	for i in 13:
		var along := z + i * 7.86 - 47.15
		_block(Vector3(STRIP_X, top + 0.015, along), Vector3(0.17, 0.026, 3.25), valley.trim)
		for side: float in [-1.0, 1.0]:
			var x := STRIP_X + side * 6.1
			_block(Vector3(x, top + 0.07, along), Vector3(0.44, 0.13, 0.53), amber)
			if i % 2 == 0:
				var ground: float = valley.height_at(x, along)
				var span := top - ground
				if span > 1.0:
					_block(Vector3(x, top - span * 0.5, along), Vector3(0.55, span, 0.62), metals)
	_add_access(center, z + 31.4 if not is_observatory else z + 4.0)
	if is_observatory:
		_build_observatory(center + Vector3(-4.1, 0, -33.7))
	else:
		var post := center + Vector3(-4.5, 0.0, 39)
		_lantern(post, amber, Color("#ffb672"))
		_crate(post + Vector3(0, 0, -2.8), Vector3(0.87, 0.58, 0.68))
		_point("airstrip_rest", post + Vector3(0, 0, -2.8))
	return center


func _add_access(center: Vector3, z: float) -> void:
	var top := Vector3(STRIP_X + STRIP_WIDTH * 0.49, center.y - 0.06, z)
	var edge_x := top.x + 13.0
	var end := _ground(edge_x, z) - Vector3.UP * 0.09
	if absf(top.y - end.y) > 10.5:
		edge_x += 7.0
		end = _ground(edge_x, z) - Vector3.UP * 0.09
	var ramp := _solid((top + end) * 0.5, Vector3(top.distance_to(end), 0.30, 2.85), timber)
	ramp.rotation.z = atan2(end.y - top.y, end.x - top.x)
	_lantern(end, amber, Color("#ffc077"))


func _build_observatory(at: Vector3) -> void:
	_solid(at + Vector3(0, 1.0, -3.1), Vector3(2.3, 2.0, 4.3), valley.masonry)
	_block(at + Vector3(0, 2.08, -3.1), Vector3(3.0, 0.38, 4.65), valley.trim)
	_block(at + Vector3(0, 2.25, -2.5), Vector3(0.26, 2.25, 0.32), metals).rotation.x = -0.65
	var antenna := TorusMesh.new()
	antenna.inner_radius = 0.64
	antenna.outer_radius = 0.78
	antenna.rings = 16
	antenna.ring_segments = 6
	var dish: MeshInstance3D = valley.place_mesh(self, antenna, metals, at + Vector3(0, 3.2, -1.92))
	dish.rotation.x = 0.65
	_lantern(at + Vector3(0, 0, 0.31), amber, Color("#ffc582"))
	_console(at + Vector3(0, 0, 1.2), valley.rune_material)
	_point("flight_log", at + Vector3(0, 0.9, 1.2))


func _console(at: Vector3, marking: Material) -> void:
	_block(at + Vector3.UP * 0.33, Vector3(0.76, 0.71, 0.54), valley.masonry)
	_block(at + Vector3.UP * 0.76, Vector3(0.98, 0.19, 0.67), valley.trim).rotation.x = -0.19
	_block(at + Vector3.UP * 0.88, Vector3(0.63, 0.035, 0.28), marking).rotation.x = -0.19


func _point(id: String, at: Vector3) -> void:
	points[id] = at
	var beacon := Node3D.new()
	add_child(beacon)
	beacon.position = at + Vector3.UP * 0.42
	var hint := BoxMesh.new()
	hint.size = Vector3(0.16, 0.16, 0.16)
	var crystal: MeshInstance3D = valley.place_mesh(beacon, hint, amber, Vector3.ZERO)
	crystal.rotation_degrees = Vector3(45, 35, 45)
	beacons[id] = beacon


func _boulder(at: Vector3, size: Vector3, turn: float) -> void:
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	var piece: MeshInstance3D = valley.place_mesh(self, rock, valley.rock_material, at)
	piece.scale = size
	piece.rotation = Vector3(turn * 0.17, turn, turn * 0.33)


func _campfire(at: Vector3) -> void:
	for i in 7:
		var angle := i * TAU / 7.0
		_boulder(at + Vector3(cos(angle) * 0.58, 0.12, sin(angle) * 0.58), Vector3(0.38, 0.24, 0.28), angle)
	_lantern(at - Vector3.UP * 0.93, amber, Color("#ff9b54"))


func _lantern(at: Vector3, surface: Material, color: Color) -> void:
	_block(at + Vector3.UP * 0.45, Vector3(0.105, 0.92, 0.105), metals)
	_block(at + Vector3.UP * 0.99, Vector3(0.28, 0.31, 0.28), surface)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 10.0
	add_child(light)
	light.position = at + Vector3.UP * 1.16


func _crate(at: Vector3, size: Vector3) -> void:
	_block(at + Vector3.UP * size.y * 0.5, size, timber)
	for side: float in [-1.0, 1.0]:
		_block(at + Vector3(side * size.x * 0.34, size.y * 0.51, 0), Vector3(0.073, size.y * 1.03, size.z * 1.018), metals)


func _solid(at: Vector3, size: Vector3, surface: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	valley.box(body, Vector3.ZERO, size, surface)
	return body


func _flight_obstacle(x: float, z: float, radius: float, height: float) -> void:
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 8
	obstacle.collision_mask = 0
	add_child(obstacle)
	obstacle.position = _ground(x, z) + Vector3.UP * height * 0.5
	var bounds := CylinderShape3D.new()
	bounds.radius = radius
	bounds.height = height
	var hull := CollisionShape3D.new()
	hull.shape = bounds
	obstacle.add_child(hull)


func _block(at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	return valley.box(self, at, size, surface)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, valley.height_at(x, z), z)
