extends Node2D
## World effects drawn above the cars: smoke, sparks, speed trails, the "!" slip
## warning and the grid tags. Skid marks go on a separate layer under the cars.

const DrawLayer = preload("res://scripts/draw_layer.gd")
const Car = preload("res://scripts/car.gd")
const MAX_SKID_POINTS := 1600

var cars: Array = []
var show_tags := true
var leader = null # car currently in 1st place; gets a crown (null = no crown)
var skid_layer: Node2D # set by the owner; placed between the track and the cars

var _puffs: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _skids := PackedVector2Array()
var _glow_layer: Node2D
var _font: FontVariation
var _time := 0.0
var _crown_pop := 0.0 # bounces the crown when the lead changes
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
	for w in _waves:
		w.t += delta
	_waves = _waves.filter(func(w): return w.t < 0.45)
	if leader != _last_leader:
		_last_leader = leader
		_crown_pop = 1.0
	_crown_pop = maxf(0.0, _crown_pop - delta * 3.0)
	queue_redraw()
	_glow_layer.queue_redraw()


func _draw() -> void:
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
	if leader != null and leader.state != Car.State.CRASHED:
		# Sits right on the leader's car (screen-upright) so it's clear whose it is.
		var bob := sin(_time * 5.0) * 1.5
		var pop := 1.05 * (1.0 + 0.6 * _crown_pop)
		draw_set_transform(leader.position + Vector2(0, -4.0 + bob).rotated(up), up + sin(_time * 3.0) * 0.08, Vector2(pop, pop))
		_draw_crown()
	if show_tags:
		for car in cars:
			draw_set_transform(car.position + Vector2(0, -35).rotated(up), up)
			draw_rect(Rect2(-16, -9, 32, 18), Color(car.color, 0.95))
			draw_string(_font, Vector2(-16, 5), "P%d" % (car.index + 1), HORIZONTAL_ALIGNMENT_CENTER, 32, 14, Color(0.05, 0.05, 0.08))
	draw_set_transform(Vector2.ZERO)


func _draw_crown() -> void:
	var gold := Color(1.0, 0.8, 0.15)
	var outline := Color(0.02, 0.03, 0.05)
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
		draw_circle(tip, 2.3, Color(1.0, 0.3, 0.35))
	draw_circle(Vector2(0, 5.5), 2.0, Color(0.35, 0.8, 1.0))
	draw_line(Vector2(-9, -1), Vector2(-11, 5), Color(1, 1, 1, 0.6), 2.0)


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
	if leader != null and leader.state != Car.State.CRASHED:
		var p: Vector2 = leader.position
		ci.draw_texture_rect(Car.glow_texture(), Rect2(p - Vector2(34, 34), Vector2(68, 68)), false, Color(1.0, 0.75, 0.2, 0.4))
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
