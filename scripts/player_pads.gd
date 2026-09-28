extends Control
## Player corner pads: a big hold button per player with a speed ring, a HUD pill
## (current lap, lap progress, race position) and pop-up messages, plus the pause (X)
## button. On touch screens the top pads are drawn upside-down so they read correctly
## for the player sitting on the other side of the phone.
##
## Multi-touch safe: each finger is tracked on its own, and a touch anywhere on
## the screen counts for the nearest player's pad, so nobody has to aim.

signal pause_pressed
signal layout_changed # pad size changed (touch detected): the race refits the track

const Car = preload("res://scripts/car.gd")

const RADIUS := 70.0
const MARGIN_DESKTOP := 20.0
const MARGIN_TOUCH := 38.0 # keeps thumbs away from the phone's edge-gesture zones
const PILL_LEN := 150.0
const PILL_H := 82.0
const CLOSE_R := 26.0
const OUTLINE := Color(0.02, 0.03, 0.05)
const TOAST_SIZE := 21
const MEDALS := [Color(1.0, 0.8, 0.2), Color(0.78, 0.84, 0.9), Color(0.86, 0.52, 0.28), Color(0.45, 0.48, 0.55)]
const SUFFIX := ["ST", "ND", "RD", "TH"]
# Corner of each player's pad: P1 bottom-right, P2 top-left, P3 bottom-left, P4 top-right.
const CORNERS := [Vector2(1, 1), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)]

var num_players := 2 # cars (each gets a pad)
var humans := 2 # the first `humans` pads are real players; the rest are CPUs
var laps := 5
var king := -1 # racer on a win streak: gets a crown on their pad
var king_wins := 0
var cars: Array = [] # read every frame for speed / nitro / lap progress
var track_length := 1.0

var _places: Array[int] = [1, 2, 3, 4]
var _toasts: Array[Dictionary] = []
var _touches := {} # finger index -> player
var _mouse_player := -1
var _held: Array[bool] = [false, false, false, false]
var _lit: Array[bool] = [false, false, false, false]
var _press_anim: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _font: FontVariation
var _pill_style: StyleBoxFlat
var _badge_style: StyleBoxFlat


## Size of the strip the pads use (top/bottom in portrait, left/right in landscape);
## the track stays out of it.
static func margin() -> float:
	return MARGIN_TOUCH if Game.is_touch() else MARGIN_DESKTOP


## Pads are thumb-sized on phones and ~30% smaller with a keyboard, so on big screens
## the track gets the space. The whole pad layer is drawn at this scale.
## Lap pill length. In portrait the two bottom pills meet the X button in the middle,
## so on narrow screens they're shortened to leave it room.
static func pill_len_for(screen: Vector2) -> float:
	# The pills of two pads on the same side meet the X button in the middle of that
	# side (bottom edge in portrait, left edge in landscape): shorten them to fit.
	var side := screen.x if screen.x <= screen.y else screen.y
	var edge := RADIUS + 14.0 + margin()
	return clampf(side * 0.5 - edge - RADIUS - CLOSE_R - 28.0, 96.0, PILL_LEN)


static func ui_scale() -> float:
	return 1.0 if Game.is_touch() else 0.7


static func band_height() -> float:
	return (margin() + (RADIUS + 14.0) * 2.0 + 8.0) * ui_scale()


static func ordinal(n: int) -> String:
	return "%d%s" % [n, SUFFIX[clampi(n - 1, 0, 3)]]


var _scale := 0.0


func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit_later)
	var parent := get_parent() as Control
	if parent:
		parent.resized.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 1.0
	_pill_style = StyleBoxFlat.new()
	_pill_style.bg_color = Color(0.13, 0.15, 0.2, 0.96)
	_pill_style.set_corner_radius_all(int(PILL_H * 0.5))
	_pill_style.border_color = OUTLINE
	_pill_style.set_border_width_all(6)
	_badge_style = StyleBoxFlat.new()
	_badge_style.set_corner_radius_all(9)
	_badge_style.border_color = OUTLINE
	_badge_style.set_border_width_all(3)


func is_held(player: int) -> bool:
	return _held[player]


func release_all() -> void:
	_touches.clear()
	_mouse_player = -1
	_refresh()


## Lights a pad up; called every frame with the combined touch + keyboard state.
func set_lit(player: int, lit: bool) -> void:
	_lit[player] = lit


func set_places(places: Array[int]) -> void:
	_places = places.duplicate()


var _queued := {} # player -> Array of pending toasts


## Pop-up message next to a player's pad ("LAP 3", "NITRO!", "CRASH!"). If one was
## just shown for that player, the new one waits its turn instead of replacing it.
func toast(player: int, text: String, color := Color.WHITE, sub := "") -> void:
	var item := {"player": player, "text": text, "color": color, "t": 0.0, "sub": sub}
	for t in _toasts:
		if t.player == player and t.t < 0.7:
			if not _queued.has(player):
				_queued[player] = []
			if _queued[player].size() < 3:
				_queued[player].append(item)
			return
	_toasts = _toasts.filter(func(t): return t.player != player)
	_toasts.append(item)


func button_center(player: int) -> Vector2:
	return pad_center(player, size)


static func pad_center(player: int, screen: Vector2) -> Vector2:
	var corner: Vector2 = CORNERS[player]
	var r := RADIUS + 14.0 + margin()
	return Vector2(screen.x - r if corner.x > 0 else r, screen.y - r if corner.y > 0 else r)


## Screen areas covered by the pads, pills and the X button, as [center, radius]
## circles. Scenery uses it to keep things like parking lots out from under the UI.
static func keepouts(area: Rect2, players: int) -> Array:
	var k := ui_scale()
	var screen := area.size / k
	var out := []
	var landscape := screen.x > screen.y
	for i in players:
		var corner: Vector2 = CORNERS[i]
		var c := pad_center(i, screen)
		out.append([c, RADIUS + 24.0])
		var dir := Vector2(0, -1.0 if corner.y > 0 else 1.0) if landscape else Vector2(-1.0 if corner.x > 0 else 1.0, 0)
		var along := RADIUS
		while along <= RADIUS + pill_len_for(screen):
			out.append([c + dir * along, PILL_H * 0.5 + 14.0])
			along += 36.0
	var x_center := Vector2(margin() + RADIUS + 14.0, screen.y * 0.5) if landscape else Vector2(screen.x * 0.5, screen.y - margin() - RADIUS - 14.0)
	out.append([x_center, CLOSE_R + 24.0])
	for o in out:
		o[0] = area.position + o[0] * k
		o[1] = o[1] * k
	return out


## Covers the screen at ui_scale(): everything inside is laid out in unscaled units.
func _fit_later() -> void:
	_fit.call_deferred()


func _fit() -> void:
	var k := ui_scale()
	var changed := _scale != 0.0 and k != _scale
	_scale = k
	scale = Vector2(k, k)
	# Fill the parent (the race UI, which is already inside the safe area).
	var parent := get_parent() as Control
	var area := parent.size if parent and parent.size.x > 0.0 else get_viewport_rect().size
	position = Vector2.ZERO
	size = area / k
	queue_redraw()
	if changed:
		layout_changed.emit()


func is_landscape() -> bool:
	return size.x > size.y


func close_center() -> Vector2:
	if is_landscape():
		# Middle of the left column, between the two left pads' pills.
		return Vector2(margin() + RADIUS + 14.0, size.y * 0.5)
	return Vector2(size.x * 0.5, size.y - margin() - RADIUS - 14.0)


func _nearest_player(p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in mini(humans, num_players):
		var d := p.distance_squared_to(button_center(i))
		if d < best_d:
			best_d = d
			best = i
	return best


func _on_close(p: Vector2) -> bool:
	return p.distance_to(close_center()) <= CLOSE_R + 10.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ui_scale() != _scale:
		_fit() # a first touch switched the layout to phone size
	if event is InputEventScreenTouch:
		var pos: Vector2 = get_global_transform().affine_inverse() * event.position
		if event.pressed:
			if _on_close(pos):
				pause_pressed.emit()
				return
			_touches[event.index] = _nearest_player(pos)
			Input.vibrate_handheld(15) # a small tick so players feel the press
		else:
			_touches.erase(event.index)
		_refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Ignore mouse events that are only emulated copies of touches.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var mpos: Vector2 = get_global_transform().affine_inverse() * event.position
		if event.pressed and _on_close(mpos):
			pause_pressed.emit()
			return
		_mouse_player = _nearest_player(mpos) if event.pressed else -1
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


func _refresh() -> void:
	for i in _held.size():
		_held[i] = false
	for player in _touches.values():
		_held[player] = true
	if _mouse_player >= 0:
		_held[_mouse_player] = true


func _process(delta: float) -> void:
	for i in 4:
		_press_anim[i] = move_toward(_press_anim[i], 1.0 if _lit[i] else 0.0, delta * 12.0)
	for t in _toasts:
		t.t += delta
		# Move on to the next queued message early, so queues don't lag behind.
		if t.t > 0.7 and _queued.get(t.player, []).size() > 0:
			t.t = 99.0
	_toasts = _toasts.filter(func(t): return t.t < 1.3)
	for player in _queued.keys():
		var busy := false
		for t in _toasts:
			busy = busy or t.player == player
		if not busy and _queued[player].size() > 0:
			_toasts.append(_queued[player].pop_front())
	queue_redraw()


func _draw() -> void:
	for i in num_players:
		_draw_pad(i)
	for t in _toasts:
		_draw_toast(t)
	_draw_close()


func _text_rotation(player: int) -> float:
	var corner: Vector2 = CORNERS[player]
	return PI if corner.y == 0 and Game.is_touch() else 0.0


func _draw_pad(i: int) -> void:
	var corner: Vector2 = CORNERS[i]
	var c := button_center(i)
	var col: Color = Game.PLAYER_COLORS[i]
	var car = cars[i] if i < cars.size() else null
	var press := _press_anim[i]
	var boosting: bool = car != null and car.boosting

	# Colored band running from the screen corner into the button.
	var corner_pt := Vector2(size.x * corner.x, size.y * corner.y)
	var d := (c - corner_pt).normalized()
	var p := d.orthogonal()
	var bw := RADIUS + 14.0
	var back := corner_pt - d * 80.0
	draw_colored_polygon(PackedVector2Array([back + p * bw, c + p * bw, c - p * bw, back - p * bw]), col.darkened(0.3))
	draw_line(back + p * bw, c + p * bw, OUTLINE, 8.0)
	draw_line(back - p * bw, c - p * bw, OUTLINE, 8.0)

	# HUD pill: runs sideways in portrait, up/down in landscape, toward the screen middle.
	var landscape := is_landscape()
	var toward := -1.0 if corner.x > 0 else 1.0
	var inward := -1.0 if corner.y > 0 else 1.0
	var pill_len := pill_len_for(size)
	var pill_center: Vector2
	if landscape:
		var y1 := c.y + inward * (RADIUS + pill_len)
		draw_style_box(_pill_style, Rect2(c.x - PILL_H * 0.5, minf(c.y, y1), PILL_H, absf(y1 - c.y)))
		pill_center = Vector2(c.x, c.y + inward * (RADIUS + pill_len * 0.5 + 8.0))
	else:
		var x1 := c.x + toward * (RADIUS + pill_len)
		draw_style_box(_pill_style, Rect2(minf(c.x, x1), c.y - PILL_H * 0.5, absf(x1 - c.x), PILL_H))
		# Short pills (narrow phones) shift their contents off the button's edge.
		pill_center = Vector2(c.x + toward * (RADIUS + pill_len * 0.5 + (8.0 if pill_len < PILL_LEN else 6.0)), c.y)

	# Button with a speed ring around it.
	var ring_r := RADIUS + 7.0
	draw_circle(c, RADIUS + 14.0, OUTLINE)
	draw_arc(c, ring_r, 0.0, TAU, 36, Color(1, 1, 1, 0.08), 7.0)
	if car != null:
		var ratio: float = clampf(car.speed / Car.BOOST_SPEED, 0.0, 1.0)
		if ratio > 0.01:
			var ring_col: Color = Car.NITRO_COLOR if boosting else col.lightened(0.2)
			draw_arc(c, ring_r, -PI * 0.5, -PI * 0.5 + TAU * ratio, maxi(4, int(36 * ratio)), ring_col, 7.0)
	var r := RADIUS * (1.0 - 0.07 * press)
	draw_circle(c, r, col.lightened(0.5))
	draw_circle(c, r - 7.0, col.lerp(Color.WHITE, 0.2 * press))
	draw_circle(c + Vector2(-r * 0.28, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.14))
	# Nitro tank gauge inside the button; pulses when ready to burn.
	if car != null:
		var armed: bool = car.nitro_armed
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012) if armed and not boosting else 1.0
		draw_arc(c, r - 11.0, 0.0, TAU, 32, Color(0, 0, 0, 0.25), 7.0)
		if car.nitro > 0.01:
			draw_arc(c, r - 11.0, -PI * 0.5, -PI * 0.5 + TAU * car.nitro, maxi(4, int(32 * car.nitro)), Color(Car.NITRO_COLOR, pulse), 7.0)

	var rot := _text_rotation(i)
	draw_set_transform(c, rot)
	if i >= humans:
		# CPU rival: dimmed button with a label instead of a key.
		draw_circle(Vector2.ZERO, r - 7.0, Color(0, 0, 0, 0.35))
		var tag: String = Game.driver(i).tag
		draw_string(_font, Vector2(-RADIUS, 10), tag, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 26 if tag.length() <= 5 else 20, Color(1, 1, 1, 0.9))
		draw_string(_font, Vector2(-RADIUS, 32), "CPU • " + Game.CPU_LEVELS[Game.cpu_level], HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 11, Color(1, 1, 1, 0.7))
	elif not Game.is_touch():
		# Keyboard: show the player's key. Phones get a plain coloured button (the
		# speed ring and the pulsing nitro ring say everything).
		if car != null and car.nitro_armed:
			draw_string(_font, Vector2(-RADIUS, -20), "NITRO!" if boosting else "TAP TAP!", HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 16, Color(1, 1, 1, 0.95))
		draw_string(_font, Vector2(-RADIUS, 12), Game.key_label(i), HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 32, Color(1, 1, 1, 0.95))

	if i == king:
		_draw_king(c, landscape, toward, inward, rot)

	# Pill contents: LAP x/y, lap progress bar and the position badge.
	var fit := minf(1.0, pill_len / (PILL_LEN + 14.0)) if pill_len < PILL_LEN else 1.0
	if landscape:
		fit = minf(1.0, (pill_len + 30.0) / PILL_LEN) # the stacked layout needs less length
	draw_set_transform(pill_center, rot, Vector2(fit, fit))
	var done := 0
	var frac := 0.0
	var finished := false
	if car != null:
		done = clampi(floori(car.progress / track_length), 0, laps)
		frac = clampf(car.progress / track_length - done, 0.0, 1.0)
		finished = car.state == Car.State.FINISHED
	if finished:
		frac = 1.0
	var lap_now := str(mini(done + 1, laps))
	var caption := "FINISH" if finished else "LAP"
	var num_w := _font.get_string_size(lap_now, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var of_w := _font.get_string_size("/%d" % laps, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var place := _places[i]
	_badge_style.bg_color = MEDALS[clampi(place - 1, 0, 3)]
	var bar: Rect2
	var badge: Rect2
	var num_x := -68.0
	var num_y := 20.0
	if landscape:
		# Stacked layout for the narrow vertical pill.
		draw_string(_font, Vector2(-40, -44), caption, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1, 1, 1, 0.6))
		num_x = -(num_w + of_w + 2.0) * 0.5
		num_y = -12.0
		bar = Rect2(-28, -2, 56, 6)
		badge = Rect2(-21, 12, 42, 44)
	else:
		draw_string(_font, Vector2(-68, -12), caption, HORIZONTAL_ALIGNMENT_LEFT, 100, 15, Color(1, 1, 1, 0.6))
		bar = Rect2(-68, 27, 88, 6)
		badge = Rect2(28, -22, 42, 44)
	draw_string(_font, Vector2(num_x, num_y), lap_now, HORIZONTAL_ALIGNMENT_LEFT, 40, 36, col)
	draw_string(_font, Vector2(num_x + num_w + 2.0, num_y), "/%d" % laps, HORIZONTAL_ALIGNMENT_LEFT, 50, 19, Color(1, 1, 1, 0.55))
	draw_rect(bar, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), col)
	draw_style_box(_badge_style, badge)
	draw_string(_font, badge.position + Vector2(0, 28), str(place), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 26, OUTLINE)
	draw_string(_font, badge.position + Vector2(0, 40), SUFFIX[clampi(place - 1, 0, 3)], HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 10, OUTLINE)
	draw_set_transform(Vector2.ZERO)


## Crown on the rim of the king's button, on the side away from the pill, with
## the number of wins in a row.
func _draw_king(c: Vector2, landscape: bool, toward: float, inward: float, rot: float) -> void:
	var side := Vector2(toward, 0) if landscape else Vector2(0, inward)
	var bob := sin(Time.get_ticks_msec() * 0.005) * 2.0
	var pos := c + side * (RADIUS + 24.0) + Vector2(0, bob)
	draw_set_transform(pos, rot, Vector2(1.5, 1.5))
	var gold := Color(1.0, 0.8, 0.15)
	var shape := PackedVector2Array([
		Vector2(-14, 8), Vector2(-15, -7), Vector2(-7, 0), Vector2(0, -12),
		Vector2(7, 0), Vector2(15, -7), Vector2(14, 8),
	])
	var loop := shape.duplicate()
	loop.append(shape[0])
	draw_polyline(loop, OUTLINE, 6.0, true)
	draw_colored_polygon(shape, gold)
	draw_rect(Rect2(-14, 3, 28, 5), gold.darkened(0.25))
	for tip in [Vector2(-15, -7), Vector2(0, -12), Vector2(15, -7)]:
		draw_circle(tip, 3.5, OUTLINE)
		draw_circle(tip, 2.3, Color(1.0, 0.3, 0.35))
	draw_string(_font, Vector2(16, 10), "x%d" % king_wins, HORIZONTAL_ALIGNMENT_LEFT, 40, 15, Color.WHITE)
	draw_set_transform(Vector2.ZERO)


func _draw_toast(t: Dictionary) -> void:
	var i: int = t.player
	if i >= num_players:
		return
	var corner: Vector2 = CORNERS[i]
	var c := button_center(i)
	var toward := -1.0 if corner.x > 0 else 1.0
	var inward := -1.0 if corner.y > 0 else 1.0 # toward the middle of the screen
	var age: float = t.t
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - age * 6.0)
	var alpha := clampf((1.3 - age) / 0.4, 0.0, 1.0)
	var text: String = t.text
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_SIZE).x * pop + 20.0
	var pos: Vector2
	if is_landscape():
		# Beside the player's lap pill, just inside the track area.
		var pill_y := c.y + inward * (RADIUS + pill_len_for(size) * 0.5 + 8.0)
		pos = Vector2(c.x + toward * (PILL_H * 0.5 + 16.0 + width * 0.5), pill_y + inward * age * 18.0)
	else:
		pos = Vector2(c.x + toward * (RADIUS + pill_len_for(size) * 0.5), c.y + inward * (PILL_H * 0.5 + 30.0 + age * 18.0))
	# Keep the whole message on screen.
	pos.x = clampf(pos.x, width * 0.5, size.x - width * 0.5)
	draw_set_transform(pos, _text_rotation(i), Vector2(pop, pop))
	var col: Color = t.color
	draw_string_outline(_font, Vector2(-200, 8), text, HORIZONTAL_ALIGNMENT_CENTER, 400, TOAST_SIZE, 6, Color(0, 0, 0, alpha))
	draw_string(_font, Vector2(-200, 8), text, HORIZONTAL_ALIGNMENT_CENTER, 400, TOAST_SIZE, Color(col, alpha))
	var sub: String = t.get("sub", "")
	if sub != "":
		draw_string_outline(_font, Vector2(-200, 26), sub, HORIZONTAL_ALIGNMENT_CENTER, 400, 14, 5, Color(0, 0, 0, alpha))
		draw_string(_font, Vector2(-200, 26), sub, HORIZONTAL_ALIGNMENT_CENTER, 400, 14, Color(1, 1, 1, alpha * 0.9))
	draw_set_transform(Vector2.ZERO)


func _draw_close() -> void:
	var c := close_center()
	draw_circle(c, CLOSE_R + 6.0, OUTLINE)
	draw_circle(c, CLOSE_R, Color(0.95, 0.96, 0.98))
	var s := CLOSE_R * 0.38
	var x_col := Color(0.55, 0.62, 0.72)
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), x_col, 6.0, true)
	draw_line(c + Vector2(-s, s), c + Vector2(s, -s), x_col, 6.0, true)
