extends RefCounted
## Alpine summit with a ravine across the long straight: the road climbs to a crest
## and leaps the chasm. It's a big gap, so carry your speed (or save a nitro).

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Summit Leap"
	m.points = PackedVector2Array([
		Vector2(360, 1110), Vector2(500, 1100), Vector2(600, 1030), Vector2(630, 900),
		Vector2(630, 700), Vector2(630, 470), Vector2(605, 300), Vector2(520, 190),
		Vector2(410, 160), Vector2(310, 205), Vector2(270, 310), Vector2(320, 420),
		Vector2(410, 500), Vector2(420, 610), Vector2(320, 690), Vector2(190, 760),
		Vector2(115, 880), Vector2(135, 1010), Vector2(240, 1095),
	])
	# The ravine sits at the top of the long right-hand straight.
	m.jump_point = Vector2(630, 560)
	m.jump_kind = "ravine"
	m.jump_gap = 190.0
	m.jump_ramp = 70.0
	m.jump_min_speed = 630.0 # ~88% of top speed: keep your foot down up the hill
	m.ground = Color(0.86, 0.9, 0.95)
	m.blob = Color(0.78, 0.84, 0.91)
	m.road = Color(0.3, 0.32, 0.36)
	m.lane = Color(0.6, 0.64, 0.7)
	m.curb_b = Color(0.2, 0.45, 0.85)
	m.blob_seed = 77
	m.scenery = "snow"
	return m
