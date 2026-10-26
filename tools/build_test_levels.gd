extends Node
## Builds the combat and traversal test levels from Level Tools pieces, so
## they stay editable in the editor afterwards:
##   godot --headless --path . res://tools/build_test_levels.tscn
##   levels/combat_arena.tscn    sword and shield vs. a dummy and a swordsman
##   levels/archery_range.tscn   the bow: torches, fire, water, a switch
## Re-running overwrites them, so edit a level by hand OR here.

const Catalog := preload("res://addons/jbd_level_tools/catalog.gd")
const M := "res://addons/jbd_level_tools/materials/"

var level: JBDLevel
var rng := RandomNumberGenerator.new()
var groups := {}


func _ready() -> void:
	var err := OK
	for build in [_combat_arena, _archery_range]:
		err = max(err, _save(build))
	get_tree().quit(err)


func _save(build: Callable) -> int:
	rng.seed = 11
	groups.clear()
	level = JBDLevel.new()
	level.allow_grapple = false
	level.show_debug_overlay = true
	level.colossus_tremors = false
	var out: String = build.call()
	var ps := PackedScene.new()
	var err := ps.pack(level)
	if err == OK:
		err = ResourceSaver.save(ps, out)
	print("Saved %s: %d" % [out, err])
	level.free()
	return err


func _group(name: String) -> Node3D:
	if groups.has(name):
		return groups[name]
	var g := Node3D.new()
	g.name = name
	level.add_child(g)
	g.owner = level
	groups[name] = g
	return g


func _add(group: String, n: Node3D, pos: Vector3, yaw_deg := 0.0, name := "") -> Node3D:
	if name != "":
		n.name = name
	_group(group).add_child(n, true)
	n.owner = level
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	return n


func _piece(group: String, id: String, pos: Vector3, yaw_deg := 0.0, name := "") -> Node3D:
	return _add(group, Catalog.make(id, rng), pos, yaw_deg, name)


func _block(group: String, shape: int, size: Vector3, pos: Vector3, mat := "grid", name := "") -> JBDBlock:
	var b := JBDBlock.new()
	b.shape = shape
	b.size = size
	b.material = load(M + mat + ".tres")
	return _add(group, b, pos, 0.0, name)


func _box(size: Vector3, pos: Vector3, mat := "grid", name := "", group := "Building") -> JBDBlock:
	return _block(group, JBDBlock.Shape.BOX, size, pos, mat, name)


func _sign(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.pixel_size = 0.008
	l.font_size = 40
	l.outline_size = 10
	l.modulate = Color(1.0, 0.92, 0.7)
	_add("Signs", l, pos)


func _start(pos: Vector3, yaw_deg := 0.0) -> void:
	var start := JBDPlayerStart.new()
	start.name = "PlayerStart"
	level.add_child(start)
	start.owner = level
	start.position = pos
	start.rotation_degrees.y = yaw_deg


## Four walls round a floor, `size` across, walls `h` high.
func _room(size: Vector2, h: float, mat := "ruin", floor_mat := "grid") -> void:
	_box(Vector3(size.x, 1, size.y), Vector3(0, -1, 0), floor_mat, "Floor")
	for side in [-1.0, 1.0]:
		_box(Vector3(size.x + 1, h, 0.5), Vector3(0, 0, side * (size.y * 0.5 + 0.25)), mat)
		_box(Vector3(0.5, h, size.y), Vector3(side * (size.x * 0.5 + 0.25), 0, 0), mat)


# --- Combat arena -------------------------------------------------------------

func _combat_arena() -> String:
	level.name = "CombatArena"
	level.level_name = "Combat arena"
	level.start_hour = 12.0
	level.intro_text = "Combat arena. F3 hides the readout and hitboxes."
	_room(Vector2(28, 28), 4.0)
	_start(Vector3(0, 0, 11))
	var fire: JBDCampfire = _piece("Gameplay", "campfire", Vector3(-4, 0, 12), 0.0, "Campfire")
	fire.fire_name = "Arena Fire"
	_sign("COMBAT ARENA\nRest at the fire to bring the swordsman back", Vector3(0, 3.2, 13.5))

	# West: the stationary dummy, with a wall beside it to swing into.
	_piece("Gameplay", "training_dummy", Vector3(-8, 0, 2), 90.0, "TrainingDummy")
	_box(Vector3(0.6, 3, 4), Vector3(-10.5, 0, -2), "ruin", "SwingWall")
	_sign("Dummy: light combo, heavy\nThen swing into the wall", Vector3(-8, 3.2, 2))

	# Obstacles to strafe round and break line of sight.
	_block("Building", JBDBlock.Shape.PILLAR, Vector3(1.2, 4, 1.2), Vector3(5, 0, 3), "ruin", "PillarA")
	_block("Building", JBDBlock.Shape.PILLAR, Vector3(1.2, 4, 1.2), Vector3(-4, 0, -6), "ruin", "PillarB")
	_box(Vector3(3, 1.0, 1.2), Vector3(7, 0, -6), "wood", "LowCrates")
	_box(Vector3(4, 2.5, 0.6), Vector3(0, 0, -11), "ruin", "CoverWall")

	# North: the swordsman, waiting in the open.
	_piece("Enemies", "swordsman", Vector3(1, 0, -4), 180.0, "Swordsman")
	_sign("Swordsman: watch the windup,\nblock or dodge, punish the recovery", Vector3(1, 3.4, -8))
	return "res://levels/combat_arena.tscn"


# --- Archery range -------------------------------------------------------------

func _archery_range() -> String:
	level.name = "ArcheryRange"
	level.level_name = "Archery range"
	level.start_hour = 23.0
	level.intro_text = "Archery range. 2 for the bow, Q / D-pad up for fire and water arrows."
	var W := 24.0
	var D := 30.0
	_box(Vector3(W, 1, D), Vector3(0, -1, 0), "grid", "Floor")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 5, D), Vector3(side * (W * 0.5 + 0.25), 0, 0), "ruin")
	_box(Vector3(W + 1, 5, 0.5), Vector3(0, 0, D * 0.5 + 0.25), "ruin")
	# North wall with a gated doorway into a small vault.
	_box(Vector3(10.5, 5, 0.5), Vector3(-6.75, 0, -D * 0.5 - 0.25), "ruin")
	_box(Vector3(10.5, 5, 0.5), Vector3(6.75, 0, -D * 0.5 - 0.25), "ruin")
	var doorway := _block("Building", JBDBlock.Shape.DOORWAY, Vector3(3, 5, 0.5), Vector3(0, 0, -D * 0.5 - 0.25), "ruin", "VaultDoorway")
	doorway.opening = Vector2(1.4, 2.4)
	var gate: JBDDoor = _piece("Gameplay", "door", Vector3(0, 0, -D * 0.5 - 0.25), 0.0, "VaultGate")
	gate.locked = true
	gate.material = load(M + "iron.tres")
	_box(Vector3(6, 0.4, 4), Vector3(0, 5, -D * 0.5 - 2.5), "dark", "VaultRoof")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 5, 4), Vector3(side * 3.25, 0, -D * 0.5 - 2.5), "ruin")
	_box(Vector3(7, 5, 0.5), Vector3(0, 0, -D * 0.5 - 4.75), "ruin")
	var prize: JBDPickup = _piece("Gameplay", "pickup", Vector3(0, 0, -D * 0.5 - 3), 0.0, "VaultPrize")
	prize.item_name = "a tarnished reliquary"

	_start(Vector3(0, 0, 12))
	_sign("ARCHERY RANGE (night)\n2: bow   hold LMB / R2 to draw   Q / D-pad up: arrow type", Vector3(0, 3.0, 13.5))

	# West: a lit torch on the wall. East: an unlit one.
	_piece("Gameplay", "torch_wall", Vector3(-W * 0.5, 1.8, 2), -90.0, "LitTorch")
	var dark: JBDTorch = _piece("Gameplay", "torch_wall", Vector3(W * 0.5, 1.8, 2), 90.0, "UnlitTorch")
	dark.lit = false
	_sign("Water arrow: put it out", Vector3(-W * 0.5 + 1.2, 3.2, 2))
	_sign("Fire arrow: light it", Vector3(W * 0.5 - 1.2, 3.2, 2))

	# A wooden crate stack that burns, beside straw that's a fire hazard.
	var crates := _box(Vector3(1.4, 1.4, 1.4), Vector3(4, 0, -3), "wood", "Crates")
	var burn := Flammable.new()
	burn.name = "Flammable"
	crates.add_child(burn)
	burn.owner = level
	burn.position = Vector3(0, 1.4, 0)
	burn.burn_time = 15.0
	var straw := _box(Vector3(2.2, 0.5, 1.6), Vector3(6, 0, -3), "wood", "Straw")
	var hazard := Flammable.new()
	hazard.name = "Flammable"
	straw.add_child(hazard)
	hazard.owner = level
	hazard.position = Vector3(0, 0.5, 0)
	hazard.burn_time = 20.0
	hazard.hazard_damage_per_second = 20.0
	hazard.flame_size = Vector3(1.6, 0.7, 1.2)
	_sign("Fire arrow: wood burns,\nstraw catches and hurts", Vector3(5, 3.0, -3))

	# A stone wall arrows clatter off and can't pass, with a dummy behind it.
	_box(Vector3(6, 3, 0.6), Vector3(-4, 0, -4), "ruin", "StoneWall")
	_piece("Gameplay", "training_dummy", Vector3(-4, 0, -5.5), 0.0, "HiddenDummy")
	_piece("Gameplay", "training_dummy", Vector3(-7.5, 0, 0), 180.0, "Dummy")
	_sign("Dummy  |  stone wall: nothing gets through", Vector3(-5.5, 3.6, -2))

	# An elevated target on a ledge.
	_box(Vector3(2.5, 4, 2.5), Vector3(8, 0, -11), "ruin", "TargetLedge")
	_piece("Gameplay", "training_dummy", Vector3(8, 4, -11), 180.0, "HighDummy")
	_sign("Elevated target", Vector3(8, 7.0, -11))

	# A switch high on the north wall opens the vault gate.
	var sw := JBDArrowSwitch.new()
	sw.target = NodePath("../../Gameplay/VaultGate")
	sw.one_shot = true
	_add("Gameplay", sw, Vector3(-5, 3.6, -D * 0.5), 180.0, "ArrowSwitch")
	_sign("Shoot the switch", Vector3(-5, 4.8, -D * 0.5 + 0.6))

	# A warden guards the vault in torchlight. Douse the torch to slip past.
	var guard_torch: JBDTorch = _piece("Gameplay", "torch_standing", Vector3(2.5, 0, -12.5), 0.0, "GuardTorch")
	guard_torch.light_range = 10.0
	var warden: JBDEnemy = _piece("Enemies", "warden", Vector3(-1.5, 0, -12), 180.0, "Warden")
	for c in warden.get_children():
		c.queue_free()
		warden.remove_child(c)
	return "res://levels/archery_range.tscn"
