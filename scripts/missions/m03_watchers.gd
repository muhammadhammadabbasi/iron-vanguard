extends "res://scripts/missions/mission_base.gd"
## Mission 3: THE WATCHERS - hilltop radar station at dusk: shut down cameras, blow the radar dish, extract.

const TOP := Vector3(0, 0, 0)
const START := Vector3(10, 0, 150)
const CONTROL := Vector3(-12, 0, -10)
const RADAR := Vector3(14, 0, -16)
const PAD := Vector3(26, 0, 14)

var radar_node: Node3D
var cams_done := false
var radar_done := false
var radar_planted := false
var cameras: Array = []
var drop_heli


func _build_level() -> void:
	map_center = Vector3(0, 0, 40)
	map_size = 280.0
	atmosphere("belfast_sunset_puresky", Vector3(-6, -110, 0), Color(1.0, 0.62, 0.42), 1.4, Color(0.55, 0.45, 0.45), 0.004, 0.9, 1.05)
	make_terrain({
		"size": 440.0, "amplitude": 5.0, "rim_start": 170.0, "rim_height": 55.0, "seed_value": 33,
		"layer_low": "forrest_ground_01", "layer_mid": "dirt", "layer_rock": "rocky_terrain_02",
		"hills": [{"pos": TOP, "radius": 95.0, "height": 26.0}],
		"flats": [
			{"pos": TOP, "radius": 40.0, "blend": 18.0, "height": 27.0},
			{"pos": START, "radius": 16.0, "blend": 14.0, "height": 2.0},
		],
	})
	road([Vector3(10, 0, 160), Vector3(30, 0, 110), Vector3(34, 0, 70), Vector3(14, 0, 44), Vector3(2, 0, 38)], 5.5, "gravel")
	_station()
	scatter("pine", 140, Vector3(0, 0, 40), 190.0, [[TOP, 48.0], [START, 18.0], [Vector3(30, 0, 110), 8.0], [Vector3(34, 0, 70), 8.0]], 0.0, "trunk", Vector2(0.7, 1.25))
	scatter("rocks", 45, Vector3(0, 0, 30), 180.0, [[TOP, 44.0], [START, 16.0]], 0.0, "none", Vector2(0.6, 2.0))
	_enemies()


func _station() -> void:
	fence([Vector3(-36, 0, -34), Vector3(36, 0, -34), Vector3(36, 0, 34), Vector3(-36, 0, 34), Vector3(-36, 0, -34)], [[Vector3(4, 0, 34), 8.0]])
	place("guard_booth", 11.0, 37.0, PI, "trimesh")
	place("watchtower", -31.0, 29.0, 0.7, "trimesh")
	place("watchtower", 31.0, -29.0, -2.4, "trimesh")
	radar_node = place("radar", RADAR.x, RADAR.z, 0.6, "box")
	radar_node.scale = Vector3.ONE * 1.7
	var r2 := place("radar", -22.0, 12.0, -0.8, "box")
	r2.scale = Vector3.ONE * 1.0
	var r3 := place("radar", 24.0, -2.0, 2.2, "box")
	r3.scale = Vector3.ONE * 0.9
	house(CONTROL, Vector3(12, 3.4, 8), [["s", 2.5, 1.6, 0.0, 2.4], ["s", -2.5, 1.8, 1.0, 2.2], ["e", 0.0, 1.5, 1.0, 2.2], ["n", 2.0, 1.5, 1.0, 2.2]], "concrete_layers_02", "flat")
	# consoles in the control room
	for i in 3:
		var p := ground(Vector3(CONTROL.x - 4.0 + i * 2.2, 0, CONTROL.z - 3.2))
		Geo.solid_box(nav, Vector3(1.6, 1.0, 0.6), p + Vector3(0, 0.62, 0), Fx.mats["metal"])
		Geo.mesh_box(nav, Vector3(1.2, 0.5, 0.05), p + Vector3(0, 1.45, -0.2), Fx.mats["screen"], Vector3(-0.2, 0, 0))
	interact(ground(Vector3(CONTROL.x - 1.8, 0, CONTROL.z - 2.4)) + Vector3.UP * 1.0, "Hold [E] to shut down the security cameras", "SHUTTING DOWN CAMERAS...", 3.0, _on_console, 2.2)
	house(Vector3(14, 0, 18), Vector3(13, 3.0, 7), [["w", 0.0, 1.6, 0.0, 2.2], ["s", 3.0, 1.4, 1.0, 2.0], ["n", -3.0, 1.4, 1.0, 2.0]], "red_brick", "pitched")
	place("tent", -18.0, -20.0, 0.3, "box")
	place("chem_tank", -26.0, -10.0, 0.0, "box")
	place("containers", 26.0, -24.0, PI / 2.0, "box")
	place("ural", -4.0, 22.0, 1.2, "box")
	place("jeep", 4.0, 12.0, -0.4, "box")
	place("crates", -6.0, -24.0, 0.2, "box")
	place("ammo_crate", 0.0, 4.0, 0.7, "box")
	place("sandbags", 0.0, 30.0, 0.0, "box")
	place("sandbags", 9.0, 30.0, 0.0, "box")
	for i in 6:
		place("barrel", -22.0 + (i % 3) * 0.7, -4.0 + (i / 3) * 0.7, 0.0, "box")
	# helipad
	var pad := Geo.mesh_cyl(nav, 6.0, 0.06, ground(PAD) + Vector3(0, 0.03, 0), Fx.pbr("concrete_floor_worn_001", 0.4), Vector3.ZERO, -1.0, 24)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geo.mesh_box(nav, Vector3(0.6, 0.02, 4.0), ground(PAD) + Vector3(-1.4, 0.08, 0), Fx.mats["lz"])
	Geo.mesh_box(nav, Vector3(0.6, 0.02, 4.0), ground(PAD) + Vector3(1.4, 0.08, 0), Fx.mats["lz"])
	Geo.mesh_box(nav, Vector3(2.2, 0.02, 0.6), ground(PAD) + Vector3(0, 0.08, 0), Fx.mats["lz"])
	for p in [Vector3(-10, 0, 6), Vector3(10, 0, -4), Vector3(4, 0, 30)]:
		place("lamp", p.x, p.z, 0.0, "box")
		lamp_light(ground(p) + Vector3(0, 5.0, 0), 2.0, 16.0)
	# cameras covering the approaches
	for c in [[Vector3(0, 0, 33), 0.0], [Vector3(-35, 0, 0), -PI / 2.0], [Vector3(35, 0, 10), PI / 2.0],
			[Vector3(10, 0, -30), PI], [Vector3(-12, 0, -5.5), 0.0]]:
		var cam = security_camera(c[0], c[1], 3.6)
		cameras.append(cam)
	alarm_panel(Vector3(-2, 0, -2))
	alarm_panel(Vector3(18, 0, 26))
	alarm.reinforcement_points = [ground(Vector3(30, 0, 110)) + Vector3.UP, ground(Vector3(-40, 0, -120)) + Vector3.UP]
	pickup("medkit", ground(Vector3(14, 0, 18)))
	pickup("weapon", ground(Vector3(-18, 0, -18)), "svd", 10)


func _enemies() -> void:
	spawn_enemy(Vector3(6, 0, 38), Vector3(10, 0, 80))
	spawn_enemy(Vector3(1, 0, 37), Vector3(0, 0, 80))
	spawn_enemy(ground(Vector3(-31, 0, 29)) + Vector3(0, 9.0, 0), Vector3(0, 0, 80), [], true)
	spawn_enemy(ground(Vector3(31, 0, -29)) + Vector3(0, 9.0, 0), Vector3(0, 0, 0), [], true)
	spawn_enemy(Vector3(-30, 0, -28), Vector3.ZERO, [Vector3(-30, 0, -28), Vector3(30, 0, -28), Vector3(30, 0, 28), Vector3(-30, 0, 28)])
	spawn_enemy(Vector3(0, 0, 0), Vector3.ZERO, [Vector3(0, 0, 0), Vector3(20, 0, -8), Vector3(-16, 0, -14)])
	spawn_enemy(Vector3(CONTROL.x + 2.0, 0, CONTROL.z - 1.0), Vector3(CONTROL.x, 0, CONTROL.z + 10))
	spawn_enemy(Vector3(CONTROL.x - 3.0, 0, CONTROL.z + 6.0), Vector3(0, 0, 20))
	spawn_enemy(Vector3(RADAR.x - 3.0, 0, RADAR.z + 5.0), Vector3(0, 0, 10))
	spawn_enemy(Vector3(RADAR.x + 5.0, 0, RADAR.z - 2.0), Vector3(30, 0, -10))
	spawn_enemy(Vector3(14, 0, 14), Vector3(14, 0, 30))
	spawn_enemy(Vector3(-20, 0, 8), Vector3(-36, 0, 8))
	spawn_enemy(Vector3(26, 0, 6), Vector3(36, 0, 10))
	spawn_enemy(Vector3(30, 0, 90), Vector3.ZERO, [Vector3(30, 0, 90), Vector3(36, 0, 60), Vector3(16, 0, 44)])
	spawn_enemy(Vector3(-24, 0, 60), Vector3.ZERO, [Vector3(-24, 0, 60), Vector3(-44, 0, 20), Vector3(-30, 0, 70)])


# ================================================================ flow

func start() -> void:
	player.give_loadout(["knife", "m9", "m4", "svd"], "m9")
	player.grenades = 3
	player.medkits = 2
	player.global_position = ground(START) + Vector3(0, 0.3, 0)
	player.set_yaw(0.25)
	player.controls_enabled = true
	drop_heli = HeliScript.new()
	actors.add_child(drop_heli)
	drop_heli.global_position = ground(START) + Vector3(14, 0.1, 10)
	drop_heli.rotation.y = 0.4
	drop_heli.take_off(ground(START) + Vector3(220, 120, 260), 16.0)
	get_tree().create_timer(18.0, false).timeout.connect(drop_heli.queue_free)
	step = 1
	save_checkpoint()
	say(["m3_intro_1", "m3_intro_2", "m3_intro_3"])
	_update_objective()


func _update_objective() -> void:
	if not cams_done:
		objective("Shut down the cameras from the control room", ground(CONTROL) + Vector3.UP * 2.5)
	elif not radar_done:
		objective("Plant C4 on the main radar dish", ground(RADAR) + Vector3.UP * 5.0)
	else:
		objective("Get to the landing pad", ground(PAD) + Vector3.UP * 2.0)


func _on_console() -> void:
	_cameras_off()


func _cameras_off() -> void:
	if cams_done:
		return
	cams_done = true
	for c in cameras:
		if is_instance_valid(c):
			c.set_active(false)
	say(["m3_cams", "m3_cams_ok"])
	save_checkpoint()
	interact(ground(RADAR) + Vector3(-3.0, 1.0, 3.0), "Hold [E] to plant C4 on the radar", "PLANTING C4...", 3.0, _on_radar_c4, 3.2)
	_update_objective()


func _on_radar_c4() -> void:
	radar_planted = true
	say(["m3_c4"])
	hud.notify("C4 PLANTED  -  GET CLEAR")
	plant_c4(ground(RADAR) + Vector3(-2.0, 0.3, 2.0), 9.0, _on_radar_blown)


func _on_radar_blown() -> void:
	radar_done = true
	Fx.explosion(ground(RADAR) + Vector3(0, 7, 0), 7.0, 80.0)
	var tw := radar_node.create_tween()
	tw.tween_property(radar_node, "rotation:z", 1.2, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(radar_node, "position:y", radar_node.position.y - 1.5, 2.5)
	say(["m3_radar_down"])
	save_checkpoint()
	_update_objective()
	call_extraction(PAD, ground(PAD) + Vector3(240, 90, 180), -PI * 0.3, "m3_raven")


func _step(_delta: float) -> void:
	if not cams_done and step >= 1:
		var all_dead := true
		for c in cameras:
			if is_instance_valid(c) and not c.destroyed:
				all_dead = false
				break
		if all_dead:
			_cameras_off()


func _board() -> void:
	say(["m3_end"])
	super._board()
