extends "res://scripts/missions/mission_base.gd"
## Mission 1: BLACKOUT - HALO jump at dawn into Karsa Valley, blow the radio mast, steal the laptop, extract.

const DZ := Vector3(-95, 0, 55)
const LZ := Vector3(0, 0, 100)
const MAST := Vector3(-24, 0, 20)
const OFFICE := Vector3(14, 0, -20)
const PLANE_ALT := 720.0

var plane: Node3D
var plane_cam: Camera3D
var plane_sound: AudioStreamPlayer
var plane_t := 0.0
var jumped := false
var can_jump := false
var mast_node: Node3D
var mast_done := false
var mast_planted := false
var laptop_done := false
var extraction_called := false
var office_house: Node3D
var smoke: Node


func _build_level() -> void:
	map_center = Vector3(-20, 0, 20)
	map_size = 300.0
	atmosphere("belfast_sunset_puresky", Vector3(-11, 65, 0), Color(1.0, 0.72, 0.5), 1.55, Color(0.62, 0.52, 0.48), 0.0013, 1.0, 0.88)
	make_terrain({
		"size": 460.0, "amplitude": 8.0, "rim_start": 170.0, "rim_height": 70.0, "seed_value": 11,
		"layer_low": "forrest_ground_01", "layer_mid": "dirt", "layer_rock": "rocky_terrain_02",
		"flats": [
			{"pos": Vector3(0, 0, 0), "radius": 50.0, "blend": 25.0, "height": 2.0},
			{"pos": LZ, "radius": 16.0, "blend": 14.0, "height": 1.5},
			{"pos": DZ, "radius": 18.0, "blend": 16.0, "height": 4.0},
		],
		"hills": [
			{"pos": Vector3(-70, 0, -70), "radius": 60.0, "height": 22.0},
			{"pos": Vector3(80, 0, -40), "radius": 50.0, "height": 16.0},
			{"pos": Vector3(70, 0, 90), "radius": 55.0, "height": 14.0},
		],
	})
	road([Vector3(0, 0, 36), Vector3(0, 0, 70), Vector3(8, 0, 110), Vector3(30, 0, 160), Vector3(40, 0, 220)], 6.0, "gravel")
	road([Vector3(0, 0, -34), Vector3(-6, 0, -80), Vector3(-30, 0, -150), Vector3(-40, 0, -220)], 6.0, "gravel")
	_outpost()
	scatter("pine", 170, Vector3(-20, 0, 20), 200.0, [[Vector3.ZERO, 58.0], [LZ, 22.0], [DZ, 24.0], [Vector3(0, 0, 70), 8.0], [Vector3(8, 0, 110), 8.0]], 0.0, "trunk", Vector2(0.75, 1.25))
	scatter("rocks", 40, Vector3(-20, 0, 20), 190.0, [[Vector3.ZERO, 55.0], [LZ, 18.0], [DZ, 18.0]], 0.0, "none", Vector2(0.6, 1.8))
	_enemies()


func _outpost() -> void:
	# fence with gate (south) and a cut hole on the west side
	fence([Vector3(-40, 0, -36), Vector3(40, 0, -36), Vector3(40, 0, 36), Vector3(-40, 0, 36), Vector3(-40, 0, -36)],
		[[Vector3(0, 0, 36), 9.0], [Vector3(-40, 0, 10), 3.0]])
	place("guard_booth", 9.5, 39.0, PI, "trimesh")
	place("sandbags", -6.0, 40.0, 0.0, "box")
	place("sandbags", 4.5, 31.0, 0.0, "box")
	place("watchtower", -35.0, -31.0, 0.6, "trimesh")
	place("watchtower", 35.0, 31.0, -2.5, "trimesh")
	mast_node = place("radio_tower", MAST.x, MAST.z, 0.0, "trimesh")
	# commander's office + barracks
	office_house = house(OFFICE, Vector3(11, 3.2, 8), [["s", -2.0, 1.6, 0.0, 2.3], ["s", 2.8, 1.6, 1.0, 2.1], ["e", 0.0, 1.6, 1.0, 2.1], ["w", 0.0, 1.6, 1.0, 2.1]], "painted_plaster_wall", "flat")
	place("table", OFFICE.x + 2.5, OFFICE.z - 2.4, 0.0, "box", 0.12)
	place("chair", OFFICE.x + 2.5, OFFICE.z - 1.6, PI, "box", 0.12)
	place("ammo_crate", OFFICE.x - 4.0, OFFICE.z - 3.0, 0.0, "box", 0.12)
	_laptop(Vector3(OFFICE.x + 2.5, h(OFFICE.x, OFFICE.z) + 0.12 + 0.78, OFFICE.z - 2.4))
	house(Vector3(-16, 0, -20), Vector3(15, 3.0, 7.5), [["s", -4.0, 1.6, 0.0, 2.2], ["s", 3.0, 1.6, 0.0, 2.2], ["s", 0.0, 1.4, 1.0, 2.0], ["n", -3.0, 1.4, 1.0, 2.0], ["n", 3.0, 1.4, 1.0, 2.0]], "red_brick", "pitched")
	for i in 4:
		place("crates", -21.0 + i * 3.3, -22.0, 0.0, "box", 0.12)
	# fuel depot
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
	place("sandbags", -27.0, 26.0, -0.4, "box")
	for p in [Vector3(-12, 0, -6), Vector3(14, 0, 4), Vector3(0, 0, 30)]:
		place("lamp", p.x, p.z, 0.0, "box")
		lamp_light(ground(p) + Vector3(0, 5.0, 0), 1.6, 16.0)
	alarm_panel(Vector3(2, 0, -8))
	alarm_panel(Vector3(-8, 0, -16))
	alarm.reinforcement_points = [ground(Vector3(0, 0, 150)) + Vector3.UP, ground(Vector3(-25, 0, -140)) + Vector3.UP]
	pickup("medkit", ground(Vector3(-4, 0, 7)))
	pickup("weapon", ground(Vector3(-18, 0, -19)), "svd", 10)


func _laptop(pos: Vector3) -> void:
	var base := Geo.mesh_box(nav, Vector3(0.38, 0.025, 0.27), pos + Vector3(0, 0.013, 0), Fx.mats["gun_metal"])
	var scr := Geo.mesh_box(nav, Vector3(0.38, 0.26, 0.015), pos + Vector3(0, 0.14, -0.14), Fx.mats["screen"], Vector3(-0.25, 0, 0))
	base.name = "Laptop"
	scr.name = "LaptopScreen"
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
	spawn_enemy(Vector3(-40, 0, 60), Vector3.ZERO, [Vector3(-40, 0, 60), Vector3(-60, 0, 20), Vector3(-45, 0, -20)])


# ================================================================ flow

func start() -> void:
	player.give_loadout(["knife", "m9", "m4"], "m4")
	player.grenades = 3
	player.medkits = 2
	# C-130 flying over the valley
	plane = Node3D.new()
	add_child(plane)
	var pm := Models.make("c130")
	pm.rotation.y = -PI / 2.0
	plane.add_child(pm)
	plane_cam = Camera3D.new()
	plane_cam.far = 3000.0
	plane_cam.fov = 60.0
	add_child(plane_cam)
	plane_cam.current = true
	plane_sound = AudioStreamPlayer.new()
	plane_sound.stream = Sfx.streams.get("plane_engine")
	plane_sound.volume_db = -4.0
	add_child(plane_sound)
	plane_sound.play()
	plane_sound.finished.connect(_loop_plane_sound)
	player.global_position = Vector3(DZ.x - 300, PLANE_ALT, DZ.z)
	hud.cinematic(true, 0.01)
	objective("Get ready to jump")
	say(["m1_plane_1", "m1_plane_2", "m1_plane_3", "m1_plane_4"], _green_light)
	smoke = Fx.smoke_emitter(ground(DZ) + Vector3(0, 0.1, 0))


func _loop_plane_sound() -> void:
	if plane_sound != null and not jumped:
		plane_sound.play()


func _green_light() -> void:
	can_jump = true
	hud.notify("GREEN LIGHT  -  PRESS [SPACE] TO JUMP")
	get_tree().create_timer(7.0, false).timeout.connect(_jump)


func _jump() -> void:
	if jumped:
		return
	jumped = true
	hud.cinematic(false)
	var drop := plane.global_position + Vector3(0, -6, 0) - plane.global_transform.basis.x * 0.0
	player.start_freefall(drop, -PI / 2.0)
	player.controls_enabled = true
	player.cam.current = true
	plane_sound.volume_db = -14.0
	objective("Parachute down to the green smoke", ground(DZ) + Vector3.UP * 2.0)
	say(["m1_freefall"])
	player.landed.connect(_on_landed, CONNECT_ONE_SHOT)
	step = 1


func _step(delta: float) -> void:
	if plane != null:
		plane_t += delta
		plane.global_position = Vector3(DZ.x - 420 + plane_t * 62.0, PLANE_ALT + 40.0, DZ.z)
		if not jumped:
			player.global_position = plane.global_position + Vector3(-12, -6, 0)
			var behind := plane.global_position + Vector3(-70 + sin(plane_t * 0.2) * 10.0, 14, 34)
			plane_cam.global_position = behind
			plane_cam.look_at(plane.global_position + Vector3(6, 0, 0), Vector3.UP)
			if can_jump and Input.is_action_just_pressed("jump"):
				_jump()
		elif plane_t > 30.0:
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
		call_extraction(LZ, ground(LZ) + Vector3(-200, 70, 260), PI * 0.8, "m1_raven")


func _on_landed() -> void:
	next_step(2)
	say(["m1_landed", "m1_mast_hint"])
	_update_objective()
	interact(ground(MAST) + Vector3(7.0, 1.0, 0.0), "Hold [E] to plant C4 on the radio mast", "PLANTING C4...", 3.0, _on_mast_c4, 2.6)


func _update_objective() -> void:
	if not mast_done:
		objective("Destroy the radio mast", ground(MAST) + Vector3.UP * 6.0)
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
