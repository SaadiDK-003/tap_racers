## Switches between screens and resizes the window after each one. Resize listeners
## left behind by freed screens show up as errors and a growing connection count.
## Run: godot --headless --path . --script res://tools/check_resize.gd
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _shake() -> void:
	for s in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(1000, 700)]:
		root.size = s
		root.size_changed.emit()
		await process_frame

func _run() -> void:
	for path in ["res://scenes/main_menu.tscn", "res://scenes/records.tscn", "res://scenes/main_menu.tscn", "res://scenes/race.tscn", "res://scenes/main_menu.tscn", "res://scenes/garage.tscn"]:
		change_scene_to_file(path)
		for i in 20: await process_frame
		await _shake()
		print("ok ", path, " root size_changed connections: ", root.size_changed.get_connections().size())
	quit()
