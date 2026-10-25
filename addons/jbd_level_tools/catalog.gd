@tool
extends RefCounted
## Everything the Place tab can drop into a level, and how to make each one.
## Add an entry to ITEMS to put a new piece on the palette.

const M := "res://addons/jbd_level_tools/materials/"
const PREFAB_DIR := "res://prefabs/"

const Block := preload("res://addons/jbd_level_tools/objects/block.gd")
const Torch := preload("res://addons/jbd_level_tools/objects/torch.gd")
const CampfireSpot := preload("res://addons/jbd_level_tools/objects/campfire_spot.gd")
const EnemySpawner := preload("res://addons/jbd_level_tools/objects/enemy_spawner.gd")
const PlayerStart := preload("res://addons/jbd_level_tools/objects/player_start.gd")
const ShadowZone := preload("res://addons/jbd_level_tools/objects/shadow_zone.gd")
const LevelExit := preload("res://addons/jbd_level_tools/objects/level_exit.gd")
const Landform := preload("res://addons/jbd_level_tools/objects/landform.gd")
const Ladder := preload("res://addons/jbd_level_tools/objects/ladder.gd")
const Bridge := preload("res://addons/jbd_level_tools/objects/bridge.gd")
const Door := preload("res://addons/jbd_level_tools/objects/door.gd")
const Lever := preload("res://addons/jbd_level_tools/objects/lever.gd")
const Pickup := preload("res://addons/jbd_level_tools/objects/pickup.gd")
const TrainingDummy := preload("res://addons/jbd_level_tools/objects/training_dummy.gd")
const AttackDummy := preload("res://addons/jbd_level_tools/objects/attack_dummy.gd")

## id: [label, category, tooltip]
const ITEMS := {
	"campfire": ["Campfire", "Gameplay", "Checkpoint. Rest here to heal and pick morning or evening."],
	"torch_wall": ["Wall torch", "Gameplay", "Click a wall: the torch mounts facing out of it."],
	"torch_standing": ["Standing torch", "Gameplay", "A torch on a pole."],
	"hook_anchor": ["Hook anchor", "Gameplay", "A wooden beam the grappling hook bites into."],
	"warden": ["Warden", "Gameplay", "Patrols day and night. Comes with two patrol points."],
	"hollow": ["Hollow", "Gameplay", "Only walks at night. Comes with two patrol points."],
	"patrol_point": ["Patrol point", "Gameplay", "Select an enemy first, then click to add points to its route."],
	"player_start": ["Player start", "Gameplay", "Where Jeffrey wakes up. One per level."],
	"shadow_zone": ["Shadow zone", "Gameplay", "Deep shadow: dims the light gem inside it."],
	"level_exit": ["Level exit", "Gameplay", "Reaching it completes the level."],
	"door": ["Door", "Gameplay", "Hinged door. Fits a Doorway block. Tick Locked to make it lever-only."],
	"lever": ["Lever", "Gameplay", "Set its Target to a door (or anything with activate())."],
	"pickup": ["Pickup", "Gameplay", "A small item to pick up. Set Item Name."],
	"training_dummy": ["Dummy", "Gameplay", "Straw dummy that shows the damage you do."],
	"attack_dummy": ["Attack dummy", "Gameplay", "Turns to face you and swings a club. For testing the shield."],
	"ground_grass": ["Grass tile", "Ground", "8 x 8 m of gently rolling grass. Its top sits at the click."],
	"ground_grass_big": ["Big grass", "Ground", "16 x 16 m of rolling grass."],
	"ground_dirt": ["Dirt tile", "Ground", "8 x 8 m of bare earth."],
	"ground_rocky": ["Rocky ground", "Ground", "8 x 8 m of bumpy stony ground."],
	"ground_slope": ["Slope", "Ground", "8 x 8 m grassy slope, rising 3 m toward -Z."],
	"hill": ["Hill", "Ground", "A 16 m grassy mound, 4 m high."],
	"cliff": ["Cliff", "Mountains", "12 m wide, 8 m high rock face toward -Z, grass on top."],
	"cliff_tall": ["Tall cliff", "Mountains", "16 m wide, 18 m high rock face toward -Z."],
	"ledge": ["Ledge", "Mountains", "Flat-topped outcrop to stand on. Push it into a cliff."],
	"mesa": ["Plateau", "Mountains", "Steep-sided rock with a flat grassy top, 8 m high."],
	"spire": ["Spire", "Mountains", "A tall pillar of rock."],
	"mountain_small": ["Peak", "Mountains", "A 24 m wide rocky peak."],
	"mountain": ["Mountain", "Mountains", "A 60 m wide mountain for the skyline."],
	"ladder": ["Ladder", "Bridges & Ladders", "Click a wall or cliff: it stands on the ground and reaches the top."],
	"ladder_tall": ["Long ladder", "Bridges & Ladders", "An 8 m ladder (or fits the wall you click)."],
	"plank_bridge": ["Plank bridge", "Bridges & Ladders", "8 m, with railings. Starts at the click, spans toward -Z."],
	"rope_bridge": ["Rope bridge", "Bridges & Ladders", "12 m sagging rope bridge. Starts at the click, spans toward -Z."],
	"stone_bridge": ["Stone bridge", "Bridges & Ladders", "10 m stone arch with parapets."],
	"floor": ["Floor", "Building", "4 x 4 m slab."],
	"wall": ["Wall", "Building", "4 m wide, 4 m tall."],
	"ceiling": ["Ceiling", "Building", "Thin dark slab. Raise it with the gizmo."],
	"platform": ["Platform", "Building", "2 x 2 m stone block."],
	"bridge": ["Bridge", "Building", "Narrow wooden walkway. Grapple-able."],
	"beam": ["Beam", "Building", "Thin wooden beam. Grapple-able."],
	"stairs": ["Stairs", "Building", "Climbs toward -Z."],
	"ramp": ["Ramp", "Building", "Climbs toward -Z."],
	"arch": ["Arch", "Building", "Wall with an arched opening."],
	"doorway": ["Doorway", "Building", "Wall with a door-sized opening."],
	"window": ["Window", "Building", "Wall with a window."],
	"pillar": ["Pillar", "Building", "8-sided column."],
	"roof": ["Roof", "Building", "Gabled roof."],
	"rock": ["Rock", "Nature", "Lumpy boulder. Every one is different."],
	"rock_large": ["Big rock", "Nature", "A boulder the size of a hut."],
	"bone_spur": ["Bone spur", "Nature", "Tall spike of bone, good cover."],
}


static func categories() -> Array[String]:
	return ["Gameplay", "Ground", "Mountains", "Bridges & Ladders", "Building", "Nature"]


static func items_in(category: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id][1] == category:
			out.append(id)
	return out


static func prefab_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(PREFAB_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			out.append(PREFAB_DIR + f)
	return out


static func label(id: String) -> String:
	if id.begins_with("res://"):
		return id.get_file().get_basename().capitalize()
	return ITEMS[id][0]


## Which group node a new piece goes under, to keep the scene tree tidy.
static func container_for(id: String) -> String:
	if id.begins_with("res://"):
		return "Prefabs"
	if id in ["warden", "hollow"]:
		return "Enemies"
	if id in ["patrol_point", "player_start"]:
		return ""
	return ITEMS[id][1]


## Mounts on walls instead of standing on floors.
static func wall_mounted(id: String) -> bool:
	return id in ["torch_wall", "ladder", "ladder_tall"]


## Called when a wall-mounted piece is placed on a wall at `pos` facing
## `normal`. Ladders stand on the ground below and reach the wall's top.
static func fit_to_wall(node: Node3D, xf: Transform3D, normal: Vector3, space: PhysicsDirectSpaceState3D) -> Transform3D:
	if not node is JBDLadder:
		return xf
	var n := Vector3(normal.x, 0, normal.z).normalized()
	var pos := xf.origin + n * 0.06
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + n * 0.3 + Vector3.UP * 0.1, pos + n * 0.3 + Vector3.DOWN * 200.0))
	var inside := xf.origin - n * 0.25
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(inside + Vector3.UP * 200.0, inside + Vector3.DOWN * 1.0))
	if not down.is_empty():
		pos.y = down.position.y
	if not top.is_empty() and top.position.y > pos.y + 0.5:
		node.height = snappedf(top.position.y - pos.y, 0.05)
	xf.origin = pos
	return xf


## Build a fresh, unparented node for an item id or a prefab path.
static func make(id: String, rng: RandomNumberGenerator = null) -> Node3D:
	if id.begins_with("res://"):
		var ps: PackedScene = load(id)
		return ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE if Engine.is_editor_hint() else PackedScene.GEN_EDIT_STATE_DISABLED)
	var n: Node3D
	match id:
		"campfire":
			n = CampfireSpot.new()
		"torch_wall":
			n = Torch.new()
		"torch_standing":
			n = Torch.new()
			n.style = Torch.Style.STANDING
		"hook_anchor":
			n = _block(Block.Shape.BOX, Vector3(1.4, 0.6, 3), "wood", true)
		"warden", "hollow":
			n = EnemySpawner.new()
			n.kind = id
			n.load_defaults()
			for i in 2:
				var m := Marker3D.new()
				m.name = "Patrol%d" % (i + 1)
				m.position = Vector3(0, 0, -6.0 * i)
				n.add_child(m)
		"patrol_point":
			n = Marker3D.new()
		"player_start":
			n = PlayerStart.new()
		"shadow_zone":
			n = ShadowZone.new()
		"level_exit":
			n = LevelExit.new()
		"door":
			n = Door.new()
		"lever":
			n = Lever.new()
		"pickup":
			n = Pickup.new()
		"training_dummy":
			n = TrainingDummy.new()
		"attack_dummy":
			n = AttackDummy.new()
		"ground_grass", "ground_grass_big", "ground_dirt", "ground_rocky":
			var w := 16.0 if id == "ground_grass_big" else 8.0
			n = _land(Landform.Form.GROUND, Vector3(w, 1.5, w), 0.6, 6.0, rng)
			if id == "ground_dirt":
				n.top_material = load(M + "dirt.tres")
			elif id == "ground_rocky":
				n.top_material = load(M + "rock.tres")
				n.roughness = 1.2
				n.feature_size = 2.5
			n.side_material = load(M + "dirt.tres")
		"ground_slope":
			n = _land(Landform.Form.SLOPE, Vector3(8, 3, 8), 0.4, 6.0, rng)
			n.side_material = load(M + "dirt.tres")
		"hill":
			n = _land(Landform.Form.HILL, Vector3(16, 4, 16), 0.6, 6.0, rng)
			n.side_material = load(M + "dirt.tres")
			n.top_threshold = 0.45
		"cliff":
			n = _land(Landform.Form.CLIFF, Vector3(12, 8, 4), 0.9, 3.5, rng)
		"cliff_tall":
			n = _land(Landform.Form.CLIFF, Vector3(16, 18, 6), 1.4, 5.0, rng)
		"ledge":
			n = _land(Landform.Form.LEDGE, Vector3(5, 1.2, 3), 0.35, 2.0, rng)
		"mesa":
			n = _land(Landform.Form.MESA, Vector3(16, 8, 16), 1.0, 4.0, rng)
		"spire":
			n = _land(Landform.Form.SPIRE, Vector3(4, 14, 4), 0.6, 3.0, rng)
		"mountain_small":
			n = _land(Landform.Form.MOUNTAIN, Vector3(24, 14, 24), 1.6, 6.0, rng)
		"mountain":
			n = _land(Landform.Form.MOUNTAIN, Vector3(60, 40, 60), 4.0, 14.0, rng)
		"ladder":
			n = Ladder.new()
		"ladder_tall":
			n = Ladder.new()
			n.height = 8.0
		"plank_bridge":
			n = Bridge.new()
		"rope_bridge":
			n = Bridge.new()
			n.style = Bridge.Style.ROPE
			n.length = 12.0
			n.width = 1.4
		"stone_bridge":
			n = Bridge.new()
			n.style = Bridge.Style.STONE
			n.length = 10.0
			n.width = 3.0
			n.grapple_anchor = false
		"floor":
			n = _block(Block.Shape.BOX, Vector3(4, 0.5, 4), "plate")
		"wall":
			n = _block(Block.Shape.BOX, Vector3(4, 4, 0.6), "ruin")
		"ceiling":
			n = _block(Block.Shape.BOX, Vector3(4, 0.3, 4), "dark")
		"platform":
			n = _block(Block.Shape.BOX, Vector3(2, 1, 2), "ruin")
		"bridge":
			n = _block(Block.Shape.BOX, Vector3(1.6, 0.3, 8), "wood", true)
		"beam":
			n = _block(Block.Shape.BOX, Vector3(0.4, 0.4, 4), "wood", true)
		"stairs":
			n = _block(Block.Shape.STAIRS, Vector3(2, 3, 5), "ruin")
		"ramp":
			n = _block(Block.Shape.RAMP, Vector3(3, 3, 8), "plate")
		"arch":
			n = _block(Block.Shape.ARCH, Vector3(4, 4, 0.8), "ruin")
		"doorway":
			n = _block(Block.Shape.DOORWAY, Vector3(4, 4, 0.6), "ruin")
			n.opening = Vector2(1.4, 2.4)
		"window":
			n = _block(Block.Shape.WINDOW, Vector3(4, 4, 0.6), "ruin")
			n.opening = Vector2(1.2, 1.2)
			n.sill = 1.4
		"pillar":
			n = _block(Block.Shape.PILLAR, Vector3(1, 5, 1), "bone")
		"roof":
			n = _block(Block.Shape.ROOF, Vector3(5, 2, 6), "dark")
		"rock", "rock_large":
			var s := 1.6 if id == "rock" else 5.0
			n = _block(Block.Shape.ROCK, Vector3(s * 1.2, s * 0.8, s), "rock")
			n.rock_seed = rng.randi() if rng else randi()
		"bone_spur":
			n = _block(Block.Shape.PILLAR, Vector3(0.8, 4, 0.8), "bone")
	n.name = label(id).to_pascal_case()
	return n


static func _land(form: int, size: Vector3, roughness: float, feature: float, rng: RandomNumberGenerator) -> Node3D:
	var l := Landform.new()
	l.form = form
	l.size = size
	l.roughness = roughness
	l.feature_size = feature
	l.rock_seed = (rng.randi() if rng else randi()) % 100000
	return l


static func _block(shape: int, size: Vector3, mat: String, grapple := false) -> Node3D:
	var b := Block.new()
	b.shape = shape
	b.size = size
	b.material = load(M + mat + ".tres")
	b.grapple_anchor = grapple
	return b


static func snap(p: Vector3, step: float, snap_y: bool) -> Vector3:
	if step <= 0.0:
		return p
	return Vector3(snappedf(p.x, step), snappedf(p.y, step) if snap_y else p.y, snappedf(p.z, step))


## Recursively hand ownership to `owner`, so the nodes save with the scene.
## Stops at instanced scenes, which own their own insides.
static func set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	if node != owner and node.scene_file_path != "":
		return
	for c in node.get_children():
		set_owner_recursive(c, owner)
