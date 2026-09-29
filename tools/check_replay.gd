## Plays a race with bots and rockets, then checks the replay: it starts, a tap skips
## it, the camera and cars are put back, and the results appear.
## Run: godot --path . --resolution 720x1016 --script res://tools/check_replay.gd [-- notap] [map=13]
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.debug_bots = true
	game.debug_shot = "x" # keeps the replay on in bot runs (no screenshot is taken)
	game.debug_item = "rocket"
	game.num_players = 2
	game.num_cpus = 2
	game.laps = 3
	game.debug_no_intro = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="):
			game.debug_map = a.substr(4).to_int()
	change_scene_to_file("res://scenes/race.tscn")
	var race = null
	for i in 6000:
		await process_frame
		race = current_scene
		if race and race.get("_replaying"):
			break
	if race == null or not race._replaying:
		print("REPLAY never started (no exciting moment this race?)")
		quit()
		return
	print("REPLAY started: %s, world scale %.2f (fit %.2f)" % [race.replay.clip.label, race.world.scale.x, race.world.fit_scale])
	if "notap" in OS.get_cmdline_user_args():
		await create_timer(6.5, true, false, true).timeout # let it play to the end
	else:
		await create_timer(0.8, true, false, true).timeout # real seconds
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = KEY_SPACE
		Input.parse_input_event(e)
	await create_timer(0.5, true, false, true).timeout
	print("after: replaying %s, time_scale %.2f, results shown %s, world scale back to fit %s, hold_view %s" % [
		race._replaying, Engine.time_scale, race._results.visible, is_equal_approx(race.world.scale.x, race.world.fit_scale), race.world.hold_view])
	quit()
