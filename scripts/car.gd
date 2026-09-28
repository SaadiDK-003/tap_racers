extends Node2D
## A slot car locked to its lane. Hold = accelerate, release = brake.
## Too much speed for a corner builds up slip; full slip throws the car off the track.
## Driving fast fills a NITRO tank. Once full, a quick double-tap fires a nitro burst:
## a big kick of speed for a couple of seconds during which the car can't crash.

signal crashed(car)
signal boost_started(car)
signal nitro_ready(car)
signal near_miss(car) # slid right to the edge of a crash and saved it
signal shield_used(car) # the shield power-up just blocked a crash or a rocket

enum State { GRID, RACING, CRASHED, FINISHED }

const DrawLayer = preload("res://scripts/draw_layer.gd")

const TOP_SPEED := 720.0
const BOOST_SPEED := 1000.0
const NITRO_FILL_TIME := 2.6 # seconds of flat-out driving to fill the tank
const NITRO_BURN_TIME := 1.8 # length of a nitro burst
const NITRO_KICK := 160.0 # instant speed added when nitro fires
const NITRO_GRACE := 0.7 # seconds after a burst before the car can slip again
const NITRO_START := 0.5 # tank level at the start of a race
const DOUBLE_TAP := 0.35 # max seconds between two presses to count as a double-tap
const ACCEL := 950.0
const BOOST_ACCEL := 1100.0
const BRAKE := 1050.0 # average release slow-down, used for braking-distance maths (bots)
const DRAG := 650.0 # base slow-down when the button is released
const TURN_SMOOTHING := 22.0 # higher = car follows the track direction more tightly
const GRIP := 1350.0 # lateral grip: safe corner speed = sqrt(GRIP * radius)
const SLIP_TOLERANCE := 0.15 # up to 15% over a corner's limit is free, no slip at all
const SLIP_RATE := 6.0 # how fast slip builds beyond the tolerance
const SLIP_RECOVER := 6.0 # how fast the car regains grip once back under it
const SLIP_VISIBLE := 0.25 # below this the car looks perfectly planted
const MAX_DRIFT := 10.0 # sideways slide (px) just before a crash
const CRASH_TIME := 1.1
const CRUISE_SPEED := 220.0
const LENGTH := 42.0
const WIDTH := 24.0
const TRAIL_POINTS := 18
const OUTLINE := Color(0.02, 0.03, 0.05)
const NITRO_COLOR := Color(0.35, 0.8, 1.0)

static var _add_mat: CanvasItemMaterial
static var _glow_tex: GradientTexture2D
# Baked car images, one per look (body, decal, colour, number), shared by every car.
static var _skins := {}
const SKIN_SCALE := 3.0 # texture pixels per car unit (sharp even when zoomed in)
const SKIN_RECT := Rect2(-34, -24, 68, 48) # car-local area the image covers

var baking := false # true for the hidden copy that renders a skin

var index := 0
var color := Color.WHITE
var lane_offset := 0.0
var track
var effects
var engine: AudioStreamPlayer
var body := "classic" # car style from the garage: classic, kart, f1, muscle
var decal := "none" # none, stripes, number, checker, flames, bolt
var engine_gain := 0.0 # dB offset (CPU engines are quieter)
var nitro_fill_mult := 1.0 # catch-up: cars further back fill nitro faster
var lap_clean := true # no crash and no visible slide so far this lap (PERFECT LAP)
var grip_mult := 1.0 # weather: rain makes corners slippery
var shield := false: # power-up: blocks the next crash or rocket, for SHIELD_TIME seconds
	set(v):
		shield = v
		shield_time = SHIELD_TIME if v else 0.0
var shield_time := 0.0
const ZAP_TIME := 2.0
var zap_t := 0.0 # lightning: shrunk and slowed while > 0
var _base_scale := Vector2.ZERO
const SHIELD_TIME := 10.0
var mega := false # power-up: the next nitro burst lasts longer
var night := false # draw headlight beams
var _burn_mult := 1.0
var _peak_slip := 0.0

var state := State.GRID
var progress := -22.0 # distance along the centerline; line crossed at 0
var speed := 0.0
var slip := 0.0
var finish_time := -1.0
var crashes := 0
var throttle := false
var boosting := false
var trail := PackedVector2Array()

var _drift := 0.0
var _slide_dir := 0.0
var nitro := NITRO_START # tank level 0..1
var nitro_armed := false # tank was filled; can be burned until empty
var _grace := 0.0
var _clock := 0.0
var _last_press := -10.0
var _prev_held := false
var _flame_power := 0.0
var _crash_timer := 0.0
var _crash_vel := Vector2.ZERO
var _spin := 0.0
var _invuln := 0.0
var _smoke_timer := 0.0
var _last_wheels := PackedVector2Array()
var _glow: Node2D
var _flame: Node2D


static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


func _ready() -> void:
	if baking:
		return
	_glow = _add_fx_layer(_draw_glow)
	_flame = _add_fx_layer(_draw_flame)


func _add_fx_layer(fn: Callable) -> Node2D:
	var layer := DrawLayer.new()
	layer.draw_fn = fn
	layer.show_behind_parent = true
	layer.material = additive()
	add_child(layer)
	return layer


func place() -> void:
	position = track.point_at(progress, lane_offset)
	rotation = track.tangent_at(progress).angle()


func tick(delta: float, held: bool) -> void:
	_clock += delta
	if held and not _prev_held:
		if _clock - _last_press <= DOUBLE_TAP:
			fire_nitro()
		_last_press = _clock
	_prev_held = held
	throttle = held
	match state:
		State.GRID:
			place()
			if held:
				_emit_smoke(delta, 0.1, Color(0.7, 0.7, 0.75, 0.35))
		State.RACING, State.FINISHED:
			_drive(delta, held)
		State.CRASHED:
			_crashed(delta)

	var target_flame := 0.0
	if boosting:
		target_flame = 1.6
	elif held and state == State.RACING:
		target_flame = clampf((speed / TOP_SPEED - 0.6) / 0.4, 0.0, 1.0)
	_flame_power = lerpf(_flame_power, target_flame, minf(1.0, 12.0 * delta))
	_update_trail()
	_update_engine()
	if shield:
		shield_time -= delta
		if shield_time <= 0.0:
			shield = false
	# Lightning shrink: pop small, then grow back over the last half second.
	if _base_scale == Vector2.ZERO:
		_base_scale = scale
	if zap_t > 0.0:
		zap_t = maxf(0.0, zap_t - delta)
		var k := lerpf(0.65, 1.0, clampf((0.5 - zap_t) / 0.5, 0.0, 1.0)) if zap_t < 0.5 else 0.65
		scale = _base_scale * k
	elif scale != _base_scale:
		scale = _base_scale

	if _invuln > 0.0:
		_invuln -= delta
		modulate.a = 0.35 if int(_invuln * 12.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	# On a figure-8, cars on the bridge are drawn above the bridge deck, others below it.
	z_index = 2 if track.has_bridge() and track.on_bridge(progress) and state != State.CRASHED else 0
	queue_redraw()
	_glow.queue_redraw()
	_flame.queue_redraw()


func _drive(delta: float, held: bool) -> void:
	var k: float = track.curvature_at(progress)

	_update_nitro(delta, held)

	# Speed eases in and out instead of snapping: strong pull from low speed that
	# tapers off near the top, and a brake that softens as the car slows down.
	if state == State.FINISHED:
		speed = move_toward(speed, CRUISE_SPEED, DRAG * delta)
	elif held or boosting:
		var target := BOOST_SPEED if boosting else TOP_SPEED
		if zap_t > 0.0:
			target = TOP_SPEED * 0.55
		if speed < target:
			var rate := BOOST_ACCEL if speed >= TOP_SPEED else ACCEL
			var taper := 0.45 + 0.55 * (1.0 - speed / target)
			speed = minf(target, speed + rate * taper * delta)
		else:
			speed = move_toward(speed, target, DRAG * delta)
	else:
		speed = move_toward(speed, 0.0, (DRAG + 750.0 * speed / TOP_SPEED) * delta)

	var safe := sqrt(GRIP * grip_mult / maxf(absf(k), 0.00001))
	var over := speed / safe - 1.0 - SLIP_TOLERANCE
	if boosting or _grace > 0.0:
		# Nitro: the car can't crash, it just drifts a little for style.
		_grace = maxf(0.0, _grace - delta)
		slip = clampf(over * 2.0, 0.0, 0.55) if boosting else maxf(0.0, slip - SLIP_RECOVER * delta)
	elif over > 0.0 and state == State.RACING:
		slip += over * SLIP_RATE * delta
	else:
		slip = maxf(0.0, slip - SLIP_RECOVER * delta)

	# Only a real corner sets the slide direction, so straights never wobble.
	if absf(k) > 1.0 / 800.0:
		_slide_dir = -signf(k)
	var visible_slip := maxf(0.0, slip - SLIP_VISIBLE) / (1.0 - SLIP_VISIBLE)
	_drift = lerpf(_drift, visible_slip * MAX_DRIFT * _slide_dir, minf(1.0, 12.0 * delta))
	progress += speed * delta
	position = track.point_at(progress, lane_offset + _drift)
	var heading: float = track.tangent_at(progress).angle() - _slide_dir * visible_slip * 0.25
	rotation = lerp_angle(rotation, heading, 1.0 - exp(-TURN_SMOOTHING * delta))

	if visible_slip > 0.0:
		_emit_smoke(delta, 0.035, Color(0.9, 0.9, 0.95, 0.5))
		_leave_skids()
	else:
		_last_wheels.clear()
	if slip >= 1.0 and shield:
		# Shield absorbs the crash: the car scrubs speed and carries on.
		shield = false
		slip = 0.3
		speed = minf(speed, safe * 0.9)
		shield_used.emit(self)
	elif slip >= 1.0:
		_crash(_slide_dir)
	elif state == State.RACING and can_crash():
		if visible_slip > 0.15:
			lap_clean = false
		# Close call: got near the limit and recovered without crashing.
		_peak_slip = maxf(_peak_slip, slip)
		if slip < 0.05:
			if _peak_slip > 0.65:
				near_miss.emit(self)
			_peak_slip = 0.0


## Hit by lightning: shrunk and slowed for ZAP_TIME, unless a shield blocks it.
## Returns true if the car was zapped.
func zap() -> bool:
	if state != State.RACING:
		return false
	if shield:
		shield = false
		shield_used.emit(self)
		return false
	zap_t = ZAP_TIME
	speed = minf(speed, TOP_SPEED * 0.55)
	boosting = false
	return true


## Hit by a rocket: blown off the track (even mid-nitro), unless a shield blocks it.
## Returns true if the car crashed.
func rocket_hit() -> bool:
	if state != State.RACING:
		return false
	if shield:
		shield = false
		shield_used.emit(self)
		return false
	lap_clean = false
	_crash(1.0 if randf() < 0.5 else -1.0)
	return true


## Bonus nitro (close calls, perfect laps); may fill the tank.
func add_nitro(amount: float) -> void:
	if nitro_armed or boosting:
		return
	nitro = minf(1.0, nitro + amount)
	if nitro >= 1.0:
		nitro_armed = true
		nitro_ready.emit(self)


## False during nitro and its short grace period.
func can_crash() -> bool:
	return not boosting and _grace <= 0.0


## Double-tap action: fires a nitro burst if the tank is full.
func fire_nitro() -> void:
	if state != State.RACING or not nitro_armed or boosting:
		return
	boosting = true
	_burn_mult = 1.7 if mega else 1.0
	mega = false
	speed = minf(BOOST_SPEED, maxf(speed, 200.0) + NITRO_KICK)
	boost_started.emit(self)


func _update_nitro(delta: float, _held: bool) -> void:
	if state != State.RACING:
		boosting = false
		return
	if boosting:
		nitro -= delta / (NITRO_BURN_TIME * _burn_mult)
		if nitro <= 0.0:
			nitro = 0.0
			nitro_armed = false
			boosting = false
			_grace = NITRO_GRACE
	elif not nitro_armed:
		# Fills faster the closer the car runs to top speed.
		var fast := clampf((speed / TOP_SPEED - 0.4) / 0.6, 0.0, 1.0)
		nitro += fast * nitro_fill_mult * delta / NITRO_FILL_TIME
		if nitro >= 1.0:
			nitro = 1.0
			nitro_armed = true
			nitro_ready.emit(self)


## Bots fire nitro when full and heading onto a stretch without sharp corners.
func bot_wants_nitro() -> bool:
	if not nitro_armed or boosting:
		return false
	var x := 0.0
	while x < 700.0:
		if absf(track.curvature_at(progress + x)) > 1.0 / 180.0:
			return false
		x += 25.0
	return true


func _rear_wheels() -> PackedVector2Array:
	var fwd := Vector2.from_angle(rotation)
	var side := fwd.orthogonal() * WIDTH * 0.5 * scale.x
	var rear := position - fwd * LENGTH * 0.3 * scale.x
	return PackedVector2Array([rear + side, rear - side])


func _leave_skids() -> void:
	var wheels := _rear_wheels()
	if _last_wheels.size() == 2 and effects:
		effects.skid(_last_wheels[0], wheels[0])
		effects.skid(_last_wheels[1], wheels[1])
	_last_wheels = wheels


func _crash(outward: float) -> void:
	state = State.CRASHED
	crashes += 1
	boosting = false
	nitro = 0.0
	nitro_armed = false
	_grace = 0.0
	lap_clean = false
	_peak_slip = 0.0
	var tg: Vector2 = track.tangent_at(progress)
	var normal := Vector2(-tg.y, tg.x) * outward
	_crash_vel = (tg * 0.85 + normal * 0.5).normalized() * maxf(speed, 160.0) * 0.8
	_spin = -outward * 11.0
	_crash_timer = CRASH_TIME
	speed = 0.0
	slip = 0.0
	_drift = 0.0
	_last_wheels.clear()
	if effects:
		effects.burst(position, color)
	crashed.emit(self)


func _crashed(delta: float) -> void:
	_crash_timer -= delta
	position += _crash_vel * delta
	_crash_vel = _crash_vel.move_toward(Vector2.ZERO, 650.0 * delta)
	rotation += _spin * delta
	_spin = move_toward(_spin, 0.0, 7.0 * delta)
	_emit_smoke(delta, 0.06, Color(0.3, 0.3, 0.32, 0.5))
	if _crash_timer <= 0.0:
		state = State.RACING
		_invuln = 1.0
		place()


func _emit_smoke(delta: float, interval: float, col: Color) -> void:
	_smoke_timer -= delta
	if _smoke_timer > 0.0 or effects == null:
		return
	_smoke_timer = interval
	var rear := position - Vector2.from_angle(rotation) * LENGTH * 0.5 * scale.x
	effects.puff(rear, col, randf_range(4.0, 7.0), Vector2.from_angle(randf() * TAU) * 20.0)


func _update_trail() -> void:
	if state == State.RACING and speed > TOP_SPEED * 0.55:
		trail.append(position - Vector2.from_angle(rotation) * LENGTH * 0.5 * scale.x)
		if trail.size() > TRAIL_POINTS:
			trail.remove_at(0)
	elif trail.size() > 0:
		trail.remove_at(0)


func _update_engine() -> void:
	if engine == null:
		return
	var r := speed / TOP_SPEED
	engine.pitch_scale = 0.55 + r * 1.35
	engine.volume_db = lerpf(-30.0, -17.0, clampf(r, 0.0, 1.0)) + (2.0 if boosting else 0.0) + engine_gain


## CPU driver (also used by the menu's demo race and the --bots debug flag).
## `skill` scales how close to each corner's limit it drives; a gentle per-car wobble
## keeps CPUs from driving identically.
func bot_throttle(skill := 1.0, top_share := 1.0) -> bool:
	if not boosting and speed > TOP_SPEED * top_share:
		return false
	skill *= 1.0 + 0.03 * sin(progress / 280.0 + index * 1.7)
	var brake_dist := speed * speed / (2.0 * BRAKE) + 40.0
	var x := 0.0
	while x <= brake_dist:
		var k: float = track.curvature_at(progress + x)
		var safe := sqrt(GRIP * grip_mult / maxf(absf(k), 0.00001)) * (1.0 + SLIP_TOLERANCE * 0.8) * skill
		if speed > sqrt(safe * safe + 2.0 * BRAKE * x):
			return false
		x += 12.0
	return true


# --- Drawing ----------------------------------------------------------------

static func _rounded(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - radius, radius), -PI * 0.5],
		[r.end - Vector2(radius, radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[r.position + Vector2(radius, radius), PI],
	]
	for c in corners:
		for step in 5:
			pts.append(c[0] + Vector2.from_angle(c[1] + step * PI * 0.125) * radius)
	return pts


func _shape(r: Rect2, radius: float, fill: Color) -> void:
	var poly := _rounded(r, radius)
	draw_colored_polygon(poly, fill)
	poly.append(poly[0])
	draw_polyline(poly, OUTLINE, 3.0, true)


## Neon underglow (additive, drawn behind the body), plus headlights at night and the shield.
func _draw_glow(ci: CanvasItem) -> void:
	if state == State.CRASHED:
		return
	if night:
		var beam := PackedVector2Array([Vector2(LENGTH * 0.45, -7), Vector2(LENGTH * 0.45 + 150, -48), Vector2(LENGTH * 0.45 + 150, 48), Vector2(LENGTH * 0.45, 7)])
		var warm := Color(1.0, 0.92, 0.7)
		ci.draw_polygon(beam, PackedColorArray([Color(warm, 0.35), Color(warm, 0.0), Color(warm, 0.0), Color(warm, 0.35)]))
		ci.draw_texture_rect(glow_texture(), Rect2(-LENGTH * 0.5 - 16, -14, 20, 28), false, Color(1, 0.1, 0.05, 0.6))
	# Blinks during its last 3 seconds.
	if shield and (shield_time > 3.0 or int(shield_time * 8.0) % 2 == 0):
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
		ci.draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(0.4, 0.9, 1.0, 0.7 * pulse), 4.0, true)
		ci.draw_circle(Vector2.ZERO, 29.0, Color(0.4, 0.9, 1.0, 0.12))
	var c := NITRO_COLOR if boosting else color
	var a := 0.35 + 0.25 * clampf(speed / TOP_SPEED, 0.0, 1.0)
	ci.draw_texture_rect(glow_texture(), Rect2(-44, -30, 88, 60), false, Color(c, a))


## Exhaust flames (additive, drawn behind the body).
func _draw_flame(ci: CanvasItem) -> void:
	if _flame_power < 0.05 or state != State.RACING:
		return
	var p := _flame_power
	var outer := NITRO_COLOR if boosting else Color(1.0, 0.45, 0.1)
	var mid := Color(0.7, 0.95, 1.0) if boosting else Color(1.0, 0.85, 0.25)
	var base_x := -LENGTH * 0.5 - 2.0
	for y in [-5.0, 5.0]:
		var length := (10.0 + 22.0 * p) * randf_range(0.8, 1.15)
		var w := 4.0 + 2.5 * p
		_flame_cone(ci, base_x, y, length, w, Color(outer, 0.85))
		_flame_cone(ci, base_x, y, length * 0.65, w * 0.65, Color(mid, 0.9))
		_flame_cone(ci, base_x, y, length * 0.3, w * 0.35, Color(1, 1, 1, 0.9))
	ci.draw_texture_rect(glow_texture(), Rect2(base_x - 30.0 * p - 10.0, -18, 40.0 * p + 20.0, 36), false, Color(outer, 0.5 * minf(p, 1.0)))


func _flame_cone(ci: CanvasItem, x: float, y: float, length: float, w: float, c: Color) -> void:
	var tip := Vector2(x - length, y + randf_range(-1.5, 1.5))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y - w), Vector2(x - length * 0.35, y - w * 0.9), tip, Vector2(x - length * 0.35, y + w * 0.9), Vector2(x, y + w)]), c)


## A texture of this car's body/decal/colour, rendered once and cached.
func _skin() -> Texture2D:
	var key := "%s|%s|%s|%d" % [body, decal, color.to_html(), index if decal == "number" else 0]
	if _skins.has(key):
		return _skins[key]
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(SKIN_RECT.size * SKIN_SCALE)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter = get_script().new()
	painter.baking = true
	painter.body = body
	painter.decal = decal
	painter.color = color
	painter.index = index
	painter.state = State.CRASHED # no underglow in the image
	painter.scale = Vector2(SKIN_SCALE, SKIN_SCALE)
	painter.position = -SKIN_RECT.position * SKIN_SCALE
	vp.add_child(painter)
	Game.add_child(vp) # lives on the autoload, so the cache survives scene changes
	_skins[key] = vp.get_texture()
	return _skins[key]


func _draw() -> void:
	if not baking:
		# Normal cars draw their cached image plus the lights that change.
		draw_texture_rect(_skin(), SKIN_RECT, false)
		if not throttle and state == State.RACING:
			var hl := LENGTH * 0.5
			var hw := WIDTH * 0.5
			draw_circle(Vector2(-hl + 1, -hw + 5), 2.8, Color(1, 0.15, 0.1))
			draw_circle(Vector2(-hl + 1, hw - 5), 2.8, Color(1, 0.15, 0.1))
		return
	match body:
		"f1": _draw_f1()
		"kart": _draw_kart()
		"muscle": _draw_muscle()
		_: _draw_classic()


func _wheel(center: Vector2, size: Vector2) -> void:
	_shape(Rect2(center - size * 0.5, size), 2.5, OUTLINE)
	draw_rect(Rect2(center - Vector2(size.x * 0.3, size.y * 0.5 - 1.5), Vector2(size.x * 0.6, 1.5)), Color(1, 1, 1, 0.12))


func _draw_classic() -> void:
	var hl := LENGTH * 0.5
	var hw := WIDTH * 0.5
	draw_colored_polygon(_rounded(Rect2(-hl + 3, -hw + 5, LENGTH, WIDTH), 8), Color(0, 0, 0, 0.4))
	for wx in [-LENGTH * 0.28, LENGTH * 0.26]:
		for wy in [-hw - 1.0, hw + 1.0]:
			_wheel(Vector2(wx, wy), Vector2(12, 7))
	_shape(Rect2(-hl, -hw + 2, LENGTH, WIDTH - 4), 8.0, color)
	draw_rect(Rect2(-hl + 5, -hw + 4, LENGTH - 12, 3), Color(1, 1, 1, 0.25))
	if decal == "none":
		draw_rect(Rect2(hl - 14, -5.5, 11, 3), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(hl - 14, 2.5, 11, 3), Color(1, 1, 1, 0.9))
	_draw_decal(Rect2(-hl + 5, -hw + 5, LENGTH - 9, WIDTH - 10))
	_shape(Rect2(-7, -hw + 6, 14, WIDTH - 12), 4.0, color.lightened(0.45))
	draw_rect(Rect2(-5, -hw + 8, 4, WIDTH - 16), Color(0.1, 0.12, 0.18, 0.8))
	_shape(Rect2(-hl - 3, -hw, 7, WIDTH), 2.5, color.darkened(0.35))
	draw_circle(Vector2(hl - 2, -hw + 5), 2.2, Color(1, 1, 0.85))
	draw_circle(Vector2(hl - 2, hw - 5), 2.2, Color(1, 1, 0.85))


## Open-wheel single seater: narrow nose, exposed wheels, big wings.
func _draw_f1() -> void:
	var hl := LENGTH * 0.5 + 2.0
	var hw := WIDTH * 0.5
	draw_colored_polygon(_rounded(Rect2(-hl + 3, -hw + 4, hl * 2.0, WIDTH), 6), Color(0, 0, 0, 0.35))
	for wx in [-hl * 0.62, hl * 0.52]:
		for wy in [-hw, hw]:
			draw_line(Vector2(wx, 0), Vector2(wx, wy), OUTLINE, 2.5)
			_wheel(Vector2(wx, wy), Vector2(14, 9))
	var fuselage := PackedVector2Array([
		Vector2(hl + 3, -2.5), Vector2(hl - 12, -4.5), Vector2(0, -6.5), Vector2(-hl + 6, -6.0),
		Vector2(-hl + 6, 6.0), Vector2(0, 6.5), Vector2(hl - 12, 4.5), Vector2(hl + 3, 2.5),
	])
	draw_colored_polygon(fuselage, color)
	var loop := fuselage.duplicate()
	loop.append(fuselage[0])
	draw_polyline(loop, OUTLINE, 3.0, true)
	_shape(Rect2(-10, -10, 16, 4), 2.0, color.darkened(0.2))
	_shape(Rect2(-10, 6, 16, 4), 2.0, color.darkened(0.2))
	_draw_decal(Rect2(-hl + 7, -4.5, hl * 2.0 - 12, 9))
	_shape(Rect2(hl - 1, -hw - 2, 5, WIDTH + 4), 2.0, color.darkened(0.35))
	_shape(Rect2(-hl - 1, -hw + 1, 7, WIDTH - 2), 2.0, color.darkened(0.45))
	draw_circle(Vector2(-3, 0), 5.5, OUTLINE)
	draw_circle(Vector2(-3, 0), 4.2, Color(0.95, 0.95, 0.98))
	draw_rect(Rect2(-1, -3, 3, 6), Color(0.1, 0.12, 0.2))


## Go-kart: short and wide, fat tyres, driver sitting in the open.
func _draw_kart() -> void:
	var kl := LENGTH * 0.4
	var kw := WIDTH * 0.5
	draw_colored_polygon(_rounded(Rect2(-kl + 3, -kw + 4, kl * 2.0, WIDTH), 6), Color(0, 0, 0, 0.35))
	for wx in [-kl * 0.72, kl * 0.66]:
		for wy in [-kw, kw]:
			_wheel(Vector2(wx, wy), Vector2(11, 9))
	_shape(Rect2(-kl, -kw + 4, kl * 2.0, WIDTH - 8), 4.0, Color(0.2, 0.21, 0.25))
	_shape(Rect2(kl * 0.25, -7, kl * 0.8, 14), 5.0, color)
	_shape(Rect2(-kl * 0.55, -kw + 2, kl * 0.9, 4), 2.0, color)
	_shape(Rect2(-kl * 0.55, kw - 6, kl * 0.9, 4), 2.0, color)
	_draw_decal(Rect2(kl * 0.3, -5.5, kl * 0.7, 11))
	_shape(Rect2(-kl - 2, -kw + 3, 4, WIDTH - 6), 1.5, color.darkened(0.4))
	draw_circle(Vector2(-3, 0), 7.5, OUTLINE)
	draw_circle(Vector2(-3, 0), 6.0, color.lightened(0.35))
	draw_rect(Rect2(-5, -1.5, 8, 3), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(0, -4, 3, 8), Color(0.1, 0.12, 0.2))


## Muscle car: long, wide and boxy with a big hood and a spoiler.
func _draw_muscle() -> void:
	var hl := LENGTH * 0.5 + 2.0
	var hw := WIDTH * 0.5 + 1.0
	draw_colored_polygon(_rounded(Rect2(-hl + 3, -hw + 5, hl * 2.0, hw * 2.0), 5), Color(0, 0, 0, 0.4))
	for wx in [-hl * 0.55, hl * 0.52]:
		for wy in [-hw + 1.0, hw - 1.0]:
			_wheel(Vector2(wx, wy), Vector2(12, 7))
	_shape(Rect2(-hl, -hw + 2, hl * 2.0, hw * 2.0 - 4), 5.0, color)
	draw_rect(Rect2(-hl + 4, -hw + 4, hl * 2.0 - 8, 2.5), Color(1, 1, 1, 0.22))
	_draw_decal(Rect2(-hl + 4, -hw + 5, hl * 2.0 - 8, hw * 2.0 - 10))
	# Windscreen, roof and rear window.
	draw_colored_polygon(PackedVector2Array([Vector2(8, -hw + 5), Vector2(3, -hw + 4), Vector2(3, hw - 4), Vector2(8, hw - 5)]), Color(0.1, 0.13, 0.2))
	_shape(Rect2(-12, -hw + 5, 15, hw * 2.0 - 10), 3.0, color.lightened(0.15))
	draw_rect(Rect2(-16, -hw + 6, 4, hw * 2.0 - 12), Color(0.1, 0.13, 0.2))
	_shape(Rect2(hl - 16, -3, 7, 6), 1.5, color.darkened(0.3))
	_shape(Rect2(-hl - 2, -hw + 1, 5, hw * 2.0 - 2), 2.0, color.darkened(0.45))
	draw_rect(Rect2(hl - 3, -hw + 3, 3, 5), Color(1, 1, 0.85))
	draw_rect(Rect2(hl - 3, hw - 8, 3, 5), Color(1, 1, 0.85))


## Decal painted on the body's top surface.
func _draw_decal(deck: Rect2) -> void:
	var cy := deck.get_center().y
	var paint := Color(1, 1, 1, 0.92)
	if color.get_luminance() > 0.7:
		paint = Color(0.1, 0.1, 0.14, 0.9)
	match decal:
		"stripes":
			draw_rect(Rect2(deck.position.x, cy - 3.5, deck.size.x, 2.2), paint)
			draw_rect(Rect2(deck.position.x, cy + 1.3, deck.size.x, 2.2), paint)
		"number":
			var r := minf(deck.size.y * 0.42, 7.0)
			var c := Vector2(deck.end.x - r - 2.0, cy)
			draw_circle(c, r + 1.2, OUTLINE)
			draw_circle(c, r, Color.WHITE)
			draw_set_transform(c, PI * 0.5)
			draw_string(ThemeDB.fallback_font, Vector2(-r, r * 0.55), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.5), Color(0.05, 0.05, 0.08))
			draw_set_transform(Vector2.ZERO)
		"checker":
			var sq := maxf(2.5, deck.size.y / 4.0)
			var x0 := deck.get_center().x - sq
			var rows := int(deck.size.y / sq)
			for col in 2:
				for row in rows:
					var dark := (col + row) % 2 == 0
					draw_rect(Rect2(x0 + col * sq, deck.position.y + row * sq, sq, sq), Color(0.05, 0.05, 0.07) if dark else Color.WHITE)
		"flames":
			for side in [-1.0, 1.0]:
				var edge: float = cy + side * deck.size.y * 0.5
				var pts := PackedVector2Array([Vector2(deck.end.x, edge)])
				var steps := 5
				for k in steps:
					var x := deck.end.x - deck.size.x * (k + 0.5) / steps * 0.9
					var depth := deck.size.y * (0.42 - 0.06 * k)
					pts.append(Vector2(x, edge - side * depth))
					pts.append(Vector2(x - deck.size.x * 0.06, edge - side * depth * 0.35))
				pts.append(Vector2(deck.position.x + deck.size.x * 0.1, edge))
				draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.95))
				var inner := PackedVector2Array()
				for p in pts:
					inner.append(Vector2(p.x, lerpf(edge, p.y, 0.55)))
				draw_colored_polygon(inner, Color(1.0, 0.85, 0.2, 0.95))
		"bolt":
			var x0 := deck.position.x
			var w := deck.size.x
			var h := deck.size.y * 0.35
			var bolt := PackedVector2Array([
				Vector2(x0, cy - h), Vector2(x0 + w * 0.45, cy - h * 0.2), Vector2(x0 + w * 0.4, cy + h * 0.5),
				Vector2(x0 + w, cy + h * 0.1),
			])
			draw_polyline(bolt, OUTLINE, 5.0, true)
			draw_polyline(bolt, Color(1.0, 0.9, 0.2), 2.8, true)
