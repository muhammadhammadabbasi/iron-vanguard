extends Node3D
## Wind-swept grass clumps streamed in cells around the player (MultiMesh, no textures needed).

const CELL := 12.0

var terrain
var radius := 45.0
var density := 1.6          # clumps per square metre
var avoid: Array = []       # [[Vector3 centre, radius], ...] (bases, roads handled by terrain)
var base_col := Color(0.20, 0.27, 0.09)
var tip_col := Color(0.55, 0.62, 0.28)
var height := 0.5
var _cells := {}
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _queue: Array = []


func setup(t, quality: int, cols := []) -> void:
	terrain = t
	radius = [26.0, 42.0, 60.0][quality]
	density = [0.9, 1.5, 2.2][quality]
	if cols.size() == 2:
		base_col = cols[0]
		tip_col = cols[1]
	_mesh = _clump_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = _shader()
	_mat.set_shader_parameter("base_col", base_col)
	_mat.set_shader_parameter("tip_col", tip_col)
	_mat.set_shader_parameter("fade_end", radius)


func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for b in 9:
		var a := r.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.16)
		var face := r.randf() * TAU
		var w := r.randf_range(0.035, 0.06)
		var hgt := height * r.randf_range(0.6, 1.25)
		var lean := Vector3(cos(face + 1.3), 0, sin(face + 1.3)) * r.randf_range(0.05, 0.2) * hgt
		var side := Vector3(cos(face), 0, sin(face)) * w
		var p0 := off - side
		var p1 := off + side
		var mid_l := off - side * 0.55 + Vector3(0, hgt * 0.5, 0) + lean * 0.35
		var mid_r := off + side * 0.55 + Vector3(0, hgt * 0.5, 0) + lean * 0.35
		var tip := off + Vector3(0, hgt, 0) + lean
		var n := side.cross(Vector3.UP).normalized()
		for tri in [[p0, 0.0], [p1, 0.0], [mid_l, 0.5], [p1, 0.0], [mid_r, 0.5], [mid_l, 0.5], [mid_l, 0.5], [mid_r, 0.5], [tip, 1.0]]:
			st.set_normal((n + Vector3.UP * 1.5).normalized())
			st.set_uv(Vector2(0, tri[1]))
			st.add_vertex(tri[0])
	return st.commit()


func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform vec4 base_col : source_color;
uniform vec4 tip_col : source_color;
uniform float fade_end = 45.0;
varying float vh;
varying vec3 wp;
void vertex() {
	vh = UV.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wind = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.21) * 0.6 + sin(TIME * 3.1 + wp.x * 0.9) * 0.25;
	VERTEX.x += wind * 0.09 * vh * vh;
	VERTEX.z += wind * 0.05 * vh * vh;
	float d = length(wp - CAMERA_POSITION_WORLD);
	VERTEX *= 1.0 - smoothstep(fade_end * 0.7, fade_end, d);
}
void fragment() {
	float v = fract(sin(dot(floor(wp.xz * 0.7), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = mix(base_col.rgb, tip_col.rgb, vh) * mix(0.8, 1.15, v);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * vh;
}
"""
	return sh


func _process(_delta: float) -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or terrain == null:
		return
	var cam := get_viewport().get_camera_3d()
	var c: Vector3 = cam.global_position if cam != null else pl.global_position
	var ci := int(floor(c.x / CELL))
	var cj := int(floor(c.z / CELL))
	var rc := int(ceil(radius / CELL))
	var wanted := {}
	if c.y - terrain.height_at(c.x, c.z) < radius:
		for j in range(cj - rc, cj + rc + 1):
			for i in range(ci - rc, ci + rc + 1):
				var key := Vector2i(i, j)
				wanted[key] = true
				if not _cells.has(key) and not _queue.has(key):
					_queue.append(key)
	for key in _cells.keys():
		if not wanted.has(key):
			_cells[key].queue_free()
			_cells.erase(key)
	var built := 0
	while not _queue.is_empty() and built < 3:
		var k: Vector2i = _queue.pop_front()
		if wanted.has(k) and not _cells.has(k):
			_cells[k] = _build_cell(k)
			built += 1


func _build_cell(k: Vector2i) -> MultiMeshInstance3D:
	var r := RandomNumberGenerator.new()
	r.seed = hash(k)
	var count := int(CELL * CELL * density)
	var xforms := []
	for n in count:
		var x := (k.x + r.randf()) * CELL
		var z := (k.y + r.randf()) * CELL
		var ok := true
		for av in avoid:
			if Vector2(x - av[0].x, z - av[0].z).length() < av[1]:
				ok = false
				break
		if not ok or terrain.on_road(x, z):
			continue
		var y: float = terrain.height_at(x, z)
		var slope: float = absf(terrain.height_at(x + 0.6, z) - y) + absf(terrain.height_at(x, z + 0.6) - y)
		if slope > 0.45 or y > terrain.snow_line - 3.0:
			continue
		var s := r.randf_range(0.7, 1.35)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.2), s))
		xforms.append(Transform3D(b, Vector3(x, y - 0.03, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
