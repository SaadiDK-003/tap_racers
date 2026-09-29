extends Control
## Title screen with a live demo race in the background: choose player count and
## laps, then start a race on a random map.

const RaceWorld = preload("res://scripts/race_world.gd")
const Car = preload("res://scripts/car.gd")
const CoinBadge = preload("res://scripts/coin_badge.gd")
const StarRow = preload("res://scripts/star_row.gd")

var _controls_box: VBoxContainer
var _cpu_buttons: Array[Button] = []
var _level_buttons: Array[Button] = []
var _demo: RaceWorld
var _sound_button: Button
var _music_button: Button
var _vibe_button: Button
var _landscape := false
var _play_button: Button
var _summary: Label
var _setup: Control # race setup panel (options + players)
var _settings: Control # sound / music / fullscreen panel
var _badge: Control


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
		if Game.has_meta("career"):
			Game.start_career(clampi(Game.get_meta("career"), 0, Game.CareerEvents.count() - 1))
			Game.remove_meta("career")
			get_tree().change_scene_to_file.call_deferred("res://scenes/race.tscn")
			return
		Game.num_cpus = clampi(Game.num_cpus, 1 if Game.num_players == 1 else 0, Game.MAX_PLAYERS - Game.num_players)
		_start.call_deferred()
		return
	Game.load_settings()
	Game.reset_streak() # a streak is a run of races in one sitting
	theme = Game.make_theme()
	Sfx.play_music("menu")
	_build_demo()

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_landscape = Game.is_landscape_layout()
	_build_home()
	_build_setup()
	_build_settings()
	if Game.has_meta("menu_panel"): # debug: --menu_panel=setup / settings
		_show(_setup if Game.get_meta("menu_panel") == "setup" else _settings, true)
		Game.remove_meta("menu_panel")

	_badge = CoinBadge.new()
	add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_place_badge()
	# A method (not a lambda) so Godot drops the connection when the menu is freed.
	get_viewport().size_changed.connect(_place_badge)
	_play_button.grab_focus()
	get_viewport().size_changed.connect(_on_resized)
	if not Profile.data.tutorial_done and not bool(Profile.setting("tutorial_offered", false)) and not Game.debug_skip_menu:
		_offer_tutorial()


func _place_badge() -> void:
	var sr := Game.safe_rect()
	_badge.position = Vector2(sr.end.x - 190, sr.position.y + 16)


# --- Home screen ---------------------------------------------------------------

## Home: title, PLAY, a one-line summary of the race settings, RACE SETUP, four
## menu buttons and the daily challenge. Options live in the setup panel.
func _build_home() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	Game.fit_to_safe(center)
	var main: BoxContainer = HBoxContainer.new() if _landscape else VBoxContainer.new()
	main.add_theme_constant_override("separation", 60 if _landscape else 26)
	center.add_child(main)
	var left := _column()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(left)
	var right := _column()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(right)

	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 14)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var title_size := 76 if _landscape else 84
	logo.custom_minimum_size = Vector2(title_size, title_size)
	title.add_child(logo)
	title.add_child(_label("TAP", title_size, 14))
	title.add_child(_label("RACERS", title_size, 14, Game.ACCENT))
	left.add_child(title)
	left.add_child(_label("Hold to go  •  Let go to brake\nNitro full? Double-tap for a boost!", 22, 6, Color(1, 1, 1, 0.8)))
	left.add_child(_spacer(6))

	_play_button = _big_button("PLAY", _start, Vector2(460, 110), 46)
	left.add_child(_center_wrap(_play_button))
	_play_button.pivot_offset = _play_button.custom_minimum_size * 0.5
	var pulse := create_tween().set_loops()
	pulse.tween_property(_play_button, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_play_button, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	_summary = _label("", 19, 4, Color(1, 1, 1, 0.75))
	left.add_child(_summary)
	var setup_b := _menu_button("RACE SETUP", func(): _show(_setup, true), Vector2(460, 70))
	left.add_child(_center_wrap(setup_b))
	_update_summary()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for item in [["GARAGE", "res://scenes/garage.tscn"], ["RECORDS", "res://scenes/records.tscn"], ["AWARDS", "res://scenes/awards.tscn"], ["HOW TO PLAY", ""]]:
		var target: String = item[1]
		var b := _menu_button(item[0], func():
			if target == "":
				_start_tutorial()
			else:
				Game.save_settings()
				get_tree().change_scene_to_file(target), Vector2(223, 76))
		grid.add_child(b)
	right.add_child(_center_wrap(_career_button()))
	right.add_child(_center_wrap(grid))
	right.add_child(_daily_chip())

	# Settings gear in the top-left corner (the coin counter sits top-right).
	var gear := Button.new()
	gear.custom_minimum_size = Vector2(60, 60)
	var sr := Game.safe_rect()
	gear.position = sr.position + Vector2(16, 16)
	gear.focus_mode = Control.FOCUS_NONE
	gear.add_theme_stylebox_override("normal", Game.make_style(Color(0.08, 0.09, 0.13, 0.9), 30, Color(0.02, 0.03, 0.05), 4))
	gear.add_theme_stylebox_override("hover", Game.make_style(Color(0.16, 0.18, 0.24, 0.95), 30, Color(0.02, 0.03, 0.05), 4))
	gear.draw.connect(func(): _draw_gear(gear))
	gear.pressed.connect(func(): _show(_settings, true))
	add_child(gear)


## CAREER, with the stars earned so far.
func _career_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(460, 80)
	b.focus_mode = Control.FOCUS_NONE
	var gold := Color(1.0, 0.82, 0.2)
	b.add_theme_stylebox_override("normal", Game.make_style(Color(0.2, 0.15, 0.05, 0.95), 18, gold, 4))
	b.add_theme_stylebox_override("hover", Game.make_style(Color(0.28, 0.21, 0.07, 0.95), 18, gold, 4))
	b.add_theme_stylebox_override("pressed", Game.make_style(Color(0.14, 0.1, 0.03, 0.95), 18, gold, 4))
	b.pressed.connect(func():
		Game.save_settings()
		get_tree().change_scene_to_file("res://scenes/career.tscn"))
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 14)
	c.add_child(h)
	var t := _label("CAREER", 32, 8, gold)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var star := StarRow.new(1, 26, 0, 1)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(star)
	var n := _label("%d/%d" % [Profile.career_total(), Game.CareerEvents.count() * 3], 24, 6)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	return b


func _draw_gear(ci: Control) -> void:
	var c := ci.size * 0.5
	var col := Color(0.85, 0.88, 0.95)
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0)
		ci.draw_line(c + d * 9.0, c + d * 16.0, col, 6.0)
	ci.draw_circle(c, 12.0, col)
	ci.draw_circle(c, 5.0, Color(0.08, 0.09, 0.13))


func _update_summary() -> void:
	var parts: Array[String] = []
	if Game.is_trial():
		parts = ["TIME TRIAL", "%d LAPS" % Game.laps]
	else:
		parts.append("%d PLAYER%s" % [Game.num_players, "" if Game.num_players == 1 else "S"])
		if Game.num_cpus > 0:
			parts.append("%d CPU (%s)" % [Game.num_cpus, Game.CPU_LEVELS[Game.cpu_level]])
		parts.append("SINGLE RACE" if Game.races == 1 else "CUP OF %d" % Game.races)
		parts.append("%d LAPS" % Game.laps)
	if not Game.items_on and not Game.is_trial():
		parts.append("NO ITEMS")
	if Game.weather_mode != 0:
		parts.append(Game.WEATHER_MODES[Game.weather_mode])
	_summary.text = "  •  ".join(parts)


# --- Race setup panel -------------------------------------------------------------

func _build_setup() -> void:
	var content := _panel_overlay()
	_setup = content.get_meta("overlay")
	var cols: BoxContainer = HBoxContainer.new() if _landscape else VBoxContainer.new()
	cols.add_theme_constant_override("separation", 40 if _landscape else 14)
	var left := _column()
	left.add_theme_constant_override("separation", 8)
	var right := _column()
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_label("RACE SETUP", 40, 8, Game.ACCENT))
	content.add_child(cols)
	cols.add_child(left)
	cols.add_child(right)
	left.add_child(_option_row("PLAYERS", [1, 2, 3, 4], ["1", "2", "3", "4"], Game.num_players, _pick_players))
	var cpu_row := _option_row("CPU RIVALS", [0, 1, 2, 3], ["0", "1", "2", "3"], Game.num_cpus, _pick_cpus)
	_cpu_buttons = _last_row_buttons
	left.add_child(cpu_row)
	left.add_child(_option_row("CPU LEVEL", [0, 1, 2], Game.CPU_LEVELS, Game.cpu_level, func(v): Game.cpu_level = v; _refresh_controls()))
	_level_buttons = _last_row_buttons
	left.add_child(_option_row("RACES", Game.RACE_OPTIONS, ["SINGLE", "CUP 3", "CUP 5", "TRIAL"], Game.races, func(v): Game.races = v; _refresh_controls()))
	left.add_child(_option_row("LAPS", Game.LAP_OPTIONS, ["5", "6"], Game.laps, func(v): Game.laps = v))
	left.add_child(_option_row("ITEMS", [1, 0], ["ON", "OFF"], 1 if Game.items_on else 0, func(v): Game.items_on = v == 1))
	left.add_child(_option_row("WEATHER", [0, 1, 2, 3], Game.WEATHER_MODES, Game.weather_mode, func(v): Game.weather_mode = v))
	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 8)
	right.add_child(_label("ON THE GRID", 18, 4, Color(1, 1, 1, 0.6)))
	right.add_child(_controls_box)
	right.add_child(_spacer(6))
	right.add_child(_center_wrap(_big_button("START RACE", _start, Vector2(420, 88), 34)))
	right.add_child(_center_wrap(_menu_button("DONE", func(): _show(_setup, false), Vector2(420, 62))))
	_fix_cpu_count()
	_refresh_controls()


# --- Settings panel -----------------------------------------------------------------

func _build_settings() -> void:
	var content := _panel_overlay()
	_settings = content.get_meta("overlay")
	content.add_child(_label("SETTINGS", 40, 8, Game.ACCENT))
	_sound_button = _menu_button("", _toggle_sound, Vector2(380, 70))
	_music_button = _menu_button("", _toggle_music, Vector2(380, 70))
	content.add_child(_center_wrap(_sound_button))
	content.add_child(_center_wrap(_music_button))
	if Game.is_touch():
		_vibe_button = _menu_button("", _toggle_vibration, Vector2(380, 70))
		content.add_child(_center_wrap(_vibe_button))
	if not OS.has_feature("mobile"):
		content.add_child(_center_wrap(_menu_button("FULLSCREEN", Game.toggle_fullscreen, Vector2(380, 70))))
	content.add_child(_center_wrap(_menu_button("CLOSE", func(): _show(_settings, false), Vector2(380, 62))))
	_update_sound_button()


## A dimmed full-screen overlay with a centred panel; returns the panel's content box
## (the overlay itself is stored in its "overlay" meta). Starts hidden.
func _panel_overlay() -> VBoxContainer:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	Game.fit_to_safe(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Game.make_style(Color(0.07, 0.08, 0.12, 0.97), 26, Color(0.02, 0.03, 0.05), 5))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.set_meta("overlay", overlay)
	return v


func _show(panel: Control, on: bool) -> void:
	panel.visible = on
	Sfx.play(Sfx.beep, -10.0, 1.2 if on else 0.9)
	if not on:
		Game.save_settings()
		_update_summary()


func _big_button(text: String, fn: Callable, size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", Game.make_style(Game.ACCENT, 22, Color(0.02, 0.03, 0.05), 6))
	b.add_theme_stylebox_override("hover", Game.make_style(Game.ACCENT.lightened(0.12), 22, Color(0.02, 0.03, 0.05), 6))
	b.add_theme_stylebox_override("pressed", Game.make_style(Game.ACCENT.darkened(0.15), 22, Color(0.02, 0.03, 0.05), 6))
	b.pressed.connect(fn)
	return b


func _menu_button(text: String, fn: Callable, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(fn)
	return b


func _center_wrap(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	w.add_child(c)
	return w


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
	# Kept light: it runs the whole time the menu is open (3 cars, no smoke or skids).
	_demo.build(map, 3)
	_demo.effects.show_tags = false
	_demo.effects.visible = false
	_demo.effects.set_process(false)
	for car in _demo.cars:
		car.effects = null # no smoke, sparks or skid marks to update
	if _demo.train:
		_demo.train.quiet = true # no bell or horn under the menu music
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
			if car.bot_wants_nitro() and not _demo.train_ahead(car):
				car.fire_nitro()
			car.tick(delta, car.bot_throttle() and not _demo.should_wait_for_train(car))
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
	Game.fit_to_safe(center)
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


func _toggle_vibration() -> void:
	Game.vibration = not Game.vibration
	Game.save_settings()
	_update_sound_button()
	Game.buzz(60, 0.7)


func _update_sound_button() -> void:
	if _vibe_button:
		_vibe_button.text = "VIBRATION: ON" if Game.vibration else "VIBRATION: OFF"
	if _sound_button:
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
			cpu_chip.add_child(_label("%s   CPU %s   (%s)" % [Game.driver(i).name, Game.CPU_LEVELS[Game.cpu_level].to_lower(), corners[i]], 21, 4, Game.PLAYER_COLORS[i].lightened(0.1)))
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
