extends Node2D
## Builds a smooth closed circuit from a map definition, draws it, and answers
## geometry queries (position / direction / curvature at a distance along the loop).

const DrawLayer = preload("res://scripts/draw_layer.gd")
const Scenery = preload("res://scripts/scenery.gd")
const STEP := 4.0

var map
var lane_offsets: Array[float] = []
var length := 0.0

var _n := 0
var _step := STEP
var _pos := PackedVector2Array()
var _tan := PackedVector2Array()
var _curv := PackedFloat32Array()
var _runs: Array[PackedInt32Array] = [] # sample indices of each corner (for curbs, tire walls)
var _props: Array[Dictionary] = []
var _scenery_layer: Node2D
var night := false # darkens the bridge deck (it's drawn above the night overlay)
var _deck_layer: Node2D
var _bridge_s := -1.0 # distance along the loop of the bridge's middle (-1 = no bridge)


func setup(map_def, offsets: Array[float]) -> void:
	map = map_def
	lane_offsets = offsets
	_build_curve()
	_runs = _find_corner_runs()
	_find_bridge()
	_find_jump()
	# Scenery is placed when the track is fitted to the screen (see rebuild_scenery),
	# since parking lots depend on what's visible. Building it here too was wasted work.
	_build_visuals()


# --- Geometry queries -------------------------------------------------------

func point_at(s: float, offset := 0.0) -> Vector2:
	var f := fposmod(s, length) / _step
	var i := int(f) % _n
	var j := (i + 1) % _n
	var t := f - floorf(f)
	var tg := _tan[i].lerp(_tan[j], t).normalized()
	return _pos[i].lerp(_pos[j], t) + Vector2(-tg.y, tg.x) * offset


func tangent_at(s: float) -> Vector2:
	var f := fposmod(s, length) / _step
	var i := int(f) % _n
	return _tan[i].lerp(_tan[(i + 1) % _n], f - floorf(f)).normalized()


## Signed curvature (1 / radius). Positive means the road bends toward the +normal side.
func curvature_at(s: float) -> float:
	var f := fposmod(s, length) / _step
	var i := int(f) % _n
	return lerpf(_curv[i], _curv[(i + 1) % _n], f - floorf(f))


## Regenerates the scenery for what's on screen: {visible: polygon, keepouts: [[p, r]]}.
func rebuild_scenery(view: Dictionary) -> void:
	_props = Scenery.build(self, map, view)
	if _scenery_layer:
		_scenery_layer.queue_redraw()
	if _bake_vp:
		_bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Colour of the weather overlay (night / rain) to paint onto the bridge deck, which
## is drawn above the world's overlay layer.
var deck_overlay := Color(0, 0, 0, 0)


func set_deck_overlay(c: Color) -> void:
	deck_overlay = c
	night = c.a > 0.0
	if _deck_vp:
		_deck_root.get_child(0).queue_redraw()
		_deck_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Glowing scenery for night races: [position, radius, colour] for lava, vents,
## cracks and neon signs.
func glow_points() -> Array:
	var out := []
	for prop in _props:
		match prop.k:
			"lava": out.append([prop.p, prop.r * 2.2, Color(1.0, 0.45, 0.1, 0.55)])
			"vent": out.append([prop.p, prop.r * 2.5, Color(1.0, 0.4, 0.1, 0.45)])
			"crack": out.append([prop.p, prop.r * 1.4, Color(1.0, 0.4, 0.1, 0.3)])
			"module": out.append([prop.p, prop.r * 1.8, Color(0.5, 0.8, 1.0, 0.35)])
			"crane": out.append([prop.p, 40.0, Color(1.0, 0.85, 0.5, 0.35)])
			"neon_sign": out.append([prop.p, prop.r * 2.4, Color(Scenery.NEON_COLORS[absi(int(prop.seed)) % Scenery.NEON_COLORS.size()], 0.5)])
	return out


## Street lamps in the scenery (they glow at night).
func lamp_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for prop in _props:
		if prop.k == "lamp":
			out.append(prop.p)
		elif prop.k == "grandstand":
			out.append(prop.p)
	return out


# --- Jump over water ------------------------------------------------------------

const JUMP_RAMP := 40.0 # length of the take-off and landing ramps
const JUMP_GAP := 120.0 # length of open water between the ramps
var _jump_s := -1.0 # distance along the loop of the middle of the gap (-1 = none)
var _river_from := 0.0 # river extent across the road (negative side .. positive side)
var _river_to := 0.0


func has_jump() -> bool:
	return _jump_s >= 0.0


## Distance along the loop where cars leave the ground (end of the take-off ramp).
func jump_lip() -> float:
	return fposmod(_jump_s - JUMP_GAP * 0.5, length)


## 0..1 across the water gap, or -1 when `s` isn't over the gap.
func jump_fraction(s: float) -> float:
	if _jump_s < 0.0:
		return -1.0
	var d := fposmod(s - jump_lip(), length)
	return d / JUMP_GAP if d <= JUMP_GAP else -1.0


## Distance from `s` ahead to the take-off lip (0..length).
func dist_to_lip(s: float) -> float:
	return fposmod(jump_lip() - s, length)


## True anywhere on the ramps or the gap (keep items and mines away from here).
func in_jump_zone(s: float) -> bool:
	if _jump_s < 0.0:
		return false
	var d := fposmod(s - jump_lip() + JUMP_RAMP + 30.0, length)
	return d <= JUMP_GAP + (JUMP_RAMP + 30.0) * 2.0


const JUMP_RIVER := 900.0 # how far the river runs either side of the road


## Sideways wiggle of the river along its length (0 at the road, so the gap stays put).
func _river_bend(t: float) -> float:
	return sin(t * 0.006) * 70.0 * clampf(absf(t) / 200.0, 0.0, 1.0)


## Points along the river's centre line (for keeping scenery out of the water).
func river_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _jump_s < 0.0:
		return out
	var cj: Vector2 = point_at(_jump_s, 0.0)
	var along: Vector2 = tangent_at(_jump_s)
	var across := Vector2(-along.y, along.x)
	var t := _river_from
	while t <= _river_to:
		out.append(cj + across * t + along * _river_bend(t))
		t += 45.0
	return out


func _find_jump() -> void:
	var jp: Vector2 = map.jump_point
	if not jp.is_finite():
		return
	var best := 0
	for i in _n:
		if _pos[i].distance_to(jp) < _pos[best].distance_to(jp):
			best = i
	_jump_s = best * _step
	# Work out how far the river can run on each side before it would touch another
	# part of the road: the outer side runs off into the canyon, the infield side stops.
	var cj: Vector2 = point_at(_jump_s, 0.0)
	var along: Vector2 = tangent_at(_jump_s)
	var across := Vector2(-along.y, along.x)
	var limits: Array[float] = []
	for side in [-1.0, 1.0]:
		var t := 0.0
		var reach := JUMP_RIVER
		while t < JUMP_RIVER:
			t += 20.0
			var q: Vector2 = cj + across * side * t + along * _river_bend(side * t)
			var clear := true
			for i in range(0, _n, 2):
				var ds := absf(fposmod(i * _step - _jump_s + length * 0.5, length) - length * 0.5)
				if ds > JUMP_GAP + 200.0 and _pos[i].distance_to(q) < map.road_width * 0.5 + JUMP_GAP * 0.5 + 60.0:
					clear = false
					break
			if not clear:
				reach = maxf(map.road_width * 0.5 + 40.0, t - 40.0)
				break
		limits.append(reach)
	_river_from = -limits[0]
	_river_to = limits[1]


## River under the gap and striped ramps on either side, painted over the road.
func _draw_jump(ci: CanvasItem) -> void:
	if _jump_s < 0.0:
		return
	var w: float = map.road_width
	var lip := jump_lip()
	var land := lip + JUMP_GAP
	# A winding river crosses the whole canyon under the gap: sandy banks, water, ripples.
	var cj: Vector2 = point_at(_jump_s, 0.0)
	var along: Vector2 = tangent_at(_jump_s)
	var across := Vector2(-along.y, along.x)
	# The infield end is a round pond (a river can't cross the track a second time).
	var pond_t := _river_from if absf(_river_from) < absf(_river_to) else _river_to
	for layer in 2:
		var half := JUMP_GAP * 0.5 + (10.0 if layer == 0 else 0.0)
		var col := Color(0.72, 0.6, 0.42) if layer == 0 else Color(0.14, 0.42, 0.62)
		var poly := PackedVector2Array()
		var steps := 40
		for k in steps + 1:
			var t := lerpf(_river_from, _river_to, float(k) / steps)
			poly.append(cj + across * t + along * (_river_bend(t) - half))
		for k in steps + 1:
			var t := lerpf(_river_to, _river_from, float(k) / steps)
			poly.append(cj + across * t + along * (_river_bend(t) + half))
		ci.draw_colored_polygon(poly, col)
		ci.draw_circle(cj + across * pond_t + along * _river_bend(pond_t), half * 1.25, col)
	for k in 12:
		var t := lerpf(_river_from, _river_to, (k + 0.5) / 12.0)
		var q: Vector2 = cj + across * t + along * (_river_bend(t) + (k % 3 - 1) * JUMP_GAP * 0.25)
		ci.draw_line(q - across * 16.0, q + across * 16.0, Color(0.55, 0.8, 0.95, 0.6), 3.0, true)
	# Ramps: yellow/black warning stripes, brighter towards the edge of the gap.
	for r in [[lip - JUMP_RAMP, lip], [land, land + JUMP_RAMP]]:
		var s0: float = r[0]
		var s1: float = r[1]
		var quad := PackedVector2Array([point_at(s0, -w * 0.5), point_at(s1, -w * 0.5), point_at(s1, w * 0.5), point_at(s0, w * 0.5)])
		ci.draw_colored_polygon(quad, Color(0.35, 0.35, 0.38))
		var n := 7
		for k in n:
			var a0 := -w * 0.5 + w * k / n
			var a1 := a0 + w / n
			var stripe := PackedVector2Array([point_at(s0, a0), point_at(s0, a1), point_at(s1, a1 - w / n * 0.6), point_at(s1, a0 - w / n * 0.6)])
			ci.draw_colored_polygon(stripe, Color(1.0, 0.8, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.1))
		var edge := s1 if s0 < lip else s0
		ci.draw_line(point_at(edge, -w * 0.5), point_at(edge, w * 0.5), Color(0.95, 0.95, 0.95), 4.0)


func has_bridge() -> bool:
	return _bridge_s >= 0.0


## True while `s` is on the raised section of a figure-8.
func on_bridge(s: float) -> bool:
	if _bridge_s < 0.0:
		return false
	var d := absf(fposmod(s - _bridge_s + length * 0.5, length) - length * 0.5)
	return d < map.bridge_half


func _find_bridge() -> void:
	var bp: Vector2 = map.bridge_point
	if not bp.is_finite():
		return
	# The loop passes the crossing twice; find the closest sample of each pass.
	var passes: Array[int] = []
	var i := 0
	while i < _n:
		if _pos[i].distance_to(bp) < 30.0:
			var best := i
			while i < _n and _pos[i].distance_to(bp) < 30.0:
				if _pos[i].distance_to(bp) < _pos[best].distance_to(bp):
					best = i
				i += 1
			passes.append(best)
		i += 1
	if passes.size() >= 2:
		_bridge_s = passes[clampi(map.bridge_pass, 0, passes.size() - 1)] * _step


## Centerline sample points.
func points() -> PackedVector2Array:
	return _pos


## Each corner as {s: distance at its middle, side: +1/-1 outside of the bend}.
func corners() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in _runs:
		var mid := r[r.size() / 2]
		out.append({"s": mid * _step, "side": -signf(_curv[mid])})
	return out


## Area covered by the road and curbs, in track coordinates.
func bounds() -> Rect2:
	var r := Rect2(_pos[0], Vector2.ZERO)
	for p in _pos:
		r = r.expand(p)
	return r.grow(map.road_width * 0.5 + 18.0)


# --- Construction -----------------------------------------------------------

func _build_curve() -> void:
	var pts: PackedVector2Array = map.points
	var cnt := pts.size()
	var curve := Curve2D.new()
	curve.bake_interval = 2.0
	for i in cnt + 1:
		# Catmull-Rom style handles for a smooth loop through every point.
		var p := pts[i % cnt]
		var handle := (pts[(i + 1) % cnt] - pts[(i - 1 + cnt) % cnt]) / 6.0
		curve.add_point(p, -handle, handle)

	length = curve.get_baked_length()
	_n = int(length / STEP)
	_step = length / _n
	_pos.resize(_n)
	_tan.resize(_n)
	for i in _n:
		_pos[i] = curve.sample_baked(i * _step, true)
	for i in _n:
		_tan[i] = (_pos[(i + 1) % _n] - _pos[(i - 1 + _n) % _n]).normalized()

	# Curvature measured over a ~60px window, then smoothed heavily so the
	# speed limit changes gradually through a corner instead of jumping around.
	var k := 8
	var raw := PackedFloat32Array()
	raw.resize(_n)
	for i in _n:
		raw[i] = _tan[(i - k + _n) % _n].angle_to(_tan[(i + k) % _n]) / (2.0 * k * _step)
	for _pass in 4:
		var smooth := PackedFloat32Array()
		smooth.resize(_n)
		for i in _n:
			var sum := 0.0
			for j in range(-6, 7):
				sum += raw[(i + j + _n) % _n]
			smooth[i] = sum / 13.0
		raw = smooth
	_curv = raw


func _offset_point(i: int, offset: float) -> Vector2:
	var tg := _tan[i]
	return _pos[i] + Vector2(-tg.y, tg.x) * offset


# Everything static (ground, road, curbs, lane lines, scenery: thousands of shapes)
# is drawn once into an off-screen texture, and each frame just draws that one image.
# This is what keeps phones smooth. The bake covers the visible screen area at
# screen resolution and is refreshed when the view changes (see bake()).
var _bake_vp: SubViewport
var _bake_root: Node2D
var _baked: Sprite2D
var _bake_rect := Rect2()
var _deck_vp: SubViewport
var _deck_root: Node2D


func _build_visuals() -> void:
	# Plain ground colour around the baked image (seen only during screen shake).
	_add_layer(func(ci): ci.draw_rect(Rect2(-4000, -4000, 9000, 9000), map.ground), self)
	_bake_vp = SubViewport.new()
	_bake_vp.disable_3d = true
	_bake_vp.transparent_bg = false
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_bake_vp)
	_bake_root = Node2D.new()
	_bake_vp.add_child(_bake_root)
	_add_layer(_draw_ground, _bake_root)
	# Drop shadow: drawn opaque inside a CanvasGroup, which then fades the whole group
	# at once, so overlapping discs don't stack up darker.
	var shadow := CanvasGroup.new()
	shadow.self_modulate = Color(1, 1, 1, 0.35)
	shadow.position = Vector2(0, 10)
	_bake_root.add_child(shadow)
	_add_layer(func(ci): _draw_band(ci, map.road_width + 40.0, Color.BLACK), shadow)
	_add_layer(_draw_curbs, _bake_root)
	_add_layer(func(ci): _draw_band(ci, map.road_width, map.road), _bake_root)
	_add_layer(_draw_details, _bake_root)
	_add_layer(_draw_jump, _bake_root)
	_scenery_layer = _add_layer(func(ci): Scenery.draw_all(ci, _props), _bake_root)
	_baked = Sprite2D.new()
	_baked.centered = false
	_baked.texture = _bake_vp.get_texture()
	add_child(_baked)
	if has_bridge():
		# The deck gets its own baked image, drawn above the cars passing underneath.
		_deck_vp = SubViewport.new()
		_deck_vp.disable_3d = true
		_deck_vp.transparent_bg = true
		_deck_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_deck_vp)
		_deck_root = Node2D.new()
		_deck_vp.add_child(_deck_root)
		_add_layer(_draw_bridge, _deck_root)
		var deck := Sprite2D.new()
		deck.centered = false
		deck.texture = _deck_vp.get_texture()
		# Baked at screen resolution, so draw it pixel-for-pixel: smoothing would blend
		# its edge with the transparent pixels around it and leave a dark seam line.
		deck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		deck.z_index = 1
		add_child(deck)
		_deck_layer = deck
	bake(bounds().grow(400.0), 1.0)


## Re-renders the static layers for `area` (track coordinates) at `pixels_per_unit`.
func bake(area: Rect2, pixels_per_unit: float) -> void:
	var k := pixels_per_unit
	k = minf(k, minf(4096.0 / area.size.x, 4096.0 / area.size.y))
	_bake_rect = area
	_bake_vp.size = Vector2i(maxi(1, ceili(area.size.x * k)), maxi(1, ceili(area.size.y * k)))
	_bake_root.scale = Vector2(k, k)
	_bake_root.position = -area.position * k
	_baked.position = area.position
	_baked.scale = Vector2(1.0 / k, 1.0 / k)
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _deck_vp:
		var d := _deck_area()
		var kd := minf(pixels_per_unit, minf(2048.0 / d.size.x, 2048.0 / d.size.y))
		_deck_vp.size = Vector2i(ceili(d.size.x * kd), ceili(d.size.y * kd))
		_deck_root.scale = Vector2(kd, kd)
		_deck_root.position = -d.position * kd
		(_deck_layer as Sprite2D).position = d.position
		(_deck_layer as Sprite2D).scale = Vector2(1.0 / kd, 1.0 / kd)
		_deck_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Area covered by the bridge deck, its railings and its shadow.
func _deck_area() -> Rect2:
	var half: float = map.bridge_half
	var r := Rect2(point_at(_bridge_s), Vector2.ZERO)
	var s := _bridge_s - half
	while s <= _bridge_s + half:
		r = r.expand(point_at(s))
		s += 10.0
	return r.grow(map.road_width * 0.5 + 34.0)


func _add_layer(fn: Callable, parent: Node) -> Node2D:
	var layer := DrawLayer.new()
	layer.draw_fn = fn
	parent.add_child(layer)
	return layer


## A band of `width` along the centre line, drawn as overlapping discs. Unlike a thick
## line, its edges stay perfectly smooth on bends tighter than half its width.
func _draw_band(ci: CanvasItem, width: float, color: Color) -> void:
	var r := width * 0.5
	for i in _n:
		ci.draw_circle(_pos[i], r, color, true, -1.0, true)


# --- Drawing ----------------------------------------------------------------

func _draw_ground(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-3000, -3000, 6720, 7280), map.ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = map.blob_seed
	var style := StyleBoxFlat.new()
	style.bg_color = map.blob
	for i in map.blob_count:
		var sz := Vector2(rng.randf_range(140, 300), rng.randf_range(140, 320))
		var p := Vector2(rng.randf_range(-300, 900), rng.randf_range(-200, 1400))
		style.set_corner_radius_all(int(minf(sz.x, sz.y) * 0.3))
		ci.draw_style_box(style, Rect2(p, sz))
	# Subtle dot grid around the circuit.
	var area := bounds().grow(500.0)
	var dot: Color = map.ground.darkened(0.06) if map.ground.get_luminance() > 0.5 else map.ground.lightened(0.07)
	for x in range(int(area.position.x), int(area.end.x), 44):
		for y in range(int(area.position.y), int(area.end.y), 44):
			ci.draw_rect(Rect2(x, y, 3, 3), dot)


func _find_corner_runs() -> Array[PackedInt32Array]:
	var threshold := 1.0 / 240.0
	var start := 0
	for i in _n:
		if absf(_curv[i]) < threshold:
			start = i
			break
	var runs: Array[PackedInt32Array] = []
	var run := PackedInt32Array()
	var run_sign := 0.0
	for j in _n + 1:
		var i := (start + j) % _n
		var k := _curv[i]
		var inside := absf(k) >= threshold and (run.is_empty() or signf(k) == run_sign)
		if inside:
			if run.is_empty():
				run_sign = signf(k)
			run.append(i)
		elif not run.is_empty():
			if run.size() >= 6:
				runs.append(run)
			run = PackedInt32Array()
	return runs


## Red/white curbs on the outside of every corner, with rounded ends.
func _draw_curbs(ci: CanvasItem) -> void:
	var off: float = map.road_width * 0.5 + 6.0
	var pad := 5
	for r in _runs:
		var side := -signf(_curv[r[r.size() / 2]])
		var pts := PackedVector2Array()
		for j in range(-pad, r.size() + pad):
			pts.append(_offset_point((r[0] + j + _n) % _n, off * side))
		ci.draw_polyline(pts, map.curb_a, 14.0)
		var stripe := 3
		for j in range(0, pts.size() - stripe, stripe * 2):
			ci.draw_polyline(pts.slice(j, j + stripe + 1), map.curb_b, 14.0)
		ci.draw_circle(pts[0], 7.0, map.curb_b)
		ci.draw_circle(pts[pts.size() - 1], 7.0, map.curb_b)


## The raised deck of a figure-8, drawn above the road (and cars) passing underneath.
## It rises smoothly out of the road: same surface colour, and a shadow that grows
## from nothing at the ramps to full height in the middle, so there are no seams.
func _draw_bridge(ci: CanvasItem) -> void:
	var w: float = map.road_width
	var half: float = map.bridge_half
	var i0 := int((_bridge_s - half) / _step)
	var i1 := int((_bridge_s + half) / _step)
	var count := i1 - i0
	var center := PackedVector2Array()
	var shadow := PackedVector2Array()
	var shade := PackedColorArray()
	for k in count + 1:
		var idx := (i0 + k + _n) % _n
		var height := sin(PI * float(k) / count) # 0 at the ramps, 1 in the middle
		center.append(_pos[idx])
		shadow.append(_pos[idx] + Vector2(14, 18) * height)
		# Fades in with height, so nothing shows where the ramps meet the road.
		shade.append(Color(0, 0, 0, 0.4 * height * height))
	ci.draw_polyline_colors(shadow, shade, w, true)
	# No anti-aliasing on the deck surface: its edges sit exactly on the road below,
	# and an AA fringe would show as a thin seam across the road at the ramp ends.
	ci.draw_polyline(center, map.road, w, false)
	for off in lane_offsets:
		var lane := PackedVector2Array()
		for k in count + 1:
			lane.append(_offset_point((i0 + k + _n) % _n, off))
		ci.draw_polyline(lane, map.lane, 4.0, true)
	# Railings only along the raised middle part, fading in from the ramps.
	var r0 := int(count * 0.18)
	var r1 := int(count * 0.82)
	for side in [-1.0, 1.0]:
		var rail := PackedVector2Array()
		for k in range(r0, r1 + 1):
			rail.append(_offset_point((i0 + k + _n) % _n, side * (w * 0.5 + 3.0)))
		ci.draw_polyline(rail, Color(0.1, 0.1, 0.12), 9.0, true)
		ci.draw_polyline(rail, Color(0.85, 0.87, 0.92), 5.0, true)
		for k in range(0, rail.size(), 6):
			ci.draw_circle(rail[k], 4.0, Color(0.3, 0.32, 0.38))
	# Weather overlay painted onto the deck itself (it's drawn above the world overlay).
	if deck_overlay.a > 0.0:
		ci.draw_polyline(center, deck_overlay, w + 16.0, false)


func _draw_details(ci: CanvasItem) -> void:
	# One guide line per lane, like the slot in a slot-car track.
	for off in lane_offsets:
		var pts := PackedVector2Array()
		for i in _n + 1:
			pts.append(_offset_point(i % _n, off))
		ci.draw_polyline(pts, map.lane, 4.0, true)

	# Checkered start/finish line at s = 0.
	var w: float = map.road_width
	ci.draw_set_transform(_pos[0], _tan[0].angle())
	var cols := 6
	var sq := w / cols
	for x in 2:
		for y in cols:
			var col := Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.06)
			ci.draw_rect(Rect2(x * sq * 0.9, -w * 0.5 + y * sq, sq * 0.9, sq), col)
	ci.draw_set_transform(Vector2.ZERO)
