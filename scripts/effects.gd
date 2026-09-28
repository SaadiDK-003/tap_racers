extends Node2D
## World effects drawn above the cars: smoke, sparks, speed trails, the "!" slip
## warning and the grid tags. Skid marks go on a separate layer under the cars.

const DrawLayer = preload("res://scripts/draw_layer.gd")
const Car = preload("res://scripts/car.gd")
const MAX_SKID_POINTS := 1600

var cars: Array = []
var show_tags := true
var leader = null # car currently in 1st place (null = none)
var skid_layer: Node2D # set by the owner; placed between the track and the cars

var _puffs: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _bolts: Array[Dictionary] = [] # lightning strikes {car, t, seed}
var _bubbles: Array[Dictionary] = [] # CPU speech bubbles {car, text, t}
const BUBBLE_TIME := 2.2
var _skids := PackedVector2Array()
var _glow_layer: Node2D
var _font: FontVariation
var _time := 0.0
const CROWN_TIME := 3.0 # seconds the crown shows after someone takes the lead
const CROWN_AHEAD := 40.0 # drawn this far in front of the car, so the car stays visible
static var _spot_tex: GradientTexture2D
var _spot_car = null # winner in the spotlight
var _spot_t := 0.0
var _firework_t := 0.0
var _crown_pop := 0.0 # bounces the crown when it appears
var _crown_t := 0.0 # time left to show the crown
var _last_leader = null


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 1.0
	_glow_layer = DrawLayer.new()
	_glow_layer.draw_fn = _draw_additive
	_glow_layer.material = Car.additive()
	add_child(_glow_layer)
	if skid_layer:
		skid_layer.draw_fn = _draw_skids


func puff(p: Vector2, col: Color, radius: float, vel := Vector2.ZERO, life := 0.7) -> void:
	_puffs.append({"p": p, "v": vel, "t": 0.0, "life": life, "r": radius, "c": col})


func burst(p: Vector2, car_color: Color) -> void:
	for i in 14:
		puff(p, Color(0.35, 0.35, 0.38, 0.7), randf_range(6, 13), Vector2.from_angle(randf() * TAU) * randf_range(30, 140), 1.0)
	for i in 22:
		var c := Color(1.0, 0.75, 0.3) if i % 3 != 0 else car_color
		_sparks.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(160, 420), "t": 0.0, "life": randf_range(0.3, 0.6), "c": c})


## Speech bubble above a car (CPU driver chatter).
func say(car, text: String) -> void:
	_bubbles = _bubbles.filter(func(b): return b.car != car)
	_bubbles.append({"car": car, "text": text, "t": 0.0})


## A lightning bolt striking down onto a car.
func bolt(car) -> void:
	_bolts.append({"car": car, "t": 0.0, "seed": randi()})
	for i in 10:
		_sparks.append({"p": car.position, "v": Vector2.from_angle(randf() * TAU) * randf_range(120, 260), "t": 0.0, "life": randf_range(0.2, 0.4), "c": Color(1.0, 0.95, 0.5)})


## Winner moment: a spotlight follows the car and fireworks burst around it.
func celebrate(car) -> void:
	_spot_car = car
	_spot_t = 3.2
	_firework_t = 0.0


func firework(p: Vector2, col: Color) -> void:
	_waves.append({"p": p, "t": 0.0, "c": col})
	for i in 26:
		var a := i * TAU / 26.0 + randf() * 0.1
		var c := col if i % 3 != 0 else Color(1.0, 0.95, 0.7)
		_sparks.append({"p": p, "v": Vector2.from_angle(a) * randf_range(230, 330), "t": 0.0, "life": randf_range(0.55, 0.85), "c": c})


static func _spotlight_texture() -> GradientTexture2D:
	if _spot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.6))
		g.add_point(0.05, Color(0, 0, 0, 0))
		g.add_point(0.12, Color(0, 0, 0, 0.55))
		_spot_tex = GradientTexture2D.new()
		_spot_tex.gradient = g
		_spot_tex.fill = GradientTexture2D.FILL_RADIAL
		_spot_tex.fill_from = Vector2(0.5, 0.5)
		_spot_tex.fill_to = Vector2(1.0, 0.5)
		_spot_tex.width = 256
		_spot_tex.height = 256
	return _spot_tex


## Expanding ring when a car fires its nitro.
func shockwave(p: Vector2, col: Color) -> void:
	_waves.append({"p": p, "t": 0.0, "c": col})
	for i in 12:
		_sparks.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(200, 380), "t": 0.0, "life": randf_range(0.25, 0.45), "c": col})


func skid(a: Vector2, b: Vector2) -> void:
	_skids.append(a)
	_skids.append(b)
	if _skids.size() > MAX_SKID_POINTS:
		_skids = _skids.slice(_skids.size() - MAX_SKID_POINTS)
	if skid_layer:
		skid_layer.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for q in _puffs:
		q.t += delta
		q.p += q.v * delta
		q.v *= 0.93
	_puffs = _puffs.filter(func(q): return q.t < q.life)
	for s in _sparks:
		s.t += delta
		s.p += s.v * delta
		s.v *= 0.9
	_sparks = _sparks.filter(func(s): return s.t < s.life)
	for b in _bolts:
		b.t += delta
	_bolts = _bolts.filter(func(b): return b.t < 0.4)
	for b in _bubbles:
		b.t += delta
	_bubbles = _bubbles.filter(func(b): return b.t < BUBBLE_TIME)
	for w in _waves:
		w.t += delta
	_waves = _waves.filter(func(w): return w.t < 0.45)
	if leader != _last_leader:
		_last_leader = leader
		_crown_pop = 1.0
		_crown_t = CROWN_TIME if leader != null else 0.0
	_crown_pop = maxf(0.0, _crown_pop - delta * 3.0)
	_crown_t = maxf(0.0, _crown_t - delta)
	if _spot_t > 0.0:
		_spot_t -= delta
		_firework_t -= delta
		if _firework_t <= 0.0 and _spot_t > 0.6:
			_firework_t = 0.35
			var p: Vector2 = _spot_car.position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 130.0)
			firework(p, _spot_car.color.lightened(randf_range(0.0, 0.3)))
			Sfx.play(Sfx.crash, -18.0, randf_range(1.8, 2.3))
	queue_redraw()
	_glow_layer.queue_redraw()


func _draw() -> void:
	if _spot_t > 0.0 and _spot_car != null:
		# Darken everything except a circle around the winner (fades in and out).
		var a := clampf(minf(3.2 - _spot_t, _spot_t) / 0.4, 0.0, 1.0)
		var r := 1500.0
		draw_texture_rect(_spotlight_texture(), Rect2(_spot_car.position - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
	for q in _puffs:
		var k: float = q.t / q.life
		var c: Color = q.c
		draw_circle(q.p, q.r * (1.0 + k * 1.4), Color(c, c.a * (1.0 - k)))
	# Icons above cars are drawn "screen-up" even when the whole world is rotated.
	var up: float = -(get_parent() as Node2D).rotation
	for car in cars:
		# Blinking "!" when a crash is close, so players learn to lift off.
		if car.state == Car.State.RACING and car.can_crash() and car.slip > 0.4 and int(_time * 10.0) % 2 == 0:
			draw_set_transform(car.position + Vector2(0, -34).rotated(up), up)
			draw_circle(Vector2.ZERO, 12.0, Color(0.02, 0.03, 0.05))
			draw_circle(Vector2.ZERO, 9.5, Color(1.0, 0.8, 0.1) if car.slip < 0.75 else Color(1.0, 0.25, 0.15))
			draw_string(_font, Vector2(-10, 6), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 17, Color(0.05, 0.05, 0.05))
	if _crown_visible():
		# In front of the new leader for a few seconds, then it fades away.
		var bob := sin(_time * 5.0) * 1.5
		var pop := 1.0 + 0.6 * _crown_pop
		draw_set_transform(_crown_pos() + Vector2(0, bob).rotated(up), up + sin(_time * 3.0) * 0.08, Vector2(pop, pop))
		_draw_crown(_crown_alpha())
	for b in _bubbles:
		_draw_bubble(b, up)
	draw_set_transform(Vector2.ZERO)
	if show_tags:
		for car in cars:
			draw_set_transform(car.position + Vector2(0, -35).rotated(up), up)
			draw_rect(Rect2(-16, -9, 32, 18), Color(car.color, 0.95))
			draw_string(_font, Vector2(-16, 5), "P%d" % (car.index + 1), HORIZONTAL_ALIGNMENT_CENTER, 32, 14, Color(0.05, 0.05, 0.08))
	draw_set_transform(Vector2.ZERO)


func _draw_bubble(b: Dictionary, up: float) -> void:
	var car = b.car
	var t: float = b.t
	var a := clampf(minf(t / 0.12, (BUBBLE_TIME - t) / 0.3), 0.0, 1.0)
	var pop := 0.8 + 0.2 * minf(1.0, t / 0.12)
	var text: String = b.text
	var fs := 13
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
	var h := 22.0
	draw_set_transform(car.position + Vector2(0, -44).rotated(up), up, Vector2(pop, pop))
	var box := Rect2(-w * 0.5, -h, w, h)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95 * a)
	style.set_corner_radius_all(10)
	style.border_color = Color(car.color.darkened(0.2), a)
	style.set_border_width_all(2)
	draw_style_box(style, box)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -1), Vector2(5, -1), Vector2(0, 7)]), Color(1, 1, 1, 0.95 * a))
	draw_string(_font, Vector2(-w * 0.5, -6), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0.08, 0.08, 0.12, a))


func _crown_visible() -> bool:
	return leader != null and _crown_t > 0.0 and leader.state != Car.State.CRASHED


func _crown_alpha() -> float:
	return clampf(_crown_t / 0.5, 0.0, 1.0) # fades out over the last half second


func _crown_pos() -> Vector2:
	return leader.position + Vector2.from_angle(leader.rotation) * CROWN_AHEAD * leader.scale.x


func _draw_crown(alpha := 1.0) -> void:
	var gold := Color(1.0, 0.8, 0.15, alpha)
	var outline := Color(0.02, 0.03, 0.05, alpha)
	var shape := PackedVector2Array([
		Vector2(-14, 8), Vector2(-15, -7), Vector2(-7, 0), Vector2(0, -12),
		Vector2(7, 0), Vector2(15, -7), Vector2(14, 8),
	])
	draw_colored_polygon(shape, gold)
	var loop := shape.duplicate()
	loop.append(shape[0])
	draw_polyline(loop, outline, 3.0, true)
	draw_rect(Rect2(-14, 3, 28, 5), gold.darkened(0.25))
	draw_line(Vector2(-14, 3), Vector2(14, 3), outline, 2.0)
	# Jewels on the tips and a shine.
	for tip in [Vector2(-15, -7), Vector2(0, -12), Vector2(15, -7)]:
		draw_circle(tip, 3.5, outline)
		draw_circle(tip, 2.3, Color(1.0, 0.3, 0.35, alpha))
	draw_circle(Vector2(0, 5.5), 2.0, Color(0.35, 0.8, 1.0, alpha))
	draw_line(Vector2(-9, -1), Vector2(-11, 5), Color(1, 1, 1, 0.6 * alpha), 2.0)


func _draw_additive(ci: CanvasItem) -> void:
	for car in cars:
		var pts: PackedVector2Array = car.trail
		if pts.size() < 2:
			continue
		var c: Color = Car.NITRO_COLOR if car.boosting else car.color
		var colors := PackedColorArray()
		for i in pts.size():
			colors.append(Color(c, 0.55 * float(i) / pts.size()))
		ci.draw_polyline_colors(pts, colors, 7.0 if car.boosting else 5.0, true)
	if _crown_visible():
		var p := _crown_pos()
		ci.draw_texture_rect(Car.glow_texture(), Rect2(p - Vector2(30, 30), Vector2(60, 60)), false, Color(1.0, 0.75, 0.2, 0.4 * _crown_alpha()))
	var sky: float = -(get_parent() as Node2D).rotation
	for b in _bolts:
		# Jagged bolt from off-screen "above" down to the car, flickering.
		var target: Vector2 = b.car.position
		var start: Vector2 = target + Vector2(0, -260).rotated(sky)
		var rng := RandomNumberGenerator.new()
		rng.seed = b.seed + int(b.t * 30.0)
		var pts := PackedVector2Array([start])
		for k in range(1, 7):
			var f := k / 7.0
			pts.append(start.lerp(target, f) + Vector2(rng.randf_range(-18, 18), 0).rotated(sky))
		pts.append(target)
		var a: float = 1.0 - b.t / 0.4
		ci.draw_polyline(pts, Color(1.0, 0.9, 0.3, 0.5 * a), 12.0, true)
		ci.draw_polyline(pts, Color(1.0, 1.0, 0.85, a), 4.0, true)
		ci.draw_texture_rect(Car.glow_texture(), Rect2(target - Vector2(40, 40), Vector2(80, 80)), false, Color(1.0, 0.9, 0.4, 0.6 * a))
	for w in _waves:
		var k: float = w.t / 0.45
		ci.draw_arc(w.p, 20.0 + 110.0 * k, 0.0, TAU, 48, Color(w.c, 0.9 * (1.0 - k)), 8.0 * (1.0 - k) + 2.0, true)
	for s in _sparks:
		var k: float = s.t / s.life
		var p: Vector2 = s.p
		var v: Vector2 = s.v
		ci.draw_line(p, p - v * 0.04, Color(s.c, 1.0 - k), 2.5)


func _draw_skids(ci: CanvasItem) -> void:
	if _skids.size() >= 2:
		ci.draw_multiline(_skids, Color(0.02, 0.02, 0.03, 0.35), 4.0)
