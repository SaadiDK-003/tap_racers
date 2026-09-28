extends Node2D
## Boost pads: glowing arrow strips across the road at the start of long straights.
## Driving over one gives an instant speed kick. They're part of every track, with or
## without power-up items.

signal boosted(car)

const Car = preload("res://scripts/car.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

const MAX_PADS := 2
const STRAIGHT := 300.0 # road ahead of a pad that must be (nearly) straight
const PAD_LEN := 70.0
const COLOR := Color(0.2, 0.95, 1.0)
const COLOR_B := Color(1.0, 0.85, 0.2)

var track
var cars: Array = []
var pads: Array[float] = [] # distance along the loop where each pad starts
var _prev := {}
var _t := 0.0
var _glow: Node2D


## `avoid`: distances (e.g. item box spots) the pads should keep clear of.
func setup(track_node, avoid: Array[float] = []) -> void:
	track = track_node
	var L: float = track.length
	# Score every spot by how straight the road ahead of it is, then take the best
	# ones, spread around the lap. (Tracks are smooth curves, so "straight" means
	# gently curving; the pad's short crash protection covers the rest.)
	var scored: Array = []
	var s := 0.0
	while s < L:
		var ok := s > 150.0 and s < L - 170.0 # well clear of the start line and the grid
		for a in avoid:
			if absf(fposmod(s - a + L * 0.5, L) - L * 0.5) < 180.0:
				ok = false
		var worst := 0.0
		var x := -40.0
		while ok and x <= STRAIGHT:
			worst = maxf(worst, absf(track.curvature_at(s + x)))
			if track.on_bridge(s + x):
				ok = false
			x += 20.0
		if ok and worst < 1.0 / 220.0:
			scored.append([worst, s])
		s += 20.0
	scored.sort_custom(func(a, b): return a[0] < b[0])
	for c in scored:
		if pads.size() >= MAX_PADS:
			break
		var far := true
		for p in pads:
			if absf(fposmod(c[1] - p + L * 0.5, L) - L * 0.5) < L / 3.0:
				far = false
		if far:
			pads.append(c[1])
	_glow = DrawLayer.new()
	_glow.material = Car.additive()
	_glow.draw_fn = _draw_glow
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_glow.queue_redraw()


## Called every frame by the race, after the cars have moved.
func update_cars() -> void:
	var L: float = track.length
	for car in cars:
		var before: float = _prev.get(car, car.progress)
		var now: float = car.progress
		_prev[car] = now
		if car.state != Car.State.RACING or now <= before:
			continue
		for p in pads:
			var mid := p + PAD_LEN * 0.5
			if floorf((before - mid) / L) != floorf((now - mid) / L):
				car.boost_pad()
				boosted.emit(car)


func _draw() -> void:
	var w: float = track.map.road_width
	for p in pads:
		# Dark base strip, then three animated chevrons.
		var base := PackedVector2Array()
		for k in 7:
			base.append(track.point_at(p + PAD_LEN * k / 6.0, -w * 0.5 + 6.0))
		for k in 7:
			base.append(track.point_at(p + PAD_LEN * (6 - k) / 6.0, w * 0.5 - 6.0))
		draw_colored_polygon(base, Color(0.05, 0.08, 0.12, 0.7))
		for c in 3:
			var phase := fposmod(_t * 2.2 - c * 0.33, 1.0)
			var a := 0.35 + 0.65 * (1.0 - phase)
			_chevron(p + 12.0 + c * 20.0, w, Color(COLOR if c != 1 else COLOR_B, a))


func _chevron(s: float, w: float, col: Color) -> void:
	var tip: Vector2 = track.point_at(s + 12.0, 0.0)
	var l_out: Vector2 = track.point_at(s, -w * 0.4)
	var r_out: Vector2 = track.point_at(s, w * 0.4)
	var l_in: Vector2 = track.point_at(s - 8.0, -w * 0.4)
	var r_in: Vector2 = track.point_at(s - 8.0, w * 0.4)
	var tip_in: Vector2 = track.point_at(s + 4.0, 0.0)
	draw_colored_polygon(PackedVector2Array([l_in, l_out, tip, r_out, r_in, tip_in]), col)


func _draw_glow(ci: CanvasItem) -> void:
	for p in pads:
		var c: Vector2 = track.point_at(p + PAD_LEN * 0.5, 0.0)
		var pulse := 0.25 + 0.1 * sin(_t * 5.0)
		ci.draw_texture_rect(Car.glow_texture(), Rect2(c - Vector2(70, 70), Vector2(140, 140)), false, Color(COLOR, pulse))
