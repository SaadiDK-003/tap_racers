extends ScrollContainer
## Phone-style touch scrolling. Drag anywhere on the list (cards and buttons too)
## and it follows the finger; flick it and it glides to a stop. A touch only becomes
## a scroll once it moves past DEADZONE, so taps on buttons in the list still work,
## and a swipe that starts on a button never presses it. The mouse wheel and the
## scrollbar work as usual.

const DEADZONE := 10.0 # viewport units a finger moves before it's a scroll
const FRICTION := 3.2 # how quickly a flick slows down (higher = shorter glide)
const MAX_SPEED := 4500.0
const SAMPLE_TIME := 0.1 # seconds of finger movement used to measure a flick
const AWAY := Vector2(-10000, -10000) # where _cancel_press moves the emulated mouse

var _touch := -1 # finger index being tracked, or -1
var _start := Vector2.ZERO
var _dragging := false
var _pos := 0.0 # scroll position (float, for sub-pixel motion)
var _vel := 0.0 # glide speed after a flick, units per second
var _samples: Array[Vector2] = [] # (time, finger y) over the last SAMPLE_TIME


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _bar() -> VScrollBar:
	return get_v_scroll_bar()


func _max_scroll() -> float:
	var b := _bar()
	return maxf(0.0, b.max_value - b.page)


func _set_pos(v: float) -> void:
	_pos = clampf(v, 0.0, _max_scroll())
	_bar().value = _pos # the bar's value is a float: the list moves smoothly


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0 and get_global_rect().has_point(event.position):
			_touch = event.index
			_start = event.position
			_dragging = false
			_vel = 0.0
			_pos = _bar().value
			_samples = [Vector2(_now(), event.position.y)]
		elif not event.pressed and event.index == _touch:
			_touch = -1
			if _dragging:
				_vel = _flick_speed()
				_dragging = false
	elif event is InputEventScreenDrag and event.index == _touch:
		if not _dragging and absf(event.position.y - _start.y) > DEADZONE:
			_dragging = true
			_cancel_press()
		if _dragging:
			_set_pos(_pos - event.relative.y)
			var t := _now()
			_samples.append(Vector2(t, event.position.y))
			while _samples.size() > 2 and t - _samples[0].x > SAMPLE_TIME:
				_samples.pop_front()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging and event.position.x > AWAY.x * 0.5:
		# The mouse events phones emulate from the finger: keep them away from the
		# buttons under it while scrolling.
		get_viewport().set_input_as_handled()


## Speed of the finger over its last moments; zero if it stopped before lifting.
func _flick_speed() -> float:
	if _samples.size() < 2:
		return 0.0
	var a: Vector2 = _samples[0]
	var b: Vector2 = _samples[_samples.size() - 1]
	if _now() - b.x > 0.08 or b.x - a.x <= 0.0:
		return 0.0 # finger held still before lifting: no glide
	return clampf(-(b.y - a.y) / (b.x - a.x), -MAX_SPEED, MAX_SPEED)


## A swipe that started on a button must not press it: move the (emulated) mouse
## off it, so the button sees the finger leave and ignores the release.
func _cancel_press() -> void:
	var away := InputEventMouseMotion.new()
	away.position = AWAY
	away.global_position = away.position
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input.call_deferred(away) # not from inside another input event


func _process(delta: float) -> void:
	if _dragging:
		return
	if absf(_vel) > 0.0:
		_set_pos(_pos + _vel * delta)
		_vel *= exp(-FRICTION * delta)
		if absf(_vel) < 12.0 or _pos <= 0.0 or _pos >= _max_scroll():
			_vel = 0.0
	else:
		_pos = _bar().value # follow the wheel / scrollbar
