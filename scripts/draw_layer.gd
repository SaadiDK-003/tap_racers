extends Node2D
## A node whose drawing is delegated to a callable (used to layer track visuals).

var draw_fn: Callable


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
