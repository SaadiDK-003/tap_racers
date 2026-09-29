extends RefCounted
## A quarry with a big outer loop and a gravel shortcut straight across the middle.
## Slow down at the SHORTCUT sign to turn in: it's much shorter, but narrow, twisty
## and loose. Keep your foot down to stay on the fast way round.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Quarry Cut"
	m.points = PackedVector2Array([
		Vector2(360, 1110), Vector2(500, 1105), Vector2(600, 1040), Vector2(635, 920),
		Vector2(635, 700), Vector2(635, 480), Vector2(612, 300), Vector2(540, 190),
		Vector2(430, 150), Vector2(320, 160), Vector2(230, 210), Vector2(170, 300),
		Vector2(130, 420), Vector2(115, 560), Vector2(115, 700), Vector2(120, 840),
		Vector2(150, 980), Vector2(240, 1085),
	])
	# The shortcut leaves the right-hand straight and rejoins the left side lower down.
	m.shortcut_from = Vector2(635, 760)
	m.shortcut = PackedVector2Array([
		Vector2(560, 640), Vector2(470, 620), Vector2(390, 650), Vector2(310, 625),
		Vector2(230, 620),
	])
	m.shortcut_to = Vector2(117, 800)
	m.ground = Color(0.7, 0.62, 0.5)
	m.blob = Color(0.64, 0.56, 0.45)
	m.road = Color(0.28, 0.28, 0.3)
	m.lane = Color(0.55, 0.53, 0.5)
	m.curb_b = Color(0.95, 0.55, 0.15)
	m.blob_seed = 91
	m.scenery = "desert"
	return m
