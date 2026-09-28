extends SceneTree
## Layout checker for map designers:
##   godot --headless --path . --script res://tools/check_tracks.gd
## For every map it reports the track length, the tightest corner radius and the
## closest distance between two separate parts of the road (ignoring the crossing
## point of a figure-8). Roads are 108 wide, so parts closer than ~150 will touch.

const MAPS := [
	"res://maps/sunset_speedway.gd", "res://maps/canyon_hairpins.gd", "res://maps/forest_ring.gd",
	"res://maps/frosty_peaks.gd", "res://maps/palm_beach.gd", "res://maps/crossover.gd",
	"res://maps/volcano_rush.gd", "res://maps/neon_nights.gd", "res://maps/autumn_valley.gd",
]


func _init() -> void:
	var Track = load("res://scripts/track.gd")
	for path in MAPS:
		if not ResourceLoader.exists(path):
			continue
		var m = load(path).build()
		var t = Track.new()
		var offs: Array[float] = [0.0]
		t.map = m
		t.lane_offsets = offs
		t._build_curve()
		var pts: PackedVector2Array = t._pos
		var n := pts.size()
		var min_r := INF
		for i in n:
			var k: float = absf(t._curv[i])
			if k > 0.0:
				min_r = minf(min_r, 1.0 / k)
		var closest := INF
		var where := Vector2.ZERO
		var step := 3
		var skip := int(260.0 / t._step) # samples this close along the road don't count
		for i in range(0, n, step):
			for j in range(i + skip, n, step):
				if n - (j - i) < skip:
					continue
				var d := pts[i].distance_to(pts[j])
				var bp: Vector2 = m.bridge_point
				if bp.is_finite() and pts[i].distance_to(bp) < 150.0:
					continue
				if d < closest:
					closest = d
					where = pts[i]
		var b := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			b = b.expand(p)
		var ok := "OK" if closest >= 150.0 and min_r >= 55.0 else "CHECK"
		print("%-18s len %5d  tightest r %4d  closest parts %4d at (%d,%d)  size %dx%d  %s" % [
			m.title, int(t.length), int(min_r), int(closest), int(where.x), int(where.y), int(b.size.x), int(b.size.y), ok])
		t.free()
	quit()
