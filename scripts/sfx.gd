extends Node
## Autoload "Sfx": all sounds and music are synthesized in code, so the game needs no
## audio files. Music is rendered on a worker thread at startup and starts once ready.

const RATE := 22050

var enabled := true
var music_enabled := true
var cheer: AudioStreamWAV
var rain: AudioStreamWAV
var pickup: AudioStreamWAV
var _ambient: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music := {} # name -> AudioStreamWAV, filled by the worker thread
var _music_task := -1
var _wanted_music := ""
var engine: AudioStreamWAV
var crash: AudioStreamWAV
var beep: AudioStreamWAV
var go: AudioStreamWAV
var boost: AudioStreamWAV
var lap: AudioStreamWAV
var fanfare: AudioStreamWAV

var _voices: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _lp := 0.0


func _ready() -> void:
	_rng.seed = 42
	engine = _make(0.5, _engine, true)
	crash = _make(0.7, _crash)
	beep = _make(0.18, func(t, d): return _tone(t, d, 660.0) * 0.5)
	go = _make(0.5, func(t, d): return _tone(t, d, 990.0) * 0.55)
	boost = _make(0.7, _boost)
	lap = _make(0.35, _lap)
	fanfare = _make(0.9, _fanfare)
	cheer = _make(1.4, _cheer)
	rain = _make(2.0, _rain, true)
	pickup = _make(0.35, _pickup)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -13.0
	add_child(_music_player)
	_start_next_render()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)


func play(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	for p in _voices:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Switches the background music ("menu", "race0".."race2" or "" for silence).
func play_music(name: String) -> void:
	_wanted_music = name
	_sync_music()


## Looping background ambience (rain), or null to stop it.
func play_ambient(stream: AudioStream) -> void:
	if stream == null or not enabled:
		_ambient.stop()
		return
	_ambient.stream = stream
	_ambient.play()


## Slows the music down (used for the slow-motion photo finish).
func set_music_pitch(pitch: float) -> void:
	_music_player.pitch_scale = pitch
	music_pitch = pitch


var music_pitch := 1.0


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	_sync_music()


## Silence everything while the game is in the background (phone Home button, app
## switch, browser tab hidden) and bring it back when the player returns.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if what == NOTIFICATION_APPLICATION_PAUSED or OS.has_feature("mobile") or OS.has_feature("web"):
				_set_background(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_background(false)


func _set_background(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_sync_music()
		_start_next_render()


func _sync_music() -> void:
	var stream: AudioStreamWAV = _music.get(_wanted_music) if music_enabled else null
	if stream == null:
		_music_player.stop()
		_music_player.stream = null
	elif _music_player.stream != stream or not _music_player.playing:
		_music_player.stream = stream
		_music_player.pitch_scale = music_pitch
		_music_player.play()


var _render_queue := ["menu", "race0", "race1", "race2"]


## Music is rendered one track at a time (menu first) on a worker thread. On the
## single-threaded web build each task runs in one go, so splitting them up keeps
## any single pause short.
func _start_next_render() -> void:
	if _render_queue.is_empty():
		return
	var name: String = _render_queue.pop_front()
	_music_task = WorkerThreadPool.add_task(_render_one.bind(name))


func _render_one(name: String) -> void:
	var stream: AudioStreamWAV
	if name == "menu":
		stream = _render_menu_music()
	else:
		stream = _render_race_music(RACE_THEMES[int(name.substr(4))])
	var music := _music.duplicate()
	music[name] = stream
	_music = music


## A looping engine player for one car; the caller changes its pitch with speed.
func make_engine() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = engine
	p.volume_db = -30.0
	return p


func _make(duration: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	_lp = 0.0
	for i in n:
		var v: float = fn.call(float(i) / RATE, duration)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


static func _saw(f: float, t: float) -> float:
	return 2.0 * fposmod(t * f, 1.0) - 1.0


static func _tone(t: float, d: float, f: float) -> float:
	var env := minf(1.0, t / 0.005) * (1.0 - t / d)
	return sin(TAU * f * t) * env


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _engine(t: float, _d: float) -> float:
	# Frequencies are multiples of 2 Hz so the 0.5 s loop is seamless.
	var v := 0.45 * _saw(96.0, t) + 0.3 * _saw(144.0, t) + 0.35 * sin(TAU * 48.0 * t)
	v *= 0.75 + 0.25 * sin(TAU * 24.0 * t)
	_lp += (v + _noise() * 0.15 - _lp) * 0.25
	return _lp * 0.7


func _crash(t: float, _d: float) -> float:
	_lp += (_noise() - _lp) * 0.35
	return _lp * exp(-t * 5.0) * 1.2 + sin(TAU * 55.0 * t) * exp(-t * 9.0) * 0.7


func _boost(t: float, d: float) -> float:
	var cutoff := 0.05 + 0.4 * (t / d)
	_lp += (_noise() - _lp) * cutoff
	return _lp * sin(PI * t / d) * 1.1


func _lap(t: float, d: float) -> float:
	var f := 880.0 if t < 0.12 else 1320.0
	var local := fmod(t, 0.12) if t < 0.12 else t - 0.12
	return sin(TAU * f * t) * exp(-local * 12.0) * 0.45 * (1.0 - t / d)


func _rain(_t: float, _d: float) -> float:
	# Soft hiss plus random drops.
	var hiss := _noise() * 0.25
	_lp += (hiss - _lp) * 0.6
	var drop := _noise() * 0.9 if _rng.randf() < 0.0015 else 0.0
	return (hiss - _lp) * 1.3 + drop


func _pickup(t: float, d: float) -> float:
	var f := 600.0 + 900.0 * t / d
	return sin(TAU * f * t) * (1.0 - t / d) * 0.45


func _cheer(t: float, d: float) -> float:
	# A crowd: band-limited noise that swells, with lots of little "voices" in it.
	_lp += (_noise() - _lp) * 0.3
	var env := sin(PI * minf(t / d * 1.4, 1.0)) * (1.0 - t / d * 0.5)
	var voices := 0.6 + 0.4 * sin(TAU * 7.0 * t + sin(TAU * 3.1 * t) * 2.0)
	return _lp * env * voices * 1.4


# --- Music --------------------------------------------------------------------
# A tiny sequencer: notes are rendered straight into `_buf` (a member, since packed
# arrays are copied when passed to functions), with tails wrapping around so the
# loop is seamless.

var _buf := PackedFloat32Array()

static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = buf.size()
	return s


func _note(start: float, length: float, freq: float, vol: float, wave: int, attack := 0.005, release := 0.08) -> void:
	# wave: 0 sine, 1 square-ish, 2 saw-ish, 3 triangle
	var n := _buf.size()
	var i0 := int(start * RATE)
	var count := int((length + release) * RATE)
	var phase := 0.0
	var step := freq / RATE
	for j in count:
		var t := float(j) / RATE
		var env := minf(1.0, t / attack)
		if t > length:
			env *= maxf(0.0, 1.0 - (t - length) / release)
		var v: float
		match wave:
			0: v = sin(TAU * phase)
			1: v = 0.6 * sin(TAU * phase) + 0.25 * sin(TAU * phase * 3.0) + 0.12 * sin(TAU * phase * 5.0)
			2: v = 0.6 * sin(TAU * phase) + 0.3 * sin(TAU * phase * 2.0) + 0.15 * sin(TAU * phase * 3.0)
			_: v = 1.0 - 4.0 * absf(fposmod(phase, 1.0) - 0.5)
		_buf[(i0 + j) % n] += v * env * vol
		phase += step


func _kick(start: float, vol: float) -> void:
	var n := _buf.size()
	var i0 := int(start * RATE)
	var phase := 0.0
	for j in int(0.18 * RATE):
		var t := float(j) / RATE
		phase += (45.0 + 110.0 * exp(-t * 30.0)) / RATE
		_buf[(i0 + j) % n] += sin(TAU * phase) * exp(-t * 16.0) * vol


func _hit(start: float, length: float, vol: float, bright: float) -> void:
	# Noise hit: snare (bright ~0.5) or hi-hat (bright ~0.95).
	var n := _buf.size()
	var i0 := int(start * RATE)
	var prev := 0.0
	for j in int(length * RATE):
		var t := float(j) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		var v := x - prev * bright
		prev = x
		_buf[(i0 + j) % n] += v * exp(-t / length * 5.0) * vol


## Race themes: tempo, 4-bar chord loop (MIDI notes), arpeggio pattern, bass
## rhythm (8ths, or root-fifth bounce) and lead tone. Each track uses one of these.
const RACE_THEMES := [
	{"bpm": 128.0, "chords": [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], # Am F C G
		"arp": [0, 1, 2, 1], "bass": "eighths", "wave": 1, "lift": 12},
	{"bpm": 140.0, "chords": [[48, 52, 55], [55, 59, 62], [57, 60, 64], [53, 57, 60]], # C G Am F
		"arp": [0, 2, 1, 2], "bass": "bounce", "wave": 3, "lift": 12},
	{"bpm": 120.0, "chords": [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]], # Dm Bb Gm A
		"arp": [0, 1, 2, 0], "bass": "sixteenths", "wave": 2, "lift": 0},
]


func _render_race_music(theme: Dictionary) -> AudioStreamWAV:
	var beat: float = 60.0 / float(theme.bpm)
	_buf = PackedFloat32Array()
	_buf.resize(int(beat * 16.0 * RATE))
	var arp: Array = theme.arp
	for bar in 4:
		var chord: Array = theme.chords[bar]
		var t0 := bar * 4.0 * beat
		var root: int = chord[0] - 12
		match theme.bass:
			"bounce":
				for e in 8:
					var tone := root + (7 if e % 2 == 1 else 0)
					_note(t0 + e * beat * 0.5, beat * 0.4, _midi(tone), 0.32, 2, 0.004, 0.03)
			"sixteenths":
				for e in 16:
					_note(t0 + e * beat * 0.25, beat * 0.2, _midi(root - (12 if e % 8 == 0 else 0)), 0.26, 2, 0.003, 0.02)
			_:
				for e in 8:
					_note(t0 + e * beat * 0.5, beat * 0.42, _midi(root + (12 if e % 4 == 3 else 0)), 0.32, 2, 0.004, 0.03)
		for s16 in 16:
			var tone: int = chord[arp[s16 % 4]] + (12 if s16 >= 8 else 0) + int(theme.lift)
			_note(t0 + s16 * beat * 0.25, beat * 0.2, _midi(tone), 0.11, int(theme.wave), 0.003, 0.03)
		for b in 4:
			_kick(t0 + b * beat, 0.75)
			if b % 2 == 1:
				_hit(t0 + b * beat, 0.16, 0.28, 0.45)
			_hit(t0 + b * beat + beat * 0.5, 0.04, 0.12, 0.95)
			if theme.bass == "bounce":
				_hit(t0 + b * beat + beat * 0.25, 0.03, 0.06, 0.95)
				_hit(t0 + b * beat + beat * 0.75, 0.03, 0.06, 0.95)
	return _to_wav(_buf)


func _render_menu_music() -> AudioStreamWAV:
	# 96 BPM, 4 bars: Cmaj7 - Am7 - Fmaj7 - G6. Soft pads and a gentle arpeggio.
	var beat := 60.0 / 96.0
	_buf = PackedFloat32Array()
	_buf.resize(int(beat * 16.0 * RATE))
	var chords := [[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59]]
	for bar in 4:
		var chord: Array = chords[bar]
		var t0 := bar * 4.0 * beat
		for k in chord.size():
			_note(t0, beat * 3.8, _midi(chord[k]), 0.1, 0, 0.3, 0.5)
		for e in 8:
			var tone: int = chord[[1, 2, 3, 2][e % 4]] + 12
			_note(t0 + e * beat * 0.5, beat * 0.4, _midi(tone), 0.08, 3, 0.01, 0.25)
		_note(t0, beat * 1.8, _midi(chord[0] - 12), 0.22, 0, 0.02, 0.3)
		_note(t0 + beat * 2.0, beat * 1.8, _midi(chord[0] - 12), 0.18, 0, 0.02, 0.3)
		for b in 4:
			_hit(t0 + b * beat + beat * 0.5, 0.03, 0.05, 0.95)
	return _to_wav(_buf)


func _fanfare(t: float, _d: float) -> float:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var idx := mini(int(t / 0.14), 3)
	var local := t - idx * 0.14
	var f: float = notes[idx]
	var decay := 3.0 if idx == 3 else 10.0
	return (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-local * decay) * 0.4
