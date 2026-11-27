extends Control
## Picture-in-picture "video call" feed, shown while a character speaks (IGI-style handler window).
## Renders a small live 3D scene in its own world: Major Malik typing at her desk in the operations office,
## or Kade in the field. Raven (the pilot) is audio-only with a static screen.

const UI = preload("res://scripts/core/ui.gd")
const Geo = preload("res://scripts/core/geo.gd")

var view: SubViewport
var cam: Camera3D
var name_lbl: Label
var sub_lbl: Label
var live_dot: ColorRect
var static_rect: ColorRect
var office: Node3D
var field: Node3D
var hide_t := 0.0
var t := 0.0
var current := ""
var malik_ap: AnimationPlayer
var kade_ap: AnimationPlayer
var env_office: Environment
var env_field: Environment


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, Control.PRESET_TOP_RIGHT, -366, 18, -20, 250)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.9)
	sb.border_color = Color(0.85, 0.64, 0.25, 0.9)
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	UI.full_rect(frame)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	view = SubViewport.new()
	view.size = Vector2i(384, 216)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	var tr := TextureRect.new()
	tr.texture = view.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	UI.place(tr, Control.PRESET_TOP_WIDE, 4, 4, -4, 196)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	# scanlines + static
	var scan := TextureRect.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 4:
		img.set_pixel(x, 0, Color(0, 0, 0, 0.22))
	scan.texture = ImageTexture.create_from_image(img)
	scan.stretch_mode = TextureRect.STRETCH_TILE
	UI.place(scan, Control.PRESET_TOP_WIDE, 4, 4, -4, 196)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)
	static_rect = ColorRect.new()
	static_rect.color = Color(0.6, 0.65, 0.6, 0.0)
	UI.place(static_rect, Control.PRESET_TOP_WIDE, 4, 4, -4, 196)
	static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(static_rect)
	live_dot = ColorRect.new()
	live_dot.color = Color(0.95, 0.15, 0.1)
	live_dot.position = Vector2(12, 12)
	live_dot.size = Vector2(9, 9)
	add_child(live_dot)
	var live := UI.label("LIVE", 12, Color(1, 1, 1, 0.9), true, UI.heavy_font(3, 0.4))
	live.position = Vector2(26, 6)
	add_child(live)
	name_lbl = UI.label("", 14, UI.ACCENT, true, UI.heavy_font(3, 0.5))
	name_lbl.position = Vector2(10, 200)
	add_child(name_lbl)
	sub_lbl = UI.label("", 11, Color(0.8, 0.8, 0.78), true)
	sub_lbl.position = Vector2(220, 203)
	add_child(sub_lbl)
	_build_office()
	_build_field()
	cam = Camera3D.new()
	cam.fov = 38.0
	view.add_child(cam)
	cam.current = true
	visible = false
	Sfx.voice_started.connect(_on_voice)


func _env(color_top: Color, ambient: Color, energy: float) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = color_top
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = energy
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	return e


func _build_office() -> void:
	office = Node3D.new()
	view.add_child(office)
	env_office = _env(Color(0.05, 0.06, 0.08), Color(0.55, 0.6, 0.7), 0.6)
	var wall := Fx.pbr("concrete_layers_02", 0.6, Color(0.55, 0.6, 0.65))
	Geo.mesh_box(office, Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), Fx.pbr("concrete_floor_worn_001", 0.5, Color(0.6, 0.6, 0.65)))
	Geo.mesh_box(office, Vector3(8, 3.2, 0.2), Vector3(0, 1.6, -1.6), wall)
	Geo.mesh_box(office, Vector3(0.2, 3.2, 8), Vector3(-2.6, 1.6, 0), wall)
	# wall screens with a map glow
	for i in 3:
		Geo.mesh_box(office, Vector3(1.1, 0.65, 0.04), Vector3(-1.4 + i * 1.25, 1.85, -1.48), Fx.mats["screen"])
	Geo.mesh_box(office, Vector3(1.6, 1.0, 0.04), Vector3(1.6, 1.7, -1.48), Fx.mats["map"])
	# desk, chair, laptop
	var desk := Models.make("table", false)
	desk.position = Vector3(0, 0, 0.62)
	office.add_child(desk)
	var chair := Models.make("chair", false)
	chair.position = Vector3(0, 0, -0.15)
	chair.rotation.y = PI
	office.add_child(chair)
	Geo.mesh_box(office, Vector3(0.36, 0.02, 0.25), Vector3(0, 0.8, 0.5), Fx.mats["gun_metal"])
	Geo.mesh_box(office, Vector3(0.36, 0.24, 0.015), Vector3(0, 0.92, 0.63), Fx.mats["screen"], Vector3(0.3, 0, 0))
	var malik := Models.character("malik")
	office.add_child(malik)
	malik.position = Vector3(0, 0, 0.0)
	malik_ap = AnimationPlayer.new()
	malik.add_child(malik_ap)
	malik_ap.add_animation_library("", Models.anim_library("malik"))
	if malik_ap.has_animation("typing"):
		malik_ap.play("typing")
	var key := OmniLight3D.new()
	key.light_color = Color(0.6, 0.75, 1.0)
	key.light_energy = 1.6
	key.omni_range = 4.0
	key.position = Vector3(0.1, 1.2, 1.0)
	office.add_child(key)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.3
	lamp.omni_range = 5.0
	lamp.position = Vector3(-1.4, 2.2, 0.6)
	office.add_child(lamp)


func _build_field() -> void:
	field = Node3D.new()
	field.position = Vector3(500, 0, 0)
	view.add_child(field)
	env_field = _env(Color(0.52, 0.68, 0.86), Color(0.75, 0.8, 0.85), 0.8)
	env_field.fog_enabled = true
	env_field.fog_light_color = Color(0.62, 0.72, 0.85)
	env_field.fog_density = 0.03
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.3
	field.add_child(sun)
	Geo.mesh_box(field, Vector3(60, 0.1, 60), Vector3(0, -0.05, 0), Fx.pbr("forrest_ground_01", 0.3))
	for p in [Vector3(-3, 0, -6), Vector3(2.5, 0, -9), Vector3(-7, 0, -12), Vector3(6, 0, -14)]:
		var tr := Models.make("pine", false)
		tr.position = p
		field.add_child(tr)
	var kade := Models.character("kade")
	field.add_child(kade)
	kade.rotation.y = 0.25
	kade_ap = AnimationPlayer.new()
	kade.add_child(kade_ap)
	kade_ap.add_animation_library("", Models.anim_library("kade"))
	kade_ap.play("idle")


func _on_voice(speaker: String, _text: String, dur: float) -> void:
	if speaker not in ["malik", "kade", "raven"]:
		return
	visible = true
	hide_t = dur + 0.4
	if speaker == current:
		return
	current = speaker
	static_rect.color.a = 0.85
	match speaker:
		"malik":
			name_lbl.text = "MAJOR S. MALIK"
			sub_lbl.text = "OVERWATCH - OPS"
			cam.environment = env_office
			cam.position = Vector3(0.35, 1.32, 1.55)
			cam.look_at(Vector3(0.0, 1.05, 0.05))
		"kade":
			name_lbl.text = "SGT. R. KADE"
			sub_lbl.text = "VANGUARD ONE - HELMET"
			cam.environment = env_field
			cam.position = field.position + Vector3(0.55, 1.6, 1.6)
			cam.look_at(field.position + Vector3(0.0, 1.45, 0.0))
		"raven":
			name_lbl.text = "RAVEN 2-6"
			sub_lbl.text = "AUDIO ONLY"
			static_rect.color.a = 0.95


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	hide_t -= delta
	if hide_t <= 0.0:
		visible = false
		current = ""
		return
	live_dot.visible = fmod(t, 1.0) < 0.6
	if current == "raven":
		static_rect.color = Color(randf_range(0.3, 0.6), randf_range(0.3, 0.6), randf_range(0.3, 0.6), 0.95)
	else:
		static_rect.color.a = move_toward(static_rect.color.a, 0.0, delta * 3.0)
		# slight hand-held camera drift
		cam.h_offset = sin(t * 0.9) * 0.01
		cam.v_offset = sin(t * 1.3) * 0.006
