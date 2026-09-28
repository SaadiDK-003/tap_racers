extends RefCounted
## Career mode: ten solo events against named CPU rivals, from rookie races to
## Blaze's final. Each event pays up to three stars: a podium (which unlocks the
## next event), a win, and the event's own goal (only counts on the podium).

const PODIUM := 1
const WIN := 2
const GOAL := 4
const STAR_COINS := 25 # for every star earned for the first time

# map = index into Game.MAPS; level = CPU level; weather: 1 clear, 2 rain, 3 night.
const EVENTS := [
	{"title": "ROOKIE RUN", "map": 2, "level": 0, "rivals": ["ROOKIE RAY", "GRANNY SPEED", "ZIPPY"],
		"laps": 5, "items": false, "weather": 1, "goal": "no_crash"},
	{"title": "SUNSET SPRINT", "map": 0, "level": 0, "rivals": ["ZIPPY", "TURBO TINA", "ROOKIE RAY"],
		"laps": 5, "items": true, "weather": 1, "goal": "nitro3"},
	{"title": "BEACH PARTY", "map": 4, "level": 1, "rivals": ["GRANNY SPEED", "CAPTAIN CRASH", "ZIPPY"],
		"laps": 5, "items": true, "weather": 1, "goal": "close3"},
	{"title": "STORMY HAIRPINS", "map": 1, "level": 1, "rivals": ["PROFESSOR PIT", "TURBO TINA", "GRANNY SPEED"],
		"laps": 5, "items": false, "weather": 2, "goal": "no_crash"},
	{"title": "FARMYARD FEUD", "map": 10, "level": 1, "rivals": ["CAPTAIN CRASH", "DUCHESS", "ROOKIE RAY"],
		"laps": 5, "items": true, "weather": 1, "goal": "rocket1"},
	{"title": "ICE COLD", "map": 3, "level": 1, "rivals": ["PROFESSOR PIT", "DUCHESS", "TURBO TINA"],
		"laps": 5, "items": false, "weather": 1, "goal": "perfect1"},
	{"title": "DOCKS AFTER DARK", "map": 11, "level": 1, "rivals": ["DUCHESS", "CAPTAIN CRASH", "ZIPPY"],
		"laps": 5, "items": true, "weather": 3, "goal": "margin2"},
	{"title": "SPLASH DOWN", "map": 12, "level": 2, "rivals": ["CAPTAIN CRASH", "ZIPPY", "TURBO TINA"],
		"laps": 5, "items": false, "weather": 1, "goal": "no_crash"},
	{"title": "NEON SHOWDOWN", "map": 7, "level": 2, "rivals": ["DUCHESS", "PROFESSOR PIT", "TURBO TINA"],
		"laps": 5, "items": true, "weather": 3, "goal": "nitro3"},
	{"title": "BLAZE'S FINAL", "map": 6, "level": 2, "rivals": ["BLAZE", "DUCHESS", "PROFESSOR PIT"],
		"laps": 6, "items": true, "weather": 1, "goal": "margin2"},
]

const GOALS := {
	"no_crash": "Podium without crashing",
	"nitro3": "Podium + fire nitro 3 times",
	"close3": "Podium + 3 CLOSE CALLS",
	"rocket1": "Podium + hit a rival with an item",
	"perfect1": "Podium + drive a PERFECT LAP",
	"margin2": "Win by 2 seconds or more",
}


static func count() -> int:
	return EVENTS.size()


static func event(i: int) -> Dictionary:
	return EVENTS[i]


static func goal_text(i: int) -> String:
	return GOALS[EVENTS[i].goal]


## Stars (bitmask) for P1's result. stats = {place, crashes, nitros, close_calls,
## perfect_laps, rocket_hits, margin}.
static func stars_for(i: int, stats: Dictionary) -> int:
	var place: int = stats.place
	if place < 1 or place > 3:
		return 0
	var bits := PODIUM
	if place == 1:
		bits |= WIN
	var met := false
	match EVENTS[i].goal:
		"no_crash": met = int(stats.crashes) == 0
		"nitro3": met = int(stats.nitros) >= 3
		"close3": met = int(stats.close_calls) >= 3
		"rocket1": met = int(stats.rocket_hits) >= 1
		"perfect1": met = int(stats.perfect_laps) >= 1
		"margin2": met = place == 1 and float(stats.margin) >= 2.0
	if met:
		bits |= GOAL
	return bits


static func star_count(bits: int) -> int:
	return (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1)
