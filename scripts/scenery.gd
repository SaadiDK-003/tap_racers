extends RefCounted
## Procedural trackside scenery. Fills the empty ground around and inside the circuit
## with props for the map's theme, plus a grandstand at the start line and tire walls
## on the outside of corners. Everything is placed once (seeded, so a map always looks
## the same) and drawn into one static layer.

const OUTLINE := Color(0.02, 0.03, 0.05, 0.9)
const SHADOW := Color(0, 0, 0, 0.28)
const SHADOW_OFFSET := Vector2(5, 7)
const CELL := 20.0 # distance-field cell size
const FIELD_CAP := 220.0

# Per theme: [kind, weight, min radius, max radius, optional max count]
const THEMES := {
	"city": [["building", 6, 36, 64], ["house", 4, 22, 32], ["tree", 3, 14, 20], ["lamp", 1, 7, 7, 14]],
	"forest": [["tree", 9, 18, 32], ["bush", 4, 10, 15], ["flowers", 1, 10, 14, 8], ["pond", 1, 55, 95], ["log", 1, 16, 20]],
	"desert": [["rock", 7, 12, 34], ["cactus", 4, 11, 16], ["dune", 2, 60, 110], ["bones", 1, 12, 12]],
	"snow": [["pine", 9, 16, 30], ["snow_rock", 4, 12, 24], ["frozen_pond", 1, 55, 90], ["snowman", 1, 12, 12, 4]],
	"beach": [["palm", 7, 20, 30], ["umbrella", 2, 14, 18, 6], ["towel", 2, 12, 14, 6], ["lagoon", 1, 60, 100]],
	"volcano": [["rock", 7, 12, 32], ["lava", 4, 28, 55, 9], ["vent", 3, 10, 14, 10], ["crack", 3, 30, 50, 12]],
	"neon": [["building", 6, 36, 64], ["neon_sign", 5, 26, 40, 14], ["lamp", 2, 7, 7, 14]],
	"space": [["stars", 8, 26, 40], ["module", 4, 30, 48, 10], ["satellite", 3, 16, 20, 8], ["planet", 1, 45, 80, 3], ["rock", 3, 10, 22]],
	"farm": [["field", 7, 50, 85, 14], ["tree", 6, 16, 26], ["barn", 3, 34, 46, 5], ["hay", 2, 9, 12, 8], ["cow", 2, 10, 10, 8], ["fence", 2, 30, 40, 8]],
	"harbor": [["yard", 8, 42, 60, 16], ["water", 3, 50, 90, 6], ["boat", 3, 22, 30, 8], ["crane", 3, 34, 42, 6], ["crate", 3, 8, 11, 14], ["lamp", 2, 7, 7, 12]],
}
# Kinds that lie flat on the ground and are drawn first.
const FLAT := ["stars", "field", "water", "parking", "pond", "frozen_pond", "lagoon", "dune", "towel", "flowers", "shell", "bones", "lava", "crack"]
const NEON_COLORS := [Color(1.0, 0.25, 0.7), Color(0.2, 0.9, 1.0), Color(0.65, 0.4, 1.0), Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.5)]
const CAR_COLORS := [
	Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.92, 0.92, 0.95), Color(0.2, 0.2, 0.24),
	Color(0.95, 0.75, 0.2), Color(0.3, 0.7, 0.4), Color(0.6, 0.62, 0.68), Color(0.55, 0.3, 0.7),
]

const PALETTES := {
	"city": [Color(0.2, 0.24, 0.32), Color(0.26, 0.22, 0.3), Color(0.18, 0.27, 0.3), Color(0.3, 0.27, 0.24)],
	"forest": [Color(0.16, 0.42, 0.2), Color(0.2, 0.5, 0.22), Color(0.12, 0.35, 0.2), Color(0.3, 0.52, 0.2)],
	"desert": [Color(0.55, 0.3, 0.2), Color(0.48, 0.27, 0.2), Color(0.62, 0.38, 0.24)],
	"snow": [Color(0.13, 0.35, 0.3), Color(0.16, 0.4, 0.33), Color(0.1, 0.3, 0.28)],
	"beach": [Color(0.95, 0.35, 0.3), Color(0.3, 0.65, 0.95), Color(1.0, 0.8, 0.25), Color(0.4, 0.85, 0.5)],
	"volcano": [Color(0.22, 0.18, 0.18), Color(0.28, 0.22, 0.2), Color(0.18, 0.15, 0.16)],
	"neon": [Color(0.14, 0.12, 0.2), Color(0.18, 0.14, 0.24), Color(0.12, 0.13, 0.2)], # dark towers; signs glow
	"space": [Color(0.42, 0.44, 0.5), Color(0.36, 0.38, 0.46), Color(0.5, 0.48, 0.52)],
	"farm": [Color(0.3, 0.52, 0.2), Color(0.36, 0.58, 0.22), Color(0.26, 0.46, 0.2)],
	"harbor": [Color(0.85, 0.3, 0.2), Color(0.2, 0.5, 0.8), Color(0.95, 0.7, 0.15), Color(0.25, 0.65, 0.4), Color(0.9, 0.9, 0.9)],

}


static func build(track, map, view := {}) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(map.blob_seed) * 7919 + 17
	var field := _distance_field(track)
	var props: Array[Dictionary] = []
	var grid := {}
	var road_half: float = map.road_width * 0.5

	# Keep every prop out of the river (invisible placeholder props along it).
	for q in track.river_points():
		_register(grid, props, {"k": "river_space", "p": q, "r": track.jump_gap * 0.5 + 30.0, "rot": 0.0, "seed": 0, "c": Color.WHITE})
	# ...and off the railway (and its tunnel mound).
	for q in track.rail_points():
		_register(grid, props, {"k": "river_space", "p": q, "r": track.RAIL_HALF + 34.0, "rot": 0.0, "seed": 0, "c": Color.WHITE})
	_add_grandstand(track, map, field, props, grid)
	_add_parking_lots(track, map, field, props, grid, rng, view)
	_add_tire_walls(track, map, field, props, grid)

	var kinds: Array = THEMES.get(map.scenery, THEMES["forest"])
	var palette: Array = PALETTES.get(map.scenery, PALETTES["forest"])
	if not map.scenery_palette.is_empty():
		palette = map.scenery_palette
	var total_weight := 0
	for k in kinds:
		total_weight += int(k[1])
	var area: Rect2 = track.bounds().grow(260.0)
	var target := int(area.get_area() / 6500.0 * map.scenery_density)
	var counts := {}
	var tries := 0
	while props.size() < target and tries < target * 8:
		tries += 1
		var pick := rng.randi() % total_weight
		var kind: Array = kinds[0]
		for k in kinds:
			pick -= int(k[1])
			if pick < 0:
				kind = k
				break
		if kind.size() > 4 and counts.get(kind[0], 0) >= int(kind[4]):
			continue
		var r := rng.randf_range(float(kind[2]), float(kind[3]))
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _field_dist(field, p) < road_half + 22.0 + r:
			continue
		if _overlaps(grid, props, p, r):
			continue
		counts[kind[0]] = counts.get(kind[0], 0) + 1
		_register(grid, props, {
			"k": kind[0], "p": p, "r": r, "rot": rng.randf() * TAU, "seed": rng.randi(),
			"c": palette[rng.randi() % palette.size()],
		})

	props.sort_custom(func(a, b):
		var fa: bool = FLAT.has(a.k)
		var fb: bool = FLAT.has(b.k)
		if fa != fb:
			return fa
		return a.p.y < b.p.y)
	return props


# --- Placement helpers ------------------------------------------------------

## Coarse distance-to-road grid, so thousands of placement checks stay cheap.
static func _distance_field(track) -> Dictionary:
	var b: Rect2 = track.bounds().grow(FIELD_CAP + 300.0)
	var w := int(b.size.x / CELL) + 1
	var h := int(b.size.y / CELL) + 1
	var d := PackedFloat32Array()
	d.resize(w * h)
	d.fill(FIELD_CAP)
	var pts: PackedVector2Array = track.points()
	var reach := int(FIELD_CAP / CELL) + 1
	for i in range(0, pts.size(), 3):
		var p := pts[i]
		var cx := int((p.x - b.position.x) / CELL)
		var cy := int((p.y - b.position.y) / CELL)
		for y in range(maxi(0, cy - reach), mini(h, cy + reach + 1)):
			for x in range(maxi(0, cx - reach), mini(w, cx + reach + 1)):
				var center := b.position + Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
				var dist := center.distance_to(p)
				var idx := y * w + x
				if dist < d[idx]:
					d[idx] = dist
	return {"origin": b.position, "w": w, "h": h, "d": d}


static func _field_dist(field: Dictionary, p: Vector2) -> float:
	var x := int((p.x - field.origin.x) / CELL)
	var y := int((p.y - field.origin.y) / CELL)
	if x < 0 or y < 0 or x >= field.w or y >= field.h:
		return FIELD_CAP
	return field.d[y * field.w + x] - CELL * 0.75 # cell error margin


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 96.0), floori(p.y / 96.0))


static func _overlaps(grid: Dictionary, props: Array[Dictionary], p: Vector2, r: float) -> bool:
	var c := _cell(p)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			for idx in grid.get(c + Vector2i(dx, dy), []):
				var q: Dictionary = props[idx]
				if p.distance_to(q.p) < r + q.r + 6.0:
					return true
	return false


static func _register(grid: Dictionary, props: Array[Dictionary], prop: Dictionary) -> void:
	var c := _cell(prop.p)
	if not grid.has(c):
		grid[c] = []
	grid[c].append(props.size())
	props.append(prop)


static func _add_grandstand(track, map, field: Dictionary, props: Array[Dictionary], grid: Dictionary) -> void:
	var road_half: float = map.road_width * 0.5
	var tg: Vector2 = track.tangent_at(0.0)
	var center_of_track: Vector2 = track.bounds().get_center()
	# Try the infield side first (it's visible on every screen), then the outside.
	var sides := [1.0, -1.0]
	var normal := Vector2(-tg.y, tg.x)
	if normal.dot(center_of_track - track.point_at(0.0)) < 0.0:
		sides = [-1.0, 1.0]
	for side in sides:
		var c: Vector2 = track.point_at(40.0, side * (road_half + 62.0))
		var ok := true
		for along in [-120.0, -60.0, 0.0, 60.0, 120.0]:
			for across in [-26.0, 26.0]:
				var q: Vector2 = c + tg * along + normal * side * across
				if _field_dist(field, q) < road_half + 14.0:
					ok = false
		if ok and not _overlaps(grid, props, c, 110.0):
			_register(grid, props, {"k": "grandstand", "p": c, "r": 120.0, "rot": tg.angle(), "seed": 7, "c": Color.WHITE})
			return


## Spectator parking: one or two lots with painted bays and parked cars. Like at a
## real venue they sit outside the circuit, close to it, never in the infield. With a
## view, lots must be fully on screen and clear of the UI (buttons, pills, X).
static func _add_parking_lots(track, map, field: Dictionary, props: Array[Dictionary], grid: Dictionary, rng: RandomNumberGenerator, view: Dictionary) -> void:
	var road_half: float = map.road_width * 0.5
	var loop: PackedVector2Array = track.points()
	var bounds: Rect2 = track.bounds()
	var center := bounds.get_center()
	var outer := bounds.grow(240.0)
	var visible: PackedVector2Array = view.get("visible", PackedVector2Array())
	var keepouts: Array = view.get("keepouts", [])
	if visible.size() >= 3:
		var vr := Rect2(visible[0], Vector2.ZERO)
		for v in visible:
			vr = vr.expand(v)
		outer = vr
	var hull := Geometry2D.convex_hull(loop)
	var candidates: Array[Dictionary] = []
	for attempt in 2400:
		# Two-row lots where there's room, single-row ones for tight pockets.
		var rows := 2 if attempt % 3 != 2 else 1
		var bays := (4 if rows == 2 else 3) + rng.randi() % 4
		var size := Vector2(bays * 28.0 + 24.0, 132.0 if rows == 2 else 74.0)
		var rot := 0.0 if rng.randf() < 0.5 else PI * 0.5
		var c := Vector2(rng.randf_range(outer.position.x, outer.end.x), rng.randf_range(outer.position.y, outer.end.y))
		if Geometry2D.is_point_in_polygon(c, loop):
			continue
		var ok := true
		var nearest := INF
		var x := -size.x * 0.5
		while ok and x <= size.x * 0.5:
			var y := -size.y * 0.5
			while y <= size.y * 0.5:
				var q := c + Vector2(x, y).rotated(rot)
				var d := _field_dist(field, q)
				# Every sample is clear of the road, and they're closer together than the
				# road is wide, so the whole lot is on one side of it: testing the centre
				# against the track outline (done above) covers every point.
				if d < road_half + 22.0:
					ok = false
					break
				if visible.size() >= 3 and not Geometry2D.is_point_in_polygon(q, visible):
					ok = false
					break
				for k in keepouts:
					if q.distance_to(k[0]) < float(k[1]):
						ok = false
						break
				if not ok:
					break
				nearest = minf(nearest, d)
				y += 20.0
			x += 20.0
		# Must be outside and close to the track, like a car park next to the venue.
		if not ok or nearest > road_half + 110.0:
			continue
		var in_pocket := Geometry2D.is_point_in_polygon(c, hull)
		# Prefer lots hugging the track, bigger ones, and the outside pockets of bends.
		var score := (300.0 if in_pocket else 0.0) - nearest * 2.0 + size.x * rows
		candidates.append({"c": c, "size": size, "bays": bays, "rows": rows, "rot": rot, "score": score})
	candidates.sort_custom(func(a, b): return a.score > b.score)

	var placed: Array[Vector2] = []
	for cand in candidates:
		if placed.size() >= 2:
			break
		var c: Vector2 = cand.c
		var radius: float = cand.size.length() * 0.5
		var too_close := false
		for other in placed:
			if other.distance_to(c) < 320.0:
				too_close = true
		if too_close or _overlaps(grid, props, c, radius * 0.8):
			continue
		var cars := []
		for i in cand.bays * cand.rows:
			cars.append(CAR_COLORS[rng.randi() % CAR_COLORS.size()] if rng.randf() < 0.78 else null)
		_register(grid, props, {"k": "parking", "p": c, "r": radius * 0.8, "rot": cand.rot, "seed": rng.randi(), "c": Color.WHITE, "size": cand.size, "bays": cand.bays, "rows": cand.rows, "cars": cars})
		placed.append(c)


static func _add_tire_walls(track, map, field: Dictionary, props: Array[Dictionary], grid: Dictionary) -> void:
	var road_half: float = map.road_width * 0.5
	for corner in track.corners():
		var s: float = corner.s
		var side: float = corner.side
		var tg: Vector2 = track.tangent_at(s)
		var c: Vector2 = track.point_at(s, side * (road_half + 46.0))
		var tires := PackedVector2Array()
		for j in range(-2, 3):
			tires.append(c + tg * j * 15.0)
		var ok := true
		for t in tires:
			if _field_dist(field, t) < road_half + 26.0:
				ok = false
		if ok and not _overlaps(grid, props, c, 36.0):
			_register(grid, props, {"k": "tires", "p": c, "r": 36.0, "rot": tg.angle(), "seed": 0, "c": Color.WHITE, "pts": tires})


# --- Drawing ----------------------------------------------------------------

static func draw_all(ci: CanvasItem, props: Array[Dictionary]) -> void:
	for prop in props:
		match prop.k:
			"tree": _tree(ci, prop)
			"pine": _pine(ci, prop, false)
			"bush": _bush(ci, prop)
			"flowers": _flowers(ci, prop)
			"pond": _water(ci, prop, Color(0.2, 0.45, 0.65), Color(0.45, 0.7, 0.85))
			"frozen_pond": _water(ci, prop, Color(0.62, 0.8, 0.92), Color(0.9, 0.97, 1.0))
			"lagoon": _water(ci, prop, Color(0.15, 0.62, 0.72), Color(0.55, 0.9, 0.9))
			"log": _log(ci, prop)
			"rock": _rock(ci, prop, prop.c)
			"snow_rock": _snow_rock(ci, prop)
			"cactus": _cactus(ci, prop)
			"dune": _dune(ci, prop)
			"bones": _bones(ci, prop)
			"snowman": _snowman(ci, prop)
			"palm": _palm(ci, prop)
			"umbrella": _umbrella(ci, prop)
			"towel": _towel(ci, prop)
			"shell": _shell(ci, prop)
			"building": _building(ci, prop, true)
			"house": _building(ci, prop, false)
			"lamp": _lamp(ci, prop)
			"car_parked": _parked_car(ci, prop)
			"grandstand": _grandstand(ci, prop)
			"parking": _parking(ci, prop)
			"tires": _tires(ci, prop)
			"lava": _lava(ci, prop)
			"vent": _vent(ci, prop)
			"crack": _crack(ci, prop)
			"neon_sign": _neon_sign(ci, prop)
			"stars": _stars(ci, prop)
			"module": _module(ci, prop)
			"satellite": _satellite(ci, prop)
			"planet": _planet(ci, prop)
			"field": _field(ci, prop)
			"hay": _hay(ci, prop)
			"barn": _barn(ci, prop)
			"cow": _cow(ci, prop)
			"fence": _fence(ci, prop)
			"water": _water(ci, prop, Color(0.12, 0.3, 0.5), Color(0.25, 0.45, 0.62))
			"container": _container(ci, prop)
			"yard": _yard(ci, prop)
			"boat": _boat(ci, prop)
			"crane": _crane(ci, prop)
			"crate": _crate(ci, prop)


static func _blob(center: Vector2, r: float, seed: int, points := 12, wobble := 0.18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := i * TAU / points
		var k := 1.0 + wobble * sin(a * 3.0 + seed) + wobble * 0.6 * sin(a * 5.0 + seed * 0.7)
		pts.append(center + Vector2.from_angle(a) * r * k)
	return pts


static func _outlined(ci: CanvasItem, poly: PackedVector2Array, fill: Color, width := 3.0) -> void:
	ci.draw_colored_polygon(poly, fill)
	var loop := poly.duplicate()
	loop.append(poly[0])
	ci.draw_polyline(loop, OUTLINE, width, true)


static func _circle(ci: CanvasItem, p: Vector2, r: float, fill: Color) -> void:
	ci.draw_circle(p, r + 2.5, OUTLINE)
	ci.draw_circle(p, r, fill)


static func _tree(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = prop.c
	ci.draw_circle(p + SHADOW_OFFSET, r * 1.05, SHADOW)
	_outlined(ci, _blob(p, r, prop.seed, 14, 0.12), c)
	ci.draw_circle(p + Vector2(-r * 0.25, -r * 0.28), r * 0.5, c.lightened(0.15))
	ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.38), r * 0.22, c.lightened(0.3))


static func _pine(ci: CanvasItem, prop: Dictionary, _snowy: bool) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = prop.c
	ci.draw_circle(p + SHADOW_OFFSET, r, SHADOW)
	for layer in 3:
		var lr := r * (1.0 - layer * 0.28)
		var star := PackedVector2Array()
		for i in 16:
			var a: float = prop.rot + layer * 0.4 + i * TAU / 16.0
			star.append(p + Vector2.from_angle(a) * lr * (1.0 if i % 2 == 0 else 0.72))
		_outlined(ci, star, c.lightened(layer * 0.12), 2.5)
		# Snow on the branch tips.
		ci.draw_circle(p + Vector2.from_angle(prop.rot + layer) * lr * 0.55, lr * 0.16, Color(0.95, 0.97, 1.0))
	ci.draw_circle(p, r * 0.12, Color(0.95, 0.97, 1.0))


static func _bush(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = prop.c.darkened(0.1)
	ci.draw_circle(p + SHADOW_OFFSET * 0.6, r * 1.1, SHADOW)
	for i in 3:
		var o := Vector2.from_angle(prop.rot + i * TAU / 3.0) * r * 0.45
		_circle(ci, p + o, r * 0.6, c)
	for i in 3:
		var o := Vector2.from_angle(prop.rot + i * TAU / 3.0) * r * 0.45
		ci.draw_circle(p + o + Vector2(-2, -2), r * 0.3, c.lightened(0.15))


static func _flowers(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var cols := [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.9, 0.9, 1.0), Color(0.7, 0.5, 1.0)]
	for i in 7:
		var o: Vector2 = Vector2.from_angle(prop.rot + i * 2.4) * prop.r * (0.3 + 0.1 * i)
		ci.draw_circle(p + o, 3.2, cols[(prop.seed + i) % cols.size()])
		ci.draw_circle(p + o, 1.2, Color(1, 0.9, 0.4))


static func _water(ci: CanvasItem, prop: Dictionary, deep: Color, shallow: Color) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	_outlined(ci, _blob(p, r * 1.08, prop.seed, 20, 0.14), shallow, 3.0)
	ci.draw_colored_polygon(_blob(p, r * 0.9, prop.seed, 20, 0.14), deep)
	for i in 3:
		var a := p + Vector2(-r * 0.4 + i * r * 0.3, -r * 0.2 + i * r * 0.18)
		ci.draw_line(a, a + Vector2(r * 0.22, 0), Color(1, 1, 1, 0.45), 3.0, true)


static func _log(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var d := Vector2.from_angle(prop.rot) * r
	ci.draw_line(p - d + SHADOW_OFFSET, p + d + SHADOW_OFFSET, SHADOW, 12.0)
	ci.draw_line(p - d, p + d, OUTLINE, 13.0)
	ci.draw_line(p - d, p + d, Color(0.45, 0.3, 0.18), 8.0)
	_circle(ci, p + d, 4.5, Color(0.75, 0.6, 0.4))


static func _rock(ci: CanvasItem, prop: Dictionary, c: Color) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var poly := _blob(p, r, prop.seed, 7, 0.22)
	ci.draw_colored_polygon(_blob(p + SHADOW_OFFSET, r, prop.seed, 7, 0.22), SHADOW)
	_outlined(ci, poly, c)
	ci.draw_colored_polygon(_blob(p + Vector2(-r * 0.2, -r * 0.25), r * 0.5, prop.seed + 3, 6, 0.2), c.lightened(0.18))


static func _snow_rock(ci: CanvasItem, prop: Dictionary) -> void:
	_rock(ci, prop, Color(0.45, 0.5, 0.58))
	var p: Vector2 = prop.p
	ci.draw_colored_polygon(_blob(p + Vector2(-prop.r * 0.15, -prop.r * 0.2), prop.r * 0.55, prop.seed + 5, 8, 0.2), Color(0.95, 0.97, 1.0))


static func _cactus(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c := Color(0.3, 0.6, 0.3)
	ci.draw_circle(p + SHADOW_OFFSET, r, SHADOW)
	var arm := Vector2.from_angle(prop.rot) * r * 0.95
	_circle(ci, p + arm, r * 0.42, c.darkened(0.1))
	_circle(ci, p - arm * 0.85, r * 0.36, c.darkened(0.1))
	_circle(ci, p, r * 0.62, c)
	for i in 6:
		ci.draw_circle(p + Vector2.from_angle(i * TAU / 6.0) * r * 0.38, 1.4, Color(0.95, 0.95, 0.8))
	ci.draw_circle(p + Vector2(0, -r * 0.1), r * 0.18, Color(1.0, 0.5, 0.6))


static func _dune(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var poly := PackedVector2Array()
	for i in 16:
		var a: float = prop.rot + i * TAU / 16.0
		poly.append(p + Vector2(cos(a) * r * 1.3, sin(a) * r * 0.55).rotated(prop.rot))
	ci.draw_colored_polygon(poly, Color(1, 0.85, 0.6, 0.12))
	ci.draw_polyline(poly.slice(2, 8), Color(1, 0.9, 0.7, 0.25), 3.0, true)


static func _bones(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var bone := Color(0.95, 0.92, 0.85)
	var d := Vector2.from_angle(prop.rot) * 9.0
	ci.draw_line(p - d, p + d, OUTLINE, 6.0)
	ci.draw_line(p - d, p + d, bone, 3.0)
	for e in [p - d, p + d]:
		_circle(ci, e + d.orthogonal() * 0.25, 2.5, bone)
		_circle(ci, e - d.orthogonal() * 0.25, 2.5, bone)


static func _snowman(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	ci.draw_circle(p + SHADOW_OFFSET, 13.0, SHADOW)
	_circle(ci, p, 12.0, Color(0.96, 0.98, 1.0))
	_circle(ci, p + Vector2(0, -6), 7.5, Color(1, 1, 1))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(8, -6), p + Vector2(0, -5)]), Color(1.0, 0.5, 0.1))
	ci.draw_circle(p + Vector2(-2.5, -8.5), 1.3, OUTLINE)
	ci.draw_circle(p + Vector2(2.5, -8.5), 1.3, OUTLINE)
	ci.draw_line(p + Vector2(-7, -1), p + Vector2(7, -1), Color(0.9, 0.2, 0.25), 3.0)


static func _palm(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	ci.draw_circle(p + SHADOW_OFFSET * 1.3, r * 0.9, SHADOW)
	for i in 6:
		var a: float = prop.rot + i * TAU / 6.0
		var tip := p + Vector2.from_angle(a) * r
		var side := Vector2.from_angle(a + PI * 0.5) * r * 0.22
		var mid := p + Vector2.from_angle(a) * r * 0.5
		_outlined(ci, PackedVector2Array([p, mid + side, tip, mid - side]), Color(0.25, 0.6, 0.3).lightened(0.08 * (i % 2)), 2.5)
	_circle(ci, p, r * 0.16, Color(0.55, 0.38, 0.2))
	ci.draw_circle(p + Vector2(3, 2), r * 0.08, Color(0.4, 0.28, 0.15))


static func _umbrella(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = prop.c
	ci.draw_circle(p + SHADOW_OFFSET, r, SHADOW)
	ci.draw_circle(p, r + 2.5, OUTLINE)
	for i in 8:
		var a0: float = prop.rot + i * TAU / 8.0
		var a1 := a0 + TAU / 8.0
		var seg := PackedVector2Array([p, p + Vector2.from_angle(a0) * r, p + Vector2.from_angle((a0 + a1) * 0.5) * r, p + Vector2.from_angle(a1) * r])
		ci.draw_colored_polygon(seg, c if i % 2 == 0 else Color(0.97, 0.97, 0.95))
	_circle(ci, p, 2.5, Color(0.97, 0.97, 0.95))


static func _towel(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var c: Color = prop.c
	var x := Vector2.from_angle(prop.rot) * 13.0
	var y := x.orthogonal() * 0.55
	_outlined(ci, PackedVector2Array([p - x - y, p + x - y, p + x + y, p - x + y]), c, 2.0)
	ci.draw_line(p - x * 0.4 - y, p - x * 0.4 + y, Color(1, 1, 1, 0.7), 3.0)
	ci.draw_line(p + x * 0.4 - y, p + x * 0.4 + y, Color(1, 1, 1, 0.7), 3.0)


static func _shell(ci: CanvasItem, prop: Dictionary) -> void:
	_circle(ci, prop.p, 4.0, Color(1.0, 0.8, 0.75))
	ci.draw_circle(prop.p + Vector2(-1, -1), 1.5, Color(1, 1, 1))


static func _building(ci: CanvasItem, prop: Dictionary, tall: bool) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = prop.c
	var rot := snappedf(prop.rot, PI * 0.5)
	var half := Vector2(r * 0.95, r * 0.72)
	var shadow_len := 14.0 if tall else 7.0
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-half + Vector2(shadow_len, shadow_len), half * 2.0), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(2.5, 2.5), half * 2.0 + Vector2(5, 5)), OUTLINE)
	if tall:
		ci.draw_rect(Rect2(-half, half * 2.0), c)
		ci.draw_rect(Rect2(-half + Vector2(5, 5), half * 2.0 - Vector2(10, 10)), c.lightened(0.08))
		# Lit windows / roof lights.
		var rng := RandomNumberGenerator.new()
		rng.seed = prop.seed
		var step := 11.0
		var y := -half.y + 10.0
		while y < half.y - 8.0:
			var x := -half.x + 10.0
			while x < half.x - 8.0:
				if rng.randf() < 0.55:
					var lit := Color(1.0, 0.85, 0.45, 0.9) if rng.randf() < 0.7 else Color(0.5, 0.8, 1.0, 0.8)
					ci.draw_rect(Rect2(x, y, 5, 5), lit)
				x += step
			y += step
		ci.draw_rect(Rect2(half.x - 22, -half.y + 6, 14, 10), c.darkened(0.3))
	else:
		# Small house with a pitched roof seen from above.
		var roof := Color(0.6, 0.25, 0.22) if prop.seed % 2 == 0 else Color(0.25, 0.35, 0.55)
		ci.draw_rect(Rect2(-half, Vector2(half.x * 2.0, half.y)), roof)
		ci.draw_rect(Rect2(Vector2(-half.x, 0), Vector2(half.x * 2.0, half.y)), roof.darkened(0.2))
		ci.draw_line(Vector2(-half.x, 0), Vector2(half.x, 0), OUTLINE, 2.0)
		ci.draw_rect(Rect2(half.x * 0.3, -half.y * 0.8, 6, 6), Color(0.35, 0.3, 0.3))
	ci.draw_set_transform(Vector2.ZERO)


static func _lamp(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	ci.draw_circle(p, 26.0, Color(1.0, 0.85, 0.5, 0.06))
	ci.draw_circle(p, 16.0, Color(1.0, 0.85, 0.5, 0.1))
	_circle(ci, p, 4.5, Color(1.0, 0.92, 0.65))


static func _parked_car(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var rot := snappedf(prop.rot, PI * 0.5)
	var cols := [Color(0.85, 0.85, 0.9), Color(0.3, 0.3, 0.35), Color(0.7, 0.2, 0.2), Color(0.25, 0.45, 0.75)]
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-11, -6, 26, 16), SHADOW)
	ci.draw_rect(Rect2(-14.5, -8.5, 29, 17), OUTLINE)
	ci.draw_rect(Rect2(-12, -6, 24, 12), cols[prop.seed % cols.size()])
	ci.draw_rect(Rect2(-3, -5, 8, 10), Color(0.15, 0.2, 0.3))
	ci.draw_set_transform(Vector2.ZERO)


static func _parking(ci: CanvasItem, prop: Dictionary) -> void:
	var size: Vector2 = prop.size
	var half := size * 0.5
	var bays: int = prop.bays
	var paint := Color(0.92, 0.92, 0.88, 0.85)
	ci.draw_set_transform(prop.p, prop.rot)
	ci.draw_rect(Rect2(-half + Vector2(6, 8), size), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(3, 3), size + Vector2(6, 6)), OUTLINE)
	ci.draw_rect(Rect2(-half, size), Color(0.21, 0.22, 0.25))
	ci.draw_rect(Rect2(-half + Vector2(4, 4), size - Vector2(8, 8)), Color(0.24, 0.25, 0.28))
	# One or two rows of bays facing a driving lane.
	var rows: int = prop.get("rows", 2)
	var bay_w := 28.0
	var depth := 44.0
	var x0 := -half.x + 12.0
	for row in rows:
		var y_edge := -half.y + 6.0 if row == 0 else half.y - 6.0
		var dir := 1.0 if row == 0 else -1.0
		for i in bays + 1:
			var x := x0 + i * bay_w
			ci.draw_line(Vector2(x, y_edge), Vector2(x, y_edge + dir * depth), paint, 2.0)
		for i in bays:
			var col = prop.cars[row * bays + i]
			if col == null:
				continue
			var cx := x0 + i * bay_w + bay_w * 0.5
			var cy := y_edge + dir * depth * 0.5
			ci.draw_rect(Rect2(cx - 8 + 3, cy - 14 + 4, 16, 28), SHADOW)
			ci.draw_rect(Rect2(cx - 9.5, cy - 15.5, 19, 31), OUTLINE)
			ci.draw_rect(Rect2(cx - 8, cy - 14, 16, 28), col)
			var glass_y := cy - dir * 3.0 - 5.0
			ci.draw_rect(Rect2(cx - 6, glass_y, 12, 10), Color(0.12, 0.16, 0.24))
			ci.draw_rect(Rect2(cx - 6, glass_y + 1, 12, 2), Color(1, 1, 1, 0.25))
	# Dashed line along the driving lane and a "P" sign.
	var lane_y := 0.0 if rows == 2 else half.y - 12.0
	var x := -half.x + 14.0
	while x < half.x - 14.0:
		ci.draw_line(Vector2(x, lane_y), Vector2(x + 10, lane_y), Color(0.95, 0.8, 0.3, 0.8), 2.0)
		x += 20.0
	var sign := Rect2(half.x - 26, lane_y - 12, 22, 24)
	ci.draw_rect(sign.grow(2.5), OUTLINE)
	ci.draw_rect(sign, Color(0.15, 0.4, 0.85))
	ci.draw_set_transform(prop.p + Vector2(half.x - 15, lane_y + 7).rotated(prop.rot), prop.rot)
	ci.draw_string(ThemeDB.fallback_font, Vector2(-8, 0), "P", HORIZONTAL_ALIGNMENT_CENTER, 16, 18, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)


static func _grandstand(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	ci.draw_set_transform(p, prop.rot)
	var half := Vector2(130, 30)
	ci.draw_rect(Rect2(-half + Vector2(8, 10), half * 2.0), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(3, 3), half * 2.0 + Vector2(6, 6)), OUTLINE)
	ci.draw_rect(Rect2(-half, half * 2.0), Color(0.55, 0.58, 0.65))
	# Rows of spectators in random colors.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var crowd := [Color(1, 0.35, 0.35), Color(0.35, 0.65, 1), Color(1, 0.85, 0.3), Color(0.35, 0.85, 0.5), Color(0.95, 0.95, 0.95), Color(0.9, 0.5, 0.2)]
	for row in 4:
		var y := -half.y + 8.0 + row * 14.0
		ci.draw_rect(Rect2(-half.x + 4, y - 5, half.x * 2.0 - 8, 10), Color(0.4, 0.43, 0.5))
		var x := -half.x + 9.0
		while x < half.x - 6.0:
			ci.draw_circle(Vector2(x, y), 3.4, crowd[rng.randi() % crowd.size()])
			x += 8.0 + rng.randf() * 3.0
	ci.draw_rect(Rect2(-half.x - 3, -half.y - 10, half.x * 2.0 + 6, 8), Color(0.9, 0.2, 0.25))
	ci.draw_set_transform(Vector2.ZERO)


static func _lava(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	# Dark crust rim, bright molten middle, a few hot spots.
	_outlined(ci, _blob(p, r * 1.1, prop.seed, 20, 0.16), Color(0.35, 0.1, 0.05), 3.0)
	ci.draw_colored_polygon(_blob(p, r * 0.92, prop.seed, 20, 0.16), Color(0.95, 0.35, 0.05))
	ci.draw_colored_polygon(_blob(p, r * 0.6, prop.seed + 4, 16, 0.2), Color(1.0, 0.6, 0.1))
	for i in 4:
		var q := p + Vector2.from_angle(prop.rot + i * 1.7) * r * (0.2 + 0.12 * i)
		ci.draw_circle(q, r * 0.1, Color(1.0, 0.9, 0.45))
	# Floating crust plates.
	for i in 3:
		var q := p + Vector2.from_angle(prop.rot * 2.0 + i * 2.1) * r * 0.55
		ci.draw_colored_polygon(_blob(q, r * 0.14, prop.seed + i, 6, 0.25), Color(0.3, 0.1, 0.06))


static func _vent(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	ci.draw_circle(p + SHADOW_OFFSET * 0.6, r * 1.1, SHADOW)
	_outlined(ci, _blob(p, r, prop.seed, 9, 0.18), Color(0.2, 0.16, 0.16))
	ci.draw_circle(p, r * 0.45, Color(0.1, 0.05, 0.04))
	ci.draw_circle(p, r * 0.3, Color(1.0, 0.45, 0.1))
	# A little smoke drifting off.
	for i in 3:
		ci.draw_circle(p + Vector2(r * 0.5 + i * 5.0, -r * 0.8 - i * 7.0), 4.0 + i * 1.5, Color(0.6, 0.58, 0.58, 0.35 - i * 0.08))


static func _crack(ci: CanvasItem, prop: Dictionary) -> void:
	# A glowing lava crack in the ground.
	var p: Vector2 = prop.p
	var r: float = prop.r
	var pts := PackedVector2Array()
	var dir := Vector2.from_angle(prop.rot)
	for i in 6:
		var t := float(i) / 5.0 - 0.5
		var wig := dir.orthogonal() * sin(i * 2.3 + prop.seed) * r * 0.18
		pts.append(p + dir * r * 2.0 * t + wig)
	ci.draw_polyline(pts, Color(0.08, 0.04, 0.03), 7.0, true)
	ci.draw_polyline(pts, Color(1.0, 0.4, 0.08), 3.5, true)
	ci.draw_polyline(pts, Color(1.0, 0.85, 0.4), 1.2, true)


static func _neon_sign(ci: CanvasItem, prop: Dictionary) -> void:
	# A glowing neon sign seen from above: a bright outline with a soft halo.
	var p: Vector2 = prop.p
	var r: float = prop.r
	var c: Color = NEON_COLORS[absi(int(prop.seed)) % NEON_COLORS.size()]
	var rot := snappedf(prop.rot, PI * 0.5)
	var half := Vector2(r * 0.95, r * 0.45)
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-half + Vector2(5, 6), half * 2.0), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(2, 2), half * 2.0 + Vector2(4, 4)), OUTLINE)
	ci.draw_rect(Rect2(-half, half * 2.0), Color(0.08, 0.06, 0.12))
	for g in 3:
		ci.draw_rect(Rect2(-half + Vector2(3, 3) - Vector2(g, g) * 2.0, half * 2.0 - Vector2(6, 6) + Vector2(g, g) * 4.0), Color(c, 0.18 - g * 0.05), false, 3.0)
	ci.draw_rect(Rect2(-half + Vector2(4, 4), half * 2.0 - Vector2(8, 8)), c, false, 2.5)
	# Glowing "letters": a row of short bars.
	var x := -half.x + 10.0
	var k := 0
	while x < half.x - 10.0:
		var h := half.y * (0.5 if k % 3 == 1 else 0.8)
		ci.draw_rect(Rect2(x, -h * 0.5, 4, h), c.lightened(0.3))
		x += 8.0
		k += 1
	ci.draw_set_transform(Vector2.ZERO)


# --- Space ---------------------------------------------------------------------

static func _stars(ci: CanvasItem, prop: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = prop.seed
	for i in 7:
		var q: Vector2 = prop.p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * prop.r
		var big := rng.randf() < 0.2
		ci.draw_circle(q, 2.2 if big else 1.2, Color(1, 1, 1, rng.randf_range(0.4, 0.9)))
		if big:
			ci.draw_line(q - Vector2(4, 0), q + Vector2(4, 0), Color(1, 1, 1, 0.35), 1.0)
			ci.draw_line(q - Vector2(0, 4), q + Vector2(0, 4), Color(1, 1, 1, 0.35), 1.0)


static func _module(ci: CanvasItem, prop: Dictionary) -> void:
	# Station module: a rounded hull with lit windows and a beacon.
	var p: Vector2 = prop.p
	var r: float = prop.r
	var rot := snappedf(prop.rot, PI * 0.5)
	var half := Vector2(r, r * 0.45)
	ci.draw_set_transform(p, rot)
	var hull := StyleBoxFlat.new()
	hull.bg_color = prop.c
	hull.set_corner_radius_all(int(half.y))
	hull.border_color = OUTLINE
	hull.set_border_width_all(3)
	ci.draw_rect(Rect2(-half + Vector2(6, 7), half * 2.0), SHADOW)
	ci.draw_style_box(hull, Rect2(-half, half * 2.0))
	ci.draw_rect(Rect2(-half.x + 8, -2, half.x * 2.0 - 16, 4), Color(prop.c.lightened(0.25)))
	var x := -half.x + 14.0
	while x < half.x - 12.0:
		ci.draw_rect(Rect2(x, -half.y + 5, 6, 5), Color(0.55, 0.85, 1.0, 0.9))
		x += 12.0
	ci.draw_circle(Vector2(half.x - 8, half.y - 8), 3.0, Color(1.0, 0.3, 0.3))
	ci.draw_set_transform(Vector2.ZERO)


static func _satellite(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var d := Vector2.from_angle(prop.rot)
	var n := d.orthogonal()
	ci.draw_line(p - d * 18.0, p + d * 18.0, OUTLINE, 3.0)
	for side in [-1.0, 1.0]:
		var c: Vector2 = p + d * 14.0 * side
		var panel := PackedVector2Array([c - d * 6.0 - n * 5.0, c + d * 6.0 - n * 5.0, c + d * 6.0 + n * 5.0, c - d * 6.0 + n * 5.0])
		_outlined(ci, panel, Color(0.2, 0.35, 0.75), 2.0)
		ci.draw_line(c - n * 5.0, c + n * 5.0, Color(0.5, 0.7, 1.0, 0.6), 1.0)
	_circle(ci, p, 5.5, Color(0.85, 0.85, 0.9))
	ci.draw_circle(p + n * 2.0, 1.8, Color(1.0, 0.8, 0.2))


static func _planet(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r * 0.7
	var cols := [Color(0.85, 0.5, 0.3), Color(0.4, 0.6, 0.9), Color(0.7, 0.45, 0.85), Color(0.5, 0.75, 0.55)]
	var c: Color = cols[absi(int(prop.seed)) % cols.size()]
	var tilt: float = prop.rot
	# Ring behind, planet, ring in front.
	var ring := func(front: bool):
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI * (i / 24.0) + (0.0 if front else PI)
			pts.append(p + Vector2(cos(a) * r * 1.7, sin(a) * r * 0.45).rotated(tilt))
		ci.draw_polyline(pts, Color(1.0, 0.9, 0.7, 0.7), 4.0, true)
	ring.call(false)
	_circle(ci, p, r, c)
	ci.draw_circle(p + Vector2(r * 0.25, r * 0.25), r * 0.8, c.darkened(0.2))
	ci.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.35, c.lightened(0.2))
	ring.call(true)


# --- Farm ---------------------------------------------------------------------------

static func _field(ci: CanvasItem, prop: Dictionary) -> void:
	# A patch of crops in rows (wheat or green crops).
	var p: Vector2 = prop.p
	var r: float = prop.r
	var rot := snappedf(prop.rot, PI * 0.25)
	var wheat := absi(int(prop.seed)) % 2 == 0
	var base := Color(0.85, 0.7, 0.3) if wheat else Color(0.3, 0.55, 0.2)
	var half := Vector2(r, r * 0.7)
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-half, half * 2.0), base.darkened(0.15))
	var y := -half.y + 5.0
	while y < half.y - 3.0:
		ci.draw_line(Vector2(-half.x + 3, y), Vector2(half.x - 3, y), base.lightened(0.12), 4.0)
		y += 9.0
	ci.draw_set_transform(Vector2.ZERO)


static func _hay(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	ci.draw_circle(p + SHADOW_OFFSET * 0.6, r, SHADOW)
	_circle(ci, p, r, Color(0.88, 0.72, 0.35))
	ci.draw_arc(p, r * 0.6, 0.0, TAU, 16, Color(0.72, 0.55, 0.25), 2.0, true)
	ci.draw_arc(p, r * 0.25, 0.0, TAU, 12, Color(0.72, 0.55, 0.25), 2.0, true)


static func _barn(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var rot := snappedf(prop.rot, PI * 0.5)
	var half := Vector2(r, r * 0.7)
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-half + Vector2(8, 10), half * 2.0), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(3, 3), half * 2.0 + Vector2(6, 6)), OUTLINE)
	ci.draw_rect(Rect2(-half, Vector2(half.x * 2.0, half.y)), Color(0.75, 0.18, 0.15))
	ci.draw_rect(Rect2(Vector2(-half.x, 0), Vector2(half.x * 2.0, half.y)), Color(0.6, 0.13, 0.12))
	ci.draw_line(Vector2(-half.x, 0), Vector2(half.x, 0), OUTLINE, 2.5)
	for x in [-half.x * 0.5, 0.0, half.x * 0.5]:
		ci.draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(0, 0, 0, 0.18), 2.0)
	ci.draw_set_transform(Vector2.ZERO)


static func _cow(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var d := Vector2.from_angle(prop.rot)
	ci.draw_circle(p + SHADOW_OFFSET * 0.5, 9.0, SHADOW)
	var body := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		body.append(p + d * cos(a) * 10.0 + d.orthogonal() * sin(a) * 6.0)
	_outlined(ci, body, Color(0.97, 0.97, 0.95), 2.0)
	ci.draw_circle(p - d * 3.0 + d.orthogonal() * 2.0, 3.0, OUTLINE)
	ci.draw_circle(p + d * 4.0 - d.orthogonal() * 2.0, 2.2, OUTLINE)
	_circle(ci, p + d * 12.0, 3.5, Color(0.95, 0.85, 0.8))


static func _fence(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var d: Vector2 = Vector2.from_angle(snappedf(prop.rot, PI * 0.5)) * prop.r
	ci.draw_line(p - d, p + d, Color(0.45, 0.3, 0.18), 3.0)
	for k in 5:
		var q: Vector2 = (p - d).lerp(p + d, k / 4.0)
		_circle(ci, q, 2.5, Color(0.55, 0.38, 0.22))


# --- Harbour ------------------------------------------------------------------------

static func _container(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	var rot := snappedf(prop.rot, PI * 0.5)
	var half := Vector2(r, r * 0.42)
	ci.draw_set_transform(p, rot)
	ci.draw_rect(Rect2(-half + Vector2(5, 6), half * 2.0), SHADOW)
	ci.draw_rect(Rect2(-half - Vector2(2, 2), half * 2.0 + Vector2(4, 4)), OUTLINE)
	ci.draw_rect(Rect2(-half, half * 2.0), prop.c)
	var x := -half.x + 4.0
	while x < half.x - 2.0:
		ci.draw_line(Vector2(x, -half.y), Vector2(x, half.y), prop.c.darkened(0.2), 1.5)
		x += 5.0
	ci.draw_set_transform(Vector2.ZERO)


## Container yard: containers lined up in neat rows, like a real port.
static func _yard(ci: CanvasItem, prop: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = prop.seed
	var cols := PALETTES["harbor"]
	var rot := snappedf(prop.rot, PI * 0.5)
	var r: float = prop.r
	var box := Vector2(26, 10) # one container
	var rows := clampi(int(r * 1.4 / (box.y + 3.0)), 3, 7)
	var per_row := 2 + rng.randi() % 2
	var origin := Vector2(-(box.x + 3.0) * per_row * 0.5, -(box.y + 3.0) * rows * 0.5)
	ci.draw_set_transform(prop.p, rot)
	ci.draw_rect(Rect2(origin - Vector2(4, 4), Vector2((box.x + 3.0) * per_row + 5.0, (box.y + 3.0) * rows + 5.0)), Color(0.28, 0.3, 0.33))
	for row in rows:
		for c in per_row:
			if rng.randf() < 0.12:
				continue # a gap in the stack
			var q := origin + Vector2(c * (box.x + 3.0), row * (box.y + 3.0))
			var col: Color = cols[rng.randi() % cols.size()]
			ci.draw_rect(Rect2(q + Vector2(3, 3), box), SHADOW)
			ci.draw_rect(Rect2(q - Vector2(1.5, 1.5), box + Vector2(3, 3)), OUTLINE)
			ci.draw_rect(Rect2(q, box), col)
			var x := 3.0
			while x < box.x - 1.0:
				ci.draw_line(q + Vector2(x, 0), q + Vector2(x, box.y), col.darkened(0.2), 1.2)
				x += 4.0
	ci.draw_set_transform(Vector2.ZERO)


static func _boat(ci: CanvasItem, prop: Dictionary) -> void:
	# A small boat in its own patch of water.
	var p: Vector2 = prop.p
	var r: float = prop.r
	_outlined(ci, _blob(p, r * 1.2, prop.seed, 14, 0.12), Color(0.25, 0.45, 0.62), 2.0)
	ci.draw_colored_polygon(_blob(p, r * 1.0, prop.seed, 14, 0.12), Color(0.12, 0.3, 0.5))
	var d := Vector2.from_angle(prop.rot)
	var n := d.orthogonal()
	var hull := PackedVector2Array([p + d * r * 0.85, p + d * r * 0.3 + n * r * 0.32, p - d * r * 0.7 + n * r * 0.3,
		p - d * r * 0.7 - n * r * 0.3, p + d * r * 0.3 - n * r * 0.32])
	_outlined(ci, hull, Color(0.95, 0.95, 0.95), 2.5)
	var cab := PackedVector2Array([p + n * r * 0.18, p - d * r * 0.35 + n * r * 0.18, p - d * r * 0.35 - n * r * 0.18, p - n * r * 0.18])
	ci.draw_colored_polygon(cab, prop.c)
	ci.draw_line(p - d * r * 1.1, p - d * r * 1.6, Color(1, 1, 1, 0.5), 3.0)


static func _crane(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var d := Vector2.from_angle(prop.rot)
	var n := d.orthogonal()
	var arm: float = prop.r * 1.4
	ci.draw_line(p + Vector2(8, 10), p + d * arm + Vector2(8, 10), SHADOW, 9.0)
	ci.draw_line(p, p + d * arm, OUTLINE, 9.0)
	ci.draw_line(p, p + d * arm, Color(0.95, 0.7, 0.1), 5.0)
	for k in range(1, 6):
		var q: Vector2 = p + d * arm * k / 6.0
		ci.draw_line(q - n * 2.5, q + n * 2.5, Color(0.55, 0.4, 0.05), 1.5)
	var base := PackedVector2Array([p + Vector2(-9, -9), p + Vector2(9, -9), p + Vector2(9, 9), p + Vector2(-9, 9)])
	_outlined(ci, base, Color(0.85, 0.6, 0.08), 3.0)
	_circle(ci, p + d * arm, 3.0, Color(0.3, 0.3, 0.32))


static func _crate(ci: CanvasItem, prop: Dictionary) -> void:
	var p: Vector2 = prop.p
	var r: float = prop.r
	ci.draw_rect(Rect2(p - Vector2(r, r) + Vector2(3, 4), Vector2(r, r) * 2.0), SHADOW)
	ci.draw_rect(Rect2(p - Vector2(r, r) - Vector2(1.5, 1.5), Vector2(r, r) * 2.0 + Vector2(3, 3)), OUTLINE)
	ci.draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Color(0.65, 0.45, 0.25))
	ci.draw_line(p - Vector2(r, r), p + Vector2(r, r), Color(0.45, 0.3, 0.15), 2.0)


static func _tires(ci: CanvasItem, prop: Dictionary) -> void:
	var tire_cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.95, 0.95)]
	var i := 0
	for t in prop.pts:
		ci.draw_circle(t + Vector2(3, 4), 8.5, SHADOW)
		ci.draw_circle(t, 8.5, OUTLINE)
		ci.draw_circle(t, 7.0, Color(0.12, 0.12, 0.14))
		ci.draw_circle(t, 3.5, tire_cols[i % 2])
		i += 1
