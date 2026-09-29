extends Control
## Career: the ladder of ten events. Each card shows the track, the rivals, the
## conditions, the event goal and the stars earned; the next event unlocks with a
## podium on the one before.

const CoinBadge = preload("res://scripts/coin_badge.gd")
const StarRow = preload("res://scripts/star_row.gd")
const CE = preload("res://scripts/career_events.gd")

const LEVEL_COLORS := [Color(0.45, 0.9, 0.5), Color(1.0, 0.8, 0.3), Color(1.0, 0.4, 0.35)]


func _ready() -> void:
	theme = Game.make_theme()
	Sfx.play_music("menu")
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	add_child(margin)
	Game.fit_to_safe(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	header.add_child(_label("CAREER", 54, 10, Game.ACCENT))
	var total := HBoxContainer.new()
	total.add_theme_constant_override("separation", 6)
	total.add_child(StarRow.new(1, 30, 0, 1))
	total.add_child(_label("%d / %d" % [Profile.career_total(), CE.count() * 3], 28, 6))
	header.add_child(total)
	header.add_child(CoinBadge.new())
	outer.add_child(header)
	outer.add_child(_label("Podium to unlock the next event  •  Win  •  Beat the goal", 17, 4, Color(1, 1, 1, 0.6)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var landscape := Game.is_landscape_layout()
	var grid := GridContainer.new()
	grid.columns = 2 if landscape else 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var focus_card: Control = null
	for i in CE.count():
		var card := _card(i)
		grid.add_child(card)
		if Profile.career_unlocked(i):
			focus_card = card # the furthest open event
	if focus_card:
		# Scroll so the newest open event is in view.
		(func(): scroll.ensure_control_visible(focus_card)).call_deferred()

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		Game.end_career()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	outer.add_child(back_row)


func _card(i: int) -> Control:
	var e: Dictionary = CE.event(i)
	var open := Profile.career_unlocked(i)
	var stars := Profile.career_stars(i)
	var final := i == CE.count() - 1
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(560 if Game.is_landscape_layout() else 660, 112)
	b.disabled = not open
	var edge := Color(1.0, 0.45, 0.2) if final else Color(0.3, 0.34, 0.42)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var bgc := Color(0.1, 0.12, 0.17)
		if st == "hover":
			bgc = Color(0.15, 0.17, 0.24)
		elif st == "pressed":
			bgc = Color(0.08, 0.09, 0.13)
		elif st == "disabled":
			bgc = Color(0.07, 0.08, 0.1)
		b.add_theme_stylebox_override(st, Game.make_style(bgc, 16, edge if open else Color(0.15, 0.16, 0.2), 3))
	b.pressed.connect(func():
		Game.start_career(i)
		get_tree().change_scene_to_file("res://scenes/race.tscn"))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	b.add_child(pad)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 14)
	pad.add_child(h)

	var num := _label(str(i + 1), 40, 8, Game.ACCENT if open else Color(1, 1, 1, 0.25))
	num.custom_minimum_size = Vector2(52, 0)
	h.add_child(num)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var dim := 1.0 if open else 0.35
	var t := _label(e.title, 25, 6, Color(1, 1, 1, dim))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(t)
	if not open:
		var l := _label("LOCKED  •  Podium in event %d to unlock" % i, 16, 4, Color(1, 1, 1, 0.4))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(l)
		return b
	var map_title: String = Game.MAPS[e.map].build().title
	var tags: Array[String] = [map_title.to_upper(), "%d LAPS" % e.laps]
	if e.weather == 2:
		tags.append("RAIN")
	elif e.weather == 3:
		tags.append("NIGHT")
	tags.append("ITEMS" if e.items else "NO ITEMS")
	var info := _label("  •  ".join(tags), 15, 4, Color(1, 1, 1, 0.7))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(info)
	var rivals := HBoxContainer.new()
	rivals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rivals.add_theme_constant_override("separation", 8)
	var lvl := _label(Game.CPU_LEVELS[e.level], 15, 4, LEVEL_COLORS[e.level])
	rivals.add_child(lvl)
	rivals.add_child(_label("vs " + ", ".join(e.rivals), 15, 4, Color(1, 1, 1, 0.55)))
	v.add_child(rivals)
	var goal := _label("GOAL: " + CE.goal_text(i), 16, 4, Color(0.55, 0.85, 1.0) if stars & CE.GOAL == 0 else Color(1.0, 0.82, 0.2))
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(goal)
	var sr := StarRow.new(stars, 24)
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sr)
	return b


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l
