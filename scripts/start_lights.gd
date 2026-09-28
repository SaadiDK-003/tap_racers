extends Control
## Racing start lights: red lights come on one by one, then all turn green for GO.

var lit := 0
var green := false


func _ready() -> void:
	custom_minimum_size = Vector2(300, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = custom_minimum_size * 0.5


func set_state(red_count: int, is_green: bool) -> void:
	if red_count != lit or is_green != green:
		lit = red_count
		green = is_green
		queue_redraw()


func _draw() -> void:
	var s := custom_minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	style.set_corner_radius_all(26)
	style.border_color = Color(0.02, 0.02, 0.03)
	style.set_border_width_all(6)
	draw_style_box(style, Rect2(Vector2.ZERO, s))
	for i in 3:
		var c := Vector2(s.x * (0.2 + 0.3 * i), s.y * 0.5)
		var on := green or i < lit
		var col := Color(0.2, 1.0, 0.45) if green else Color(1.0, 0.18, 0.15)
		if on:
			draw_circle(c, 44.0, Color(col, 0.18))
			draw_circle(c, 34.0, Color(col, 0.35))
			draw_circle(c, 28.0, col)
			draw_circle(c + Vector2(-8, -9), 8.0, Color(1, 1, 1, 0.45))
		else:
			draw_circle(c, 28.0, Color(0.16, 0.17, 0.2))
