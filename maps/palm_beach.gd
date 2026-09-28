extends RefCounted
## Seaside circuit: long back straight, a V-shaped hairpin at the top and a lagoon infield.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Palm Beach"
	m.points = PackedVector2Array([
		Vector2(620, 760), Vector2(620, 450), Vector2(600, 290), Vector2(520, 185),
		Vector2(400, 180), Vector2(340, 290), Vector2(250, 300), Vector2(160, 330),
		Vector2(120, 460), Vector2(120, 760), Vector2(130, 950), Vector2(210, 1060),
		Vector2(380, 1100), Vector2(540, 1070), Vector2(610, 960),
	])
	m.ground = Color(0.9, 0.78, 0.55)
	m.blob = Color(0.86, 0.73, 0.5)
	m.road = Color(0.33, 0.33, 0.37)
	m.lane = Color(0.62, 0.62, 0.66)
	m.curb_b = Color(0.1, 0.65, 0.75)
	m.blob_seed = 9
	m.scenery = "beach"
	return m
