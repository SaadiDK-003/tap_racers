extends RefCounted
## Figure-8 with a bridge: the two loops cross in the middle, one pass going over the other.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Crossover Bridge"
	m.points = PackedVector2Array([
		Vector2(205, 320), Vector2(230, 420), Vector2(300, 500), Vector2(400, 590),
		Vector2(500, 680), Vector2(580, 780), Vector2(600, 900), Vector2(550, 1020),
		Vector2(420, 1080), Vector2(280, 1050), Vector2(200, 950), Vector2(210, 820),
		Vector2(290, 700), Vector2(400, 590), Vector2(510, 500), Vector2(590, 400),
		Vector2(600, 270), Vector2(530, 160), Vector2(400, 120), Vector2(270, 150),
		Vector2(205, 230),
	])
	m.bridge_point = Vector2(400, 590)
	m.bridge_pass = 1
	m.ground = Color(0.1, 0.1, 0.15)
	m.blob = Color(0.08, 0.08, 0.12)
	m.road = Color(0.25, 0.25, 0.3)
	m.lane = Color(0.5, 0.5, 0.62)
	m.curb_b = Color(0.6, 0.3, 0.95)
	m.blob_seed = 21
	m.scenery = "city"
	return m
