extends SceneTree
## Run: godot --headless --path . --script res://tools/check_scripts.gd
## Loads every script, so parse errors in scripts that aren't autoloads show up too.
func _initialize() -> void:
	var d := DirAccess.open("res://scripts")
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s = load("res://scripts/" + f)
			if s == null:
				print("PARSEFAIL ", f)
	quit()
