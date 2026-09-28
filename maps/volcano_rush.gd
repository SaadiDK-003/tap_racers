extends RefCounted
## Heart-shaped circuit around a volcano: a deep dip between two lobes at the top,
## and a long sweeping run down to the rounded point at the bottom.

const MapDef = preload("res://maps/map_def.gd")


static func build():
	var m := MapDef.new()
	m.title = "Volcano Rush"
	m.points = PackedVector2Array([
		Vector2(100, 700), Vector2(100, 440), Vector2(130, 270), Vector2(220, 165),
		Vector2(320, 160), Vector2(375, 250), Vector2(375, 390), Vector2(420, 480),
		Vector2(520, 480), Vector2(565, 390), Vector2(565, 250), Vector2(620, 160), Vector2(720, 165),
		Vector2(810, 270), Vector2(830, 440), Vector2(780, 640), Vector2(680, 840),
		Vector2(560, 1010), Vector2(465, 1100), Vector2(370, 1010), Vector2(250, 900),
		Vector2(140, 820),
	])
	m.ground = Color(0.13, 0.1, 0.1)
	m.blob = Color(0.1, 0.075, 0.075)
	m.road = Color(0.24, 0.22, 0.23)
	m.lane = Color(0.55, 0.42, 0.38)
	m.curb_a = Color(0.95, 0.9, 0.85)
	m.curb_b = Color(1.0, 0.35, 0.1)
	m.blob_seed = 13
	m.scenery = "volcano"
	return m
