extends Node3D

const TERRAIN_STEP := 2.0
const TERRAIN_COLUMNS := 221
const TERRAIN_ROWS := 211
const TERRAIN_ORIGIN := Vector2(-220, -350)
const HANGING_COURT := Vector3(-37, 22, -104)

var rng := RandomNumberGenerator.new()
var relief := FastNoiseLite.new()
var rock_material: ShaderMaterial
var rune_material: StandardMaterial3D
var masonry: StandardMaterial3D
var trim: StandardMaterial3D
var water_level := 2.0


func _ready() -> void:
	rng.seed = 41928
	relief.seed = 717
	relief.frequency = 0.038
	relief.fractal_octaves = 4
	rock_material = ShaderMaterial.new()
	rock_material.shader = preload("res://valley.gdshader")
	masonry = material(Color("#655a48"))
	trim = material(Color("#938367"))
	rune_material = material(Color("#5afce5"))
	rune_material.emission_enabled = true
	rune_material.emission = Color("#45f9e0")
	rune_material.emission_energy_multiplier = 3.2
	_light_world()
	_build_terrain()
	_build_river()
	_build_landmarks()
	_plant_valley()


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


func _light_world() -> void:
	var environment := Environment.new()
	var sky_shader := ShaderMaterial.new()
	sky_shader.shader = preload("res://solstice_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_shader
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c4d9e9")
	environment.ambient_light_energy = 0.64
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a3bbb7")
	environment.fog_density = 0.00175
	environment.fog_sun_scatter = 0.07
	environment.fog_height = 18.0
	environment.fog_height_density = 0.006
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0019
	environment.volumetric_fog_albedo = Color("#e1dfbc")
	environment.volumetric_fog_anisotropy = 0.42
	environment.volumetric_fog_length = 104.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.47
	environment.glow_bloom = 0.025
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-23, -134, 0)
	sun.light_color = Color("#ffce91")
	sun.light_energy = 1.65
	sun.light_angular_distance = 1.5
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
	var ground := place_mesh(self, mesh, rock_material, Vector3.ZERO)
	ground.create_trimesh_collision()


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
	var water := ShaderMaterial.new()
	water.shader = preload("res://river.gdshader")
	place_mesh(self, surface.commit(), water, Vector3.ZERO)


func _build_landmarks() -> void:
	var island_material := rock_material.duplicate() as ShaderMaterial
	island_material.set_shader_parameter("floating_rock", true)
	for specification: Vector4 in [
		Vector4(-44, 53, -61, 16), Vector4(59, 69, -105, 19),
		Vector4(-53, 70, -156, 13), Vector4(96, 101, -198, 23),
		Vector4(12, 87, -248, 26), Vector4(-114, 103, -240, 25),
		Vector4(111, 71, -301, 20), Vector4(-130, 54, -126, 12)
	]:
		var center := Vector3(specification.x, specification.y, specification.z)
		var radius := specification.w
		var island := place_mesh(self, _island_mesh(radius), island_material, center)
		island.create_trimesh_collision()
		_make_spire(center + Vector3(0, 0.4, 0), radius * 0.83, radius * 0.105)
		for i in 5:
			var angle := float(i) * TAU / 5.0
			var offset := Vector3(cos(angle), 0, sin(angle)) * radius * 0.49
			_make_spire(center + offset, radius * rng.randf_range(0.19, 0.42), radius * 0.057)
	var court := place_mesh(self, _island_mesh(11.0), island_material, HANGING_COURT - Vector3.UP * 1.27)
	court.create_trimesh_collision()
	_waterfall(Vector3(-31.5, 51.5, -55), 33.0, 1.65)
	_waterfall(Vector3(47.0, 67.0, -95), 52.0, 2.4)
	_waterfall(Vector3(-31.0, 21.0, -96), 15.0, 0.92)
	_make_spire(Vector3(-20, height_at(-20, -158), -158), 58.0, 4.4)
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


func _make_spire(at: Vector3, height: float, radius: float) -> void:
	var spine := Node3D.new()
	add_child(spine)
	spine.position = at
	spine.rotation.y = rng.randf_range(0, TAU)
	_column(spine, height * 0.07, height * 0.17, radius * 1.26, radius * 1.44, trim)
	_column(spine, height * 0.44, height * 0.68, radius * 0.68, radius, masonry)
	_column(spine, height * 0.73, height * 0.043, radius * 0.91, radius * 0.88, trim)
	_column(spine, height * 0.80, height * 0.08, radius * 0.82, radius * 0.91, masonry)
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
	# The whole spire is static. Batch its trim, masonry and light in three surfaces.
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
	for i in 2400:
		var x := rng.randf_range(-164, 174)
		var z := rng.randf_range(-317, 54)
		var height := height_at(x, z)
		if height < 4.0 or absf(x - river_center(z)) < 11.0 or (absf(x) < 10.0 and z > -25.0):
			continue
		if relief.get_noise_2d(x * 0.43 + 152.0, z * 0.43) < -0.12:
			continue
		var size := rng.randf_range(0.62, 1.92)
		var at := Vector3(x, height, z)
		var yaw := rng.randf_range(0, TAU)
		trunks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), at + Vector3.UP * size))
		for tier in 3:
			var width := size * (1.36 - tier * 0.29)
			crowns.append(Transform3D(Basis(Vector3.UP, yaw + tier).scaled(Vector3(width, size, width)),
				at + Vector3.UP * size * (1.95 + tier * 0.68)))
			crown_colors.append(Color(0.57, 0.72, 0.41).lerp(Color(1.0, 0.87, 0.58), rng.randf()))
	var trunk := CylinderMesh.new()
	trunk.height = 2.0
	trunk.bottom_radius = 0.18
	trunk.top_radius = 0.10
	trunk.radial_segments = 5
	_instances(trunk, material(Color("#513c24")), trunks)
	_instances(_bough_mesh(), material(Color("#578442"), true), crowns, crown_colors)

	var blades: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	for i in 10500:
		var x := rng.randf_range(-76.0, 76.0)
		var z := rng.randf_range(-142.0, 39.0)
		var y := height_at(x, z)
		if y < 4.0 or (z > 1.5 and z < 13.0 and absf(x) < 2.9):
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
	var grass := material(Color("#82964d"))
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_instances(plant.commit(), grass, blades).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blossom := PrismMesh.new()
	blossom.size = Vector3(0.13, 0.13, 0.12)
	_instances(blossom, material(Color.WHITE, true), flowers, flower_colors).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _bough_mesh() -> ArrayMesh:
	const POINTS := 10
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_smooth_group(-1)
	for i in POINTS:
		var a := _bough_tip(i, POINTS)
		var b := _bough_tip(i + 1, POINTS)
		var upper_a := a * 0.62 + Vector3.UP * 0.48
		var upper_b := b * 0.62 + Vector3.UP * 0.48
		for point: Vector3 in [Vector3(0.09, 1.16, 0), upper_a, upper_b, upper_a, a, upper_b,
				upper_b, a, b, a, Vector3(0, -0.72, 0), b]:
			builder.add_vertex(point)
	builder.generate_normals()
	return builder.commit()


func _bough_tip(index: int, count: int) -> Vector3:
	var phase := float(index) * TAU / count
	var reach := 0.57 + 0.34 * float(index % 2) + 0.095 * cos(phase * 3.0)
	return Vector3(cos(phase) * reach, -0.94 + 0.3 * cos(phase * 5.0), sin(phase) * reach)


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
