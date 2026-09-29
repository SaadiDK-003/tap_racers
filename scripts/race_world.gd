extends Node2D
## The playfield: track, skid marks, cars and effects, scaled to fit a screen area.
## Used by the race and by the menu's background demo.

const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const Effects = preload("res://scripts/effects.gd")
const Train = preload("res://scripts/train.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")
const Powerups = preload("res://scripts/powerups.gd")

var map
var track: Track
var effects: Effects
var powerups: Powerups # null when items are off
var weather := "clear" # clear, rain or night
var cars: Array = []
var shake := 0.0 # seconds of screen shake left
var hold_view := false # the race is moving the camera itself (intro sweep)
var fit_scale := 1.0
var _fit_center := Vector2.ZERO
var _bake_area := Rect2()
var _bake_k := 1.0
var random_styles := false # menu demo: every car gets a random look

var _base_pos := Vector2.ZERO


func build(map_def, num_cars: int) -> void:
	map = map_def
	var spacing := minf(46.0, (map.road_width - 36.0) / maxf(num_cars - 1, 1))
	var offsets: Array[float] = []
	for i in num_cars:
		# P1 gets the right-hand lane, P2 the left one (matching their corners).
		offsets.append(((num_cars - 1) * 0.5 - i) * spacing)
	track = Track.new()
	add_child(track)
	track.setup(map, offsets)

	var skids := DrawLayer.new()
	add_child(skids)
	_weather_layer = DrawLayer.new()
	_weather_layer.draw_fn = _draw_weather
	add_child(_weather_layer)
	_lights_layer = DrawLayer.new()
	_lights_layer.draw_fn = _draw_night_lights
	_lights_layer.material = Car.additive()
	add_child(_lights_layer)
	_powerup_slot = Node2D.new()
	add_child(_powerup_slot)
	var car_layer := Node2D.new()
	add_child(car_layer)
	effects = Effects.new()
	effects.skid_layer = skids
	for i in num_cars:
		var car := Car.new()
		car.index = i
		car.color = Game.slot_color(i)
		car.lane_offset = offsets[i]
		car.track = track
		car.effects = effects
		car.scale = Vector2.ONE * clampf(spacing / 36.0, 0.8, 1.0)
		var look: Array = Game.slot_style(i)
		if Game.is_cpu(i) or random_styles:
			var bodies: Array = Profile.BODIES
			var decals: Array = Profile.DECALS
			var trails: Array = Profile.TRAILS
			look = [bodies[randi() % bodies.size()].id, decals[randi() % decals.size()].id, trails[randi() % trails.size()].id]
		car.body = look[0]
		car.decal = look[1]
		car.trail_style = look[2]
		car_layer.add_child(car)
		car.place()
		cars.append(car)
	effects.cars = cars
	if track.has_rail():
		train = Train.new()
		add_child(train) # above the cars
		train.setup(track)
		var sig: Node2D = train.signals_node()
		add_child(sig)
		move_child(sig, car_layer.get_index()) # on the road, below the cars
	effects.z_index = 3 # smoke, tags and the crown above everything, even the bridge
	add_child(effects)


var _weather_layer: Node2D
var _lights_layer: Node2D
var _powerup_slot: Node2D


func enable_powerups() -> void:
	powerups = Powerups.new()
	_powerup_slot.add_child(powerups)
	powerups.setup(track, cars.size())
	powerups.cars = cars


## Lights flashing and the crossing coming up: no nitro (a boosting car can't brake).
func train_ahead(car) -> bool:
	if train == null or not train.active():
		return false
	var ahead: float = -track.dist_from_rail(car.progress)
	return ahead > -track.RAIL_HALF and ahead < 2200.0 # a burst covers ~1800


## Computer drivers (CPUs, the menu demo): stop for the train when the car couldn't
## clear the crossing in time. True = let go (brake) this frame.
func should_wait_for_train(car) -> bool:
	if train == null or not train.active():
		return false
	var ahead: float = -track.dist_from_rail(car.progress) # to the middle of the rails
	var line: float = ahead - track.RAIL_HALF - TRAIN_STOP_GAP # to the stop line
	if line < -TRAIN_STOP_GAP:
		return false # on or past the rails: get clear
	var to_road: float = train.time_to_road()
	var clear_time := (ahead + track.RAIL_HALF + 30.0) / maxf(car.speed, 60.0)
	if to_road > clear_time + 0.5:
		return false # plenty of time to cross first
	var stop_dist: float = car.speed * car.speed / (2.0 * CAR_BRAKING)
	if car.speed > 120.0 and line < stop_dist + 5.0:
		return false # too late to stop cleanly: commit (braking now would stop it on the rails)
	var wait := line < stop_dist + 40.0
	if wait and car.boosting:
		car.cancel_nitro() # a boosting car can't brake
	return wait


## Rain: slippery (less grip) under a grey-blue tint. Night: dark, headlights on,
## street lamps glowing.
const RAIN_GRIP := 0.86
const RAIN_TINT := Color(0.12, 0.16, 0.24, 0.3)
const NIGHT_TINT := Color(0.02, 0.03, 0.09, 0.62)
var train # the level-crossing train (rail tracks only)
const TRAIN_STOP_GAP := 30.0 # computer drivers stop this far before the rails
const CAR_BRAKING := 950.0 # how hard a car slows when you let go (measured ~1000-1100)
var rain_amount := 0.0 # 0..1: how hard it's raining (a shower fades in)


func set_weather(w: String) -> void:
	weather = w
	rain_amount = 1.0 if w == "rain" else 0.0
	for car in cars:
		car.night = w == "night"
	_apply_weather()
	_lights_layer.queue_redraw()


## A shower rolling in mid-race: grip and the grey tint follow the rain's strength.
func set_rain(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if weather == "night" or is_equal_approx(amount, rain_amount):
		return
	rain_amount = amount
	weather = "rain" if amount > 0.0 else "clear"
	_apply_weather()


func _apply_weather() -> void:
	for car in cars:
		car.grip_mult = lerpf(1.0, RAIN_GRIP, rain_amount)
	# The bridge deck is drawn above the overlay, so it gets the same colour painted on.
	var overlay := Color(0, 0, 0, 0)
	if weather == "night":
		overlay = NIGHT_TINT
	elif rain_amount > 0.0:
		overlay = Color(RAIN_TINT, RAIN_TINT.a * rain_amount)
	track.set_deck_overlay(overlay)
	_weather_layer.queue_redraw()


func _draw_weather(ci: CanvasItem) -> void:
	var big := Rect2(-4000, -4000, 9000, 9000)
	if weather == "night":
		ci.draw_rect(big, NIGHT_TINT)
	elif rain_amount > 0.0:
		ci.draw_rect(big, Color(RAIN_TINT, RAIN_TINT.a * rain_amount))


func _draw_night_lights(ci: CanvasItem) -> void:
	if weather != "night":
		return
	for g in track.glow_points():
		var r: float = g[1]
		ci.draw_texture_rect(Car.glow_texture(), Rect2(g[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, g[2])
	for p in track.lamp_points():
		ci.draw_texture_rect(Car.glow_texture(), Rect2(p - Vector2(60, 60), Vector2(120, 120)), false, Color(1.0, 0.85, 0.5, 0.45))
	# Floodlights along the start straight.
	for k in 5:
		var q: Vector2 = track.point_at(-120.0 + k * 60.0, 0.0)
		ci.draw_texture_rect(Car.glow_texture(), Rect2(q - Vector2(90, 90), Vector2(180, 180)), false, Color(0.8, 0.85, 1.0, 0.18))


var _view_key := ""


## Scales and centers the track inside `area` (screen coordinates). Tracks are
## drawn tall, so on a wide (landscape) area the track is turned sideways to fill it.
## `ui_keepouts` are [center, radius] screen circles covered by UI.
func fit(area: Rect2, max_scale := 1.6, ui_keepouts: Array = []) -> void:
	var b: Rect2 = track.bounds()
	var turn := (area.size.x > area.size.y) != (b.size.x > b.size.y)
	var size := Vector2(b.size.y, b.size.x) if turn else b.size
	var s := minf(minf(area.size.x / size.x, area.size.y / size.y), max_scale)
	rotation = -PI * 0.5 if turn else 0.0
	scale = Vector2(s, s)
	fit_scale = s
	_fit_center = area.get_center()
	_base_pos = area.get_center() - Transform2D(rotation, scale, 0.0, Vector2.ZERO) * b.get_center()
	position = _base_pos
	_update_scenery_view(ui_keepouts)


## Tells the scenery which part of the ground is on screen (and not under the UI),
## in track coordinates, so parking lots end up somewhere players can see them.
func _update_scenery_view(ui_keepouts: Array) -> void:
	var screen := get_viewport_rect().size
	var key := "%d,%d,%d,%.3f" % [screen.x, screen.y, ui_keepouts.size(), rotation]
	if key == _view_key:
		return
	_view_key = key
	var inv := Transform2D(rotation, scale, 0.0, _base_pos).affine_inverse()
	var visible := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(screen.x, 0), screen, Vector2(0, screen.y)]:
		visible.append(inv * corner)
	var keepouts := []
	for k in ui_keepouts:
		keepouts.append([inv * (k[0] as Vector2), float(k[1]) / scale.x])
	track.rebuild_scenery({"visible": visible, "keepouts": keepouts})
	# Bake the static layers for exactly the visible area, at the screen's real pixel
	# density (so it's sharp on phones), plus a margin for screen shake.
	var area := Rect2(visible[0], Vector2.ZERO)
	for v in visible:
		area = area.expand(v)
	var window_px := float(get_tree().root.size.x) / maxf(screen.x, 1.0)
	_bake_area = area.grow(40.0 / scale.x)
	_bake_k = clampf(scale.x * window_px, 0.4, 2.5)
	track.bake(_bake_area, _bake_k)


## Camera for the intro: centred on track point `p` at `zoom` x the fitted size,
## blending (0..1) into the normal fitted view.
func view_at(p: Vector2, zoom: float, blend: float) -> void:
	var s := lerpf(fit_scale * zoom, fit_scale, blend)
	var zoomed := _fit_center - Transform2D(rotation, Vector2(s, s), 0.0, Vector2.ZERO) * p
	scale = Vector2(s, s)
	var pos := zoomed.lerp(_base_pos, blend)
	# The zoomed view is the fitted view scaled by z around some screen point A. With
	# A on screen, it never shows ground outside the baked (fitted) area.
	var z := s / fit_scale
	if z > 1.001:
		var a := (pos - _base_pos * z) / (1.0 - z)
		var screen := get_viewport_rect().size
		a = a.clamp(Vector2.ZERO, screen)
		pos = a + (_base_pos - a) * z
	position = pos


func end_view() -> void:
	hold_view = false
	scale = Vector2(fit_scale, fit_scale)
	position = _base_pos


func _process(delta: float) -> void:
	if hold_view:
		return
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		var a := shake * 28.0
		position = _base_pos + Vector2(randf_range(-a, a), randf_range(-a, a))
	else:
		position = _base_pos
