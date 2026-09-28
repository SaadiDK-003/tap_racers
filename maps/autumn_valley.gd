extends RefCounted
## Flowing valley circuit: a long sweeper on the right, a bend biting in on the
## left, and a wide hairpin at the bottom. Autumn forest scenery.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Autumn Valley"
	m.points = PackedVector2Array([
		Vector2(620, 620), Vector2(620, 340), Vector2(560, 190), Vector2(420, 120),
		Vector2(270, 140), Vector2(160, 250), Vector2(170, 400), Vector2(300, 480),
		Vector2(370, 580), Vector2(320, 690), Vector2(190, 730), Vector2(110, 840),
		Vector2(120, 990), Vector2(230, 1090), Vector2(400, 1120), Vector2(545, 1070),
		Vector2(620, 950), Vector2(620, 800),
	])
	m.ground = Color(0.2, 0.15, 0.08)
	m.blob = Color(0.17, 0.12, 0.06)
	m.road = Color(0.26, 0.25, 0.26)
	m.lane = Color(0.6, 0.5, 0.38)
	m.curb_b = Color(0.85, 0.3, 0.1)
	m.blob_seed = 29
	m.scenery = "forest"
	m.scenery_palette = [Color(0.85, 0.4, 0.12), Color(0.8, 0.25, 0.12), Color(0.9, 0.6, 0.15), Color(0.6, 0.3, 0.1), Color(0.35, 0.45, 0.15)]
	return m
