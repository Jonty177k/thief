# First-person controller

Jeffrey's controller, built to the *First-Person Controller Specification*
(Godot 4.x implementation brief). The goal is Thief II: grounded, a little
weighty, smooth acceleration, quick strafing, controlled jumps. It is not a
fast FPS controller.

The values in the spec are starting estimates, not measured Thief II values.
Every one of them is in the Inspector, so tune by feel.

![The test area's combat yard](screenshots/controller_01_yard.png)

## Playing the test area

Press **F5**. The game starts in the controller test area
(`levels/controller_test.tscn`), with the debug readout on the right.

| Station | Where | What it tests |
| --- | --- | --- |
| Pillars | straight ahead | Circle them, strafe, stop hard, walk diagonally |
| Campfire and a pickup | either side of the start | Interact (rest menu, pick up) |
| Combat yard | past the pillars | Straw dummy (light/heavy damage, chaining) and the attack dummy (shield) |
| Narrow corridor, crouch passage, dash lane, ladder wall | east (right) | 1 m corridor, 1.3 m ceiling, dashing into walls, a 5 m ladder |
| Stairs, steps, jump gaps, ledges, ramps | west (left) | Smooth stairs, real 25 cm steps, 1.5/2/2.5/3 m gaps at 2 m up, 40/80/120 cm ledges, a 21° ramp and a 53° slope you can't climb |
| Door, gate and lever | north | Open the door, find the gate locked, pull the lever outside |
| Opening-area pieces | far north | Grass tiles, a cliff with a ladder, rope/plank/stone bridges, a plateau, hills, spires and mountains |

The old greybox Colossus slice is still there: open `scenes/greybox_slice.tscn`
and press **F6**.

## Controls

The bindings live in **Project Settings → Input Map**, so they can be changed
there without code. `tools/write_input_map.gd` rewrites them to the defaults.
Controller bindings use *All Devices*, so any controller works without
picking a device number.

| Action | DualSense | Keyboard / mouse |
| --- | --- | --- |
| Move / strafe (analog) | Left stick | WASD |
| Look | Right stick | Mouse |
| Run (hold) | L2 | Shift |
| Block (hold) | L1 | Right mouse |
| Light attack | R1 | Left mouse |
| Heavy attack | R2 | F |
| Jump | Cross (X) | Space |
| Dash | Circle | Alt |
| Interact / open / pick up | Square | E |
| Crouch (toggle) | Triangle | Ctrl (or C) |
| Rest menu: morning / evening / get up | D-pad up / D-pad down / Circle | 1 / 2 / E |
| Debug readout | Options | F3 |
| Fullscreen / window | | F11 |
| Climb a ladder | walk into it, or Square | walk into it, or E |
| Controls overlay | Create | H |
| Grappling hook (greybox slice only) | R3 | G or middle mouse |

The game starts fullscreen. F11 switches to a window and back; the window
size is in *Project Settings → Display → Window*.

### PS5 controller

Plug it in by USB or pair it over Bluetooth, before or during play; a
message says when it connects. Godot reads a DualSense through its built-in
SDL controller database, which uses Xbox names: Cross is "A", Circle "B",
Square "X", Triangle "Y", and L2/R2 are analog trigger axes. The Input Map
is bound to those, so it works the same on Windows, macOS and Linux.

If Godot ever doesn't recognise a Sony controller (a new model ID or a
clone), `scripts/gamepad.gd` adds the DualSense's raw button layout for it,
so Cross still jumps and L2 still runs. The debug readout's last line (F3 or
Options) names the controller and says *mapped* when Godot knows its layout.

If Steam is running with Steam Input on for PlayStation controllers, it
presents the pad as an Xbox controller; that works too, with the same
buttons. Tools like DS4Windows do the same.

## How it's built

`scenes/player.tscn` is a reusable player. The root is a `CharacterBody3D`
(`scripts/player/player.gd`) and each job is its own child node:

```
Jeffrey (player.gd)           health, damage, action state, the can_* rules
├── Collision                 capsule (the body)
├── Leg                       downward ray under the capsule: rides up steps
├── GroundRay                 reads the ground below (slope, ledges, debug)
├── Head (player_camera.gd)   look, pitch limits, camera feel        ← tune
│   └── Camera3D
│       ├── Viewmodel         placeholder sword and shield
│       └── InteractRay       2.2 m interaction ray
├── Input (player_input.gd)   reads the Input Map once per tick      ← tune
├── Movement                  walk, run, crouch, jump, slopes, steps, ladders ← tune
├── Dash                      directional dash                        ← tune
├── Sword                     light and heavy attacks                 ← tune
├── Shield                    block arc                               ← tune
├── Interaction               finds and uses Interactables            ← tune
└── Stealth                   light gem and noise, for enemies
```

Each tick the root runs them in a fixed order:
Input → Dash → Sword → Shield → Interaction → Movement → Stealth. All
movement goes through `move_and_slide()` (or `move_and_collide()`); nothing
sets the position directly, except respawning.

### States and priority

`Normal, Crouching, Airborne, Dashing, Light Attack, Heavy Attack, Blocking,
Interacting, Climbing, Dead`. *Climbing* (on a ladder) is extra to the spec,
for the ladders. The rules for what may start live in one place, the `can_*`
functions in `player.gd`:

- No dash during a heavy attack (windup, swing or recovery). A light attack's
  recovery *can* be cut short by a dash (*Cancels Light Recovery*).
- No dash in the air (*Allow In Air*), on a ladder, or while using something.
- No attacks with the shield up, mid-dash, on a ladder or while using something.
- The shield can't be raised during a swing or a dash; it rises when the swing ends if L1 is still held.
- No jumping mid-dash or during a heavy attack.
- No interacting during attacks, dashes or with the shield up.
- Look always works while alive, including mid-attack and mid-dash. The
  camera is never turned for you.

### Damage interface

`scripts/combat/damage_info.gd` (`DamageInfo`) carries one blow: amount,
source, origin, the horizontal **direction** it travels, knockback, a kind,
and **blocked**, which the receiver fills in. Anything with a
`receive_damage(info: DamageInfo)` method can be hurt: Jeffrey, the dummies
and the Wardens all use it. `DamageInfo.deliver(collider, info)` finds the
receiver above a collider.

### Interactable interface

`scripts/combat/interactable.gd` (`Interactable`) is a node you add under
anything usable. It has a *Prompt* and *Enabled*, and an `interacted(by)`
signal. The player looks for one on (or under) whatever the interaction ray
hits; nothing about doors or levers lives in the player. The door, lever,
pickup and campfire all use it.

## Tuning reference

Open `scenes/player.tscn` and select the node. Hover any value in the
Inspector for its description.

### Movement

| Group | Setting | Default | Notes |
| --- | --- | --- | --- |
| Speeds | Walk Speed | 3.2 m/s | Full stick or a key. Half stick is about 1.3 m/s |
| | Run Speed | 5.4 m/s | While Run is held |
| | Crouch Speed | 1.6 m/s | |
| Acceleration | Ground Acceleration | 14 m/s² | Speeding up |
| | Ground Deceleration | 18 m/s² | Slowing down or turning around |
| | Air Acceleration Ratio | 0.25 | Air steering, as a share of ground acceleration |
| Jump and Gravity | Gravity | 19.6 m/s² | |
| | Jump Velocity | 6.0 m/s | About a 0.9 m jump |
| | Coyote Time | 0.10 s | Jump still works just after walking off an edge |
| | Jump Buffer | 0.12 s | A press just before landing still jumps |
| | Max Fall Speed | 45 m/s | |
| Slopes and Steps | Max Slope Degrees | 46° | Steeper ground slides you off |
| | Steep Slide Speed | 5 m/s | |
| | Step Height | 0.35 m | Ledges this high are walked up |
| | Crouch Step Height | 0.2 m | |
| | Floor Snap | 0.4 m | Stays glued going down stairs and slopes |
| Body and Crouch | Standing Height | 1.8 m | |
| | Eye Height | 1.65 m | |
| | Crouch Height | 1.0 m | Eye drops by the same amount |
| | Capsule Radius | 0.35 m | |
| | Crouch Toggle | on | Off for hold-to-crouch |
| | Crouch Transition Speed | 5 m/s | |
| Ladders | Climb Speed | 2.2 m/s | |
| | Climb Strafe Speed | 1.0 m/s | |
| | Ladder Jump Off | 3.5 m/s | |
| Falling | Fall Damage Threshold | 13 m/s | About a 4.3 m drop |
| | Fall Damage Per Speed | 9 | |
| | Stride | 1.1 m | Distance between footsteps |

Crouching won't let you stand up under something; you stay crouched until
there is room. Air control is reduced but never bleeds off a running jump.

### Camera (the Head node)

| Group | Setting | Default |
| --- | --- | --- |
| Mouse | Mouse Sensitivity | 0.12°/pixel |
| | Invert Y | off |
| Gamepad Look | Stick Yaw Speed | 200°/s |
| | Stick Pitch Speed | 140°/s |
| | Stick Deadzone | 0.12 |
| | Stick Response Curve | 1.6 (1 is linear) |
| | Stick Smoothing | 14 |
| Limits | Pitch Min / Max | -85° / 85° |
| | FOV | 75° |
| Feel | Head Bob Enabled | on |
| | Bob Stride / Height / Sway | 2.2 m / 0.025 m / 0.012 m (walking) |
| | Run Bob Multiplier | 1.3 |
| | Crouch Bob Multiplier / Crouch Bob Stride | 1.6 / 1.4 m (shorter, heavier steps) |
| | Dash Lean Enabled | **off** |
| | Dash Lean Degrees | 3° |
| | Landing Dip Enabled | on |
| | Land Dip Threshold / Per Speed / Max | 3 m/s / 0.02 / 0.2 m |
| | Step Smoothing | 12 |

The left stick's deadzone is *Move Deadzone* (0.15) on the **Input** node.

### Dash

| Setting | Default | Notes |
| --- | --- | --- |
| Distance | 3.0 m | |
| Duration | 0.22 s | |
| Recovery | 0.25 s | Before the next dash |
| Falloff | 0.5 | 0 = constant speed, 1 = slows to a stop |
| Exit Speed | 3.2 m/s | Carried out, so it blends into walking |
| I Frame Time | 0 s | Invulnerability; off for now |
| Allow In Air | off | |
| Cancels Light Recovery | on | |

With the stick centred, the dash goes backward.

### Sword

| Setting | Light | Heavy |
| --- | --- | --- |
| Windup | 0.08 s | 0.42 s |
| Active | 0.12 s | 0.16 s |
| Recovery | 0.22 s | 0.55 s |
| Damage | 10 | 30 |
| Range | 2.0 m | 2.4 m |
| Knockback | 2 m/s | 7 m/s |
| Move Multiplier | 0.75 | 0.35 |

Light attacks chain (*Light Chaining*, up to *Light Chain Max* = 3 swings,
alternating direction). *Blade Radius* (0.18 m) is the thickness of the swept
blade, and *Input Buffer* (0.15 s) lets an early press count. While active,
the blade is swept as a shape cast from the eye through its arc, so it stops
at walls and hits each target at most once per swing.

### Shield

| Setting | Default | Notes |
| --- | --- | --- |
| Block Arc Degrees | 120° | Protected cone in front |
| Blocked Damage Multiplier | 0.15 | Damage that still gets through |
| Blocked Knockback Multiplier | 0.4 | |
| Move Multiplier | 0.55 | Speed with the shield up |

A block gives a metallic clank, a shield jolt, a small camera kick and a pale
screen flash. There is no parry yet.

### Interaction

| Setting | Default |
| --- | --- |
| Interaction Range | 2.2 m |
| Interact Time | 0.25 s (time spent in the Interacting state) |

## Debug readout

F3 (Options on the controller) shows: state, grounded and distance to the
ground, horizontal speed and target speed, horizontal and vertical velocity,
stick deflection and whether you're running, crouch and capsule height (and
whether a ceiling is stopping you standing), attack and phase, block, dash
availability (ready, dashing, recovering, or blocked by state), what you're
aiming at, health, input device and FPS. It's on by default in the test
level (*Show Debug Overlay* on the level root).

## Tests

```
godot --headless --path . res://tests/controller_test.tscn
```

77 checks in the test level, driving Jeffrey through the real Input Map
actions. They cover the acceptance tests in the spec:

- Acceleration and deceleration; Run only while held; half stick walks
  slower; normalised diagonals; backward and strafe speed.
- Jump height, reduced air control, jump buffer, coyote time off a ledge,
  running jump over the 2.5 m gap.
- Smooth stairs, real 25 cm steps, the 21° ramp; the 53° slope can't be climbed.
- Crouch: toggle, capsule and eye height, speed, the 1.3 m passage, can't
  stand under it, stands once clear.
- Dash: about 3 m in 0.22 s along the stick, backward when centred, no spam,
  stops at a wall without clipping, look works during it, no jump mid-dash.
- Sword: light and heavy timing and damage, one hit per swing, chaining,
  stopping at walls, look works mid-attack, no dash during a heavy attack, the
  shield can't interrupt a swing.
- Shield: no attacks while blocking, frontal attack blocked, side and rear
  attacks get through.
- Interaction: prompts for the door, lever and campfire, no prompt out of
  reach, door opens and you walk through, locked gate, lever opens it, pickup,
  rest menu opens and closes.
- Ladders up and down, the cliff ladder, all three bridges, death and respawn.

The older suites still pass too:
`tests/smoke_test.tscn` (the greybox slice) and
`tests/level_tools_test.tscn` (the editor tools and the new pieces).

### What the tests can't check

- **A real DualSense.** The tests press the Input Map actions, so they prove
  the actions work, not that your OS reports Cross as "A" or L2 as the left
  trigger axis. Plug one in and check each button in the test area; the
  readout's last line says *gamepad* once it sees the controller.
- **Feel.** Whether walking, stopping, jumping and the camera feel like
  Thief II is for you to judge. Use the checklist below.
- **Audio.** The block clank, sword thud, whoosh and scrape are synthesised
  placeholders; the tests run with no audio device.

## Manual playtest checklist

From the spec, in the test area:

- **Walking and strafing:** circle the pillars, stop abruptly, walk diagonally.
- **Jumping:** the 2 m-high platforms, the gaps (1.5 m walking, 2.5 m running), running jumps.
- **Dash:** dodge sideways round the attack dummy, and into the dash-lane walls.
- **Combat:** are light and heavy timings readable on the straw dummy? Can you always look around?
- **Shield:** block the attack dummy from the front, then the side, then with your back to it.
- **Crouch:** the 1.3 m passage; try standing up inside it.
- **Controller:** every button in the table above, partial stick tilt, L2 and R2 as analog triggers.

## Notes against the spec and the GDD

Where the spec and the GDD disagree, this follows the spec:

- **No stamina.** The first prototype's stamina bar (sprint, attacks and
  blocking all cost it) is gone. Run is hold-to-run with no limit.
- **No mantle.** Jumping at a ledge used to climb it. The spec says no
  mantle yet, so 1.2 m ledges are now too high (the test area has one to
  show this). The grappling hook still clambers onto a ledge at the end of a pull.
- **Grappling hook is an add-on.** It isn't part of the controller. It's
  `scripts/player/grapple_hook.gd`, which Main adds only when the level's
  *Allow Grapple* is on (the greybox slice, the example camp). The test area
  turns it off. In the GDD it's a later unlock (the Hookshot, 7.3).
- **No lean.** Q/E lean is gone; E is now Interact.
- **Rest at a campfire** is now Interact (E / Square) on the fire, not F.
  F is the heavy attack.
- **Shield** blocks a 120° frontal cone and lets 15% of the damage through,
  which is the GDD's "soaks most of a hit" without the stamina cost.
- **Capsule plus a ray leg.** The body is a capsule, as the spec asks, riding
  on a short downward ray (a SeparationRayShape3D) so stairs and kerbs are
  walked up smoothly. Walking off a ledge drops you cleanly; steep slopes
  are read from the ground ray and slide you off.
- **Ladders** add a *Climbing* state the spec doesn't list. Walk into a
  ladder (or press Interact next to it) to grab it; push forward to climb,
  back to go down (or look down and push forward), and you step off onto the
  ledge at the top. Jump lets go.
- Backstabs (×4 on an unaware enemy from behind) stay, but on the enemy's
  side of the damage interface.
