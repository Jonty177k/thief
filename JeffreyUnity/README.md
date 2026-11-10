# Jeffrey Brings Death 2.0 (Unity)

A fresh Unity 6 project, started from scratch. The first job is the one
everything else stands on: **movement and controls that match Thief 2 one
to one.**

## Opening it

1. Install **Unity 6** (any 6000.0 LTS version) from Unity Hub.
2. Unity Hub → **Add** → **Add project from disk** → pick this `JeffreyUnity` folder.
   If Hub asks about the editor version, pick the Unity 6 you have.
3. The first import takes a minute. If Unity asks whether to **enable the new
   Input System backends** and restart, either answer works: the code reads
   the keyboard and mouse through whichever input system is on.
4. The movement test scene builds itself the first time and opens at
   `Assets/Jeffrey/Scenes/MovementTest.unity`. If it doesn't, use the menu
   **Jeffrey → Build Movement Test Scene**. Press **Play**.

Click in the Game view to capture the mouse. **Esc** frees it again.
**F1** hides the controls card, **F3** the debug readout.

The scene is generated from code (`Assets/Jeffrey/Editor/MovementTestBuilder.cs`),
so if it ever gets messed up, rebuild it from the menu.

## Controls

The Thief 2 defaults. Every key can be changed in the Inspector on
Jeffrey's **Thief Input** component (*Bindings*).

| Action | Key | What it does |
| --- | --- | --- |
| Run forward / move backward | W / S | Backward is slower, as in Thief |
| Strafe left / right | A / D | |
| Turn left / right | ← / → | Keyboard turning. With Alt held they strafe instead |
| Speed toggle | Shift (hold) | Walk is the default, Shift runs. Tick *Always Run* to swap them |
| Crouch | C | Toggles. Crouched you creep at half speed and fit under 1.25 m. You can't stand up under something low |
| Jump / mantle | Space | Tap to jump. **Hold** at a ledge to mantle onto it, from the ground or in mid-air. Ledges from 0.45 m to 1.9 m from standing, or catch one up to 1.6 m above your feet while jumping. Under a low roof you end up crouched |
| Slide (movement modifier) | Alt | Turns the arrow keys into strafing; with W it leans forward |
| Lean left / right | Q / E | Peek round corners. The view slides 0.6 m and tilts; it stops at walls. Slows you while leaning |
| Lean forward | Alt + W | Peek over a ledge or through a doorway without stepping forward |
| Attack | Left mouse | Placeholder. With the sword: tap for a quick slash, hold for an overhead swing. With the bow: hold to draw |
| Block | B / middle mouse | Placeholder. Sword only, while held |
| Use item / interact | Right mouse / Enter | Opens doors and picks things up. With nothing to use in front of you, uses the selected item (placeholder) |
| Drop item | R | Drops one of the selected item as a physical object. Use it to pick it back up |
| Next / previous item | Tab / Shift + Tab | Water bomb, fire bomb, glider |
| Clear selected item | Backspace | |
| Next / previous weapon | Numpad + / − | Sword, bow (rope arrows) |
| Put away weapon | ~ | |
| Zoom in / out | ] / [ | 1×, 2×, 4×, 8×. Mouse turns slower when zoomed |
| Reset zoom | P | |

Attack, block, items and weapons are wired up so every key on the list
does something visible, but the real sword, bow, bombs and glider come
later. Thief 2 has no gamepad support, so neither does this yet.

## The test course

| Where (from the start) | What |
| --- | --- |
| Straight ahead | **Mantle row**: ledges of 0.5, 0.9, 1.3, 1.7, 2.1 and 2.8 m. Walk up and hold Space. 2.1 m needs a jump first; 2.8 m is too high |
| Behind the row | A ledge under a **low roof**: mantle it and you stay crouched |
| Right | **Crouch tunnel**, 1.25 m high |
| Far right | **Stairs** (0.2 m steps), a 25° ramp you can walk up, a 55° one you can't |
| Behind you | **Jump gaps** on raised platforms: 1.5 m (walk), 2.5 m (run), 3.5 m (run and hold Space to catch the far ledge) |
| Left | **Lean corner**: stand on the wooden square at the end of the wall, face the way you started, and lean left (Q) to see the red "guard" round the corner |
| Far left | **Balcony**: walk up the ramp, stand at the parapet and lean forward (Alt + W) to see the red marker at the foot of the wall |
| Back left | Two **doors**: one opens, one is locked |

## How it's built

Everything is on one GameObject, **Jeffrey**, with its origin at his feet:

```
Jeffrey               CharacterController (the body)
│  ThiefInput         reads keys and mouse once per frame; the bindings     ← tune
│  ThiefMovement      walk, run, crouch, jump, mantle, slide, lean-forward  ← tune
│  ThiefCamera        mouse look, eye height, leaning, head bob, zoom       ← tune
│  ThiefActions       weapons, attack/block, inventory, use, drop (placeholders)
│  ThiefHud           crosshair, prompts, weapon/item, F3 readout, F1 card
└── Eye               the pivot that leans and pitches
    └── Camera
```

Scripts are in `Assets/Jeffrey/Scripts`. Anything with an `IThiefUsable`
component can be used with right mouse (see `ThiefDoor`).

Jeffrey is on the *Ignore Raycast* layer so his own collider never gets in
the way of the ledge, headroom, lean and use checks.

## Tuning

All of these are in the Inspector. The numbers are starting estimates of
Thief 2's feel, not measured values, so tune by feel.

**Thief Movement**

| Setting | Default | |
| --- | --- | --- |
| Walk Speed / Run Speed | 2.6 / 5.2 m/s | |
| Crouch Multiplier | 0.5 | Creep speed, as a fraction of walk or run |
| Backward / Strafe Multiplier | 0.7 / 0.85 | |
| Always Run | off | |
| Ground Acceleration / Deceleration | 28 / 22 m/s² | |
| Air Acceleration | 3 m/s² | Thief gives you very little air control |
| Jump Height | 0.8 m | |
| Gravity | 20 m/s² | |
| Keyboard Turn Speed | 130 °/s | Arrow keys |
| Stand / Crouch Height | 1.8 / 1.05 m | |
| Crouch Is Toggle | on | Off: hold C |
| Step Offset / Slope Limit | 0.35 m / 46° | |
| Mantle Min Height | 0.45 m | Lower is just a step |
| Mantle Max Height Grounded / Airborne | 1.9 / 1.6 m | |
| Mantle Reach | 0.6 m | How far ahead a ledge can be |
| Mantle Rise Time / Forward Time | 0.7 / 0.3 s | Thief's mantle is slow and deliberate |

**Thief Camera**

| Setting | Default | |
| --- | --- | --- |
| Max Pitch | 85° | |
| Lean Distance / Lean Roll | 0.6 m / 12° | |
| Lean Speed | 4 | Full leans per second |
| Lean Move Multiplier | 0.4 | Speed while fully leaning |
| Lean Forward Distance / Pitch | 0.45 m / 6° | |
| Bob Walk / Bob Run | 0.025 / 0.045 m | |
| Base Field Of View | 75° | |
| Zoom Levels | 1, 2, 4, 8 | |

**Thief Input**: *Mouse Sensitivity* (degrees per pixel, 0.12) and *Invert Mouse Y*.

## Status

The code has been compile-checked but **has not yet been run in the Unity
editor**: there's no Unity in the cloud workspace it was written in. The
first open is the first real test, so expect some tuning and possibly a
fix or two.

Not in yet: ladders, ropes, swimming, fall damage, footstep sounds and
surface noise, the light gem, and the real weapons and items.
