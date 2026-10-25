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
	return ["Gameplay", "Building", "Nature"]


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
	return id == "torch_wall"


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
