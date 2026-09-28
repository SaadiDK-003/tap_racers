extends Node
## Time trial: P1 alone against the clock and a ghost of their best lap on this track.
## Records the player's laps as distance samples; the best one becomes the new ghost.

const Car = preload("res://scripts/car.gd")

const DT := 1.0 / 30.0 # ghost sample interval

var race
var car
var ghost_car: Car
var lap_times: Array[float] = []

var _ghost: Dictionary = {} # saved best lap {time, dt, d}
var _ghost_d := PackedFloat32Array()
var _ghost_t := -1.0 # time into the current lap for the ghost (-1 = not started)
var _samples := PackedFloat32Array()
var _sample_clock := 0.0
var _lap_base := 0.0
var _best_samples := PackedFloat32Array()
var _best := INF
var _timer: Label
var _lap_clock := -1.0


func setup(race_node) -> void:
	race = race_node
	car = race.cars[0]
	_ghost = Profile.ghost(race.world.map.title)
	if not _ghost.is_empty():
		_ghost_d = PackedFloat32Array(_ghost.d)
		ghost_car = Car.new()
		ghost_car.index = 0
		ghost_car.color = Color(0.85, 0.9, 1.0)
		ghost_car.body = car.body
		ghost_car.decal = car.decal
		ghost_car.trail_style = car.trail_style
		ghost_car.track = race.world.track
		ghost_car.modulate = Color(0.7, 0.85, 1.0, 0.5)
		ghost_car.scale = car.scale
		ghost_car.visible = false
		car.get_parent().add_child(ghost_car)
	_timer = Label.new()
	_timer.add_theme_font_size_override("font_size", 30)
	_timer.add_theme_constant_override("outline_size", 8)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_top = 14.0
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.root_ui.add_child(_timer)
	_update_timer()


func best_lap() -> float:
	return _best


func ghost_time() -> float:
	return float(_ghost.get("time", INF))


func update(delta: float) -> void:
	# The lap clock starts when the car first crosses the line (standing start).
	if _lap_clock < 0.0 and car.progress >= 0.0:
		_start_lap(0.0)
	if _lap_clock >= 0.0:
		_lap_clock += delta
		_sample_clock += delta
		while _sample_clock >= DT:
			_sample_clock -= DT
			_samples.append(car.progress - _lap_base)
	_move_ghost(delta)
	_update_timer()


func _start_lap(base: float) -> void:
	_lap_base = base
	_lap_clock = 0.0
	_sample_clock = 0.0
	_samples = PackedFloat32Array([0.0])
	_ghost_t = 0.0 if not _ghost_d.is_empty() else -1.0


## Called by the race when a lap is completed.
func on_lap(lap_time: float, lap_index: int) -> void:
	# Lap 1 includes the standing start, so time it from the line crossing instead.
	var t := _lap_clock if _lap_clock > 0.0 else lap_time
	lap_times.append(t)
	var ghost_best := ghost_time()
	if t < _best:
		_best = t
		_best_samples = _samples.duplicate()
		_best_samples.append(race.world.track.length)
	var i: int = car.index
	if ghost_best < INF:
		var diff := t - ghost_best
		race.pads.toast(i, "%s%.2fs" % ["+" if diff >= 0.0 else "-", absf(diff)], Color(1.0, 0.45, 0.4) if diff >= 0.0 else Color(0.4, 1.0, 0.5), "vs ghost")
	else:
		race.pads.toast(i, "LAP %.2fs" % t, Color(0.85, 0.55, 1.0))
	_start_lap(float(lap_index) * race.world.track.length)


func _move_ghost(delta: float) -> void:
	if ghost_car == null or _ghost_t < 0.0:
		return
	_ghost_t += delta
	var f := _ghost_t / float(_ghost.dt)
	var i := int(f)
	var d: float
	if i >= _ghost_d.size() - 1:
		d = _ghost_d[_ghost_d.size() - 1]
	else:
		d = lerpf(_ghost_d[i], _ghost_d[i + 1], f - i)
	var s := _lap_base + d
	ghost_car.visible = car.state != Car.State.FINISHED
	ghost_car.position = race.world.track.point_at(s, car.lane_offset)
	ghost_car.rotation = race.world.track.tangent_at(s).angle()


func _update_timer() -> void:
	var laps := Game.race_laps()
	var lap := mini(lap_times.size() + 1, laps)
	var best_text := "--" if _best == INF else "%.2f" % _best
	var ghost_text := "" if ghost_time() == INF else "   GHOST %.2f" % ghost_time()
	_timer.text = "TIME TRIAL   LAP %d/%d   %.2f\nBEST %s%s" % [lap, laps, maxf(_lap_clock, 0.0), best_text, ghost_text]


func save_result(who: String) -> Dictionary:
	return Profile.record_trial(race.world.map.title, who, _best, _best_samples, DT)
