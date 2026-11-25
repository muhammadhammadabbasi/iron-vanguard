extends StaticBody3D
## Heightmap terrain: noise hills, flattened building zones, mountain rim, splat-textured with Poly Haven PBR maps.

const TEX := "res://assets/polyhaven/textures/%s/%s_%s.jpg"

var size := 360          # metres (square, centred on origin)
var res := 1.0           # collision cell size (m)
var mesh_step := 2.0     # render mesh cell size (m)
var amplitude := 7.0
var rim_height := 55.0
var rim_start := 140.0
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

var _noise: FastNoiseLite
var _noise2: FastNoiseLite


func setup() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.frequency = noise_freq
	_noise.fractal_octaves = 4
	_noise2 = FastNoiseLite.new()
	_noise2.seed = seed_value + 7
	_noise2.frequency = 0.03
	collision_layer = 1
	collision_mask = 0
	_build_collision()
	_build_mesh()


func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * amplitude + _noise2.get_noise_2d(x, z) * 0.6
	for hl in hills:
		var d := Vector2(x - hl.pos.x, z - hl.pos.z).length()
		if d < hl.radius:
			var k: float = 1.0 - d / hl.radius
			h += hl.height * k * k * (3.0 - 2.0 * k)
	# mountain rim
	var r := maxf(absf(x), absf(z))
	if r > rim_start:
		var k2 := clampf((r - rim_start) / (size * 0.5 - rim_start), 0.0, 1.0)
		h += rim_height * k2 * k2 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 12.0 * k2
	# flatten building zones
	for f in flats:
		var d2 := Vector2(x - f.pos.x, z - f.pos.z).length()
		if d2 < f.radius + f.blend:
			var w: float = 1.0 if d2 <= f.radius else 1.0 - (d2 - f.radius) / f.blend
			w = w * w * (3.0 - 2.0 * w)
			h = lerpf(h, f.height, w)
	return h


func _build_collision() -> void:
	var n := int(size / res) + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	var half := size * 0.5
	for j in n:
		for i in n:
			data[j * n + i] = height_at(-half + i * res, -half + j * res)
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	hs.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hs
	add_child(cs)


func _tex(id: String, kind: String) -> Texture2D:
	var p := TEX % [id, id, kind]
	if ResourceLoader.exists(p):
		return load(p)
	return null


func _build_mesh() -> void:
	var n := int(size / mesh_step) + 1
	var half := size * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var x := -half + i * mesh_step
			var z := -half + j * mesh_step
			var h := height_at(x, z)
			verts[j * n + i] = Vector3(x, h, z)
			var e := 0.8
			var nx := height_at(x - e, z) - height_at(x + e, z)
			var nz := height_at(x, z - e) - height_at(x, z + e)
			normals[j * n + i] = Vector3(nx, 2.0 * e, nz).normalized()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
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
	add_child(mi)


func _material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
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
	return sm


## Flat ribbon mesh that follows the terrain (roads, paths).
func add_road(points: Array, width: float, tex_id := "asphalt_02", uv_scale := 0.25) -> void:
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
