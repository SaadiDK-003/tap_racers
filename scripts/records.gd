extends Control
## Records: best lap on every track, each player colour's wins / races / crashes,
## and a few all-time totals.

const CoinBadge = preload("res://scripts/coin_badge.gd")
const SmoothScroll = preload("res://scripts/smooth_scroll.gd")


func _ready() -> void:
	theme = Game.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var landscape := Game.is_landscape_layout()

	# Header pinned at the top, BACK pinned at the bottom, lists scroll in between,
	# so the page fits any window however many tracks there are.
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
	header.add_child(_label("RECORDS", 54, 10, Game.ACCENT))
	header.add_child(CoinBadge.new())
	outer.add_child(header)

	var scroll := SmoothScroll.new() # touch: drag anywhere, flick to glide
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var main: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	main.add_theme_constant_override("separation", 40 if landscape else 16)
	center.add_child(main)

	# Track records.
	var tracks := _panel(main)
	tracks.add_child(_label("TRACK RECORDS", 22, 4, Color(1, 1, 1, 0.65)))
	var best: Dictionary = Profile.data.best_laps
	for m in Game.MAPS:
		var title: String = m.build().title
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_l := _label(title.to_upper(), 18, 4)
		name_l.custom_minimum_size = Vector2(200, 0)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_l)
		var rec: Dictionary = best.get(title, {})
		var time_l := _label("%.2fs" % float(rec.time) if not rec.is_empty() else "--", 20, 4, Color(0.85, 0.55, 1.0))
		time_l.custom_minimum_size = Vector2(90, 0)
		row.add_child(time_l)
		var who_l := _label(rec.get("who", ""), 18, 4, _color_of(rec.get("who", "")))
		who_l.custom_minimum_size = Vector2(110, 0)
		row.add_child(who_l)
		tracks.add_child(row)

	# Players.
	var players := _panel(main)
	players.add_child(_label("PLAYERS", 22, 4, Color(1, 1, 1, 0.65)))
	var head := HBoxContainer.new()
	for h in ["", "RACES", "WINS", "CRASHES"]:
		var l := _label(h, 15, 2, Color(1, 1, 1, 0.5))
		l.custom_minimum_size = Vector2(110 if h == "" else 80, 0)
		head.add_child(l)
	players.add_child(head)
	var most_crashes := -1
	var crash_king := -1
	for i in Game.MAX_PLAYERS:
		var c := int(Profile.data.crashes[i])
		if c > most_crashes:
			most_crashes = c
			crash_king = i
	for i in Game.MAX_PLAYERS:
		var row := HBoxContainer.new()
		var name_l := _label("P%d %s" % [i + 1, Game.PLAYER_NAMES[i]], 20, 4, Game.PLAYER_COLORS[i])
		name_l.custom_minimum_size = Vector2(110, 0)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_l)
		for v in [Profile.data.races[i], Profile.data.wins[i], Profile.data.crashes[i]]:
			var l := _label(str(int(v)), 22, 4)
			l.custom_minimum_size = Vector2(80, 0)
			row.add_child(l)
		players.add_child(row)
	players.add_child(_label("Most crashes: P%d %s" % [crash_king + 1, Game.PLAYER_NAMES[crash_king]] if most_crashes > 0 else "No crashes yet!", 16, 4, Color(1, 0.5, 0.45)))

	# Totals.
	var totals := HBoxContainer.new()
	totals.alignment = BoxContainer.ALIGNMENT_CENTER
	totals.add_theme_constant_override("separation", 30)
	totals.add_child(_label("Coins earned: %d" % int(Profile.data.coins_earned), 18, 4, Color(1.0, 0.85, 0.4)))
	totals.add_child(_label("Perfect laps: %d" % int(Profile.data.perfect_laps), 18, 4, Color(0.5, 0.9, 1.0)))
	totals.add_child(_label("Cups won: %d" % int(Profile.data.championships), 18, 4, Color(1.0, 0.8, 0.3)))
	outer.add_child(totals)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	outer.add_child(back_row)


func _panel(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	return v


func _color_of(who: String) -> Color:
	for i in Game.MAX_PLAYERS:
		if who.ends_with(Game.PLAYER_NAMES[i]):
			return Game.PLAYER_COLORS[i]
	return Color.WHITE


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l
