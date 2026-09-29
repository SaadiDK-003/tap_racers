extends RefCounted
## Countryside circuit with a railway across the long right-hand straight: when the
## lights flash and the barriers drop, wait for the train (or risk it).

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Rail Crossing"
	m.points = PackedVector2Array([
		Vector2(360, 1110), Vector2(520, 1105), Vector2(610, 1040), Vector2(640, 920),
		Vector2(640, 700), Vector2(640, 480), Vector2(612, 300), Vector2(530, 190),
		Vector2(420, 158), Vector2(320, 196), Vector2(282, 300), Vector2(300, 420),
		Vector2(330, 520), Vector2(318, 620), Vector2(240, 700), Vector2(140, 790),
		Vector2(108, 925), Vector2(160, 1050), Vector2(262, 1102),
	])
	m.rail_point = Vector2(640, 640)
	m.ground = Color(0.36, 0.55, 0.3)
	m.blob = Color(0.32, 0.5, 0.27)
	m.road = Color(0.27, 0.28, 0.3)
	m.lane = Color(0.5, 0.52, 0.48)
	m.curb_b = Color(0.95, 0.6, 0.1)
	m.blob_seed = 61
	m.scenery = "forest"
	return m
