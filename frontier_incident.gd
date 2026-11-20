extends Node3D

const TITLE := "The Flood Gauge Robbery"
const TRACE := "intake_trace"
const WITNESS := "intake_witness"
const DISPATCH := "intake_dispatch"
const TALK := "iven_followup"
const LABELS := {
	TRACE: "Inspect the tally seal in the mud",
	WITNESS: "Speak to Iven, the ferryman",
	DISPATCH: "Recover the duplicate dispatch",
	TALK: "Talk to Iven",
}
const APPROACH_RANGE := 15.0
const RETREAT_TIME := 3.6
const SHIFT_LENGTH := 108.0
const SHELTER := 1.0
const GAUGE := 2.0
const WATCH := 0.0
const LANDING := -1.0

var started := false
var wash := 0.0
var retreat := -1.0
var elapsed := 0.0
var shift_time := 0.0
var alarm := 0.0
var conversations := 0
var discussed_trace := false
var _station := WATCH
var _speech_time := 0.0
var _walk_phase := 0.0
var _walk_blend := 0.0
var _valley: Node3D
var _scene_at: Vector3
var _trace_at: Vector3
var _shelter_at: Vector3
var _dispatch_at: Vector3
var _landing_at: Vector3
var _working_at: Vector3
var _witness: Node3D
var _coat: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _trace: Node3D
var _satchel: Node3D
var _lamp: OmniLight3D
var _oilskin: StandardMaterial3D
var _lamp_clock := 0.0
var _gauge_face: Label3D
var _gauge_indicator: MeshInstance3D
var _gauge_off: StandardMaterial3D
var _gauge_on: StandardMaterial3D
var _shelter_lamp: OmniLight3D
var _roof_rain: AudioStreamPlayer3D
var _surfaces: Array[ShaderMaterial] = []
var _surface_wetness := -1.0
var _shelter_bodies: Array[StaticBody3D] = []


func build(terrain: Node3D) -> void:
	_valley = terrain
	_scene_at = _ground(-4.8, -54.0)
	_trace_at = _ground(-6.4, -54.6)
	_shelter_at = _ground(-8.1, -58.8)
	_dispatch_at = _ground(-6.9, -59.8)
	_landing_at = _ground(-4.0, -45.0)
	_working_at = _ground(-7.32, -58.85)
	_build_scene()
	_build_witness()
	reset()
	hide()


func reset() -> void:
	started = false
	wash = 0.0
	retreat = -1.0
	elapsed = 0.0
	shift_time = 0.0
	alarm = 0.0
	conversations = 0
	discussed_trace = false
	_station = WATCH
	_speech_time = 0.0
	_walk_phase = 0.0
	_walk_blend = 0.0
	if _roof_rain:
		_roof_rain.stop()
	_lamp_clock = 0.0
	_pose_witness(0.0, 0.0, _trace_at)
	_witness.reset_physics_interpolation()


func save_to(file: ConfigFile) -> void:
	file.set_value("flood_gauge", "started", started)
	file.set_value("flood_gauge", "wash", wash)
	file.set_value("flood_gauge", "retreat", retreat)
	file.set_value("flood_gauge", "elapsed", elapsed)
	file.set_value("flood_gauge", "shift_time", shift_time)
	file.set_value("flood_gauge", "alarm", alarm)
	file.set_value("flood_gauge", "station", _station)
	file.set_value("flood_gauge", "conversations", conversations)
	file.set_value("flood_gauge", "discussed_trace", discussed_trace)


func load_from(file: ConfigFile) -> void:
	reset()
	started = bool(file.get_value("flood_gauge", "started", false))
	wash = clampf(float(file.get_value("flood_gauge", "wash", 0.0)), 0.0, 1.0)
	retreat = clampf(float(file.get_value("flood_gauge", "retreat", -1.0)), -1.0, RETREAT_TIME)
	elapsed = clampf(float(file.get_value("flood_gauge", "elapsed", 0.0)), 0.0, 60.0)
	shift_time = fposmod(float(file.get_value("flood_gauge", "shift_time", elapsed)), SHIFT_LENGTH)
	alarm = clampf(float(file.get_value("flood_gauge", "alarm", 0.0)), 0.0, 1.0)
	var legacy_station := smoothstep(0.0, RETREAT_TIME, retreat)
	_station = clampf(float(file.get_value("flood_gauge", "station", legacy_station)), LANDING, GAUGE)
	conversations = maxi(0, int(file.get_value("flood_gauge", "conversations", 0)))
	discussed_trace = bool(file.get_value("flood_gauge", "discussed_trace", false))
	_pose_witness(0.0, 0.0, _trace_at)
	_witness.reset_physics_interpolation()


func refresh(file: RefCounted) -> void:
	visible = file.camp_complete()
	for body in _shelter_bodies:
		body.collision_layer = 1 if visible else 0
	_trace.visible = wash < 1.0 and not file.collected.has(TRACE)
	_satchel.visible = not file.collected.has(DISPATCH)
	var restored: bool = file.collected.has(DISPATCH)
	_gauge_face.text = "INTAKE 04\nLOGGING" if restored else "INTAKE 04\nOUT OF SERVICE"
	_gauge_indicator.material_override = _gauge_on if restored else _gauge_off


func advance(delta: float, pilot: CharacterBody3D, storm: float, file: RefCounted, on_foot := true) -> String:
	if not visible:
		return ""
	var at := pilot.global_position
	if not started:
		if not on_foot or not is_near(at):
			return ""
		started = true
		return "A lantern beside an overturned survey case. Someone is still here."
	var nearby := on_foot and at.distance_to(_scene_at) < 20.0
	var message := ""
	var resolved: bool = file.collected.has(DISPATCH)
	if absf(_surface_wetness - storm) > 0.025:
		_surface_wetness = storm
		for surface in _surfaces:
			surface.set_shader_parameter("wetness", storm)
	_shelter_lamp.shadow_enabled = nearby and _valley._quality >= 2
	if _roof_rain:
		var audible := nearby and storm > 0.20
		if audible and not _roof_rain.playing:
			_roof_rain.play()
		elif not audible and _roof_rain.playing:
			_roof_rain.stop()
		_roof_rain.volume_db = lerpf(-38.0, -16.0, storm)
	elapsed = minf(elapsed + delta, 60.0)
	shift_time = fposmod(shift_time + delta, SHIFT_LENGTH)
	_speech_time = maxf(0.0, _speech_time - delta)
	var startled: bool = nearby and pilot.sprinting and at.distance_to(_witness.position) < 6.0
	if startled:
		alarm = 1.0
	elif storm < 0.55:
		alarm = move_toward(alarm, 0.0, delta / 17.0)
	var seeking_cover := storm >= 0.68 or alarm > 0.25
	# Once headed for cover, finish the walk before resuming the shift.
	if seeking_cover or (retreat >= 0.0 and retreat < RETREAT_TIME):
		if retreat < 0.0 and nearby and not resolved and not file.collected.has(WITNESS):
			message = "Iven backs away from your approach." if startled else "Iven is taking shelter by the flood gauge."
		_station = move_toward(_station, SHELTER, delta * (2.0 / RETREAT_TIME if _station < WATCH else 1.0 / RETREAT_TIME))
		retreat = RETREAT_TIME if _station == SHELTER else 0.0
	else:
		retreat = -1.0
		var target := WATCH
		if shift_time >= 72.0:
			target = SHELTER
		elif shift_time >= 42.0:
			target = LANDING
		elif shift_time >= 16.0:
			target = GAUGE if resolved else SHELTER
		if _speech_time <= 0.0:
			_station = move_toward(_station, target, delta * (0.72 if _station > SHELTER else 0.24))
	if not resolved and wash < 1.0 and not file.collected.has(TRACE):
		var previous_wash := wash
		wash = minf(1.0, wash + delta * smoothstep(0.22, 0.82, storm) / 21.0)
		if wash >= 1.0:
			_trace.hide()
			if not file.collected.has(WITNESS):
				message = "Rain washed the seal into the ditch. Ask Iven what he saw."
		elif previous_wash < 0.55 and wash >= 0.55 and not file.collected.has(WITNESS):
			message = "Water is rising around the tally seal."
	_pose_witness(delta, storm, at if nearby else Vector3.INF)
	return message if nearby else ""


func is_near(at: Vector3) -> bool:
	return at.distance_to(_scene_at) < APPROACH_RANGE


func can_interact(id: String, file: RefCounted) -> bool:
	if not visible or not started:
		return false
	if id == TALK:
		return (file.collected.has(WITNESS) or file.collected.has(DISPATCH)) and _can_speak()
	if file.collected.has(id) or file.collected.has(DISPATCH):
		return false
	match id:
		TRACE:
			return wash < 1.0
		WITNESS:
			return _can_speak()
		DISPATCH:
			return file.collected.has(TRACE) or file.collected.has(WITNESS)
	return false


func _can_speak() -> bool:
	return retreat < 0.0 or retreat >= RETREAT_TIME


func speak(file: RefCounted) -> String:
	conversations += 1
	_speech_time = 4.8
	if file.collected.has(DISPATCH):
		return "Iven: I wired the gauge back in. If the river rises tonight, they'll hear it at the landing."
	if file.collected.has(TRACE) and not discussed_trace:
		discussed_trace = true
		return "Iven: That Vesper seal was on their ledger. I tucked our copy of the dispatch inside the gauge."
	if conversations > 1:
		return "Iven: You're back. The paper's still inside the gauge. I haven't told anyone else where."
	if wash >= 1.0:
		return "Iven: The rain took their tracks. I saw both coats. The dispatch they came for is inside the gauge."
	return "Iven: Two blank coats stripped the survey case. I hid the duplicate inside the gauge before they came back."


func point(id: String) -> Vector3:
	match id:
		TRACE:
			return _trace_at + Vector3.UP * 0.1
		WITNESS, TALK:
			return _witness.position + Vector3.UP * 0.75
	return _dispatch_at + Vector3.UP * 0.68


func next_lead(file: RefCounted) -> String:
	if can_interact(DISPATCH, file):
		return DISPATCH
	if can_interact(TRACE, file):
		return TRACE
	return WITNESS


func _pose_witness(delta: float, storm: float, look_at_point: Vector3) -> void:
	var at := _scene_at.lerp(_landing_at, -_station) if _station < WATCH else _scene_at.lerp(_shelter_at, _station)
	if _station > SHELTER:
		at = _shelter_at.lerp(_working_at, _station - SHELTER)
	var displacement := at - _witness.position
	displacement.y = 0.0
	var moving := delta > 0.0 and displacement.length_squared() > 0.000004
	_witness.position = _ground(at.x, at.z) - Vector3.UP * 0.02
	var work := _dispatch_at if _station >= 0.94 else (_landing_at + Vector3.RIGHT * 2.0 if _station < -0.9 else _trace_at)
	var watching_player := look_at_point.is_finite() and (_speech_time > 0.0 or look_at_point.distance_to(at) < 3.3)
	var facing := displacement if moving else (look_at_point if watching_player else work) - at
	var heading := atan2(-facing.x, -facing.z)
	_witness.rotation.y = heading if delta == 0.0 else lerp_angle(_witness.rotation.y, heading, minf(delta * 8.0, 1.0))
	_walk_phase = fposmod(_walk_phase + (displacement.length() * 6.6 if moving else delta * 4.0), TAU)
	_walk_blend = move_toward(_walk_blend, float(moving), delta * 5.0)
	var swing := sin(_walk_phase) * _walk_blend * 0.38
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	var working := not moving and not watching_player and _station >= 1.9
	var checking_bank := not moving and not watching_player and _station <= -0.9
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x,
		0.96 + sin(_lamp_clock * 3.8) * 0.22 if working else -0.08 - swing * 0.62, minf(delta * 6.0, 1.0))
	_coat.rotation.x = lerpf(_coat.rotation.x, -0.14 if working or checking_bank else -0.07 * alarm, minf(delta * 4.0, 1.0))
	_coat.position.y = absf(swing) * 0.12 + sin(_lamp_clock * (2.8 + alarm * 1.5)) * 0.009
	_lamp_clock += delta
	_lamp.light_energy = 1.95 + sin(_lamp_clock * 8.0) * 0.09 + sin(_lamp_clock * 17.0) * storm * 0.18
	_oilskin.roughness = lerpf(0.82, 0.46, storm)


func _build_scene() -> void:
	var timber: StandardMaterial3D = _valley.material(Color("#544137"))
	var iron: StandardMaterial3D = _valley.material(Color("#384047"))
	iron.metallic = 0.43
	var wood := _weathered(Color("#695547"), Color("#261e19"), false)
	var steel := _weathered(Color("#697573"), Color("#3c291d"), true)
	var brass: StandardMaterial3D = _valley.material(Color("#ad7950"))
	brass.metallic = 0.58
	var case_frame := Node3D.new()
	add_child(case_frame)
	case_frame.position = _ground(_scene_at.x - 0.95, _scene_at.z - 0.62) + Vector3.UP * 0.18
	case_frame.rotation = Vector3(0.23, -0.54, 0.17)
	_valley.box(case_frame, Vector3.ZERO, Vector3(0.78, 0.33, 0.53), timber)
	for side: float in [-1.0, 1.0]:
		_valley.box(case_frame, Vector3(side * 0.27, 0.015, 0), Vector3(0.085, 0.36, 0.55), iron)
	var lid: MeshInstance3D = _valley.box(case_frame, Vector3(0, 0.39, 0.43), Vector3(0.78, 0.045, 0.54), timber)
	lid.rotation.x = 0.94
	_trace = Node3D.new()
	add_child(_trace)
	var seal := CylinderMesh.new()
	seal.top_radius = 0.10
	seal.bottom_radius = 0.11
	seal.height = 0.025
	_valley.place_mesh(_trace, seal, brass, _trace_at + Vector3.UP * 0.10)
	for i in range(4):
		var slot := _trace_at.lerp(_dispatch_at, float(i) * 0.14)
		var mark: MeshInstance3D = _valley.box(_trace, _ground(slot.x, slot.z) + Vector3.UP * 0.045,
			Vector3(0.11, 0.065, 0.46), timber)
		mark.rotation.y = -0.73
	_valley.box(self, _dispatch_at + Vector3.UP * 0.35, Vector3(0.22, 1.1, 0.27), steel)
	_valley.box(self, _dispatch_at + Vector3(0, 0.92, 0), Vector3(0.67, 0.71, 0.29), steel)
	_valley.box(self, _dispatch_at + Vector3(0, 0.98, 0.152), Vector3(0.56, 0.45, 0.035), iron)
	_gauge_face = _sign("INTAKE 04\nOUT OF SERVICE", _dispatch_at + Vector3(0, 1.02, 0.179), 0.0036)
	_gauge_off = _valley.material(Color("#713c31"))
	_gauge_on = _valley.material(Color("#6aca96"))
	_gauge_on.emission_enabled = true
	_gauge_on.emission = Color("#429a69")
	_gauge_on.emission_energy_multiplier = 1.8
	_gauge_indicator = _valley.box(self, _dispatch_at + Vector3(0.18, 1.17, 0.179), Vector3(0.038, 0.038, 0.015), _gauge_off)
	_valley.box(self, _dispatch_at + Vector3.UP * 1.30, Vector3(0.76, 0.06, 0.42), steel)
	for i in range(5):
		_valley.box(self, _dispatch_at + Vector3(-0.27, 0.68 + i * 0.052, 0.18), Vector3(0.045, 0.008, 0.009), brass)
	_satchel = _valley.box(self, _dispatch_at + Vector3(0.20, 0.63, 0.03), Vector3(0.22, 0.13, 0.16), timber)
	_build_work_shelter(wood, steel)
	_build_approach(wood, steel)
	_work_light(_scene_at + Vector3(0.25, 0.96, -1.06), iron, 6.7, 1.8)


func _build_work_shelter(wood: Material, steel: Material) -> void:
	var roof := _shelter_at + Vector3(-0.48, 2.40, -0.22)
	for x: float in [-1.25, 1.17]:
		for z: float in [-1.34, 1.34]:
			var post := _ground(roof.x + x, roof.z + z)
			var height := roof.y + x * 0.16 - post.y
			var post_center := post + Vector3.UP * height * 0.5
			var post_size := Vector3(0.13, height, 0.13)
			_valley.box(self, post_center, post_size, wood)
			_shelter_collision(post_center, post_size)
	for i in 14:
		var z := -1.53 + float(i) * 0.235
		var panel: MeshInstance3D = _valley.box(self, roof + Vector3(0, 0.06, z), Vector3(2.94, 0.055, 0.24), steel)
		panel.rotation.z = 0.16
		var rib: MeshInstance3D = _valley.box(self, roof + Vector3(0, 0.10, z - 0.106), Vector3(2.99, 0.045, 0.027), steel)
		rib.rotation.z = 0.16
	for i in 12:
		var z := roof.z - 1.32 + float(i) * 0.233
		var base := _ground(roof.x - 1.26, z)
		var height := roof.y - 0.20 - base.y
		_valley.box(self, base + Vector3.UP * height * 0.5, Vector3(0.075, height, 0.222), wood)
	_shelter_collision(roof + Vector3(-1.26, -0.99, 0), Vector3(0.09, 1.68, 2.72))
	_shelter_collision(roof + Vector3(0, 0.06, 0), Vector3(2.92, 0.085, 3.18), 0.16)
	var bench := _ground(roof.x - 0.84, roof.z - 0.29)
	_valley.box(self, bench + Vector3.UP * 0.78, Vector3(0.60, 0.09, 1.63), wood)
	for z: float in [-0.61, 0.61]:
		_valley.box(self, bench + Vector3(0, 0.40, z), Vector3(0.45, 0.78, 0.10), wood)
	_valley.box(self, bench + Vector3(0.04, 0.89, -0.35), Vector3(0.31, 0.20, 0.46), steel)
	_shelter_lamp = _work_light(roof + Vector3(0.76, -0.40, 1.28), steel, 7.2, 2.25)
	if DisplayServer.get_name() != "headless":
		_build_roof_rain(roof)


func _shelter_collision(at: Vector3, size: Vector3, lean := 0.0) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.collision_layer = 0
	_shelter_bodies.append(body)
	body.position = at
	body.rotation.z = lean


func _build_approach(wood: Material, steel: Material) -> void:
	var post := _ground(-5.95, -46.75)
	_valley.box(self, post + Vector3.UP * 0.92, Vector3(0.14, 1.84, 0.16), wood)
	_valley.box(self, post + Vector3(0, 1.49, 0.04), Vector3(1.18, 0.51, 0.10), steel)
	_sign("WINDGATE\nFLOOD GAUGE", post + Vector3(0, 1.49, 0.098), 0.0065)
	_work_light(post + Vector3(0, 1.92, 0.14), steel, 7.0, 1.7)
	var generator := RandomNumberGenerator.new()
	generator.seed = 8741
	var stone := SphereMesh.new()
	stone.radial_segments = 7
	stone.rings = 4
	var ballast := MultiMesh.new()
	ballast.transform_format = MultiMesh.TRANSFORM_3D
	ballast.mesh = stone
	ballast.instance_count = 165
	for i in ballast.instance_count:
		var at := Vector3(-4.0, 0, -43.5).lerp(Vector3(-6.8, 0, -58.9), generator.randf())
		at += Vector3(0.98, 0, -0.18) * generator.randf_range(-2.2, 2.2)
		at.y = _ground(at.x, at.z).y + 0.02
		var size := generator.randf_range(0.07, 0.23)
		var shape := Basis(Vector3.UP, generator.randf_range(0, TAU)).scaled(Vector3(size * 1.45, size * 0.50, size))
		ballast.set_instance_transform(i, Transform3D(shape, at))
	var gravel := MultiMeshInstance3D.new()
	gravel.multimesh = ballast
	gravel.material_override = _weathered(Color("#625d53"), Color("#2e3434"), false)
	gravel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gravel.visibility_range_end = 41.0
	add_child(gravel)
	_plant_bank(generator)


func _plant_bank(generator: RandomNumberGenerator) -> void:
	var needles: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 16:
		var place := _ground(generator.randf_range(0.5, 7.8) if i < 11 else generator.randf_range(-5.8, 1.8),
			generator.randf_range(-62.5, -46.2) if i < 11 else generator.randf_range(-70.0, -62.6))
		if place.y < 3.5:
			continue
		var size := generator.randf_range(0.74, 1.64)
		var heading := generator.randf_range(0.0, TAU)
		trunks.append(Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * size), place + Vector3.UP * size))
		for tier in 4:
			var width := size * (1.25 - float(tier) * 0.22)
			var shape := Basis(Vector3.UP, heading + tier * 0.71).scaled(Vector3(width, size * 0.79, width * 0.88))
			needles.append(Transform3D(shape, place + Vector3.UP * size * (1.40 + tier * 0.52)))
			colors.append(Color("#748778").lerp(Color("#a5a986"), generator.randf()))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.055
	trunk.bottom_radius = 0.13
	trunk.height = 2.0
	trunk.radial_segments = 6
	_bank_instances(trunk, _valley.material(Color("#53483e")), trunks, [])
	_bank_instances(_valley._bough_mesh(), _valley._forest_material(Color("#3b5545")), needles, colors)


func _bank_instances(mesh: Mesh, surface: Material, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var batch := MultiMesh.new()
	batch.mesh = mesh
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
		if batch.use_colors:
			batch.set_instance_color(i, colors[i])
	var plants := MultiMeshInstance3D.new()
	plants.multimesh = batch
	plants.material_override = surface
	plants.visibility_range_end = 60.0
	add_child(plants)


func _build_roof_rain(at: Vector3) -> void:
	const RATE := 22050
	const FRAMES := RATE * 3
	var sample := PackedByteArray()
	sample.resize(FRAMES * 2)
	var generator := RandomNumberGenerator.new()
	generator.seed = 214
	var tap := 0.0
	var low := 0.0
	for frame in FRAMES:
		var noise := generator.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.12)
		if generator.randf() < 0.004:
			tap = generator.randf_range(0.08, 0.49)
		tap *= 0.978
		var edge := smoothstep(0.0, 250.0, minf(frame, FRAMES - frame))
		var strike := sin(float(frame) * 0.47) * tap
		sample.encode_s16(frame * 2, int((low * 0.22 + strike) * edge * 32767.0))
	var loop := AudioStreamWAV.new()
	loop.format = AudioStreamWAV.FORMAT_16_BITS
	loop.mix_rate = RATE
	loop.data = sample
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = FRAMES
	_roof_rain = AudioStreamPlayer3D.new()
	_roof_rain.bus = &"Ambience"
	_roof_rain.stream = loop
	_roof_rain.max_distance = 16.0
	_roof_rain.unit_size = 3.2
	add_child(_roof_rain)
	_roof_rain.position = at


func _weathered(color: Color, stains: Color, metal: bool) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://flood_gauge_surfaces.gdshader")
	surface.set_shader_parameter("base_tint", color)
	surface.set_shader_parameter("wear_tint", stains)
	surface.set_shader_parameter("metal_surface", metal)
	_surfaces.append(surface)
	return surface


func _sign(text_value: String, at: Vector3, size: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = text_value
	sign.font_size = 32
	sign.pixel_size = size
	sign.outline_size = 0
	sign.modulate = Color("#e2d9bd")
	add_child(sign)
	sign.position = at
	return sign


func _work_light(at: Vector3, housing: Material, reach: float, energy: float) -> OmniLight3D:
	var glass: StandardMaterial3D = _valley.material(Color("#ffd4a2"))
	glass.emission_enabled = true
	glass.emission = Color("#ffba73")
	glass.emission_energy_multiplier = 2.0
	_valley.box(self, at, Vector3(0.15, 0.13, 0.13), glass)
	for y: float in [-0.082, 0.082]:
		_valley.box(self, at + Vector3.UP * y, Vector3(0.23, 0.045, 0.21), housing)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffb879")
	light.light_energy = energy
	light.omni_range = reach
	light.distance_fade_enabled = true
	light.distance_fade_begin = 32.0
	light.distance_fade_length = 12.0
	add_child(light)
	light.position = at + Vector3(0.0, -0.09, 0.13)
	return light


func _build_witness() -> void:
	_witness = Node3D.new()
	add_child(_witness)
	_coat = Node3D.new()
	_witness.add_child(_coat)
	_oilskin = _valley.material(Color("#44413c"))
	var wool: StandardMaterial3D = _valley.material(Color("#282e32"))
	var leather: StandardMaterial3D = _valley.material(Color("#272326"))
	var face: StandardMaterial3D = _valley.material(Color("#926e56"))
	var stitching: StandardMaterial3D = _valley.material(Color("#74614d"))
	var lamp_glass: StandardMaterial3D = _valley.material(Color("#ffbd75"))
	lamp_glass.emission_enabled = true
	lamp_glass.emission = lamp_glass.albedo_color
	lamp_glass.emission_energy_multiplier = 2.4
	var jacket := CylinderMesh.new()
	jacket.top_radius = 0.28
	jacket.bottom_radius = 0.37
	jacket.height = 0.81
	jacket.radial_segments = 12
	var body: MeshInstance3D = _valley.place_mesh(_coat, jacket, _oilskin, Vector3(0, 1.02, 0))
	body.scale.z = 0.74
	_valley.box(_coat, Vector3(0, 1.03, -0.249), Vector3(0.021, 0.63, 0.018), stitching).rotation.x = 0.076
	for side: float in [-1.0, 1.0]:
		var breast: MeshInstance3D = _valley.box(_coat, Vector3(side * 0.138, 1.14, -0.218),
			Vector3(0.122, 0.136, 0.03), _oilskin)
		breast.rotation.y = -side * 0.36
		_valley.box(_coat, Vector3(side * 0.138, 1.205, -0.232), Vector3(0.121, 0.022, 0.021),
			stitching).rotation.y = breast.rotation.y
	_round_part(_coat, Vector3(0, 1.39, 0.0), Vector3(0.67, 0.24, 0.40), wool)
	_round_part(_coat, Vector3(0, 1.64, 0.0), Vector3(0.41, 0.51, 0.40), _oilskin)
	_round_part(_coat, Vector3(0, 1.64, -0.128), Vector3(0.297, 0.383, 0.157), wool)
	_round_part(_coat, Vector3(0, 1.61, -0.147), Vector3(0.245, 0.32, 0.16), face)
	_round_part(_coat, Vector3(0, 1.52, -0.193), Vector3(0.24, 0.16, 0.12), wool)
	_round_part(_coat, Vector3(0, 1.62, -0.226), Vector3(0.057, 0.086, 0.058), face)
	for side: float in [-1.0, 1.0]:
		_round_part(_coat, Vector3(side * 0.055, 1.662, -0.214), Vector3(0.041, 0.016, 0.022), wool)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		_witness.add_child(leg)
		leg.position = Vector3(side * 0.134, 0.68, 0)
		_legs.append(leg)
		_round_part(leg, Vector3(0, -0.29, 0), Vector3(0.205, 0.60, 0.22), wool)
		_round_part(leg, Vector3(0, -0.58, -0.046), Vector3(0.21, 0.20, 0.34), leather)
		var arm := Node3D.new()
		_coat.add_child(arm)
		arm.position = Vector3(side * 0.31, 1.31, -0.04 if side > 0 else 0.02)
		_round_part(arm, Vector3(0, -0.25, 0), Vector3(0.22, 0.59, 0.23), _oilskin)
		_arms.append(arm)
		arm.rotation.z = side * 0.17
		arm.rotation.x = 0.31 if side > 0 else -0.08
		if side < 0:
			_round_part(arm, Vector3(0.023, -0.52, 0.0), Vector3(0.105, 0.14, 0.11), leather)
	_round_part(_coat, Vector3(0.36, 0.83, -0.20), Vector3(0.13, 0.17, 0.14), face)
	var lamp_at := Vector3(0.41, 0.65, -0.28)
	_valley.box(_coat, lamp_at, Vector3(0.13, 0.22, 0.13), lamp_glass)
	for y in [-0.11, 0.11]:
		_valley.box(_coat, lamp_at + Vector3.UP * y, Vector3(0.18, 0.04, 0.18), leather)
	for x in [-0.068, 0.068]:
		_valley.box(_coat, lamp_at + Vector3(x, 0.0, -0.067), Vector3(0.014, 0.22, 0.014), leather)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("#ffac65")
	_lamp.omni_range = 7.0
	_lamp.light_energy = 1.95
	_coat.add_child(_lamp)
	_lamp.position = lamp_at + Vector3(0.16, 0.05, -0.18)


func _round_part(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	var part: MeshInstance3D = _valley.place_mesh(parent, mesh, surface, at)
	part.scale = size
	return part


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _valley.surface_height_at(x, z), z)
