extends Node
## Autoload "Game": race settings, player definitions, input setup and the map registry.

const MIN_PLAYERS := 1 # humans; a lone player races CPUs
const MAX_PLAYERS := 4 # cars on track (humans + CPUs)
const RACE_OPTIONS := [1, 3, 5, 0] # 1 = single race, 3/5 = championship, 0 = time trial
const TUTORIAL_MAP := 2 # Forest Ring: simple and flowing
const POINTS := [10, 6, 3, 1]
const CPU_LEVELS := ["EASY", "NORMAL", "HARD"]
# How close to each corner's limit CPUs drive (1.0 = on the limit, tolerance included),
# and the share of top speed they use on straights.
const CPU_SKILL := [0.64, 0.74, 1.03]
const CPU_TOP := [0.66, 0.76, 1.0]
const LAP_OPTIONS := [5, 6]
const ACCENT := Color(1.0, 0.45, 0.2)

const PLAYER_NAMES := ["RED", "BLUE", "YELLOW", "GREEN"]
const PLAYER_COLORS := [
	Color(1.0, 0.3, 0.3),
	Color(0.25, 0.64, 1.0),
	Color(1.0, 0.82, 0.25),
	Color(0.24, 0.86, 0.52),
]

# Physical key positions (layout independent). Spread across the keyboard so that
# several can be held together, and no modifier keys (Shift/Ctrl/Alt) so the OS
# never pops up Sticky Keys or other hotkey prompts.
# P1 = bottom-right pad, P2 = top-left, P3 = bottom-left, P4 = top-right.
const PLAYER_KEYS := [[KEY_L], [KEY_A], [KEY_V], [KEY_UP]]

# Map registry: add a new map script here and it joins the random rotation.
const Drivers = preload("res://scripts/drivers.gd")

const MAPS := [
	preload("res://maps/sunset_speedway.gd"),
	preload("res://maps/canyon_hairpins.gd"),
	preload("res://maps/forest_ring.gd"),
	preload("res://maps/frosty_peaks.gd"),
	preload("res://maps/palm_beach.gd"),
	preload("res://maps/crossover.gd"),
	preload("res://maps/volcano_rush.gd"),
	preload("res://maps/neon_nights.gd"),
	preload("res://maps/autumn_valley.gd"),
	preload("res://maps/orbit_station.gd"),
	preload("res://maps/farmland_twist.gd"),
	preload("res://maps/harbor_docks.gd"),
	preload("res://maps/splash_canyon.gd"),
]

var num_players := 2 # humans
var num_cpus := 0
var cpu_level := 1
var laps := 5
var races := 1 # races in the championship (1 = single race)
var items_on := true # power-up boxes on the track
var weather_mode := 0 # 0 random, 1 clear, 2 rain, 3 night
const WEATHER_MODES := ["RANDOM", "CLEAR", "RAIN", "NIGHT"]

var tutorial := false # the guided "how to play" race
var retry_map := -1 # race this map again instead of a random one (time trial retry, rematch)
var rematch_boost := -1 # rematch: car slot that gets a head start and full nitro (-1 = none)

# Championship state.
var cup_race := 0 # races finished so far
var cup_points: Array[int] = [0, 0, 0, 0]
var cup_wins: Array[int] = [0, 0, 0, 0]
var cup_last_place: Array[int] = [0, 0, 0, 0]
var cpu_drivers: Array = [] # personality for each car slot that is a CPU (null for humans)

var _last_map := -1
var current_map := -1 # index of the map being raced
var _used_maps: Array[int] = []

# Debug options, passed after "--" on the command line (e.g. `godot -- --players=4 --bots`).
var debug_map := -1
var debug_bots := false
var debug_reckless := false # bots never brake (tests crashes)
var debug_coast := false
var debug_log := false # print lap times and results
var debug_item := "" # --items=rocket (shield, mega, lightning, mine): every box gives that item
var debug_perf := false # print render stats (draw calls, primitives, fps)
var debug_autopilot := false # P1 is driven by the bot but counts as a human (tests saving)
var debug_podium := false # jump straight to a sample championship podium
var debug_scene := "" # open scenes/<name>.tscn straight away (e.g. garage, records)
var debug_coins := -1 # set the coin balance (for testing the garage)
var debug_shot := ""
var debug_shot_time := 1.0
var debug_shot_on := "" # --shot_on=rocket: take the --shot screenshot just after a rocket fires
var debug_skip_menu := false


func _ready() -> void:
	randomize()
	_setup_input()
	_parse_debug_args()
	get_tree().root.size_changed.connect(_update_layout)
	_update_layout()
	if debug_shot != "" and debug_shot_on == "":
		_debug_screenshot()


var _perf_t := 0.0


func _process(delta: float) -> void:
	if not debug_perf:
		return
	_perf_t += delta
	if _perf_t > 1.0:
		_perf_t = 0.0
		print("PERF fps %d  draw calls %d  primitives %d  frame %.1f ms" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		toggle_fullscreen()


## Wide windows (desktop, big screens) use a 1280x720 landscape layout; tall ones
## (phones) use 720x1280 portrait. The short side is always 720 so UI keeps its size.
func _update_layout() -> void:
	var root := get_tree().root
	var want := Vector2i(1280, 720) if root.size.x > root.size.y else Vector2i(720, 1280)
	if root.content_scale_size != want:
		root.content_scale_size = want


func is_landscape_layout() -> bool:
	var s := get_tree().root.content_scale_size
	return s.x > s.y


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


static func action_name(i: int) -> String:
	return "p%d_throttle" % (i + 1)


func _setup_input() -> void:
	for i in MAX_PLAYERS:
		var action := action_name(i)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in PLAYER_KEYS[i]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


var _key_labels := {}


func key_label(i: int) -> String:
	if not _key_labels.has(i):
		_key_labels[i] = _make_key_label(i)
	return _key_labels[i]


func _make_key_label(i: int) -> String:
	var key: Key = PLAYER_KEYS[i][0]
	if key == KEY_UP:
		return "UP"
	if OS.has_feature("web"):
		return OS.get_keycode_string(key) # layout lookup isn't available in browsers
	var mapped := DisplayServer.keyboard_get_keycode_from_physical(key)
	return OS.get_keycode_string(mapped if mapped != KEY_NONE else key)


var debug_safe := Vector4.ZERO # --safe=left,top,right,bottom: fake a phone's cutouts

## Phone screen insets (left, top, right, bottom) in viewport units: the notch or
## camera hole, rounded corners and the gesture bar. Zero on desktop and web.
func safe_insets() -> Vector4:
	if debug_safe != Vector4.ZERO:
		return debug_safe
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or safe.size.x <= 0:
		return Vector4.ZERO
	var k := get_tree().root.get_visible_rect().size / win
	return Vector4(
		maxf(0.0, safe.position.x * k.x), maxf(0.0, safe.position.y * k.y),
		maxf(0.0, (win.x - safe.end.x) * k.x), maxf(0.0, (win.y - safe.end.y) * k.y))


## The part of the screen clear of cutouts, in viewport units.
func safe_rect() -> Rect2:
	var vp := get_tree().root.get_visible_rect()
	var i := safe_insets()
	return Rect2(vp.position + Vector2(i.x, i.y), vp.size - Vector2(i.x + i.z, i.y + i.w))


## Keeps a full-screen control inside the safe area (and updates on resize/rotate).
func fit_to_safe(c: Control) -> void:
	_apply_insets(c, 1.0)
	get_tree().root.size_changed.connect(func():
		if is_instance_valid(c):
			_apply_insets(c, 1.0))


## For a background inside a safe-area control: stretch it back out to the edges.
func bleed(c: Control) -> void:
	_apply_insets(c, -1.0)
	get_tree().root.size_changed.connect(func():
		if is_instance_valid(c):
			_apply_insets(c, -1.0))


func _apply_insets(c: Control, sign: float) -> void:
	var i := safe_insets() * sign
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = i.x
	c.offset_top = i.y
	c.offset_right = -i.z
	c.offset_bottom = -i.w


var _touch_seen := false


## True on phones and tablets. Some mobile browsers only report a touchscreen after
## the first touch, so the platform and any touch seen so far count too.
func is_touch() -> bool:
	return _touch_seen or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _touch_seen:
		_touch_seen = true


var _settings_loaded := false


## Restores the menu choices and sound settings from the profile (once per session).
func load_settings() -> void:
	if _settings_loaded or debug_skip_menu or debug_podium:
		return
	_settings_loaded = true
	num_players = int(Profile.setting("players", num_players))
	num_cpus = int(Profile.setting("cpus", num_cpus))
	cpu_level = int(Profile.setting("cpu_level", cpu_level))
	races = int(Profile.setting("races", races))
	laps = int(Profile.setting("laps", laps))
	items_on = bool(Profile.setting("items", items_on))
	weather_mode = int(Profile.setting("weather", weather_mode))
	Sfx.enabled = bool(Profile.setting("sound", true))
	Sfx.set_music_enabled(bool(Profile.setting("music", true)))


func save_settings() -> void:
	if debug_bots or debug_log or debug_shot != "" or OS.get_cmdline_user_args().size() > 0:
		return # test runs must not overwrite the player's settings
	for pair in [["players", num_players], ["cpus", num_cpus], ["cpu_level", cpu_level], ["races", races], ["laps", laps], ["items", items_on], ["weather", weather_mode], ["sound", Sfx.enabled], ["music", Sfx.music_enabled]]:
		Profile.data.settings[pair[0]] = pair[1]
	Profile.save()


## Weather for the next race: fixed, or random (mostly clear, sometimes rain or night).
func pick_weather() -> String:
	if tutorial:
		return "clear"
	match weather_mode:
		1: return "clear"
		2: return "rain"
		3: return "night"
	var r := randf()
	return "rain" if r < 0.2 else ("night" if r < 0.4 else "clear")


func is_trial() -> bool:
	return races == 0 and not tutorial


## Solo modes (tutorial, time trial) only have P1 on track.
func total_racers() -> int:
	if tutorial or is_trial():
		return 1
	return clampi(num_players + num_cpus, 1, MAX_PLAYERS)


func race_laps() -> int:
	return 2 if tutorial else laps


func items_enabled() -> bool:
	return items_on and not is_trial()


func is_cpu(i: int) -> bool:
	return i >= num_players


func racer_name(i: int) -> String:
	if is_cpu(i):
		return driver(i).name
	return "P%d %s" % [i + 1, PLAYER_NAMES[i]]


## Short name for pop-ups: "P2", or a CPU driver's name.
func short_name(i: int) -> String:
	return driver(i).name if is_cpu(i) else "P%d" % (i + 1)


## The CPU personality in slot `i` (the same one for a whole championship).
func driver(i: int) -> Dictionary:
	if cpu_drivers.size() < MAX_PLAYERS or cpu_drivers[i] == null:
		_assign_drivers()
	return cpu_drivers[i]


func _assign_drivers() -> void:
	var picks := Drivers.pick(MAX_PLAYERS)
	cpu_drivers = []
	for i in MAX_PLAYERS:
		cpu_drivers.append(picks[i])


func is_championship() -> bool:
	return races > 1 and not tutorial


## Starts a fresh championship (or single race) with the current settings.
func start_cup() -> void:
	_assign_drivers() # new rivals for every championship / single race
	cup_race = 0
	for i in MAX_PLAYERS:
		cup_points[i] = 0
		cup_wins[i] = 0
		cup_last_place[i] = 0
	_used_maps.clear()


## Records a finished race (order = racer indices, winner first); returns points given.
func record_race(order: Array[int]) -> Array[int]:
	var given: Array[int] = [0, 0, 0, 0]
	for place in order.size():
		var i := order[place]
		given[i] = POINTS[place] if place < POINTS.size() else 0
		cup_points[i] += given[i]
		cup_last_place[i] = place + 1
		if place == 0:
			cup_wins[i] += 1
	cup_race += 1
	return given


func cup_finished() -> bool:
	return cup_race >= races


## Championship standings: racer indices, best first (points, then wins, then last race).
func cup_standings() -> Array[int]:
	var order: Array[int] = []
	for i in total_racers():
		order.append(i)
	order.sort_custom(func(a, b):
		if cup_points[a] != cup_points[b]:
			return cup_points[a] > cup_points[b]
		if cup_wins[a] != cup_wins[b]:
			return cup_wins[a] > cup_wins[b]
		return cup_last_place[a] < cup_last_place[b])
	return order


## Returns a new random map: never the same twice in a row, and no repeats within
## a championship until every map has been used.
func next_map():
	var idx := randi() % MAPS.size()
	if tutorial:
		idx = TUTORIAL_MAP
	elif retry_map >= 0:
		idx = retry_map
		retry_map = -1
	elif debug_map >= 0:
		idx = debug_map % MAPS.size()
	elif MAPS.size() > 1:
		if _used_maps.size() >= MAPS.size():
			_used_maps.clear()
		var tries := 0
		while (idx == _last_map or _used_maps.has(idx)) and tries < 100:
			idx = randi() % MAPS.size()
			tries += 1
	_last_map = idx
	_used_maps.append(idx)
	current_map = idx
	return MAPS[idx].build()


func _parse_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"players": num_players = clampi(value.to_int(), MIN_PLAYERS, MAX_PLAYERS)
			"cpus": num_cpus = clampi(value.to_int(), 0, MAX_PLAYERS - 1)
			"cpu_level": cpu_level = clampi(value.to_int(), 0, 2)
			"races": races = maxi(0, value.to_int())
			"tutorial": tutorial = true
			"log": debug_log = true
			"rematch": rematch_boost = value.to_int() # test the rematch head start
			"touch": _touch_seen = true # preview the phone layout on desktop
			"safe":
				var v := value.split(",")
				if v.size() == 4:
					debug_safe = Vector4(v[0].to_float(), v[1].to_float(), v[2].to_float(), v[3].to_float())
			"perf": debug_perf = true
			"autopilot": debug_autopilot = true
			"weather": weather_mode = maxi(0, WEATHER_MODES.find(value.to_upper()))
			"items":
				items_on = value != "off"
				debug_item = value if value in ["rocket", "shield", "mega", "lightning", "mine"] else ""
			"podium": debug_podium = true
			"scene": debug_scene = value
			"garage_tab": set_meta("garage_tab", value.to_int())
			"menu_panel": set_meta("menu_panel", value)
			"coins": debug_coins = value.to_int()
			"laps": laps = maxi(1, value.to_int())
			"map": debug_map = value.to_int()
			"bots":
				debug_bots = true
				debug_reckless = value == "reckless"
				debug_coast = value == "coast" # lets go before the jump ramp (tests splashes)
			"race": debug_skip_menu = true
			"shot":
				debug_shot = value
			"shot_time": debug_shot_time = value.to_float()
			"shot_on": debug_shot_on = value


## Takes the debug screenshot `delay` seconds from now (used by --shot_on).
func debug_capture(delay: float) -> void:
	if debug_shot == "":
		return
	debug_shot_time = delay
	var path := debug_shot
	debug_shot = ""
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _debug_screenshot() -> void:
	await get_tree().create_timer(debug_shot_time).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(debug_shot)
	get_tree().quit()


# --- UI styling shared by the menu and race screens ---

func make_style(bg: Color, radius := 14, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_width)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var accent := ACCENT
	t.set_stylebox("normal", "Button", make_style(Color(0.17, 0.19, 0.25), 14))
	t.set_stylebox("hover", "Button", make_style(Color(0.24, 0.27, 0.35), 14))
	t.set_stylebox("pressed", "Button", make_style(accent, 14))
	t.set_stylebox("hover_pressed", "Button", make_style(accent.lightened(0.1), 14))
	t.set_stylebox("disabled", "Button", make_style(Color(0.12, 0.13, 0.16), 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_font_size("font_size", "Button", 28)
	t.set_stylebox("panel", "PanelContainer", make_style(Color(0.07, 0.08, 0.11, 0.92), 18))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	return t
