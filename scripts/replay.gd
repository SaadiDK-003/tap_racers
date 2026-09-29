extends Node
## Race replay: keeps the last few seconds of the race in a small rolling buffer
## (30 samples a second of what each car looks like, plus the train and rockets).
## When something exciting happens, the seconds around it are kept as a clip if it
## beats the race's best moment so far. After the finish, the best clip plays back
## in slow motion with the camera on the action, re-playing its bursts and sounds.
## Cheap: ~40 floats per sample; playback reuses the normal car / train / rocket drawing.

const Car = preload("res://scripts/car.gd")

const RATE := 30.0 # samples per second
const BEFORE := 1.5 # seconds of a clip before the moment
const AFTER := 1.3 # ...and after it
const KEEP := BEFORE + AFTER + 0.6 # seconds in the rolling buffer
const SPEED := 0.6 # playback speed (slow motion)
const ZOOM := 1.35
const MIN_SCORE := 50 # moments below this don't get a replay
const F := 9 # floats per car per sample

var world
var cars: Array = []

var _buf: Array = [] # samples: {t, cars: PackedFloat32Array, train: float, rockets: PackedFloat32Array}
var _fx: Array = [] # {t, kind, pos, color, car}
var _next_t := 0.0
var _pending: Array = [] # moments waiting for their AFTER seconds: {t, score, focus, label}
var clip := {} # the best moment: {score, label, focus, t0, t1, samples, fx}

# Playback.
var playing := false
var _rt := 0.0 # clip time being shown
var _i := 0 # sample index
var _fx_i := 0
var _saved := {}
var _cam := Vector2.ZERO


func setup(world_node) -> void:
	world = world_node
	cars = world.cars


# --- Recording ---------------------------------------------------------------------

func record(t: float) -> void:
	if t < _next_t:
		return
	_next_t = t + 1.0 / RATE
	var c := PackedFloat32Array()
	c.resize(cars.size() * F)
	for k in cars.size():
		var car = cars[k]
		var o := k * F
		c[o] = car.position.x
		c[o + 1] = car.position.y
		c[o + 2] = car.rotation
		c[o + 3] = car.scale.x
		c[o + 4] = car.modulate.a
		c[o + 5] = car.speed
		c[o + 6] = car._flame_power
		c[o + 7] = (1 if car.boosting else 0) + (2 if car.shield else 0) + (4 if car.z_index > 0 else 0) + (8 if car.throttle else 0)
		c[o + 8] = car.z_index
	var train_head := NAN
	if world.train and world.train.state == world.train.State.PASSING:
		train_head = world.train.head
	var rockets := PackedFloat32Array()
	if world.powerups:
		for r in world.powerups._rockets:
			rockets.append_array([r.s, r.lane, r.dir, r.shooter.index, r.target.index])
	var arm := 0.0
	var lit := false
	if world.train:
		arm = world.train._arm
		lit = world.train.active()
	_buf.append({"t": t, "cars": c, "train": train_head, "train_dir": world.train.dir if world.train else 1.0,
		"arm": arm, "lit": lit, "rockets": rockets})
	while _buf.size() > 2 and t - _buf[0].t > KEEP:
		_buf.pop_front()
	while _fx.size() > 0 and t - _fx[0].t > KEEP:
		_fx.pop_front()


## A visual / sound event to re-play in a clip ("crash", "splash", "land", "nitro").
func fx(t: float, kind: String, car) -> void:
	_fx.append({"t": t, "kind": kind, "pos": car.position, "color": car.color, "car": car.index})


## Something exciting happened to `focus` (a car index): keep it if it's the best yet.
func note(t: float, score: int, focus: int, label: String) -> void:
	if score < MIN_SCORE or score <= int(clip.get("score", 0)):
		return
	for p in _pending:
		if absf(p.t - t) < 0.8: # same moment: keep the bigger one
			if score > p.score:
				p.score = score
				p.focus = focus
				p.label = label
			return
	_pending.append({"t": t, "score": score, "focus": focus, "label": label})


## Saves moments once their AFTER seconds have been recorded (or at the finish, `now`).
func update(t: float, now := false) -> void:
	for p in _pending.duplicate():
		if not now and t < p.t + AFTER:
			continue
		_pending.erase(p)
		if p.score <= int(clip.get("score", 0)):
			continue
		var samples := _buf.filter(func(s): return s.t >= p.t - BEFORE and s.t <= p.t + AFTER)
		if samples.size() < 10:
			continue
		clip = {"score": p.score, "label": p.label, "focus": p.focus, "t0": samples[0].t,
			"t1": samples[samples.size() - 1].t, "samples": samples,
			"fx": _fx.filter(func(e): return e.t >= samples[0].t and e.t <= samples[samples.size() - 1].t)}


func has_clip() -> bool:
	return not clip.is_empty()


# --- Playback ----------------------------------------------------------------------

func start() -> void:
	playing = true
	_rt = clip.t0
	_i = 0
	_fx_i = 0
	# Remember how everything looks now, to put it back afterwards.
	_saved = {"cars": [], "rockets": world.powerups._rockets.duplicate() if world.powerups else [], "train": {}}
	for car in cars:
		_saved.cars.append({"pos": car.position, "rot": car.rotation, "scale": car.scale, "a": car.modulate.a,
			"speed": car.speed, "flame": car._flame_power, "boost": car.boosting, "shield": car.shield,
			"z": car.z_index, "throttle": car.throttle, "trail": car.trail.duplicate()})
		car.trail.clear()
	if world.powerups:
		world.powerups.set_process(false)
		world.powerups._rockets.clear()
	if world.train:
		var tr = world.train
		_saved.train = {"state": tr.state, "head": tr.head, "dir": tr.dir, "visible": tr.visible, "arm": tr._arm, "blink": tr._blink}
		tr.set_process(false)
	var s0: Dictionary = clip.samples[0]
	_cam = _car_pos(s0, clip.focus)
	world.hold_view = true # the replay moves the camera (end_view() hands it back)


## Advances playback by `delta` (already slowed by Engine.time_scale). False when done.
func step(delta: float) -> bool:
	_rt += delta
	var samples: Array = clip.samples
	while _i < samples.size() - 2 and samples[_i + 1].t <= _rt:
		_i += 1
	var a: Dictionary = samples[_i]
	var b: Dictionary = samples[mini(_i + 1, samples.size() - 1)]
	var f := clampf((_rt - a.t) / maxf(b.t - a.t, 0.001), 0.0, 1.0)
	_apply(a, b, f)
	while _fx_i < clip.fx.size() and clip.fx[_fx_i].t <= _rt:
		_play_fx(clip.fx[_fx_i])
		_fx_i += 1
	# Camera: follow the car the moment is about, zooming in at the start.
	_cam = _cam.lerp(_car_pos(a, clip.focus).lerp(_car_pos(b, clip.focus), f), minf(1.0, delta * 6.0))
	var zoom := lerpf(1.0, ZOOM, clampf((_rt - clip.t0) / 0.35, 0.0, 1.0))
	world.view_at(_cam, zoom, 0.0)
	return _rt < clip.t1


func stop() -> void:
	playing = false
	for k in cars.size():
		var car = cars[k]
		var s: Dictionary = _saved.cars[k]
		car.position = s.pos
		car.rotation = s.rot
		car.scale = s.scale
		car.modulate.a = s.a
		car.speed = s.speed
		car._flame_power = s.flame
		car.boosting = s.boost
		car.shield = s.shield
		car.z_index = s.z
		car.throttle = s.throttle
		car.trail = s.trail
		_redraw(car)
	if world.powerups:
		world.powerups._rockets.assign(_saved.rockets)
		world.powerups.set_process(true)
		world.powerups.queue_redraw()
	if world.train and not _saved.train.is_empty():
		var tr = world.train
		tr.state = _saved.train.state
		tr.head = _saved.train.head
		tr.dir = _saved.train.dir
		tr.visible = _saved.train.visible
		tr._arm = _saved.train.arm
		tr._blink = _saved.train.blink
		tr.signals_node().queue_redraw()
		tr.set_process(true)
		tr.queue_redraw()
	world.end_view()


func _car_pos(s: Dictionary, k: int) -> Vector2:
	var c: PackedFloat32Array = s.cars
	return Vector2(c[k * F], c[k * F + 1])


func _apply(a: Dictionary, b: Dictionary, f: float) -> void:
	var ca: PackedFloat32Array = a.cars
	var cb: PackedFloat32Array = b.cars
	for k in cars.size():
		var car = cars[k]
		var o := k * F
		car.position = Vector2(lerpf(ca[o], cb[o], f), lerpf(ca[o + 1], cb[o + 1], f))
		car.rotation = lerp_angle(ca[o + 2], cb[o + 2], f)
		var sc := lerpf(ca[o + 3], cb[o + 3], f)
		car.scale = Vector2(sc, sc)
		car.modulate.a = lerpf(ca[o + 4], cb[o + 4], f)
		car.speed = lerpf(ca[o + 5], cb[o + 5], f)
		car._flame_power = lerpf(ca[o + 6], cb[o + 6], f)
		var flags := int(ca[o + 7])
		car.boosting = flags & 1 != 0
		car.shield = flags & 2 != 0
		car.throttle = flags & 8 != 0
		car.z_index = int(ca[o + 8])
		car._update_trail()
		car._update_engine()
		_redraw(car)
	if world.train:
		var tr = world.train
		# Crossing signals as they were: barrier position, lamps flashing in turn.
		tr._arm = lerpf(a.arm, b.arm, f)
		tr._blink = bool(a.lit) and int(_rt / 0.3) % 2 == 0
		tr.state = tr.State.WARNING if a.lit else tr.State.IDLE # the lamps read this
		tr.signals_node().queue_redraw()
		var h: float = a.train
		if is_nan(h):
			tr.visible = false
		else:
			tr.state = tr.State.PASSING
			tr.dir = a.train_dir
			tr.head = h if is_nan(float(b.train)) else lerpf(h, b.train, f)
			tr.visible = true
			tr.queue_redraw()
	if world.powerups:
		var list: Array[Dictionary] = world.powerups._rockets
		list.clear()
		var r: PackedFloat32Array = a.rockets
		for j in range(0, r.size(), 5):
			list.append({"s": r[j], "lane": r[j + 1], "dir": r[j + 2], "shooter": cars[int(r[j + 3])], "target": cars[int(r[j + 4])]})
		world.powerups.queue_redraw()


func _redraw(car) -> void:
	car.queue_redraw()
	car._glow.queue_redraw()
	car._flame.queue_redraw()


func _play_fx(e: Dictionary) -> void:
	var fx_node = world.effects
	match e.kind:
		"crash":
			fx_node.burst(e.pos, e.color)
			Sfx.play(Sfx.crash, -3.0, randf_range(0.8, 0.9))
		"splash":
			fx_node.splash(e.pos)
			Sfx.play(Sfx.crash, -4.0, 0.5)
		"land":
			fx_node.land_dust(e.pos)
		"nitro":
			fx_node.shockwave(e.pos, Car.NITRO_COLOR)
			Sfx.play(Sfx.boost, -4.0, 0.85)
		"bolt":
			fx_node.bolt(cars[e.car])
