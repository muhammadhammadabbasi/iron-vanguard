extends "res://scripts/missions/mission_base.gd"
## Mission 1: BLACKOUT - HALO jump from a C-130 into Karsa Valley, blow the radio mast, steal the laptop, extract.

const DZ := Vector3(-170, 0, 120)
const LZ := Vector3(40, 0, 200)
const MAST := Vector3(-24, 0, 20)
const OFFICE := Vector3(14, 0, -20)
const CHECKPOINT := Vector3(-15, 0, -170)
const CAMP := Vector3(-200, 0, -60)
const NEST := Vector3(-110, 0, -110)
const PLANE_ALT := 760.0
const PLANE_R := 210.0
const PLANE_SPEED := 62.0

var plane: Node3D
var plane_model: Node3D
var bay: Node3D
var bay_cam: Camera3D
var chase_cam: Camera3D
var bay_lights: Array = []
var kade_npc: Node3D
var kade_ap: AnimationPlayer
var plane_sound: AudioStreamPlayer
var plane_t := 0.0
var plane_ang := 0.0
var jumped := false
var jumping := false
var can_jump := false
var mast_node: Node3D
var mast_done := false
var mast_planted := false
var laptop_done := false
var extraction_called := false
var smoke: Node


func _build_level() -> void:
	map_center = Vector3(-60, 0, 10)
	map_size = 500.0
	atmosphere("kloofendal_48d_partly_cloudy_puresky", Vector3(-24, 70, 0), Color(1.0, 0.86, 0.68), 1.7, Color(0.66, 0.74, 0.84), 0.0008, 1.0, 0.85)
	make_terrain({
		"amplitude": 9.0, "rim_start": 330.0, "rim_height": 90.0, "seed_value": 11,
		"layer_low": "forrest_ground_01", "layer_mid": "dirt", "layer_rock": "rocky_terrain_02",
		"patch_a": Color(0.5, 0.58, 0.3), "patch_b": Color(0.24, 0.3, 0.17),
		"flats": [
			{"pos": Vector3(0, 0, 0), "radius": 50.0, "blend": 25.0, "height": 2.0},
			{"pos": LZ, "radius": 18.0, "blend": 16.0, "height": 2.5},
			{"pos": DZ, "radius": 22.0, "blend": 18.0, "height": 5.0},
			{"pos": CHECKPOINT, "radius": 14.0, "blend": 14.0, "height": 3.0},
			{"pos": CAMP, "radius": 22.0, "blend": 16.0, "height": 6.0},
			{"pos": NEST, "radius": 8.0, "blend": 12.0, "height": 19.0},
		],
		"hills": [
			{"pos": NEST, "radius": 80.0, "height": 18.0},
			{"pos": Vector3(120, 0, -60), "radius": 80.0, "height": 20.0},
			{"pos": Vector3(150, 0, 140), "radius": 90.0, "height": 26.0},
			{"pos": Vector3(-260, 0, 200), "radius": 90.0, "height": 22.0},
		],
	})
	road([Vector3(0, 0, 36), Vector3(4, 0, 90), Vector3(30, 0, 160), Vector3(42, 0, 220), Vector3(60, 0, 300), Vector3(70, 0, 440)], 6.0, "gravel")
	road([Vector3(-40, 0, -6), Vector3(-90, 0, -30), Vector3(-150, 0, -50), Vector3(-200, 0, -60)], 4.5, "gravel")
	road([Vector3(0, 0, -36), Vector3(-6, 0, -100), Vector3(-15, 0, -170), Vector3(-30, 0, -260), Vector3(-40, 0, -440)], 6.0, "gravel")
	_outpost()
	_outer_areas()
	var avoid := [[Vector3.ZERO, 58.0], [LZ, 24.0], [DZ, 26.0], [CHECKPOINT, 16.0], [CAMP, 26.0], [NEST, 10.0]]
	scatter("pine", 320, Vector3(-40, 0, 0), 420.0, avoid, 0.0, "trunk", Vector2(0.75, 1.3))
	scatter("rocks", 70, Vector3(-40, 0, 0), 400.0, avoid, 0.0, "none", Vector2(0.6, 2.0))
	grass(Color(0.16, 0.22, 0.07), Color(0.46, 0.55, 0.22))
	_enemies()


func _outpost() -> void:
	fence([Vector3(-40, 0, -36), Vector3(40, 0, -36), Vector3(40, 0, 36), Vector3(-40, 0, 36), Vector3(-40, 0, -36)],
		[[Vector3(0, 0, 36), 9.0], [Vector3(0, 0, -36), 9.0], [Vector3(-40, 0, 10), 3.0]])
	place("guard_booth", 9.5, 39.0, PI, "trimesh")
	place("sandbags", -6.0, 40.0, 0.0, "box")
	place("sandbags", 4.5, 31.0, 0.0, "box")
	place("watchtower", -35.0, -31.0, 0.6, "trimesh")
	place("watchtower", 35.0, 31.0, -2.5, "trimesh")
	mast_node = place("radio_tower", MAST.x, MAST.z, 0.0, "trimesh")
	house(OFFICE, Vector3(11, 3.2, 8), [["s", -2.0, 1.6, 0.0, 2.3], ["s", 2.8, 1.6, 1.0, 2.1], ["e", 0.0, 1.6, 1.0, 2.1], ["w", 0.0, 1.6, 1.0, 2.1]], "painted_plaster_wall", "flat")
	place("table", OFFICE.x + 2.5, OFFICE.z - 2.4, 0.0, "box", 0.12)
	place("chair", OFFICE.x + 2.5, OFFICE.z - 1.6, PI, "box", 0.12)
	place("ammo_crate", OFFICE.x - 4.0, OFFICE.z - 3.0, 0.0, "box", 0.12)
	_laptop(Vector3(OFFICE.x + 2.5, h(OFFICE.x, OFFICE.z) + 0.12 + 0.78, OFFICE.z - 2.4))
	house(Vector3(-16, 0, -20), Vector3(15, 3.0, 7.5), [["s", -4.0, 1.6, 0.0, 2.2], ["s", 3.0, 1.6, 0.0, 2.2], ["s", 0.0, 1.4, 1.0, 2.0], ["n", -3.0, 1.4, 1.0, 2.0], ["n", 3.0, 1.4, 1.0, 2.0]], "red_brick", "pitched")
	for i in 4:
		place("crates", -21.0 + i * 3.3, -22.0, 0.0, "box", 0.12)
	for p in [Vector3(25, 0, -6), Vector3(25, 0, 2), Vector3(31, 0, -2)]:
		place("chem_tank", p.x, p.z, PI / 2.0, "box")
	for i in 7:
		place("barrel", 20.0 + (i % 4) * 0.8, -12.0 + (i / 4) * 0.8, 0.0, "box")
	place("ural", 6.0, 12.0, 0.35, "box")
	place("ural", 16.0, 22.0, -1.25, "box")
	place("jeep", -8.0, 25.0, 2.6, "box")
	place("containers", -30.0, -4.0, 0.0, "box")
	place("containers", 30.0, -26.0, PI / 2.0, "box")
	place("tent", -6.0, 6.0, 0.2, "box")
	place("tent", -17.0, 4.0, -0.15, "box")
	place("crates", 8.0, -6.0, 0.4, "box")
	place("crates", -10.0, 16.0, -0.9, "box")
	place("ammo_crate", 3.0, 2.0, 0.6, "box")
	place("sandbags", -20.0, 20.0, 1.2, "box")
	for p in [Vector3(-12, 0, -6), Vector3(14, 0, 4), Vector3(0, 0, 30)]:
		place("lamp", p.x, p.z, 0.0, "box")
		lamp_light(ground(p) + Vector3(0, 5.0, 0), 1.4, 16.0)
	alarm_panel(Vector3(2, 0, -8))
	alarm_panel(Vector3(-8, 0, -16))
	alarm.reinforcement_points = [ground(Vector3(60, 0, 300)) + Vector3.UP, ground(Vector3(-30, 0, -260)) + Vector3.UP]
	pickup("medkit", ground(Vector3(-4, 0, 7)))
	pickup("weapon", ground(Vector3(-18, 0, -19)), "svd", 10)


func _outer_areas() -> void:
	# road checkpoint (north)
	place("guard_booth", CHECKPOINT.x + 6.0, CHECKPOINT.z, -PI / 2.0, "trimesh")
	place("barrier", CHECKPOINT.x - 2.0, CHECKPOINT.z + 4.0, 0.1, "box")
	place("sandbags", CHECKPOINT.x - 6.0, CHECKPOINT.z - 3.0, PI / 2.0, "box")
	place("jeep", CHECKPOINT.x - 8.0, CHECKPOINT.z + 8.0, 0.5, "box")
	# logging camp (west)
	house(CAMP + Vector3(6, 0, -4), Vector3(8, 2.8, 6), [["s", 0.0, 1.5, 0.0, 2.2], ["e", 0.0, 1.3, 1.0, 2.0]], "red_brick", "pitched")
	place("tent", CAMP.x - 8.0, CAMP.z + 4.0, 0.4, "box")
	place("ural", CAMP.x - 4.0, CAMP.z - 10.0, 1.2, "box")
	place("crates", CAMP.x + 2.0, CAMP.z + 8.0, 0.2, "box")
	for i in 5:
		place("barrel", CAMP.x - 2.0 + i * 0.75, CAMP.z + 3.0, 0.0, "box")
	pickup("medkit", ground(CAMP + Vector3(6, 0, -4)))
	pickup("grenade", ground(CAMP + Vector3(4, 0, -3)))
	# sniper nest on the hill
	place("watchtower", NEST.x, NEST.z, 0.9, "trimesh")
	pickup("weapon", ground(NEST + Vector3(3, 0, 3)), "svd", 10)


func _laptop(pos: Vector3) -> void:
	Geo.mesh_box(nav, Vector3(0.38, 0.025, 0.27), pos + Vector3(0, 0.013, 0), Fx.mats["gun_metal"])
	Geo.mesh_box(nav, Vector3(0.38, 0.26, 0.015), pos + Vector3(0, 0.14, -0.14), Fx.mats["screen"], Vector3(-0.25, 0, 0))
	interact(pos, "Hold [E] to download the laptop", "DOWNLOADING FILES...", 4.0, _on_laptop, 1.8)


func _enemies() -> void:
	spawn_enemy(Vector3(6, 0, 41), Vector3(6, 0, 80))
	spawn_enemy(Vector3(-5, 0, 42), Vector3(-5, 0, 80))
	spawn_enemy(ground(Vector3(-35, 0, -31)) + Vector3(0, 9.0, 0), Vector3(0, 0, 0), [], true)
	spawn_enemy(ground(Vector3(35, 0, 31)) + Vector3(0, 9.0, 0), Vector3(-30, 0, 40), [], true)
	spawn_enemy(Vector3(-32, 0, -28), Vector3.ZERO, [Vector3(-32, 0, -28), Vector3(32, 0, -28), Vector3(32, 0, 28), Vector3(-32, 0, 28)])
	spawn_enemy(Vector3(-18, 0, 0), Vector3.ZERO, [Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(18, 0, 14)])
	spawn_enemy(Vector3(-20, 0, 15), Vector3(-40, 0, 20))
	spawn_enemy(Vector3(-28, 0, 22), Vector3(-30, 0, 60))
	spawn_enemy(Vector3(-14, 0, -13), Vector3(0, 0, 0))
	spawn_enemy(Vector3(-19, 0, -20), Vector3(-19, 0, -10))
	spawn_enemy(Vector3(OFFICE.x - 2, 0, OFFICE.z), Vector3(OFFICE.x, 0, OFFICE.z + 10))
	spawn_enemy(Vector3(OFFICE.x + 1, 0, OFFICE.z + 6.5), Vector3(OFFICE.x + 1, 0, 20))
	spawn_enemy(Vector3(21, 0, -1), Vector3(0, 0, 0))
	spawn_enemy(Vector3(10, 0, 16), Vector3(0, 0, 36))
	spawn_enemy(Vector3(4, 0, -40), Vector3(0, 0, -80))
	# outside the base
	spawn_enemy(Vector3(-60, 0, 60), Vector3.ZERO, [Vector3(-60, 0, 60), Vector3(-110, 0, 90), Vector3(-80, 0, 20)])
	spawn_enemy(Vector3(10, 0, 110), Vector3.ZERO, [Vector3(10, 0, 110), Vector3(32, 0, 170), Vector3(4, 0, 80)])
	spawn_enemy(CHECKPOINT + Vector3(3, 0, 3), CHECKPOINT + Vector3(0, 0, 40))
	spawn_enemy(CHECKPOINT + Vector3(-3, 0, -2), CHECKPOINT + Vector3(0, 0, -40))
	spawn_enemy(CHECKPOINT + Vector3(6, 0, 0), CHECKPOINT + Vector3(30, 0, 0))
	spawn_enemy(CAMP + Vector3(0, 0, 4), Vector3.ZERO, [CAMP + Vector3(0, 0, 4), CAMP + Vector3(30, 0, 0), CAMP + Vector3(10, 0, -25)])
	spawn_enemy(CAMP + Vector3(6, 0, -4), CAMP + Vector3(6, 0, 10))
	spawn_enemy(CAMP + Vector3(-6, 0, -8), CAMP + Vector3(-30, 0, -8))
	spawn_enemy(ground(NEST) + Vector3(0, 9.5, 0), Vector3(0, 0, 0), [], true)


# ================================================================ intro: C-130 cargo bay + jump

func _build_plane() -> void:
	plane = Node3D.new()
	add_child(plane)
	plane_model = Models.make("c130")
	plane_model.rotation.y = PI    # model nose points +Z; our plane flies along -Z
	plane.add_child(plane_model)
	# cargo bay interior (local space: forward -Z, ramp at +Z)
	bay = Node3D.new()
	plane.add_child(bay)
	var floor_m := Fx.pbr("metal_plate", 0.8, Color(0.55, 0.58, 0.55))
	var wall_m := Fx.pbr("metal_plate", 0.5, Color(0.42, 0.46, 0.4))
	Geo.mesh_box(bay, Vector3(3.2, 0.1, 13.0), Vector3(0, -0.05, 0), floor_m)
	Geo.mesh_box(bay, Vector3(0.1, 3.0, 13.0), Vector3(-1.65, 1.5, 0), wall_m)
	Geo.mesh_box(bay, Vector3(0.1, 3.0, 13.0), Vector3(1.65, 1.5, 0), wall_m)
	Geo.mesh_box(bay, Vector3(3.4, 0.1, 13.0), Vector3(0, 3.0, 0), wall_m)
	Geo.mesh_box(bay, Vector3(3.4, 3.0, 0.1), Vector3(0, 1.5, -6.5), wall_m)
	for i in 9:
		var z := -6.0 + i * 1.5
		Geo.mesh_box(bay, Vector3(0.14, 3.0, 0.14), Vector3(-1.56, 1.5, z), Fx.mats["metal"])
		Geo.mesh_box(bay, Vector3(0.14, 3.0, 0.14), Vector3(1.56, 1.5, z), Fx.mats["metal"])
		Geo.mesh_box(bay, Vector3(3.2, 0.12, 0.14), Vector3(0, 2.9, z), Fx.mats["metal"])
	for side in [-1.0, 1.0]:
		Geo.mesh_box(bay, Vector3(0.45, 0.08, 9.0), Vector3(side * 1.3, 0.48, -1.0), Fx.mats["sleeve"])
		Geo.mesh_box(bay, Vector3(0.06, 0.6, 9.0), Vector3(side * 1.5, 0.8, -1.0), Fx.mats["sleeve"])
	for rx in [-0.5, 0.5]:
		Geo.mesh_box(bay, Vector3(0.12, 0.06, 13.0), Vector3(rx, 0.03, 0), Fx.mats["metal"])
	# lowered ramp at the rear
	Geo.mesh_box(bay, Vector3(3.2, 0.1, 4.0), Vector3(0, -0.85, 8.3), floor_m, Vector3(-0.45, 0, 0))
	for z in [-4.0, 1.0]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.15, 0.1)
		l.light_energy = 2.2
		l.omni_range = 7.0
		l.position = Vector3(0, 2.6, z)
		bay.add_child(l)
		bay_lights.append(l)
	var jl := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	jl.mesh = sm
	jl.material_override = Fx.mats["red_dot"]
	jl.position = Vector3(1.4, 2.3, 5.8)
	jl.name = "JumpLight"
	bay.add_child(jl)
	kade_npc = Models.character("kade")
	bay.add_child(kade_npc)
	kade_npc.position = Vector3(0.2, 0, 2.0)
	kade_ap = AnimationPlayer.new()
	kade_npc.add_child(kade_ap)
	kade_ap.add_animation_library("", Models.anim_library("kade"))
	kade_ap.play("idle")
	bay_cam = Camera3D.new()
	bay_cam.fov = 62.0
	bay_cam.far = 6000.0
	bay.add_child(bay_cam)
	bay_cam.position = Vector3(-0.9, 1.75, -4.6)
	chase_cam = Camera3D.new()
	chase_cam.fov = 55.0
	chase_cam.far = 6000.0
	add_child(chase_cam)


func _set_inside(inside: bool) -> void:
	plane_model.visible = not inside
	bay.visible = inside
	if inside:
		bay_cam.current = true
	else:
		chase_cam.current = true


func start() -> void:
	player.give_loadout(["knife", "m9", "m4"], "m4")
	player.grenades = 3
	player.medkits = 2
	player.controls_enabled = false
	_build_plane()
	plane_sound = AudioStreamPlayer.new()
	plane_sound.stream = Sfx.streams.get("plane_engine")
	plane_sound.volume_db = -2.0
	add_child(plane_sound)
	plane_sound.play()
	plane_sound.finished.connect(_loop_plane_sound)
	plane_ang = PI * 0.75
	_update_plane(0.0)
	player.global_position = plane.global_position
	_set_inside(true)
	hud.cinematic(true, 0.01)
	objective("Get ready to jump")
	say(["m1_plane_1", "m1_plane_2", "m1_plane_3", "m1_plane_4"], _green_light)
	smoke = Fx.smoke_emitter(ground(DZ) + Vector3(0, 0.1, 0))


func _loop_plane_sound() -> void:
	if plane_sound != null and is_instance_valid(plane_sound):
		plane_sound.play()


func _update_plane(delta: float) -> void:
	plane_ang += PLANE_SPEED / PLANE_R * delta
	var c := Vector3(DZ.x, h(DZ.x, DZ.z) + PLANE_ALT, DZ.z)
	var pos := c + Vector3(cos(plane_ang), 0, sin(plane_ang)) * PLANE_R
	var tangent := Vector3(-sin(plane_ang), 0, cos(plane_ang))
	plane.global_position = pos
	plane.look_at(pos + tangent, Vector3.UP)
	plane.rotate_object_local(Vector3.FORWARD, -0.12)   # gentle bank into the turn


func _green_light() -> void:
	can_jump = true
	for l in bay_lights:
		l.light_color = Color(0.2, 1.0, 0.3)
	var jl := bay.get_node("JumpLight") as MeshInstance3D
	jl.material_override = Fx.mats["screen"]
	_set_inside(true)
	hud.notify("GREEN LIGHT  -  PRESS [SPACE] TO JUMP")
	get_tree().create_timer(8.0, false).timeout.connect(_jump)


func _jump() -> void:
	if jumped or jumping:
		return
	jumping = true
	can_jump = false
	# Kade runs down the bay and leaps off the ramp
	kade_ap.play("run", 0.2)
	var tw := kade_npc.create_tween()
	tw.tween_property(kade_npc, "position", Vector3(0.0, -0.3, 6.6), 1.3)
	tw.tween_callback(func(): kade_ap.play("jump", 0.15))
	tw.tween_property(kade_npc, "position", Vector3(0.0, -4.5, 12.0), 1.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(_leave_plane)


func _leave_plane() -> void:
	jumped = true
	kade_npc.visible = false
	hud.cinematic(false)
	var drop := plane.global_transform * Vector3(0, -6, 14)
	var heading := plane.global_rotation.y
	player.start_freefall(drop, heading)
	player.controls_enabled = true
	plane_sound.volume_db = -12.0
	_set_inside(false)
	player.tp_cam.current = true
	objective("Parachute down to the green smoke", ground(DZ) + Vector3.UP * 2.0)
	say(["m1_freefall"])
	player.landed.connect(_on_landed, CONNECT_ONE_SHOT)
	step = 1


func _step(delta: float) -> void:
	if plane != null:
		plane_t += delta
		_update_plane(delta)
		if not jumped:
			player.global_position = plane.global_position
			player.velocity = Vector3.ZERO
			# cut to an outside shot of the plane while Kade checks his gear
			var outside := plane_t > 5.5 and plane_t < 12.0 and not can_jump and not jumping
			if outside != plane_model.visible:
				_set_inside(not outside)
			if outside:
				chase_cam.global_position = plane.global_transform * Vector3(-38, 10, 30)
				chase_cam.look_at(plane.global_position, Vector3.UP)
			else:
				bay_cam.position = Vector3(-0.9, 1.75, -4.6) + Vector3(sin(plane_t * 7.0), cos(plane_t * 5.0), 0) * 0.012
				bay_cam.look_at(bay.global_transform * Vector3(0.2, 1.3, 6.0), plane.global_transform.basis.y)
			if can_jump and Input.is_action_just_pressed("jump"):
				_jump()
		elif plane_t > 60.0:
			plane.queue_free()
			plane = null
			plane_sound.stop()
	if step == 1 and player.mode == 2 and not has_meta("chute_said"):
		set_meta("chute_said", true)
		say(["m1_chute", "m1_steer"])
	if step >= 2 and not extraction_called and mast_done and laptop_done:
		extraction_called = true
		next_step(4)
		objective("Get to the extraction point", ground(LZ) + Vector3.UP * 2.0)
		call_extraction(LZ, ground(LZ) + Vector3(-200, 90, 260), PI * 0.8, "m1_raven")


func _on_landed() -> void:
	next_step(2)
	say(["m1_landed", "m1_mast_hint"])
	_update_objective()
	interact(ground(MAST) + Vector3(7.0, 1.0, 0.0), "Hold [E] to plant C4 on the radio mast", "PLANTING C4...", 3.0, _on_mast_c4, 3.0)


func _update_objective() -> void:
	if not mast_done:
		objective("Destroy the radio mast", ground(MAST) + Vector3(7.0, 2.0, 0.0))
	elif not laptop_done:
		objective("Find the commander's laptop", ground(OFFICE) + Vector3.UP * 2.0)


func _on_mast_c4() -> void:
	mast_planted = true
	say(["m1_c4_set"])
	hud.notify("C4 PLANTED  -  GET CLEAR")
	plant_c4(ground(MAST) + Vector3(6.2, 0.2, 0.0), 8.0, _on_mast_blown)


func _on_mast_blown() -> void:
	mast_done = true
	alarm.radio_up = false
	Fx.explosion(ground(MAST) + Vector3(0, 6, 0), 6.0, 80.0)
	var tw := mast_node.create_tween()
	tw.tween_property(mast_node, "rotation:z", 1.45, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Sfx.play3d("explosion", mast_node.global_position + Vector3(12, 0, 0), 0.0, 200.0))
	for c in mast_node.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	say(["m1_mast_down", "m1_mast_ok"])
	save_checkpoint()
	_update_objective()


func _on_laptop() -> void:
	laptop_done = true
	say(["m1_laptop", "m1_laptop_2"])
	save_checkpoint()
	_update_objective()


func _board() -> void:
	say(["m1_end"])
	super._board()
