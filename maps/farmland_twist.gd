extends RefCounted
## Countryside circuit: a long back straight and a snake of S-bends up the other side.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Farmland Twist"
	m.points = PackedVector2Array([
		Vector2(620, 700), Vector2(620, 380), Vector2(590, 200), Vector2(480, 120),
		Vector2(340, 150), Vector2(290, 260), Vector2(370, 360), Vector2(330, 470),
		Vector2(180, 500), Vector2(130, 620), Vector2(230, 720), Vector2(360, 760),
		Vector2(380, 870), Vector2(260, 930), Vector2(140, 1000), Vector2(170, 1110),
		Vector2(330, 1150), Vector2(500, 1130), Vector2(600, 1040), Vector2(620, 900),
	])
	m.ground = Color(0.42, 0.55, 0.25)
	m.blob = Color(0.38, 0.5, 0.22)
	m.road = Color(0.3, 0.29, 0.28)
	m.lane = Color(0.62, 0.6, 0.5)
	m.curb_b = Color(0.85, 0.2, 0.15)
	m.blob_seed = 37
	m.scenery = "farm"
	return m
