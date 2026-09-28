extends RefCounted
## Desert canyon with a river across the main straight: hit the ramp fast enough to
## jump the water, or it's a splash.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Splash Canyon"
	m.points = PackedVector2Array([
		Vector2(620, 780), Vector2(620, 420), Vector2(580, 240), Vector2(470, 150),
		Vector2(330, 160), Vector2(240, 250), Vector2(250, 380), Vector2(350, 470),
		Vector2(360, 590), Vector2(250, 670), Vector2(140, 770), Vector2(110, 910),
		Vector2(160, 1045), Vector2(300, 1110), Vector2(460, 1100), Vector2(580, 1030),
		Vector2(620, 910),
	])
	m.jump_point = Vector2(620, 520)
	m.ground = Color(0.8, 0.55, 0.35)
	m.blob = Color(0.74, 0.5, 0.32)
	m.road = Color(0.3, 0.27, 0.26)
	m.lane = Color(0.6, 0.5, 0.42)
	m.curb_b = Color(0.2, 0.6, 0.85)
	m.blob_seed = 43
	m.scenery = "desert"
	return m
