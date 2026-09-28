extends RefCounted
## CPU driver personalities: a name, a short tag for the pad button, and lines they
## say in a speech bubble at key moments.

const ROSTER := [
	{"name": "BLAZE", "tag": "BLAZE", "lines": {
		"start": ["Try to keep up!", "Watch and learn."],
		"overtake": ["See ya!", "Too slow!", "Coming through!"],
		"lead": ["Too easy!", "Mine now."],
		"hit": ["Hey! Not cool!", "You'll pay for that!"],
		"crash": ["That wall moved!", "Ugh, my paint!"],
		"win": ["Blaze always wins!"]}},
	{"name": "CAPTAIN CRASH", "tag": "CAPTAIN", "lines": {
		"start": ["Full speed ahead!", "Brakes are for cowards!"],
		"overtake": ["Outta my way!", "Yarrr!"],
		"lead": ["The sea is mine!", "Ha HA!"],
		"hit": ["Arr, that stings!", "Mutiny!"],
		"crash": ["Worth it!", "Again! Again!"],
		"win": ["Victory, me hearties!"]}},
	{"name": "GRANNY SPEED", "tag": "GRANNY", "lines": {
		"start": ["Buckle up, dears!", "Mind the old lady!"],
		"overtake": ["Pardon me, dear!", "Excuse me, sweetie!"],
		"lead": ["Keep up, youngsters!", "Still got it!"],
		"hit": ["Oh my!", "How rude!"],
		"crash": ["My hip!", "Oh, fiddlesticks!"],
		"win": ["Cookies for everyone!"]}},
	{"name": "TURBO TINA", "tag": "TINA", "lines": {
		"start": ["Let's GO!", "Nitro is life!"],
		"overtake": ["Zoom!", "Bye bye!"],
		"lead": ["Front row seat!", "Woohoo!"],
		"hit": ["Seriously?!", "Rude!"],
		"crash": ["Oops!", "Too much turbo!"],
		"win": ["Turbo power!"]}},
	{"name": "PROFESSOR PIT", "tag": "PROF", "lines": {
		"start": ["I have calculated this.", "Optimal line engaged."],
		"overtake": ["As predicted.", "Simple physics."],
		"lead": ["Statistically inevitable.", "Q.E.D."],
		"hit": ["Unscientific!", "That was not in my model!"],
		"crash": ["A minor miscalculation.", "Recalibrating..."],
		"win": ["Science wins!"]}},
	{"name": "ROOKIE RAY", "tag": "ROOKIE", "lines": {
		"start": ["Is this the gas pedal?", "First race! Eek!"],
		"overtake": ["Did I just pass?!", "Sorry! Sorry!"],
		"lead": ["I'm WINNING?!", "Mom, look!"],
		"hit": ["Why me?!", "Ow ow ow!"],
		"crash": ["I'm okay!", "Whoopsie!"],
		"win": ["I actually won?!"]}},
	{"name": "DUCHESS", "tag": "DUCHESS", "lines": {
		"start": ["Make way for royalty.", "How quaint."],
		"overtake": ["Step aside, peasant.", "Toodle-oo!"],
		"lead": ["As it should be.", "Naturally."],
		"hit": ["How dare you!", "Off with your head!"],
		"crash": ["This is beneath me.", "Unacceptable!"],
		"win": ["Bow to your duchess!"]}},
	{"name": "ZIPPY", "tag": "ZIPPY", "lines": {
		"start": ["Zoom zoom!", "Beep beep!"],
		"overtake": ["Zip zip!", "Wheee!"],
		"lead": ["Zippy on top!", "Nyoom!"],
		"hit": ["Bonk!", "Aww!"],
		"crash": ["Boing!", "Spinny!"],
		"win": ["Zippy zoom champion!"]}},
]


## Picks `count` different drivers at random.
static func pick(count: int) -> Array:
	var pool := ROSTER.duplicate()
	pool.shuffle()
	return pool.slice(0, count)


const GENERIC := {
	"splash": ["I can't swim!", "Glub glub...", "Who put water here?!", "Brrr, cold!"],
	"jump": ["Wheee!", "Look, I'm flying!", "Big air!"],
}


static func line(driver: Dictionary, moment: String) -> String:
	var options: Array = driver.lines.get(moment, GENERIC.get(moment, []))
	return options[randi() % options.size()] if not options.is_empty() else ""
