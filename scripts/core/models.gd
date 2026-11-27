extends Node
## Model registry. Autoloaded as "Models".
##
## Loads Sketchfab / Poly Haven / Mixamo files, bakes skinned meshes into static meshes, rescales them to
## real-world size, fixes orientation, and caches the result so every later instance is cheap.
##
##   Models.make("watchtower")                 -> Node3D (visual only)
##   Models.make_static("watchtower", "trimesh") -> StaticBody3D with collision
##   Models.anim_library("swat")               -> AnimationLibrary of Mixamo animations for a character

const SF := "res://assets/sketchfab/"
const PH := "res://assets/polyhaven/models/"

## size = target size in metres along `axis` ("height", "length" = longest horizontal, "max" = longest)
## rot  = extra rotation (degrees) applied before sizing
## anchor = "bottom" (feet on y=0, centred in xz) or "center"
const DEFS := {
	# --- weapons (muzzle along +X in the source files) ---
	"m4": {"path": SF + "low_poly_m4a1_8cab1c/low_poly_m4a1.glb", "size": 0.84, "axis": "length", "anchor": "center", "fwd": -PI / 2.0},
	"ak": {"path": SF + "low_poly_akm_849b7c/low_poly_akm.glb", "size": 0.88, "axis": "length", "anchor": "center", "fwd": -PI / 2.0},
	"svd": {"path": SF + "low_poly_svd_dragunov_fe40c5/low_poly_svd_dragunov.glb", "size": 1.22, "axis": "length", "anchor": "center", "fwd": -PI / 2.0},
	"m9": {"path": SF + "beretta_pistol_f4dd70/beretta_pistol.glb", "size": 0.217, "axis": "length", "anchor": "center", "fwd": -PI / 2.0},
	"knife": {"path": SF + "combat_knife_48e00d/combat_knife.glb", "size": 0.30, "axis": "length", "anchor": "center", "fwd": -PI / 2.0},
	"grenade": {"path": SF + "grenade_m67_happy_or_sad_grunge_pass_dcfc56/grenade_m67_happy_or_sad_grunge_pass.glb", "size": 0.09, "axis": "height", "anchor": "center", "tint": Color(0.22, 0.25, 0.16)},
	"binoculars": {"path": SF + "binoculars_8_ussr_1935_063c8a/binoculars_8_ussr_1935.glb", "size": 0.18, "axis": "length", "anchor": "center"},
	"c4": {"path": SF + "simple_old_c4_43d3b6/simple_old_c4.glb", "size": 0.22, "axis": "max", "anchor": "bottom"},
	"medkit": {"path": SF + "medkit_bda966/medkit.glb", "size": 0.42, "axis": "max", "anchor": "bottom"},
	"keycard": {"path": SF + "scp_keycards_e519db/scp_keycards.glb", "size": 0.25, "axis": "max", "anchor": "bottom"},
	# --- vehicles / aircraft ---
	"blackhawk": {"path": SF + "us_army_uh_60m_black_hawk_low_poly_model_854bf0/us_army_uh_60m_black_hawk_low_poly_model.glb", "size": 19.8, "axis": "length", "anchor": "bottom"},
	"ka27": {"path": SF + "kamov_ka_27_soviet_military_helicopter_054f00/kamov_ka_27_soviet_military_helicopter.glb", "size": 15.9, "axis": "max", "anchor": "bottom"},
	"c130": {"path": SF + "c130_ce61f8/c130.glb", "size": 40.4, "axis": "length", "anchor": "center", "tint": Color(0.33, 0.36, 0.31)},
	"ural": {"path": SF + "ural_4320_f953c5/ural_4320.glb", "size": 7.4, "axis": "length", "anchor": "bottom"},
	"jeep": {"path": SF + "jeep_3216a8/jeep.glb", "size": 5.0, "axis": "length", "anchor": "bottom"},
	"parachute": {"path": SF + "pubg_green_parachute_92386c/pubg_green_parachute.glb", "size": 8.5, "axis": "length", "anchor": "center"},
	# --- structures ---
	"watchtower": {"path": SF + "watch_tower_042f32/watch_tower.glb", "size": 9.0, "axis": "height", "anchor": "bottom"},
	"guard_booth": {"path": SF + "small_guard_booth_422ec8/small_guard_booth.glb", "size": 2.9, "axis": "height", "anchor": "bottom"},
	"radio_tower": {"path": SF + "radio_communications_tower_70a199/radio_communications_tower.glb", "size": 22.0, "axis": "height", "anchor": "bottom"},
	"radar": {"path": SF + "low_poly_radar_dish_ed6850/low_poly_radar_dish.glb", "size": 7.5, "axis": "height", "anchor": "bottom"},
	"hangar": {"path": SF + "j_type_hanger_d86713/j_type_hanger.glb", "size": 30.0, "axis": "length", "anchor": "bottom"},
	"tent": {"path": SF + "tent_979c07/tent.glb", "size": 6.0, "axis": "length", "anchor": "bottom"},
	"containers": {"path": SF + "shipping_containers_cc3f71/shipping_containers.glb", "size": 6.1, "axis": "length", "anchor": "bottom"},
	"chem_tank": {"path": SF + "chemical_tank_63c001/chemical_tank.glb", "size": 5.5, "axis": "height", "anchor": "bottom"},
	"firing_tower": {"path": SF + "military_firing_tower_2eaa7a/military_firing_tower.glb", "size": 7.0, "axis": "height", "anchor": "bottom"},
	"sandbags": {"path": SF + "sandbag_barrier_ready_for_unreal_engine_593800/sandbag_barrier_ready_for_unreal_engine.glb", "size": 3.2, "axis": "length", "anchor": "bottom"},
	"barrier": {"path": SF + "jersey_barrier_b52246/jersey_barrier.glb", "size": 2.0, "axis": "length", "anchor": "bottom"},
	"crates": {"path": SF + "crates_and_barrels_5ae3c7/crates_and_barrels.glb", "size": 2.6, "axis": "length", "anchor": "bottom"},
	"ammo_crate": {"path": SF + "old_ammo_crate_6a834e/old_ammo_crate.glb", "size": 1.0, "axis": "length", "anchor": "bottom"},
	"cctv": {"path": SF + "cctv_camera_e69d5e/cctv_camera.glb", "size": 0.55, "axis": "max", "anchor": "center"},
	"siren": {"path": SF + "psx_siren_7d9012/psx_siren.glb", "size": 4.5, "axis": "height", "anchor": "bottom"},
	"lamp": {"path": SF + "modern_chinese_street_lamp_ce9d02/modern_chinese_street_lamp.glb", "size": 5.5, "axis": "height", "anchor": "bottom"},
	"chair": {"path": SF + "office_chair_modern_675f34/office_chair_modern.glb", "size": 1.0, "axis": "height", "anchor": "bottom"},
	"pine": {"path": SF + "pine_tree_d45218/pine_tree.glb", "size": 14.0, "axis": "height", "anchor": "bottom"},
	"dead_trees": {"path": SF + "psx_dead_tree_pack_405100/psx_dead_tree_pack.glb", "size": 6.0, "axis": "height", "anchor": "bottom"},
	"cliff": {"path": SF + "cliff_082da1/cliff.glb", "size": 9.0, "axis": "height", "anchor": "bottom"},
	# --- Poly Haven props ---
	"barrel": {"path": PH + "Barrel_01/Barrel_01.gltf", "size": 0.9, "axis": "height", "anchor": "bottom"},
	"table": {"path": PH + "wooden_table_02/wooden_table_02.gltf", "size": 0.78, "axis": "height", "anchor": "bottom"},
	"rocks": {"path": PH + "rock_moss_set_02/rock_moss_set_02.gltf", "size": 2.0, "axis": "max", "anchor": "bottom"},
}

## Mixamo animation files -> short names used by the game.
const ANIM_DIR := "res://assets/animations/"
const ANIMS := {
	"idle": ["Ch15_nonPBR@Rifle Idle.fbx", true],
	"walk": ["Ch15_nonPBR@Rifle Walk.fbx", true],
	"run": ["Ch15_nonPBR@Rifle Run.fbx", true],
	"fire": ["Ch15_nonPBR@Firing Rifle.fbx", true],
	"reload": ["Ch15_nonPBR@Reload.fbx", false],
	"death_front": ["Ch15_nonPBR@Death From Front Headshot.fbx", false],
	"death_back": ["Ch15_nonPBR@Death From Back Headshot.fbx", false],
	"death": ["Ch15_nonPBR@Death.fbx", false],
	"death_run": ["Ch15_nonPBR@Rifle Run To Dying.fbx", false],
	"crouch_walk": ["Ch15_nonPBR@Walk Crouching Forward Right.fbx", true],
	"throw": ["Ch15_nonPBR@Throw Grenade.fbx", false],
	"stab": ["Ch15_nonPBR@Stabbing.fbx", false],
	"knife_idle": ["Ch15_nonPBR@Knife Idle.fbx", true],
	"jump": ["Ch15_nonPBR@Jump Forward.fbx", false],
	"freefall": ["Ch15_nonPBR@Treading Water.fbx", true],
	"swim": ["Ch15_nonPBR@Swimming.fbx", true],
	"walk_back": ["Ch15_nonPBR@Backwards Rifle Walk.fbx", true],
	"typing": ["Ch18_nonPBR@Typing.fbx", true],
}
const CHARACTERS := {
	"malik": {"path": "res://assets/characters/malik/malik_ch18.fbx", "skel": "Skeleton3D"},
	"swat": {"path": "res://assets/characters/enemy/enemy_swat.fbx", "skel": "Skeleton3D"},
	"kade": {"path": "res://assets/characters/player/player_ch15.glb", "skel": "Skeleton3D"},
}

var _parts := {}      # id -> {"parts": [[mesh, xform, mats]], "aabb": AABB}
var _scenes := {}
var _libs := {}
var _raw_anims := {}


func has(id: String) -> bool:
	return DEFS.has(id) and ResourceLoader.exists(DEFS[id].path)


func _load_scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


func _prepare(id: String) -> Dictionary:
	if _parts.has(id):
		return _parts[id]
	var def: Dictionary = DEFS[id]
	var ps := _load_scene(def.path)
	var out := {"parts": [], "aabb": AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)}
	if ps == null:
		push_warning("Models: missing " + def.path)
		_parts[id] = out
		return out
	var inst: Node = ps.instantiate()
	add_child(inst)  # needed for global transforms + skeleton poses
	var raw := []
	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var mesh: Mesh = m.mesh
		if m.skin != null and m.get_node_or_null(m.skeleton) != null:
			var baked: ArrayMesh = m.bake_mesh_from_current_skeleton_pose()
			if baked != null:
				mesh = baked
		var mats := []
		for si in mesh.get_surface_count():
			mats.append(m.get_active_material(si) if si < m.mesh.get_surface_count() else null)
		var xf: Transform3D = m.global_transform
		var a: AABB = xf * mesh.get_aabb()
		if a.size.length() < 1e-6:
			continue
		aabb = a if first else aabb.merge(a)
		first = false
		raw.append([mesh, xf, mats])
	inst.queue_free()
	if raw.is_empty():
		_parts[id] = out
		return out
	# orientation fix
	var rot := Basis.from_euler(def.get("rot", Vector3.ZERO) * (PI / 180.0))
	var rotated := AABB()
	first = true
	for r in raw:
		var a2: AABB = Transform3D(rot, Vector3.ZERO) * r[1] * r[0].get_aabb()
		rotated = a2 if first else rotated.merge(a2)
		first = false
	var measure: float
	match def.get("axis", "max"):
		"height":
			measure = rotated.size.y
		"length":
			measure = maxf(rotated.size.x, rotated.size.z)
		_:
			measure = rotated.get_longest_axis_size()
	var k: float = def.size / maxf(measure, 1e-6)
	var offset := -rotated.get_center() * k
	if def.get("anchor", "bottom") == "bottom":
		offset.y = -rotated.position.y * k
	var norm := Transform3D(Basis(rot).scaled(Vector3.ONE * k), offset)
	for r in raw:
		out.parts.append([r[0], norm * r[1], r[2]])
	out.aabb = AABB(rotated.position * k + offset, rotated.size * k)
	if def.has("tint"):
		var t := StandardMaterial3D.new()
		t.albedo_color = def.tint
		t.roughness = 0.8
		t.metallic = 0.2
		for p in out.parts:
			for i in p[2].size():
				p[2][i] = _tinted(p[2][i], def.tint)
	_parts[id] = out
	return out


func _tinted(src: Material, tint: Color) -> Material:
	if src is BaseMaterial3D:
		var m: BaseMaterial3D = src.duplicate()
		m.albedo_color = tint
		return m
	var n := StandardMaterial3D.new()
	n.albedo_color = tint
	return n


func aabb(id: String) -> AABB:
	return _prepare(id).aabb


## Visual-only instance.
func make(id: String, shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = id
	if not DEFS.has(id):
		push_warning("Models: unknown id " + id)
		return root
	for p in _prepare(id).parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[1]
		for i in p[2].size():
			if p[2][i] != null:
				mi.set_surface_override_material(i, p[2][i])
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## Weapon with its muzzle (or blade) pointing along -Z and its centre at the origin.
func weapon(id: String, shadows := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = id
	var m := make(id, shadows)
	m.rotation.y = DEFS.get(id, {}).get("fwd", 0.0)
	holder.add_child(m)
	return holder


## Instance with collision. collide: "box" (one box around the model), "trimesh" (exact), "none".
func make_static(id: String, collide := "box", shadows := true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = id
	sb.collision_layer = 1
	sb.collision_mask = 0
	var vis := make(id, shadows)
	sb.add_child(vis)
	var info := _prepare(id)
	if collide == "box":
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = info.aabb.size
		cs.shape = bs
		cs.position = info.aabb.get_center()
		sb.add_child(cs)
	elif collide == "trimesh":
		for p in info.parts:
			var shape: ConcavePolygonShape3D = p[0].create_trimesh_shape()
			if shape == null:
				continue
			var cs2 := CollisionShape3D.new()
			cs2.shape = shape
			cs2.transform = p[1]
			sb.add_child(cs2)
	return sb


# ---------------------------------------------------------------- characters + animation

func character(id: String) -> Node3D:
	var def: Dictionary = CHARACTERS[id]
	var ps := _load_scene(def.path)
	var n: Node3D = ps.instantiate() if ps != null else Node3D.new()
	return n


func skeleton_path(id: String) -> String:
	return CHARACTERS[id].skel


func _raw(name: String) -> Animation:
	if _raw_anims.has(name):
		return _raw_anims[name]
	var a: Animation = null
	var file: String = ANIM_DIR + ANIMS[name][0]
	var ps := _load_scene(file)
	if ps != null:
		var s := ps.instantiate()
		var ap = s.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0:
			var list: PackedStringArray = ap[0].get_animation_list()
			if list.size() > 0:
				a = ap[0].get_animation(list[0]).duplicate(true)
		s.free()
	_raw_anims[name] = a
	return a


## AnimationLibrary whose tracks point at this character's skeleton.
func anim_library(char_id: String) -> AnimationLibrary:
	if _libs.has(char_id):
		return _libs[char_id]
	var lib := AnimationLibrary.new()
	var skel: String = CHARACTERS[char_id].skel
	for name in ANIMS:
		var src := _raw(name)
		if src == null:
			continue
		var a: Animation = src.duplicate(true)
		var looped: bool = ANIMS[name][1]
		a.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		for t in a.get_track_count():
			var p := String(a.track_get_path(t))
			var bone := p.get_slice(":", 1)
			a.track_set_path(t, NodePath(skel + ":" + bone))
			# keep loops in place: remove horizontal root motion from the hips
			if looped and bone == "mixamorig_Hips" and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var k0: Vector3 = a.track_get_key_value(t, 0) if a.track_get_key_count(t) > 0 else Vector3.ZERO
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(k0.x, v.y, k0.z))
		lib.add_animation(name, a)
	_libs[char_id] = lib
	return lib
