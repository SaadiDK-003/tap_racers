# Tap Racers

Local multiplayer (2–4 players) one-button slot-car racing for mobile and desktop, built with Godot 4.7.

## Menu
- **Home:** a big **PLAY** button with a one-line summary of your race settings, **RACE SETUP**, **CAREER** (with your star count), Garage, Records, Awards, How to Play, and the daily challenge. The gear in the top corner opens Settings.
- **Race setup:** players, CPU rivals and level, races, laps, items and weather, plus who's on the grid (with the CPU drivers' names).
- **Settings:** sound, music, replays, vibration (phones and tablets) and fullscreen (desktop only).

## Modes
- **Players and CPU rivals:** 1–4 human players, with CPU rivals filling the grid up to 4 cars. A single player always gets at least one CPU. CPU level is Easy, Normal or Hard.
- **Career:** 10 solo events on set tracks against named CPU rivals, from Rookie Run (Easy) to Blaze's Final (Hard, 6 laps). Each event has fixed laps, weather and items, and pays up to 3 stars: a podium finish (which unlocks the next event), a win, and the event's goal (e.g. no crashes, 3 nitros, 3 close calls, an item hit, a perfect lap, or winning by 2 seconds). Every new star pays 25 coins. Your own race settings come back when you leave career.
- **Win streak king:** a human who wins 2 races in a row becomes KING, with a crown and win count on their pad, and the start banner names them. Each further win pays the king 15 coins, and another human who beats the king gets 40. A CPU win ends the streak. It carries over REMATCH, NEW TRACK and Cup races, and resets on the main menu.
- **Replay:** after the finish, the race's best moment plays back in slow motion before the results, zoomed in on the action: a train or rocket hit, a mine, a double lightning strike, a splash, big air or a last-lap lead change. Tap to skip, or turn REPLAYS off in Settings.
- **Rematch:** after a single race, REMATCH replays the same track, and NEW TRACK picks a random one.
- **Races:** *Single* race, or a *Cup* of 3 or 5 races on random tracks with no repeats. Points are 10 / 6 / 3 / 1, and standings show after each race. The Cup ends on a podium with a trophy.
- **CPU drivers:** each race picks CPU rivals from 8 personalities: Blaze, Captain Crash, Granny Speed, Turbo Tina, Professor Pit, Rookie Ray, Duchess and Zippy. Their name shows on their pad and in the results, and now and then they say something in a speech bubble when they start, overtake, take the lead, get hit, crash or win.
- **Items from lap 2:** the "?" boxes only appear once the leader starts lap 2, so lap 1 is a clean race.
- **Catch-up help:** cars further back fill their nitro faster (up to about 2x for last place, more if far behind), so races stay close.

## Progress (saved on the device)
- **Coins** (human players only):

  | Earned for | Coins |
  |---|---|
  | 1st / 2nd / 3rd / 4th place | 30 / 20 / 12 / 6 |
  | Each PERFECT LAP | +5 |
  | Each CLOSE CALL | +2 |
  | Winning a Cup | +100 |
  | Daily challenge | +100 |

- **Garage:** tabs for BODY, DECAL and TRAIL, picked separately for each player. Every body has its own engine sound, and tapping one revs it:
  - **Bodies:** Classic, Kart 150, Formula 250, Buggy 300, Muscle 350, Hover 450.
  - **Decals:** Plain, Stripes 60, Number 80, Polka 90, Checker 100, Stars 120, Zigzag 130, Flames 150, Lightning 200.
  - **Speed trails:** Classic, Fire 120, Ice 120, Neon 160, Gold 200, Rainbow 300.

  CPUs get random looks.
- **Records:** best lap on every track (humans only, with who set it), plus races, wins and crashes per player and all-time totals.
- **Daily challenge:** a new goal every day, shown in the menu, for example "Win a race on Frosty Peaks" or "Fire nitro 3 times in one race". It's the same for everyone on the same date.
- **Saved settings:** menu choices, sound and music are remembered too. Everything lives in `user://profile.json`.

## Items and weather
- **Power-up boxes (ITEMS ON/OFF):** two rows of "?" boxes, one box per lane, sit around the track. Items are an occasional surprise, not constant chaos: after you take a box, yours comes back only after 14 s, so it's about one item every other lap. Items fire automatically, so the game stays one-button:
  - **SHIELD:** a bubble that blocks your next crash or rocket. It lasts 10 s and blinks before it runs out.
  - **ROCKET:** homes in on the car ahead of you (or 2nd place, if you're leading) and blows it off the track, even mid-nitro. A shield blocks it. The target gets a "ROCKET INCOMING!" warning.
  - **MEGA NITRO:** fills your tank, and the next burst lasts longer.
  - **LIGHTNING:** strikes every car ahead of you, shrinking and slowing them for 2 s. It's a rare comeback item and never given to the leader.
  - **MINES:** drops a mine in every other lane behind you. The next car in each lane is blown off the track.

  Shields block rockets, mines and lightning.

  Cars at the back mostly get rockets, lightning and nitro; the leader mostly gets shields and mines. When you hit a box, a roulette icon spins over your car for a moment before it lands on your item.
- **Winner moment:** a spotlight follows the winner while fireworks burst around their car in their colour.
- **WEATHER (RANDOM / CLEAR / RAIN / NIGHT):**
  - **Rain** means less grip in corners, rain streaks, spray behind cars and rain sound.
  - **Night** means a dark track, headlight beams and glowing street lamps.
  - **Random** is mostly clear, with rain or night about 20% of the time each. About 3 in 10 clear races (of 3+ laps) get a **shower** partway through: lightning, thunder and RAIN INCOMING!, then the rain and slippery corners build up over 5 seconds. Winning once it's raining counts as a rain win.

## Phones
- **Pads:** on phones they're plain coloured buttons (no key letters), thumb-sized, set in from the screen edges clear of Android's edge-gesture zones, and give a small vibration on every press. With a keyboard they're 30% smaller and show each player's key, so the track gets more of the screen. `--touch` previews the phone layout on desktop.
- **Safe areas:** on phones, every screen keeps buttons and text clear of the notch or camera hole, rounded corners and the gesture bar. Backgrounds, the track and overlays still fill the whole screen. `--safe=left,top,right,bottom` fakes cutouts on desktop for testing.
- **Performance:** the static parts of each track (ground, road, curbs, scenery, bridge deck) and each car's look are drawn once into images. That cut the work per frame by about 85%. `--perf` prints live render stats.

## Tutorial, time trial and awards
- **HOW TO PLAY:** a guided race on Forest Ring. A coach card reacts to what you do: hold to drive, let go before corners, fill and fire nitro, grab boxes. First launch offers it once, and completing it pays +50 coins.
- **Time trial:** RACES → TRIAL. P1 races alone against the clock and a see-through **ghost** of their best lap on that track.
  - Each lap shows how far ahead of or behind the ghost you are.
  - Beating it saves a new ghost.
  - You get **RETRY THIS TRACK** or **NEW TRACK** afterwards.
- **Awards** (menu button): 16 achievements, for example *Spotless*, *Comeback Kid*, *Rocketeer* (hit 3 cars with rockets) and *World Tour*. Each pays coins once, and new ones show on the results screen.

## Race moments
- **Intro sweep:** before the start lights, the camera glides zoomed-in along the track to the grid and zooms out. It takes about 2.4 s; tap or press any player key to skip. `--intro=off` turns it off.
- **Pop-ups by each player's corner:** OVERTAKE!, TOOK THE LEAD!, FASTEST LAP!, and NITRO READY!.
- **CLOSE CALL!:** slide right to the edge of a crash and save it to earn bonus nitro.
- **PERFECT LAP!:** a lap with no crash and no slides earns bonus nitro. This one is for humans only.
- **Photo finish:** if the runner-up is less than about a third of a second behind the winner, the game switches to slow motion with a camera flash and "PHOTO FINISH!", then shows the winning margin.
- **Music and crowd:** three race themes (each track uses one) and a calm menu tune. On the final lap the music speeds up and the crowd roars. The crowd also cheers lead changes and "ooohs" at big knockouts. The crowd cheers at the start, as cars cross the line, and at the finish. SOUND and MUSIC can each be toggled in the menu.

## How to play
- **Hold** your button to accelerate and **let go** to brake.
- Corners have a speed limit with a 15% free margin. Go well over it and the car slides (smoke and a blinking **!**), then flies off. It comes back after about 1 s.
- **NITRO:** driving fast fills your nitro tank (the inner blue ring on your button). You start with half a tank, and it fills about once a lap. When it's full the button says **TAP TAP!**. **Double-tap** to fire a 1.8 s burst of speed during which your car can't crash. Crashing empties the tank.
- Each corner shows your **LAP x/5**, a lap progress bar, your race position and a speed ring around your button.
- A race is 5 or 6 laps (chosen in the menu). After the winner crosses the line, everyone else has 15 s to finish.
- **Play Again** loads a random track, never the same one twice in a row.

| Player | Corner (phone) | Desktop key |
|---|---|---|
| P1 Red | bottom-right | `L` |
| P2 Blue | top-left | `A` |
| P3 Yellow | bottom-left | `V` |
| P4 Green | top-right | `Up arrow` |

- **Keys** are matched by physical position, so they work on any keyboard layout. None of them is Shift, Ctrl or Alt, so the OS never shows Sticky Keys or other hotkey pop-ups. Menu buttons never take keyboard focus, so a player's key can't press a button by accident.
- **Mobile** supports multi-touch. Every finger is tracked on its own, and a touch anywhere counts for the nearest player's corner. On phones, the top players' text is shown upside-down so it faces them across the table.
- **Pause:** the ✕ button, `Esc`, or Android Back.
- **Screen orientation:** wide windows (desktop, TV) use a landscape layout: the track turns sideways and the pads' lap pills run up and down the side columns. Tall screens (phones) use portrait. Resizing the window switches between the two live. **F11** or the menu's **FULLSCREEN** button toggles fullscreen on desktop.

## Project layout
- `scripts/game.gd`: autoload with settings, player colours and keys, and the **map registry**.
- `scripts/race.gd`: race flow (countdown → race → results) and the UI.
- `scripts/race_world.gd`: track, cars and effects scaled to fit the screen (also used for the menu's demo race).
- `scripts/effects.gd`: smoke, sparks, trails and skid marks. `scripts/sfx.gd`: sounds synthesized in code (no audio files).
- `scripts/track.gd`: builds a smooth loop from the map points, draws it, and handles the geometry.
- `scripts/car.gd`: slot-car physics: throttle, grip, slip and crashes.
- `scripts/player_pads.gd`: corner buttons, lap pills, the pause button, and touch/mouse input.
- `maps/*.gd`: one file per track.

## Maps
Thirteen tracks are in the random rotation, each with its own scenery theme:
- Sunset Speedway (night city)
- Canyon Hairpins (desert)
- Forest Ring (forest)
- Frosty Peaks (snow)
- Palm Beach (beach)
- **Crossover Bridge**: a figure-8 where one pass goes over the other on a bridge. For your own figure-8, set `bridge_point` to where the loop crosses itself.
- **Volcano Rush**: a heart-shaped track with lava pools, smoking vents and glowing cracks. It's the hardest track.
- **Neon Nights**: a dog-bone track through a dark city with glowing neon signs.
- **Autumn Valley**: a flowing forest track in autumn colours.
- **Orbit Station**: a rounded triangle in space, with station modules, satellites, planets and stars.
- **Farmland Twist**: countryside S-bends past crop fields, barns, hay bales and cows. It's one of the harder tracks.
- **Harbor Docks**: an L-shaped circuit around a port, with container yards, boats, cranes and dock lamps.
- **Splash Canyon**: a desert canyon with a **jump over a river**. Hit the ramp at speed (at least about two-thirds of top speed) to fly across. Too slow and it's a SPLASH, and you come back on the far bank. Nitro gives BIG AIR.

- **Quarry Cut**: a hairpin at the top with a narrow **gravel shortcut** right beside it, cutting the turn short. Slow down at the SHORTCUT sign (let go before the fork) to turn in; keep your finger down to stay on the hairpin. The shortcut is shorter but loose, and a nitro burst won't have run out by the fork, so each lap it's nitro or shortcut (about even). Its item boxes and mines are on the main road, and rockets don't follow you onto it.
- **Summit Leap**: an alpine track with a **ravine jump** at the top of the long straight, taken off a hill crest. It's a bigger gap than Splash Canyon's river: keep your foot down up the hill (about 88% of top speed) or you FALL IN and come back on the far side. With nitro it's huge BIG AIR.
- **Rail Crossing**: countryside with a **railway level crossing** on the long straight. Every 7–12 s the lights flash, a bell rings and the barriers drop; 2 s later a train sweeps across into a tunnel. Wait at the barrier, or risk it: the train knocks you off (a shield saves you). Players heading for it get a "TRAIN!" warning. CPUs stop for it and hold their nitro; Easy ones sometimes chance it.

For your own jump track, set `m.jump_point` to the middle of the gap on a long straight, and optionally `m.jump_kind = "ravine"`, `m.jump_gap`, `m.jump_ramp` and `m.jump_min_speed` (the river is 120 / 40 / 470). The river is drawn automatically and stops before it reaches any other part of the road. For a shortcut, set `m.shortcut_from` and `m.shortcut_to` (points on the main road) and `m.shortcut` (the points in between). For a level crossing, set `m.rail_point` on a straight: the rails run off the map on one side and end in a tunnel wherever another part of the road would be in the way.

Scenery (`scripts/scenery.gd`) is generated automatically in the empty ground around and inside each track, along with tyre walls outside the corners, a grandstand at the start line and spectator parking lots.

## Adding a map
1. Copy `maps/sunset_speedway.gd` and change `title`, `points` and the colours. The track is scaled automatically to fit between the button strips, so use any coordinates (a tall shape fits best). The first point is the start line (put it on a straight). Keep separate parts of the road at least ~160 units apart so they never touch.
2. Set `m.scenery` to `"city"`, `"forest"`, `"desert"`, `"snow"`, `"beach"`, `"volcano"`, `"neon"`, `"space"`, `"farm"` or `"harbor"`. `m.scenery_palette` can recolour the props; Autumn Valley uses it for autumn trees.
3. Check the layout with `godot --headless --path . --script res://tools/check_tracks.gd`. It flags corners that are too tight and parts of the road that come too close together.
4. Add it to `MAPS` in `scripts/game.gd` (and to the list in `tools/check_tracks.gd`). It then joins the random rotation.

## Debug flags
Pass these after `--`:
```
godot --path . -- --race --players=4 --map=1 --laps=2 --bots
```
- `--players=1 --cpus=3 --cpu_level=2 --races=3` sets up a race against CPUs. `--log` prints lap times, and `--podium` jumps to a sample Cup podium.
- `--weather=rain` (or `clear` / `night` / `random`) and `--items=off` set the weather and turn power-ups off. `--shower` (or `--shower=3`) makes rain roll in on lap 2 (or 3); `--shot_on=shower --shot_time=2` screenshots 2 s after it starts (`--shot_on=train` does the same when a train appears, `--shot_on=replay` during the replay). `tools/check_replay.gd` checks a replay starts, skips and hands back to the results.
- `--menu_panel=setup` (or `settings`) opens that menu panel directly.
- `--scene=garage` (or `records`; `--garage_tab=2` opens the trail tab) opens that screen directly, and `--coins=500` sets the coin balance for testing.
- `--streak=2,3` makes P2 the king with 3 wins in a row.
- `--shortcut=always` (or `never`) makes computer drivers always (or never) take a shortcut, and `--nitro=off` turns nitro off (for comparing lap times).
- `--race --career=3` races career event 4 (numbered from 0).
- `--tutorial` starts the tutorial, `--races=0` starts a time trial, and `--autopilot` lets the bot drive P1 while still saving results.
- `--bots` makes the computer drive every car well. `--bots=coast` makes them let go before a jump, to test splashes. `--bots=reckless` never brakes (to test crashes).
- `--perf` prints fps, the worst frame, draw calls and script time every second, and logs each hitch (a frame over 25 ms).
- `--shot=out.png --shot_time=2` saves a screenshot and quits.

## Exporting
Presets for **Web**, **Windows**, **Linux** and **Android** are in `export_presets.cfg`. Builds go to `export/`:
```
godot --headless --path . --export-release "Web"
godot --headless --path . --export-release "Windows"
godot --headless --path . --export-release "Linux"
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/.android/debug.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android godot --headless --path . --export-release "Android" export/android/TapRacers.apk
```
- **Windows:** the `.exe` gets the logo icon (`assets/icon.ico`) and "Tap Racers" version info through [rcedit](https://github.com/electron/rcedit), run with Wine on Linux. Point Godot at both in the editor settings: `export/windows/rcedit` and `export/windows/wine`. Without them the build still works, but shows Godot's default icon.
- **Web:** serve `export/web/` with any static server, for example `python3 -m http.server`, then open `index.html`. It's built without threads, so no special server headers are needed.
- **Android:** use the **release** export for testing on phones, because debug builds run much slower. It's signed with the local debug key, which is fine for installing on your own phones. The Play Store needs your own release keystore instead. Install with `adb install -r export/android/TapRacers.apk`, or copy the file to the phone.
# tap_racers
