# Jeffrey Brings Death 2.0

You are Jeffrey, a peasant demon creeping up the back of a walking Colossus
toward the glowing tree on its shoulder. You are weak, and you stay weak.

This is the **first playable greybox slice**, built in **Godot 4.3**
(GDScript, no plugins). Everything is placeholder primitives with a
low-res, Thief 2-ish look: the game renders at 640×360 and is scaled up
with nearest-neighbour filtering.

![Start of the slice, by day](docs/screenshots/01_start_day.png)
![The first cliff at dusk](docs/screenshots/02_dusk_cliff.png)

## Running it

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, **Import**, and pick this folder's `project.godot`.
3. Press **F5**.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| Mouse | Look |
| Shift | Sprint (uses stamina, loud) |
| Ctrl or C | Crouch (slow, quiet, darker) |
| Space | Jump. Jump at a ledge to mantle onto it |
| Left mouse | Sword (pitiful) |
| Right mouse | Shield (soaks most of a hit, costs stamina) |
| Q or middle mouse | Grappling hook. Only bites **brown wood**. Press again or jump to let go |
| F or E | Rest at a campfire |
| 1 / 2 | In the rest menu: rest until morning / evening |
| H | Hide the controls overlay |
| T | Debug: skip one hour |
| Esc | Free the mouse (click to recapture) |

## What's in the slice

- **The Colossus's back**, three plateaus climbing to the tree:
  the *Haunch* (start), the *Ribs* (+12 m), and the *Shoulder* (+32 m),
  with the neck and head beyond as a dead end with a view. Fall off and you die.
- **Several ways up each cliff.** First cliff: a guarded ramp on the left,
  wooden beams to grapple on the lip, or a precarious staircase of scale ridges
  on the right. Second cliff: a long guarded ramp or a two-stage grapple chain.
- **The tree** glows through fog from everywhere. Reach its roots to end the slice.
- **Day/night cycle** (10 real minutes per day). By day you're easy to spot.
  At night you're hard to see, but **Hollows** come out: faster, sharper-eyed
  and deadlier than the Wardens.
- **Light gem** at the bottom of the HUD, as in Thief: bright means seen.
  Crouching, standing still, shadow under overhangs and night all darken it.
  Campfires light you up.
- **Wardens** patrol day and night. They notice you gradually (`?`), then hunt (`!`),
  lose you if you break line of sight, search, and give up. Three hits kill you.
  Your sword does 9 damage to their 260 HP (×4 on an unaware back). Don't.
- **Campfires** are checkpoints. Walking up to one sets your respawn point.
  Resting heals you, skips to morning or evening, and resets every enemy,
  Elden Ring style. Three fires: *Tailbone Fire*, *Rib Hollow*, *Shoulder Watch*.
- The Colossus occasionally takes a step and the world shudders.

## Project layout

```
project.godot        engine settings (low-res stretch, Game autoload)
scenes/main.tscn     the only scene; everything is built in code
scripts/
  game.gd            autoload: clock, daylight, checkpoint
  main.gd            input map, wiring, resting, dying
  world.gd           level layout: greybox, fires, enemies, tree  <- edit the level here
  player.gd          Jeffrey: movement, crouch, mantle, sword, shield, grapple, light gem
  enemy.gd           Warden / Hollow stats and stealth AI
  campfire.gd        checkpoint fire
  day_night.gd       sun, moon, sky, fog
  hud.gd             bars, light gem, clock, prompts, rest menu
tests/
  smoke_test.tscn    headless playtest of the core mechanics
  screenshots.tscn   renders the images in docs/screenshots
```

Tuning lives in constants at the top of each script (`player.gd` speeds and
damage, `enemy.gd` `KINDS`, `game.gd` day length).

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

Prints `PASS`/`FAIL` for 19 checks (grapple routes, ramp, day/night visibility,
Hollows only at night, a Warden spotting and killing Jeffrey, respawn,
blocking, resting, reaching the tree) and exits non-zero on failure.

## Not in this slice yet

Sound, real art, enemy navmesh pathing (enemies walk straight at you and stop
at edges), throwables/distractions, the Thief-style levels (Prison, Sunken City,
the party, the mansion around the tree), and saving.
