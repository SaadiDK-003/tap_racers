extends RefCounted
## Data describing one circuit. Points are joined into a smooth closed loop and the
## whole track is scaled automatically to fit the screen between the button strips,
## so any coordinate range works (a tall, portrait-ish shape fits best). The first
## point is the start/finish line, so put it in the middle of a straight. Keep
## separate parts of the road at least ~160 units apart so they never touch.

var title := "Track"
var points := PackedVector2Array()
var road_width := 108.0

var ground := Color(0.075, 0.105, 0.145)
var blob := Color(0.06, 0.085, 0.12)
var road := Color(0.24, 0.26, 0.31)
var lane := Color(0.42, 0.5, 0.49)
var curb_a := Color(0.96, 0.96, 0.96)
var curb_b := Color(0.9, 0.12, 0.15)

var blob_count := 12
var blob_seed := 1

## Figure-8 tracks: where the loop crosses itself, and which pass (0 or 1) is the
## bridge going over the other one. Leave bridge_point at INF for normal tracks.
var bridge_point := Vector2.INF
var bridge_pass := 1
var bridge_half := 190.0 # bridge length either side of the crossing

## Scenery theme: "city", "forest", "desert", "snow" or "beach" (see scripts/scenery.gd).
var scenery := "forest"
var scenery_density := 1.0
