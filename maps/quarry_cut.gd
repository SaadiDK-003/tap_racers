extends RefCounted
## A quarry circuit with a hairpin at the top and a gravel shortcut that cuts it short,
## right beside the turn.
## Slow down at the SHORTCUT sign to turn in: it's much shorter, but narrow, twisty
## and loose. Keep your foot down to stay on the fast way round.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Quarry Cut"
	m.points = PackedVector2Array([
		Vector2(360, 1110), Vector2(500, 1105), Vector2(600, 1045), Vector2(640, 950), Vector2(622, 840), Vector2(574, 740), Vector2(570, 560), Vector2(570, 430), Vector2(570, 330), Vector2(543, 230), Vector2(470, 157), Vector2(370, 130), Vector2(270, 157), Vector2(197, 230), Vector2(170, 330), Vector2(170, 430), Vector2(170, 560), Vector2(168, 740), Vector2(122, 840), Vector2(104, 950), Vector2(150, 1045), Vector2(240, 1095),
	])
	# The top is a hairpin; the shortcut takes the same turn lower down, right beside
	# it: it peels off one leg of the hairpin and rejoins the other, skipping the ends.
	m.shortcut_from = Vector2(570, 630)
	m.shortcut = PackedVector2Array([
		Vector2(543, 530), Vector2(470, 457), Vector2(370, 430), Vector2(270, 457), Vector2(197, 530),
	])
	m.shortcut_to = Vector2(170, 630)
	m.ground = Color(0.7, 0.62, 0.5)
	m.blob = Color(0.64, 0.56, 0.45)
	m.road = Color(0.28, 0.28, 0.3)
	m.lane = Color(0.55, 0.53, 0.5)
	m.curb_b = Color(0.95, 0.55, 0.15)
	m.blob_seed = 91
	m.scenery = "desert"
	return m
