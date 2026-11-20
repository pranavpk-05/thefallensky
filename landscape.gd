extends Node3D

const TERRAIN_STEP := 2.0
const TERRAIN_COLUMNS := 221
const TERRAIN_ROWS := 211
const TERRAIN_ORIGIN := Vector2(-220, -350)
const HANGING_COURT := Vector3(-37, 22, -104)
const SKY_ISLANDS := [
	Vector4(-44, 53, -61, 16), Vector4(59, 69, -105, 19),
	Vector4(-53, 70, -156, 13), Vector4(96, 101, -198, 23),
	Vector4(12, 87, -248, 26), Vector4(-114, 103, -240, 25),
	Vector4(111, 71, -301, 20), Vector4(-130, 54, -126, 12),
]

var rng := RandomNumberGenerator.new()
var relief := FastNoiseLite.new()
var rock_material: ShaderMaterial
var rune_material: StandardMaterial3D
var masonry: StandardMaterial3D
var trim: StandardMaterial3D
var water_level := 2.0
var storm_strength := 0.0
var environment: Environment
var sun: DirectionalLight3D
var sky_shader: ShaderMaterial

var _story_mood := 0.0
var _local_gloom := 0.0
var _world_time := 230.0
var _weather_sample := 0.0
var _quality := 2
var _rain: GPUParticles3D
var _grass_shader: ShaderMaterial
var _river_shader: ShaderMaterial
var _island_shader: ShaderMaterial
var _ground_cover: Array[MultiMeshInstance3D] = []
var _last_lightning := 0.0


func _ready() -> void:
	rng.seed = 41928
	relief.seed = 717
	relief.frequency = 0.038
	relief.fractal_octaves = 4
	rock_material = ShaderMaterial.new()
	rock_material.shader = preload("res://valley.gdshader")
	rock_material.set_shader_parameter("gravel_map", preload("res://assets/materials/wet-gravel.png"))
	masonry = material(Color("#655a48"))
	trim = material(Color("#938367"))
	rune_material = material(Color("#5afce5"))
	rune_material.emission_enabled = true
	rune_material.emission = Color("#72cdd0")
	rune_material.emission_energy_multiplier = 1.74
	_light_world()
	_build_terrain()
	_build_river()
	_build_landmarks()
	_build_horizon()
	_plant_valley()
	_build_rain()
	set_quality(_quality)
	_update_weather()


func set_frontier_mood(progress: float) -> void:
	_story_mood = clampf(progress, 0.0, 1.0)


func set_quality(level: int) -> void:
	_quality = clampi(level, 0, 3)
	if environment == null:
		return
	environment.volumetric_fog_enabled = _quality >= 2
	environment.ssao_enabled = _quality >= 2
	environment.ssil_enabled = _quality == 3
	environment.volumetric_fog_length = 92.0 if _quality < 3 else 138.0
	sun.directional_shadow_max_distance = [46.0, 75.0, 118.0, 155.0][_quality]
	get_viewport().scaling_3d_scale = [0.77, 0.89, 1.0, 1.0][_quality]
	for group in _ground_cover:
		group.visibility_range_end = [28.0, 42.0, 56.0, 76.0][_quality]
		group.visibility_range_end_margin = 8.0


func _process(delta: float) -> void:
	_world_time += delta
	var camera := get_viewport().get_camera_3d()
	var forest_gloom := 0.0
	if is_instance_valid(camera):
		forest_gloom = 1.0 - smoothstep(11.0, 52.0, camera.global_position.distance_to(Vector3(-50.0, 12.0, -64.0)))
		_rain.global_position = camera.global_position + Vector3(0.0, 12.0, 0.0)
	_local_gloom = lerpf(_local_gloom, forest_gloom, delta * 1.25)
	var phase := fposmod(_world_time + 3.1, 29.0)
	var flash := smoothstep(0.72, 0.97, storm_strength) * (
		exp(-pow((phase - 0.08) * 36.0, 2.0)) + 0.46 * exp(-pow((phase - 0.24) * 21.0, 2.0)))
	sun.light_energy += (flash - _last_lightning) * 0.85
	_last_lightning = flash
	_weather_sample += delta
	if _weather_sample > 0.20:
		_weather_sample = 0.0
		_update_weather()


func _update_weather() -> void:
	var cycle := 0.5 - 0.5 * cos(_world_time * TAU / 540.0)
	var forecast := 0.5 - 0.5 * cos(_world_time * TAU / 181.0)
	var night := maxf(smoothstep(0.33, 0.94, cycle), smoothstep(0.18, 0.97, _story_mood))
	var rain_target := forecast * (0.70 + _story_mood * 0.30)
	storm_strength = smoothstep(0.38, 0.94, rain_target)
	_rain.emitting = storm_strength > 0.10
	if _rain.emitting:
		_rain.amount_ratio = storm_strength * (0.54 if _quality < 2 else 1.0)
	environment.ambient_light_color = Color("#bacbd1").lerp(Color("#7893b5"), night)
	environment.ambient_light_energy = lerpf(0.47, 0.37, night) - _local_gloom * 0.065
	environment.fog_light_color = Color("#819497").lerp(Color("#354963"), night)
	environment.fog_density = 0.00155 + night * 0.0009 + storm_strength * 0.0035 + _local_gloom * 0.0014
	environment.fog_height_density = 0.0068 + 0.010 * storm_strength + 0.006 * _local_gloom
	environment.volumetric_fog_density = 0.0014 + 0.0050 * storm_strength + 0.0035 * _local_gloom
	environment.volumetric_fog_albedo = Color("#dbdfd0").lerp(Color("#99aec8"), night)
	sun.rotation_degrees = Vector3(lerpf(-17.0, -30.0, night), lerpf(-155.0, -199.0, night), 0.0)
	sun.light_color = Color("#ffcc8a").lerp(Color("#7dacec"), night)
	sun.light_energy = lerpf(1.48, 0.59, night) * (1.0 - storm_strength * 0.44) + _last_lightning * 0.85
	sky_shader.set_shader_parameter("night", night)
	sky_shader.set_shader_parameter("storm", storm_strength)
	sky_shader.set_shader_parameter("cloud_offset", Vector2(_world_time * 0.012, -_world_time * 0.007))
	rock_material.set_shader_parameter("wetness", storm_strength)
	_island_shader.set_shader_parameter("wetness", storm_strength)
	_river_shader.set_shader_parameter("storm", storm_strength)
	_grass_shader.set_shader_parameter("gusts", storm_strength)


func river_center(z: float) -> float:
	return 30.0 + 15.0 * sin(z * 0.021) + 6.0 * sin(z * 0.052)


func height_at(x: float, z: float) -> float:
	var start := 34.0 * exp(-pow(x / 26.0, 2.0) - pow((z - 15.0) / 22.0, 2.0))
	var left := 44.0 * exp(-pow((x + 102.0 + sin(z * 0.019) * 19.0) / 45.0, 2.0))
	var right := 57.0 * exp(-pow((x - 115.0 - sin(z * 0.023) * 22.0) / 47.0, 2.0))
	var ridge := (33.0 + 19.0 * sin(x * 0.039) + 11.0 * sin(x * 0.13)) * exp(-pow((z + 328.0) / 26.0, 2.0))
	var distance := absf(x - river_center(z))
	var valley := 7.0 + relief.get_noise_2d(x, z) * (6.0 + (left + right) * 0.30) + start + left + right + ridge
	return lerpf(-0.8 + relief.get_noise_2d(x * 0.7, z) * 1.2, valley, smoothstep(4.6, 12.5, distance))


func surface_height_at(x: float, z: float) -> float:
	# Match the two triangles per cell in _build_terrain when placing props between vertices.
	var grid := (Vector2(x, z) - TERRAIN_ORIGIN) / TERRAIN_STEP
	var column := clampi(floori(grid.x), 0, TERRAIN_COLUMNS - 2)
	var row := clampi(floori(grid.y), 0, TERRAIN_ROWS - 2)
	var u := clampf(grid.x - column, 0.0, 1.0)
	var v := clampf(grid.y - row, 0.0, 1.0)
	var corner := TERRAIN_ORIGIN + Vector2(column, row) * TERRAIN_STEP
	var right := height_at(corner.x + TERRAIN_STEP, corner.y)
	var lower := height_at(corner.x, corner.y + TERRAIN_STEP)
	if u + v <= 1.0:
		return height_at(corner.x, corner.y) * (1.0 - u - v) + right * u + lower * v
	return height_at(corner.x + TERRAIN_STEP, corner.y + TERRAIN_STEP) * (u + v - 1.0) \
		+ right * (1.0 - v) + lower * (1.0 - u)


func _light_world() -> void:
	environment = Environment.new()
	sky_shader = ShaderMaterial.new()
	sky_shader.shader = preload("res://solstice_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_shader
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a4c7ed")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#8eabbb")
	environment.fog_density = 0.00175
	environment.fog_sky_affect = 0.08
	environment.fog_sun_scatter = 0.13
	environment.fog_height = 18.0
	environment.fog_height_density = 0.006
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0019
	environment.volumetric_fog_albedo = Color("#e1dfbc")
	environment.volumetric_fog_anisotropy = 0.42
	environment.volumetric_fog_sky_affect = 0.13
	environment.volumetric_fog_length = 104.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.39
	environment.glow_bloom = 0.035
	environment.ssao_radius = 2.5
	environment.ssao_intensity = 1.15
	environment.ssao_power = 1.2
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-17, -155, 0)
	sun.light_color = Color("#ffce91")
	sun.light_energy = 1.65
	sun.light_angular_distance = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


func _build_terrain() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in TERRAIN_ROWS:
		var z := TERRAIN_ORIGIN.y + row * TERRAIN_STEP
		for column in TERRAIN_COLUMNS:
			var x := TERRAIN_ORIGIN.x + column * TERRAIN_STEP
			vertices.append(Vector3(x, height_at(x, z), z))
			var dx := height_at(x + 0.6, z) - height_at(x - 0.6, z)
			var dz := height_at(x, z + 0.6) - height_at(x, z - 0.6)
			normals.append(Vector3(-dx, 1.2, -dz).normalized())
			if row < TERRAIN_ROWS - 1 and column < TERRAIN_COLUMNS - 1:
				var i := row * TERRAIN_COLUMNS + column
				indices.append_array([i, i + 1, i + TERRAIN_COLUMNS, i + 1, i + TERRAIN_COLUMNS + 1, i + TERRAIN_COLUMNS])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := StaticBody3D.new()
	var floor := CollisionShape3D.new()
	floor.shape = mesh.create_trimesh_shape()
	ground.add_child(floor)
	add_child(ground)
	const CELLS := 28
	for row in range(0, TERRAIN_ROWS - 1, CELLS):
		for column in range(0, TERRAIN_COLUMNS - 1, CELLS):
			var width := mini(TERRAIN_COLUMNS - column, CELLS + 1)
			var height := mini(TERRAIN_ROWS - row, CELLS + 1)
			var positions := PackedVector3Array()
			var shading := PackedVector3Array()
			var faces := PackedInt32Array()
			for z in height:
				var first := (row + z) * TERRAIN_COLUMNS + column
				positions.append_array(vertices.slice(first, first + width))
				shading.append_array(normals.slice(first, first + width))
				if z < height - 1:
					for x in width - 1:
						var i := z * width + x
						faces.append_array([i, i + 1, i + width, i + 1, i + width + 1, i + width])
			arrays[Mesh.ARRAY_VERTEX] = positions
			arrays[Mesh.ARRAY_NORMAL] = shading
			arrays[Mesh.ARRAY_INDEX] = faces
			var patch := ArrayMesh.new()
			patch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			place_mesh(self, patch, rock_material, Vector3.ZERO)


func _build_river() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 211:
		var z := TERRAIN_ORIGIN.y + float(row) * 2.0
		var next_z := z + 2.0
		var left := Vector3(river_center(z) - 9.0, water_level, z)
		var right := Vector3(river_center(z) + 9.0, water_level, z)
		var next_left := Vector3(river_center(next_z) - 9.0, water_level, next_z)
		var next_right := Vector3(river_center(next_z) + 9.0, water_level, next_z)
		var corners := [left, right, next_left, next_right]
		for index: int in [0, 1, 2, 1, 3, 2]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(index % 2, row + index / 2.0))
			surface.add_vertex(corners[index])
	_river_shader = ShaderMaterial.new()
	_river_shader.shader = preload("res://river.gdshader")
	place_mesh(self, surface.commit(), _river_shader, Vector3.ZERO)


func _build_landmarks() -> void:
	_island_shader = rock_material.duplicate() as ShaderMaterial
	_island_shader.set_shader_parameter("floating_rock", true)
	for specification: Vector4 in SKY_ISLANDS:
		var center := Vector3(specification.x, specification.y, specification.z)
		var radius := specification.w
		var island := place_mesh(self, _island_mesh(radius), _island_shader, center)
		island.create_trimesh_collision()
		_make_spire(center + Vector3(0, 0.4, 0), radius * 0.83, radius * 0.105)
		for i in 5:
			var angle := float(i) * TAU / 5.0
			var offset := Vector3(cos(angle), 0, sin(angle)) * radius * 0.49
			_make_spire(center + offset, radius * rng.randf_range(0.19, 0.42), radius * 0.057)
	var court := place_mesh(self, _island_mesh(11.0), _island_shader, HANGING_COURT - Vector3.UP * 1.27)
	court.create_trimesh_collision()
	_waterfall(Vector3(-31.5, 51.5, -55), 33.0, 1.65)
	_waterfall(Vector3(47.0, 67.0, -95), 52.0, 2.4)
	_waterfall(Vector3(-31.0, 21.0, -96), 15.0, 0.92)
	_make_spire(Vector3(-20, height_at(-20, -158), -158), 61.0, 4.9, true)
	for x in [-34.0, -9.0]:
		_make_spire(Vector3(x, height_at(x, -168), -168), 32.0, 2.3)
	for i in 12:
		var x := rng.randf_range(-77.0, 10.0)
		var z := rng.randf_range(-199.0, -56.0)
		_make_spire(Vector3(x, height_at(x, z), z), rng.randf_range(2.5, 16.0), rng.randf_range(0.6, 1.65))
	var y := height_at(0, 10)
	for x in [-3.9, 3.9]:
		_make_spire(Vector3(x, height_at(x, 7), 7), 6.0, 0.75)
	for i in 8:
		var x := (i % 2) * 2.35 - 1.175
		var z := 11.0 - i * 1.14
		var slab := box(self, Vector3(x, height_at(x, z), z), Vector3(2.15, 0.36, 1.08), trim)
		slab.rotation.y = rng.randf_range(-0.16, 0.16)
	box(self, Vector3(0, y - 0.55, 10), Vector3(5.7, 1.05, 5.0), masonry)
	_ornament_islands()


func _ornament_islands() -> void:
	var extents := RandomNumberGenerator.new()
	extents.seed = 3917
	var splinters: Array[Transform3D] = []
	var canopy: Array[Transform3D] = []
	var rock_seed := rng.state
	var shard_mesh := _island_mesh(1.0)
	rng.state = rock_seed
	for island: Vector4 in SKY_ISLANDS:
		var at := Vector3(island.x, island.y, island.z)
		for i in 9:
			var phase := TAU * i / 9.0 + extents.randf_range(-0.18, 0.18)
			var heading := Vector3(cos(phase), 0.0, sin(phase))
			var size := island.w * extents.randf_range(0.065, 0.20)
			var rim := heading * island.w * extents.randf_range(0.78, 0.94)
			var fragments := Basis(Vector3.UP, phase).scaled(Vector3(size, size * 2.12, size * 0.81))
			splinters.append(Transform3D(fragments, at + rim - Vector3.UP * island.w * 0.12))
			if i % 3 == 0:
				size *= 0.68
				var drift := heading * island.w * extents.randf_range(1.10, 1.55)
				fragments = Basis(Vector3.FORWARD, extents.randf_range(-0.52, 0.52)).scaled(Vector3(size, size * 1.62, size))
				splinters.append(Transform3D(fragments, at + drift - Vector3.UP * island.w * 0.65))
			var crown := Basis(Vector3.UP, phase).scaled(Vector3.ONE * island.w * extents.randf_range(0.085, 0.135))
			canopy.append(Transform3D(crown, at + heading * island.w * 0.66 + Vector3.UP * island.w * 0.07))
	_chunked_instances(shard_mesh, _island_shader, splinters, [], 96.0)
	_chunked_instances(_bough_mesh(), material(Color("#526f42")), canopy, [], 96.0)


func _build_horizon() -> void:
	# These distant escarpments sit outside the playable collision mesh.
	for band in 3:
		var mesh := SurfaceTool.new()
		mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		var crest := PackedVector3Array()
		var toe := PackedVector3Array()
		for i in 67:
			var x := float(i - 33) * 15.0
			var z := -390.0 - float(band) * 118.0 + 20.0 * sin(x * 0.017 + band)
			var uplift := 36.0 + 19.0 * band + 27.0 * sin(x * 0.016 + band * 3.7)
			var facets := absf(relief.get_noise_2d(x * 1.25, z)) * 94.0
			crest.append(Vector3(x, uplift + facets, z))
			toe.append(Vector3(x, -9.0, z + 64.0))
		for i in 66:
			for point: Vector3 in [toe[i], crest[i], toe[i + 1], toe[i + 1], crest[i], crest[i + 1]]:
				mesh.add_vertex(point)
		mesh.generate_normals()
		var strata := material(Color("#374c50").lerp(Color("#5c7482"), float(band) * 0.36))
		strata.cull_mode = BaseMaterial3D.CULL_DISABLED
		var ridge := place_mesh(self, mesh.commit(), strata, Vector3.ZERO)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 760
	_rain.emitting = false
	_rain.lifetime = 1.05
	_rain.visibility_aabb = AABB(Vector3(-25, -32, -25), Vector3(50, 48, 50))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var drops := ParticleProcessMaterial.new()
	drops.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	drops.emission_box_extents = Vector3(21, 4, 21)
	drops.direction = Vector3(0.2, -1, 0.13).normalized()
	drops.spread = 4.0
	drops.initial_velocity_min = 15.0
	drops.initial_velocity_max = 22.0
	drops.gravity = Vector3(0, -11, 0)
	drops.scale_min = 0.8
	drops.scale_max = 1.45
	_rain.process_material = drops
	var streak := QuadMesh.new()
	streak.size = Vector2(0.022, 0.60)
	var wet := material(Color(0.65, 0.76, 0.87, 0.28))
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = wet
	_rain.draw_pass_1 = streak
	add_child(_rain)


func _waterfall(at: Vector3, drop: float, width: float) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(0, 0), Vector2(0.46, 0.04), Vector2(0.83, 0.15),
		Vector2(1.05, 0.48), Vector2(1.16, 0.77), Vector2(1.40, 1.0)]
	for row in profile.size() - 1:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var level: Vector2 = profile[row + corner.y]
			var x := (corner.x - 0.5) * width * (1.0 + level.y * 0.55)
			builder.set_uv(Vector2(corner.x, level.y))
			builder.add_vertex(Vector3(x + level.y * width * 0.3, -drop * level.y, level.x * 3.0))
	builder.generate_normals()
	var spray := ShaderMaterial.new()
	spray.shader = preload("res://cascade.gdshader")
	place_mesh(self, builder.commit(), spray, at).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _island_mesh(radius: float) -> ArrayMesh:
	const SIDES := 19
	var rings: Array[PackedVector3Array] = []
	for profile: Vector2 in [Vector2(0.0, 0.12), Vector2(0.57, 0.055), Vector2(1.0, -0.07),
			Vector2(0.92, -0.25), Vector2(0.53, -0.54), Vector2(0.20, -0.95), Vector2(0.0, -1.30)]:
		var ring := PackedVector3Array()
		for i in SIDES:
			var angle := float(i) * TAU / float(SIDES)
			var r := radius * profile.x * (0.90 + 0.14 * cos(angle * 3.0) + rng.randf_range(-0.13, 0.13))
			var y := radius * (profile.y + rng.randf_range(-0.06, 0.06) * profile.x)
			ring.append(Vector3(cos(angle) * r + radius * maxf(0, -profile.y) * 0.18, y, sin(angle) * r))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for row in rings.size() - 1:
		for i in SIDES:
			var next := (i + 1) % SIDES
			if row > 0:
				for vertex: Vector3 in [rings[row][i], rings[row + 1][i], rings[row][next]]:
					surface.add_vertex(vertex)
			if row < rings.size() - 2:
				for vertex: Vector3 in [rings[row][next], rings[row + 1][i], rings[row + 1][next]]:
					surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _make_spire(at: Vector3, height: float, radius: float, monumental := false) -> void:
	var spine := Node3D.new()
	add_child(spine)
	spine.position = at
	spine.rotation.y = rng.randf_range(0, TAU)
	_column(spine, height * 0.07, height * 0.17, radius * 1.26, radius * 1.44, trim)
	_column(spine, height * 0.44, height * 0.68, radius * 0.68, radius, masonry)
	_column(spine, height * 0.73, height * 0.043, radius * 0.91, radius * 0.88, trim)
	_column(spine, height * 0.80, height * 0.08, radius * 0.82, radius * 0.91, masonry)
	if monumental:
		spine.rotation.y = 0.21
		_crown_spire(spine, height, radius)
	else:
		_column(spine, height * 0.89, height * 0.027, radius * 0.65, radius * 0.72, rune_material)
		_column(spine, height * 0.945, height * 0.089, radius * 0.16, radius * 0.67, trim)
	for i in 4:
		var angle := i * TAU / 4.0
		var fin := box(spine, Vector3(sin(angle) * radius, height * 0.22, cos(angle) * radius),
			Vector3(radius * 0.32, height * 0.39, radius * 0.45), trim)
		fin.rotation.y = angle
		var glyph := box(spine, Vector3(sin(angle) * radius * 0.59, height * 0.59, cos(angle) * radius * 0.59),
			Vector3(radius * 0.12, height * 0.25, radius * 0.42), rune_material)
		glyph.rotation.y = angle
	_batch_stonework(spine)


func _crown_spire(spine: Node3D, height: float, radius: float) -> void:
	var weathered := ShaderMaterial.new()
	weathered.shader = preload("res://spire_stone.gdshader")
	_column(spine, radius * 0.22, radius * 0.44, radius * 2.45, radius * 2.52, weathered)
	_column(spine, radius * 0.65, radius * 0.42, radius * 1.98, radius * 2.22, weathered)
	_column(spine, height * 0.375, height * 0.63, radius * 0.83, radius * 1.32, weathered)
	_column(spine, height * 0.68, height * 0.052, radius * 1.12, radius * 1.08, trim)
	_column(spine, height * 0.70, height * 0.011, radius * 1.134, radius * 1.125, rune_material)
	for i in 4:
		var azimuth := (float(i) + 0.5) * TAU / 4.0
		var shoulder := Vector3(sin(azimuth), 0.0, cos(azimuth))
		var base := shoulder * radius * 1.52 + Vector3.UP * height * 0.14
		var upper := shoulder * radius * 0.86 + Vector3.UP * height * 0.65
		var buttress := box(spine, (base + upper) * 0.5,
			Vector3(radius * 0.42, base.distance_to(upper), radius * 0.58), weathered)
		buttress.quaternion = Quaternion(Vector3.UP, (upper - base).normalized())
		var strut := box(spine, base - Vector3.UP * (height * 0.03),
			Vector3(radius * 0.80, height * 0.23, radius * 0.80), weathered)
		strut.rotation.y = azimuth
	var oculus := Vector3(0, height * 0.955, 0)
	var stone_rim := TorusMesh.new()
	stone_rim.inner_radius = radius * 0.77
	stone_rim.outer_radius = radius * 1.28
	stone_rim.rings = 32
	stone_rim.ring_segments = 8
	place_mesh(spine, stone_rim, weathered, oculus).rotation.x = PI * 0.5
	var inner_rim := TorusMesh.new()
	inner_rim.inner_radius = radius * 0.731
	inner_rim.outer_radius = radius * 0.80
	inner_rim.rings = 32
	inner_rim.ring_segments = 6
	place_mesh(spine, inner_rim, rune_material, oculus + Vector3.BACK * radius * 0.11).rotation.x = PI * 0.5
	var lens := PrismMesh.new()
	lens.size = Vector3(radius * 0.52, radius * 0.96, radius * 0.52)
	place_mesh(spine, lens, rune_material, oculus).rotation.z = PI
	for i in 11:
		var angle := (float(i) + 0.5) * TAU / 12.0
		var stone := box(spine, oculus + Vector3(sin(angle), cos(angle), 0) * radius * 1.21,
			Vector3(radius * 0.27, radius * 0.38, radius * 0.56), trim)
		stone.rotation.z = -angle


func _batch_stonework(spine: Node3D) -> void:
	# Consolidate static parts to one draw per material and shadow pass.
	var batches := {}
	for child: MeshInstance3D in spine.get_children():
		var surface := child.material_override
		if not batches.has(surface):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(surface)
			batches[surface] = builder
		batches[surface].append_from(child.mesh, 0, child.transform)
		spine.remove_child(child)
		child.queue_free()
	var combined := ArrayMesh.new()
	for builder: SurfaceTool in batches.values():
		builder.commit(combined)
	place_mesh(spine, combined, null, Vector3.ZERO)


func _plant_valley() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var birches: Array[Transform3D] = []
	var birch_colors: Array[Color] = []
	for i in 3200:
		var x := rng.randf_range(-164, 174) if i < 2400 else rng.randf_range(-78, -30)
		var z := rng.randf_range(-317, 54) if i < 2400 else rng.randf_range(-93, -34)
		var height := height_at(x, z)
		if height < 4.0 or absf(x - river_center(z)) < 11.0 or _clearing(x, z):
			continue
		var grove := relief.get_noise_2d(x * 0.4 + 152.0, z * 0.43)
		if grove < -0.12 or (height > 48.0 and grove < 0.21):
			continue
		var size := rng.randf_range(0.57, 1.56) + maxf(0.0, grove) * 1.28
		var at := Vector3(x, height, z)
		var yaw := rng.randf_range(0, TAU)
		trunks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), at + Vector3.UP * size))
		if i % 5 == 0:
			var birch := Basis(Vector3.UP, yaw).scaled(Vector3(1.56, 1.26, 1.56) * size)
			birches.append(Transform3D(birch, at + Vector3.UP * size * 2.43))
			birch_colors.append(Color("#828b42").lerp(Color("#c48a42"), rng.randf() * 0.74))
			continue
		for tier in 3:
			var width := size * (1.45 - tier * 0.30)
			var crown_basis := Basis(Vector3.UP, yaw + tier).scaled(Vector3(width, size * 0.93, width * 0.82))
			crowns.append(Transform3D(crown_basis, at + Vector3(cos(yaw) * tier * 0.11,
				size * (1.82 + tier * 0.65), sin(yaw) * tier * 0.11)))
			crown_colors.append(Color(0.52, 0.73, 0.62).lerp(Color(0.96, 0.92, 0.59), rng.randf()))
	var trunk := CylinderMesh.new()
	trunk.height = 2.0
	trunk.bottom_radius = 0.18
	trunk.top_radius = 0.10
	trunk.radial_segments = 5
	_chunked_instances(trunk, _forest_material(Color("#493327")), trunks, [], 78.0)
	_chunked_instances(_bough_mesh(), _forest_material(Color("#49723f")), crowns, crown_colors, 78.0)
	_chunked_instances(_broadleaf_mesh(), _forest_material(Color("#aeb46b")), birches, birch_colors, 78.0)

	var blades: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	for i in 15200:
		var x := rng.randf_range(-76.0, 76.0)
		var z := rng.randf_range(-142.0, 39.0)
		if i < 5200:
			x = rng.randf_range(-15, 15)
			z = rng.randf_range(-26, 19)
		var y := height_at(x, z)
		if y < 4.0 or (z > 1.0 and z < 21.0 and absf(x) < 3.8) or _forest_path(x, z) < 1.1:
			continue
		var amount := rng.randf_range(0.36, 1.05)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(amount, amount, amount))
		blades.append(Transform3D(basis, Vector3(x, y - 0.08, z)))
		if i % 7 == 0:
			flowers.append(Transform3D(basis, Vector3(x, y + amount * 0.39, z)))
			flower_colors.append(Color("#dbc272") if i % 14 == 0 else Color("#afaaa4"))
	var plant := SurfaceTool.new()
	plant.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var turn := Basis(Vector3.UP, i * TAU / 5.0)
		for point: Vector3 in [Vector3(-0.065, 0, 0), Vector3(0.065, 0, 0), Vector3(0.21, 0.48 + i * 0.052, 0.05)]:
			plant.add_vertex(turn * point)
	plant.generate_normals()
	_grass_shader = ShaderMaterial.new()
	_grass_shader.shader = preload("res://frontier_grass.gdshader")
	_ground_cover.append_array(_chunked_instances(plant.commit(), _grass_shader, blades, [], 23.0, false))
	var blossom := PrismMesh.new()
	blossom.size = Vector3(0.13, 0.13, 0.12)
	_ground_cover.append_array(_chunked_instances(blossom, _forest_material(Color.WHITE, Vector2(0.36, 1.36)),
		flowers, flower_colors, 23.0, false))
	_place_undergrowth()


func _clearing(x: float, z: float) -> bool:
	var runway := absf(x + 17.0) < 9.0 and ((z > -122.0 and z < -17.0) or (z > -284.0 and z < -176.0))
	return runway or (absf(x) < 12.0 and z > -26.0) \
		or Vector2(x + 52.0, z + 65.0).length_squared() < 144.0 \
		or Vector2(x - 7.0, z - 10.0).length_squared() < 100.0 \
		or Vector2(x + 21.0, z + 151.0).length_squared() < 25.0 \
		or _forest_path(x, z) < 3.2


func _forest_path(x: float, z: float) -> float:
	var trailhead := Vector2(-32.0, -38.0)
	var curve := Vector2(-21.0, -27.0)
	var offset := Vector2(x, z) - trailhead
	var progress := clampf(offset.dot(curve) / curve.length_squared(), 0.0, 1.0)
	return (offset - curve * progress).length()


func _forest_material(color: Color, fade := Vector2(1.06, 3.15)) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://frontier_canopy.gdshader")
	surface.set_shader_parameter("foliage", color)
	surface.set_shader_parameter("near_fade", fade)
	return surface


func _place_undergrowth() -> void:
	var stones: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for i in 1050:
		var x := rng.randf_range(-128.0, 134.0)
		var z := rng.randf_range(-284.0, 36.0)
		if i < 430:
			x = rng.randf_range(-72.0, 34.0)
			z = rng.randf_range(-90.0, 28.0)
		var y := height_at(x, z)
		if y < 3.9 or _clearing(x, z):
			continue
		var radius := rng.randf_range(0.38, 1.52)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius, radius * rng.randf_range(0.58, 1.15), radius))
		var at := Vector3(x, y - 0.22, z)
		if i % 3 == 0:
			stones.append(Transform3D(b, at))
		else:
			ferns.append(Transform3D(b, at))
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 3
	rock.radius = 0.94
	rock.height = 1.75
	_chunked_instances(rock, rock_material, stones, [], 62.0)
	_ground_cover.append_array(_chunked_instances(_fern_mesh(), _grass_shader, ferns, [], 23.0, false))


func _broadleaf_mesh() -> ArrayMesh:
	var source := SphereMesh.new()
	source.radial_segments = 8
	source.rings = 4
	source.radius = 0.83
	source.height = 1.2
	var clusters := SurfaceTool.new()
	clusters.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var angle := i * TAU / 5.0
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(0.84, 0.92 + 0.25 * cos(angle * 2.0), 0.82))
		clusters.append_from(source, 0, Transform3D(basis, Vector3(cos(angle) * 0.45, sin(angle * 3.0) * 0.21, sin(angle) * 0.45)))
	return clusters.commit()


func _fern_mesh() -> ArrayMesh:
	var fronds := SurfaceTool.new()
	fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var turn := Basis(Vector3.UP, i * TAU / 6.0)
		for j in 4:
			var t := float(j + 1) / 4.0
			var stem := Vector3(t * 0.85, sin(t * 2.0) * 0.52 + t * 0.1, 0.0)
			var spread := 0.24 - t * 0.14
			for point: Vector3 in [stem, stem + Vector3(0.24, 0.058, -spread),
					stem + Vector3(0.13, 0.045, 0), stem,
					stem + Vector3(0.13, 0.045, 0), stem + Vector3(0.24, 0.058, spread)]:
				fronds.add_vertex(turn * point)
	fronds.generate_normals()
	return fronds.commit()


func _chunked_instances(mesh: Mesh, surface: Material, transforms: Array[Transform3D], colors: Array[Color],
		cell_size: float, shadows := true) -> Array[MultiMeshInstance3D]:
	var cells := {}
	var groups: Array[MultiMeshInstance3D] = []
	for i in transforms.size():
		var at := transforms[i].origin
		var cell := Vector2i(floori(at.x / cell_size), floori(at.z / cell_size))
		if not cells.has(cell):
			cells[cell] = PackedInt32Array()
		cells[cell].append(i)
	for cell: Vector2i in cells:
		var local: Array[Transform3D] = []
		var tint: Array[Color] = []
		var center := Vector3((cell.x + 0.5) * cell_size, 0, (cell.y + 0.5) * cell_size)
		var indices: PackedInt32Array = cells[cell]
		for i in indices:
			center.y += transforms[i].origin.y
		center.y /= indices.size()
		for i in indices:
			var placement := transforms[i]
			placement.origin -= center
			local.append(placement)
			if not colors.is_empty():
				tint.append(colors[i])
		var group := _instances(mesh, surface, local, tint)
		group.position = center
		if not shadows:
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		groups.append(group)
	return groups


func _bough_mesh() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm in 7:
		var yaw := Basis(Vector3.UP, float(arm) * TAU / 7.0 + sin(arm * 2.4) * 0.16)
		var reach := 0.80 + sin(arm * 3.95) * 0.17
		var base := Vector3(0.02, 0.55 - arm * 0.062, 0)
		var tip := Vector3(reach, -0.63 + sin(arm * 2.0) * 0.16, 0.033)
		var mid := base.lerp(tip, 0.55)
		for side: float in [-1.0, 1.0]:
			var feather := mid + Vector3(-0.14, -0.17, 0.25 * side)
			var near := base.lerp(tip, 0.26) + Vector3(-0.08, -0.12, 0.18 * side)
			var far := base.lerp(tip, 0.80) + Vector3(-0.07, -0.08, 0.17 * side)
			for point: Vector3 in [base, near, mid, mid, near, feather, mid, feather, far, mid, far, tip]:
				builder.add_vertex(yaw * point)
	builder.generate_normals()
	return builder.commit()


func _instances(mesh: Mesh, surface: Material, transforms: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
		if batch.use_colors:
			batch.set_instance_color(i, colors[i])
	var group := MultiMeshInstance3D.new()
	group.multimesh = batch
	group.material_override = surface
	add_child(group)
	return group


func _column(parent: Node3D, y: float, height: float, top: float, bottom: float, surface: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.radial_segments = 8
	mesh.rings = 0
	place_mesh(parent, mesh, surface, Vector3(0, y, 0))


func box(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return place_mesh(parent, mesh, surface, at)


func place_mesh(parent: Node3D, mesh: Mesh, surface: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	parent.add_child(instance)
	instance.position = at
	return instance


func material(color: Color, vertex_color := false) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.89
	surface.vertex_color_use_as_albedo = vertex_color
	return surface
