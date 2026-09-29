## Simulates a finger swipe on a scrolling page and logs the scroll position each
## frame (smoothness, and whether it keeps gliding after the finger lifts). With
## "tap", it taps instead, to check buttons in a list still work.
## Run: godot --path . --resolution 540x960 --script res://tools/check_scroll.gd -- awards [swipe|flick|tap|swipe_then_tap] [y as a fraction of the window]
extends SceneTree

var _log: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var s := _find_scroll(c)
		if s:
			return s
	return null


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	e.velocity = rel * 60.0
	Input.parse_input_event(e)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "awards"
	var mode: String = args[1] if args.size() > 1 else "swipe"
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 30:
		await process_frame
	var sc := _find_scroll(current_scene)
	var win := Vector2(root.size)
	var k := win.x / root.get_visible_rect().size.x # window px per viewport unit
	var start := Vector2(win.x * 0.5, win.y * (float(args[2]) if args.size() > 2 else 0.7))
	var before := current_scene.name
	_touch(start, true)
	await process_frame
	var pos := start
	if mode == "tap":
		await process_frame
	else:
		for f in (5 if mode in ["flick", "swipe_then_tap"] else 16):
			var step := Vector2(0, -22.0)
			pos += step
			_drag(pos, step)
			await process_frame
			_log.append("drag f%d scroll %.1f" % [f, sc.get_v_scroll_bar().value if sc else -1.0])
	_touch(pos, false)
	if mode == "swipe_then_tap":
		# Swipe the list back down, then tap where the swipe began.
		for i in 40:
			await process_frame
		_touch(start, true)
		var p2 := start
		for f in 8:
			p2 += Vector2(0, 30)
			_drag(p2, Vector2(0, 30))
			await process_frame
		_touch(p2, false)
		for i in 60:
			await process_frame
		_log.append("list back at %.1f; tapping" % sc.get_v_scroll_bar().value)
		_touch(start, true)
		await process_frame
		await process_frame
		_touch(start, false)
	var last := -1.0
	for f in 90:
		await process_frame
		if current_scene == null or current_scene.name != before:
			_log.append("SCENE CHANGED to %s after release (a button was pressed)" % (current_scene.name if current_scene else "?"))
			break
		var v: float = sc.get_v_scroll_bar().value if sc else -1.0
		if v != last:
			_log.append("after f%d scroll %.1f" % [f, v])
		last = v
	for l in _log:
		print("SCROLL ", l)
	print("SCROLL window px/unit %.2f" % k)
	quit()
