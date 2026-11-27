extends StaticBody3D
## Heightmap terrain: noise hills, flattened building zones, mountain rim, splat-textured with Poly Haven PBR maps.

const TEX := "res://assets/polyhaven/textures/%s/%s_%s.jpg"

var size := 900.0        # metres (square, centred on origin)
var res := 2.5           # collision + render grid cell size (m)
var amplitude := 7.0
var rim_height := 55.0
var rim_start := 340.0
var noise_freq := 0.006
var seed_value := 1
var flats: Array = []    # [{"pos": Vector3, "radius": float, "blend": float, "height": float}]
var hills: Array = []    # [{"pos": Vector3, "radius": float, "height": float}]
var layer_low := "forrest_ground_01"
var layer_mid := "dirt"
var layer_rock := "rocky_terrain_02"
var layer_high := ""      # optional snow
var snow_line := 999.0
var tint := Color(1, 1, 1)
var patch_a := Color(0.55, 0.62, 0.35)   # aerial colour patches (meadow)
var patch_b := Color(0.28, 0.33, 0.20)   # (forest floor)

var _noise: FastNoiseLite
var _noise2: FastNoiseLite
var _noise3: FastNoiseLite
var _grid := PackedFloat32Array()
var _n := 0


func setup() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.frequency = noise_freq
	_noise.fractal_octaves = 4
	_noise2 = FastNoiseLite.new()
	_noise2.seed = seed_value + 7
	_noise2.frequency = 0.03
	_noise3 = FastNoiseLite.new()
	_noise3.seed = seed_value + 13
	_noise3.frequency = 0.0025
	_noise3.fractal_octaves = 3
	collision_layer = 1
	collision_mask = 0
	_build_grid()
	_build_collision()
	_build_mesh()
	_build_horizon()
	_build_bounds()


func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * amplitude + _noise2.get_noise_2d(x, z) * 0.6
	for hl in hills:
		var d := Vector2(x - hl.pos.x, z - hl.pos.z).length()
		if d < hl.radius:
			var k: float = 1.0 - d / hl.radius
			h += hl.height * k * k * (3.0 - 2.0 * k)
	# mountain rim, continuing into far mountains beyond the playable square
	var half := size * 0.5
	var r := maxf(absf(x), absf(z))
	if r > rim_start:
		var k2 := clampf((r - rim_start) / (half - rim_start), 0.0, 1.0)
		h += rim_height * k2 * k2 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 12.0 * k2
		if r > half:
			var far := minf((r - half) / 900.0, 1.0)
			h += far * (60.0 + _noise3.get_noise_2d(x, z) * 140.0) + _noise.get_noise_2d(x * 1.7, z * 1.7) * 25.0 * far
	# flatten building zones
	for f in flats:
		var d2 := Vector2(x - f.pos.x, z - f.pos.z).length()
		if d2 < f.radius + f.blend:
			var w: float = 1.0 if d2 <= f.radius else 1.0 - (d2 - f.radius) / f.blend
			w = w * w * (3.0 - 2.0 * w)
			h = lerpf(h, f.height, w)
	return h


func _build_grid() -> void:
	_n = int(size / res) + 1
	_grid.resize(_n * _n)
	var half := size * 0.5
	for j in _n:
		for i in _n:
			_grid[j * _n + i] = height_at(-half + i * res, -half + j * res)


func _g(i: int, j: int) -> float:
	return _grid[clampi(j, 0, _n - 1) * _n + clampi(i, 0, _n - 1)]


func _build_collision() -> void:
	var hs := HeightMapShape3D.new()
	hs.map_width = _n
	hs.map_depth = _n
	hs.map_data = _grid
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3(res, 1.0, res)
	add_child(cs)


func _build_bounds() -> void:
	# invisible walls just inside the edge so nobody can walk, drive or glide off the map
	var half := size * 0.5 - 6.0
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.0 if d.x != 0 else size, 2000.0, size if d.x != 0 else 4.0)
		cs.shape = bs
		cs.position = d * (half + 2.0) + Vector3(0, 900, 0)
		add_child(cs)


func _tex(id: String, kind: String) -> Texture2D:
	var p := TEX % [id, id, kind]
	if ResourceLoader.exists(p):
		return load(p)
	return null


func _build_mesh() -> void:
	var n := _n
	var half := size * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(-half + i * res, _g(i, j), -half + j * res)
			var nx := _g(i - 1, j) - _g(i + 1, j)
			var nz := _g(i, j - 1) - _g(i, j + 1)
			normals[j * n + i] = Vector3(nx, 2.0 * res, nz).normalized()
	indices.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = a + n
			indices[k + 3] = a + 1
			indices[k + 4] = a + n + 1
			indices[k + 5] = a + n
			k += 6
	_add_mesh(verts, normals, indices)


## Coarse ring of distant mountains out to the horizon (render only).
func _build_horizon() -> void:
	var step := 50.0
	var half := size * 0.5
	var ext := 4000.0
	var n := int(ext * 2.0 / step) + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var x := -ext + i * step
			var z := -ext + j * step
			var inside := absf(x) < half - step and absf(z) < half - step
			var hh := height_at(x, z) - (30.0 if inside else 0.0)
			verts[j * n + i] = Vector3(x, hh, z)
	for j in n:
		for i in n:
			var hl := verts[j * n + maxi(i - 1, 0)].y
			var hr := verts[j * n + mini(i + 1, n - 1)].y
			var hd := verts[maxi(j - 1, 0) * n + i].y
			var hu := verts[mini(j + 1, n - 1) * n + i].y
			normals[j * n + i] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	for j in n - 1:
		for i in n - 1:
			var x0 := -ext + i * step
			var z0 := -ext + j * step
			# skip quads fully inside the detailed terrain
			if x0 >= -half and x0 + step <= half and z0 >= -half and z0 + step <= half:
				continue
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	_add_mesh(verts, normals, indices)


func _add_mesh(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 50.0
	add_child(mi)


func _material() -> ShaderMaterial:
	if _mat_cache != null:
		return _mat_cache
	var sm := ShaderMaterial.new()
	_mat_cache = sm
	sm.shader = load("res://scripts/world/terrain.gdshader")
	var layers := [["low", layer_low], ["mid", layer_mid], ["rock", layer_rock], ["high", layer_high if layer_high != "" else layer_rock]]
	for l in layers:
		var a := _tex(l[1], "albedo")
		var nrm := _tex(l[1], "normal")
		var rgh := _tex(l[1], "roughness")
		if a != null:
			sm.set_shader_parameter("alb_" + l[0], a)
		if nrm != null:
			sm.set_shader_parameter("nrm_" + l[0], nrm)
		if rgh != null:
			sm.set_shader_parameter("rgh_" + l[0], rgh)
	sm.set_shader_parameter("snow_line", snow_line)
	sm.set_shader_parameter("tint", tint)
	sm.set_shader_parameter("patch_a", patch_a)
	sm.set_shader_parameter("patch_b", patch_b)
	return sm


var _mat_cache: ShaderMaterial


var roads: Array = []


func on_road(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for r in roads:
		var pts: Array = r[0]
		for i in pts.size() - 1:
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < r[1] * 0.5 + 0.6:
				return true
	return false


## Flat ribbon mesh that follows the terrain (roads, paths).
func add_road(points: Array, width: float, tex_id := "asphalt_02", uv_scale := 0.25) -> void:
	roads.append([points.duplicate(), width])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var steps := maxi(int(a.distance_to(b) / 2.0), 1)
		for s in steps:
			pts.append(a.lerp(b, float(s) / steps))
	pts.append(points[points.size() - 1])
	var dist := 0.0
	var src := pts.duplicate()
	for i in pts.size():
		var p: Vector3 = src[i]
		var dir: Vector3 = (src[mini(i + 1, src.size() - 1)] - src[maxi(i - 1, 0)])
		dir.y = 0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		var l := p + side
		var r := p - side
		l.y = height_at(l.x, l.z) + 0.06
		r.y = height_at(r.x, r.z) + 0.06
		if i > 0:
			dist += p.distance_to(src[i - 1])
		pts[i] = [l, r, dist]
	for i in pts.size() - 1:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		var v0: float = p0[2] * uv_scale
		var v1: float = p1[2] * uv_scale
		for tri in [[p0[0], 0.0, v0], [p0[1], width * uv_scale, v0], [p1[0], 0.0, v1],
				[p0[1], width * uv_scale, v0], [p1[1], width * uv_scale, v1], [p1[0], 0.0, v1]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(tri[1], tri[2]))
			st.add_vertex(tri[0])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	var a := _tex(tex_id, "albedo")
	if a != null:
		mat.albedo_texture = a
		mat.normal_enabled = true
		mat.normal_texture = _tex(tex_id, "normal")
		mat.roughness_texture = _tex(tex_id, "roughness")
	else:
		mat.albedo_color = Color(0.2, 0.2, 0.2)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
