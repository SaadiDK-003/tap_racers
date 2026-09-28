extends RefCounted
## L-shaped circuit around a harbour: a hairpin at the top, a long run along the docks.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Harbor Docks"
	m.points = PackedVector2Array([
		Vector2(110, 700), Vector2(110, 400), Vector2(150, 220), Vector2(260, 140),
		Vector2(380, 180), Vector2(420, 320), Vector2(400, 520), Vector2(430, 650),
		Vector2(540, 700), Vector2(640, 790), Vector2(650, 950), Vector2(560, 1070),
		Vector2(400, 1110), Vector2(230, 1090), Vector2(130, 990), Vector2(110, 860),
	])
	m.ground = Color(0.35, 0.37, 0.4)
	m.blob = Color(0.31, 0.33, 0.36)
	m.road = Color(0.22, 0.23, 0.26)
	m.lane = Color(0.55, 0.58, 0.62)
	m.curb_b = Color(1.0, 0.75, 0.1)
	m.blob_seed = 41
	m.scenery = "harbor"
	return m
