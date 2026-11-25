extends Node
## Materials + visual effects (impacts, tracers, explosions). Autoloaded as "Fx".

var mats := {}
var pmesh := {}
var ramps := {}
var holes: Array = []


func _ready() -> void:
	_build_materials()
	_build_particles()


func root() -> Node:
	var cs := get_tree().current_scene
	if cs == null:
		return null
	var a := cs.get_node_or_null("Actors")
	return a if a != null else cs


# ---------------------------------------------------------------- materials

func _std(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _noise_mat(c1: Color, c2: Color, freq: float, sd: int, scale: float, rough := 0.95) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.frequency = freq
	n.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	tex.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	return m


func _emit(color: Color, energy: float, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _pmat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# soft round particle
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	gt.gradient = g
	m.albedo_texture = gt
	return m


func _build_materials() -> void:
	mats["ground"] = _noise_mat(Color(0.20, 0.17, 0.13), Color(0.36, 0.30, 0.22), 0.05, 3, 0.08)
	mats["road"] = _noise_mat(Color(0.16, 0.15, 0.14), Color(0.27, 0.25, 0.22), 0.09, 8, 0.15)
	mats["concrete"] = _noise_mat(Color(0.38, 0.37, 0.35), Color(0.56, 0.54, 0.50), 0.08, 11, 0.25)
	mats["concrete_dark"] = _noise_mat(Color(0.22, 0.22, 0.22), Color(0.34, 0.33, 0.32), 0.08, 12, 0.25)
	mats["plaster"] = _noise_mat(Color(0.50, 0.42, 0.32), Color(0.66, 0.57, 0.44), 0.06, 21, 0.2)
	mats["roof"] = _noise_mat(Color(0.20, 0.19, 0.18), Color(0.30, 0.27, 0.24), 0.1, 22, 0.3)
	mats["rock"] = _noise_mat(Color(0.27, 0.25, 0.23), Color(0.48, 0.44, 0.39), 0.12, 5, 0.18)
	mats["sandbag"] = _noise_mat(Color(0.45, 0.39, 0.28), Color(0.58, 0.51, 0.38), 0.3, 6, 0.6)
	mats["wood"] = _noise_mat(Color(0.28, 0.19, 0.11), Color(0.42, 0.30, 0.18), 0.2, 7, 0.5)
	mats["rust"] = _noise_mat(Color(0.30, 0.15, 0.08), Color(0.45, 0.28, 0.16), 0.15, 9, 0.4, 0.8)
	mats["metal"] = _std(Color(0.26, 0.27, 0.28), 0.5, 0.6)
	mats["crate"] = _std(Color(0.24, 0.29, 0.17), 0.8)
	mats["ammo_stripe"] = _std(Color(0.85, 0.65, 0.12), 0.6)
	mats["mountain"] = _std(Color(0.16, 0.15, 0.18), 1.0)
	mats["tire"] = _std(Color(0.05, 0.05, 0.05), 0.9)
	mats["glass"] = _std(Color(0.05, 0.07, 0.09), 0.1, 0.3)
	mats["heli"] = _std(Color(0.18, 0.21, 0.17), 0.6, 0.3)
	mats["truck"] = _std(Color(0.30, 0.31, 0.22), 0.75, 0.2)
	mats["burnt"] = _std(Color(0.09, 0.08, 0.07), 0.95)
	mats["red_barrel"] = _std(Color(0.55, 0.08, 0.05), 0.55, 0.3)
	mats["fuel_tank"] = _std(Color(0.55, 0.55, 0.52), 0.6, 0.4)
	mats["gun_metal"] = _std(Color(0.08, 0.08, 0.09), 0.45, 0.6)
	mats["gun_dark"] = _std(Color(0.13, 0.13, 0.12), 0.7, 0.2)
	var g2: StandardMaterial3D = mats["gun_dark"].duplicate()
	g2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["gun_dark_2s"] = g2
	mats["gun_tan"] = _std(Color(0.24, 0.22, 0.17), 0.85)
	mats["sleeve"] = _noise_mat(Color(0.20, 0.23, 0.15), Color(0.36, 0.36, 0.24), 0.9, 30, 4.0, 0.9)
	mats["glove"] = _std(Color(0.10, 0.09, 0.08), 0.8)
	mats["skin"] = _std(Color(0.55, 0.40, 0.30), 0.7)
	mats["enemy_cloth"] = _std(Color(0.44, 0.38, 0.27), 0.9)
	mats["enemy_vest"] = _std(Color(0.18, 0.19, 0.14), 0.85)
	mats["enemy_scarf"] = _std(Color(0.45, 0.07, 0.06), 0.9)
	mats["boot"] = _std(Color(0.12, 0.10, 0.08), 0.8)
	mats["lamp"] = _emit(Color(1.0, 0.78, 0.45), 4.0, true)
	mats["screen"] = _emit(Color(0.35, 0.65, 1.0), 2.5, true)
	mats["red_dot"] = _emit(Color(1.0, 0.1, 0.05), 6.0, true)
	mats["lz"] = _std(Color(0.75, 0.72, 0.62), 0.9)
	mats["map"] = _std(Color(0.70, 0.64, 0.48), 0.9)
	var fl := _emit(Color(1.0, 0.7, 0.3), 8.0, true)
	fl.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["flash"] = fl
	var tr := _emit(Color(1.0, 0.85, 0.5), 6.0, true)
	tr.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["tracer"] = tr
	# bullet hole
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.albedo_color = Color(0.02, 0.02, 0.02)
	var gt := GradientTexture2D.new()
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	gt.gradient = g
	hm.albedo_texture = gt
	mats["hole"] = hm


func _quad(size: float, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _pmat(additive)
	return q


func _ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _build_particles() -> void:
	pmesh["spark"] = _quad(0.07, true)
	pmesh["dust"] = _quad(0.35, false)
	pmesh["blood"] = _quad(0.18, false)
	pmesh["fire"] = _quad(1.1, true)
	pmesh["smoke"] = _quad(2.2, false)
	pmesh["flash"] = _quad(0.6, true)
	var db := BoxMesh.new()
	db.size = Vector3(0.12, 0.12, 0.12)
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.roughness = 1.0
	db.material = dm
	pmesh["debris"] = db
	ramps["spark"] = _ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.1, 0)], [0.0, 1.0])
	ramps["dust"] = _ramp([Color(0.45, 0.40, 0.33, 0.7), Color(0.4, 0.36, 0.3, 0)], [0.0, 1.0])
	ramps["blood"] = _ramp([Color(0.45, 0.02, 0.02, 0.9), Color(0.3, 0.0, 0.0, 0)], [0.0, 1.0])
	ramps["fire"] = _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.45, 0.1, 0.9), Color(0.25, 0.1, 0.05, 0)], [0.0, 0.35, 1.0])
	ramps["smoke"] = _ramp([Color(0.2, 0.19, 0.18, 0.0), Color(0.22, 0.21, 0.2, 0.65), Color(0.3, 0.29, 0.28, 0)], [0.0, 0.15, 1.0])
	ramps["debris"] = _ramp([Color(0.15, 0.13, 0.11, 1), Color(0.15, 0.13, 0.11, 1)], [0.0, 1.0])
	ramps["green_smoke"] = _ramp([Color(0.3, 0.9, 0.35, 0.0), Color(0.3, 0.85, 0.35, 0.55), Color(0.4, 0.7, 0.45, 0)], [0.0, 0.1, 1.0])
	ramps["flash"] = _ramp([Color(1, 0.8, 0.4, 1), Color(1, 0.6, 0.2, 0)], [0.0, 1.0])


# ---------------------------------------------------------------- effects

func _particles(pos: Vector3, dir: Vector3, amount: int, life: float, vmin: float, vmax: float,
		spread: float, grav: Vector3, mesh_name: String, ramp_name: String, smin := 1.0, smax := 1.0) -> CPUParticles3D:
	var r := root()
	if r == null:
		return null
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.mesh = pmesh[mesh_name]
	p.color_ramp = ramps[ramp_name]
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.4, false).timeout.connect(p.queue_free)
	return p


func impact(pos: Vector3, normal: Vector3, flesh: bool) -> void:
	if flesh:
		_particles(pos, normal, 10, 0.45, 1.0, 3.0, 40.0, Vector3(0, -6, 0), "blood", "blood", 0.6, 1.4)
	else:
		_particles(pos, normal, 8, 0.35, 3.0, 7.0, 35.0, Vector3(0, -9.8, 0), "spark", "spark", 0.5, 1.2)
		_particles(pos, normal, 5, 0.9, 0.5, 1.6, 25.0, Vector3(0, 0.3, 0), "dust", "dust", 0.7, 1.4)
		if randf() < 0.5:
			Sfx.play3d("impact", pos, -12.0, 30.0, 0.2)


func bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var r := root()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11)
	mi.mesh = q
	mi.material_override = mats["hole"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = pos + normal * 0.012
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.look_at(mi.global_position + normal, up)
	holes.append(mi)
	while holes.size() > 80:
		var old = holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func muzzle_flash(pos: Vector3) -> void:
	var r := root()
	if r == null:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.omni_range = 6.0
	l.light_energy = 2.5
	r.add_child(l)
	l.global_position = pos
	var p := _particles(pos, Vector3.UP, 1, 0.06, 0.0, 0.0, 0.0, Vector3.ZERO, "flash", "flash", 1.0, 1.4)
	if p != null:
		p.explosiveness = 1.0
	get_tree().create_timer(0.05, false).timeout.connect(l.queue_free)


func tracer(from: Vector3, to: Vector3) -> void:
	var r := root()
	if r == null:
		return
	var dir := to - from
	var length := dir.length()
	if length < 2.0:
		return
	dir /= length
	var seg := minf(length * 0.5, 5.0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, seg)
	mi.mesh = bm
	mi.material_override = mats["tracer"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = from + dir * seg * 0.5
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.look_at(to, up)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to - dir * seg * 0.5, maxf(length / 320.0, 0.02))
	tw.tween_callback(mi.queue_free)


func smoke_emitter(pos: Vector3) -> CPUParticles3D:
	var r := root()
	if r == null:
		return null
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.6, 0.4, 0.0)
	p.mesh = pmesh["smoke"]
	p.color_ramp = ramps["green_smoke"]
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


func explosion(pos: Vector3, radius: float, damage: float) -> void:
	var r := root()
	if r == null:
		return
	Sfx.play3d("explosion", pos, 8.0, 320.0, 0.08)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = radius * 3.0
	l.light_energy = 8.0
	r.add_child(l)
	l.global_position = pos + Vector3.UP
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.7)
	tw.tween_callback(l.queue_free)
	_particles(pos, Vector3.UP, 28, 0.8, 2.0, 8.0, 85.0, Vector3(0, 2, 0), "fire", "fire", 1.0, 2.6)
	_particles(pos, Vector3.UP, 18, 3.5, 1.0, 3.5, 60.0, Vector3(0, 1.0, 0), "smoke", "smoke", 1.2, 2.6)
	_particles(pos, Vector3.UP, 22, 1.8, 5.0, 13.0, 65.0, Vector3(0, -14, 0), "debris", "debris", 0.5, 1.4)
	# scorch mark
	var space := r.get_viewport().get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 2.0, 1))
	if not down.is_empty():
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(radius * 0.7, radius * 0.7)
		mi.mesh = q
		mi.material_override = mats["hole"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(mi)
		mi.global_position = down.position + Vector3.UP * 0.02
		mi.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	# damage
	for n in get_tree().get_nodes_in_group("damageable"):
		if not (n is Node3D) or not n.has_method("take_damage"):
			continue
		var center: Vector3 = n.global_position + Vector3.UP * 0.7
		var d := center.distance_to(pos)
		if d > radius:
			continue
		var los := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.2, center, 1))
		if not los.is_empty() and los.collider != n:
			continue
		var amt := damage * clampf(1.0 - d / radius, 0.15, 1.0)
		if n.is_in_group("player"):
			amt *= 0.7
		n.take_damage(amt, pos, false, "explosion")
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null:
		var pd: float = pl.global_position.distance_to(pos)
		pl.add_shake(clampf(1.0 - pd / (radius * 4.0), 0.0, 1.0) * 0.9)


# ---------------------------------------------------------------- Poly Haven PBR materials

var _pbr := {}


## Realistic material from a Poly Haven texture folder (albedo + normal + roughness), world-space triplanar.
func pbr(tex_id: String, scale := 0.5, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s_%.3f_%s" % [tex_id, scale, tint.to_html()]
	if _pbr.has(key):
		return _pbr[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/polyhaven/textures/%s/%s_" % [tex_id, tex_id]
	if ResourceLoader.exists(base + "albedo.jpg"):
		m.albedo_texture = load(base + "albedo.jpg")
		m.albedo_color = tint
		if ResourceLoader.exists(base + "normal.jpg"):
			m.normal_enabled = true
			m.normal_texture = load(base + "normal.jpg")
		if ResourceLoader.exists(base + "roughness.jpg"):
			m.roughness_texture = load(base + "roughness.jpg")
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		if ResourceLoader.exists(base + "ao.jpg"):
			m.ao_enabled = true
			m.ao_texture = load(base + "ao.jpg")
	else:
		m.albedo_color = Color(0.5, 0.5, 0.5) * tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_pbr[key] = m
	return m
