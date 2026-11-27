extends CanvasLayer
## In-game HUD, overlays (binoculars, sniper scope, satellite map) and pause / fail / complete screens.

signal resume_pressed
signal retry_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed
signal quit_pressed

const UI = preload("res://scripts/core/ui.gd")
const Weapons = preload("res://scripts/player/weapons.gd")
const FeedScript = preload("res://scripts/ui/video_feed.gd")

const SPEAKERS := {"malik": "MAJOR MALIK", "kade": "KADE", "raven": "RAVEN 2-6", "rauf": "LT. RAUF"}
const TIPS := [
	"Use binoculars [B] to scout a base before you go in. Spotted enemies appear on your map [M].",
	"Guards who see you run to the alarm. Shoot the siren pole to silence it.",
	"Crouch [C] to move quietly and stay hidden. Sprinting makes noise.",
	"Your silenced M9 [2] won't alert guards further away.",
	"Knife [1] an unaware guard from behind for a silent kill.",
	"Health does not regenerate. Use medkits [H].",
	"Security cameras raise the alarm. Shoot them out or avoid their sweep.",
]


class Crosshair extends Control:
	var gap := 10.0

	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1, 1, 1, 0.85)
		var sh := Color(0, 0, 0, 0.5)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var a: Vector2 = c + d * gap
			var b: Vector2 = c + d * (gap + 8.0)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), sh, 2.0)
			draw_line(a, b, col, 2.0)
		draw_circle(c, 1.3, col)


class HitMarker extends Control:
	var col := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(c + dn * 7.0, c + dn * 17.0, col, 2.5)


class Diamond extends Control:
	var col := Color(1.0, 0.82, 0.25, 0.95)

	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0)])
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.75), 2.0)


class ScopeOverlay extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := size.y * 0.46
		var black := Color(0, 0, 0, 1)
		draw_rect(Rect2(0, 0, c.x - r, size.y), black)
		draw_rect(Rect2(c.x + r, 0, size.x - c.x - r, size.y), black)
		# corners outside the circle
		var steps := 64
		for i in steps:
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			var p0 := c + Vector2(cos(a0), sin(a0)) * r
			var p1 := c + Vector2(cos(a1), sin(a1)) * r
			var far0 := c + Vector2(cos(a0), sin(a0)) * size.x
			var far1 := c + Vector2(cos(a1), sin(a1)) * size.x
			draw_colored_polygon(PackedVector2Array([p0, far0, far1, p1]), black)
		draw_arc(c, r, 0, TAU, 96, Color(0, 0, 0), 6.0)
		var lc := Color(0, 0, 0, 0.9)
		draw_line(Vector2(c.x - r, c.y), Vector2(c.x - 12, c.y), lc, 2.0)
		draw_line(Vector2(c.x + 12, c.y), Vector2(c.x + r, c.y), lc, 2.0)
		draw_line(Vector2(c.x, c.y + 12), Vector2(c.x, c.y + r), lc, 2.0)
		draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - 12), lc, 1.0)
		for i in range(1, 5):
			draw_line(Vector2(c.x - 6, c.y + 12 + i * 22), Vector2(c.x + 6, c.y + 12 + i * 22), lc, 1.5)
		draw_circle(c, 1.5, Color(0.9, 0.1, 0.05))


class BinocOverlay extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := size.y * 0.42
		var black := Color(0, 0, 0, 1)
		var l := c + Vector2(-r * 0.62, 0)
		var rr := c + Vector2(r * 0.62, 0)
		var steps := 48
		# fill outside two circles (approximate with polygons per scanline band)
		var band := 4
		var y := 0
		while y < int(size.y):
			var yy := float(y) + band * 0.5
			var spans := []
			for cc in [l, rr]:
				var dy: float = yy - cc.y
				if absf(dy) < r:
					var dx := sqrt(r * r - dy * dy)
					spans.append([cc.x - dx, cc.x + dx])
			if spans.is_empty():
				draw_rect(Rect2(0, y, size.x, band), black)
			else:
				var x0: float = spans[0][0]
				var x1: float = spans[spans.size() - 1][1]
				if spans.size() == 2:
					x0 = minf(spans[0][0], spans[1][0])
					x1 = maxf(spans[0][1], spans[1][1])
				draw_rect(Rect2(0, y, x0, band), black)
				draw_rect(Rect2(x1, y, size.x - x1, band), black)
				if spans.size() == 2 and spans[0][1] < spans[1][0]:
					draw_rect(Rect2(spans[0][1], y, spans[1][0] - spans[0][1], band), black)
			y += band
		var lc := Color(0.1, 1.0, 0.3, 0.7)
		draw_line(c + Vector2(-40, 0), c + Vector2(40, 0), lc, 1.0)
		draw_line(c + Vector2(0, -30), c + Vector2(0, 30), lc, 1.0)
		for i in range(-4, 5):
			draw_line(c + Vector2(i * 10, -3), c + Vector2(i * 10, 3), lc, 1.0)


class MapOverlay extends Control:
	var hud

	func _draw() -> void:
		if hud == null or hud.mission == null:
			return
		var rect := Rect2(Vector2.ZERO, size)
		var m = hud.mission
		var pl = hud.player
		var s: float = m.map_size
		var c: Vector3 = m.map_center
		var f := func(p: Vector3) -> Vector2:
			return Vector2((p.x - (c.x - s / 2.0)) / s * size.x, (p.z - (c.z - s / 2.0)) / s * size.y)
		draw_rect(rect, Color(0.9, 0.9, 0.85, 1), false, 2.0)
		# grid
		for i in range(1, 6):
			var gx := size.x * i / 6.0
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(1, 1, 1, 0.12), 1.0)
			draw_line(Vector2(0, gx), Vector2(size.x, gx), Color(1, 1, 1, 0.12), 1.0)
		for e in hud.get_tree().get_nodes_in_group("enemy"):
			if e.get_meta("tagged_t", 0.0) > hud.clock or e.state == 3:
				var ep: Vector2 = f.call(e.global_position)
				draw_circle(ep, 5.0, Color(0.95, 0.15, 0.1))
				draw_arc(ep, 6.0, 0, TAU, 12, Color(0, 0, 0, 0.8), 1.5)
		for cam in hud.get_tree().get_nodes_in_group("security_camera"):
			if not cam.destroyed and cam.active:
				var cp: Vector2 = f.call(cam.global_position)
				draw_rect(Rect2(cp - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.55, 0.1))
		for ap in hud.get_tree().get_nodes_in_group("alarm_panel"):
			if not ap.destroyed:
				var app: Vector2 = f.call(ap.global_position)
				draw_string(ThemeDB.fallback_font, app + Vector2(-5, 6), "A", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 0.2, 0.2))
		if hud.marker_pos != null:
			var op: Vector2 = f.call(hud.marker_pos)
			var pts := PackedVector2Array([op + Vector2(0, -11), op + Vector2(11, 0), op + Vector2(0, 11), op + Vector2(-11, 0)])
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
		if pl != null:
			var pp: Vector2 = f.call(pl.global_position)
			var fwd := Vector2(-sin(pl.yaw), -cos(pl.yaw))
			var side := Vector2(-fwd.y, fwd.x)
			draw_colored_polygon(PackedVector2Array([pp + fwd * 12.0, pp - fwd * 7.0 + side * 7.0, pp - fwd * 4.0, pp - fwd * 7.0 - side * 7.0]), Color(0.2, 0.9, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 12), "N  ^", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))


var player
var mission
var clock := 0.0
var root: Control
var crosshair: Crosshair
var hitmark: HitMarker
var hit_t := 0.0
var obj_lbl: Label
var obj_flash := 0.0
var ammo_lbl: Label
var wpn_lbl: Label
var inv_lbl: Label
var status_lbl: Label
var hp_bar: ProgressBar
var hp_lbl: Label
var sub_lbl: RichTextLabel
var sub_t := 0.0
var prompt_lbl: Label
var prompt_bar: ProgressBar
var prompt_owner = null
var marker: Control
var marker_dist: Label
var marker_pos = null
var vignette: TextureRect
var flash_amt := 0.0
var fade_rect: ColorRect
var notify_lbl: Label
var notify_t := 0.0
var alarm_lbl: Label
var alt_lbl: Label
var scope: ScopeOverlay
var binoc: BinocOverlay
var binoc_lbl: Label
var tag_layer: Control
var map_panel: Control
var map_view: SubViewport
var map_cam: Camera3D
var map_overlay: MapOverlay
var map_refresh := 0.0
var panel_root: Control
var cine_bars: Array = []


func setup(p, m) -> void:
	player = p
	mission = m
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	UI.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_vignette()
	scope = ScopeOverlay.new()
	UI.full_rect(scope)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	root.add_child(scope)
	binoc = BinocOverlay.new()
	UI.full_rect(binoc)
	binoc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	binoc.visible = false
	root.add_child(binoc)
	binoc_lbl = UI.label("", 16, Color(0.2, 1.0, 0.4), true, UI.heavy_font(3, 0.3))
	UI.place(binoc_lbl, Control.PRESET_CENTER, -200, 60, 200, 90)
	binoc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(binoc_lbl)
	tag_layer = Control.new()
	UI.full_rect(tag_layer)
	tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_layer.draw.connect(_draw_tags)
	root.add_child(tag_layer)
	crosshair = Crosshair.new()
	UI.full_rect(crosshair)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	hitmark = HitMarker.new()
	UI.full_rect(hitmark)
	hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmark.modulate.a = 0.0
	root.add_child(hitmark)
	_build_objective()
	_build_status()
	_build_subtitles()
	_build_prompt()
	_build_marker()
	notify_lbl = UI.label("", 20, UI.ACCENT, true, UI.heavy_font(4, 0.5))
	UI.place(notify_lbl, Control.PRESET_CENTER_TOP, -400, 92, 400, 124)
	notify_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(notify_lbl)
	alarm_lbl = UI.label("ALARM", 22, Color(1, 0.2, 0.15), true, UI.heavy_font(8, 0.8))
	UI.place(alarm_lbl, Control.PRESET_CENTER_TOP, -200, 20, 200, 52)
	alarm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alarm_lbl.visible = false
	root.add_child(alarm_lbl)
	alt_lbl = UI.label("", 22, Color(0.9, 0.95, 1.0), true, UI.heavy_font(3, 0.5))
	UI.place(alt_lbl, Control.PRESET_CENTER_TOP, -400, 130, 400, 200)
	alt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(alt_lbl)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			UI.place(bar, Control.PRESET_TOP_WIDE, 0, 0, 0, 0)
		else:
			UI.place(bar, Control.PRESET_BOTTOM_WIDE, 0, 0, 0, 0)
		root.add_child(bar)
		cine_bars.append(bar)
	_build_map()
	var feed := FeedScript.new()
	root.add_child(feed)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	UI.full_rect(fade_rect)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	player.hit_confirmed.connect(_on_hit)
	player.damaged.connect(_on_damaged)
	Sfx.voice_started.connect(_on_voice)


func _build_vignette() -> void:
	vignette = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.6, 0, 0, 0), Color(0.6, 0, 0, 0.05), Color(0.5, 0, 0, 0.9)])
	gt.gradient = g
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	UI.full_rect(vignette)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)


func _build_objective() -> void:
	var box := VBoxContainer.new()
	UI.place(box, Control.PRESET_TOP_LEFT, 28, 22, 700, 120)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.add_child(UI.label("OBJECTIVE", 13, UI.ACCENT, true, UI.heavy_font(5, 0.6)))
	obj_lbl = UI.label("", 20, Color.WHITE, true, UI.heavy_font(1, 0.3))
	box.add_child(obj_lbl)


func _build_status() -> void:
	var box := VBoxContainer.new()
	UI.place(box, Control.PRESET_BOTTOM_RIGHT, -360, -140, -28, -22)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	wpn_lbl = UI.label("", 14, Color(0.85, 0.85, 0.82), true, UI.heavy_font(4, 0.4))
	wpn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(wpn_lbl)
	ammo_lbl = UI.label("", 40, Color.WHITE, true, UI.heavy_font(1, 0.6))
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(ammo_lbl)
	inv_lbl = UI.label("", 14, Color(0.85, 0.85, 0.8), true, UI.heavy_font(3, 0.3))
	inv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(inv_lbl)
	status_lbl = UI.label("", 17, UI.ACCENT, true, UI.heavy_font(3, 0.5))
	UI.place(status_lbl, Control.PRESET_CENTER, -300, 34, 300, 62)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_lbl)
	hp_bar = ProgressBar.new()
	hp_bar.max_value = 100.0
	hp_bar.show_percentage = false
	UI.place(hp_bar, Control.PRESET_BOTTOM_LEFT, 30, -44, 310, -30)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.35, 0.85, 0.4, 0.9)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fg)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bar)
	hp_lbl = UI.label("", 13, Color(0.85, 0.85, 0.82), true, UI.heavy_font(4, 0.4))
	UI.place(hp_lbl, Control.PRESET_BOTTOM_LEFT, 30, -68, 400, -46)
	root.add_child(hp_lbl)


func _build_subtitles() -> void:
	sub_lbl = RichTextLabel.new()
	sub_lbl.bbcode_enabled = true
	sub_lbl.fit_content = true
	sub_lbl.scroll_active = false
	sub_lbl.add_theme_font_size_override("normal_font_size", 20)
	sub_lbl.add_theme_font_size_override("bold_font_size", 20)
	sub_lbl.add_theme_constant_override("outline_size", 6)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	UI.place(sub_lbl, Control.PRESET_CENTER_BOTTOM, -540, -200, 540, -110)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub_lbl)


func _build_prompt() -> void:
	prompt_lbl = UI.label("", 19, Color.WHITE, true, UI.heavy_font(2, 0.4))
	UI.place(prompt_lbl, Control.PRESET_CENTER, -340, 74, 340, 104)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_lbl)
	prompt_bar = ProgressBar.new()
	prompt_bar.max_value = 1.0
	prompt_bar.show_percentage = false
	UI.place(prompt_bar, Control.PRESET_CENTER, -160, 110, 160, 118)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UI.ACCENT
	prompt_bar.add_theme_stylebox_override("background", bg)
	prompt_bar.add_theme_stylebox_override("fill", fg)
	prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_bar.visible = false
	root.add_child(prompt_bar)


func _build_marker() -> void:
	marker = Control.new()
	marker.size = Vector2(90, 56)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(marker)
	var d := Diamond.new()
	d.position = Vector2(34, 0)
	d.size = Vector2(22, 22)
	marker.add_child(d)
	marker_dist = UI.label("", 14, Color(1, 0.9, 0.6), true, UI.heavy_font(1, 0.4))
	marker_dist.position = Vector2(0, 24)
	marker_dist.size = Vector2(90, 24)
	marker_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_child(marker_dist)
	marker.visible = false


func _build_map() -> void:
	map_panel = Control.new()
	UI.full_rect(map_panel)
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.visible = false
	root.add_child(map_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	UI.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(shade)
	map_view = SubViewport.new()
	map_view.size = Vector2i(768, 768)
	map_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map_panel.add_child(map_view)
	map_cam = Camera3D.new()
	map_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_cam.far = 1500.0
	map_view.add_child(map_cam)
	var holder := Control.new()
	UI.place(holder, Control.PRESET_CENTER, -330, -330, 330, 330)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(holder)
	var tr := TextureRect.new()
	tr.texture = map_view.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	UI.full_rect(tr)
	tr.modulate = Color(0.9, 0.95, 0.9)
	holder.add_child(tr)
	map_overlay = MapOverlay.new()
	map_overlay.hud = self
	UI.full_rect(map_overlay)
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(map_overlay)
	var title := UI.label("SATELLITE MAP", 18, UI.ACCENT, true, UI.heavy_font(6, 0.6))
	UI.place(title, Control.PRESET_CENTER, -330, -366, 330, -336)
	map_panel.add_child(title)
	var legend := UI.label("YOU (blue)   OBJECTIVE (gold)   SPOTTED ENEMY (red)   CAMERA (orange)   A = ALARM", 13, Color(0.85, 0.85, 0.8))
	UI.place(legend, Control.PRESET_CENTER, -330, 336, 330, 360)
	map_panel.add_child(legend)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	clock += delta
	if player == null or not is_instance_valid(player):
		return
	var hp_f: float = 1.0 - player.hp / player.max_hp
	flash_amt = move_toward(flash_amt, 0.0, delta * 1.5)
	vignette.modulate.a = clampf(maxf(hp_f - 0.35, 0.0) * 1.3 + flash_amt, 0.0, 1.0)
	var playing: bool = not player.dead and panel_root == null and player.mode == 0
	var wd: Dictionary = Weapons.get_def(player.current)
	var scoped: bool = wd.get("scope", false) and player.ads > 0.85 and playing
	scope.visible = scoped
	binoc.visible = player.binocs and playing
	crosshair.visible = playing and player.ads < 0.5 and player.sprint_blend < 0.5 and not player.binocs and not map_panel.visible
	crosshair.gap = 8.0 + player.spread * 500.0 + Vector2(player.velocity.x, player.velocity.z).length() * 2.2
	crosshair.queue_redraw()
	hit_t = move_toward(hit_t, 0.0, delta)
	hitmark.modulate.a = clampf(hit_t / 0.2, 0.0, 1.0)
	wpn_lbl.text = wd.get("name", "")
	ammo_lbl.text = player.ammo_text()
	var low := false
	if player.current != "" and not wd.get("melee", false):
		low = player.inv[player.current].mag <= int(wd.mag * 0.2)
	ammo_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if low else Color.WHITE)
	inv_lbl.text = "GRENADES %d     MEDKITS %d" % [player.grenades, player.medkits]
	hp_bar.value = player.hp
	hp_lbl.text = "HEALTH  %d" % int(player.hp)
	var fg: StyleBoxFlat = hp_bar.get_theme_stylebox("fill")
	fg.bg_color = Color(0.35, 0.85, 0.4, 0.9) if player.hp > 50 else (Color(0.95, 0.75, 0.2, 0.9) if player.hp > 25 else Color(0.95, 0.25, 0.2, 0.95))
	if not playing:
		status_lbl.text = ""
	elif player.reloading:
		status_lbl.text = "RELOADING"
	elif low and player.current != "":
		status_lbl.text = "PRESS  [R]  TO RELOAD" if player.inv[player.current].reserve > 0 else "NO AMMO"
	else:
		status_lbl.text = ""
	var alarm = get_tree().get_first_node_in_group("alarm_system")
	alarm_lbl.visible = alarm != null and alarm.raised and fmod(clock, 1.0) < 0.65
	_altitude()
	_binocs(delta)
	_update_marker()
	if sub_t > 0.0:
		sub_t -= delta
		if sub_t <= 0.0:
			sub_lbl.text = ""
	if notify_t > 0.0:
		notify_t -= delta
		notify_lbl.modulate.a = clampf(notify_t, 0.0, 1.0)
	if obj_flash > 0.0:
		obj_flash -= delta
		var pulse := 0.5 + 0.5 * sin(obj_flash * 10.0)
		obj_lbl.modulate = Color(1, 1, 1).lerp(UI.ACCENT, pulse * clampf(obj_flash, 0.0, 1.0))
	else:
		obj_lbl.modulate = Color.WHITE
	var want_map: bool = Input.is_action_pressed("map") and playing
	if want_map != map_panel.visible:
		map_panel.visible = want_map
		if want_map:
			_refresh_map()
	if map_panel.visible:
		map_refresh -= delta
		if map_refresh <= 0.0:
			_refresh_map()
		map_overlay.queue_redraw()
	tag_layer.queue_redraw()


func _altitude() -> void:
	if player.mode == 1:
		var a: float = player.altitude()
		alt_lbl.text = "ALTITUDE  %d m\n%s" % [int(a), "PRESS  [SPACE]  TO OPEN PARACHUTE" if a < 650.0 else "FREEFALL - STEER WITH [W A S D]"]
	elif player.mode == 2:
		alt_lbl.text = "ALTITUDE  %d m\nSTEER  [A] [D]    BRAKE  [S]" % int(player.altitude())
	else:
		alt_lbl.text = ""


func _binocs(_delta: float) -> void:
	if not binoc.visible:
		binoc_lbl.text = ""
		return
	var cam: Camera3D = player.cam
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1200.0, 1 | 4, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var dist := -1.0
	if not hit.is_empty():
		dist = from.distance_to(hit.position)
	binoc_lbl.text = "RANGE  %s" % ("%d m" % int(dist) if dist > 0 else "---")
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = e.global_position + Vector3.UP * 1.2 - from
		var d := to.length()
		if d < 450.0 and fwd.dot(to / d) > 0.985:
			var q2 := PhysicsRayQueryParameters3D.create(from, e.global_position + Vector3.UP * 1.2, 1, [player.get_rid()])
			if player.get_world_3d().direct_space_state.intersect_ray(q2).is_empty():
				if e.get_meta("tagged_t", 0.0) < clock:
					Sfx.play("hitmarker", -16.0, 0.0)
				e.set_meta("tagged_t", clock + 60.0)


func _draw_tags() -> void:
	if player == null or player.dead or player.mode != 0:
		return
	var cam: Camera3D = player.cam
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_meta("tagged_t", 0.0) < clock:
			continue
		var wp: Vector3 = e.global_position + Vector3.UP * 2.15
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var col := Color(1.0, 0.2, 0.15, 0.9)
		tag_layer.draw_colored_polygon(PackedVector2Array([sp + Vector2(-6, -9), sp + Vector2(6, -9), sp]), col)


func _refresh_map() -> void:
	map_refresh = 1.0
	if mission == null:
		return
	map_view.world_3d = player.get_world_3d()
	map_cam.size = mission.map_size
	map_cam.global_position = mission.map_center + Vector3(0, 600, 0)
	map_cam.rotation = Vector3(-PI / 2.0, 0, 0)
	if mission.env != null and map_cam.environment == null:
		var e: Environment = mission.env.duplicate()
		e.fog_enabled = false
		e.glow_enabled = false
		e.ssao_enabled = false
		e.tonemap_exposure = 1.0
		map_cam.environment = e
	map_cam.current = true
	map_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_marker() -> void:
	if marker_pos == null or player.dead or player.mode == 3 or player.binocs:
		marker.visible = false
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := root.get_viewport_rect().size
	var wp: Vector3 = marker_pos
	if absf((wp - cam.global_position).dot(-cam.global_transform.basis.z)) < 0.05:
		return
	var sp := cam.unproject_position(wp)
	if cam.is_position_behind(wp):
		sp = Vector2(vp.x - sp.x, vp.y - 60.0)
	sp.x = clampf(sp.x, 50.0, vp.x - 50.0)
	sp.y = clampf(sp.y, 70.0, vp.y - 70.0)
	marker.position = sp - Vector2(45, 11)
	marker_dist.text = "%dm" % int(player.global_position.distance_to(wp))
	marker.visible = true


# ---------------------------------------------------------------- API

func set_objective(text: String) -> void:
	obj_lbl.text = text
	obj_flash = 2.5


func set_marker(pos) -> void:
	marker_pos = pos


func _on_voice(speaker: String, text: String, dur: float) -> void:
	if text == "":
		return
	var who: String = SPEAKERS.get(speaker, speaker.to_upper())
	var col := "#e0a940" if speaker != "kade" else "#8fd3ff"
	sub_lbl.text = "[center][color=%s][b]%s:[/b][/color]  %s[/center]" % [col, who, text]
	sub_t = dur


func hide_subtitle() -> void:
	pass


func show_prompt(text: String, progress: float, owner = null) -> void:
	prompt_owner = owner
	prompt_lbl.text = text
	prompt_bar.visible = progress > 0.0
	prompt_bar.value = progress


func hide_prompt() -> void:
	prompt_owner = null
	prompt_lbl.text = ""
	prompt_bar.visible = false


func notify(text: String) -> void:
	notify_lbl.text = text
	notify_t = 3.0
	notify_lbl.modulate.a = 1.0


func cinematic(on: bool, time := 0.6) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cine_bars[0], "offset_bottom", 80.0 if on else 0.0, time)
	tw.tween_property(cine_bars[1], "offset_top", -80.0 if on else 0.0, time)
	for n in [obj_lbl.get_parent(), hp_bar, hp_lbl, ammo_lbl.get_parent()]:
		tw.tween_property(n, "modulate:a", 0.0 if on else 1.0, time)


func fade(to_alpha: float, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, time)
	return tw


func set_black(a: float) -> void:
	fade_rect.color.a = a


func _on_hit(killed: bool, _headshot: bool) -> void:
	hit_t = 0.25
	hitmark.col = Color(1.0, 0.3, 0.25) if killed else Color.WHITE
	hitmark.queue_redraw()


func _on_damaged(_from) -> void:
	flash_amt = minf(flash_amt + 0.3, 0.6)


# ---------------------------------------------------------------- panels

func clear_panel() -> void:
	root.visible = true
	if panel_root != null:
		panel_root.queue_free()
		panel_root = null


func show_pause(on: bool) -> void:
	clear_panel()
	if on:
		var info: Dictionary = Game.mission_info(mission.mission_id)
		_panel("PAUSED", "Mission %d: %s   |   Difficulty: %s" % [info.id, info.name, Game.difficulty_name()], [
			["RESUME", resume_pressed], ["RESTART MISSION", restart_pressed],
			["QUIT TO MAIN MENU", menu_pressed], ["EXIT GAME", quit_pressed]])


func show_fail() -> void:
	clear_panel()
	root.visible = false
	_panel("MISSION FAILED", "Vanguard One is down.\n\nTIP: " + str(TIPS.pick_random()), [
		["RETRY FROM CHECKPOINT", retry_pressed], ["RESTART MISSION", restart_pressed], ["MAIN MENU", menu_pressed]],
		Color(0.9, 0.25, 0.2))


func show_complete(stats: Dictionary) -> void:
	clear_panel()
	root.visible = false
	var tt: float = stats.time
	var acc := 0.0
	if stats.shots > 0:
		acc = 100.0 * float(stats.hits) / float(stats.shots)
	var info: Dictionary = Game.mission_info(stats.mission)
	var body := "Mission %d: %s\n\n" % [info.id, info.name]
	body += "TIME  %d:%02d     KILLS  %d     STEALTH KILLS  %d\n" % [int(tt) / 60, int(tt) % 60, stats.kills, stats.stealth_kills]
	body += "HEADSHOTS  %d     ACCURACY  %.0f%%     ALARM  %s\n" % [stats.headshots, acc, "RAISED" if stats.alarm else "NEVER RAISED"]
	body += "DIFFICULTY  %s" % stats.difficulty
	var buttons := []
	if stats.mission < Game.MISSIONS.size():
		buttons.append(["NEXT MISSION", next_pressed])
	buttons.append_array([["PLAY AGAIN", restart_pressed], ["MAIN MENU", menu_pressed]])
	_panel("MISSION COMPLETE", body, buttons, Color(0.55, 0.85, 0.45))


func _panel(title: String, body: String, buttons: Array, title_color := Color.WHITE) -> void:
	panel_root = Control.new()
	UI.full_rect(panel_root)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_root)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.74)
	UI.full_rect(bg)
	panel_root.add_child(bg)
	var box := VBoxContainer.new()
	UI.place(box, Control.PRESET_CENTER, -340, -250, 340, 250)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel_root.add_child(box)
	box.add_child(UI.label(title, 44, title_color, true, UI.heavy_font(6, 0.8)))
	if body != "":
		var bl := UI.label(body, 17, Color(0.85, 0.85, 0.82))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(660, 0)
		box.add_child(bl)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)
	for b in buttons:
		var sig: Signal = b[1]
		box.add_child(UI.button(b[0], func(): sig.emit()))
