extends RefCounted
## Fast, flowing forest circuit: one long straight and a kidney-shaped bend.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Forest Ring"
	m.points = PackedVector2Array([
		Vector2(120, 700), Vector2(120, 380), Vector2(170, 220), Vector2(310, 140),
		Vector2(480, 150), Vector2(600, 240), Vector2(620, 380), Vector2(540, 480),
		Vector2(520, 580), Vector2(610, 690), Vector2(660, 830), Vector2(620, 990),
		Vector2(480, 1080), Vector2(300, 1080), Vector2(170, 1010), Vector2(120, 880),
	])
	m.ground = Color(0.09, 0.17, 0.11)
	m.blob = Color(0.07, 0.14, 0.09)
	m.road = Color(0.25, 0.27, 0.29)
	m.lane = Color(0.45, 0.55, 0.47)
	m.curb_b = Color(0.95, 0.75, 0.1)
	m.blob_seed = 11
	m.scenery = "forest"
	return m
