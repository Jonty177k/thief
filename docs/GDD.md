# JEFFREY BRINGS DEATH 2.0

**Game Design Document — Version 0.1**

- **Genre:** First-Person Stealth / Exploration / Immersive Sim
- **Engine:** Godot
- **Platform:** PC (Steam), with potential console ports
- **Estimated Length:** 3–5 hours
- **Visual Style:** Retro 3D dark fantasy, inspired by late-1990s PC games
- **Development:** Solo developer with AI-assisted programming and custom visual level-building tools

## 1. High Concept

Jeffrey Brings Death 2.0 is a first-person, open-world stealth adventure set on the back of an enormous living colossus.

You play as Jeffrey, a physically weak peasant demon tasked with ascending the colossus toward an enormous glowing tree growing from its summit.

The tree is visible from much of the world, providing a constant sense of direction and an ultimate destination.

The colossus's body supports a strange civilization of prisons, underground settlements, cities, and aristocratic mansions. Its inhabitants have built their society around exploiting the creature that sustains them.

Jeffrey must navigate this dangerous world through exploration, stealth, climbing, and supernatural movement abilities.

Enemies are overwhelmingly powerful. Combat is possible but dangerous, and Jeffrey never becomes significantly stronger.

As Jeffrey ascends, he discovers that the aristocracy's pollution and exploitation are slowly killing the colossus.

His journey culminates in a mansion constructed around the great tree itself.

Jeffrey kills the tree.
The colossus dies.
The world ends.

### Design Pillars

1. **Exploration and Discovery:** Players should constantly wonder whether a distant location is reachable and experiment with different routes.
2. **Vulnerability:** Jeffrey is physically weak. Avoiding enemies is usually preferable to fighting them.
3. **Verticality:** Climbing, descending, grappling, and discovering elevated pathways define traversal.
4. **Player Ingenuity:** Abilities should interact with environments in multiple ways, encouraging experimentation.
5. **Atmosphere:** Lighting, sound, architecture, and environmental storytelling create an unsettling fantasy world.
6. **Compact Design:** A short, interconnected adventure with carefully constructed levels and minimal filler.

## 2. Inspirations

### Thief: The Dark Project

Primary inspiration for stealth, level design, sound propagation, enemy awareness, and atmosphere.

Specific references:

- Cragscleft Prison
- The Lost City
- The Haunted Cathedral
- Large, nonlinear infiltration environments

### Elden Ring

Primary inspiration for the overworld.

- A distant, visible destination
- Dangerous enemies that encourage avoidance
- Multiple possible routes
- Organic exploration
- Campfire checkpoints
- Environmental storytelling
- The satisfaction of discovering unexpected pathways

### Shadow of the Colossus / God of War

Inspiration for the setting and scale. The entire playable world exists on the body of an enormous creature.

### Metroid Prime

Inspiration for movement progression. New abilities expand the player's traversal options and encourage revisiting previously inaccessible areas.

## 3. Player Character

### Jeffrey

Jeffrey is a peasant demon. He is small, physically vulnerable, and poorly equipped compared with the creatures and soldiers inhabiting the colossus.

### Starting Equipment

- Sword
- Shield
- Basic movement abilities

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

Progression primarily comes from unlocking movement and magic abilities rather than increasing character statistics.

Combat should be simple, responsive, and skill-based.

**Design goal:** An experienced player can survive encounters through timing and positioning, but combat never becomes trivial.

### Controller

Jeffrey's first-person controller follows the separate *First-Person
Controller Specification*: Thief II-style grounded movement, hold-to-run,
toggle crouch, a short directional dash, light and heavy sword attacks, a
held shield and a context Interact button, on a DualSense or keyboard and
mouse. Where that spec and this document differ, the spec wins for now:

- No stamina. Running, attacking and blocking cost nothing.
- No mantling (jumping onto chest-high ledges). The Hookshot (7.3) still
  pulls Jeffrey up onto a ledge.
- No leaning.
- The shield blocks a 120° cone in front and lets 15% of a blocked hit through.
- Resting at a campfire is done with Interact.

Controls, tuning values and test results: [CONTROLLER.md](CONTROLLER.md).

## 4. Core Gameplay Loop

1. Rest at a campfire to heal and choose the time of day.
2. Observe the surrounding environment and identify possible routes toward the tree.
3. Explore pathways, ruins, buildings, and dangerous wilderness.
4. Avoid or carefully engage enemies.
5. Use mobility abilities to overcome obstacles and discover shortcuts.
6. Find new campfires, secrets, and entrances to major levels.
7. Complete major levels to unlock new abilities and access higher regions of the colossus.
8. Return to the overworld and continue ascending.

### Exploration Philosophy

The player should frequently experience:

- "Can I get up there?"
- "What's behind that building?"
- "Can I sneak around these enemies?"
- "Does this path connect to somewhere I've already been?"

The world should reward curiosity and spatial reasoning.

## 5. World Structure

The world consists of interconnected open environments punctuated by large, carefully designed immersive-sim levels.

### Overall Progression

#### Area 1 — Lower Colossus Overworld

The player begins near the lower regions of the creature. The enormous glowing tree is visible far above.

Features:

- Winding paths
- Ruined settlements
- Dangerous enemies
- Cliffs and vertical obstacles
- Campfires
- Hidden shortcuts
- Multiple possible approaches

Paths eventually funnel toward the first major levels.

#### Level 1 — The Prison

*Inspiration: Cragscleft Prison, Thief: The Dark Project*

A large, oppressive prison built into the colossus.

Gameplay emphasis:

- Traditional stealth
- Guard patrols
- Dark corridors
- Vertical shafts
- Multiple infiltration routes
- Keys, switches, and environmental puzzles

The player must navigate the prison and discover a route farther into the colossus.

#### Level 2 — The Underground City

*Inspiration: The Lost City, Thief: The Dark Project*

A supernatural underground environment buried within the creature.

Features:

- Ancient architecture
- Caverns
- Unnatural lighting
- Strange creatures
- Hidden pathways
- Environmental hazards
- Extensive vertical exploration

The level should feel mysterious and disorienting. After escaping, Jeffrey emerges into a higher region of the overworld.

#### Area 2 — Upper Colossus Overworld

A new open region with greater elevation, increasingly strange architecture, and more dangerous enemies.

The player has acquired new traversal abilities, enabling more sophisticated navigation. Previously impossible routes become accessible.

#### Level 3 — The Aristocratic City

*Inspiration: Life of the Party, Thief II*

A dense, vertical city built into the upper reaches of the colossus. The player navigates rooftops, balconies, bridges, interiors, and elevated walkways.

The city reveals the central environmental conflict: the aristocracy's industry and pollution are poisoning the colossus.

Features:

- Rooftop traversal
- Guarded estates
- Wealthy residences
- Industrial infrastructure
- Environmental storytelling
- Multiple infiltration routes

This level leads toward the final mansion.

#### Level 4 — The Tree Mansion

A grand aristocratic mansion physically constructed around the enormous tree that sustains the colossus. The architecture is intertwined with massive roots, branches, and organic structures.

The mansion is the final major level.

Gameplay emphasis:

- Complex vertical traversal
- Advanced stealth
- Combining previously acquired abilities
- Interconnected rooms and passages
- Reaching the tree's vital structure

#### Finale — Death of the Colossus

Jeffrey kills the tree.
The colossus begins dying.
The world collapses.
The game ends.

Final sequence details remain to be designed.

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

## 7. Player Abilities and Upgrades

Abilities are acquired progressively throughout the adventure. They expand the player's options without making Jeffrey substantially stronger in direct combat.

### 7.1 Bow and Arrow

A versatile ranged weapon and environmental tool.

**Standard Arrow**

- Deals ranged damage
- Can distract enemies through impact sounds
- Allows attacks from a distance

**Water-Fused Arrow**

- Extinguishes torches and flames
- Creates darkness for stealth
- Allows players to manipulate lighting

**Fire-Fused Arrow**

- Ignites flammable surfaces and objects
- Can illuminate dark spaces
- Can create environmental hazards

**Design Requirements**

- The bow should be responsive and simple to operate.
- Arrow fusion should be accessible through a quick selection interface.
- Water and fire interactions should work consistently with environmental objects.
- The system should reward experimentation without requiring complicated crafting menus.

### 7.2 Feather Drop

A supernatural ability allowing Jeffrey to survive falls from enormous heights.

**Activation:** Hold the Run button while falling.

**Behavior**

- Slows or magically cushions the fall
- Prevents or significantly reduces fall damage
- Produces a bright flash of light
- Creates a loud sound

**Stealth Tradeoff:** Feather Drop attracts nearby enemies. It is excellent for exploration and emergency descent but dangerous during stealth encounters.

**Design Purpose:** Enables large vertical drops and new descending routes without eliminating the importance of stealth.

### 7.3 Hookshot / Wire Gun

A multifunctional traversal tool. This is one of the game's most important mechanics.

**Mode A — Hookshot**

The player fires a hook toward a valid attachment point. Jeffrey is rapidly pulled toward the attachment point, similar to Link's hookshot.

Uses:

- Scaling buildings
- Crossing gaps
- Reaching ledges
- Escaping dangerous situations
- Navigating vertical environments

**Mode B — Wire Placement**

The player fires a wire toward a distant attachment point. The other end can be secured to a nearby surface. This creates a traversable wire between two locations. Jeffrey can climb onto the wire and carefully walk across it.

Uses:

- Crossing courtyards silently
- Moving between rooftops
- Avoiding enemies below
- Creating alternative infiltration routes
- Bypassing dangerous terrain

**Design Philosophy:** The hookshot emphasizes fast movement. The wire emphasizes careful, deliberate traversal. The player chooses the appropriate approach depending on the situation.

**Technical Requirements**

- Reliable attachment detection
- Visible attachment feedback
- Configurable maximum range
- Rope or wire rendering
- Collision-safe player movement
- Smooth transitions between ground and wire
- Clear feedback when an attachment is invalid

### 7.4 Double Jump

A second jump performed while airborne. *Inspiration: Metroid Prime*

**Behavior**

- Enables additional height and distance
- Improves precision platforming
- Allows access to elevated routes
- Can be combined with other traversal abilities

**Stealth Characteristics:** Relatively quiet. Double Jump should be the preferred option for controlled, precise vertical movement.

**Acquisition:** Obtained during the mansion portion of the aristocratic city / Life of the Party-inspired sequence.

### 7.5 Wing Flap

Jeffrey uses his demonic wings to launch himself high into the air.

**Behavior**

- Provides a powerful vertical boost
- Reaches significantly greater heights than Double Jump
- Enables access to high ledges and structures
- Can be combined with Hookshot movement

**Stealth Tradeoff:** Wing Flap produces a very loud noise. Nearby enemies are alerted.

**Design Purpose:** Provides an exciting, powerful movement option while preserving the importance of stealth.

**Double Jump vs. Wing Flap**

- Double Jump: Quiet, precise, limited height.
- Wing Flap: Loud, powerful, substantial vertical height.

Both should remain useful throughout the game.

## 8. Stealth System

Stealth is a central gameplay mechanic.

### Visibility

Enemy detection depends on:

- Light levels
- Distance
- Line of sight
- Player movement
- Environmental cover

Darkness should meaningfully reduce detection.

### Sound

Enemies respond to sound generated by:

- Footsteps
- Running
- Jumping and landing
- Weapons
- Environmental objects
- Feather Drop
- Wing Flap

Different surfaces may produce different amounts of noise.

### Enemy Awareness

Suggested states:

1. Unaware
2. Suspicious
3. Investigating
4. Alerted
5. Searching
6. Returning to patrol

Enemies should investigate disturbances and communicate threats when appropriate.

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
- Hookshot attachment points
- Wire attachment locations
- Accessible ledges
- Dangerous falls
- Concealed routes

Visual language should remain consistent.

### Ability-Based Exploration

New movement abilities should unlock alternative paths through existing environments. Revisiting earlier locations should reveal new opportunities.

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

The game will be developed in Godot with AI-assisted programming. Claude will help create the foundational systems and custom visual tools. The developer should be able to construct and modify environments without writing code for routine level-building tasks.

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
- Hookshot anchors
- Wire attachment surfaces
- Ability pickups
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

**Development goal:** Claude builds reusable gameplay systems and editor functionality. The developer handles world construction, level design, visual direction, and gameplay tuning through Godot's GUI.

## 13. Technical Architecture

- **Engine:** Godot 4.x
- **Perspective:** First-person

### Core Systems

1. First-person character controller
2. Sword and shield combat
3. Enemy AI and patrols
4. Visibility-based stealth
5. Sound detection
6. Day/night cycle
7. Campfire checkpoints
8. Bow and arrow system
9. Elemental arrow fusion
10. Feather Drop
11. Hookshot and wire traversal
12. Double Jump
13. Wing Flap
14. Ability acquisition
15. Save/load system
16. Level transitions
17. Modular environment tools

### Implementation Principles

- Systems should be modular and reusable.
- Gameplay variables should be exposed through Godot's Inspector or custom editor interfaces.
- Avoid hardcoding level-specific behavior into general gameplay systems.

Prefer data-driven configuration for:

- Enemy properties
- Ability parameters
- Lighting
- Sound intensity
- Traversal distances
- Damage
- Cooldowns

## 14. Prototype Development Roadmap

### Phase 1 — Core Movement

Build a playable first-person controller. Implement:

- Walking
- Running
- Jumping
- Crouching
- Basic collision
- Camera controls

Create a small blockout environment.

**Success criterion:** Moving through the environment feels responsive and satisfying.

### Phase 2 — Traversal Abilities

Implement:

- Feather Drop
- Hookshot
- Wire placement and traversal
- Double Jump
- Wing Flap

Create a vertical obstacle course to test every ability.

**Success criterion:** Traversal is reliable, intuitive, and enjoyable.

### Phase 3 — Stealth

Implement:

- Basic enemy AI
- Patrol routes
- Vision detection
- Hearing detection
- Suspicion states
- Enemy searching behavior

Create a small guarded courtyard.

**Success criterion:** Players can infiltrate the courtyard using multiple routes and abilities.

### Phase 4 — Combat and Bow

Implement:

- Sword attacks
- Shield blocking
- Enemy melee attacks
- Damage and death
- Bow and arrow
- Fire arrows
- Water arrows
- Torch extinguishing

**Success criterion:** Combat feels responsive, and elemental arrows meaningfully affect stealth.

### Phase 5 — World Systems

Implement:

- Day/night cycle
- Campfires
- Resting
- Checkpoints
- Saving and loading
- Ability acquisition

**Success criterion:** A short playable adventure loop works from beginning to end.

### Phase 6 — Visual Development Tools

Build or configure:

- Modular block placement
- Terrain editing
- Lighting tools
- Enemy placement
- Patrol editing
- Gameplay object placement
- Prefab library

**Success criterion:** The developer can create a new playable area primarily through GUI tools.

### Phase 7 — Vertical Slice

Construct one polished, interconnected environment demonstrating:

- Open exploration
- Vertical movement
- Stealth
- Combat
- Environmental interactions
- Campfire resting
- Day/night changes
- Multiple routes
- A meaningful destination

This should be a small, representative section of the finished game.

**Success criterion:** The prototype demonstrates the game's unique appeal and can be tested by players unfamiliar with the project.

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
- Hookshot/wire gun
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

These decisions should be resolved through prototyping.

1. Can the hookshot attach to any suitable surface, or only designated materials?
2. Can wires be placed freely between arbitrary surfaces?
3. Does Wing Flap have a cooldown or other limitation?
4. Does Feather Drop consume a resource?
5. Are arrows limited by ammunition?
6. Can the player return freely to earlier regions?
7. Does the day/night cycle advance automatically as well as through resting?
8. How does Jeffrey acquire each upgrade?
9. What motivates Jeffrey to kill the tree?
10. Is the final destruction interactive, cinematic, or a combination?
11. Does the colossus physically move during gameplay?
12. How much optional exploration is appropriate for a four-hour experience?

## 17. Creative Vision

Jeffrey Brings Death 2.0 should evoke the feeling of being small and vulnerable in an enormous, hostile, mysterious world.

The player sees the glowing tree far above and gradually discovers a route toward it.

Every region should inspire curiosity.

Every new ability should change how the player understands the environment.

Every major level should feel like a believable place with secrets, alternate entrances, and hidden connections.

The game should reward observation, patience, experimentation, and ingenuity.

Jeffrey remains weak.
The player becomes capable.
And at the summit of the colossus, Jeffrey brings death to the world that carried him there.
