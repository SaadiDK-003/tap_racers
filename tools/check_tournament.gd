## Plays a whole tournament with bots (heats and final) and checks the bracket:
## slots show the right entrants, the top two of each heat reach the final, and the
## final crowns a champion. Run: godot --path . --resolution 720x1016 --script res://tools/check_tournament.gd
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.debug_bots = true
	game.debug_shot = "x" # stay on the results screen (bot races normally quit there)
	game.debug_no_intro = true
	root.get_node("Profile").data.settings["replays"] = false # keep it quick (not saved)
	game.start_tournament(5, 1, 1)
	var t: Dictionary = game.tournament
	print("TOURNEY heats %s | %s" % [_names(game, t.heats[0]), _names(game, t.heats[1])])
	for stage in 3:
		game.begin_tournament_race()
		var slots := []
		for i in 4:
			slots.append("%s%s" % [game.racer_name(i), "" if game.is_cpu(i) else "*"])
		print("TOURNEY %s slots: %s (humans %d)" % [game.T_STAGES[stage], ", ".join(slots), game.num_players])
		change_scene_to_file("res://scenes/race.tscn")
		var shots: String = OS.get_environment("TOURNEY_SHOTS") # a folder: save screenshots there
		if shots != "":
			_shot_later(shots + "/t_race_%d.png" % stage, 2.5)
		var race = null
		for f in 20000:
			await process_frame
			race = current_scene
			if race and race.get("_results") and race._results.visible:
				break
		if not (race and race._results.visible):
			print("TOURNEY race never finished")
			quit()
			return
		if OS.get_environment("TOURNEY_SHOTS") != "":
			await create_timer(1.5).timeout
			root.get_texture().get_image().save_png(OS.get_environment("TOURNEY_SHOTS") + "/t_results_%d.png" % stage)
		print("TOURNEY %s result: %s -> stage now %d, final so far %s" % [game.T_STAGES[stage], _names(game, t.results[stage]), t.stage, _names(game, t.final)])
	print("TOURNEY champion: %s" % game.tournament_champion().name)
	if OS.get_environment("TOURNEY_SHOTS") != "":
		change_scene_to_file("res://scenes/tournament.tscn")
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png(OS.get_environment("TOURNEY_SHOTS") + "/t_champion.png")
	game.end_tournament()
	print("TOURNEY ended: in_tournament %s, players %d" % [game.in_tournament(), game.num_players])
	quit()


func _names(game, ids: Array) -> String:
	return ", ".join(ids.map(func(id): return game.tournament.entrants[id].name))


func _shot_later(path: String, delay: float) -> void:
	await create_timer(delay).timeout
	root.get_texture().get_image().save_png(path)
