extends Control
## Falling confetti for the winner celebration.

var _pieces: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func burst(colors: Array, count := 140) -> void:
	for i in count:
		_pieces.append({
			"p": Vector2(randf() * size.x, -randf() * size.y * 0.6 - 20.0),
			"v": Vector2(randf_range(-60, 60), randf_range(120, 320)),
			"rot": randf() * TAU,
			"spin": randf_range(-8, 8),
			"c": colors[randi() % colors.size()],
			"s": Vector2(randf_range(8, 14), randf_range(4, 8)),
		})


func _process(delta: float) -> void:
	if _pieces.is_empty():
		return
	for q in _pieces:
		q.v.y = minf(q.v.y + 200.0 * delta, 420.0)
		q.p += q.v * delta + Vector2(sin(q.rot) * 30.0 * delta, 0)
		q.rot += q.spin * delta
	_pieces = _pieces.filter(func(q): return q.p.y < size.y + 30.0)
	queue_redraw()


func _draw() -> void:
	for q in _pieces:
		var s: Vector2 = q.s
		draw_set_transform(q.p, q.rot, Vector2(1.0, absf(cos(q.rot * 1.7)) * 0.8 + 0.2))
		draw_rect(Rect2(-s * 0.5, s), q.c)
	draw_set_transform(Vector2.ZERO)
