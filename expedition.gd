extends Node3D

const SITES := [Vector2(0, -44), Vector2(-37, -104), Vector2(-23, -151)]
const SITE_NAMES := ["Windgate", "The Hanging Court", "The Sunken Spire"]
const Campaign = preload("res://frontier_campaign.gd")

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
var hud_layer: CanvasLayer
var foot_controls: Label
var campaign = Campaign.new()

@onready var valley = $Valley
@onready var pilot = $Wayfarer


func _ready() -> void:
	checkpoint = opening_spawn()
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
	add_child(campaign)
	var show_title := DisplayServer.get_name() != "headless" and (not OS.get_cmdline_args().has("--script")
		or OS.get_cmdline_user_args().has("--qa-title"))
	campaign.setup(self, show_title)


func opening_spawn() -> Vector3:
	return Vector3(0, valley.height_at(0, 10) + 0.6, 10)


func _physics_process(delta: float) -> void:
	if campaign.play_step(delta):
		return
	var pos: Vector3 = pilot.global_position
	if Input.is_action_just_pressed("restart"):
		if campaign.running:
			campaign.retry_checkpoint("Returned to your checkpoint.")
		else:
			pilot.respawn(checkpoint)
		return
	var out_of_bounds := pos.y < -6.0 or absf(pos.x) > 215.0 or pos.z < -346.0 or pos.z > 66.0
	var submerged: bool = pos.y < valley.water_level - 0.25 and absf(pos.x - valley.river_center(pos.z)) < 7.7
	if out_of_bounds or submerged:
		pilot.respawn(checkpoint)
		campaign.on_hazard()
		return
	if Input.is_action_just_pressed("restore"):
		if step < shrines.size() and pos.distance_to(shrines[step].global_position) < 6.0 \
				and campaign.can_restore_seal():
			_restore_site()
		elif _near_restored_updraft(pos):
			pilot.ride_updraft()


func _process(delta: float) -> void:
	daybreak += delta
	for i in rings.size():
		rings[i].rotation.z = sin(daybreak * 0.8 + i) * 0.11
		rings[i].position.y = 3.0 + sin(daybreak * 1.3 + i) * 0.24
	foot_controls.visible = not campaign.aircraft.is_piloted()
	if campaign.presentation(delta):
		return
	if step == shrines.size():
		var details := "All three seals restored"
		if campaign.running and not campaign.case_file.solved:
			details = "Resolve the last transmission in your journal   ·   J"
		show_goal("The valley remembers the sun", details, Vector3.ZERO, false)
		return
	var target := shrines[step].global_position
	var pos: Vector3 = pilot.global_position
	var distance := pos.distance_to(target)
	var details := "E   Restore seal" if distance < 6.0 else "%d / 3 seals   ·   %d m" % [step, roundi(distance)]
	if distance >= 6.0 and _near_restored_updraft(pos):
		details = "E   Ride updraft   ·   %d m to next seal" % roundi(distance)
	show_goal("Restore " + SITE_NAMES[step], details, target + Vector3.UP * 4.6, distance > 6.0)


func show_goal(title: String, details: String, aim: Vector3, show_marker: bool) -> void:
	objective.text = title
	distance_label.text = details
	var camera := get_viewport().get_camera_3d()
	marker.visible = show_marker and camera != null
	if marker.visible:
		var bounds := get_viewport().get_visible_rect().grow(-47)
		if camera.is_position_behind(aim):
			var local_x := camera.to_local(aim).x
			marker.text = "‹" if local_x < 0.0 else "›"
			marker.position = Vector2(bounds.position.x if local_x < 0.0 else bounds.end.x, bounds.get_center().y) \
				- marker.size * 0.5
			return
		marker.text = "◇"
		var screen := camera.unproject_position(aim)
		marker.position = screen.clamp(bounds.position, bounds.end) - marker.size * 0.5


func _restore_site() -> void:
	var index := step
	var site := shrines[step].global_position
	_set_shrine(step, restored)
	checkpoint = site + Vector3(0, 0.8, 4.0)
	step += 1
	if step < shrines.size():
		_set_shrine(step, active)
		pilot.ride_updraft()
	campaign.on_seal_restored(index)


func reset_seals(restored_count: int) -> void:
	step = restored_count
	for index in shrines.size():
		_set_shrine(index, restored if index < step else (active if index == step else inactive))


func dim_seals() -> void:
	for index in shrines.size():
		_set_shrine(index, inactive)


func _near_restored_updraft(pos: Vector3) -> bool:
	if campaign.running:
		for i in mini(step, 2):
			if pos.distance_to(shrines[i].global_position) < 6.0:
				return true
		return false
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
		if node.material_override in [inactive, active, restored]:
			node.material_override = glow


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label(root, "SOLSTICE OF THE SUNKEN SPIRE  /  DARK FRONTIER", 16, Color("#f5d4a2"))
	title.position = Vector2(31, 26)
	objective = _label(root, "", 27, Color("#fff3d7"))
	objective.position = Vector2(30, 54)
	distance_label = _label(root, "", 17, Color("#b6fae6"))
	distance_label.position = Vector2(31, 91)
	foot_controls = _label(root, "WASD  Move   Space  Glide   Ctrl  Crouch   Shift  Sprint   J  Journal   R  Checkpoint", 16, Color("#f8e7cd"))
	foot_controls.position = Vector2(31, -50)
	foot_controls.anchor_top = 1.0
	foot_controls.anchor_bottom = 1.0
	foot_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
