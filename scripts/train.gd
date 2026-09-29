extends Node2D
## The train on a level-crossing track: every so often the lights flash and the
## barriers drop (WARNING), then a train sweeps across the road (PASSING) and into
## the tunnel or off the map. Anything in its path gets knocked off.
## Drawn in the railway's own frame: local x = t along the rails, so the train is a
## row of rectangles clipped to the visible stretch of track (the tunnel hides it).
## It only redraws while it moves; the signals only when a light blinks or an arm moves.

enum State { IDLE, WARNING, PASSING }

const WARNING_TIME := 2.0
const SPEED := 1250.0
const GAP_MIN := 7.0 # seconds between trains
const GAP_MAX := 12.0
const FIRST_TRAIN := 6.0 # no train before this many seconds into the race
const OFFSCREEN := 900.0 # an open end: where the train appears / is gone
const PARTS := [[150.0, "loco"], [160.0, "car"], [160.0, "car"]] # length, kind
const PART_GAP := 12.0
const HALF_W := 23.0 # half the train's width

signal warned # lights started
signal passing # the train is coming

var track
var state := State.IDLE
var head := 0.0 # t of the train's front
var dir := 1.0 # travel direction along t
var length := 0.0
var cycle := 0 # trains so far (lets CPU drivers decide once per train)
var quiet := false # no bell, rumble or horn (the menu's demo race)
var _timer := FIRST_TRAIN
var _from := 0.0 # visible stretch of rails
var _to := 0.0
var _signals: Node2D
var _blink := false
var _blink_t := 0.0
var _arm := 0.0 # 0 up .. 1 down
var _bell: AudioStreamPlayer
var _rumble: AudioStreamPlayer


func setup(track_node) -> void:
	track = track_node
	position = track.rail_origin()
	rotation = track.rail_dir().angle()
	_from = track.rail_from if track.rail_tunnel[0] else -OFFSCREEN
	_to = track.rail_to if track.rail_tunnel[1] else OFFSCREEN
	length = 0.0
	for p in PARTS:
		length += p[0]
	length += PART_GAP * (PARTS.size() - 1)
	# The signals sit on the road below the cars (the owner adds them to the scene);
	# the train itself is drawn above the cars.
	_signals = Node2D.new()
	_signals.draw.connect(_draw_signals)
	_signals.position = position
	_signals.rotation = rotation
	z_index = 2
	if Sfx.enabled:
		_bell = AudioStreamPlayer.new()
		_bell.stream = Sfx.bell()
		_bell.volume_db = -14.0
		add_child(_bell)
		_rumble = AudioStreamPlayer.new()
		_rumble.stream = Sfx.rumble()
		_rumble.volume_db = -12.0
		add_child(_rumble)
		Sfx.horn() # made now, while the race loads, not when the first train appears
	visible = false


func signals_node() -> Node2D:
	return _signals


func _process(delta: float) -> void:
	match state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_start_warning()
		State.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_start_passing()
		State.PASSING:
			head += dir * SPEED * delta
			queue_redraw()
			var tail := head - dir * length
			if (dir > 0.0 and tail > _to) or (dir < 0.0 and tail < _from):
				_finish()
	_update_signals(delta)


func _start_warning() -> void:
	state = State.WARNING
	_timer = WARNING_TIME
	cycle += 1
	if _bell and not quiet:
		_bell.play()
	warned.emit()


func _start_passing() -> void:
	state = State.PASSING
	dir = 1.0 if randf() < 0.5 else -1.0
	head = _from if dir > 0.0 else _to
	visible = true
	if _rumble and not quiet:
		_rumble.play()
	if not quiet:
		Sfx.play(Sfx.horn(), -6.0)
	passing.emit()


func _finish() -> void:
	state = State.IDLE
	_timer = randf_range(GAP_MIN, GAP_MAX)
	visible = false
	if _bell:
		_bell.stop()
	if _rumble:
		_rumble.stop()


## Lights on and barriers down (or coming down): time to wait.
func active() -> bool:
	return state != State.IDLE


## Does the train cover lane offset `t` right now (with `margin` either side)?
func covers(t: float, margin := 0.0) -> bool:
	if state != State.PASSING:
		return false
	var a := minf(head, head - dir * length) - margin
	var b := maxf(head, head - dir * length) + margin
	return t >= a and t <= b


## Is a car at progress `s` in lane `offset` in the train's path this frame?
func hits(s: float, offset: float) -> bool:
	return absf(track.dist_from_rail(s)) < track.RAIL_HALF + 14.0 and covers(offset, 12.0)


## Seconds until the train's front reaches the road, or -1 once it's there / idle.
func time_to_road() -> float:
	var road_half: float = track.map.road_width * 0.5
	match state:
		State.WARNING:
			var start := _from if dir > 0.0 else _to
			return _timer + maxf(0.0, absf(start) - road_half) / SPEED
		State.PASSING:
			var d := -head - road_half if dir > 0.0 else head - road_half
			return maxf(0.0, d) / SPEED
	return -1.0


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	# Shadow, then each part: body, roof and windows, all clipped to the visible rails.
	var x := head
	for p in PARTS:
		var plen: float = p[0]
		var x0 := x - dir * plen
		var lo := minf(x, x0)
		var hi := maxf(x, x0)
		_rect(lo + 6.0, hi + 6.0, -HALF_W + 7.0, HALF_W + 7.0, Color(0, 0, 0, 0.25))
		if p[1] == "loco":
			_rect(lo, hi, -HALF_W, HALF_W, Color(0.1, 0.1, 0.12))
			_rect(lo + 3.0, hi - 3.0, -HALF_W + 3.0, HALF_W - 3.0, Color(0.85, 0.2, 0.18))
			_rect(lo + 18.0, hi - 18.0, -HALF_W + 9.0, HALF_W - 9.0, Color(0.62, 0.12, 0.12))
			# Cab at the front, with a windscreen.
			var front := hi if dir > 0.0 else lo
			var cab0 := front - dir * 34.0
			_rect(minf(front, cab0), maxf(front, cab0), -HALF_W + 3.0, HALF_W - 3.0, Color(0.95, 0.8, 0.2))
			var ws := front - dir * 8.0
			_rect(minf(ws, ws - dir * 8.0), maxf(ws, ws - dir * 8.0), -HALF_W + 6.0, HALF_W - 6.0, Color(0.25, 0.45, 0.6))
		else:
			_rect(lo, hi, -HALF_W, HALF_W, Color(0.1, 0.1, 0.12))
			_rect(lo + 3.0, hi - 3.0, -HALF_W + 3.0, HALF_W - 3.0, Color(0.2, 0.5, 0.35))
			_rect(lo + 8.0, hi - 8.0, -6.0, 6.0, Color(0.85, 0.85, 0.8))
			var w := lo + 14.0
			while w < hi - 20.0:
				_rect(w, w + 16.0, -HALF_W + 5.0, -HALF_W + 11.0, Color(0.3, 0.5, 0.65))
				_rect(w, w + 16.0, HALF_W - 11.0, HALF_W - 5.0, Color(0.3, 0.5, 0.65))
				w += 26.0
		x = x0 - dir * PART_GAP


## A rectangle from t0 to t1 (and y0..y1 across the rails), clipped to the visible
## stretch, so the train disappears into the tunnel.
func _rect(t0: float, t1: float, y0: float, y1: float, col: Color) -> void:
	var a := maxf(t0, _from)
	var b := minf(t1, _to)
	if b > a:
		draw_rect(Rect2(a, y0, b - a, y1 - y0), col)


func _update_signals(delta: float) -> void:
	var want := 1.0 if state != State.IDLE else 0.0
	var changed := false
	if _arm != want:
		_arm = move_toward(_arm, want, delta / 0.45)
		changed = true
	if state != State.IDLE:
		_blink_t += delta
		if _blink_t >= 0.3:
			_blink_t = 0.0
			_blink = not _blink
			changed = true
	elif _blink:
		_blink = false
		changed = true
	if changed and _signals:
		_signals.queue_redraw()


## Barrier arms and flashing lights on both sides of the road, before the crossing.
## Local frame: x across the road (the rails' direction), -y back along the road.
func _draw_signals() -> void:
	var road_half: float = track.map.road_width * 0.5 + 12.0
	var y: float = track.RAIL_HALF + 18.0 # before the crossing (the road runs along -y)
	for side in [-1.0, 1.0]:
		var post := Vector2(side * (road_half + 8.0), y)
		# Arm: across the road when down, along the roadside when up.
		var down := Vector2(-side, 0.0) * (road_half + 2.0)
		var up := Vector2(0.0, 1.0) * (road_half * 0.55)
		var tip := post + up.slerp(down, _arm)
		_signals.draw_line(post, tip, Color(0.08, 0.08, 0.1), 8.0)
		_signals.draw_line(post, tip, Color(0.97, 0.97, 0.95), 5.0)
		for k in 3:
			var q := post.lerp(tip, (k + 0.5) / 3.0)
			_signals.draw_line(q - (tip - post).normalized() * 6.0, q + (tip - post).normalized() * 6.0, Color(0.9, 0.15, 0.15), 5.0)
		_signals.draw_circle(post, 8.0, Color(0.15, 0.15, 0.17))
		# Two lamps that flash in turn.
		var lamp_base := post + Vector2(side * 16.0, 0.0)
		for k in 2:
			var lamp := lamp_base + Vector2(0.0, -8.0 + k * 16.0)
			var lit := state != State.IDLE and (_blink == (k == 0))
			_signals.draw_circle(lamp, 7.0, Color(0.08, 0.08, 0.1))
			_signals.draw_circle(lamp, 5.0, Color(1.0, 0.2, 0.15) if lit else Color(0.35, 0.12, 0.1))
			if lit:
				_signals.draw_circle(lamp, 12.0, Color(1.0, 0.25, 0.15, 0.3))
