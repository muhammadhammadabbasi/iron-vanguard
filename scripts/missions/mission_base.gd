extends Node3D
## Base class for every mission: world building helpers + objective / dialogue / checkpoint flow.

signal completed(stats: Dictionary)

const TerrainScript = preload("res://scripts/world/terrain.gd")
const EnemyScript = preload("res://scripts/ai/enemy.gd")
const AlarmScript = preload("res://scripts/world/alarm_system.gd")
const AlarmPanelScript = preload("res://scripts/world/alarm_panel.gd")
const CameraScript = preload("res://scripts/world/security_camera.gd")
const InteractScript = preload("res://scripts/world/interactable.gd")
const PickupScript = preload("res://scripts/world/pickup.gd")
const HeliScript = preload("res://scripts/world/helicopter.gd")
const C4Script = preload("res://scripts/world/c4_charge.gd")
const Geo = preload("res://scripts/core/geo.gd")

var main
var player
var hud
var actors: Node3D
var nav: NavigationRegion3D
var terrain
var alarm
var env: Environment
var sun: DirectionalLight3D
var rng := RandomNumberGenerator.new()

var mission_id := 1
var map_center := Vector3.ZERO
var map_size := 300.0
var step := 0
var t := 0.0
var kills := 0
var done := false
var checkpoint := {}
var dlg: Array = []
var dlg_t := 0.0
var dlg_cb: Array = []
var heli = null
var heli_ready := false
var objective_marker = null
var low_health_said := false


# ================================================================ lifecycle

func setup(m, pl, h) -> void:
	main = m
	player = pl
	hud = h
	actors = m.actors


## Called by main while the loading screen is up.
func build() -> void:
	rng.seed = 1000 + mission_id
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	add_child(nav)
	alarm = AlarmScript.new()
	alarm.name = "Alarm"
	add_child(alarm)
	alarm.spawn_fn = _spawn_reinforcement
	alarm.alarm_raised.connect(_on_alarm)
	_build_level()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 38.0
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	var half := map_size * 0.5
	nm.filter_baking_aabb = AABB(Vector3(map_center.x - half, -60, map_center.z - half), Vector3(map_size, 160, map_size))
	nav.navigation_mesh = nm
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.4)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	nav.bake_navigation_mesh(false)


## Override: build terrain, buildings, enemies.
func _build_level() -> void:
	pass


## Override: begin the mission (intro sequence).
func start() -> void:
	pass


## Override: per-frame objective logic.
func _step(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	_dialogue(delta)
	_step(delta)
	if player != null and not player.dead:
		if player.hp < 35.0 and player.medkits > 0 and not low_health_said:
			low_health_said = true
			say(["g_lowhealth"])
		elif player.hp > 60.0:
			low_health_said = false


# ================================================================ atmosphere

func atmosphere(hdri: String, sun_rot: Vector3, sun_color: Color, sun_energy: float, fog_color: Color,
		fog_density: float, sky_energy := 1.0, exposure := 1.0) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var path := "res://assets/polyhaven/hdris/%s/%s.hdr" % [hdri, hdri]
	if ResourceLoader.exists(path):
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(path)
		pm.energy_multiplier = sky_energy
		sky.sky_material = pm
	else:
		sky.sky_material = ProceduralSkyMaterial.new()
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = exposure
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.0
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.rotation_degrees = sun_rot
	add_child(sun)
	Game.apply_quality(get_viewport(), env, sun)


# ================================================================ world building

func make_terrain(cfg: Dictionary) -> void:
	terrain = TerrainScript.new()
	terrain.name = "Terrain"
	for k in cfg:
		terrain.set(k, cfg[k])
	nav.add_child(terrain)
	terrain.setup()


func h(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain != null else 0.0


func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, h(p.x, p.z), p.z)


## Place a registry model on the terrain. collide: "box" | "trimesh" | "none"
func place(id: String, x: float, z: float, yaw := 0.0, collide := "box", y_off := 0.0, parent: Node = null) -> Node3D:
	var n: Node3D
	if collide == "none":
		n = Models.make(id)
	else:
		n = Models.make_static(id, collide)
	(parent if parent != null else nav).add_child(n)
	n.position = Vector3(x, h(x, z) + y_off, z)
	n.rotation.y = yaw
	return n


func scatter(id: String, count: int, center: Vector3, radius: float, avoid: Array, min_gap := 0.0, collide := "none", scale_range := Vector2(0.8, 1.2)) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 12:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for av in avoid:
			if Vector2(p.x - av[0].x, p.z - av[0].z).length() < av[1]:
				ok = false
				break
		if not ok:
			continue
		var n: Node3D
		if collide == "trunk":
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.add_child(Models.make(id))
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.35
			cy.height = 6.0
			cs.shape = cy
			cs.position.y = 3.0
			sb.add_child(cs)
			n = sb
			nav.add_child(n)
		else:
			n = Models.make(id)
			add_child(n)
		n.position = ground(p) + Vector3(0, -0.15, 0)
		n.rotation.y = rng.randf() * TAU
		n.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = 260.0
			mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		placed += 1


## Realistic block building with PBR walls, door/window openings, floor, flat or pitched roof and a light.
## openings: [[side ("n"|"s"|"e"|"w"), offset, width, bottom, top], ...]
func house(center: Vector3, size: Vector3, openings: Array, wall_tex := "painted_plaster_wall", roof := "flat", yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	nav.add_child(root)
	var base_y := h(center.x, center.z)
	root.position = Vector3(center.x, base_y, center.z)
	root.rotation.y = yaw
	var wall := Fx.pbr(wall_tex, 0.45)
	var floor_mat := Fx.pbr("concrete_floor_worn_001", 0.35)
	var hh := size.y
	for side in ["n", "s", "e", "w"]:
		var along_x: bool = side == "n" or side == "s"
		var length: float = size.x if along_x else size.z
		var b := Vector3.ZERO
		match side:
			"n":
				b = Vector3(0, 0, -size.z / 2.0)
			"s":
				b = Vector3(0, 0, size.z / 2.0)
			"e":
				b = Vector3(size.x / 2.0, 0, 0)
			"w":
				b = Vector3(-size.x / 2.0, 0, 0)
		var ops := openings.filter(func(o): return o[0] == side)
		ops.sort_custom(func(o1, o2): return o1[1] < o2[1])
		var cursor := -length / 2.0
		for o in ops:
			var a: float = o[1] - o[2] / 2.0
			var bb: float = o[1] + o[2] / 2.0
			_wall_piece(root, b, along_x, cursor, a, -0.6, hh, wall)
			if o[3] > 0.0:
				_wall_piece(root, b, along_x, a, bb, -0.6, o[3], wall)
				# window sill
				var sp := b + (Vector3((a + bb) / 2.0, o[3], 0) if along_x else Vector3(0, o[3], (a + bb) / 2.0))
				Geo.mesh_box(root, Vector3(bb - a, 0.06, 0.42) if along_x else Vector3(0.42, 0.06, bb - a), sp, Fx.mats["concrete_dark"])
			if o[4] < hh:
				_wall_piece(root, b, along_x, a, bb, o[4], hh, wall)
			cursor = bb
		_wall_piece(root, b, along_x, cursor, length / 2.0, -0.6, hh, wall)
	Geo.solid_box(root, Vector3(size.x - 0.3, 0.12, size.z - 0.3), Vector3(0, 0.06, 0), floor_mat)
	if roof == "pitched":
		var rm := Fx.pbr("metal_plate", 0.3, Color(0.75, 0.6, 0.5))
		var ang := 0.42
		var half_w := size.x / 2.0 + 0.5
		var slope_len := half_w / cos(ang)
		for sgn in [-1.0, 1.0]:
			var pc := Vector3(sgn * half_w / 2.0, hh + tan(ang) * half_w / 2.0, 0)
			Geo.solid_box(root, Vector3(slope_len, 0.12, size.z + 0.8), pc, rm, Vector3(0, 0, -sgn * ang))
		# gables
		var gm := wall
		for zs in [-1.0, 1.0]:
			var gable := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(size.x, tan(ang) * half_w, 0.3)
			gable.mesh = pm
			gable.material_override = gm
			gable.position = Vector3(0, hh + tan(ang) * half_w / 2.0, zs * size.z / 2.0)
			root.add_child(gable)
		Geo.solid_box(root, Vector3(size.x, 0.1, size.z), Vector3(0, hh, 0), floor_mat)
	else:
		Geo.solid_box(root, Vector3(size.x + 0.4, 0.3, size.z + 0.4), Vector3(0, hh + 0.15, 0), Fx.pbr("concrete_layers_02", 0.3))
		Geo.mesh_box(root, Vector3(size.x + 0.5, 0.45, 0.25), Vector3(0, hh + 0.3, size.z / 2.0 + 0.1), wall)
		Geo.mesh_box(root, Vector3(size.x + 0.5, 0.45, 0.25), Vector3(0, hh + 0.3, -size.z / 2.0 - 0.1), wall)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.6)
	l.light_energy = 1.1
	l.omni_range = maxf(size.x, size.z) * 0.8
	l.position = Vector3(0, hh - 0.4, 0)
	root.add_child(l)
	Geo.mesh_sphere(root, 0.08, Vector3(0, hh - 0.3, 0), Fx.mats["lamp"], Vector3.ONE, 8)
	return root


func _wall_piece(parent: Node3D, b: Vector3, along_x: bool, a: float, bb: float, y0: float, y1: float, mat: Material) -> void:
	if bb - a < 0.01 or y1 - y0 < 0.01:
		return
	var mid := (a + bb) / 2.0
	var pos := b + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid))
	pos.y = (y0 + y1) / 2.0
	var sz := Vector3(bb - a, y1 - y0, 0.3) if along_x else Vector3(0.3, y1 - y0, bb - a)
	Geo.solid_box(parent, sz, pos, mat)


## Local point inside a house (for furniture / interactables).
func house_point(house_node: Node3D, local: Vector3) -> Vector3:
	return house_node.global_transform * local


static var _chain_tex: Texture2D


func _chainlink_texture() -> Texture2D:
	if _chain_tex != null:
		return _chain_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 64:
		for w in 2:
			img.set_pixel((i + w) % 64, i, Color(0.62, 0.64, 0.66, 1))
			img.set_pixel((63 - i + w) % 64, i, Color(0.62, 0.64, 0.66, 1))
	img.generate_mipmaps()
	_chain_tex = ImageTexture.create_from_image(img)
	return _chain_tex


## Chain-link fence along a polyline, with gaps where gaps=[point, width].
func fence(points: Array, gaps := [], height := 2.6) -> void:
	var post_mat: Material = Fx.mats["metal"]
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_texture = _chainlink_texture()
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh_mat.alpha_scissor_threshold = 0.4
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.metallic = 0.6
	mesh_mat.roughness = 0.5
	mesh_mat.uv1_scale = Vector3(1, 1, 1)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segs := int(ceil(a.distance_to(b) / 3.0))
		for s in segs:
			var p0 := a.lerp(b, float(s) / segs)
			var p1 := a.lerp(b, float(s + 1) / segs)
			var mid := (p0 + p1) * 0.5
			var skip := false
			for g in gaps:
				if Vector2(mid.x - g[0].x, mid.z - g[0].z).length() < g[1] * 0.5:
					skip = true
			var y0 := h(p0.x, p0.z)
			Geo.mesh_cyl(nav, 0.05, height + 0.3, Vector3(p0.x, y0 + (height + 0.3) / 2.0, p0.z), post_mat, Vector3.ZERO, -1.0, 6)
			if skip:
				continue
			var len := p0.distance_to(p1)
			var ym := h(mid.x, mid.z)
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			nav.add_child(sb)
			sb.position = Vector3(mid.x, ym + height / 2.0, mid.z)
			sb.rotation.y = atan2(-(p1.z - p0.z), p1.x - p0.x)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(len, height)
			mi.mesh = q
			var m2: StandardMaterial3D = mesh_mat.duplicate()
			m2.uv1_scale = Vector3(len / 0.6, height / 0.6, 1)
			mi.material_override = m2
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sb.add_child(mi)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(len, height, 0.1)
			cs.shape = bs
			sb.add_child(cs)
			Geo.mesh_box(sb, Vector3(len, 0.04, 0.04), Vector3(0, height / 2.0, 0), post_mat)


func road(points: Array, width := 6.0, tex := "asphalt_02") -> void:
	terrain.add_road(points, width, tex)


func lamp_light(pos: Vector3, energy := 2.0, rng_m := 16.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.light_energy = energy
	l.omni_range = rng_m
	add_child(l)
	l.position = pos


# ================================================================ actors

func spawn_enemy(pos: Vector3, look := Vector3.ZERO, patrol := [], stationary := false, groups := []):
	var e = EnemyScript.new()
	e.stationary = stationary
	var pts := []
	for p in patrol:
		pts.append(ground(p))
	e.patrol_points = pts
	for g in groups:
		e.add_to_group(g)
	actors.add_child(e)
	e.global_position = ground(pos) + Vector3.UP * 0.1 if pos.y < 0.5 else pos
	if look != Vector3.ZERO:
		var d: Vector3 = look - pos
		e.rotation.y = atan2(-d.x, -d.z)
	e.home = e.global_position
	e.home_yaw = e.rotation.y
	e.died.connect(_on_enemy_died)
	return e


func _spawn_reinforcement(pos: Vector3) -> void:
	var e = spawn_enemy(pos, Vector3.ZERO, [], false, ["reinforcement"])
	if player != null:
		e.rush_to(player.global_position)


func _on_enemy_died(_e) -> void:
	kills += 1


func alarm_panel(pos: Vector3, yaw := 0.0) -> Node3D:
	var p := AlarmPanelScript.new()
	p.system = alarm
	nav.add_child(p)
	p.position = ground(pos)
	p.rotation.y = yaw
	alarm.panels.append(p)
	return p


func security_camera(pos: Vector3, yaw: float, height := 3.2) -> Node3D:
	var c := CameraScript.new()
	add_child(c)
	c.position = ground(pos) + Vector3.UP * height
	c.rotation.y = yaw
	if pos.y < 0.5:
		Geo.mesh_cyl(self, 0.06, height, ground(pos) + Vector3.UP * height / 2.0, Fx.mats["metal"])
	return c


func interact(pos: Vector3, prompt: String, busy: String, hold: float, cb: Callable, radius := 2.0) -> Area3D:
	var it := InteractScript.new()
	it.prompt = prompt
	it.busy_text = busy
	it.hold_time = hold
	it.radius = radius
	add_child(it)
	it.global_position = pos
	it.done.connect(cb)
	return it


func pickup(kind: String, pos: Vector3, item := "", amount := 0) -> void:
	var p := PickupScript.new()
	p.kind = kind
	if item != "":
		p.item = item
	if amount > 0:
		p.amount = amount
	p.life = 99999.0
	actors.add_child(p)
	p.global_position = pos + Vector3.UP * 0.3


func plant_c4(pos: Vector3, fuse: float, cb: Callable) -> void:
	var c := C4Script.new()
	c.fuse = fuse
	actors.add_child(c)
	c.global_position = pos
	c.detonated.connect(cb)


func alive(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(n): return n.is_in_group("enemy"))


# ================================================================ objectives / dialogue / checkpoints

func objective(text: String, marker = null) -> void:
	hud.set_objective(text)
	objective_marker = marker
	hud.set_marker(marker)
	if step > 0:
		Sfx.play("objective", -8.0, 0.0)


func next_step(n: int, save := true) -> void:
	step = n
	if save:
		save_checkpoint()


func say(ids: Array, cb := Callable()) -> void:
	for i in ids.size():
		dlg.append(ids[i])
		dlg_cb.append(cb if i == ids.size() - 1 else Callable())


func _dialogue(delta: float) -> void:
	if dlg_t > 0.0:
		dlg_t -= delta
		if dlg_t <= 0.0:
			hud.hide_subtitle()
		return
	if dlg.is_empty():
		return
	var id: String = dlg.pop_front()
	var cb: Callable = dlg_cb.pop_front()
	dlg_t = Sfx.voice(id) + 0.3
	if cb.is_valid():
		get_tree().create_timer(dlg_t, false).timeout.connect(cb)


func save_checkpoint() -> void:
	if player == null or player.dead or player.mode != 0:
		return
	checkpoint = player.checkpoint_data()
	checkpoint["step"] = step
	hud.notify("CHECKPOINT")


func respawn() -> void:
	player.respawn(checkpoint)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.forget()
	alarm.stop()
	hud.notify("CHECKPOINT RESTORED")


func _on_alarm() -> void:
	hud.notify("ALARM RAISED")
	say(["g_alarm_kade", "g_alarm_malik"])


# ================================================================ extraction

func call_extraction(lz: Vector3, from: Vector3, yaw: float, raven_line: String) -> void:
	heli = HeliScript.new()
	actors.add_child(heli)
	var tw: Tween = heli.fly_in(from, ground(lz), yaw, 18.0)
	tw.finished.connect(func():
		heli_ready = true
		say([raven_line])
		var it := interact(heli.global_position + heli.global_transform.basis.x * 2.6 + Vector3.UP * 1.0, "Hold [E] to board the helicopter", "Boarding...", 0.6, _board, 4.0)
		it.marker_offset = Vector3.ZERO)
	Fx.smoke_emitter(ground(lz) + Vector3(5, 0.1, 4))


func _board() -> void:
	if done:
		return
	player.ride(heli, Vector3(1.1, 1.3, 0.6))
	heli.take_off(heli.global_position + Vector3(0, 60, 0) - heli.global_transform.basis.z * 240.0, 16.0)
	hud.set_marker(null)
	get_tree().create_timer(4.5, false).timeout.connect(finish)


func finish() -> void:
	if done:
		return
	done = true
	Game.complete_mission(mission_id)
	var st: Dictionary = player.stats
	completed.emit({
		"mission": mission_id, "time": t, "kills": kills, "shots": st.shots, "hits": st.hits,
		"headshots": st.headshots, "stealth_kills": st.stealth_kills, "alarm": alarm.raised or alarm.spawned > 0,
		"difficulty": Game.difficulty_name(),
	})
