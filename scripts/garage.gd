extends Control
## Garage: each player picks a car body and a decal. Locked styles are bought with
## coins earned by racing. Every tile shows a live preview of the car with that style.

const Car = preload("res://scripts/car.gd")
const CoinBadge = preload("res://scripts/coin_badge.gd")

const OUTLINE := Color(0.02, 0.03, 0.05)

var _slot := 0
var _preview: Car
var _preview_label: Label
var _tabs: Array[Button] = []
var _body_grid: GridContainer
var _decal_grid: GridContainer
var _message: Label
var _t := 0.0


func _ready() -> void:
	theme = Game.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var landscape := Game.is_landscape_layout()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var main: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	main.add_theme_constant_override("separation", 40 if landscape else 14)
	center.add_child(main)

	# Left / top: header, player tabs and the showcase.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	main.add_child(left)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(_label("GARAGE", 54, 10, Game.ACCENT))
	header.add_child(CoinBadge.new())
	left.add_child(header)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in Game.MAX_PLAYERS:
		var b := Button.new()
		b.text = "P%d" % (i + 1)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.custom_minimum_size = Vector2(84, 56)
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = Game.PLAYER_COLORS[i]
		b.add_theme_stylebox_override("normal", Game.make_style(Color(col, 0.25), 14, Color(col, 0.6), 3))
		b.add_theme_stylebox_override("hover", Game.make_style(Color(col, 0.4), 14, col, 3))
		b.add_theme_stylebox_override("pressed", Game.make_style(col.darkened(0.2), 14, Color.WHITE, 4))
		b.pressed.connect(_select_slot.bind(i))
		tabs.add_child(b)
		_tabs.append(b)
	left.add_child(tabs)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(420, 250 if landscape else 230)
	stage.draw.connect(_draw_stage.bind(stage))
	left.add_child(stage)
	_preview = _make_car(0, "classic", "none", 3.4)
	stage.add_child(_preview)
	set_meta("stage", stage)
	_preview_label = _label("", 24, 6)
	left.add_child(_preview_label)
	_message = _label("", 20, 4, Color(1, 0.85, 0.4))
	left.add_child(_message)

	# Right / bottom: body and decal tiles, back button.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	main.add_child(right)
	right.add_child(_label("BODY", 22, 4, Color(1, 1, 1, 0.6)))
	_body_grid = GridContainer.new()
	_body_grid.columns = 4
	_body_grid.add_theme_constant_override("h_separation", 10)
	_body_grid.add_theme_constant_override("v_separation", 10)
	right.add_child(_body_grid)
	right.add_child(_label("DECAL", 22, 4, Color(1, 1, 1, 0.6)))
	_decal_grid = GridContainer.new()
	_decal_grid.columns = 3 if landscape else 3
	_decal_grid.add_theme_constant_override("h_separation", 10)
	_decal_grid.add_theme_constant_override("v_separation", 10)
	right.add_child(_decal_grid)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 64)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	right.add_child(back_row)
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	if _preview:
		_preview.rotation = -PI * 0.5 + sin(_t * 0.8) * 0.35
		_preview.queue_redraw()
	var stage: Control = get_meta("stage")
	_preview.position = stage.size * 0.5
	stage.queue_redraw()


func _draw_stage(stage: Control) -> void:
	var c := stage.size * 0.5
	var col: Color = Game.PLAYER_COLORS[_slot]
	for i in 3:
		stage.draw_circle(c, 115.0 - i * 18.0, Color(col, 0.06 + i * 0.03))
	stage.draw_arc(c, 112.0, 0.0, TAU, 64, Color(col, 0.6), 4.0, true)
	for i in 8:
		var a := _t * 0.6 + i * TAU / 8.0
		stage.draw_line(c + Vector2.from_angle(a) * 118.0, c + Vector2.from_angle(a) * 128.0, Color(col, 0.5), 3.0)


func _select_slot(i: int) -> void:
	_slot = i
	_message.text = ""
	_rebuild()


func _rebuild() -> void:
	var look: Array = Profile.style(_slot)
	_preview.index = _slot
	_preview.color = Game.PLAYER_COLORS[_slot]
	_preview.body = look[0]
	_preview.decal = look[1]
	_preview_label.text = "P%d %s  •  %s + %s" % [_slot + 1, Game.PLAYER_NAMES[_slot], _name_of(Profile.BODIES, look[0]), _name_of(Profile.DECALS, look[1])]
	_preview_label.add_theme_color_override("font_color", Game.PLAYER_COLORS[_slot])
	for grid in [_body_grid, _decal_grid]:
		for child in grid.get_children():
			child.queue_free()
	for item in Profile.BODIES:
		_body_grid.add_child(_tile(item, true, look))
	for item in Profile.DECALS:
		_decal_grid.add_child(_tile(item, false, look))


func _tile(item: Dictionary, is_body: bool, look: Array) -> Button:
	var id: String = item.id
	var price: int = item.price
	var owned := Profile.is_unlocked(id)
	var equipped: bool = look[0] == id if is_body else look[1] == id
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 118)
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = Game.PLAYER_COLORS[_slot]
	if equipped:
		b.add_theme_stylebox_override("normal", Game.make_style(Color(col, 0.3), 16, Color.WHITE, 4))
		b.add_theme_stylebox_override("hover", Game.make_style(Color(col, 0.4), 16, Color.WHITE, 4))
	elif not owned:
		b.add_theme_stylebox_override("normal", Game.make_style(Color(0.1, 0.11, 0.14), 16, Color(1, 1, 1, 0.08), 2))
	# Mini car showing this style.
	var mini := _make_car(_slot, id if is_body else look[0], look[1] if is_body else id, 1.35)
	mini.position = Vector2(59, 50)
	mini.modulate = Color(1, 1, 1, 1.0 if owned else 0.45)
	b.add_child(mini)
	var name_l := _label(item.name, 15, 4)
	name_l.position = Vector2(0, 80)
	name_l.size = Vector2(118, 20)
	b.add_child(name_l)
	var tag := "EQUIPPED" if equipped else ("OWNED" if owned else str(price))
	var tag_col := Color(0.6, 1.0, 0.7) if equipped else (Color(1, 1, 1, 0.6) if owned else (Color(1.0, 0.85, 0.35) if Profile.coins() >= price else Color(1.0, 0.4, 0.4)))
	# Price tag: a drawn coin + the price (font symbols don't exist in the web build's font).
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 4)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.position = Vector2(0, 97)
	tag_row.size = Vector2(118, 18)
	if not owned:
		var coin := Control.new()
		coin.custom_minimum_size = Vector2(14, 18)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.draw.connect(func(): CoinBadge.draw_coin(coin, Vector2(7, 9), 5.5))
		tag_row.add_child(coin)
	tag_row.add_child(_label(tag, 14, 4, tag_col))
	b.add_child(tag_row)
	b.pressed.connect(_on_tile.bind(item, is_body))
	return b


func _on_tile(item: Dictionary, is_body: bool) -> void:
	var id: String = item.id
	if not Profile.is_unlocked(id):
		if not Profile.buy(id, item.price):
			_message.text = "Need %d more coins - win races to earn them!" % (int(item.price) - Profile.coins())
			Sfx.play(Sfx.beep, -4.0, 0.6)
			return
		_message.text = "Unlocked %s!" % item.name
		Sfx.play(Sfx.fanfare, -4.0)
	else:
		_message.text = ""
		Sfx.play(Sfx.lap, -6.0)
	if is_body:
		Profile.equip(_slot, id, "")
	else:
		Profile.equip(_slot, "", id)
	_rebuild()


func _make_car(slot: int, body: String, decal: String, s: float) -> Car:
	var car := Car.new()
	car.index = slot
	car.color = Game.PLAYER_COLORS[slot]
	car.body = body
	car.decal = decal
	car.rotation = -PI * 0.5
	car.scale = Vector2(s, s)
	return car


static func _name_of(list: Array, id: String) -> String:
	for item in list:
		if item.id == id:
			return item.name
	return id.to_upper()


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
