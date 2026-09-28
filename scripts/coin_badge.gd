extends Control
## Coin counter: a gold coin and the player's balance. Counts up when coins are added.

var _shown := -1.0 # displayed amount; -1 until the first frame
var _font: FontVariation


func _ready() -> void:
	custom_minimum_size = Vector2(170, 52)
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var target := float(Profile.coins())
	if _shown < 0.0:
		_shown = target
		queue_redraw()
	if absf(_shown - target) > 0.5:
		_shown = move_toward(_shown, target, maxf(40.0, absf(target - _shown) * 4.0) * delta)
		queue_redraw()
	elif _shown != target:
		_shown = target
		queue_redraw()


static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r + 2.5, Color(0.02, 0.03, 0.05))
	ci.draw_circle(c, r, Color(1.0, 0.78, 0.2))
	ci.draw_circle(c, r * 0.72, Color(0.95, 0.65, 0.12))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(1.0, 0.85, 0.35))
	ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.6))


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	style.set_corner_radius_all(26)
	style.border_color = Color(0.02, 0.03, 0.05)
	style.set_border_width_all(4)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	draw_coin(self, Vector2(28, size.y * 0.5), 15.0)
	draw_string(_font, Vector2(52, size.y * 0.5 + 11), str(maxi(0, int(round(_shown)))), HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 30, Color(1.0, 0.88, 0.4))
