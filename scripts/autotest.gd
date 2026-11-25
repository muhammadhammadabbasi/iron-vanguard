extends Node
## Automated play-through:  godot --fixed-fps 60 -- --autotest --mission=1 [--shots=DIR]

var main
var shots_dir := ""
var fails := 0
var mid := 1


func _log(msg: String) -> void:
	print("AUTOTEST: ", msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_log("PASS  " + msg)
	else:
		fails += 1
		_log("FAIL  " + msg)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, false).timeout


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join("m%d_%s.png" % [mid, name]))
	_log("screenshot " + name)


func _hold(action: String, secs: float) -> void:
	var tt := 0.0
	while tt < secs:
		Input.action_press(action)
		await _wait(0.1)
		tt += 0.1
	Input.action_release(action)


func _wait_until(cond: Callable, timeout: float) -> bool:
	var tt := 0.0
	while not cond.call() and tt < timeout:
		await _wait(0.25)
		tt += 0.25
	return cond.call()


func _stand(p, pos: Vector3, look: Vector3) -> void:
	p.global_position = pos + Vector3.UP * 0.3
	p.velocity = Vector3.ZERO
	await _wait(0.2)
	p.look_at_point(look)


func run(m) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		if a.begins_with("--mission="):
			mid = int(a.substr(10))
	await _wait(0.2)
	if mid == 0:
		main.show_menu()
		await _wait(2.0)
		await _shot("menu")
		main._show_missions()
		await _wait(0.5)
		await _shot("missions")
		main._show_settings()
		await _wait(0.5)
		await _shot("settings")
		main._briefing(1)
		await _wait(4.5)
		await _shot("briefing")
		_finish()
		return
	await main.load_mission(mid)
	var p = main.player
	var ms = main.mission
	p.god = true
	_check(main.get_tree().get_nodes_in_group("enemy").size() >= 12, "enemies spawned (%d)" % main.get_tree().get_nodes_in_group("enemy").size())
	var nm: NavigationMesh = ms.nav.navigation_mesh
	_check(nm != null and nm.get_polygon_count() > 50, "navmesh baked (%d polygons)" % (nm.get_polygon_count() if nm != null else 0))
	match mid:
		1:
			await _m1(p, ms)
		2:
			await _m2(p, ms)
		3:
			await _m3(p, ms)
	_finish()


func _finish() -> void:
	_log("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _combat_checks(p, ms, look_from: Vector3) -> void:
	# shooting
	var enemies = main.get_tree().get_nodes_in_group("enemy")
	var target = null
	var best := INF
	for e in enemies:
		var d: float = e.global_position.distance_to(look_from)
		if d < best and not e.stationary:
			best = d
			target = e
	if target == null:
		_check(false, "no enemy to test shooting")
		return
	await _stand(p, target.global_position + Vector3(0, 0, 9), target.global_position)
	var hp0: float = target.hp
	p.equip("m4", true)
	for i in 8:
		if not target.is_in_group("enemy"):
			break
		p.look_at_point(target.global_position + Vector3.UP * 1.2)
		p.ads = 1.0
		p.fire_cd = 0.0
		p._fire()
		await _wait(0.15)
	_check(target.hp < hp0, "rifle damages an enemy (hp %.0f -> %.0f)" % [hp0, target.hp])
	await _wait(2.5)
	var moving := 0
	for e in main.get_tree().get_nodes_in_group("enemy"):
		if Vector2(e.velocity.x, e.velocity.z).length() > 0.5:
			moving += 1
	_check(moving >= 2, "alerted enemies are moving (%d)" % moving)
	await _shot("combat")
	# binoculars + map
	p.binocs = true
	await _wait(0.6)
	await _shot("binoculars")
	p.binocs = false
	Input.action_press("map")
	await _wait(0.8)
	await _shot("map")
	Input.action_release("map")
	# grenade + medkit
	p.throw_grenade()
	await _wait(3.0)
	p.god = false
	p.hp = 40.0
	p.use_medkit()
	_check(p.hp > 90.0, "medkit heals (hp %.0f)" % p.hp)
	# death + checkpoint
	p.take_damage(1000.0, Vector3.ZERO, false, "explosion")
	_check(p.dead, "player can die")
	await _wait(3.0)
	_check(main.hud.panel_root != null, "mission failed screen shown")
	await _shot("failed")
	main._retry()
	await _wait(0.5)
	_check(not p.dead, "retry from checkpoint works")
	p.god = true
	for e in main.get_tree().get_nodes_in_group("enemy"):
		e.forget()


func _m1(p, ms) -> void:
	await _wait(3.0)
	await _shot("plane")
	ms._jump()
	await _wait(2.5)
	_check(p.mode == 1, "freefall after jump")
	await _shot("freefall")
	p.global_position = ms.ground(ms.DZ) + Vector3(0, 120, 30)
	p.velocity = Vector3(0, -40, 0)
	await _wait(0.5)
	p.open_chute()
	await _wait(1.5)
	p.pitch = 0.6
	await _wait(0.4)
	await _shot("canopy")
	_check(await _wait_until(func(): return p.mode == 0, 40.0), "landed with parachute")
	await _wait(1.0)
	_check(ms.step == 2, "step 2 after landing")
	await _stand(p, ms.ground(Vector3(-60, 0, 50)), ms.ground(Vector3(-10, 0, 10)) + Vector3.UP * 3.0)
	await _wait(1.0)
	await _shot("outpost")
	await _combat_checks(p, ms, Vector3(0, 0, 30))
	await _stand(p, ms.ground(ms.MAST) + Vector3(7.4, 0, 0.0), ms.ground(ms.MAST) + Vector3.UP * 2.0)
	await _hold("interact", 3.6)
	_check(ms.mast_planted, "C4 planted on mast")
	await _stand(p, ms.ground(Vector3(-50, 0, 30)), ms.ground(ms.MAST) + Vector3.UP * 8.0)
	_check(await _wait_until(func(): return ms.mast_done, 12.0), "radio mast destroyed")
	await _wait(1.0)
	await _shot("mast_down")
	_check(not ms.alarm.radio_up, "reinforcements cut off")
	var lap: Vector3 = ms.ground(Vector3(ms.OFFICE.x + 2.5, 0, ms.OFFICE.z - 1.0))
	await _stand(p, lap, lap + Vector3(0, 0.9, -1.4))
	await _shot("office")
	await _hold("interact", 4.6)
	_check(ms.laptop_done, "laptop downloaded")
	await _wait(1.0)
	_check(ms.extraction_called, "extraction called")
	_check(await _wait_until(func(): return ms.heli_ready, 30.0), "helicopter landed")
	await _stand(p, ms.ground(ms.LZ) + Vector3(-14, 0, 12), ms.heli.global_position + Vector3.UP * 2.0)
	await _shot("helicopter")
	await _stand(p, ms.heli.global_position + ms.heli.global_transform.basis.x * 2.6, ms.heli.global_position)
	await _hold("interact", 1.4)
	_check(await _wait_until(func(): return ms.done, 10.0), "mission 1 complete")
	await _wait(2.5)
	await _shot("complete")


func _m2(p, ms) -> void:
	await _wait(6.0)
	await _shot("insertion")
	_check(await _wait_until(func(): return ms.step == 1, 30.0), "inserted by helicopter")
	await _wait(1.0)
	await _stand(p, ms.ground(Vector3(0, 0, 96)), ms.ground(Vector3(0, 0, 40)) + Vector3.UP * 3.0)
	await _shot("village")
	await _combat_checks(p, ms, Vector3(0, 0, 50))
	await _stand(p, ms.ground(ms.ANTENNA) + Vector3(-7.4, 0, 0.0), ms.ground(ms.ANTENNA) + Vector3.UP * 2.0)
	await _hold("interact", 3.6)
	await _stand(p, ms.ground(Vector3(0, 0, 50)), ms.ground(ms.ANTENNA) + Vector3.UP * 8.0)
	_check(await _wait_until(func(): return ms.antenna_done, 12.0), "antenna destroyed")
	var kp: Vector3 = ms.ground(Vector3(ms.CMD_HOUSE.x - 3.0, 0, ms.CMD_HOUSE.z + 3.2))
	await _stand(p, kp, kp + Vector3(0, 0.8, -1.2))
	await _shot("commander_house")
	await _hold("interact", 1.6)
	_check(ms.has_key, "keycard taken")
	await _stand(p, ms.ground(ms.BOOTH) + Vector3(-1.0, 0, 0.5), ms.ground(ms.GATE))
	await _hold("interact", 2.6)
	_check(ms.gate_open, "gate opened")
	await _wait(4.5)
	await _stand(p, ms.ground(Vector3(0, 0, 10)), ms.ground(Vector3(0, 0, -30)) + Vector3.UP * 1.5)
	await _shot("gate_open")
	await _stand(p, ms.ground(ms.RAUF) + Vector3(0, 0, 4.0), ms.ground(ms.RAUF) + Vector3.UP * 1.6)
	_check(await _wait_until(func(): return ms.met, 5.0), "met Rauf")
	await _wait(1.5)
	await _shot("rauf")
	_check(await _wait_until(func(): return ms.done, 40.0), "mission 2 complete")


func _m3(p, ms) -> void:
	await _wait(2.0)
	await _shot("start")
	await _stand(p, ms.ground(Vector3(20, 0, 70)), ms.ground(Vector3(0, 0, 0)) + Vector3.UP * 6.0)
	await _wait(0.5)
	await _shot("hill")
	await _combat_checks(p, ms, Vector3(0, 0, 30))
	var con: Vector3 = ms.ground(Vector3(ms.CONTROL.x - 1.8, 0, ms.CONTROL.z - 1.4))
	await _stand(p, con, con + Vector3(0, 1.2, -2.0))
	await _shot("control_room")
	await _hold("interact", 3.6)
	_check(ms.cams_done, "cameras shut down")
	await _stand(p, ms.ground(ms.RADAR) + Vector3(-3.0, 0, 3.0), ms.ground(ms.RADAR) + Vector3.UP * 4.0)
	await _hold("interact", 3.6)
	_check(ms.radar_planted, "C4 planted on radar")
	await _stand(p, ms.ground(Vector3(-20, 0, 25)), ms.ground(ms.RADAR) + Vector3.UP * 6.0)
	_check(await _wait_until(func(): return ms.radar_done, 14.0), "radar destroyed")
	await _wait(1.2)
	await _shot("radar_down")
	_check(await _wait_until(func(): return ms.heli_ready, 30.0), "helicopter landed on the pad")
	await _stand(p, ms.heli.global_position + ms.heli.global_transform.basis.x * 2.6, ms.heli.global_position)
	await _shot("pad")
	await _hold("interact", 1.4)
	_check(await _wait_until(func(): return ms.done, 10.0), "mission 3 complete")
	await _wait(2.5)
	await _shot("complete")
