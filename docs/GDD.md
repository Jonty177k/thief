# JEFFREY BRINGS DEATH 2.0

**Game Design Document — Version 0.2**

- **Genre:** First-Person Stealth / Exploration / Immersive Sim
- **Engine:** Unity 6 (moving from Godot; see [UNITY_PORT.md](UNITY_PORT.md))
- **Platform:** PC (Steam), with potential console ports
- **Estimated Length:** 3–5 hours
- **Visual Style:** Retro 3D dark fantasy, inspired by late-1990s PC games
- **Development:** Solo developer with AI-assisted programming and custom visual level-building tools

### What changed in 0.2

- **Structure.** Elden Ring plus Thief. The game is no longer a straight
  climb through four levels. Jeffrey crosses an open overworld to **three
  dungeons on the outskirts**, takes a **key** from each, and uses the
  three keys to enter the **tower at the centre** and climb to its top.
  The dungeons can be done in any order (section 5).
- **Engine.** The game moves from Godot to Unity. The Godot build stays on
  `main` as the reference for every system that has already been made to
  feel right.
- **Item list.** The kit now follows the *Items / World Functionality*
  list: sword, rope arrows, water bombs, fire bombs and a glider, plus
  doors, fire, the light gem, surface noise, campfires, NPCs, merchants,
  guards, monsters, wildlife, ladders, elevators and vaulting (sections 3,
  7 and 8). Where the list differs from what is built in Godot, section 7.7
  says what carries over.

## 1. High Concept

Jeffrey Brings Death 2.0 is a first-person, open-world stealth adventure set on the back of an enormous living colossus.

You play as Jeffrey, a physically weak peasant demon. At the centre of the colossus's back stands a great **tower**, and from its top grows the enormous glowing tree that keeps the creature alive. The tower is sealed. Its gate needs **three keys**, and each key is kept in a **dungeon on the outskirts** of the colossus's back.

The tower and the tree are visible from almost everywhere, giving the player a constant sense of direction and an ultimate destination. The dungeons are what stand between Jeffrey and it.

The colossus's body supports a strange civilization of prisons, drowned settlements, cities, and aristocratic estates. Its inhabitants have built their society around exploiting the creature that sustains them.

Jeffrey must navigate this dangerous world through exploration, stealth, climbing, and a handful of thief's tools.

Enemies are overwhelmingly powerful. Combat is possible but dangerous, and Jeffrey never becomes significantly stronger.

Along the way Jeffrey discovers that the aristocracy's pollution and exploitation are slowly killing the colossus.

With three keys in hand he climbs the tower, built around the trunk of the great tree, to its top.

Jeffrey kills the tree.
The colossus dies.
The world ends.

### Design Pillars

1. **Exploration and Discovery:** Players should constantly wonder whether a distant location is reachable and experiment with different routes.
2. **Vulnerability:** Jeffrey is physically weak. Avoiding enemies is usually preferable to fighting them.
3. **Verticality:** Climbing, descending, rope arrows, gliding, and discovering elevated pathways define traversal.
4. **Player Ingenuity:** Tools should interact with environments in multiple ways, encouraging experimentation.
5. **Atmosphere:** Lighting, sound, architecture, and environmental storytelling create an unsettling fantasy world.
6. **Compact Design:** A short, interconnected adventure with carefully constructed levels and minimal filler.
7. **Player's Choice of Order:** The three dungeons can be tackled in any order, Elden Ring style. The overworld is the hub that connects them.

## 2. Inspirations

### Thief: The Dark Project

Primary inspiration for stealth, level design, sound propagation, enemy awareness, and atmosphere.

Specific references:

- Cragscleft Prison
- The Lost City
- The Haunted Cathedral
- Large, nonlinear infiltration environments

### Elden Ring

Primary inspiration for the overworld and the structure: an open world with major locations you can take on in any order, and a central goal they unlock.

- A distant, visible destination
- Dangerous enemies that encourage avoidance
- Multiple possible routes
- Organic exploration
- Campfire checkpoints
- Environmental storytelling
- The satisfaction of discovering unexpected pathways

### Shadow of the Colossus / God of War

Inspiration for the setting and scale. The entire playable world exists on the body of an enormous creature.

### Zelda: Breath of the Wild

Inspiration for the glider: climbing high and drifting far is a way of seeing and crossing the world.

## 3. Player Character

### Jeffrey

Jeffrey is a peasant demon. He is small, physically vulnerable, and poorly equipped compared with the creatures and soldiers inhabiting the colossus.

### Starting Equipment

- Sword
- Shield (not on the new item list; kept for now, see question 1 in section 16)
- Rope arrows
- A few water bombs and fire bombs
- Basic movement: walk, run, crouch, jump, vault, climb ladders

### Combat Philosophy

Jeffrey's combat capabilities are comparable to a starting Confessor in Elden Ring.

He can:

- Attack with a sword
- Block attacks with a shield
- Dodge and evade enemies
- Fight individual opponents when necessary

However:

- Enemies deal significant damage.
- Fighting multiple enemies is extremely dangerous.
- Jeffrey does not gain substantial health or damage upgrades.
- Player combat skill improves through practice.

Progression comes from tools and knowledge of the world, not from character statistics.

Combat should be simple, responsive, and skill-based.

**Design goal:** An experienced player can survive encounters through timing and positioning, but combat never becomes trivial.

### Controller

Jeffrey's first-person controller follows the *First-Person Controller
Specification* that the Godot build was made to (Thief II-style grounded
movement, hold-to-run, toggle crouch, a short directional dash, light and
heavy sword attacks, a held shield, a context Interact button, DualSense or
keyboard and mouse). The Unity controller is a port of it, with the same
tuning values as the starting point. One change from the spec:

- **Vaulting is in.** The item list asks for vaulting to higher ledges, as
  in Thief. Jump at a ledge up to about chest height and Jeffrey pulls
  himself onto it. (The Godot build had no mantling.)

The rest of the spec stands: no stamina, no leaning, the shield blocks a
120° cone and lets 15% of a blocked hit through, and resting at a campfire
is done with Interact.

Controls, tuning values and test results for the Godot version:
[CONTROLLER.md](CONTROLLER.md).

## 4. Core Gameplay Loop

1. Rest at a campfire to heal and choose the time of day.
2. Look out over the colossus. Pick a dungeon to go after, or a landmark to investigate.
3. Explore pathways, ruins, villages, and dangerous wilderness to find a way there.
4. Avoid or carefully engage enemies. Talk to NPCs, and trade with merchants for bombs and arrows.
5. Use rope arrows, bombs, and the glider to overcome obstacles and discover shortcuts.
6. Find new campfires, secrets, and dungeon entrances.
7. Infiltrate a dungeon Thief-style and steal its key.
8. Return to the overworld. Repeat until Jeffrey has all three keys.
9. Open the tower and climb it.

### Exploration Philosophy

The player should frequently experience:

- "Can I get up there?"
- "What's behind that building?"
- "Can I sneak around these enemies?"
- "Does this path connect to somewhere I've already been?"
- "Which dungeon should I try next?"

The world should reward curiosity and spatial reasoning.

## 5. World Structure

**Elden Ring plus Thief.** One open overworld on the colossus's back,
three Thief-style dungeons on its outskirts, and one tower at its centre.

```
                  [ Dungeon 2: The Sunken City ]
                       (the flank, low and wet)
                                 |
   [ Dungeon 1: The Prison ] — OVERWORLD — [ Dungeon 3: The Aristocrats' Quarter ]
     (the tail / haunch)          |            (the shoulder, polluted)
                                  |
                     THE TOWER, at the centre
               (three locks on its gate; the tree at its top)
```

### The Overworld

A single compact, dense open region covering the colossus's back. The
tower is in the middle of it and visible from everywhere. The three
dungeons sit near its edges, roughly equal distances from the starting
point, so the player picks a direction rather than following one.

Features:

- Winding paths and several routes to each dungeon
- Ruined settlements, villages with NPCs and merchants
- Guards on the roads, monsters in the wilds, wildlife
- Cliffs, chasms and vertical obstacles to rope-arrow up or glide down
- Campfires
- Hidden shortcuts that connect the outskirts to each other
- The tower's sealed gate, seen early, so the player knows what the keys are for

The overworld changes between day and night (section 6). Each region of the
outskirts has its own look, so the player always knows roughly where they are.

### The Three Dungeons

Each dungeon is a large, carefully designed immersive-sim level in the
spirit of a Thief mission. Each has several ways in, a key hidden deep
inside, and a way back out to the overworld (often a shortcut that opens
from the inside).

They can be done **in any order**. That means:

- Every dungeon must be completable with the **starting kit**.
- Tools found in one dungeon (section 7.5) make the others easier or open
  optional routes, but are never required.
- Enemy difficulty is set by where you are and the time of day, not by how
  many keys you have.

#### Dungeon 1 — The Prison

*Inspiration: Cragscleft Prison, Thief: The Dark Project*

A large, oppressive prison built into the colossus's haunch.

- Traditional stealth: guard patrols, dark corridors, cell blocks
- Vertical shafts and a mine or quarry cut into the creature
- Keys, switches, lifts, and environmental puzzles
- Multiple infiltration routes: the front gate, the mine, the roofs
- The key: held by the warden, or in his office

#### Dungeon 2 — The Sunken City

*Inspiration: The Lost City, Thief: The Dark Project*

A supernatural drowned city in a hollow of the colossus's flank.

- Ancient architecture, caverns, flooded streets
- Unnatural lighting and strange creatures rather than guards
- Hidden pathways, environmental hazards, extensive vertical exploration
- Fire and water matter more here than anywhere else
- Mysterious and disorienting
- The key: on an altar or in a sealed vault at the bottom of the city

#### Dungeon 3 — The Aristocrats' Quarter

*Inspiration: Life of the Party, Thief II*

A dense, vertical district of estates on the colossus's shoulder, where
the aristocracy hold a party while their chimneys poison the creature.

- Rooftop traversal, balconies, bridges, elevated walkways
- Guarded estates and wealthy interiors
- Industrial infrastructure pumping pollution into the colossus
- Reveals the central conflict: the aristocracy's industry is killing the colossus
- The key: in a lord's vault, or worn by the host of the party

### The Tower

*Inspiration: the old Tree Mansion level*

An aristocratic tower at the centre of the colossus's back, built around
the trunk of the great tree. Its gate has three locks. With the three keys
Jeffrey opens it and climbs.

- Complex vertical traversal, inside and out
- Advanced stealth, with the hardest guards in the game
- Everything the player has learned comes together
- Roots and branches grow through the architecture
- At the top, in the crown of the tree, its vital structure

### Finale — Death of the Colossus

Jeffrey kills the tree.
The colossus begins dying.
The world collapses.
The game ends.

Final sequence details remain to be designed.

### Story Flow

Because the dungeons can be done in any order, the story is told in the
world rather than in a fixed sequence: NPCs, notes, and what Jeffrey sees.
Each dungeon shows a different face of the aristocracy's rot (who they
lock up, what they drowned, what they burn). By the third key the player
understands why the tree has to die.

## 6. Day / Night System

The game has a persistent day/night cycle. Time influences visibility, enemy behavior, and exploration.

### Daytime

Advantages:

- Easier enemies
- Better environmental visibility
- Easier navigation

Disadvantages:

- Jeffrey is more visible
- Stealth is more difficult
- Exposed routes are dangerous

### Nighttime

Advantages:

- Darkness improves stealth
- Some routes become easier to infiltrate
- Reduced visibility for enemies

Disadvantages:

- More dangerous enemies
- Greater risk when discovered
- Navigating unfamiliar environments becomes harder

### Campfires

Campfires serve as checkpoints and resting locations. At a campfire, the player can:

- Restore health
- Save checkpoint progress
- Rest until morning
- Rest until evening

Campfires should be distributed throughout the overworld and major levels.

**Design intention:** Choosing when to explore is a meaningful strategic decision.

## 7. Player Tools and Upgrades

Tools expand the player's options without making Jeffrey substantially
stronger in direct combat. The kit follows the *Items* list.

### 7.1 Sword (and shield)

Jeffrey's only real weapon: light and heavy attacks, Confessor-weak. The
shield blocks a frontal cone. The Godot build's sword and shield combat is
ported as it is ([COMBAT.md](COMBAT.md)).

### 7.2 Rope Arrows

*Inspiration: the rope arrow, Thief*

Fired from a short bow. A rope arrow that hits **wood** sticks and drops a
climbable rope to the ground. Jeffrey can climb up and down it, and pull
the arrow back out at the top or bottom to reuse it. Stone, metal and
flesh don't take it.

Rope arrows are quicker than Thief's: the arrow flies fast and flat, and
climbing is brisk.

Uses:

- Scaling walls, cliffs and buildings
- Reaching balconies and rooftops
- Climbing down into shafts and pits
- Escaping pursuit

**Design requirements**

- Readable wood: players must be able to tell what will take an arrow
- Clear aim feedback (will it stick?)
- Rope length limited, so not every height is reachable from the ground
- A small supply, recoverable, with spares from merchants

### 7.3 Water Bombs

Thrown, not fired. A water bomb bursts in a splash.

- Puts out torches and fires in the splash, creating darkness for stealth
- Puts out a burning enemy, or Jeffrey
- Makes a noise where it lands, so it doubles as a distraction

### 7.4 Fire Bombs

Thrown. A fire bomb bursts into flame.

- Sets wood, hay, cloth and some enemies alight; fire spreads
- Lights torches and braziers (useful for seeing, bad for hiding)
- Damages and scatters enemies; a dangerous last resort in a fight
- Loud and bright

**Bomb design requirements**

- Quick to throw, with a visible arc preview
- Water and fire interact with the world consistently (the elemental
  system from the Godot bow carries over)
- Limited supply, found in the world and bought from merchants

### 7.5 Glider

*Inspiration: the paraglider, Zelda: Breath of the Wild*

Open the glider in mid-air to drift down and forward instead of falling.

- Survive big drops; cross gaps from high to low
- Reach places across chasms from cliff tops and towers
- Combines with rope arrows: climb high, then glide far
- Visible in daylight, so gliding over guards by day is risky

**Acquisition (proposal):** found early in the overworld, on the way to
whichever dungeon the player reaches first, so it is part of the kit for
all three. Alternatively, a dungeon reward (see below).

### 7.6 Dungeon Rewards

Each dungeon gives its **key**, plus a reward that makes the rest of the
game richer but is never required (because the order is free). Proposals:

- More rope or rope-arrow capacity
- A bomb satchel (carry more bombs)
- A quieter tread or a cloak (less visible)
- Money for merchants

### 7.7 What carries over from the Godot build

| Built in Godot | In 0.2 |
| --- | --- |
| Sword and shield combat, swordsman enemy | Ported as is |
| Bow with plain, fire and water arrows | The bow becomes the rope-arrow bow. Fire and water become **bombs**; the elemental components (flammable, flames, extinguish) carry over unchanged |
| Hookshot (hauls Jeffrey to wood) | Replaced by **rope arrows**. Its aiming, "will it bite" feedback and wood-only rule carry over |
| Wire gun (walk a tightrope) | Parked. Not on the item list |
| Grappling hook (greybox add-on) | Replaced by rope arrows |
| Dash | Kept for combat dodging |
| Light gem, noise events, ladders, doors, levers, campfires, day/night | Ported as is |
| Feather Drop, Double Jump, Wing Flap (design only) | Cut. The glider covers falling; vaulting and rope arrows cover climbing |

## 8. Stealth System

Stealth is a central gameplay mechanic.

### Visibility

Enemy detection depends on:

- Light levels
- Distance
- Line of sight
- Player movement
- Environmental cover

Darkness should meaningfully reduce detection. A **light gem** on the HUD shows how visible Jeffrey is, as in Thief.

### Sound

Enemies respond to sound generated by:

- Footsteps
- Running
- Jumping and landing
- Weapons
- Environmental objects
- Bombs bursting
- Doors, elevators and ladders

Different surfaces produce different amounts of noise, as in Thief: stone and metal are loud, carpet, grass and moss are quiet, water splashes. Players should be able to plan a quiet route by reading the floor.

### Enemy Awareness

Suggested states:

1. Unaware
2. Suspicious
3. Investigating
4. Alerted
5. Searching
6. Returning to patrol

Enemies should investigate disturbances and communicate threats when appropriate.

### Enemy Types

- **Guards**, modelled on the Builders' guards in Thief: human, patrol, talk, carry torches, raise alarms.
- **Monsters**, modelled on Elden Ring: fantasy creatures in the wilds and the Sunken City, stronger at night.
- **Wildlife**, mostly harmless, but it can startle and give Jeffrey away.

### Stealth Philosophy

- The player should have multiple ways to avoid encounters.
- Combat should remain a viable fallback.
- Traversal abilities should create interesting stealth opportunities.

## 9. Level Design Principles

### Interconnected Environments

Levels should feature:

- Multiple entrances
- Alternative routes
- Vertical pathways
- Hidden rooms
- Shortcuts
- Loops connecting previously visited locations

Avoid excessive linear corridors.

### Vertical Design

Every major environment should use height as an important gameplay dimension. Examples:

- Rooftops
- Towers
- Balconies
- Underground shafts
- Bridges
- Tree branches
- Cliffs
- Elevated passageways

### Environmental Readability

Players should be able to recognize:

- Climbable surfaces
- Wood that takes a rope arrow
- Places to glide from and to
- Accessible ledges
- Dangerous falls
- Concealed routes

Visual language should remain consistent.

### Tool-Based Exploration

Rope arrows, bombs and the glider should each open alternative paths. Dungeon rewards should reveal new opportunities in places the player has already been.

### Open World Scope

The overworld should be compact and dense. Prioritize:

- Carefully designed paths
- Memorable landmarks
- Meaningful secrets
- Interconnected spaces
- Distinctive encounters

Avoid enormous empty terrain.

## 10. Visual Direction

### Overall Aesthetic

Retro first-person dark fantasy. Influences:

- Thief: The Dark Project
- Thief II
- Daggerfall
- Late-1990s PC 3D graphics
- Gothic and surreal architecture

### Visual Characteristics

- Low-poly geometry
- Low-resolution textures
- Strong silhouettes
- Dramatic lighting
- Deep shadows
- Atmospheric fog
- Restrained color palettes
- Strange organic architecture

### The Colossus

The environment should constantly remind players that they are standing on a living creature. Possible environmental details:

- Vast organic surfaces
- Exposed bones
- Pulsating tissue
- Roots penetrating architecture
- Distant rumbling
- Slow environmental movement
- Signs of sickness and decay

### The Tree

The giant glowing tree is the game's most important visual landmark. It should:

- Be visible from multiple locations
- Establish direction and scale
- Contrast with the surrounding darkness
- Become more visually imposing as Jeffrey approaches

## 11. Audio Direction

Sound design is essential to the experience.

### Environmental Audio

- Wind
- Distant machinery
- Creaking architecture
- Creature movement
- Organic rumbling
- Distant voices
- Footsteps on different surfaces
- Environmental ambience

### Stealth Audio

Players should be able to hear enemies before seeing them. Enemy footsteps, conversations, and reactions should communicate location and awareness.

### Colossus Audio

The creature should have an audible presence. Possible sounds:

- Deep breathing
- Heartbeats
- Internal movement
- Distant groans
- Structural vibrations

### Music

Sparse, atmospheric music. Silence and environmental audio should dominate much of the experience.

## 12. GUI Level-Building Tools

The game will be developed in Unity with AI-assisted programming. Unity already covers much of this section out of the box (Terrain tools, ProBuilder, Polybrush, grid snapping, prefabs, undo); the custom work is a placement palette for our gameplay pieces and the play-test buttons. See [UNITY_PORT.md](UNITY_PORT.md). Claude will help create the foundational systems and custom visual tools. The developer should be able to construct and modify environments without writing code for routine level-building tasks.

### 12.1 Block-Based Level Editor

A visual building system for constructing environments using modular pieces.

Required features:

- Place blocks
- Move, rotate, and scale objects
- Duplicate and delete objects
- Grid snapping
- Adjustable snap increments
- Material assignment
- Reusable prefabs
- Undo and redo
- Save and load scenes

Modular pieces:

- Floors
- Walls
- Ceilings
- Stairs
- Ramps
- Arches
- Pillars
- Doors
- Windows
- Bridges
- Platforms
- Beams
- Roofs

### 12.2 Terrain Editor

Visual terrain creation and modification. Desired features:

- Raise and lower terrain
- Smooth terrain
- Flatten terrain
- Paint textures
- Create cliffs and slopes
- Place rocks and environmental objects

### 12.3 Lighting Editor

Visual controls for:

- Light placement
- Light intensity
- Color
- Range
- Shadow casting
- Torch behavior
- Day/night lighting

### 12.4 Enemy Placement

Place enemies directly into levels. Configure through GUI:

- Enemy type
- Patrol points
- Detection range
- Hearing sensitivity
- Movement speed
- Health
- Damage
- Behavior settings

### 12.5 Gameplay Object Placement

Drag-and-drop objects:

- Campfires
- Doors
- Keys
- Switches
- Torches
- Rope-arrow wood surfaces
- Dungeon keys and the tower gate
- Elevators
- NPCs and merchants
- Tool pickups
- Checkpoints
- Environmental hazards

### 12.6 Playtesting

The developer should be able to launch directly into a level from the editor. Support:

- Start from selected position
- Test individual levels
- Debug enemy detection
- Visualize sound propagation
- Display traversal attachment points
- Adjust gameplay values without changing code

**Development goal:** Claude builds reusable gameplay systems and editor functionality. The developer handles world construction, level design, visual direction, and gameplay tuning through Unity's editor.

## 13. Technical Architecture

- **Engine:** Unity 6 LTS, Universal Render Pipeline
- **Language:** C#
- **Perspective:** First-person

The port plan, package choices and the mapping from the Godot code are in
[UNITY_PORT.md](UNITY_PORT.md).

### Core Systems

1. First-person character controller, with vaulting
2. Sword and shield combat
3. Enemy AI and patrols on a NavMesh (guards, monsters, wildlife)
4. Light gem and visibility-based stealth
5. Sound detection, with different surface noises
6. Day/night cycle
7. Campfire checkpoints
8. Rope arrows
9. Water and fire bombs, and the fire/water elemental system
10. Glider
11. Doors, keys, levers, ladders, elevators
12. NPC talk and merchants
13. Keys and the tower gate
14. Save/load system
15. Overworld and dungeon scene loading
16. Level-building tools

### Implementation Principles

- Systems should be modular and reusable components.
- Gameplay values are exposed in the Inspector (serialized fields) or in ScriptableObject assets.
- Avoid hardcoding level-specific behavior into general gameplay systems.

Prefer data-driven configuration (ScriptableObjects) for:

- Enemy properties
- Tool parameters
- Lighting
- Sound intensity and surface noise
- Traversal distances
- Damage
- Merchant stock and prices

## 14. Development Roadmap

The Godot build covered phases 1 to 4 of the old roadmap (controller,
combat, bow and elements, hookshot) and the level tools. The Unity roadmap
ports that work first, then builds the new structure. Full detail is in
[UNITY_PORT.md](UNITY_PORT.md).

1. **Unity project and controller.** Project setup, input, the controller with vaulting, the low-res look.
2. **Combat.** Sword, shield, dash, the swordsman.
3. **Tools.** Rope arrows, water and fire bombs, the elemental system, the glider.
4. **Stealth.** Light gem, surface noise, guards on a NavMesh with Thief-style awareness.
5. **World systems.** Day/night, campfires, doors and keys, elevators, saving, scene loading.
6. **Level tools.** Unity's terrain and ProBuilder, plus a placement palette for our pieces.
7. **Vertical slice.** One region of the outskirts and the first dungeon's entrance and first floor.
8. **Content.** NPCs and merchants, wildlife and monsters, the three dungeons, the tower, the finale.

**Success criterion for the slice:** a player unfamiliar with the project
can cross part of the overworld, find a dungeon, get inside by more than
one route, and get out with a key.

## 15. Scope and Commercial Goals

### Target Experience

A complete, atmospheric adventure lasting approximately 3–5 hours.

### Target Audience

Players interested in:

- Thief
- Immersive sims
- Retro first-person games
- Dark fantasy
- Environmental exploration
- Interconnected worlds
- Stealth gameplay

### Commercial Positioning

A short, distinctive indie game with strong atmosphere, satisfying movement, and memorable level design.

### Tentative Pricing

$12.99–$14.99 USD. Final pricing should depend on polish, length, replayability, and market comparisons.

### Scope Priorities

Highest priority:

- Movement quality
- Stealth
- Level design
- Rope arrows and the glider
- Atmosphere
- Environmental exploration

Secondary priority:

- Combat complexity
- Enemy variety
- Optional secrets
- Environmental interactions

Avoid unless necessary:

- Large RPG progression systems
- Complex crafting
- Loot rarity
- Procedural open-world generation
- Large numbers of weapons
- Extensive dialogue systems
- Massive environments

## 16. Open Design Questions

These decisions should be resolved through prototyping or by the designer.

1. Does Jeffrey keep the shield? It isn't on the new item list.
2. Does the hookshot survive alongside rope arrows, or do rope arrows replace it entirely? (0.2 assumes they replace it.)
3. Is the glider found early in the overworld, or a dungeon reward?
4. Are rope arrows and bombs limited, and how many can Jeffrey carry?
5. What do merchants take as money, and what do they sell?
6. Can Jeffrey kill or steal from NPCs, and do they react to it?
7. Is the tower only one climb, or does it have its own Thief-style floors with optional routes?
8. Does each dungeon need a fixed theme position (tail, flank, shoulder), or is that up to the level design?
9. Does the day/night cycle advance automatically as well as through resting?
10. What motivates Jeffrey to kill the tree?
11. Is the final destruction interactive, cinematic, or a combination?
12. Does the colossus physically move during gameplay?
13. How much optional exploration is appropriate for a four-hour experience?

## 17. Creative Vision

Jeffrey Brings Death 2.0 should evoke the feeling of being small and vulnerable in an enormous, hostile, mysterious world.

The player sees the tower and its glowing tree from the outskirts, gathers three keys from the edges of the world, and gradually discovers a route to the top.

Every region should inspire curiosity.

Every new tool should change how the player understands the environment.

Every major level should feel like a believable place with secrets, alternate entrances, and hidden connections.

The game should reward observation, patience, experimentation, and ingenuity.

Jeffrey remains weak.
The player becomes capable.
And at the summit of the colossus, Jeffrey brings death to the world that carried him there.
