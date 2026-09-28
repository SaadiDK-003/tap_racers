extends RefCounted
## Rounded-triangle circuit on a space station, with a chicane down the right side.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Orbit Station"
	m.points = PackedVector2Array([
		Vector2(360, 1080), Vector2(180, 1080), Vector2(100, 990), Vector2(120, 860),
		Vector2(200, 660), Vector2(290, 440), Vector2(340, 250), Vector2(420, 150),
		Vector2(520, 180), Vector2(560, 300), Vector2(520, 420), Vector2(560, 540),
		Vector2(640, 640), Vector2(660, 780), Vector2(640, 950), Vector2(580, 1060),
		Vector2(480, 1090),
	])
	m.ground = Color(0.03, 0.03, 0.08)
	m.blob = Color(0.05, 0.04, 0.12)
	m.road = Color(0.22, 0.24, 0.3)
	m.lane = Color(0.45, 0.65, 0.8)
	m.curb_a = Color(0.9, 0.95, 1.0)
	m.curb_b = Color(0.2, 0.75, 1.0)
	m.blob_seed = 31
	m.scenery = "space"
	return m
