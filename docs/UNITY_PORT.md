# Unity port plan

Jeffrey is moving from Godot 4.3 to Unity. This is the plan: what Unity
project we set up, how each Godot system maps across, and the order we
build in. The design it serves is [GDD.md](GDD.md) v0.2 (three dungeons on
the outskirts, three keys, the tower at the centre).

The Godot build on `main` stays as the reference. Its systems have been
tuned by feel and tested, so the port copies their behaviour and their
tuning values rather than redesigning them.

## The Unity project

| Choice | Pick | Why |
| --- | --- | --- |
| Version | **Unity 6 LTS** (6000.0.x) | Long-term support, current URP and AI Navigation |
| Render pipeline | **URP** | Fast, simple, good for a deliberately low-fi look; easy to render low-res and upscale |
| Language | C# | |
| Input | **Input System** package, one `Controls.inputactions` asset | Same as Godot's Input Map: rebindable without code, DualSense and keyboard/mouse |
| Player body | `CharacterController` | Kinematic, like Godot's `CharacterBody3D`; we keep full control of the feel |
| Enemy movement | **AI Navigation** (NavMesh) | The Godot build had no pathfinding; Unity gives us it for free |
| Level building | **Terrain** + **Terrain Tools**, **ProBuilder**, **Polybrush**, grid snapping | Covers most of the Godot Level Tools plugin out of the box |
| Tests | **Unity Test Framework** (edit and play mode) | Replaces the headless Godot test scenes |
| Version control | Git with Git LFS for textures, audio and models; Unity's standard `.gitignore` | |

### The low-res look

The Godot build renders at 640×360 and scales up with nearest-neighbour
filtering. In Unity: the game camera renders into a 640×360
`RenderTexture` with point filtering, and a full-screen `RawImage` (or a
URP blit) shows it at window size. Textures import with Point filtering
and no compression artefacts. Fog and vertex-lit-looking materials in URP
Simple Lit.

## Folder layout

```
Assets/
  _Game/
    Scripts/
      Player/        PlayerController, PlayerInput, PlayerMovement, PlayerCamera,
                     PlayerVault, PlayerDash, PlayerSword, PlayerShield,
                     PlayerInteraction, PlayerStealth, PlayerLoadout, Viewmodel
      Tools/         RopeArrowBow, RopeArrow, ClimbRope, BombThrower, Bomb, Glider
      Combat/        DamageInfo, IDamageable, Health, EnemyAttack, Swordsman
      Elements/      ElementalEffect, IElementReceiver, Flammable, Flame, Extinguishable
      Stealth/       NoiseEvent, NoiseSystem, LightGem, SurfaceNoise
      AI/            Guard, Monster, Wildlife, Perception, AwarenessState
      World/         GameClock, DayNight, Campfire, Checkpoints, DungeonKey,
                     TowerGate, Door, Lever, Ladder, Elevator, LevelExit
      NPC/           Talker, Merchant, Wallet
      Save/          SaveSystem, SaveData
      UI/            Hud, LightGemView, RestMenu, MerchantMenu, Prompts, DebugOverlay
    Data/            ScriptableObjects: enemy kinds, tool tuning, surface noise, merchant stock
    Prefabs/         Player, enemies, campfire, door, ladder, elevator, torch, key, ...
    Materials/       grass, dirt, rock, wood, stone, iron, ... (the Godot material set)
    Scenes/
      Boot.unity     loads the game and the first scene
      Overworld.unity
      Dungeon_Prison.unity, Dungeon_SunkenCity.unity, Dungeon_Aristocrats.unity
      Tower.unity
      Test/          ControllerTest, CombatArena, ToolRange, StealthYard
  Editor/            LevelPalette window, play-test buttons, gizmos
  Tests/
    EditMode/, PlayMode/
```

## How Godot maps to Unity

| Godot | Unity |
| --- | --- |
| Scene (`.tscn`) of nodes | Prefab or Scene of GameObjects |
| Script on a node, `@export` vars | `MonoBehaviour`, `[SerializeField]` fields |
| `Resource` (`.tres`), `RefCounted` data | `ScriptableObject` assets, plain C# classes |
| Signals | C# `event`s / `UnityEvent`s |
| Autoload (`Game`) | A `GameClock` / `NoiseSystem` singleton created by `Boot` |
| Input Map actions | Input System actions in `Controls.inputactions` |
| `move_and_slide()` | `CharacterController.Move()` |
| Raycasts (`PhysicsRayQuery`) | `Physics.Raycast` / `SphereCast` with layer masks |
| Groups | Tags, layers, or a component lookup |
| Editor plugin (`EditorPlugin`, dock) | `EditorWindow`, `[CustomEditor]`, gizmos |
| Headless test scenes | Unity Test Framework, run in batch mode |

### System by system

| Godot file(s) | Unity component | Notes |
| --- | --- | --- |
| `player/player.gd` (states, health, `can_*` rules) | `PlayerController` | Same state list and the same `can_*` rules in one place. Adds a **Vaulting** state |
| `player_input.gd` | `PlayerInput` | Reads `Controls` once per frame into a struct the other components read |
| `player_movement.gd` (walk, run, crouch, jump, slopes, steps, ladders) | `PlayerMovement` | Port the numbers from CONTROLLER.md's tuning tables. CharacterController's `stepOffset` and `slopeLimit` replace the step ray; ladders stay a custom state |
| (new) | `PlayerVault` | Forward and down casts find a ledge up to ~1.5 m; a short curve lifts Jeffrey onto it |
| `player_camera.gd`, head bob | `PlayerCamera` | Pitch limits, bob, landing dip |
| `player_dash.gd` | `PlayerDash` | Same distance, timing and cancel rules |
| `player_sword.gd`, `player_shield.gd`, `damage_info.gd` | `PlayerSword`, `PlayerShield`, `DamageInfo`, `IDamageable` | Windup / active / recovery timings and the 120° block cone carry over. Hitboxes as trigger volumes during the active window |
| `combat/swordsman.gd`, `enemy_attack.gd` | `Swordsman`, `EnemyAttack` | Same attack table; moves on the NavMesh |
| `player_bow.gd`, `arrow.gd`, `arrow_type.gd` | `RopeArrowBow`, `RopeArrow` | The bow's draw and aim feel carries over. The arrow sticks in **Wood**-layer colliders and spawns a `ClimbRope` |
| `player_hookshot.gd` (aim and "will it bite" feedback) | `RopeArrowBow` aim reticle | Reuse the o / x / + crosshair logic. The haul and wire modes are parked |
| `traversal/rope.gd` | `ClimbRope` | A rope you climb like a ladder, length-limited, recoverable |
| `elements/*.gd` (ElementalEffect, Flame, Flammable, fx) | `Elements/*` | Same receiver pattern: anything with `IElementReceiver` decides its own response. Fire and water now come from bombs instead of arrows |
| (new) | `BombThrower`, `Bomb` | Thrown with an arc preview; on impact emit an `ElementalEffect` with a radius and a `NoiseEvent` |
| (new) | `Glider` | Opens in the air: caps fall speed, adds forward drift, steers with look |
| `player_stealth.gd`, `stealth/noise_event.gd`, `Game.emit_noise` | `PlayerStealth`, `LightGem`, `NoiseEvent`, `NoiseSystem` | Light gem samples nearby lights plus daylight and crouch/stillness, as now. Noise events go through one `NoiseSystem` event that listeners subscribe to |
| (new) | `SurfaceNoise` | A `SurfaceType` per physics material or terrain layer (stone, metal, wood, grass, carpet, water) sets footstep loudness and sound |
| `enemy.gd` (Warden/Hollow stats, awareness) | `Guard`, `Monster`, `Perception`, data in `EnemyKind` assets | Awareness states from GDD §8 (unaware, suspicious, investigating, alerted, searching, returning). Patrol routes as waypoint lists. Night variants as different `EnemyKind`s |
| `game.gd`, `day_night.gd` | `GameClock`, `DayNight` | 10-minute day, rest to morning (6:30) or evening (19:30), sun, moon, fog, ambient light |
| `campfire.gd`, `hud.gd` rest menu | `Campfire`, `RestMenu` | Heal, set checkpoint, rest, reset enemies |
| Level Tools objects: door, lever, ladder, torch, bridge, pickup, level exit, player start, enemy spawner | Prefabs with small components | One prefab per piece, on the Level Palette |
| `addons/jbd_level_tools` terrain | Unity Terrain + Terrain Tools | Sculpt, smooth, flatten, paint layers are built in |
| `addons/jbd_level_tools` blocks, landforms, prefabs, snapping | ProBuilder, Polybrush, prefabs, grid snapping | Built in |
| `addons/jbd_level_tools` dock and catalog | `LevelPalette` editor window | A grid of our gameplay prefabs to click-place, patrol-route editing gizmos, and Play from Player Start / Play from editor camera buttons |
| `debug_overlay.gd` | `DebugOverlay` | Same F3 readout |
| `gamepad.gd` | (mostly not needed) | The Input System knows the DualSense natively |
| `tests/*.gd` | `Tests/EditMode`, `Tests/PlayMode` | Port the controller acceptance checks first |

### New for 0.2

- **Keys and the tower gate:** `DungeonKey` pickups set a flag in the save;
  `TowerGate` has three locks that show which keys you hold.
- **Elevators:** a platform on a path, called and ridden; the player rides
  it by being parented to it or by adding its velocity.
- **NPCs and merchants:** simple talk (a few lines, maybe a choice) and a
  shop menu that sells arrows and bombs for coin.
- **Wildlife:** a light AI that wanders and flees, and makes noise when startled.
- **Scene loading:** the overworld and each dungeon are separate scenes
  loaded with `SceneManager`; level exits carry Jeffrey between them and
  place him at a matching entrance.
- **Saving:** JSON in `Application.persistentDataPath`: checkpoint, time of
  day, keys held, tool counts, coin, opened shortcuts.

## Build order

Each phase ends with something to play in a test scene.

1. **Project and controller.** Create the Unity 6 URP project, packages,
   input actions, the low-res camera, and `PlayerController` with walk,
   run, crouch, jump, ladders, dash and **vaulting**. Rebuild the
   controller test area with ProBuilder. Port the controller acceptance
   tests.
2. **Combat.** Sword, shield, `DamageInfo`, training dummies, the
   swordsman. Rebuild the combat arena.
3. **Tools.** Rope arrows and climbable ropes, water and fire bombs, the
   elemental system (torches, flammables, extinguishing), the glider. A
   tool range test scene.
4. **Stealth.** Light gem, surface noise, the noise system, guards with
   perception and awareness states on a NavMesh, patrol routes. A stealth
   yard test scene.
5. **World systems.** Day/night, campfires and resting, doors, levers,
   keys, the tower gate, elevators, scene loading, saving.
6. **Level tools.** The Level Palette window and play-test buttons, on top
   of Terrain, ProBuilder and Polybrush. A short guide like LEVEL_TOOLS.md.
7. **Vertical slice.** One region of the outskirts with a campfire, a
   village, a guarded road, and the entrance and first floor of one
   dungeon (probably the Prison).
8. **Content.** NPCs and merchants, monsters and wildlife, the three
   dungeons, the tower, the finale.

## What I can and can't do from here

I can write the whole Unity project's C# code, scenes set-up scripts,
editor tools and tests, and commit them. What I can't do in this cloud
workspace is open the Unity editor or run Unity: it isn't installed here
and needs a licence. So each phase needs a check on your machine (open the
project in Unity 6, play the test scene, run the tests in the Test
Runner). If you link your computer to the project, I can run Unity's
tests there in batch mode myself.

To keep the editor-only work small, scenes are generated by editor scripts
(a menu item such as *Jeffrey → Build Test Scenes*), the same way the
Godot test levels were built by `tools/build_test_levels.gd`. That way the
scenes are reproducible from code and you never have to hand-fix a
broken scene file.

## Where it lives

To be decided with Matthew: either the same repo (`thief`) on a new
branch, with the Unity project in its own folder, or a new repo.
