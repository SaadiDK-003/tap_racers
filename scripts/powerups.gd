extends Node2D
## Power-up boxes: a row of "?" boxes across every lane at a few spots on the track.
## Driving through one gives a random item, used automatically (one-button game):
##   SHIELD     - a bubble that blocks the next crash or rocket (lasts 10 s)
##   ROCKET     - homes in on the car ahead (or 2nd place, if you lead) and blows it
##                off the track, unless that car has a shield
##   MEGA NITRO - fills your nitro tank and makes the next burst last longer
##   LIGHTNING  - every car ahead of you is shrunk and slowed for 2 s (rare, mostly for
##                the cars at the back)
##   MINE       - drops a mine in every other lane behind you; a car driving over one
##                is blown off the track
## Shields block rockets, mines and lightning. Cars at the back mostly get rockets,
## lightning and nitro; the leader mostly gets shields and mines.

signal picked(car, item: String)
signal rocket_hit(target, shooter)
signal mine_hit(target, owner)

const Car = preload("res://scripts/car.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

# Items are meant to be an occasional surprise, not constant chaos: two box rows per
# lap, and a car's box only comes back after RESPAWN seconds (about every other lap).
const SPOTS := 2
const RESPAWN := 14.0
const ROCKET_SPEED := 1250.0 # faster than any car, even on nitro
const ROCKET_LIFE := 4.0
const HIT_RANGE := 26.0
const OUTLINE := Color(0.02, 0.03, 0.05)
const ROCKET_SCALE := 1.4

var track
var cars: Array = []
var effects # for smoke trails and explosions
var _spots: Array[Dictionary] = [] # {s, boxes: Array[float] respawn timers per lane (0 = ready)}
var _rockets: Array[Dictionary] = [] # {s, lane, shooter, target, t, dir}
var _prev: Dictionary = {} # car -> progress last frame
var _t := 0.0
var _glow: Node2D
var active := false # boxes are hidden (and can't be picked up) until activate()
var _appear := 0.0 # pop-in animation 0..1
var _roulette: Array[Dictionary] = [] # {car, item, t} item boxes still spinning
var _icons: Node2D # roulette icons, drawn above the cars
const ROULETTE_TIME := 0.75
const ITEMS := ["shield", "rocket", "mega", "lightning", "mine"]
const MINE_LIFE := 15.0
var _mines: Array[Dictionary] = [] # {s, lanes: Array[bool] (live mine per lane), owner, t}


func setup(track_node, lane_count: int) -> void:
	track = track_node
	_glow = DrawLayer.new()
	_glow.material = Car.additive()
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	_icons = DrawLayer.new()
	_icons.draw_fn = _draw_roulette
	_icons.z_index = 4
	add_child(_icons)
	# Three spots spread evenly around the lap, each nudged to the calmest bit of road
	# nearby (never on the bridge or right at the start line).
	var L: float = track.length
	var picked_s: Array[float] = []
	for k in SPOTS:
		var ideal := L * (k + 0.5) / SPOTS
		var best := -1.0
		var best_score := INF
		var dx := -300.0
		while dx <= 300.0:
			var c := fposmod(ideal + dx, L)
			if c > 200.0 and c < L - 200.0 and not track.on_bridge(c) and not track.on_bridge(c + 40.0) and not track.on_bridge(c - 40.0) \
					and not track.in_jump_zone(c) and not track.in_jump_zone(c + 60.0):
				var score := absf(dx) * 0.0005
				for d in [-40.0, 0.0, 40.0]:
					score += absf(track.curvature_at(c + d))
				if score < best_score:
					best_score = score
					best = c
			dx += 20.0
		if best >= 0.0:
			picked_s.append(best)
	for p in picked_s:
		var boxes: Array[float] = []
		for i in lane_count:
			boxes.append(0.0)
		_spots.append({"s": p, "boxes": boxes})


func _process(delta: float) -> void:
	_t += delta
	for spot in _spots:
		var boxes: Array[float] = spot.boxes
		for i in boxes.size():
			boxes[i] = maxf(0.0, boxes[i] - delta)
	_update_rockets(delta)
	if active:
		_appear = minf(1.0, _appear + delta * 3.0)
	for m in _mines:
		m.t += delta
	_mines = _mines.filter(func(m): return m.t < MINE_LIFE and m.lanes.has(true))
	for r in _roulette:
		r.t += delta
		if r.t >= ROULETTE_TIME:
			if r.car.state == Car.State.RACING:
				picked.emit(r.car, r.item)
	_roulette = _roulette.filter(func(r): return r.t < ROULETTE_TIME)
	queue_redraw()
	_glow.queue_redraw()
	_icons.queue_redraw()


## Called every frame by the race, after the cars have moved.
func update_cars(places: Array[int]) -> void:
	for car in cars:
		var before: float = _prev.get(car, car.progress)
		var now: float = car.progress
		_prev[car] = now
		if car.state != Car.State.RACING or now <= before:
			continue
		_check_mines(car, before, now)
		if not active:
			continue
		for spot in _spots:
			if _crossed(before, now, spot.s) and car.index < spot.boxes.size() and spot.boxes[car.index] <= 0.0:
				spot.boxes[car.index] = RESPAWN
				if not _spinning(car):
					_roulette.append({"car": car, "item": _roll(places[car.index], cars.size()), "t": 0.0})
					if Game.debug_shot_on == "roulette":
						Game.debug_capture(0.3)


func _check_mines(car, before: float, now: float) -> void:
	for m in _mines:
		var lanes: Array[bool] = m.lanes
		var i: int = car.index
		if i >= lanes.size() or not lanes[i] or car == m.owner or car.airborne:
			continue
		if _crossed(before, now, m.s):
			lanes[i] = false
			if effects:
				effects.burst(car.position, Color(1.0, 0.4, 0.15))
			mine_hit.emit(car, m.owner)


## Brings the boxes out (the race calls this when the leader starts lap 2).
func activate() -> void:
	active = true
	_appear = 0.0


func _spinning(car) -> bool:
	for r in _roulette:
		if r.car == car:
			return true
	return false


func _crossed(a: float, b: float, s: float) -> bool:
	var L: float = track.length
	return floorf((a - s) / L) != floorf((b - s) / L)


func _roll(place: int, n: int) -> String:
	if Game.debug_item != "":
		return Game.debug_item
	var behind := float(place - 1) / maxf(n - 1, 1)
	var solo := n <= 1
	var weights := {
		"rocket": 0.0 if solo else lerpf(0.22, 0.4, behind),
		"shield": lerpf(0.25, 0.08, behind),
		"mega": lerpf(0.25, 0.22, behind),
		"lightning": 0.0 if solo or place == 1 else lerpf(0.0, 0.16, behind),
		"mine": 0.0 if solo or place == n else lerpf(0.26, 0.06, behind),
	}
	var total := 0.0
	for w in weights.values():
		total += w
	var r := randf() * total
	for item in weights:
		r -= weights[item]
		if r < 0.0:
			return item
	return "mega"


# --- Rockets ----------------------------------------------------------------

## Fires a rocket from `shooter` at the nearest car ahead on track, or at the car
## just behind if the shooter is leading. Returns the target (or null).
func fire_rocket(shooter):
	var target = null
	var best := INF
	for c in cars:
		if c == shooter or c.state == Car.State.FINISHED:
			continue
		var gap: float = c.progress - shooter.progress
		if gap > 0.0 and gap < best:
			best = gap
			target = c
	if target == null:
		for c in cars:
			if c == shooter or c.state == Car.State.FINISHED:
				continue
			var gap: float = shooter.progress - c.progress
			if gap >= 0.0 and gap < best:
				best = gap
				target = c
	if target == null:
		return null
	_rockets.append({"s": shooter.progress + 20.0, "lane": shooter.lane_offset, "shooter": shooter,
		"target": target, "t": 0.0, "dir": signf(target.progress - shooter.progress), "puff": 0.0})
	return target


## Drops a row of mines behind `owner`: one in every lane but its own.
func drop_mines(owner) -> void:
	var lanes: Array[bool] = []
	for i in track.lane_offsets.size():
		lanes.append(i != owner.index)
	var ms: float = owner.progress - 90.0
	while track.in_jump_zone(ms):
		ms -= 40.0 # never on the ramps or over the water
	_mines.append({"s": ms, "lanes": lanes, "owner": owner, "t": 0.0})


## Cars ahead of `shooter` (for lightning).
func cars_ahead(shooter) -> Array:
	var out := []
	for c in cars:
		if c != shooter and c.state == Car.State.RACING and c.progress > shooter.progress:
			out.append(c)
	return out


func is_targeted(car) -> bool:
	for r in _rockets:
		if r.target == car:
			return true
	return false


func _update_rockets(delta: float) -> void:
	for r in _rockets:
		r.t += delta
		var target = r.target
		var goal: float = target.progress
		r.dir = signf(goal - r.s) if absf(goal - r.s) > 1.0 else r.dir
		r.s = move_toward(r.s, goal, ROCKET_SPEED * delta)
		# Drift across into the target's lane as it closes in.
		r.lane = move_toward(r.lane, target.lane_offset, 90.0 * delta)
		r.puff -= delta
		if effects and r.puff <= 0.0:
			r.puff = 0.03
			effects.puff(_rocket_pos(r) - _rocket_dir(r) * 18.0, Color(0.75, 0.75, 0.78, 0.55), randf_range(3.0, 5.0), Vector2.ZERO, 0.45)
		if absf(target.progress - r.s) < HIT_RANGE and target.state == Car.State.RACING:
			r.t = 99.0
			if effects:
				effects.burst(target.position, Color(1.0, 0.55, 0.15))
			rocket_hit.emit(target, r.shooter)
		elif target.state != Car.State.RACING and r.t > 0.3:
			r.t = 99.0 # target crashed or finished before it arrived: fizzle out
			if effects:
				effects.puff(_rocket_pos(r), Color(0.4, 0.4, 0.42, 0.6), 10.0, Vector2.ZERO, 0.6)
	_rockets = _rockets.filter(func(r): return r.t < ROCKET_LIFE)


func _rocket_pos(r: Dictionary) -> Vector2:
	return track.point_at(r.s, r.lane)


func _rocket_dir(r: Dictionary) -> Vector2:
	var d: Vector2 = track.tangent_at(r.s)
	return d if r.dir >= 0.0 else -d


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	for m in _mines:
		var lanes: Array[bool] = m.lanes
		var fade := clampf((MINE_LIFE - m.t) / 1.0, 0.0, 1.0)
		for i in lanes.size():
			if lanes[i]:
				_draw_mine(track.point_at(m.s, track.lane_offsets[i]), m.t + i, fade)
	for spot in _spots:
		if not active:
			break
		var boxes: Array[float] = spot.boxes
		for i in boxes.size():
			if boxes[i] > 0.0:
				continue
			var off: float = track.lane_offsets[i] if i < track.lane_offsets.size() else 0.0
			var p: Vector2 = track.point_at(spot.s, off)
			_draw_box(p, spot.s * 0.01 + i)
	for r in _rockets:
		_draw_rocket(r)


func _draw_box(p: Vector2, phase: float) -> void:
	var bob := sin(_t * 4.0 + phase) * 2.0
	var rot := _t * 1.5 + phase
	var grow := minf(1.0, _appear * 1.3) # boxes pop in when they're activated
	var up := -(get_parent() as Node2D).rotation
	draw_circle(p + Vector2(4, 6), 13.0, Color(0, 0, 0, 0.3))
	draw_set_transform(p + Vector2(0, bob).rotated(up), rot, Vector2(grow, grow))
	var hue := fposmod(_t * 0.25 + phase * 0.1, 1.0)
	draw_rect(Rect2(-15, -15, 30, 30), OUTLINE)
	draw_rect(Rect2(-12, -12, 24, 24), Color.from_hsv(hue, 0.7, 1.0))
	draw_rect(Rect2(-8, -8, 16, 16), Color.from_hsv(hue, 0.35, 1.0))
	draw_set_transform(p + Vector2(0, bob).rotated(up), up, Vector2(grow, grow))
	draw_string(ThemeDB.fallback_font, Vector2(-10, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, OUTLINE)
	draw_set_transform(Vector2.ZERO)


func _draw_mine(p: Vector2, t: float, alpha: float) -> void:
	draw_circle(p + Vector2(3, 4), 11.0, Color(0, 0, 0, 0.3 * alpha))
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0)
		draw_line(p + d * 8.0, p + d * 13.0, Color(OUTLINE, alpha), 4.0)
	draw_circle(p, 10.5, Color(OUTLINE, alpha))
	draw_circle(p, 8.5, Color(0.25, 0.25, 0.3, alpha))
	var blink := int(t * 4.0) % 2 == 0
	draw_circle(p, 3.5, Color(1.0, 0.15, 0.1, alpha) if blink else Color(0.45, 0.08, 0.06, alpha))


func _draw_rocket(r: Dictionary) -> void:
	var p := _rocket_pos(r)
	var d := _rocket_dir(r)
	var k := Vector2(ROCKET_SCALE, ROCKET_SCALE)
	draw_set_transform(p + Vector2(4, 5), d.angle(), k)
	draw_rect(Rect2(-11, -4, 22, 8), Color(0, 0, 0, 0.3))
	draw_set_transform(p, d.angle(), k)
	# Body, nose cone and fins, in the shooter's colour.
	var col: Color = r.shooter.color
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -7), Vector2(-4, -3), Vector2(-4, 3), Vector2(-10, 7)]), col.darkened(0.3))
	draw_rect(Rect2(-12, -4.5, 20, 9).grow(2.0), OUTLINE)
	draw_rect(Rect2(-12, -4.5, 20, 9), Color(0.92, 0.92, 0.95))
	draw_rect(Rect2(-6, -4.5, 4, 9), col)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -6.5), Vector2(17, 0), Vector2(8, 6.5)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -4.5), Vector2(14, 0), Vector2(8, 4.5)]), Color(1.0, 0.3, 0.2))
	draw_set_transform(Vector2.ZERO)


## Spinning item icon above each car that just hit a box. It flicks through the
## items, slowing down, then pops up showing the one you got.
func _draw_roulette(ci: CanvasItem) -> void:
	var up := -(get_parent() as Node2D).rotation
	for r in _roulette:
		var car = r.car
		var t: float = r.t
		var landing := t > ROULETTE_TIME - 0.22
		var shown: String = r.item
		if not landing:
			# Ticks get slower as the roulette winds down.
			var ticks := int(pow(t / ROULETTE_TIME, 0.6) * 9.0)
			shown = ITEMS[(ticks + car.index) % ITEMS.size()]
		var pop := 1.0 + (0.35 * (1.0 - (ROULETTE_TIME - t) / 0.22) if landing else 0.0)
		var p: Vector2 = car.position + Vector2(0, -40).rotated(up)
		ci.draw_set_transform(p, up, Vector2(pop, pop))
		ci.draw_circle(Vector2.ZERO, 15.0, OUTLINE)
		ci.draw_circle(Vector2.ZERO, 12.5, Color(0.95, 0.96, 1.0))
		draw_item_icon(ci, shown, 1.0)
	ci.draw_set_transform(Vector2.ZERO)


## Small icon for an item, centred on the current transform's origin.
static func draw_item_icon(ci: CanvasItem, item: String, k: float) -> void:
	match item:
		"shield":
			ci.draw_arc(Vector2.ZERO, 8.0 * k, 0.0, TAU, 20, Color(0.25, 0.7, 1.0), 3.0 * k, true)
			ci.draw_circle(Vector2.ZERO, 5.5 * k, Color(0.4, 0.85, 1.0, 0.5))
		"rocket":
			ci.draw_rect(Rect2(Vector2(-7, -3) * k, Vector2(10, 6) * k), Color(0.35, 0.35, 0.4))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(3, -3) * k, Vector2(9, 0) * k, Vector2(3, 3) * k]), Color(1.0, 0.3, 0.2))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -2) * k, Vector2(-11, 0) * k, Vector2(-7, 2) * k]), Color(1.0, 0.6, 0.1))
		"mega":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(1, -9) * k, Vector2(-5, 1) * k, Vector2(0, 1) * k, Vector2(-2, 9) * k, Vector2(5, -2) * k, Vector2(0, -2) * k]), Color(0.2, 0.7, 1.0))
		"lightning":
			var bolt := PackedVector2Array([Vector2(2, -10) * k, Vector2(-6, 1) * k, Vector2(-1, 1) * k, Vector2(-3, 10) * k, Vector2(6, -2) * k, Vector2(1, -2) * k])
			ci.draw_colored_polygon(bolt, Color(1.0, 0.85, 0.1))
			var loop := bolt.duplicate()
			loop.append(bolt[0])
			ci.draw_polyline(loop, Color(0.55, 0.35, 0.0), 1.5 * k, true)
		"mine":
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(d * 5.0 * k, d * 9.0 * k, OUTLINE, 2.5 * k)
			ci.draw_circle(Vector2.ZERO, 6.5 * k, Color(0.25, 0.25, 0.3))
			ci.draw_circle(Vector2.ZERO, 2.5 * k, Color(1.0, 0.15, 0.1))


func _draw_glow(ci: CanvasItem) -> void:
	for spot in _spots:
		if not active:
			break
		var boxes: Array[float] = spot.boxes
		for i in boxes.size():
			if boxes[i] > 0.0:
				continue
			var off: float = track.lane_offsets[i] if i < track.lane_offsets.size() else 0.0
			var p: Vector2 = track.point_at(spot.s, off)
			ci.draw_texture_rect(Car.glow_texture(), Rect2(p - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 1, 1, 0.4))
	for m in _mines:
		var lanes: Array[bool] = m.lanes
		if int((m.t) * 4.0) % 2 == 0:
			for i in lanes.size():
				if lanes[i]:
					var q: Vector2 = track.point_at(m.s, track.lane_offsets[i])
					ci.draw_texture_rect(Car.glow_texture(), Rect2(q - Vector2(16, 16), Vector2(32, 32)), false, Color(1.0, 0.2, 0.1, 0.6))
	for r in _rockets:
		# Exhaust flame behind the rocket.
		var p := _rocket_pos(r)
		var d := _rocket_dir(r)
		var k := ROCKET_SCALE
		var tail := p - d * 14.0 * k
		var flick := randf_range(0.85, 1.15)
		var side := d.orthogonal() * k
		ci.draw_colored_polygon(PackedVector2Array([tail + side * 5.0, tail - d * 24.0 * k * flick, tail - side * 5.0]), Color(1.0, 0.55, 0.15, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([tail + side * 2.5, tail - d * 12.0 * k * flick, tail - side * 2.5]), Color(1.0, 0.95, 0.6, 0.95))
		ci.draw_texture_rect(Car.glow_texture(), Rect2(tail - Vector2(28, 28), Vector2(56, 56)), false, Color(1.0, 0.5, 0.15, 0.55))
