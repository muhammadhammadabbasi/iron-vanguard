extends "res://scripts/missions/mission_base.gd"
## Mission 2: SILENT PASS - helicopter insertion, village + border checkpoint, antenna, keycard, gate, meet Rauf.

const LZ := Vector3(4, 0, 150)
const GATE := Vector3(0, 0, 0)
const ANTENNA := Vector3(28, 0, 16)
const CMD_HOUSE := Vector3(-19, 0, 52)
const BOOTH := Vector3(9, 0, 5)
const RAUF := Vector3(-3, 0, -42)

var insertion_heli
var gate_node: Node3D
var antenna_node: Node3D
var antenna_done := false
var has_key := false
var gate_open := false
var rauf: Node3D
var met := false
var walls: Array = []


func _build_level() -> void:
	map_center = Vector3(0, 0, 40)
	map_size = 280.0
	atmosphere("kloofendal_48d_partly_cloudy_puresky", Vector3(-52, 35, 0), Color(1.0, 0.95, 0.88), 1.6, Color(0.72, 0.78, 0.85), 0.0011, 1.0, 0.85)
	make_terrain({
		"size": 440.0, "amplitude": 4.0, "rim_start": 150.0, "rim_height": 80.0, "seed_value": 22,
		"layer_low": "dirt", "layer_mid": "gravel", "layer_rock": "rocky_terrain_02", "layer_high": "snow_02", "snow_line": 48.0,
		"flats": [
			{"pos": Vector3(0, 0, 40), "radius": 46.0, "blend": 16.0, "height": 3.0},
			{"pos": Vector3(0, 0, -40), "radius": 34.0, "blend": 14.0, "height": 3.0},
			{"pos": LZ, "radius": 18.0, "blend": 14.0, "height": 3.0},
			{"pos": Vector3(0, 0, 100), "radius": 22.0, "blend": 14.0, "height": 3.0},
		],
		"hills": [
			{"pos": Vector3(-95, 0, 10), "radius": 70.0, "height": 55.0},
			{"pos": Vector3(95, 0, 10), "radius": 70.0, "height": 55.0},
			{"pos": Vector3(-90, 0, 90), "radius": 60.0, "height": 40.0},
			{"pos": Vector3(90, 0, 100), "radius": 60.0, "height": 42.0},
			{"pos": Vector3(-80, 0, -80), "radius": 60.0, "height": 45.0},
			{"pos": Vector3(80, 0, -80), "radius": 60.0, "height": 45.0},
		],
	})
	road([Vector3(4, 0, 170), Vector3(2, 0, 120), Vector3(0, 0, 70), Vector3(0, 0, 0), Vector3(-2, 0, -60), Vector3(-6, 0, -130)], 6.5, "asphalt_02")
	_checkpoint()
	_village()
	scatter("pine", 110, Vector3(0, 0, 40), 190.0, [[Vector3(0, 0, 40), 52.0], [Vector3(0, 0, -40), 36.0], [LZ, 22.0], [Vector3(0, 0, 100), 20.0]], 0.0, "trunk", Vector2(0.7, 1.2))
	scatter("rocks", 50, Vector3(0, 0, 30), 170.0, [[Vector3(0, 0, 40), 50.0], [Vector3(0, 0, -40), 34.0], [LZ, 18.0]], 0.0, "none", Vector2(0.8, 2.2))
	_bounds()
	_enemies()


func _checkpoint() -> void:
	# wall across the valley: containers + concrete barriers, one gate on the road
	for x in [-46.0, -38.0, -30.0, -22.0, -14.0]:
		place("containers", x, -2.0, PI / 2.0, "box")
	for x in [14.0, 22.0, 30.0, 38.0, 46.0]:
		place("containers", x, -2.0, PI / 2.0, "box")
	for x in [-8.0, -6.0, 6.0, 8.0]:
		place("barrier", x, -2.0, PI / 2.0, "box")
	for x in [-10.5, 10.5]:
		place("barrier", x, -2.0, PI / 2.0, "box")
	gate_node = StaticBody3D.new()
	gate_node.collision_layer = 1
	nav.add_child(gate_node)
	gate_node.position = ground(GATE) + Vector3(0, 0, -2.0)
	var steel := Fx.pbr("metal_plate", 0.5, Color(0.55, 0.58, 0.5))
	Geo.solid_box(gate_node, Vector3(9.0, 3.2, 0.25), Vector3(0, 1.6, 0), steel)
	for i in 8:
		Geo.mesh_box(gate_node, Vector3(0.12, 3.3, 0.35), Vector3(-4.2 + i * 1.2, 1.65, 0), Fx.mats["metal"])
	place("guard_booth", BOOTH.x, BOOTH.z, PI, "trimesh")
	place("watchtower", -15.0, 6.0, 0.4, "trimesh")
	antenna_node = place("radio_tower", ANTENNA.x, ANTENNA.z, 0.0, "trimesh")
	place("sandbags", -6.0, 6.0, 0.0, "box")
	place("sandbags", 4.5, 8.0, 0.2, "box")
	place("ural", -6.0, -14.0, 0.1, "box")
	place("tent", 12.0, -16.0, 0.0, "box")
	place("jeep", 2.0, -46.0, 0.4, "box")
	place("crates", -12.0, -10.0, 0.3, "box")
	alarm_panel(Vector3(12, 0, 2))
	alarm_panel(Vector3(-4, 0, 40))
	security_camera(Vector3(-4.0, 0, 3.0), 0.0, 4.0)
	alarm.reinforcement_points = [ground(Vector3(0, 0, -110)) + Vector3.UP]


func _village() -> void:
	var specs := [
		[Vector3(-16, 0, 26), Vector3(8, 3.0, 7), "painted_plaster_wall", "flat", 0.05],
		[Vector3(17, 0, 30), Vector3(9, 3.0, 7), "red_brick", "pitched", -0.05],
		[Vector3(16, 0, 46), Vector3(7, 3.0, 6), "painted_plaster_wall", "flat", 0.1],
		[Vector3(-17, 0, 72), Vector3(8, 3.0, 7), "red_brick", "pitched", 0.0],
		[Vector3(17, 0, 66), Vector3(10, 3.2, 7), "concrete_layers_02", "flat", -0.08],
		[Vector3(-30, 0, 40), Vector3(7, 3.0, 6), "painted_plaster_wall", "pitched", 0.3],
	]
	for s in specs:
		var side := "e" if s[0].x < 0 else "w"
		house(s[0], s[1], [[side, 0.0, 1.5, 0.0, 2.2], ["n", 1.5, 1.4, 1.0, 2.0], ["s", -1.5, 1.4, 1.0, 2.0]], s[2], s[3], s[4])
	# commander's house: bigger, two rooms
	var ch := house(CMD_HOUSE, Vector3(12, 3.4, 9), [["e", -2.0, 1.6, 0.0, 2.4], ["e", 3.0, 1.5, 1.0, 2.2], ["n", 0.0, 1.5, 1.0, 2.2], ["s", 2.0, 1.5, 1.0, 2.2]], "red_brick", "pitched")
	place("table", CMD_HOUSE.x - 3.0, CMD_HOUSE.z + 2.0, 0.0, "box", 0.12)
	place("chair", CMD_HOUSE.x - 3.0, CMD_HOUSE.z + 2.8, PI, "box", 0.12)
	place("ammo_crate", CMD_HOUSE.x + 3.5, CMD_HOUSE.z - 3.0, 0.3, "box", 0.12)
	var kp := ground(Vector3(CMD_HOUSE.x - 3.0, 0, CMD_HOUSE.z + 2.0)) + Vector3(0, 0.12 + 0.79, 0)
	var key := Models.make("keycard", false)
	add_child(key)
	key.position = kp
	key.name = "Keycard"
	interact(kp, "Hold [E] to take the gate keycard", "TAKING KEYCARD...", 1.0, _on_key.bind(key), 1.8)
	for p in [Vector3(-6, 0, 34), Vector3(6, 0, 58), Vector3(-6, 0, 80)]:
		place("lamp", p.x, p.z, PI / 2.0, "box")
		lamp_light(ground(p) + Vector3(0, 5, 0), 1.0, 12.0)
	place("ural", 8.0, 84.0, 0.2, "box")
	place("jeep", -9.0, 58.0, -1.4, "box")
	place("crates", 8.0, 40.0, 0.2, "box")
	for i in 5:
		place("barrel", -8.0 + i * 0.7, 48.0, 0.0, "box")
	pickup("medkit", ground(Vector3(17, 0, 30)))
	pickup("weapon", ground(Vector3(16, 0, 66)), "svd", 10)


func _bounds() -> void:
	# keep the player in the valley (the slopes are steep but not impossible)
	for side in [-1.0, 1.0]:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		add_child(sb)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2, 200, 400)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(side * 62.0, 50, 20)


func _enemies() -> void:
	spawn_enemy(Vector3(5, 0, 3), Vector3(0, 0, 40))
	spawn_enemy(Vector3(-5, 0, 3), Vector3(0, 0, 40))
	spawn_enemy(Vector3(9, 0, 7), Vector3(0, 0, 40))
	spawn_enemy(ground(Vector3(-15, 0, 6)) + Vector3(0, 9.0, 0), Vector3(0, 0, 60), [], true)
	spawn_enemy(Vector3(26, 0, 12), Vector3(0, 0, 30))
	spawn_enemy(Vector3(30, 0, 20), Vector3(30, 0, 60), [Vector3(30, 0, 20), Vector3(30, 0, 40), Vector3(20, 0, 50)])
	spawn_enemy(Vector3(-6, 0, 30), Vector3.ZERO, [Vector3(-6, 0, 30), Vector3(-6, 0, 76), Vector3(6, 0, 76), Vector3(6, 0, 30)])
	spawn_enemy(Vector3(5, 0, 52), Vector3(-10, 0, 52))
	spawn_enemy(Vector3(CMD_HOUSE.x + 1.0, 0, CMD_HOUSE.z), Vector3(CMD_HOUSE.x + 10, 0, CMD_HOUSE.z))
	spawn_enemy(Vector3(CMD_HOUSE.x + 8.0, 0, CMD_HOUSE.z - 2.0), Vector3(0, 0, 52))
	spawn_enemy(Vector3(-24, 0, 36), Vector3.ZERO, [Vector3(-24, 0, 36), Vector3(-26, 0, 64)])
	spawn_enemy(Vector3(14, 0, 72), Vector3(0, 0, 100))
	spawn_enemy(Vector3(-4, 0, -12), Vector3(0, 0, -2))
	spawn_enemy(Vector3(10, 0, -18), Vector3(0, 0, -2))


# ================================================================ flow

func start() -> void:
	player.give_loadout(["knife", "m9", "m4"], "m9")
	player.grenades = 2
	player.medkits = 2
	insertion_heli = HeliScript.new()
	actors.add_child(insertion_heli)
	player.ride(insertion_heli, Vector3(1.2, 1.4, 0.4))
	player.set_yaw(0.0)
	hud.cinematic(true, 0.01)
	objective("Insertion")
	var tw: Tween = insertion_heli.fly_in(ground(LZ) + Vector3(60, 90, 260), ground(LZ), 0.15, 16.0)
	tw.finished.connect(_landed_insertion)
	say(["m2_intro_1"])


func _landed_insertion() -> void:
	player.stop_ride(ground(LZ) + Vector3(-3.5, 0.3, -5.0))
	player.set_yaw(0.0)
	hud.cinematic(false)
	insertion_heli.take_off(ground(LZ) + Vector3(-120, 90, 300), 14.0)
	get_tree().create_timer(18.0, false).timeout.connect(insertion_heli.queue_free)
	step = 1
	save_checkpoint()
	say(["m2_intro_2", "m2_intro_3"])
	interact(ground(ANTENNA) + Vector3(-7.0, 1.0, 0.0), "Hold [E] to plant C4 on the antenna", "PLANTING C4...", 3.0, _on_antenna_c4, 2.6)
	interact(ground(BOOTH) + Vector3(-1.0, 1.1, 0.0), "Hold [E] to open the gate", "OPENING GATE...", 2.0, _on_gate_console, 2.4)
	_update_objective()


func _update_objective() -> void:
	if not antenna_done:
		objective("Destroy the radio antenna", ground(ANTENNA) + Vector3.UP * 6.0)
	elif not has_key:
		objective("Find the gate keycard in the commander's house", ground(CMD_HOUSE) + Vector3.UP * 2.0)
	elif not gate_open:
		objective("Open the checkpoint gate from the guard booth", ground(BOOTH) + Vector3.UP * 2.0)
	elif not met:
		objective("Meet Lt. Rauf beyond the checkpoint", ground(RAUF) + Vector3.UP * 2.0)


func _on_antenna_c4() -> void:
	hud.notify("C4 PLANTED  -  GET CLEAR")
	plant_c4(ground(ANTENNA) + Vector3(-6.2, 0.2, 0.0), 8.0, _on_antenna_blown)


func _on_antenna_blown() -> void:
	antenna_done = true
	alarm.radio_up = false
	var tw := antenna_node.create_tween()
	tw.tween_property(antenna_node, "rotation:x", 1.45, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for c in antenna_node.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	say(["m2_antenna", "m2_antenna_ok"])
	save_checkpoint()
	_update_objective()


func _on_key(key: Node3D) -> void:
	has_key = true
	key.queue_free()
	say(["m2_key", "m2_key_ok"])
	hud.notify("GATE KEYCARD")
	save_checkpoint()
	_update_objective()


func _on_gate_console() -> void:
	if not has_key:
		hud.notify("YOU NEED THE GATE KEYCARD")
		get_tree().create_timer(0.5, false).timeout.connect(_reenable_gate_console)
		return
	gate_open = true
	Sfx.play3d("alarm", ground(GATE), -16.0, 60.0, 0.0)
	var tw := gate_node.create_tween()
	tw.tween_property(gate_node, "position:x", gate_node.position.x + 8.5, 4.0).set_trans(Tween.TRANS_SINE)
	say(["m2_gate"])
	_spawn_rauf()
	save_checkpoint()
	_update_objective()


func _reenable_gate_console() -> void:
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.prompt.begins_with("Hold [E] to open the gate"):
			it.enabled = true


func _spawn_rauf() -> void:
	rauf = Models.character("kade")
	actors.add_child(rauf)
	rauf.global_position = ground(RAUF)
	rauf.rotation.y = PI
	var ap := AnimationPlayer.new()
	rauf.add_child(ap)
	ap.add_animation_library("", Models.anim_library("kade"))
	ap.play("idle")
	rauf.set_meta("ap", ap)


func _step(_delta: float) -> void:
	if gate_open and not met and rauf != null and player.global_position.distance_to(rauf.global_position) < 6.0:
		met = true
		objective("Talk with Lt. Rauf")
		hud.set_marker(null)
		player.controls_enabled = false
		player.look_at_point(rauf.global_position + Vector3.UP * 1.6)
		hud.cinematic(true)
		say(["m2_rauf_1", "m2_rauf_2", "m2_rauf_3", "m2_end"], finish)
