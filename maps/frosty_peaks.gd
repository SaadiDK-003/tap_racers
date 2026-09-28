extends RefCounted
## Snowy mountain pass with an S-bend switchback through the middle.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Frosty Peaks"
	m.points = PackedVector2Array([
		Vector2(110, 800), Vector2(110, 420), Vector2(160, 250), Vector2(300, 170),
		Vector2(470, 190), Vector2(560, 300), Vector2(520, 420), Vector2(380, 470),
		Vector2(300, 560), Vector2(360, 660), Vector2(520, 690), Vector2(640, 780),
		Vector2(650, 920), Vector2(560, 1050), Vector2(380, 1090), Vector2(220, 1060),
		Vector2(130, 960),
	])
	m.ground = Color(0.82, 0.88, 0.94)
	m.blob = Color(0.74, 0.81, 0.9)
	m.road = Color(0.3, 0.33, 0.39)
	m.lane = Color(0.6, 0.66, 0.75)
	m.curb_b = Color(0.2, 0.5, 0.95)
	m.blob_seed = 5
	m.scenery = "snow"
	return m
