extends RefCounted
## Stadium-shaped circuit with a chicane biting into each side.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Canyon Hairpins"
	m.points = PackedVector2Array([
		Vector2(603, 510), Vector2(600, 420),
		Vector2(565, 290), Vector2(460, 235), Vector2(260, 235), Vector2(150, 290),
		Vector2(120, 400), Vector2(130, 480), Vector2(210, 540), Vector2(270, 600),
		Vector2(250, 680), Vector2(160, 730), Vector2(120, 820), Vector2(125, 960),
		Vector2(170, 1055), Vector2(290, 1090), Vector2(440, 1090), Vector2(560, 1070),
		Vector2(600, 1000), Vector2(595, 920), Vector2(520, 860), Vector2(455, 800),
		Vector2(470, 730), Vector2(560, 680), Vector2(605, 600),
	])
	m.ground = Color(0.12, 0.075, 0.11)
	m.blob = Color(0.095, 0.055, 0.085)
	m.road = Color(0.27, 0.23, 0.28)
	m.lane = Color(0.56, 0.45, 0.52)
	m.curb_b = Color(1.0, 0.55, 0.1)
	m.blob_seed = 3
	m.scenery = "desert"
	return m
