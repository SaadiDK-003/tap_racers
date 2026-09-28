extends Node2D
## Draws every character once, invisibly, in each font / size / outline a screen
## uses, then removes itself. Glyphs are rasterized the first time they're drawn;
## doing it all while the race loads keeps that out of the race (a new toast or
## speech bubble could otherwise cost a few milliseconds mid-race).
## Add it as a child of the node that draws the text, so the scale matches.

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?.,'-+•/:()%&*\""

var styles: Array = [] # [font, size, outline]
var _frames := 0


func _init(list: Array = []) -> void:
	styles = list


func _draw() -> void:
	var clear := Color(1, 1, 1, 0)
	for st in styles:
		var font: Font = st[0]
		if int(st[2]) > 0:
			draw_string_outline(font, Vector2(0, -2000), CHARS, HORIZONTAL_ALIGNMENT_LEFT, -1, int(st[1]), int(st[2]), clear)
		draw_string(font, Vector2(0, -2000), CHARS, HORIZONTAL_ALIGNMENT_LEFT, -1, int(st[1]), clear)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > 2:
		queue_free()
