# [big world, little bunny](https://tixeriz.itch.io/bigworldlittlebunny)

*You are 16 pixels tall. Everything else is enormous.*

Survive **60 seconds** of raining giants. Hand-drawn shapes start slow and accelerate on the way down, and after 9 seconds triangle spikes begin rising out of the ground — jump those. The bar at the top is your progress.

Made for the [jame gam game jam](https://itch.io/jam/jame-gam-game-jam) — theme *"i'm just a little guy"*, with the jame gam palette twist: every gameplay and UI color comes straight from the jam palette.
## [TO PLAY CLICK HERE](https://tixeriz.itch.io/bigworldlittlebunny)

## Controls

| Action | Keys |
|---|---|
| Move | Arrow keys or **A / D** |
| Jump | **SPACE / W / Up** (release early for a shorter hop) |
| Start / restart | **ENTER** |

## Features

- Ground acceleration physics: ramp-up to top speed, snappier stopping, variable-height jumps
- Falling shapes accelerate the whole way down — slow to read, fast to punish
- Difficulty ramps across the 60-second run (faster spawns, faster falls, more spikes)
- Parallax wireframe background that leans with your movement
- Music starts when a run starts, stops at the end screen, restarts on retry
- All art is hand-drawn, cropped shape-by-shape from one sketch sheet, and tinted to the jam palette
- Fully code-driven scene: drop new PNGs into `art/` and they appear automatically
  
## Run it on godot

1. Download **Godot 4.x Standard** (not .NET) from [godotengine.org](https://godotengine.org/download)
2. Godot → **Import** → select `project.godot`
3. Press **F5** to play

## Build for the web

1. One-time: **Editor → Manage Export Templates → Download and Install**
2. `export_presets.cfg` is included — **Project → Export → "Web" → Export Project** to `export/web/index.html`
3. Zip that folder and upload it to itch.io (check *"This file will be played in the browser"*)

## Project layout

| Path | What it is |
|---|---|
| `scripts/main.gd` | Game loop, spawning, timer, screens, parallax, audio |
| `scripts/player.gd` | The little bunny (accel/jump physics + hitbox) |
| `scripts/shape.gd` | Falling giants (they accelerate) |
| `scripts/spike.gd` | Ground spikes: rise, linger, sink (pixel-perfect ground contact) |
| `scripts/art.gd` | Loads art/audio from disk, draws placeholders if missing |
| `scenes/Main.tscn` | Single scene — the whole tree is built in code |
| `art/` | Hand-drawn player, shapes (256×256), background |
| `audio/` | `bgm.mp3` |
| `fonts/` | Messy Handwritten |
| `jamegam-palette.gpl` | The 16 jam colors |
| `itch_description.md` | itch.io page copy |

## Tuning

Knobs live at the top of `scripts/main.gd` (`GAME_TIME`, spawn rates, speed ranges, spike timing) and `scripts/player.gd` (`SPEED`, `ACCEL`, `DECEL`, `GRAVITY`, `JUMP_VELOCITY`).

Smoke test: `godot --headless --path . -- --smoke` — asserts jump-vs-spike clearance, screen clamps, spawn bounds, spike lifecycle and asset loading, exits 0 on success.

## Credits

- **Music:** *Enter Hallownest* by Christopher Larkin (from the Hollow Knight soundtrack)
- **Font:** *Messy Handwritten*
- **Art:** hand-drawn, cropped and tinted to the jame gam palette
- **Engine:** [Godot 4.7](https://godotengine.org)
