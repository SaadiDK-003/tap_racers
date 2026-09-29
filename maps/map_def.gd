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

## Jump over water: the middle of the water gap (on a straight). INF = no jump.
var jump_point := Vector2.INF
## "river" (splash into water) or "ravine" (a rocky chasm taken off a hill crest).
var jump_kind := "river"
var jump_gap := 120.0 # length of the gap
var jump_ramp := 40.0 # length of the take-off and landing ramps
var jump_min_speed := 470.0 # speed needed at the lip to clear the gap

## Shortcut: a narrow gravel road that leaves the main road near `shortcut_from`,
## runs through `shortcut` (points in between) and rejoins near `shortcut_to`. Cars
## that reach the fork slowly turn in. Empty = no shortcut.
var shortcut := PackedVector2Array()
var shortcut_from := Vector2.INF
var shortcut_to := Vector2.INF

## Railway level crossing (on a straight): trains cross the road now and then.
## The rails run off the map on one side and into a tunnel on the other. INF = none.
var rail_point := Vector2.INF

## Scenery theme: "city", "forest", "desert", "snow" or "beach" (see scripts/scenery.gd).
var scenery := "forest"
var scenery_density := 1.0
## Optional colours for the scenery props (empty = the theme's own palette).
var scenery_palette: Array[Color] = []
