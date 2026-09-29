extends Container
## Shows its child at its natural size, centred, and scales it down if that doesn't
## fit, so a page always fits the screen with no scrolling. With max_scale > 1 it
## also grows a small page to use the space (e.g. bigger text on tall phones).

var max_scale := 1.0
## Extra scale on top of the fit, for pop-in animations (scales around the centre).
var pop := 1.0:
	set(v):
		pop = v
		queue_sort()

func _init(grow := 1.0) -> void:
	max_scale = grow
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO # can shrink to whatever space is left


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for c in get_children():
		if not (c is Control) or not c.visible:
			continue
		var m: Vector2 = c.get_combined_minimum_size()
		var k := 1.0
		if m.x > 0.0 and m.y > 0.0:
			k = minf(max_scale, minf(size.x / m.x, size.y / m.y))
		k *= pop
		c.scale = Vector2(k, k)
		c.size = m
		c.position = ((size - m * k) * 0.5).floor()
