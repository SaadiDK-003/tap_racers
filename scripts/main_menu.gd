extends Control
## Title screen with a live demo race in the background: choose player count and
## laps, then start a race on a random map.

const RaceWorld = preload("res://scripts/race_world.gd")
const Car = preload("res://scripts/car.gd")
const CoinBadge = preload("res://scripts/coin_badge.gd")

var _controls_box: VBoxContainer
var _cpu_buttons: Array[Button] = []
var _level_buttons: Array[Button] = []
var _demo: RaceWorld
var _sound_button: Button
var _music_button: Button
var _landscape := false


func _ready() -> void:
	if Game.debug_coins >= 0:
		Profile.data.coins = Game.debug_coins
		Game.debug_coins = -1
	if Game.debug_scene != "":
		var scene_name := Game.debug_scene
		Game.debug_scene = ""
		get_tree().change_scene_to_file.call_deferred("res://scenes/%s.tscn" % scene_name)
		return
	if Game.debug_podium:
		Game.debug_podium = false
		Game.start_cup()
		for r in Game.races:
			var order: Array[int] = [0, 2, 1, 3]
			if r % 2 == 0:
				order = [2, 0, 3, 1]
			Game.record_race(order.slice(0, Game.total_racers()))
		get_tree().change_scene_to_file.call_deferred("res://scenes/podium.tscn")
		return
	if Game.debug_skip_menu:
		Game.debug_skip_menu = false
		Game.num_cpus = clampi(Game.num_cpus, 1 if Game.num_players == 1 else 0, Game.MAX_PLAYERS - Game.num_players)
		_start.call_deferred()
		return
	Game.load_settings()
	theme = Game.make_theme()
	Sfx.play_music("menu")
	_build_demo()

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# Portrait: one column. Landscape: title + start on the left, options on the right.
	_landscape = Game.is_landscape_layout()
	var main: BoxContainer = HBoxContainer.new() if _landscape else VBoxContainer.new()
	main.add_theme_constant_override("separation", 30 if _landscape else 18)
	center.add_child(main)
	var top := _column()
	var options := _column()
	var actions := _column()
	if _landscape:
		var left := _column()
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_theme_constant_override("separation", 30)
		left.add_child(top)
		left.add_child(actions)
		main.add_child(left)
		main.add_child(options)
	else:
		main.add_child(top)
		main.add_child(options)
		main.add_child(actions)
	var box := top

	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 14)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var title_size := 76 if _landscape else 92
	logo.custom_minimum_size = Vector2(title_size, title_size)
	title.add_child(logo)
	title.add_child(_label("TAP", title_size, 14))
	title.add_child(_label("RACERS", title_size, 14, Game.ACCENT))
	box.add_child(title)
	box.add_child(_label("Hold to go  •  Let go to brake\nNitro full? Double-tap for a boost!", 24, 6, Color(1, 1, 1, 0.85)))

	box = options
	box.add_theme_constant_override("separation", 8)
	if _landscape:
		box.add_child(_spacer(44)) # room for the coin counter in the corner
	box.add_child(_option_row("PLAYERS", [1, 2, 3, 4], ["1", "2", "3", "4"], Game.num_players, _pick_players))
	var cpu_row := _option_row("CPU RIVALS", [0, 1, 2, 3], ["0", "1", "2", "3"], Game.num_cpus, _pick_cpus)
	_cpu_buttons = _last_row_buttons
	box.add_child(cpu_row)
	box.add_child(_option_row("CPU LEVEL", [0, 1, 2], Game.CPU_LEVELS, Game.cpu_level, func(v): Game.cpu_level = v; _refresh_controls()))
	_level_buttons = _last_row_buttons
	box.add_child(_option_row("RACES", Game.RACE_OPTIONS, ["SINGLE", "CUP 3", "CUP 5", "TRIAL"], Game.races, func(v): Game.races = v; _refresh_controls()))
	box.add_child(_option_row("LAPS", Game.LAP_OPTIONS, ["5", "6"], Game.laps, func(v): Game.laps = v))
	box.add_child(_option_row("ITEMS", [1, 0], ["ON", "OFF"], 1 if Game.items_on else 0, func(v): Game.items_on = v == 1))
	box.add_child(_option_row("WEATHER", [0, 1, 2, 3], Game.WEATHER_MODES, Game.weather_mode, func(v): Game.weather_mode = v))
	box.add_child(_spacer(4))

	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 8)
	box.add_child(_controls_box)
	_fix_cpu_count()
	_refresh_controls()

	box = actions
	var start := Button.new()
	start.text = "START RACE"
	start.custom_minimum_size = Vector2(460, 104)
	start.add_theme_font_size_override("font_size", 40)
	start.add_theme_stylebox_override("normal", Game.make_style(Game.ACCENT, 22, Color(0.02, 0.03, 0.05), 6))
	start.add_theme_stylebox_override("hover", Game.make_style(Game.ACCENT.lightened(0.12), 22, Color(0.02, 0.03, 0.05), 6))
	start.add_theme_stylebox_override("pressed", Game.make_style(Game.ACCENT.darkened(0.15), 22, Color(0.02, 0.03, 0.05), 6))
	start.pressed.connect(_start)
	box.add_child(start)
	start.pivot_offset = start.custom_minimum_size * 0.5
	var pulse := create_tween().set_loops()
	pulse.tween_property(start, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(start, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	_sound_button = Button.new()
	_sound_button.custom_minimum_size = Vector2(180, 58)
	_sound_button.add_theme_font_size_override("font_size", 22)
	_sound_button.pressed.connect(_toggle_sound)
	_update_sound_button()
	var sound_row := HBoxContainer.new()
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.add_theme_constant_override("separation", 14)
	sound_row.add_child(_sound_button)
	_music_button = Button.new()
	_music_button.custom_minimum_size = Vector2(180, 58)
	_music_button.add_theme_font_size_override("font_size", 22)
	_music_button.pressed.connect(_toggle_music)
	sound_row.add_child(_music_button)
	_update_sound_button()
	if not OS.has_feature("mobile"):
		var fs := Button.new()
		fs.text = "FULLSCREEN"
		fs.custom_minimum_size = Vector2(180, 58)
		fs.add_theme_font_size_override("font_size", 22)
		fs.pressed.connect(Game.toggle_fullscreen)
		sound_row.add_child(fs)
	box.add_child(sound_row)

	var extra_row := HBoxContainer.new()
	extra_row.alignment = BoxContainer.ALIGNMENT_CENTER
	extra_row.add_theme_constant_override("separation", 14)
	var how := Button.new()
	how.text = "HOW TO PLAY"
	how.custom_minimum_size = Vector2(150, 58)
	how.add_theme_font_size_override("font_size", 19)
	how.pressed.connect(_start_tutorial)
	extra_row.add_child(how)
	for pair in [["GARAGE", "res://scenes/garage.tscn"], ["RECORDS", "res://scenes/records.tscn"], ["AWARDS", "res://scenes/awards.tscn"]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(130, 58)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func(): Game.save_settings(); get_tree().change_scene_to_file(pair[1]))
		extra_row.add_child(b)
	box.add_child(extra_row)
	box.add_child(_daily_chip())

	var badge := CoinBadge.new()
	add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(get_viewport_rect().size.x - 190, 16)
	get_viewport().size_changed.connect(func(): badge.position = Vector2(get_viewport_rect().size.x - 190, 16))
	start.grab_focus()
	get_viewport().size_changed.connect(_on_resized)
	if not Profile.data.tutorial_done and not bool(Profile.setting("tutorial_offered", false)) and not Game.debug_skip_menu:
		_offer_tutorial()


func _on_resized() -> void:
	# Rebuild the layout when the window flips between portrait and landscape.
	if Game.is_landscape_layout() != _landscape and not _reloading:
		_reloading = true
		_reload_when_ready.call_deferred()


var _reloading := false


## On the web the canvas starts at 0x0 and grows while the first scene is still
## loading, so wait until this menu is the current scene before rebuilding it.
func _reload_when_ready() -> void:
	while get_tree().current_scene != self:
		await get_tree().process_frame
	get_tree().reload_current_scene()


func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	return v


func _build_demo() -> void:
	var map_idx := Game.debug_map if Game.debug_map >= 0 else randi() % Game.MAPS.size()
	var map = Game.MAPS[map_idx % Game.MAPS.size()].build()
	_demo = RaceWorld.new()
	_demo.random_styles = true
	# Own canvas layer behind the menu, so bridge decks and cars (which use z-index)
	# can never draw on top of the menu.
	var back_layer := CanvasLayer.new()
	back_layer.layer = -1
	add_child(back_layer)
	back_layer.add_child(_demo)
	_demo.build(map, 4)
	_demo.effects.show_tags = false
	for car in _demo.cars:
		car.state = Car.State.RACING
		car.progress = -22.0 - car.index * 260.0
	_fit_demo()
	get_viewport().size_changed.connect(_fit_demo)


func _fit_demo() -> void:
	var screen := get_viewport_rect().size
	_demo.fit(Rect2(Vector2(10, 10), screen - Vector2(20, 20)), 2.0)


func _process(delta: float) -> void:
	if _demo:
		var leader = _demo.cars[0]
		for car in _demo.cars:
			if car.bot_wants_nitro():
				car.fire_nitro()
			car.tick(delta, car.bot_throttle())
			if car.progress > leader.progress:
				leader = car
		_demo.effects.leader = leader


func _start_tutorial() -> void:
	Game.save_settings()
	Game.tutorial = true
	Game.start_cup()
	get_tree().change_scene_to_file("res://scenes/race.tscn")


## First launch: suggest the 1-minute tutorial (asked only once).
func _offer_tutorial() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Game.make_style(Color(0.08, 0.09, 0.13), 26, Game.ACCENT, 5))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_label("FIRST TIME HERE?", 44, 10, Game.ACCENT))
	v.add_child(_label("A quick 1-minute tutorial shows you how to drive,\nbrake for corners and fire your NITRO.\n(+%d coins!)" % Profile.TUTORIAL_COINS, 22, 4))
	var play := Button.new()
	play.text = "PLAY TUTORIAL"
	play.custom_minimum_size = Vector2(420, 84)
	play.add_theme_stylebox_override("normal", Game.make_style(Game.ACCENT, 18))
	play.add_theme_stylebox_override("hover", Game.make_style(Game.ACCENT.lightened(0.12), 18))
	play.pressed.connect(func(): Profile.set_setting("tutorial_offered", true); _start_tutorial())
	v.add_child(play)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(420, 64)
	skip.pressed.connect(func(): Profile.set_setting("tutorial_offered", true); overlay.queue_free())
	v.add_child(skip)


func _daily_chip() -> Control:
	var c := Profile.daily_challenge()
	var done := Profile.daily_done()
	var chip := PanelContainer.new()
	var col := Color(0.4, 0.9, 0.5) if done else Color(1.0, 0.8, 0.3)
	var style := Game.make_style(Color(col, 0.14), 14, Color(col, 0.8), 3)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	chip.add_child(v)
	v.add_child(_label("DAILY CHALLENGE  •  %s" % ("DONE!" if done else "+%d COINS" % Profile.DAILY_COINS), 16, 4, col))
	v.add_child(_label(c.text, 21, 4, Color.WHITE))
	return chip


func _start() -> void:
	Game.save_settings()
	Game.start_cup()
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _pick_players(v: int) -> void:
	Game.num_players = v
	_fix_cpu_count()
	_refresh_controls()


func _pick_cpus(v: int) -> void:
	Game.num_cpus = v
	_fix_cpu_count()
	_refresh_controls()


## Keeps humans + CPUs between 2 and 4 cars and greys out impossible choices.
func _fix_cpu_count() -> void:
	var max_cpus := Game.MAX_PLAYERS - Game.num_players
	var min_cpus := 1 if Game.num_players == 1 else 0
	Game.num_cpus = clampi(Game.num_cpus, min_cpus, max_cpus)
	for i in _cpu_buttons.size():
		_cpu_buttons[i].disabled = i < min_cpus or i > max_cpus
		_cpu_buttons[i].set_pressed_no_signal(i == Game.num_cpus)
	for b in _level_buttons:
		b.disabled = Game.num_cpus == 0


func _toggle_sound() -> void:
	Sfx.enabled = not Sfx.enabled
	Game.save_settings()
	_update_sound_button()
	Sfx.play(Sfx.beep)


func _toggle_music() -> void:
	Sfx.set_music_enabled(not Sfx.music_enabled)
	Game.save_settings()
	_update_sound_button()


func _update_sound_button() -> void:
	_sound_button.text = "SOUND: ON" if Sfx.enabled else "SOUND: OFF"
	if _music_button:
		_music_button.text = "MUSIC: ON" if Sfx.music_enabled else "MUSIC: OFF"


func _refresh_controls() -> void:
	for child in _controls_box.get_children():
		child.queue_free()
	var corners := ["bottom-right", "top-left", "bottom-left", "top-right"]
	if Game.is_trial():
		var how := "hold your corner" if Game.is_touch() else "hold  %s" % Game.key_label(0)
		_controls_box.add_child(_label("TIME TRIAL: P1 alone vs the clock\nand the ghost of your best lap  (%s)" % how, 20, 4, Color(0.85, 0.7, 1.0)))
		return
	for i in Game.total_racers():
		if Game.is_cpu(i):
			var cpu_chip := PanelContainer.new()
			var cpu_style := Game.make_style(Color(Game.PLAYER_COLORS[i], 0.1), 12, Color(Game.PLAYER_COLORS[i], 0.5), 2)
			cpu_style.content_margin_top = 4
			cpu_style.content_margin_bottom = 4
			cpu_chip.add_theme_stylebox_override("panel", cpu_style)
			cpu_chip.add_child(_label("CPU rival   %s   (%s)" % [Game.CPU_LEVELS[Game.cpu_level].to_lower(), corners[i]], 21, 4, Game.PLAYER_COLORS[i].lightened(0.1)))
			_controls_box.add_child(cpu_chip)
			continue
		var how := "hold your corner" if Game.is_touch() else "hold  %s" % Game.key_label(i)
		var chip := PanelContainer.new()
		var style := Game.make_style(Color(Game.PLAYER_COLORS[i], 0.18), 12, Game.PLAYER_COLORS[i], 3)
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(_label("P%d %s   %s   (%s)" % [i + 1, Game.PLAYER_NAMES[i], how, corners[i]], 21, 4, Game.PLAYER_COLORS[i].lightened(0.2)))
		_controls_box.add_child(chip)


var _last_row_buttons: Array[Button] = []


## A labelled row of toggle buttons: [LABEL] [a] [b] [c]. Its buttons end up in _last_row_buttons.
func _option_row(title: String, values: Array, labels: Array, current: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var name_l := _label(title, 18, 4, Color(1, 1, 1, 0.65))
	name_l.custom_minimum_size = Vector2(112, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_l)
	var group := ButtonGroup.new()
	_last_row_buttons = []
	var wide := false
	for l in labels:
		wide = wide or str(l).length() > 2
	for j in values.size():
		var v = values[j]
		var b := Button.new()
		b.text = str(labels[j])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = v == current
		b.custom_minimum_size = Vector2(90 if wide else 66, 54)
		b.add_theme_font_size_override("font_size", 18 if wide else 28)
		b.pressed.connect(func(): on_pick.call(v); Sfx.play(Sfx.beep, -8.0))
		row.add_child(b)
		_last_row_buttons.append(b)
	return row


func _choice_row(values: Array, current: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var group := ButtonGroup.new()
	for v in values:
		var b := Button.new()
		b.text = str(v)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = v == current
		b.custom_minimum_size = Vector2(120, 88)
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(func(): on_pick.call(v); Sfx.play(Sfx.beep, -8.0))
		row.add_child(b)
	return row


func _label(text: String, font_size: int, outline := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
