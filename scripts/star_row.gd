extends Control
## Three career stars (podium, win, goal); earned ones are gold, the rest dark.
## `fresh` stars (earned just now) pop in with a glow.

var bits := 0
var fresh := 0
var star_size := 22.0
var count := 3

const GOLD := Color(1.0, 0.82, 0.2)
const DARK := Color(0.2, 0.22, 0.27)


func _init(b := 0, s := 22.0, f := 0, n := 3) -> void:
	bits = b
	fresh = f
	star_size = s
	count = n
	custom_minimum_size = Vector2(s * (1.25 * n - 0.25) + 4.0, s * 1.1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := star_size * 0.5
	for k in count:
		var c := Vector2(r + 2.0 + k * star_size * 1.25, size.y * 0.5)
		var on := bits & (1 << k) != 0
		if fresh & (1 << k):
			draw_circle(c, r * 1.35, Color(GOLD, 0.25))
		draw_colored_polygon(_star(c, r + 2.0), Color(0.02, 0.03, 0.05))
		draw_colored_polygon(_star(c, r - 1.0), GOLD if on else DARK)


static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
	return pts
