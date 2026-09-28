extends Control
## End of a championship: podium with the top three cars, a trophy for the champion,
## final standings and buttons to start a new championship or go back to the menu.

const Car = preload("res://scripts/car.gd")
const PlayerPads = preload("res://scripts/player_pads.gd")
const Confetti = preload("res://scripts/confetti.gd")

const OUTLINE := Color(0.02, 0.03, 0.05)


class PodiumView extends Control:
	## Draws the three podium steps and a trophy; the cars are child nodes.
	var order: Array[int] = []
	var _t := 0.0
	var _font: FontVariation

	func _ready() -> void:
		custom_minimum_size = Vector2(560, 330)
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 1.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## Step rect for a finishing place (0 = champion).
	func step_rect(place: int) -> Rect2:
		var w := 160.0
		var heights := [150.0, 105.0, 75.0]
		var xs := [size.x * 0.5 - w * 0.5, size.x * 0.5 - w * 1.5 - 10.0, size.x * 0.5 + w * 0.5 + 10.0]
		var h: float = heights[place]
		return Rect2(xs[place], size.y - h, w, h)

	func _draw() -> void:
		# Light rays behind the champion.
		var center := Vector2(size.x * 0.5, size.y - 150.0)
		for i in 12:
			var a := _t * 0.25 + i * TAU / 12.0
			var ray := PackedVector2Array([center, center + Vector2.from_angle(a - 0.08) * 420.0, center + Vector2.from_angle(a + 0.08) * 420.0])
			draw_colored_polygon(ray, Color(1.0, 0.85, 0.3, 0.06))
		for place in mini(3, order.size()):
			var r := step_rect(place)
			var col: Color = PlayerPads.MEDALS[place]
			draw_rect(r.grow(4.0), OUTLINE)
			draw_rect(r, col.darkened(0.15))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), col.lightened(0.2))
			draw_string(_font, r.position + Vector2(0, r.size.y * 0.5 + 26), str(place + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, OUTLINE)
		if order.size() > 0:
			_draw_trophy(Vector2(size.x * 0.5, step_rect(0).position.y - 128.0 + sin(_t * 2.5) * 4.0))

	func _draw_trophy(p: Vector2) -> void:
		var gold := Color(1.0, 0.8, 0.2)
		var dark := gold.darkened(0.3)
		# Handles.
		draw_arc(p + Vector2(-26, -4), 13.0, PI * 0.5, PI * 1.5, 16, OUTLINE, 10.0)
		draw_arc(p + Vector2(26, -4), 13.0, -PI * 0.5, PI * 0.5, 16, OUTLINE, 10.0)
		draw_arc(p + Vector2(-26, -4), 13.0, PI * 0.5, PI * 1.5, 16, gold, 5.0)
		draw_arc(p + Vector2(26, -4), 13.0, -PI * 0.5, PI * 0.5, 16, gold, 5.0)
		# Cup, stem and base.
		var cup := PackedVector2Array([p + Vector2(-30, -22), p + Vector2(30, -22), p + Vector2(22, 10), p + Vector2(8, 20), p + Vector2(-8, 20), p + Vector2(-22, 10)])
		var loop := cup.duplicate()
		loop.append(cup[0])
		draw_colored_polygon(cup, gold)
		draw_polyline(loop, OUTLINE, 4.0, true)
		draw_rect(Rect2(p + Vector2(-5, 20), Vector2(10, 16)), dark)
		draw_rect(Rect2(p + Vector2(-20, 36), Vector2(40, 10)).grow(2.0), OUTLINE)
		draw_rect(Rect2(p + Vector2(-20, 36), Vector2(40, 10)), gold)
		draw_line(p + Vector2(-18, -16), p + Vector2(-12, 6), Color(1, 1, 1, 0.6), 4.0)
		# Twinkle.
		var tw := 6.0 + 3.0 * sin(_t * 6.0)
		var sp := p + Vector2(22, -30)
		draw_line(sp - Vector2(tw, 0), sp + Vector2(tw, 0), Color.WHITE, 2.5)
		draw_line(sp - Vector2(0, tw), sp + Vector2(0, tw), Color.WHITE, 2.5)


var _confetti: Confetti


func _ready() -> void:
	theme = Game.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var order := Game.cup_standings()
	var champ := order[0]
	var landscape := Game.is_landscape_layout()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.fit_to_safe(center)
	add_child(center)
	var main: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	main.add_theme_constant_override("separation", 50 if landscape else 18)
	center.add_child(main)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	main.add_child(left)
	left.add_child(_label("CHAMPION!", 64, 12, Color(1.0, 0.85, 0.25)))
	var who := _label(Game.racer_name(champ), 44, 10, Game.PLAYER_COLORS[champ])
	left.add_child(who)
	if not Game.debug_bots:
		var bonus := Profile.record_championship(not Game.is_cpu(champ))
		if bonus > 0:
			left.add_child(_label("CHAMPION BONUS  +%d COINS" % bonus, 22, 6, Color(1.0, 0.85, 0.4)))
	var view := PodiumView.new()
	view.order = order
	left.add_child(view)
	# Cars on top of the steps, facing up.
	for place in mini(3, order.size()):
		var car := Car.new()
		car.index = order[place]
		car.color = Game.PLAYER_COLORS[order[place]]
		car.rotation = -PI * 0.5
		car.scale = Vector2(2.2, 2.2)
		view.add_child(car)
		_place_car.call_deferred(view, car, place)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(right)
	right.add_child(_label("FINAL STANDINGS  •  %d RACES" % Game.races, 22, 4, Color(1, 1, 1, 0.7)))
	for rank in order.size():
		right.add_child(_standing_row(rank, order[rank]))
	right.add_child(_spacer(8))
	var again := _button("NEW CHAMPIONSHIP", _new_cup, true)
	var menu := _button("MENU", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	right.add_child(again)
	right.add_child(menu)

	_confetti = Confetti.new()
	add_child(_confetti)
	_celebrate.call_deferred(champ)
	again.disabled = true
	menu.disabled = true
	await get_tree().create_timer(1.2).timeout
	again.disabled = false
	menu.disabled = false


func _place_car(view: PodiumView, car: Node2D, place: int) -> void:
	var r := view.step_rect(place)
	car.position = Vector2(r.get_center().x, r.position.y - 30.0)


func _celebrate(champ: int) -> void:
	Sfx.play_music("menu")
	Sfx.play(Sfx.fanfare)
	Sfx.play(Sfx.cheer, 0.0)
	_confetti.burst([Game.PLAYER_COLORS[champ], Color.WHITE, Color(1.0, 0.85, 0.2), Color(0.3, 0.9, 1.0)], 220)


func _new_cup() -> void:
	Game.start_cup()
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _standing_row(rank: int, i: int) -> Control:
	var row := PanelContainer.new()
	var col: Color = Game.PLAYER_COLORS[i]
	var style := Game.make_style(Color(col, 0.16), 14, Color(col, 0.9) if rank == 0 else Color(0, 0, 0, 0), 3)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var badge := PanelContainer.new()
	var bstyle := Game.make_style(PlayerPads.MEDALS[rank], 10, OUTLINE, 3)
	bstyle.content_margin_left = 8
	bstyle.content_margin_right = 8
	bstyle.content_margin_top = 2
	bstyle.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", bstyle)
	var place := _label(PlayerPads.ordinal(rank + 1), 24, 0, Color(0.05, 0.05, 0.08))
	place.custom_minimum_size = Vector2(58, 0)
	badge.add_child(place)
	h.add_child(badge)
	var name_l := _label(Game.racer_name(i), 26, 6, col)
	name_l.custom_minimum_size = Vector2(190, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(name_l)
	var pts := _label("%d pts" % Game.cup_points[i], 26, 6)
	pts.custom_minimum_size = Vector2(90, 0)
	h.add_child(pts)
	var wins := _label("%d win%s" % [Game.cup_wins[i], "" if Game.cup_wins[i] == 1 else "s"], 18, 4, Color(1, 1, 1, 0.6))
	wins.custom_minimum_size = Vector2(70, 0)
	h.add_child(wins)
	return row


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, fn: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 80)
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		b.add_theme_stylebox_override("normal", Game.make_style(Game.ACCENT, 18))
		b.add_theme_stylebox_override("hover", Game.make_style(Game.ACCENT.lightened(0.12), 18))
		b.add_theme_stylebox_override("pressed", Game.make_style(Game.ACCENT.darkened(0.15), 18))
	b.pressed.connect(fn)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
