extends Control
## Tournament: set up (players, CPU level, laps), then the bracket: two heats of four
## and a final for the top two of each. Between races it shows who's through, which
## corner each player takes for the next race, and the champion at the end.

const CoinBadge = preload("res://scripts/coin_badge.gd")
const SmoothScroll = preload("res://scripts/smooth_scroll.gd")
const Confetti = preload("res://scripts/confetti.gd")

const CORNERS := ["bottom-right", "top-left", "bottom-left", "top-right"]
const GOLD := Color(1.0, 0.82, 0.25)

var _humans := 4
var _level := 1
var _laps := 5
var _body: VBoxContainer
var _k := 1.0 # text scale (portrait has spare width)


func _ready() -> void:
	theme = Game.make_theme()
	Sfx.play_music("menu")
	_k = 1.0 if Game.is_landscape_layout() else 1.25
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if Game.has_meta("tournament"): # debug: --tournament=N opens a fresh bracket
		Game.end_tournament()
		Game.start_tournament(int(Game.get_meta("tournament")), 3, 1)
		Game.remove_meta("tournament")
	_humans = int(Profile.setting("t_humans", 4))
	_level = int(Profile.setting("t_level", 1))
	_laps = int(Profile.setting("t_laps", 5))

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
	header.add_child(_label("TOURNAMENT", 50, 10, Color(0.75, 0.55, 1.0)))
	header.add_child(CoinBadge.new())
	outer.add_child(header)
	var scroll := SmoothScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	center.add_child(_body)
	if Game.in_tournament():
		_build_bracket()
	else:
		_build_setup()


# --- Setup -----------------------------------------------------------------------

func _build_setup() -> void:
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(_label("Up to 8 friends on one device. Two heats of four (CPUs fill\nthe empty places); the top two of each heat race the final.", 18, 4, Color(1, 1, 1, 0.75)))
	_body.add_child(_row("PLAYERS", range(2, 9).map(func(n): return str(n)), _humans - 2, func(k):
		_humans = k + 2
		_build_setup()))
	_body.add_child(_row("CPU LEVEL", Game.CPU_LEVELS, _level, func(k):
		_level = k
		_build_setup()))
	_body.add_child(_row("LAPS", ["3", "5"], 0 if _laps == 3 else 1, func(k):
		_laps = 3 if k == 0 else 5
		_build_setup()))
	var cpus := Game.T_SIZE - _humans
	_body.add_child(_label("%d players%s" % [_humans, "" if cpus == 0 else " + %d CPU driver%s" % [cpus, "" if cpus == 1 else "s"]], 20, 4, Color(1, 1, 1, 0.6)))
	var start := _big_button("START TOURNAMENT", Color(0.55, 0.35, 0.95), func():
		Profile.set_setting("t_humans", _humans)
		Profile.set_setting("t_level", _level)
		Profile.set_setting("t_laps", _laps)
		Game.start_tournament(_humans, _laps, _level)
		get_tree().reload_current_scene())
	_body.add_child(_center(start))
	_body.add_child(_center(_small_button("BACK", _go_menu)))


func _row(title: String, options: Array, selected: int, on_pick: Callable) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var l := _label(title, 18, 4, Color(1, 1, 1, 0.6))
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	for k in options.size():
		var b := Button.new()
		b.text = String(options[k])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(58 if options.size() > 3 else 110, 54)
		if k == selected:
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, Game.make_style(Game.ACCENT, 12))
		b.pressed.connect(on_pick.bind(k))
		h.add_child(b)
	return h


# --- Bracket ---------------------------------------------------------------------

func _build_bracket() -> void:
	var t: Dictionary = Game.tournament
	var st: int = t.stage
	var boxes: BoxContainer = HBoxContainer.new() if Game.is_landscape_layout() else VBoxContainer.new()
	boxes.add_theme_constant_override("separation", 14)
	boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(boxes)
	for k in 3:
		boxes.add_child(_stage_box(k))
	if st >= 3:
		var champ := Game.tournament_champion()
		var c := _label("CHAMPION: %s" % champ.name, 40, 10, champ.color)
		_body.add_child(c)
		var confetti := Confetti.new()
		confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(confetti)
		confetti.burst.call_deferred([champ.color, GOLD, Color.WHITE], 180)
		Sfx.play(Sfx.fanfare)
		var again := _big_button("NEW TOURNAMENT", Color(0.55, 0.35, 0.95), func():
			Game.end_tournament()
			get_tree().reload_current_scene())
		_body.add_child(_center(again))
	else:
		_body.add_child(_corners_line())
		var go := _big_button("RACE %s" % Game.T_STAGES[st], Game.ACCENT if st < 2 else GOLD.darkened(0.1), func():
			Game.begin_tournament_race()
			get_tree().change_scene_to_file("res://scenes/race.tscn"))
		_body.add_child(_center(go))
	_body.add_child(_center(_small_button("QUIT TOURNAMENT" if st < 3 else "MENU", func():
		Game.end_tournament()
		_go_menu())))


## One stage (heat or final): its entrants, then places and who's through once raced.
func _stage_box(k: int) -> Control:
	var t: Dictionary = Game.tournament
	var st: int = t.stage
	var ids: Array = t.heats[k] if k < 2 else t.final
	var raced: bool = t.results.has(k)
	if raced:
		ids = t.results[k]
	var now := k == st
	var panel := PanelContainer.new()
	var edge := Color(1, 1, 1, 0.12)
	if now:
		edge = Game.ACCENT
	elif k == 2 and st >= 3:
		edge = GOLD
	var style := Game.make_style(Color(0.1, 0.11, 0.16), 16, edge, 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300 if Game.is_landscape_layout() else 620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var title: String = Game.T_STAGES[k] + ("  •  NEXT" if now else "")
	v.add_child(_label(title, 22, 6, Game.ACCENT if now else Color(1, 1, 1, 0.7)))
	if ids.is_empty():
		v.add_child(_label("Top 2 of each heat", 17, 4, Color(1, 1, 1, 0.4)))
		v.add_child(_label("...", 17, 4, Color(1, 1, 1, 0.3)))
		return panel
	for n in ids.size():
		var e: Dictionary = t.entrants[ids[n]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var place := _label("%d." % (n + 1) if raced else "", 18, 4, Color(1, 1, 1, 0.6))
		place.custom_minimum_size = Vector2(30, 0)
		row.add_child(place)
		var chip := ColorRect.new()
		chip.color = e.color
		chip.custom_minimum_size = Vector2(14, 14)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var name_l := _label(e.name + ("" if e.human else "  (CPU)"), 20, 4, e.color.lightened(0.15))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		if raced and k < 2 and n < 2:
			row.add_child(_label("THROUGH", 16, 4, GOLD))
		elif raced and k == 2 and n == 0:
			row.add_child(_label("CHAMPION", 16, 4, GOLD))
		v.add_child(row)
	return panel


## Who takes which corner (and key) in the next race.
func _corners_line() -> Control:
	var ids: Array = Game.tournament_field()
	var humans := ids.filter(func(id): return Game.tournament.entrants[id].human)
	humans.sort()
	var parts: Array[String] = []
	for slot in humans.size():
		var e: Dictionary = Game.tournament.entrants[humans[slot]]
		var where: String = CORNERS[slot] if Game.is_touch() else "key %s" % Game.key_label(slot)
		parts.append("P%d: %s" % [int(e.id) + 1, where])
	var text := "No players in this race - just watch!" if parts.is_empty() else "Next race:  " + "   •   ".join(parts)
	var l := _label(text, 17, 4, Color(1, 1, 1, 0.75))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(620 if not Game.is_landscape_layout() else 900, 0)
	return l


# --- Helpers ---------------------------------------------------------------------

func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _big_button(text: String, col: Color, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(420, 80)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_stylebox_override("normal", Game.make_style(col, 20, Color(0.02, 0.03, 0.05), 5))
	b.add_theme_stylebox_override("hover", Game.make_style(col.lightened(0.12), 20, Color(0.02, 0.03, 0.05), 5))
	b.add_theme_stylebox_override("pressed", Game.make_style(col.darkened(0.15), 20, Color(0.02, 0.03, 0.05), 5))
	b.pressed.connect(fn)
	return b


func _small_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 60)
	b.pressed.connect(fn)
	return b


func _center(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	w.add_child(c)
	return w


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(round(font_size * _k)))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l
