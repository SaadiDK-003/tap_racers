extends Control
## Awards: every achievement with how to earn it, its coin reward and whether it's done.

const CoinBadge = preload("res://scripts/coin_badge.gd")


func _ready() -> void:
	theme = Game.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var landscape := Game.is_landscape_layout()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.fit_to_safe(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	var done := 0
	for a in Profile.ACHIEVEMENTS:
		if Profile.has_achievement(a[0]):
			done += 1
	header.add_child(_label("AWARDS", 50, 10, Game.ACCENT))
	header.add_child(_label("%d / %d" % [done, Profile.ACHIEVEMENTS.size()], 30, 6, Color(1, 1, 1, 0.8)))
	header.add_child(CoinBadge.new())
	outer.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2 if landscape else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for a in Profile.ACHIEVEMENTS:
		grid.add_child(_card(a))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 60)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	outer.add_child(back_row)


func _card(a: Array) -> Control:
	var got := Profile.has_achievement(a[0])
	var col := Color(1.0, 0.8, 0.25) if got else Color(0.5, 0.52, 0.6)
	var card := PanelContainer.new()
	var style := Game.make_style(Color(col, 0.14 if got else 0.06), 14, Color(col, 0.8 if got else 0.25), 3)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(_draw_star.bind(icon, got, col))
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_l := _label(a[1], 21, 4, Color.WHITE if got else Color(1, 1, 1, 0.75))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name_l)
	var desc := _label(a[2], 16, 2, Color(1, 1, 1, 0.6))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(desc)
	var reward := _label("DONE" if got else "+%d" % int(a[3]), 20, 4, Color(0.5, 1.0, 0.6) if got else Color(1.0, 0.85, 0.4))
	reward.custom_minimum_size = Vector2(70, 0)
	h.add_child(reward)
	return card


## Filled gold star when earned, outlined grey star when not (drawn, not a font glyph).
func _draw_star(ci: Control, filled: bool, col: Color) -> void:
	var c := ci.size * 0.5
	var pts := PackedVector2Array()
	for i in 10:
		var r := 15.0 if i % 2 == 0 else 6.5
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * r)
	var loop := pts.duplicate()
	loop.append(pts[0])
	if filled:
		ci.draw_colored_polygon(pts, col)
		ci.draw_polyline(loop, Color(0.02, 0.03, 0.05), 2.5, true)
	else:
		ci.draw_polyline(loop, col, 2.5, true)


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l
