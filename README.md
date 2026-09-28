# Tap Racers

Local multiplayer (2–4 players) one-button slot-car racing for mobile and desktop, built with Godot 4.7.

## Modes
- **Players and CPU rivals:** 1–4 human players, with CPU rivals filling the grid up to 4 cars. A single player always gets at least one CPU. CPU level is Easy, Normal or Hard.
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

- **Garage:** each player picks a body (Classic, Kart 150, Formula 250, Muscle 350) and a decal (Plain, Stripes 60, Number 80, Checker 100, Flames 150, Lightning 200). CPUs get random looks.
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
  - **Random** is mostly clear, with rain or night about 20% of the time each.

## Phones
- **Pads:** on phones they're plain coloured buttons (no key letters), thumb-sized, set in from the screen edges clear of Android's edge-gesture zones, and give a small vibration on every press. With a keyboard they're 30% smaller and show each player's key, so the track gets more of the screen. `--touch` previews the phone layout on desktop.
- **Performance:** the static parts of each track (ground, road, curbs, scenery, bridge deck) and each car's look are drawn once into images. That cut the work per frame by about 85%. `--perf` prints live render stats.

## Tutorial, time trial and awards
- **HOW TO PLAY:** a guided race on Forest Ring. A coach card reacts to what you do: hold to drive, let go before corners, fill and fire nitro, grab boxes. First launch offers it once, and completing it pays +50 coins.
- **Time trial:** RACES → TRIAL. P1 races alone against the clock and a see-through **ghost** of their best lap on that track.
  - Each lap shows how far ahead of or behind the ghost you are.
  - Beating it saves a new ghost.
  - You get **RETRY THIS TRACK** or **NEW TRACK** afterwards.
- **Awards** (menu button): 16 achievements, for example *Spotless*, *Comeback Kid*, *Rocketeer* (hit 3 cars with rockets) and *World Tour*. Each pays coins once, and new ones show on the results screen.

## Race moments
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
Nine tracks are in the random rotation, each with its own scenery theme:
- Sunset Speedway (night city)
- Canyon Hairpins (desert)
- Forest Ring (forest)
- Frosty Peaks (snow)
- Palm Beach (beach)
- **Crossover Bridge**: a figure-8 where one pass goes over the other on a bridge. For your own figure-8, set `bridge_point` to where the loop crosses itself.
- **Volcano Rush**: a heart-shaped track with lava pools, smoking vents and glowing cracks. It's the hardest track.
- **Neon Nights**: a dog-bone track through a dark city with glowing neon signs.
- **Autumn Valley**: a flowing forest track in autumn colours.

Scenery (`scripts/scenery.gd`) is generated automatically in the empty ground around and inside each track, along with tyre walls outside the corners, a grandstand at the start line and spectator parking lots.

## Adding a map
1. Copy `maps/sunset_speedway.gd` and change `title`, `points` and the colours. The track is scaled automatically to fit between the button strips, so use any coordinates (a tall shape fits best). The first point is the start line (put it on a straight). Keep separate parts of the road at least ~160 units apart so they never touch.
2. Set `m.scenery` to `"city"`, `"forest"`, `"desert"`, `"snow"`, `"beach"`, `"volcano"` or `"neon"`. `m.scenery_palette` can recolour the props; Autumn Valley uses it for autumn trees.
3. Check the layout with `godot --headless --path . --script res://tools/check_tracks.gd`. It flags corners that are too tight and parts of the road that come too close together.
4. Add it to `MAPS` in `scripts/game.gd` (and to the list in `tools/check_tracks.gd`). It then joins the random rotation.

## Debug flags
Pass these after `--`:
```
godot --path . -- --race --players=4 --map=1 --laps=2 --bots
```
- `--players=1 --cpus=3 --cpu_level=2 --races=3` sets up a race against CPUs. `--log` prints lap times, and `--podium` jumps to a sample Cup podium.
- `--weather=rain` (or `clear` / `night` / `random`) and `--items=off` set the weather and turn power-ups off.
- `--scene=garage` (or `records`) opens that screen directly, and `--coins=500` sets the coin balance for testing.
- `--tutorial` starts the tutorial, `--races=0` starts a time trial, and `--autopilot` lets the bot drive P1 while still saving results.
- `--bots` makes the computer drive every car well. `--bots=reckless` never brakes (to test crashes).
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
