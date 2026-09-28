extends RefCounted
## Dog-bone circuit through a neon city: two big loops joined by a narrow waist,
## with a quick chicane on the way back up.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Neon Nights"
	m.points = PackedVector2Array([
		Vector2(250, 640), Vector2(250, 480), Vector2(170, 380), Vector2(110, 260),
		Vector2(160, 145), Vector2(300, 95), Vector2(460, 95), Vector2(600, 145),
		Vector2(650, 260), Vector2(590, 380), Vector2(510, 480), Vector2(500, 580),
		Vector2(560, 650), Vector2(510, 740), Vector2(520, 820), Vector2(600, 910),
		Vector2(650, 1030), Vector2(590, 1140), Vector2(450, 1190), Vector2(300, 1190),
		Vector2(165, 1140), Vector2(110, 1030), Vector2(160, 910), Vector2(250, 800),
	])
	m.ground = Color(0.07, 0.05, 0.12)
	m.blob = Color(0.05, 0.035, 0.09)
	m.road = Color(0.2, 0.19, 0.27)
	m.lane = Color(0.55, 0.4, 0.8)
	m.curb_a = Color(0.95, 0.95, 1.0)
	m.curb_b = Color(1.0, 0.2, 0.7)
	m.blob_seed = 17
	m.scenery = "neon"
	return m
