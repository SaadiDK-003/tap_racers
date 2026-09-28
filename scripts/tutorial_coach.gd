extends Node
## Guided "how to play" race: a coach card walks a new player through driving,
## braking for corners, nitro and power-ups, reacting to what they actually do.

const Car = preload("res://scripts/car.gd")

enum Step { HOLD, BRAKE, FILL_NITRO, FIRE_NITRO, BOXES, FINISH }

var race # the race scene
var car
var _step := Step.HOLD
var _step_time := 0.0
var _first_corner := 300.0
var _panel: PanelContainer
var _title: Label
var _body: Label


func setup(race_node) -> void:
	race = race_node
	car = race.cars[0]
	for c in race.world.track.corners():
		if c.s > 80.0:
			_first_corner = c.s
			break
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Game.make_style(Color(0.06, 0.07, 0.1, 0.92), 18, Game.ACCENT, 4))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = _label(30, Game.ACCENT)
	_body = _label(22, Color.WHITE)
	v.add_child(_title)
	v.add_child(_body)
	# Full-width strip at the top; the card is centred in it.
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 16.0
	holder.offset_bottom = 150.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.root_ui.add_child(holder)
	holder.add_child(_panel)
	_panel.visible = false
	_show("TUTORIAL", "Get ready! Watch the lights...")
	_panel.visible = true


func _hold_hint() -> String:
	return "your corner button" if Game.is_touch() else "the %s key" % Game.key_label(0)


func _show(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_panel.scale = Vector2(1.08, 1.08)
	_panel.pivot_offset = _panel.size * 0.5
	race.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.2)


func _go(step: Step) -> void:
	_step = step
	_step_time = 0.0
	Sfx.play(Sfx.lap, -6.0, 1.3)
	match step:
		Step.HOLD:
			_show("1. DRIVE", "HOLD %s to accelerate." % _hold_hint())
		Step.BRAKE:
			_show("2. CORNERS", "Too fast in a corner and you fly off!\nLET GO before the corner to slow down.")
		Step.FILL_NITRO:
			_show("3. NITRO", "Driving fast fills your NITRO\n(the inner blue ring on your button).")
			car.nitro = maxf(car.nitro, 0.8)
		Step.FIRE_NITRO:
			_show("4. BOOST!", "NITRO is ready - DOUBLE-TAP %s!\nYou can't crash while it burns." % _hold_hint())
		Step.BOXES:
			_show("5. POWER-UPS", "Drive through the ? boxes for\nSHIELDS, ROCKETS and MEGA NITRO.")
		Step.FINISH:
			_show("YOU'VE GOT IT!", "Finish the race to complete the tutorial.")


## Called by the race when the lights go green.
func on_start() -> void:
	_go(Step.HOLD)


func update(delta: float) -> void:
	_step_time += delta
	match _step:
		Step.HOLD:
			if car.speed > 380.0:
				_go(Step.BRAKE)
		Step.BRAKE:
			if car.progress > _first_corner + 150.0 and car.state == Car.State.RACING:
				_go(Step.FILL_NITRO)
		Step.FILL_NITRO:
			if car.nitro_armed:
				_go(Step.FIRE_NITRO)
		Step.FIRE_NITRO:
			if not car.nitro_armed and not car.boosting:
				_go(Step.FILL_NITRO) # crashed and lost it: try again
		Step.BOXES:
			if _step_time > 6.0:
				_go(Step.FINISH)


func on_crash() -> void:
	if _step == Step.BRAKE or _step == Step.HOLD:
		_show("TOO FAST!", "Let go of %s BEFORE the corner,\nthen hold again once you're through." % _hold_hint())


func on_boost() -> void:
	if _step == Step.FIRE_NITRO:
		_go(Step.BOXES)


func on_pickup() -> void:
	if _step == Step.BOXES:
		_go(Step.FINISH)


func hide_card() -> void:
	_panel.visible = false


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
