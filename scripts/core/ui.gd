extends RefCounted
## UI construction helpers shared by the menus and the HUD.

const ACCENT := Color(0.85, 0.64, 0.25)


static func heavy_font(spacing := 4, embolden := 0.6) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = spacing
	fv.variation_embolden = embolden
	return fv


static func label(text: String, size: int, color := Color.WHITE, outline := true, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _box(bg: Color, border: Color, left := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = left
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func button(text: String, cb: Callable, width := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", heavy_font(3, 0.4))
	b.add_theme_stylebox_override("normal", _box(Color(0.05, 0.06, 0.07, 0.72), Color(0.4, 0.4, 0.4, 0.6), 3))
	b.add_theme_stylebox_override("hover", _box(Color(0.85, 0.64, 0.25, 0.92), ACCENT, 6))
	b.add_theme_stylebox_override("pressed", _box(Color(0.65, 0.48, 0.18, 0.95), ACCENT, 6))
	b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	b.pressed.connect(func(): Sfx.play("ui_click", -6.0, 0.0))
	b.pressed.connect(cb)
	return b


static func place(c: Control, preset: Control.LayoutPreset, l: float, t: float, r: float, b: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
