extends Node2D
## One race: loads a random map, runs start lights -> race -> results.
## "Play again" reloads this scene, which picks a new random map.

const RaceWorld = preload("res://scripts/race_world.gd")
const Car = preload("res://scripts/car.gd")
const PlayerPads = preload("res://scripts/player_pads.gd")
const StartLights = preload("res://scripts/start_lights.gd")
const Confetti = preload("res://scripts/confetti.gd")
const RainLayer = preload("res://scripts/rain_layer.gd")
const TutorialCoach = preload("res://scripts/tutorial_coach.gd")
const TimeTrial = preload("res://scripts/time_trial.gd")
const StarRow = preload("res://scripts/star_row.gd")
const FontWarmer = preload("res://scripts/font_warmer.gd")
const CE = preload("res://scripts/career_events.gd")
const Replay = preload("res://scripts/replay.gd")

enum Phase { INTRO, COUNTDOWN, RACING, RESULTS }

const INTRO_TIME := 2.4 # camera sweep over the track before the lights
# Zoom of the sweep. The track is baked once at the normal size (a sharper second
# bake just for the intro cost phones a freeze and a lot of memory), so keep it mild.
const INTRO_ZOOM := 1.4

const COUNTDOWN_TIME := 3.3 # red lights at 0.3s, 1.3s, 2.3s, green at 3.3s
const FINISH_GRACE := 15.0 # seconds the others get after the winner crosses the line

var world: RaceWorld
var cars: Array = []
var pads: PlayerPads
var phase := Phase.COUNTDOWN
var race_time := 0.0
var finish_order: Array = []

var _countdown := COUNTDOWN_TIME
var _reds := 0
var _grace := -1.0
var _paused := false
var _laps_seen: Array[int] = []
var _big_label: Label
var _sub_label: Label
var _lights: StartLights
var _confetti: Confetti
var _flash_tween: Tween
var _results: Control
var _results_box: VBoxContainer
var _pause_menu: Control
var _flash_rect: ColorRect
var root_ui: Control
# Commentary.
var _prev_places: Array[int] = []
var _last_callout: Array[float] = []
var _lap_start: Array[float] = []
var _best_lap := INF
var _last_cheer := -10.0
# Per-car race stats for coins, records and the daily challenge.
var _perfect: Array[int] = []
var _nitros: Array[int] = []
var _close: Array[int] = []
var _best: Array[float] = []
# Photo finish.
var _photo := false
var _photo_winner = null
# Achievement tracking.
var _rocket_hits: Array[int] = [] # cars each racer knocked out with rockets
var _was_last: Array[bool] = [] # was last after lap 1 (COMEBACK KID)
var _weather := "clear"
# Solo modes.
var _intro_t := 0.0
# Mid-race shower.
const SHOWER_CHANCE := 0.3 # of clear races (random weather only)
const SHOWER_FADE := 5.0 # seconds for the rain to build up
var _shower_at := -1.0 # leader's progress when the shower starts (-1: none)
var _shower_t := -1.0 # seconds since it started (-1: not building up)
var _rain_layer: RainLayer
# Replay of the race's best moment, shown before the results.
var replay: Replay
var _replaying := false
var _skip_replay := false
var coach: TutorialCoach
var trial: TimeTrial


func _ready() -> void:
	world = RaceWorld.new()
	add_child(world)
	world.build(Game.next_map(), Game.total_racers())
	cars = world.cars
	if Game.items_enabled():
		world.enable_powerups()
		world.powerups.effects = world.effects
		world.powerups.picked.connect(_on_pickup)
		world.powerups.rocket_hit.connect(_on_rocket_hit)
		world.powerups.mine_hit.connect(_on_mine_hit)
	var weather := Game.pick_weather()
	_weather = weather
	world.set_weather(weather)
	for car in cars:
		_laps_seen.append(0)
		_prev_places.append(0)
		_last_callout.append(-10.0)
		_lap_start.append(0.0)
		_perfect.append(0)
		_nitros.append(0)
		_close.append(0)
		_best.append(INF)
		_rocket_hits.append(0)
		_was_last.append(false)
		car.near_miss.connect(_on_near_miss)
		car.shield_used.connect(_on_shield_used)
		car.jumped.connect(_on_jumped)
		car.landed.connect(_on_landed)
		car.splashed.connect(_on_splashed)
		if Game.is_cpu(car.index):
			car.engine_gain = -7.0

		car.crashed.connect(_on_crash)
		car.boost_started.connect(_on_boost)
		car.nitro_ready.connect(_on_nitro_ready)
		if Sfx.enabled:
			car.engine = Sfx.make_engine(car.body)
			car.add_child(car.engine)
			car.engine.play()

	_build_ui()
	_sub_label.text = world.map.title.to_upper()
	if weather == "rain":
		_sub_label.text += "\nRAIN - SLIPPERY CORNERS!"
		_add_rain_layer()
		Sfx.play_ambient(Sfx.rain)
	elif weather == "clear" and _shower_allowed():
		# A shower will roll in partway through (somewhere from lap 2 to the second-to-last).
		var lap: int = Game.debug_shower if Game.debug_shower >= 0 else randi_range(2, Game.race_laps() - 1)
		lap = clampi(lap, 1, Game.race_laps())
		_shower_at = (lap - 1 + randf_range(0.25, 0.6)) * world.track.length
	elif weather == "night":
		_sub_label.text += "\nNIGHT RACE"
	if Game.is_championship():
		_sub_label.text = "RACE %d OF %d\n%s" % [Game.cup_race + 1, Game.races, _sub_label.text]
	var king := Game.king()
	if king >= 0 and king < cars.size() and not Game.is_career():
		_sub_label.text += "\nKING: %s  •  %d WINS IN A ROW" % [Game.racer_name(king), Game.streak_wins]
		if Game.num_players > 1:
			_sub_label.text += "\nBEAT THEM FOR +%d COINS!" % Game.KING_SLAYER_COINS
	if Game.is_career():
		var e: Dictionary = CE.event(Game.career_event)
		_sub_label.text = "EVENT %d  •  %s\n%s\nGOAL: %s" % [Game.career_event + 1, e.title, _sub_label.text, CE.goal_text(Game.career_event)]
	if Game.tutorial:
		coach = TutorialCoach.new()
		add_child(coach)
		coach.setup(self)
		_sub_label.text = "TUTORIAL"
	elif Game.is_trial():
		trial = TimeTrial.new()
		add_child(trial)
		trial.setup(self)
		_sub_label.text = "TIME TRIAL\n" + _sub_label.text
	if not (Game.tutorial or Game.is_trial()):
		replay = Replay.new()
		add_child(replay)
		replay.setup(world)
	if world.train:
		world.train.set_process(false) # trains run once the race starts
		world.train.warned.connect(_on_train_warning)
		world.train.passing.connect(_on_train_passing)
	# Intro sweep (skipped in tests and the tutorial).
	var intro := not (Game.debug_bots or Game.debug_log or Game.tutorial or Game.debug_no_intro)
	if intro:
		phase = Phase.INTRO
		world.hold_view = true
	_fit_world()
	get_viewport().size_changed.connect(_fit_world)
	if intro:
		_lights.modulate.a = 0.0
		_update_intro(0.0)
	Sfx.play_music("")


# --- Level-crossing train ---------------------------------------------------------



func _on_train_warning() -> void:
	# Heads-up for players heading towards the crossing.
	for i in mini(Game.num_players, cars.size()):
		var ahead: float = -world.track.dist_from_rail(cars[i].progress)
		if ahead > 0.0 and ahead < 900.0:
			pads.toast(i, "TRAIN!", Color(1.0, 0.35, 0.3), "brake for the crossing")


func _on_train_passing() -> void:
	if Game.debug_log:
		print("TRAIN at %.2fs" % race_time)
	if Game.debug_shot_on == "train":
		Game.debug_capture(Game.debug_shot_time) # --shot_time = seconds after it appears


func _check_train_hits() -> void:
	for car in cars:
		if car.state != Car.State.RACING or car.airborne:
			continue
		if not world.train.hits(car.progress, car.lane_offset):
			continue
		if Game.debug_log:
			print("TRAIN HIT %s at %.2fs (speed %d, from rails %.0f, lane %.0f, head %.0f)" % [_short_name(car.index), race_time, car.speed, world.track.dist_from_rail(car.progress), car.lane_offset, world.train.head])
		if car.rocket_hit(): # a shield saves you, same as a rocket
			pads.toast(car.index, "HIT BY THE TRAIN!", Color(1.0, 0.45, 0.2), "wait when the lights flash")
			_note(95, car, "HIT BY THE TRAIN!")
			_crowd(true)
			world.shake = maxf(world.shake, 0.35)
			Game.buzz_for(car.index, 180, 1.0)


## Lights flashing and the crossing coming up: no nitro (a boosting car can't brake).
func _train_ahead(car) -> bool:
	return world.train_ahead(car)


## CPU drivers stop for the train when they couldn't clear the crossing in time.
## Easy CPUs sometimes chance it anyway (once per train, per driver).
func _cpu_waits_for_train(car) -> bool:
	if Game.cpu_level == 0 and world.train and (car.index + world.train.cycle) % 3 == 0:
		return false
	return world.should_wait_for_train(car)


# --- Replay -------------------------------------------------------------------------

func _note(score: int, car, label: String) -> void:
	if replay and car != null and phase == Phase.RACING:
		replay.note(race_time, score, car.index, label)


func _fx(kind: String, car) -> void:
	if replay:
		replay.fx(race_time, kind, car)


func _want_replay() -> bool:
	if replay == null or not bool(Profile.setting("replays", true)):
		return false
	if (Game.debug_bots or Game.debug_log) and Game.debug_shot == "":
		return false # tests
	replay.update(race_time, true)
	return replay.has_clip()


## Plays the best moment in slow motion, with cinema bars; any tap skips it.
func _play_replay() -> void:
	_replaying = true
	_skip_replay = false
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(ui)
	Game.bleed(ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size.y = 64.0 + (Game.safe_insets().y if top else Game.safe_insets().w)
		ui.add_child(bar)
		if not top:
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var head := _make_label(30, 8, "●  REPLAY  •  " + String(replay.clip.label))
	head.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.position.y = Game.safe_insets().y + 14.0
	ui.add_child(head)
	head.position.x = (ui.size.x - head.size.x) * 0.5
	var hint := _make_label(18, 4, "TAP TO SKIP")
	hint.modulate.a = 0.7
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ui.add_child(hint)
	hint.position = Vector2((ui.size.x - hint.size.x) * 0.5, ui.size.y - Game.safe_insets().w - 44.0)
	ui.modulate.a = 0.0
	create_tween().tween_property(ui, "modulate:a", 1.0, 0.2)
	_confetti.visible = false # the finish's confetti isn't part of the replay
	Engine.time_scale = Replay.SPEED
	Sfx.set_music_pitch(0.85)
	replay.start()
	if Game.debug_shot_on == "replay":
		Game.debug_capture(Game.debug_shot_time) # --shot_time = seconds into the replay
	var elapsed := 0.0
	while true:
		await get_tree().process_frame
		var d := get_process_delta_time()
		elapsed += d
		if _skip_replay and elapsed > 0.3:
			break
		if not replay.step(d):
			break
	replay.stop()
	_confetti.visible = true
	Engine.time_scale = 1.0
	Sfx.set_music_pitch(_music_pitch)
	ui.queue_free()
	_replaying = false


func _input(event: InputEvent) -> void:
	if not _replaying:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_skip_replay = true
		get_viewport().set_input_as_handled()


func _add_rain_layer() -> void:
	_rain_layer = RainLayer.new()
	root_ui.add_child(_rain_layer)
	Game.bleed(_rain_layer)
	root_ui.move_child(_rain_layer, 0)


func _shower_allowed() -> bool:
	if Game.debug_shower >= 0:
		return true
	if Game.weather_mode != 0 or Game.is_career() or Game.tutorial or Game.is_trial():
		return false # the player (or the event) picked the weather
	return Game.race_laps() >= 3 and randf() < SHOWER_CHANCE


## Thunder, a warning, then the rain builds up over SHOWER_FADE seconds.
func _start_shower() -> void:
	if Game.debug_log:
		print("SHOWER at %.2fs" % race_time)
	if Game.debug_shot_on == "shower":
		Game.debug_capture(Game.debug_shot_time) # --shot_time = seconds after it starts
	_weather = "rain" # counts as a rain race (STORM CHASER)
	_flash_rect.color = Color(0.85, 0.9, 1.0, 0.7) # lightning
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.0, 0.12)
	t.tween_property(_flash_rect, "color:a", 0.45, 0.05)
	t.tween_property(_flash_rect, "color:a", 0.0, 0.35)
	Sfx.play(Sfx.crash, -3.0, 0.32) # thunder rumble
	Game.buzz(90, 0.6)
	world.shake = maxf(world.shake, 0.15)
	_flash("RAIN INCOMING!", 1.2, Color(0.6, 0.8, 1.0))
	for i in mini(Game.num_players, cars.size()):
		pads.toast(i, "RAIN!", Color(0.6, 0.8, 1.0), "brake earlier")
	_add_rain_layer()
	_rain_layer.amount = 0.0
	Sfx.play_ambient(Sfx.rain)
	Sfx.set_ambient_level(0.0)
	_shower_t = 0.0


func _update_shower(delta: float) -> void:
	_shower_t += delta
	var a := clampf((_shower_t - 1.0) / SHOWER_FADE, 0.0, 1.0)
	_rain_layer.amount = a
	Sfx.set_ambient_level(a)
	world.set_rain(snappedf(a, 0.1)) # in steps: each change re-renders the bridge deck
	if a >= 1.0:
		_shower_t = -1.0


func _exit_tree() -> void:
	Sfx.play_ambient(null)
	Engine.time_scale = 1.0
	Sfx.set_music_pitch(1.0)


func _fit_world() -> void:
	var sr := Game.safe_rect()
	var band := PlayerPads.band_height()
	var keepouts := PlayerPads.keepouts(sr, cars.size())
	if sr.size.x > sr.size.y:
		world.fit(Rect2(sr.position + Vector2(band, 12.0), sr.size - Vector2(band * 2.0, 24.0)), 1.6, keepouts)
	else:
		world.fit(Rect2(sr.position + Vector2(12.0, band), sr.size - Vector2(24.0, band * 2.0)), 1.6, keepouts)


func _process(delta: float) -> void:
	if _paused or _replaying:
		return
	match phase:
		Phase.INTRO:
			_intro_t += delta
			_update_intro(_intro_t / INTRO_TIME)
			if _intro_t >= INTRO_TIME or _intro_skip():
				_end_intro()
		Phase.COUNTDOWN:
			_countdown -= delta
			var elapsed := COUNTDOWN_TIME - _countdown
			var reds := 0 if elapsed < 0.3 else mini(3, int(elapsed - 0.3) + 1)
			if reds != _reds:
				_reds = reds
				_lights.set_state(reds, false)
				_pop(_lights, 1.15)
				Sfx.play(Sfx.beep, -2.0)
			if _countdown <= 0.0:
				_start_race()
		Phase.RACING:
			race_time += delta
			if replay:
				replay.record(race_time)
				replay.update(race_time)
			_check_laps()
			if _shower_at > 0.0 and _standings()[0].progress >= _shower_at:
				_shower_at = -1.0
				_start_shower()
			if _grace > 0.0 and phase == Phase.RACING and not _results_queued:
				_grace -= delta
				if not _photo:
					_sub_label.text = "RACE ENDS IN %d" % ceili(_grace)
				if _grace <= 0.0:
					_show_results()

	var order := _standings()
	_update_catch_up(order)
	var places: Array[int] = [1, 2, 3, 4]
	for car in cars:
		var held := _is_held(car.index) and phase != Phase.RESULTS
		pads.set_lit(car.index, held)
		car.tick(delta, held)
		places[car.index] = order.find(car) + 1
	pads.set_places(places)
	_call_overtakes(places)
	if world.train and world.train.state == world.train.State.PASSING:
		_check_train_hits()
	if world.powerups and phase == Phase.RACING:
		# Lap 1 is a clean race: the boxes appear once the leader starts lap 2.
		if not world.powerups.active and order[0].progress >= world.track.length:
			world.powerups.activate()
			Sfx.play(Sfx.pickup, -8.0, 0.8)
		world.powerups.update_cars(places)
	if phase == Phase.RACING:
		if coach:
			coach.update(delta)
		if trial:
			trial.update(delta)
		for car in cars:
			if cars.size() > 1 and _laps_done(car) >= 1 and places[car.index] == cars.size():
				_was_last[car.index] = true
	if _shower_t >= 0.0:
		_update_shower(delta)
	if world.weather == "rain":
		for car in cars:
			if car.state == Car.State.RACING and car.speed > 350.0 and randf() < delta * 14.0 * world.rain_amount:
				var rear: Vector2 = car.position - Vector2.from_angle(car.rotation) * 22.0
				world.effects.puff(rear, Color(0.8, 0.86, 0.95, 0.3), randf_range(5, 9), Vector2.from_angle(randf() * TAU) * 30.0, 0.5)
	world.effects.leader = order[0] if (phase == Phase.RACING or phase == Phase.RESULTS) and cars.size() > 1 else null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()
	# Phone sent to the background (or browser tab hidden): pause the race.
	elif what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and (OS.has_feature("mobile") or OS.has_feature("web"))):
		if not _paused and phase != Phase.RESULTS and is_node_ready():
			_toggle_pause()


func _is_held(i: int) -> bool:
	var car = cars[i]
	if Game.debug_coast and world.track.has_jump() and world.track.dist_to_lip(car.progress) < 130.0 and car.speed > 380.0:
		return false
	if Game.debug_bots:
		if car.bot_wants_nitro() and not _train_ahead(car):
			car.fire_nitro()
		if world.train and not Game.debug_reckless and _cpu_waits_for_train(car):
			return false
		return Game.debug_reckless or car.bot_throttle()
	if Game.debug_autopilot and i == 0:
		if world.train and _cpu_waits_for_train(car):
			return false
		if car.bot_wants_nitro() and not _train_ahead(car):
			car.fire_nitro()
		return car.bot_throttle(0.95)
	if Game.is_cpu(i):
		if phase != Phase.RACING:
			return false
		if world.train and _cpu_waits_for_train(car):
			return false
		# Easy CPUs fire nitro as soon as it's ready; the others wait for a straight.
		if car.nitro_armed and (Game.cpu_level == 0 or car.bot_wants_nitro()) and not _train_ahead(car):
			car.fire_nitro()
		return car.bot_throttle(Game.CPU_SKILL[Game.cpu_level], Game.CPU_TOP[Game.cpu_level])
	return Input.is_action_pressed(Game.action_name(i)) or pads.is_held(i)


## Catch-up help: cars further back fill their nitro faster (up to ~2x for last place).
func _update_catch_up(order: Array) -> void:
	var n := order.size()
	if n < 2:
		return
	var lead: float = order[0].progress
	for place in n:
		var car = order[place]
		var behind := float(place) / (n - 1)
		var gap := clampf((lead - car.progress) / world.track.length, 0.0, 1.0)
		car.nitro_fill_mult = 1.0 + 0.7 * behind + 0.6 * gap


## Camera glides along the second half of the lap to the grid, then zooms out.
func _update_intro(f: float) -> void:
	var L: float = world.track.length
	var e := 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 2.0) # ease out
	var p: Vector2 = world.track.point_at(L * (0.45 + 0.55 * e) - 30.0, 0.0)
	world.view_at(p, INTRO_ZOOM, smoothstep(0.6, 1.0, f))


func _intro_skip() -> bool:
	if _intro_t < 0.3:
		return false
	for i in mini(Game.num_players, cars.size()):
		if Input.is_action_pressed(Game.action_name(i)) or pads.is_held(i):
			return true
	return false


func _end_intro() -> void:
	world.end_view()
	phase = Phase.COUNTDOWN
	create_tween().tween_property(_lights, "modulate:a", 1.0, 0.2)


func _start_race() -> void:
	phase = Phase.RACING
	if world.train:
		world.train.set_process(true)
	Game.buzz(40, 0.5) # GO!
	for car in cars:
		car.state = Car.State.RACING
	world.effects.show_tags = false
	var cpus := cars.filter(func(c): return Game.is_cpu(c.index))
	if not cpus.is_empty():
		_cpu_says(cpus[randi() % cpus.size()], "start", 1.0)
	_lights.set_state(3, true)
	_pop(_lights, 1.2)
	Sfx.play(Sfx.go, -1.0)
	Sfx.play(Sfx.cheer, -6.0)
	Sfx.set_music_pitch(1.0)
	Sfx.play_music("race%d" % (maxi(Game.current_map, 0) % Sfx.RACE_THEMES.size()))
	_flash("GO!", 0.5, Color(0.3, 1.0, 0.5))
	_sub_label.text = ""
	if coach:
		coach.on_start()
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_property(_lights, "modulate:a", 0.0, 0.3)


func _check_laps() -> void:
	var total := Game.race_laps() * world.track.length
	for car in cars:
		var i: int = car.index
		var done := _laps_done(car)
		if done > _laps_seen[i]:
			_laps_seen[i] = done
			if Game.debug_bots or Game.debug_log:
				print("P%d lap %d at %.2fs (crashes %d, fps %d)" % [i + 1, done, race_time, car.crashes, Engine.get_frames_per_second()])
			_on_lap_done(car, done)
			if done == Game.race_laps() - 1 and not _final_lap_called and Game.race_laps() > 1 and not trial:
				_final_lap_called = true
				_flash("FINAL LAP!", 0.9, Color(1.0, 0.85, 0.2))
				_music_pitch = 1.08
				Sfx.set_music_pitch(_music_pitch)
				Sfx.play(Sfx.cheer, -3.0)
			if car.state == Car.State.RACING and done < Game.race_laps():
				if done == Game.race_laps() - 1:
					pads.toast(i, "FINAL LAP!", Color(1.0, 0.85, 0.2))
				else:
					pads.toast(i, "LAP %d" % (done + 1))
				Sfx.play(Sfx.lap, -6.0)
		if car.state == Car.State.RACING and car.progress >= total:
			car.state = Car.State.FINISHED
			car.finish_time = race_time
			finish_order.append(car)
			var place := finish_order.size()
			pads.toast(i, "%s PLACE!" % PlayerPads.ordinal(place), PlayerPads.MEDALS[place - 1])
			if place == 1:
				_grace = FINISH_GRACE
				Sfx.play(Sfx.cheer, -2.0)
				if _is_close_finish(car, total):
					_start_photo_finish(car)
				else:
					_announce_winner(car)
			else:
				Sfx.play(Sfx.lap, -4.0)
				if place == 2 and _photo:
					_photo_second_crossed(car)
	if finish_order.size() == cars.size():
		if not _photo:
			_sub_label.text = ""
		_queue_results()


var _results_queued := false


## Everyone has finished: let the photo finish / winner moment play, then show results.
func _queue_results() -> void:
	if _results_queued:
		return
	_results_queued = true
	while _photo:
		await get_tree().process_frame
	await get_tree().create_timer(1.6, true, false, true).timeout
	_show_results()


func _announce_winner(car) -> void:
	var i: int = car.index
	var who: String = Game.PLAYER_NAMES[i] if Game.is_cpu(i) else "P%d" % (i + 1)
	_flash("%s WINS!" % who, 1.4, car.color)
	world.effects.celebrate(car)
	_cpu_says(car, "win")
	if Game.debug_shot_on == "win":
		Game.debug_capture(1.0)
	Sfx.play(Sfx.fanfare)
	_confetti.burst([car.color, Color.WHITE, Color(1.0, 0.85, 0.2)], 90)
	Game.buzz_for(i, 260, 0.8)


# --- Commentary ---------------------------------------------------------------

func _call_overtakes(places: Array[int]) -> void:
	for car in cars:
		var i: int = car.index
		var place := places[i]
		var prev := _prev_places[i]
		_prev_places[i] = place
		if phase != Phase.RACING or race_time < 2.5 or prev == 0 or place >= prev:
			continue
		if car.state != Car.State.RACING or race_time - _last_callout[i] < 2.0:
			continue
		_last_callout[i] = race_time
		if place == 1:
			pads.toast(i, "TOOK THE LEAD!", Color(1.0, 0.85, 0.2))
			if _laps_done(car) == Game.race_laps() - 1:
				_note(75, car, "LAST-LAP LEAD CHANGE!")
			_crowd()
			_cpu_says(car, "lead", 0.7)
		else:
			pads.toast(i, "OVERTAKE!", Color(0.5, 1.0, 0.6))
			_cpu_says(car, "overtake", 0.4)


func _on_lap_done(car, done: int) -> void:
	var i: int = car.index
	var lap_time := race_time - _lap_start[i]
	_lap_start[i] = race_time
	# CPUs always drive clean, so this one is for humans only.
	if car.lap_clean and not Game.is_cpu(i) and not Game.debug_bots:
		pads.toast(i, "PERFECT LAP!", Color(0.5, 0.9, 1.0), "+NITRO")
		car.add_nitro(0.35)
		_perfect[i] += 1
	_best[i] = minf(_best[i], lap_time)
	car.lap_clean = true
	if trial:
		trial.on_lap(lap_time, done)
	if lap_time < _best_lap:
		# The first lap only sets the benchmark (it starts from a standstill).
		if done >= 2:
			pads.toast(i, "FASTEST LAP!", Color(0.85, 0.55, 1.0), "%.2fs" % lap_time)
		_best_lap = lap_time
	# The crowd in the grandstand by the line cheers as cars go past.
	if race_time - _last_cheer > 1.2:
		_last_cheer = race_time
		Sfx.play(Sfx.cheer, -12.0, randf_range(0.9, 1.1))


func _on_near_miss(car) -> void:
	if phase != Phase.RACING:
		return
	pads.toast(car.index, "CLOSE CALL!", Color(1.0, 0.6, 0.2), "+NITRO")
	_close[car.index] += 1
	car.add_nitro(0.25)
	Sfx.play(Sfx.lap, -10.0, 0.8)


# --- Photo finish ---------------------------------------------------------------

## True when another car will cross the line within about a third of a second.
func _is_close_finish(winner, total: float) -> bool:
	for other in cars:
		if other == winner or other.state != Car.State.RACING:
			continue
		if total - other.progress < maxf(other.speed, 200.0) * 0.35:
			return true
	return false


var _had_photo_finish := false


func _start_photo_finish(winner) -> void:
	_photo = true
	_had_photo_finish = true
	_photo_winner = winner
	Engine.time_scale = 0.22
	Sfx.set_music_pitch(0.55)
	_camera_flash()
	_big_label.text = "PHOTO FINISH!"
	_big_label.modulate = Color(1, 1, 1, 1)
	_big_label.scale = Vector2.ONE
	await get_tree().create_timer(1.6, true, false, true).timeout
	_end_photo_finish()


func _photo_second_crossed(second) -> void:
	_camera_flash()
	var gap: float = second.finish_time - _photo_winner.finish_time
	_sub_label.text = "%s WINS BY %.2fs!" % [Game.racer_name(_photo_winner.index), maxf(gap, 0.01)]


func _end_photo_finish() -> void:
	if not _photo:
		return
	_photo = false
	Engine.time_scale = 1.0
	Sfx.set_music_pitch(_music_pitch)
	_announce_winner(_photo_winner)


func _camera_flash() -> void:
	_flash_rect.color = Color(1, 1, 1, 0.85)
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_flash_rect, "color:a", 0.0, 0.35)
	Sfx.play(Sfx.beep, -4.0, 2.0)


# --- Power-ups ------------------------------------------------------------------

func _on_pickup(car, item: String) -> void:
	var i: int = car.index
	if coach:
		coach.on_pickup()
	Sfx.play(Sfx.pickup, -4.0)
	Game.buzz_for(i, 20, 0.3)
	if Game.debug_log:
		print("ITEM %.1f %s %s" % [race_time, _short_name(i), item])
	if Game.debug_shot_on == item and race_time > 3.0:
		Game.debug_capture({"lightning": 0.12, "mine": 0.9}.get(item, 0.1))
	match item:
		"shield":
			car.shield = true
			pads.toast(i, "SHIELD!", Color(0.45, 0.9, 1.0), "blocks a crash or rocket")
		"rocket":
			var target = world.powerups.fire_rocket(car)
			if Game.debug_log or Game.debug_bots:
				print("FIRE %.2f %s -> %s" % [race_time, _short_name(i), _short_name(target.index) if target else "none"])
			if target != null and Game.debug_shot_on == "rocket" and race_time > 4.0:
				Game.debug_capture(0.06)
			if target != null:
				pads.toast(i, "ROCKET!", Color(1.0, 0.55, 0.2), "fired at " + _short_name(target.index))
				pads.toast(target.index, "ROCKET INCOMING!", Color(1.0, 0.35, 0.3), "shield blocks it!" if target.shield else "")
				Sfx.play(Sfx.boost, -4.0, 1.6)
		"mega":
			car.add_nitro(1.0)
			car.mega = true
			pads.toast(i, "MEGA NITRO!", Car.NITRO_COLOR, "" if Game.is_cpu(i) else "DOUBLE-TAP!")
		"lightning":
			var zapped := 0
			var first_zapped = null
			for c in world.powerups.cars_ahead(car):
				world.effects.bolt(c)
				if replay:
					replay.fx(race_time, "bolt", c)
				if c.zap():
					if first_zapped == null:
						first_zapped = c
					zapped += 1
					_cpu_says(c, "hit", 0.5)
					pads.toast(c.index, "ZAPPED!", Color(1.0, 0.9, 0.3), "by " + _short_name(i))
					Game.buzz_for(c.index, 90, 0.7)
			pads.toast(i, "LIGHTNING!", Color(1.0, 0.9, 0.3), "zapped %d car%s" % [zapped, "" if zapped == 1 else "s"])
			if zapped >= 2:
				_note(60, first_zapped, "LIGHTNING!")
			_flash_rect.color = Color(1, 1, 0.85, 0.35)
			create_tween().tween_property(_flash_rect, "color:a", 0.0, 0.3)
			Sfx.play(Sfx.crash, -4.0, 1.7)
			world.shake = maxf(world.shake, 0.2)
		"mine":
			world.powerups.drop_mines(car)
			pads.toast(i, "MINES DROPPED!", Color(1.0, 0.45, 0.3), "behind you")
			Sfx.play(Sfx.beep, -6.0, 0.7)



func _on_mine_hit(target, owner) -> void:
	if Game.debug_perf:
		print("MINEHIT at %.2fs" % (Time.get_ticks_msec() / 1000.0))
	Sfx.play(Sfx.crash, -2.0, 0.9)
	world.shake = maxf(world.shake, 0.3)
	if target.rocket_hit():
		_cpu_says(target, "hit", 0.8)
		_crowd(true)
		Game.buzz_for(target.index, 150, 1.0)
		pads.toast(target.index, "MINE!", Color(1.0, 0.45, 0.2), "dropped by " + _short_name(owner.index))
		_note(65, target, "MINE!")
		pads.toast(owner.index, "MINE HIT!", Color(1.0, 0.85, 0.2), _short_name(target.index) + " went boom")
		_rocket_hits[owner.index] += 1
	else:
		pads.toast(owner.index, "BLOCKED!", Color(0.45, 0.9, 1.0), _short_name(target.index) + " had a shield")


func _on_rocket_hit(target, shooter) -> void:
	if Game.debug_perf:
		print("ROCKETHIT at %.2fs" % (Time.get_ticks_msec() / 1000.0))
	if Game.debug_log or Game.debug_bots:
		print("ROCKET %s -> %s  shield=%s" % [_short_name(shooter.index), _short_name(target.index), target.shield])
	Sfx.play(Sfx.crash, -2.0, 0.8)
	world.shake = maxf(world.shake, 0.3)
	if target.rocket_hit():
		_cpu_says(target, "hit", 0.8)
		_crowd(true)
		Game.buzz_for(target.index, 150, 1.0)
		pads.toast(target.index, "BOOM!", Color(1.0, 0.45, 0.2), "hit by " + _short_name(shooter.index))
		_note(85 if _standings()[0] == target else 70, target, "ROCKET HIT!")
		pads.toast(shooter.index, "DIRECT HIT!", Color(1.0, 0.85, 0.2))
		_rocket_hits[shooter.index] += 1
	else:
		pads.toast(shooter.index, "BLOCKED!", Color(0.45, 0.9, 1.0), _short_name(target.index) + " had a shield")


func _short_name(i: int) -> String:
	return Game.short_name(i)


func _on_shield_used(car) -> void:
	if not Game.is_cpu(car.index) and not Game.debug_bots:
		Profile.unlock("shielded")
	pads.toast(car.index, "SHIELD SAVED YOU!", Color(0.45, 0.9, 1.0))
	Sfx.play(Sfx.beep, -4.0, 1.5)


var _last_said := -10.0
var _music_pitch := 1.0
var _final_lap_called := false
var _last_roar := -10.0


## Crowd reaction from the grandstand; `ooh` is the low "ooooh" for big knockouts.
func _crowd(ooh := false) -> void:
	if race_time - _last_roar < 1.5:
		return
	_last_roar = race_time
	if ooh:
		Sfx.play(Sfx.cheer, -7.0, 0.72)
	else:
		Sfx.play(Sfx.cheer, -6.0, randf_range(1.0, 1.1))
var _said_at: Array[float] = [-10.0, -10.0, -10.0, -10.0]


## A CPU driver says a line for `moment` in a speech bubble (rate-limited so the
## screen never fills up with chatter).
func _cpu_says(car, moment: String, chance := 0.6) -> void:
	var i: int = car.index
	if not Game.is_cpu(i) or Game.debug_bots or coach or trial:
		return
	var urgent := moment == "win"
	if not urgent and (race_time - _last_said < 2.5 or race_time - _said_at[i] < 7.0 or randf() > chance):
		return
	var text: String = Game.Drivers.line(Game.driver(i), moment)
	if text == "":
		return
	_last_said = race_time
	_said_at[i] = race_time
	world.effects.say(car, text)


func _on_jumped(car, big: bool) -> void:
	if Game.debug_log:
		print("JUMP %.2f %s speed %d" % [race_time, _short_name(car.index), int(car.speed)])
	if Game.debug_shot_on == "jump" and race_time > 2.0:
		Game.debug_capture(0.13)
	Sfx.play(Sfx.boost, -8.0, 0.8)
	if big:
		pads.toast(car.index, "BIG AIR!", Color(0.5, 0.9, 1.0))
		_crowd()
		_note(55, car, "BIG AIR!")
	_cpu_says(car, "jump", 0.25)


func _on_landed(car) -> void:
	_fx("land", car)
	Sfx.play(Sfx.crash, -16.0, 1.9)
	world.effects.land_dust(car.position)
	world.shake = maxf(world.shake, 0.06)
	Game.buzz_for(car.index, 45, 0.55)


func _on_splashed(car) -> void:
	if Game.debug_log:
		print("SPLASH %.2f %s" % [race_time, _short_name(car.index)])
	if Game.debug_shot_on == "splash":
		Game.debug_capture(0.25)
	world.effects.splash(car.position)
	_fx("splash", car)
	_note(60, car, "SPLASH!")
	Sfx.play(Sfx.crash, -4.0, 0.55)
	Sfx.play(Sfx.boost, -8.0, 0.5) # whoosh of water
	pads.toast(car.index, "SPLASH!", Color(0.45, 0.8, 1.0), "too slow for the jump")
	_crowd(true)
	_cpu_says(car, "splash", 0.8)
	Game.buzz_for(car.index, 180, 1.0)


func _on_crash(car) -> void:
	if Game.debug_perf:
		print("CRASH at %.2fs" % (Time.get_ticks_msec() / 1000.0))
	_cpu_says(car, "crash", 0.5)
	_fx("crash", car)
	if coach:
		coach.on_crash()
	world.shake = 0.28
	pads.toast(car.index, "CRASH!", Color(1.0, 0.35, 0.3))
	Sfx.play(Sfx.crash, -3.0, randf_range(0.9, 1.1))
	Game.buzz_for(car.index, 130, 1.0)


func _on_boost(car) -> void:
	_nitros[car.index] += 1
	_fx("nitro", car)
	if coach:
		coach.on_boost()
	if Game.debug_bots:
		print("P%d nitro at %.2fs" % [car.index + 1, race_time])
	Sfx.play(Sfx.boost, -2.0)
	pads.toast(car.index, "NITRO!", Car.NITRO_COLOR)
	world.effects.shockwave(car.position, Car.NITRO_COLOR)
	world.shake = maxf(world.shake, 0.12)
	Game.buzz_for(car.index, 60, 0.6)


func _on_nitro_ready(car) -> void:
	pads.toast(car.index, "NITRO READY!", Car.NITRO_COLOR, "" if Game.is_cpu(car.index) else "DOUBLE-TAP!")
	Sfx.play(Sfx.lap, -8.0, 1.5)
	Game.buzz_for(car.index, 25, 0.35) # light tap: nitro is ready


func _laps_done(car) -> int:
	return clampi(floori(car.progress / world.track.length), 0, Game.race_laps())


func _standings() -> Array:
	var rest := cars.filter(func(c): return not finish_order.has(c))
	rest.sort_custom(func(a, b): return a.progress > b.progress)
	return finish_order + rest


func _flash(text: String, time: float, color := Color.WHITE) -> void:
	_big_label.text = text
	_big_label.modulate = color
	_big_label.scale = Vector2(1.7, 1.7)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_big_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_interval(time)
	_flash_tween.tween_property(_big_label, "modulate:a", 0.0, 0.3)


func _pop(node: Control, amount: float) -> void:
	node.scale = Vector2(amount, amount)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.make_theme()
	layer.add_child(root)
	Game.fit_to_safe(root) # buttons and text stay clear of notches and camera holes
	root_ui = root

	pads = PlayerPads.new()
	pads.num_players = cars.size()
	pads.humans = mini(Game.num_players, cars.size()) if not Game.debug_bots else 0
	pads.laps = Game.race_laps()
	pads.king = Game.king() if not Game.is_career() else -1
	pads.king_wins = Game.streak_wins
	pads.cars = cars
	pads.track_length = world.track.length
	pads.pause_pressed.connect(_toggle_pause)
	pads.layout_changed.connect(_fit_world)
	root.add_child(pads)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var lights_row := CenterContainer.new()
	lights_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lights_row)
	_lights = StartLights.new()
	lights_row.add_child(_lights)
	_big_label = _make_label(92, 16)
	_big_label.custom_minimum_size = Vector2(700, 150)
	_big_label.pivot_offset = _big_label.custom_minimum_size * 0.5
	_big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_big_label)
	_sub_label = _make_label(34, 10)
	box.add_child(_sub_label)
	# Big call-outs (GO!, FINAL LAP!, ...) rasterize while loading, not mid-race.
	var label_font := _big_label.get_theme_font("font")
	root_ui.add_child(FontWarmer.new([[label_font, 92, 16], [label_font, 34, 10]]))

	_results = _make_overlay(root)
	_results_box = _results.get_child(0).get_child(0).get_child(0)
	_pause_menu = _make_overlay(root)
	var pbox: VBoxContainer = _pause_menu.get_child(0).get_child(0).get_child(0)
	pbox.add_child(_make_label(54, 8, "PAUSED"))
	pbox.add_child(_make_button("RESUME", _toggle_pause, true))
	pbox.add_child(_make_button("QUIT TO MENU", _go_menu))

	_confetti = Confetti.new()
	root.add_child(_confetti)
	Game.bleed(_confetti)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_rect)
	Game.bleed(_flash_rect)


func _make_label(font_size: int, outline: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A reward/info line that wraps inside the results panel instead of stretching it.
func _wrap_label(text: String) -> Label:
	var l := _make_label(19, 6, text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.max_lines_visible = 3
	return l


func _make_button(text: String, fn: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 88)
	b.focus_mode = Control.FOCUS_NONE # player keys must never trigger menu buttons
	if accent:
		b.add_theme_stylebox_override("normal", Game.make_style(Game.ACCENT, 18))
		b.add_theme_stylebox_override("hover", Game.make_style(Game.ACCENT.lightened(0.12), 18))
		b.add_theme_stylebox_override("pressed", Game.make_style(Game.ACCENT.darkened(0.15), 18))
	b.pressed.connect(fn)
	return b


func _make_overlay(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)
	Game.bleed(overlay) # dim the whole screen...
	var center := CenterContainer.new()
	overlay.add_child(center)
	Game.fit_to_safe(center) # ...but keep the panel in the safe area
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Game.make_style(Color(0.08, 0.09, 0.13, 0.97), 28, Color(0.02, 0.03, 0.05), 6))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return overlay


func _toggle_pause() -> void:
	if phase == Phase.RESULTS:
		return
	_paused = not _paused
	_pause_menu.visible = _paused
	pads.release_all()
	pads.set_process_input(not _paused)
	world.effects.set_process(not _paused)
	for car in cars:
		if car.engine:
			car.engine.stream_paused = _paused


func _show_results() -> void:
	if phase == Phase.RESULTS:
		return
	phase = Phase.RESULTS
	_end_photo_finish()
	pads.release_all()
	pads.visible = false
	_big_label.text = ""
	_sub_label.text = ""
	if _want_replay():
		await _play_replay()

	if coach:
		_show_solo_results(true)
		return
	if trial:
		_show_solo_results(false)
		return
	var order := _standings()
	var winner = order[0]
	var order_idx: Array[int] = []
	for car in order:
		order_idx.append(car.index)
	var cup := Game.is_championship()
	var given: Array[int] = Game.record_race(order_idx)

	var box := _results_box
	var heading: String = world.map.title.to_upper()
	if cup:
		heading = "RACE %d OF %d  •  %s" % [Game.cup_race, Game.races, heading]
	elif Game.is_career():
		heading = "EVENT %d  •  %s" % [Game.career_event + 1, CE.event(Game.career_event).title]
	box.add_child(_make_label(24, 6, heading))
	var title := _make_label(52, 10, "%s WINS!" % Game.racer_name(winner.index))
	title.add_theme_color_override("font_color", winner.color)
	box.add_child(title)
	var rewards := _record_profile(order)
	var streak := _streak_line(winner.index)
	if streak != "":
		rewards = streak + ("  •  " + rewards if rewards != "" else "")
	if rewards != "":
		var r := _wrap_label(rewards)
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		box.add_child(r)
	var career_bits := -1
	if Game.is_career():
		career_bits = _career_result(order)
	for rank in order.size():
		box.add_child(_result_row(rank, order[rank], given[order[rank].index] if cup else -1))

	var next_text := "PLAY AGAIN"
	var next_fn := func(): Game.start_cup(); get_tree().reload_current_scene()
	if cup and not Game.cup_finished():
		next_text = "NEXT RACE (%d/%d)" % [Game.cup_race + 1, Game.races]
		next_fn = func(): get_tree().reload_current_scene()
	elif cup:
		next_text = "SEE THE CHAMPION!"
		next_fn = func(): get_tree().change_scene_to_file("res://scenes/podium.tscn")
	var buttons: Array[Button] = []
	box.add_child(_make_label(8, 0))
	if career_bits >= 0:
		# Career: NEXT EVENT once it's unlocked, RETRY, and back to the ladder.
		var ev := Game.career_event
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var retry := _make_button("RETRY", func():
			Game.start_career(ev)
			get_tree().reload_current_scene(), career_bits & CE.PODIUM == 0)
		row.add_child(retry)
		buttons.append(retry)
		if ev + 1 < CE.count() and Profile.career_unlocked(ev + 1):
			var nxt := _make_button("NEXT EVENT", func():
				Game.start_career(ev + 1)
				get_tree().reload_current_scene(), true)
			row.add_child(nxt)
			buttons.append(nxt)
		for b in row.get_children():
			b.custom_minimum_size.x = 214
		box.add_child(row)
	elif cup:
		var again := _make_button(next_text, next_fn, true)
		box.add_child(again)
		buttons.append(again)
	else:
		# Single race: REMATCH (same track again) or a new random track.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var rematch := _make_button("REMATCH", func():
			Game.retry_map = Game.current_map
			Game.start_cup()
			get_tree().reload_current_scene(), true)
		var fresh := _make_button("NEW TRACK", next_fn)
		for b in [rematch, fresh]:
			b.custom_minimum_size.x = 214
			row.add_child(b)
			buttons.append(b)
		box.add_child(row)
	var menu := _make_button("CAREER" if career_bits >= 0 else "MENU", _go_menu)
	box.add_child(menu)
	buttons.append(menu)
	if Game.is_landscape_layout():
		# Landscape is only 720 tall: tighten the panel so it fits with room to spare.
		box.add_theme_constant_override("separation", 8)
		for b in buttons:
			b.custom_minimum_size.y = 64
	# Short lockout so players still mashing their buttons don't skip the results.
	for b in buttons:
		b.disabled = true
	_results.visible = true
	_pop(_results.get_child(0).get_child(0), 1.1)
	_confetti.burst([winner.color, Color.WHITE, Color(1.0, 0.85, 0.2), Color(0.3, 0.9, 1.0)], 160)
	if (Game.debug_bots or Game.debug_log) and Game.debug_shot == "":
		for car in order:
			print("RESULT %s time %.2f crashes %d points %d" % [Game.racer_name(car.index), car.finish_time, car.crashes, Game.cup_points[car.index]])
		get_tree().quit()
	await get_tree().create_timer(1.2).timeout
	for b in buttons:
		b.disabled = false


## Updates the win streak and pays its coins; returns what to announce.
func _streak_line(winner: int) -> String:
	var r := Game.note_winner(winner)
	if int(r.coins) > 0 and not Game.debug_bots:
		Profile.add_coins(int(r.coins))
		Profile.save()
	var king_before: int = r.king_before
	if r.slain:
		return "%s BEAT THE KING! +%d COINS" % [Game.racer_name(winner), int(r.coins)]
	if int(r.streak) >= 2:
		return "%s IS KING! %d WINS IN A ROW +%d COINS" % [Game.racer_name(winner), int(r.streak), int(r.coins)]
	if king_before >= 0 and king_before != winner:
		return "%s'S STREAK IS OVER" % Game.racer_name(king_before)
	return ""


## Saves stats / records / coins for the human players; returns a one-line summary.
func _record_profile(order: Array) -> String:
	if Game.debug_bots:
		return ""
	var margin := 99.0
	if finish_order.size() >= 2:
		margin = finish_order[1].finish_time - finish_order[0].finish_time
	var race := {"map": world.map.title, "cpus": Game.num_cpus, "cpu_level": Game.cpu_level, "margin": margin,
		"weather": _weather, "laps": Game.race_laps(), "cars": []}
	for rank in order.size():
		var car = order[rank]
		var i: int = car.index
		race.cars.append({
			"index": i, "human": not Game.is_cpu(i), "name": Game.racer_name(i), "place": rank + 1,
			"crashes": car.crashes, "perfect_laps": _perfect[i], "nitros": _nitros[i],
			"close_calls": _close[i], "best_lap": _best[i], "rocket_hits": _rocket_hits[i],
			"was_last": _was_last[i], "photo": rank == 0 and _had_photo_finish,
		})
	var result := Profile.record_race(race)
	var parts: Array[String] = []
	if int(result.coins) > 0:
		parts.append("+%d COINS" % int(result.coins))
	if not result.record.is_empty():
		parts.append("NEW TRACK RECORD %.2fs (%s)" % [float(result.record.time), result.record.who])
	if result.daily:
		parts.append("DAILY CHALLENGE DONE!")
	var awards := Profile.take_recent_achievements()
	if not awards.is_empty():
		parts.append(("NEW AWARD: " if awards.size() == 1 else "NEW AWARDS: ") + ", ".join(awards))
	if not parts.is_empty():
		Sfx.play(Sfx.lap, -4.0, 1.2)
	return "  •  ".join(parts)


## Career: works out P1's stars, saves them and adds the star row to the results.
## Returns the stars earned this race (bitmask).
func _career_result(order: Array) -> int:
	var ev := Game.career_event
	var car = cars[0]
	var margin := 99.0
	if finish_order.size() >= 2:
		margin = finish_order[1].finish_time - finish_order[0].finish_time
	var stats := {"place": order.find(car) + 1, "crashes": car.crashes, "nitros": _nitros[0],
		"close_calls": _close[0], "perfect_laps": _perfect[0], "rocket_hits": _rocket_hits[0], "margin": margin}
	var bits := CE.stars_for(ev, stats)
	var result := Profile.record_career(ev, bits) if not Game.debug_bots else {"new": 0, "coins": 0}
	if Game.debug_log:
		print("CAREER event %d stats %s stars %d new %d" % [ev + 1, str(stats), bits, int(result.new)])
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	h.add_child(StarRow.new(bits, 40, int(result.new)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var lines := [["PODIUM", CE.PODIUM], ["WIN", CE.WIN], ["GOAL: " + CE.goal_text(ev), CE.GOAL]]
	for pair in lines:
		var got: bool = bits & int(pair[1]) != 0
		var l := _make_label(17, 4, pair[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if got else Color(1, 1, 1, 0.45))
		v.add_child(l)
	h.add_child(v)
	_results_box.add_child(h)
	var msg := ""
	if int(result.coins) > 0:
		msg = "+%d COINS FOR NEW STARS" % int(result.coins)
	if bits & CE.PODIUM and ev + 1 < CE.count() and int(result.new) & CE.PODIUM:
		msg += ("  •  " if msg != "" else "") + "EVENT %d UNLOCKED!" % (ev + 2)
	elif bits & CE.PODIUM == 0:
		msg = "Finish on the podium to unlock the next event"
	if msg != "":
		var m := _wrap_label(msg)
		m.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if bits & CE.PODIUM else Color(1, 0.6, 0.5))
		_results_box.add_child(m)
	var awards := Profile.take_recent_achievements()
	if not awards.is_empty():
		var a := _wrap_label(("NEW AWARD: " if awards.size() == 1 else "NEW AWARDS: ") + ", ".join(awards))
		a.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_results_box.add_child(a)
	return bits


## Results for the tutorial and the time trial (just P1).
func _show_solo_results(is_tutorial: bool) -> void:
	var car = cars[0]
	var box := _results_box
	var retry_fn: Callable
	var next_text: String
	var next_fn: Callable
	if is_tutorial:
		coach.hide_card()
		box.add_child(_make_label(24, 6, "TUTORIAL"))
		var t := _make_label(52, 10, "TUTORIAL COMPLETE!")
		t.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		box.add_child(t)
		var coins := Profile.complete_tutorial()
		box.add_child(_make_label(22, 6, "Hold to go  •  Let go before corners\nDouble-tap for NITRO  •  Grab the ? boxes"))
		if coins > 0:
			var r := _make_label(22, 6, "+%d COINS" % coins)
			r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			box.add_child(r)
		next_text = "LET'S RACE!"
		next_fn = func(): Game.tutorial = false; _go_menu()
		retry_fn = func(): get_tree().reload_current_scene()
	else:
		box.add_child(_make_label(24, 6, "TIME TRIAL  •  " + world.map.title.to_upper()))
		var best: float = trial.best_lap()
		var ghost_before: float = trial.ghost_time()
		var title := _make_label(52, 10, "BEST LAP %.2fs" % best)
		title.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
		box.add_child(title)
		var laps_text := ""
		for k in trial.lap_times.size():
			laps_text += ("   " if k > 0 else "") + "L%d %.2f" % [k + 1, trial.lap_times[k]]
		box.add_child(_make_label(20, 4, laps_text))
		var result := trial.save_result(Game.racer_name(0)) if not Game.debug_bots else {"coins": 0, "record": false}
		var parts: Array[String] = ["+%d COINS" % int(result.coins)]
		if result.record:
			parts.append("NEW PERSONAL BEST! (was %.2fs)" % ghost_before)
		elif ghost_before < INF:
			parts.append("Ghost to beat: %.2fs" % minf(ghost_before, best))
		var awards := Profile.take_recent_achievements()
		if not awards.is_empty():
			parts.append(("NEW AWARD: " if awards.size() == 1 else "NEW AWARDS: ") + ", ".join(awards))
		var r := _wrap_label("  •  ".join(parts))
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		box.add_child(r)
		next_text = "RETRY THIS TRACK"
		next_fn = func(): Game.retry_map = Game.current_map; get_tree().reload_current_scene()
		retry_fn = func(): get_tree().reload_current_scene()
	var again := _make_button(next_text, next_fn, true)
	var other := _make_button("TRY AGAIN" if is_tutorial else "NEW TRACK", retry_fn)
	var menu := _make_button("MENU", func(): Game.tutorial = false; _go_menu())
	box.add_child(_make_label(6, 0))
	for b in [again, other, menu]:
		box.add_child(b)
		b.disabled = true
		if Game.is_landscape_layout():
			b.custom_minimum_size.y = 62
	_results.visible = true
	_pop(_results.get_child(0).get_child(0), 1.1)
	_confetti.burst([car.color, Color.WHITE, Color(1.0, 0.85, 0.2)], 120)
	if (Game.debug_bots or Game.debug_log) and Game.debug_shot == "":
		print("SOLO RESULT best %.2f laps %s" % [trial.best_lap() if trial else -1.0, str(trial.lap_times) if trial else ""])
		get_tree().quit()
	await get_tree().create_timer(1.2).timeout
	for b in [again, other, menu]:
		b.disabled = false


## One results row. `points` >= 0 adds the championship columns (+points, total).
func _result_row(rank: int, car, points := -1) -> Control:
	var row := PanelContainer.new()
	var style := Game.make_style(Color(car.color, 0.16), 14, Color(car.color, 0.9) if rank == 0 else Color(0, 0, 0, 0), 3)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)

	var badge := PanelContainer.new()
	var bstyle := Game.make_style(PlayerPads.MEDALS[rank], 10, Color(0.02, 0.03, 0.05), 3)
	bstyle.content_margin_left = 8
	bstyle.content_margin_right = 8
	bstyle.content_margin_top = 2
	bstyle.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", bstyle)
	var place := _make_label(24, 0, PlayerPads.ordinal(rank + 1))
	place.custom_minimum_size = Vector2(58, 0)
	place.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	badge.add_child(place)
	h.add_child(badge)

	var name_l := _make_label(26, 6, Game.racer_name(car.index))
	name_l.custom_minimum_size = Vector2(190, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.add_theme_color_override("font_color", car.color)
	h.add_child(name_l)
	var time_l := _make_label(26, 6, "%.2fs" % car.finish_time if car.finish_time >= 0.0 else "DNF")
	time_l.custom_minimum_size = Vector2(100, 0)
	h.add_child(time_l)
	if points >= 0:
		var plus := _make_label(24, 6, "+%d" % points)
		plus.custom_minimum_size = Vector2(52, 0)
		plus.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		h.add_child(plus)
		var total := _make_label(20, 4, "%d pts" % Game.cup_points[car.index])
		total.custom_minimum_size = Vector2(70, 0)
		h.add_child(total)
	else:
		var crash_l := _make_label(18, 4, "%d crash%s" % [car.crashes, "" if car.crashes == 1 else "es"])
		crash_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		crash_l.custom_minimum_size = Vector2(100, 0)
		h.add_child(crash_l)
	return row


func _go_menu() -> void:
	if Game.is_career():
		get_tree().change_scene_to_file("res://scenes/career.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
