extends Node3D

const SITES := [Vector2(0, -44), Vector2(-37, -104), Vector2(-23, -151)]
const SITE_NAMES := ["Windgate", "The Hanging Court", "The Sunken Spire"]

var checkpoint: Vector3
var shrines: Array[Node3D] = []
var rings: Array[Node3D] = []
var inactive: StandardMaterial3D
var active: StandardMaterial3D
var restored: StandardMaterial3D
var step := 0
var daybreak := 0.0
var objective: Label
var distance_label: Label
var marker: Label

@onready var valley = $Valley
@onready var pilot = $Wayfarer


func _ready() -> void:
	checkpoint = Vector3(0, valley.height_at(0, 10) + 0.6, 10)
	pilot.respawn(checkpoint)
	inactive = valley.material(Color("#25626a"))
	active = valley.rune_material
	restored = valley.material(Color("#f7c77d"))
	restored.emission_enabled = true
	restored.emission = Color("#ffd583")
	restored.emission_energy_multiplier = 2.4
	for i in SITES.size():
		var point: Vector2 = SITES[i]
		var at := Vector3(point.x, valley.height_at(point.x, point.y) + 0.06, point.y)
		if i == 1:
			at = valley.HANGING_COURT
		_create_shrine(at)
	_set_shrine(0, active)
	_build_hud()


func _physics_process(_delta: float) -> void:
	var pos: Vector3 = pilot.global_position
	if Input.is_action_just_pressed("restart") or pos.y < -6.0 or absf(pos.x) > 215.0 or pos.z < -346.0 or pos.z > 66.0:
		pilot.respawn(checkpoint)
		return
	if pos.y < valley.water_level - 0.25 and absf(pos.x - valley.river_center(pos.z)) < 7.7:
		pilot.respawn(checkpoint)
		return
	if Input.is_action_just_pressed("restore"):
		if step < shrines.size() and pos.distance_to(shrines[step].global_position) < 6.0:
			_restore_site()
		elif _near_restored_updraft(pos):
			pilot.ride_updraft()


func _process(delta: float) -> void:
	daybreak += delta
	for i in rings.size():
		rings[i].rotation.z = sin(daybreak * 0.8 + i) * 0.11
		rings[i].position.y = 3.0 + sin(daybreak * 1.3 + i) * 0.24
	if step == shrines.size():
		objective.text = "The valley remembers the sun"
		distance_label.text = "All three seals restored"
		marker.hide()
		return
	var target := shrines[step].global_position
	var pos: Vector3 = pilot.global_position
	var distance := pos.distance_to(target)
	objective.text = "Restore " + SITE_NAMES[step]
	distance_label.text = "E   Restore seal" if distance < 6.0 else "%d / 3 seals   ·   %d m" % [step, roundi(distance)]
	if distance >= 6.0 and _near_restored_updraft(pos):
		distance_label.text = "E   Ride updraft   ·   %d m to next seal" % roundi(distance)
	var aim := target + Vector3.UP * 4.6
	var camera: Camera3D = pilot.camera
	marker.visible = not camera.is_position_behind(aim) and distance > 6.0
	if marker.visible:
		var bounds := get_viewport().get_visible_rect().grow(-47)
		var screen := camera.unproject_position(aim)
		marker.position = screen.clamp(bounds.position, bounds.end) - marker.size * 0.5


func _restore_site() -> void:
	var site := shrines[step].global_position
	_set_shrine(step, restored)
	checkpoint = site + Vector3(0, 0.8, 4.0)
	step += 1
	if step < shrines.size():
		_set_shrine(step, active)
		pilot.ride_updraft()


func _near_restored_updraft(pos: Vector3) -> bool:
	return step > 0 and step < shrines.size() and pos.distance_to(shrines[step - 1].global_position) < 6.0


func _create_shrine(at: Vector3) -> void:
	var shrine := Node3D.new()
	add_child(shrine)
	shrine.position = at
	shrines.append(shrine)
	var platform := CylinderMesh.new()
	platform.radial_segments = 8
	platform.height = 0.65
	platform.top_radius = 3.05
	platform.bottom_radius = 3.35
	valley.place_mesh(shrine, platform, valley.trim, Vector3(0, -0.40, 0))
	var circle := TorusMesh.new()
	circle.inner_radius = 2.46
	circle.outer_radius = 2.60
	circle.rings = 32
	circle.ring_segments = 8
	valley.place_mesh(shrine, circle, inactive, Vector3(0, 0.14, 0))
	for i in 8:
		var angle := i * TAU / 8.0
		var tile: MeshInstance3D = valley.box(shrine, Vector3(sin(angle) * 1.95, 0.14, cos(angle) * 1.95),
			Vector3(0.10, 0.10, 0.61), inactive)
		tile.rotation.y = angle
	for x in [-2.8, 2.8]:
		valley.box(shrine, Vector3(x, 0.82, 0), Vector3(0.62, 2.7, 0.69), valley.masonry)
		valley.box(shrine, Vector3(x, 1.15, 0.36), Vector3(0.12, 1.26, 0.09), inactive)
	var pivot := Node3D.new()
	shrine.add_child(pivot)
	rings.append(pivot)
	var halo := TorusMesh.new()
	halo.inner_radius = 0.95
	halo.outer_radius = 1.10
	halo.rings = 32
	halo.ring_segments = 8
	var arc: MeshInstance3D = valley.place_mesh(pivot, halo, inactive, Vector3.ZERO)
	arc.rotation.x = PI * 0.5
	var crystal: MeshInstance3D = valley.box(pivot, Vector3.ZERO, Vector3(0.47, 0.47, 0.47), inactive)
	crystal.rotation_degrees = Vector3(33, 35, 45)


func _set_shrine(index: int, glow: Material) -> void:
	for node in shrines[index].find_children("*", "MeshInstance3D", true, false):
		if node.material_override == inactive:
			node.material_override = glow
		elif node.material_override == active and glow == restored:
			node.material_override = restored


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label(root, "SOLSTICE OF THE SUNKEN SPIRE", 16, Color("#f5d4a2"))
	title.position = Vector2(31, 26)
	objective = _label(root, "", 27, Color("#fff3d7"))
	objective.position = Vector2(30, 54)
	distance_label = _label(root, "", 17, Color("#b6fae6"))
	distance_label.position = Vector2(31, 91)
	var hint := _label(root, "WASD  Move     Mouse  Look     Space  Jump / hold to glide     R  Checkpoint", 16, Color("#f8e7cd"))
	hint.position = Vector2(31, -50)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	marker = _label(root, "◇", 32, Color("#99ffe4"))
	marker.custom_minimum_size = Vector2(40, 40)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(parent: Control, words: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = words
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.022, 0.04, 0.04, 0.84))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
