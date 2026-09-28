extends Node
## Autoload "Profile": everything that is kept between sessions: coins, unlocked car
## styles and what each player has equipped, records and stats, the daily challenge,
## and menu settings. Stored as JSON in user://profile.json.

const PATH := "user://profile.json"

const BODIES := [
	{"id": "classic", "name": "CLASSIC", "price": 0},
	{"id": "kart", "name": "KART", "price": 150},
	{"id": "f1", "name": "FORMULA", "price": 250},
	{"id": "muscle", "name": "MUSCLE", "price": 350},
	{"id": "buggy", "name": "BUGGY", "price": 300},
	{"id": "hover", "name": "HOVER", "price": 450},
]
const DECALS := [
	{"id": "none", "name": "PLAIN", "price": 0},
	{"id": "stripes", "name": "STRIPES", "price": 60},
	{"id": "number", "name": "NUMBER", "price": 80},
	{"id": "checker", "name": "CHECKER", "price": 100},
	{"id": "flames", "name": "FLAMES", "price": 150},
	{"id": "bolt", "name": "LIGHTNING", "price": 200},
	{"id": "polka", "name": "POLKA", "price": 90},
	{"id": "stars", "name": "STARS", "price": 120},
	{"id": "zigzag", "name": "ZIGZAG", "price": 130},
]
const TRAILS := [
	{"id": "color", "name": "CLASSIC", "price": 0},
	{"id": "fire", "name": "FIRE", "price": 120},
	{"id": "ice", "name": "ICE", "price": 120},
	{"id": "neon", "name": "NEON", "price": 160},
	{"id": "gold", "name": "GOLD", "price": 200},
	{"id": "rainbow", "name": "RAINBOW", "price": 300},
]

const PLACE_COINS := [30, 20, 12, 6]
const PERFECT_LAP_COINS := 5
const CLOSE_CALL_COINS := 2
const CHAMPION_COINS := 100
const DAILY_COINS := 100
const TUTORIAL_COINS := 50
const TRIAL_COINS := 15
const TRIAL_RECORD_COINS := 30

# id, name, how to get it, coin reward
const ACHIEVEMENTS := [
	["first_win", "FIRST VICTORY", "Win a race", 50],
	["clean_win", "SPOTLESS", "Win a race without crashing", 50],
	["flawless", "FLAWLESS", "Drive every lap of a race as a PERFECT LAP", 100],
	["perfect10", "PERFECTIONIST", "Drive 10 PERFECT LAPS in total", 60],
	["nitro5", "NITRO JUNKIE", "Fire nitro 5 times in one race", 50],
	["rocket3", "ROCKETEER", "Knock out 3 cars with rockets or mines in one race", 60],
	["shielded", "SAVED BY THE BUBBLE", "Let a shield block a crash, rocket, mine or lightning", 30],
	["photo_win", "BY A NOSE", "Win a photo finish", 60],
	["comeback", "COMEBACK KID", "Win after being last on a later lap", 80],
	["hard_win", "PRO RACER", "Win against HARD CPUs", 80],
	["rain_win", "STORM CHASER", "Win a race in the rain", 40],
	["night_win", "NIGHT OWL", "Win a race at night", 40],
	["cup_win", "CHAMPION", "Win a championship", 100],
	["world_tour", "WORLD TOUR", "Win on every track", 150],
	["record", "RECORD BREAKER", "Set a new time-trial best lap", 40],
	["stylish", "STYLE ICON", "Unlock 3 garage items", 30],
	["career", "CAREER STAR", "Win Blaze's Final in career mode", 150],
	["superstar", "SUPERSTAR", "Earn every star in career mode", 200],
]

var data := {}


func _ready() -> void:
	load_profile()


func _defaults() -> Dictionary:
	return {
		"coins": 0,
		"coins_earned": 0,
		"unlocked": ["classic", "none"],
		"equipped": [["classic", "none"], ["classic", "none"], ["classic", "none"], ["classic", "none"]],
		"best_laps": {}, # map title -> {"time": float, "who": String}
		"wins": [0, 0, 0, 0],
		"races": [0, 0, 0, 0],
		"crashes": [0, 0, 0, 0],
		"perfect_laps": 0,
		"championships": 0,
		"daily": {"date": "", "done": false},
		"tutorial_done": false,
		"ghosts": {}, # map title -> {"time": float, "dt": float, "d": [distance along the lap]}
		"achievements": [],
		"map_wins": {}, # map title -> human wins there
		"settings": {},
		"career": [], # stars bitmask per career event
	}


func load_profile() -> void:
	data = _defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


# --- Coins and unlocks ------------------------------------------------------

func coins() -> int:
	return int(data.coins)


func add_coins(amount: int) -> void:
	data.coins = coins() + amount
	data.coins_earned = int(data.coins_earned) + amount


func is_unlocked(id: String) -> bool:
	return data.unlocked.has(id) or id in ["classic", "none", "color"] # free defaults


func buy(id: String, price: int) -> bool:
	if is_unlocked(id) or coins() < price:
		return false
	data.coins = coins() - price
	data.unlocked.append(id)
	if data.unlocked.size() >= 5: # 2 free items + 3 bought
		unlock("stylish")
	save()
	return true


## Equipped style for a player slot: [body id, decal id, trail id].
func style(slot: int) -> Array:
	var e: Array = data.equipped
	var s: Array = (e[slot] as Array).duplicate() if slot < e.size() else []
	var defaults := ["classic", "none", "color"]
	while s.size() < defaults.size(): # older saves had no trail
		s.append(defaults[s.size()])
	return s


## kind: 0 body, 1 decal, 2 trail.
func equip(slot: int, kind: int, id: String) -> void:
	var s: Array = style(slot)
	s[kind] = id
	while data.equipped.size() <= slot:
		data.equipped.append(["classic", "none", "color"])
	data.equipped[slot] = s
	save()


# --- Settings -----------------------------------------------------------------

func setting(key: String, default):
	return data.settings.get(key, default)


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save()


# --- Daily challenge -------------------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


## Today's challenge: {id, text, map}. The same for everyone on the same date.
func daily_challenge() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today())
	var map_title: String = Game.MAPS[rng.randi() % Game.MAPS.size()].build().title
	var options := [
		{"id": "win_map", "text": "Win a race on %s" % map_title},
		{"id": "no_crash_win", "text": "Win a race without crashing"},
		{"id": "perfect2", "text": "Drive 2 PERFECT LAPS in one race"},
		{"id": "nitro3", "text": "Fire nitro 3 times in one race"},
		{"id": "beat_hard", "text": "Win against HARD CPUs"},
		{"id": "close3", "text": "Pull off 3 CLOSE CALLS in one race"},
		{"id": "win_margin", "text": "Win by more than 1 second"},
	]
	var c: Dictionary = options[rng.randi() % options.size()]
	c["map"] = map_title
	return c


func daily_done() -> bool:
	return data.daily.get("date", "") == today() and data.daily.get("done", false)


func _meets(c: Dictionary, race: Dictionary, car: Dictionary) -> bool:
	var won: bool = car.place == 1
	match c.id:
		"win_map": return won and race.map == c.map
		"no_crash_win": return won and car.crashes == 0
		"perfect2": return car.perfect_laps >= 2
		"nitro3": return car.nitros >= 3
		"beat_hard": return won and race.cpus > 0 and race.cpu_level == 2
		"close3": return car.close_calls >= 3
		"win_margin": return won and race.margin > 1.0
	return false


# --- Recording a race -----------------------------------------------------------------

## Updates stats, records, coins and the daily challenge after a race.
## race = {map, cpus, cpu_level, margin, cars: [{index, human, name, place, crashes,
## perfect_laps, nitros, close_calls, best_lap}]}.
## Returns {coins, record: {time, who} or {}, daily: bool}.
func record_race(race: Dictionary) -> Dictionary:
	var earned := 0
	var record := {}
	var daily := false
	var challenge := daily_challenge()
	for car in race.cars:
		if not car.human:
			continue
		var i: int = car.index
		data.races[i] = int(data.races[i]) + 1
		data.crashes[i] = int(data.crashes[i]) + int(car.crashes)
		data.perfect_laps = int(data.perfect_laps) + int(car.perfect_laps)
		if car.place == 1:
			data.wins[i] = int(data.wins[i]) + 1
		earned += PLACE_COINS[clampi(car.place - 1, 0, 3)]
		earned += int(car.perfect_laps) * PERFECT_LAP_COINS + int(car.close_calls) * CLOSE_CALL_COINS
		# Track record (humans only).
		var best: float = car.best_lap
		if best > 0.0 and best < INF:
			var current: Dictionary = data.best_laps.get(race.map, {})
			if current.is_empty() or best < float(current.time):
				data.best_laps[race.map] = {"time": best, "who": car.name}
				if record.is_empty() or best < float(record.time):
					record = {"time": best, "who": car.name}
		if not daily_done() and not daily and _meets(challenge, race, car):
			daily = true
		_check_achievements(race, car)
	if daily:
		data.daily = {"date": today(), "done": true}
		earned += DAILY_COINS
	add_coins(earned)
	save()
	return {"coins": earned, "record": record, "daily": daily}


func record_championship(champion_is_human: bool) -> int:
	data.championships = int(data.championships) + 1
	var bonus := CHAMPION_COINS if champion_is_human else 0
	if champion_is_human:
		unlock("cup_win")
	add_coins(bonus)
	save()
	return bonus


# --- Achievements ----------------------------------------------------------------

## Achievements unlocked since the last call (the results screen shows them).
var recent_achievements: Array[String] = []


func has_achievement(id: String) -> bool:
	return data.achievements.has(id)


## Unlocks an achievement (once) and pays its reward. Returns true if it was new.
func unlock(id: String) -> bool:
	if has_achievement(id):
		return false
	for a in ACHIEVEMENTS:
		if a[0] == id:
			data.achievements.append(id)
			add_coins(int(a[3]))
			recent_achievements.append(a[1])
			save()
			return true
	return false


func take_recent_achievements() -> Array[String]:
	var out := recent_achievements.duplicate()
	recent_achievements.clear()
	return out


## Race-based achievements; `car` is a human's entry from the race summary.
func _check_achievements(race: Dictionary, car: Dictionary) -> void:
	var won: bool = car.place == 1
	if won:
		unlock("first_win")
		if car.crashes == 0:
			unlock("clean_win")
		if race.cpus > 0 and race.cpu_level == 2:
			unlock("hard_win")
		if race.weather == "rain":
			unlock("rain_win")
		if race.weather == "night":
			unlock("night_win")
		if car.get("photo", false):
			unlock("photo_win")
		if car.get("was_last", false) and race.cars.size() > 2:
			unlock("comeback")
		data.map_wins[race.map] = int(data.map_wins.get(race.map, 0)) + 1
		var every := true
		for m in Game.MAPS:
			if int(data.map_wins.get(m.build().title, 0)) == 0:
				every = false
		if every:
			unlock("world_tour")
	if car.perfect_laps >= race.get("laps", 99):
		unlock("flawless")
	if int(data.perfect_laps) >= 10:
		unlock("perfect10")
	if car.nitros >= 5:
		unlock("nitro5")
	if car.get("rocket_hits", 0) >= 3:
		unlock("rocket3")


# --- Career ------------------------------------------------------------------------

## Stars bitmask earned so far on career event `i`.
func career_stars(i: int) -> int:
	var c: Array = data.career
	return int(c[i]) if i < c.size() else 0


func career_unlocked(i: int) -> bool:
	return i == 0 or career_stars(i - 1) & Game.CareerEvents.PODIUM != 0


func career_total() -> int:
	var total := 0
	for i in Game.CareerEvents.count():
		total += Game.CareerEvents.star_count(career_stars(i))
	return total


## Saves a career result; returns {new: bitmask of stars earned for the first time, coins}.
func record_career(i: int, bits: int) -> Dictionary:
	var before := career_stars(i)
	var fresh := bits & ~before
	while data.career.size() <= i:
		data.career.append(0)
	data.career[i] = before | bits
	var coins := Game.CareerEvents.star_count(fresh) * Game.CareerEvents.STAR_COINS
	add_coins(coins)
	if i == Game.CareerEvents.count() - 1 and bits & Game.CareerEvents.WIN:
		unlock("career")
	if career_total() == Game.CareerEvents.count() * 3:
		unlock("superstar")
	save()
	return {"new": fresh, "coins": coins}


# --- Tutorial and time trial -------------------------------------------------------

## Returns the coins given (only the first time).
func complete_tutorial() -> int:
	if data.tutorial_done:
		return 0
	data.tutorial_done = true
	add_coins(TUTORIAL_COINS)
	save()
	return TUTORIAL_COINS


func ghost(map_title: String) -> Dictionary:
	return data.ghosts.get(map_title, {})


## Time trial finished. `best_lap` with its `ghost` samples. Returns {coins, record}.
func record_trial(map_title: String, who: String, best_lap: float, ghost_samples: PackedFloat32Array, dt: float) -> Dictionary:
	var earned := TRIAL_COINS
	var record := false
	var current: Dictionary = data.ghosts.get(map_title, {})
	if best_lap < INF and (current.is_empty() or best_lap < float(current.time)):
		data.ghosts[map_title] = {"time": best_lap, "dt": dt, "d": Array(ghost_samples)}
		record = not current.is_empty()
		if record:
			earned += TRIAL_RECORD_COINS
			unlock("record")
	var track_rec: Dictionary = data.best_laps.get(map_title, {})
	if best_lap < INF and (track_rec.is_empty() or best_lap < float(track_rec.time)):
		data.best_laps[map_title] = {"time": best_lap, "who": who}
	add_coins(earned)
	save()
	return {"coins": earned, "record": record}
