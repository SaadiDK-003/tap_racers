extends RefCounted
## Long back straight, a diagonal sweeper and a tight loop at the bottom right.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Sunset Speedway"
	m.points = PackedVector2Array([
		Vector2(100, 760), Vector2(100, 330), Vector2(150, 180), Vector2(290, 110),
		Vector2(500, 110), Vector2(630, 180), Vector2(660, 310), Vector2(610, 440),
		Vector2(430, 640), Vector2(370, 780), Vector2(400, 900), Vector2(490, 950),
		Vector2(570, 900), Vector2(590, 780), Vector2(620, 660), Vector2(710, 620),
		Vector2(800, 680), Vector2(820, 820), Vector2(800, 1000), Vector2(700, 1090),
		Vector2(500, 1110), Vector2(250, 1110), Vector2(140, 1060), Vector2(100, 940),
	])
	m.blob_seed = 7
	m.scenery = "city"
	return m
