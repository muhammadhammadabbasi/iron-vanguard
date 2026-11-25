extends Node3D
## Entry point: main menu, mission select, briefing, loading, mission lifecycle, pause / fail / complete.

const PlayerScript = preload("res://scripts/player/player.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const UI = preload("res://scripts/core/ui.gd")
const Geo = preload("res://scripts/core/geo.gd")

var actors: Node3D
var player
var hud
var mission
var menu_layer: CanvasLayer
var menu_scene: Node3D
var menu_cam: Camera3D
var menu_angle := 0.0
var state := "boot"
var briefing_ready := false
var pending_mission := 1
var panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actors = Node3D.new()
	actors.name = "Actors"
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(actors)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var at = load("res://scripts/autotest.gd").new()
		add_child(at)
		at.run(self)
		return
	if Game.skip_menu:
		Game.skip_menu = false
		load_mission(Game.current_mission)
	else:
		show_menu()


# ================================================================ menu

func _menu_background() -> void:
	menu_scene = Node3D.new()
	add_child(menu_scene)
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	var hdr := "res://assets/polyhaven/hdris/belfast_sunset_puresky/belfast_sunset_puresky.hdr"
	if ResourceLoader.exists(hdr):
		pm.panorama = load(hdr)
	sky.sky_material = pm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.fog_enabled = true
	e.fog_density = 0.004
	e.fog_light_color = Color(0.6, 0.45, 0.35)
	var we := WorldEnvironment.new()
	we.environment = e
	menu_scene.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, -60, 0)
	sun.light_color = Color(1.0, 0.7, 0.5)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	menu_scene.add_child(sun)
	var gnd := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	gnd.mesh = plane
	gnd.material_override = Fx.pbr("rocky_terrain_02", 0.25)
	menu_scene.add_child(gnd)
	if Models.has("blackhawk"):
		var hb := Models.make("blackhawk")
		hb.position = Vector3(4, 0, -2)
		hb.rotation.y = 0.6
		menu_scene.add_child(hb)
	var kade := Models.character("kade")
	menu_scene.add_child(kade)
	kade.position = Vector3(-2.5, 0, 3.5)
	kade.rotation.y = 0.3
	var ap := AnimationPlayer.new()
	kade.add_child(ap)
	ap.add_animation_library("", Models.anim_library("kade"))
	ap.play("idle")
	for i in 3:
		var s := Models.character("swat")
		menu_scene.add_child(s)
		s.position = Vector3(14 + i * 2.2, 0, 8 - i * 3.0)
		s.rotation.y = -1.2
		var ap2 := AnimationPlayer.new()
		s.add_child(ap2)
		ap2.add_animation_library("", Models.anim_library("swat"))
		ap2.play("idle")
		ap2.seek(i * 1.3, true)
	for p in [Vector3(-14, 0, -12), Vector3(-20, 0, -4), Vector3(18, 0, -18), Vector3(-30, 0, -30), Vector3(26, 0, -34)]:
		if Models.has("pine"):
			var tr := Models.make("pine")
			tr.position = p
			menu_scene.add_child(tr)
	menu_cam = Camera3D.new()
	menu_cam.fov = 50.0
	menu_cam.far = 1500.0
	menu_scene.add_child(menu_cam)
	menu_cam.current = true
	_update_menu_cam(0.0)


func _update_menu_cam(delta: float) -> void:
	menu_angle += delta * 0.03
	menu_cam.position = Vector3(sin(menu_angle) * 9.0 - 2.0, 2.2, 12.0 + cos(menu_angle) * 2.0)
	menu_cam.look_at(Vector3(1.5, 1.6, 0), Vector3.UP)


func show_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu_scene == null:
		_menu_background()
	if menu_layer != null:
		menu_layer.queue_free()
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.width = 256
	gt.height = 8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.92), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	gt.gradient = g
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	UI.place(shade, Control.PRESET_LEFT_WIDE, 0, 0, 900, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)
	var box := VBoxContainer.new()
	UI.place(box, Control.PRESET_CENTER_LEFT, 80, -290, 640, 330)
	box.add_theme_constant_override("separation", 10)
	menu_layer.add_child(box)
	box.add_child(UI.label("TASK FORCE VANGUARD", 16, UI.ACCENT, false, UI.heavy_font(8, 0.5)))
	box.add_child(UI.label("IRON VANGUARD", 64, Color(0.95, 0.94, 0.9), true, UI.heavy_font(6, 1.0)))
	box.add_child(UI.label("A TACTICAL STEALTH SHOOTER", 18, Color(0.75, 0.75, 0.72), false, UI.heavy_font(5, 0.4)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	box.add_child(sp)
	box.add_child(UI.button("CAMPAIGN", _show_missions))
	box.add_child(UI.button("SETTINGS", _show_settings))
	box.add_child(UI.button("CONTROLS", _show_controls))
	box.add_child(UI.button("CREDITS", _show_credits))
	box.add_child(UI.button("EXIT GAME", func(): get_tree().quit()))
	var foot := UI.label("v0.2  -  Missions 1-3 of 20  -  F11 toggles fullscreen", 13, Color(0.7, 0.7, 0.68), false)
	UI.place(foot, Control.PRESET_BOTTOM_LEFT, 80, -44, 800, -20)
	menu_layer.add_child(foot)
	panel = Control.new()
	UI.place(panel, Control.PRESET_CENTER_RIGHT, -620, -300, -70, 300)
	menu_layer.add_child(panel)


func _clear_panel() -> Control:
	for c in panel.get_children():
		c.queue_free()
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.05, 0.86)
	sb.border_color = UI.ACCENT
	sb.border_width_left = 4
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	pc.add_theme_stylebox_override("panel", sb)
	UI.full_rect(pc)
	panel.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v


func _show_missions() -> void:
	var v := _clear_panel()
	v.add_child(UI.label("CAMPAIGN", 22, UI.ACCENT, false, UI.heavy_font(5, 0.6)))
	for m in Game.MISSIONS:
		var unlocked: bool = m.id <= Game.unlocked
		var b := UI.button("%02d   %s" % [m.id, m.name], func(): _briefing(m.id), 490)
		b.disabled = not unlocked
		v.add_child(b)
		v.add_child(UI.label("      " + m.place + ("" if unlocked else "   (locked)"), 14, Color(0.7, 0.7, 0.68), false))
	v.add_child(UI.label("\nMissions 4-20 arrive in the next updates.", 14, Color(0.6, 0.6, 0.58), false))


func _show_settings() -> void:
	var v := _clear_panel()
	v.add_child(UI.label("SETTINGS", 22, UI.ACCENT, false, UI.heavy_font(5, 0.6)))
	var diff_btn := UI.button("", func(): pass, 490)
	diff_btn.pressed.connect(func():
		Game.difficulty = (Game.difficulty + 1) % 3
		Game.save()
		diff_btn.text = "DIFFICULTY:  " + Game.difficulty_name())
	diff_btn.text = "DIFFICULTY:  " + Game.difficulty_name()
	v.add_child(diff_btn)
	var q_btn := UI.button("", func(): pass, 490)
	q_btn.pressed.connect(func():
		Game.quality = (Game.quality + 1) % 3
		Game.save()
		q_btn.text = "GRAPHICS:  " + Game.QUALITY_NAMES[Game.quality])
	q_btn.text = "GRAPHICS:  " + Game.QUALITY_NAMES[Game.quality]
	v.add_child(q_btn)
	var fs_btn := UI.button("", func(): pass, 490)
	fs_btn.pressed.connect(func():
		Game.fullscreen = not Game.fullscreen
		Game.apply_window()
		Game.save()
		fs_btn.text = "FULLSCREEN:  " + ("ON" if Game.fullscreen else "OFF"))
	fs_btn.text = "FULLSCREEN:  " + ("ON" if Game.fullscreen else "OFF")
	v.add_child(fs_btn)
	for s in [["MOUSE SENSITIVITY", "sensitivity", 0.05, 1.0], ["VOLUME", "volume", 0.0, 1.0]]:
		var row := HBoxContainer.new()
		var lbl := UI.label(s[0], 17, Color(0.9, 0.9, 0.88), true, UI.heavy_font(3, 0.4))
		lbl.custom_minimum_size = Vector2(230, 0)
		row.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = 0.01
		sl.value = Game.get(s[1])
		sl.custom_minimum_size = Vector2(230, 30)
		sl.focus_mode = Control.FOCUS_NONE
		var key: String = s[1]
		sl.value_changed.connect(func(val):
			Game.set(key, val)
			if key == "volume":
				Game.apply_volume()
			Game.save())
		row.add_child(sl)
		v.add_child(row)
	v.add_child(UI.label("\nGRAPHICS: use LOW on Intel UHD / older laptops,\nMEDIUM or HIGH on a dedicated graphics card.", 14, Color(0.7, 0.7, 0.68), false))


func _show_controls() -> void:
	var v := _clear_panel()
	v.add_child(UI.label("CONTROLS", 22, UI.ACCENT, false, UI.heavy_font(5, 0.6)))
	var rows := [["Move", "W A S D"], ["Fire / Aim", "Left / Right mouse"], ["Reload", "R"], ["Weapons", "1-5 or mouse wheel"],
		["Sprint / Crouch / Jump", "Shift / C / Space"], ["Grenade", "G"], ["Medkit", "H"], ["Binoculars", "B"],
		["Satellite map", "Hold M or Tab"], ["Interact", "Hold E"], ["Parachute", "Space (open), A/D steer"], ["Pause", "Esc"]]
	for r in rows:
		var hb := HBoxContainer.new()
		var a := UI.label(r[0], 16, Color(0.85, 0.85, 0.82), false)
		a.custom_minimum_size = Vector2(230, 0)
		hb.add_child(a)
		hb.add_child(UI.label(r[1], 16, Color.WHITE, false, UI.heavy_font(2, 0.4)))
		v.add_child(hb)


func _show_credits() -> void:
	var v := _clear_panel()
	v.add_child(UI.label("CREDITS", 22, UI.ACCENT, false, UI.heavy_font(5, 0.6)))
	var txt := "Characters and animations: Mixamo (Adobe)\nTextures, skies, props: Poly Haven (CC0)\nVoices: Piper neural TTS\n\n3D models from Sketchfab (CC BY):\n"
	if FileAccess.file_exists("res://CREDITS.md"):
		var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
		for line in f.get_as_text().split("\n"):
			if line.begins_with("- **"):
				txt += line.replace("- **", "").replace("**", "").get_slice(" - https", 0) + "\n"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(490, 470)
	var l := UI.label(txt, 13, Color(0.85, 0.85, 0.82), false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(470, 0)
	sc.add_child(l)
	v.add_child(sc)


# ================================================================ briefing + loading

func _briefing(id: int) -> void:
	pending_mission = id
	state = "briefing"
	briefing_ready = false
	for c in menu_layer.get_children():
		c.queue_free()
	var info: Dictionary = Game.mission_info(id)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.94)
	UI.full_rect(bg)
	menu_layer.add_child(bg)
	var box := VBoxContainer.new()
	UI.place(box, Control.PRESET_CENTER, -480, -250, 480, 270)
	box.add_theme_constant_override("separation", 12)
	menu_layer.add_child(box)
	box.add_child(UI.label("MISSION %02d" % id, 18, UI.ACCENT, false, UI.heavy_font(6, 0.5)))
	box.add_child(UI.label(info.name, 44, Color(0.95, 0.94, 0.9), false, UI.heavy_font(6, 0.9)))
	box.add_child(UI.label("%s   -   %s   -   SGT. R. KADE" % [info.place.to_upper(), info.time], 15, Color(0.75, 0.75, 0.72), false, UI.heavy_font(3, 0.3)))
	var body := UI.label(info.brief, 19, Color(0.88, 0.88, 0.85), false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(940, 0)
	body.visible_ratio = 0.0
	box.add_child(body)
	var cont := UI.label("", 18, UI.ACCENT, false, UI.heavy_font(4, 0.5))
	box.add_child(cont)
	var tw := body.create_tween()
	tw.tween_property(body, "visible_ratio", 1.0, 4.0)
	tw.tween_callback(func(): cont.text = "CLICK OR PRESS SPACE TO DEPLOY")
	get_tree().create_timer(0.8).timeout.connect(_allow_deploy)


func _allow_deploy() -> void:
	briefing_ready = true


func load_mission(id: int) -> void:
	state = "loading"
	Game.current_mission = id
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	if menu_scene != null:
		menu_scene.queue_free()
		menu_scene = null
	var load_layer := CanvasLayer.new()
	load_layer.layer = 50
	add_child(load_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	UI.full_rect(bg)
	load_layer.add_child(bg)
	var info: Dictionary = Game.mission_info(id)
	var l := UI.label("LOADING  -  %s" % info.name, 26, UI.ACCENT, false, UI.heavy_font(8, 0.6))
	UI.place(l, Control.PRESET_CENTER, -400, -20, 400, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_layer.add_child(l)
	var tip := UI.label(str(HudScript.TIPS.pick_random()), 16, Color(0.75, 0.75, 0.72), false)
	UI.place(tip, Control.PRESET_CENTER_BOTTOM, -500, -90, 500, -50)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_layer.add_child(tip)
	await get_tree().process_frame
	await get_tree().process_frame
	player = PlayerScript.new()
	player.name = "Player"
	actors.add_child(player)
	player.global_position = Vector3(0, 500, 0)
	player.controls_enabled = false
	mission = load(info.script).new()
	mission.name = "Mission"
	mission.mission_id = id
	mission.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(mission)
	hud = HudScript.new()
	add_child(hud)
	mission.setup(self, player, hud)
	hud.setup(player, mission)
	mission.build()
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.retry_pressed.connect(_retry)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_to_menu)
	hud.next_pressed.connect(_next)
	hud.quit_pressed.connect(func(): get_tree().quit())
	mission.completed.connect(_on_complete)
	player.died.connect(_on_player_died)
	await get_tree().process_frame
	await get_tree().physics_frame
	load_layer.queue_free()
	state = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_black(1.0)
	hud.fade(0.0, 1.5)
	mission.start()


# ================================================================ in-game

func set_paused(on: bool) -> void:
	if on and state != "playing":
		return
	if not on and state != "paused":
		return
	get_tree().paused = on
	state = "paused" if on else "playing"
	hud.show_pause(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	match state:
		"playing":
			if event.is_action_pressed("pause"):
				set_paused(true)
			elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"paused":
			if event.is_action_pressed("pause"):
				set_paused(false)
		"briefing":
			if not briefing_ready:
				return
			var go := false
			if event is InputEventMouseButton and event.pressed:
				go = true
			elif event is InputEventKey and event.pressed and (event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER):
				go = true
			if go:
				Sfx.play("ui_click", -6.0, 0.0)
				load_mission(pending_mission)


func _process(delta: float) -> void:
	if state in ["menu", "briefing"] and menu_cam != null and is_instance_valid(menu_cam):
		_update_menu_cam(delta)


func _on_player_died() -> void:
	state = "dead"
	Sfx.voice("g_failed")
	await get_tree().create_timer(2.2).timeout
	if state != "dead":
		return
	hud.show_fail()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _retry() -> void:
	hud.clear_panel()
	mission.respawn()
	state = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_complete(stats: Dictionary) -> void:
	state = "complete"
	await hud.fade(1.0, 1.5).finished
	hud.show_complete(stats)
	hud.set_black(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restart() -> void:
	Game.skip_menu = true
	_reload()


func _next() -> void:
	Game.current_mission = mini(Game.current_mission + 1, Game.MISSIONS.size())
	Game.skip_menu = true
	_reload()


func _to_menu() -> void:
	Game.skip_menu = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()
