extends Control
## Screen-space rain: slanted streaks falling over the track, plus the odd splash.

const COUNT := 140

var _drops: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _drops.is_empty() and size.x > 0.0:
		for i in COUNT:
			_drops.append(_new_drop(true))
	for d in _drops:
		d.p += Vector2(-120.0, 900.0) * d.speed * delta
		if d.p.y > size.y + 20.0:
			var fresh := _new_drop(false)
			d.p = fresh.p
			d.speed = fresh.speed
	queue_redraw()


func _new_drop(anywhere: bool) -> Dictionary:
	var y := randf() * size.y if anywhere else -randf() * 60.0
	return {"p": Vector2(randf() * (size.x + 200.0), y), "speed": randf_range(0.7, 1.2)}


func _draw() -> void:
	for d in _drops:
		var p: Vector2 = d.p
		draw_line(p, p + Vector2(-5, 30) * d.speed, Color(0.75, 0.85, 1.0, 0.28), 2.0)
