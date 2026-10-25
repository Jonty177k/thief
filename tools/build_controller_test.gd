extends Node
## Builds levels/controller_test.tscn, the controller test area, from
## Level Tools pieces (so it stays editable in the editor afterwards).
##   godot --headless --path . res://tools/build_controller_test.tscn
## Re-running overwrites the level, so edit the level by hand OR here.

const Catalog := preload("res://addons/jbd_level_tools/catalog.gd")
const M := "res://addons/jbd_level_tools/materials/"
const OUT := "res://levels/controller_test.tscn"

var level: JBDLevel
var rng := RandomNumberGenerator.new()
var groups := {}


func _ready() -> void:
	rng.seed = 7
	level = JBDLevel.new()
	level.name = "ControllerTest"
	level.level_name = "Controller test"
	level.start_hour = 11.0
	level.intro_text = "Controller test area. F3 hides the readout."
	level.allow_grapple = false
	level.show_debug_overlay = true
	level.colossus_tremors = false
	_build()
	var ps := PackedScene.new()
	var err := ps.pack(level)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("Saved %s: %d" % [OUT, err])
	level.free()
	get_tree().quit(err)


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


func _sign(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.pixel_size = 0.008
	l.font_size = 40
	l.outline_size = 10
	l.modulate = Color(1.0, 0.92, 0.7)
	_add("Signs", l, pos)


func _build() -> void:
	var BOX := JBDBlock.Shape.BOX

	# Floor: 90 x 70 m of grid, top at y = 0.
	_block("Building", BOX, Vector3(90, 1, 70), Vector3(0, -1, 0), "grid", "Floor")

	var start := JBDPlayerStart.new()
	start.name = "PlayerStart"
	level.add_child(start)
	start.owner = level
	start.position = Vector3(0, 0, 12)

	# --- Spawn: campfire, a pickup, pillars to circle --------------------
	var fire: JBDCampfire = _piece("Gameplay", "campfire", Vector3(-4, 0, 14), 0.0, "Campfire")
	fire.fire_name = "Test Fire"
	var charm: JBDPickup = _piece("Gameplay", "pickup", Vector3(4, 0, 12), 0.0, "Pickup")
	charm.item_name = "a bone charm"
	_sign("CONTROLLER TEST AREA\nWalk, strafe and stop around the pillars", Vector3(0, 3.2, 4))
	for x in [-3.0, 3.0]:
		_block("Building", JBDBlock.Shape.PILLAR, Vector3(1, 3, 1), Vector3(x, 0, 0), "ruin")

	# --- Combat yard ------------------------------------------------------
	_piece("Gameplay", "training_dummy", Vector3(-3, 0, -9), 180.0, "TrainingDummy")
	_piece("Gameplay", "attack_dummy", Vector3(4, 0, -9), 180.0, "AttackDummy")
	_sign("Light and heavy attacks", Vector3(-3, 3.2, -9))
	_sign("Block it facing it, then\nturn your back and block", Vector3(4, 3.4, -9))

	# --- East: corridor, crouch passage, dash lane -----------------------
	for x in [9.25, 10.75]:
		_block("Building", BOX, Vector3(0.5, 3, 10), Vector3(x, 0, -2))
	_sign("Narrow corridor (1 m)", Vector3(10, 3.6, 3.5))
	for x in [13.75, 16.25]:
		_block("Building", BOX, Vector3(0.5, 1.3, 6), Vector3(x, 0, -2))
	_block("Building", BOX, Vector3(3, 0.4, 6), Vector3(15, 1.3, -2), "grid", "CrouchCeiling")
	_sign("Crouch passage (1.3 m)", Vector3(15, 2.6, 1.5))
	for x in [19.75, 24.25]:
		_block("Building", BOX, Vector3(0.5, 3, 10), Vector3(x, 0, -2))
	_sign("Dash into the walls (4 m lane)", Vector3(22, 3.6, 3.5))
	# A plain wall with a ladder, for climbing.
	_block("Building", BOX, Vector3(4, 5, 3), Vector3(30, 0, -4), "grid", "LadderWall")
	var wall_ladder: JBDLadder = _piece("Building", "ladder", Vector3(30, 0, -2.44), 180.0, "WallLadder")
	wall_ladder.height = 5.0
	_sign("Ladder (5 m)", Vector3(30, 6, -1))

	# --- West: stairs, steps, platforms, jump gaps, ramps ----------------
	var smooth: JBDBlock = _block("Building", JBDBlock.Shape.STAIRS, Vector3(3, 2, 5), Vector3(-10, 0, -0.5), "grid", "Stairs")
	smooth.steps = 10
	var steps: JBDBlock = _block("Building", JBDBlock.Shape.STAIRS, Vector3(3, 2, 6), Vector3(-14, 0, 0), "grid", "Steps")
	steps.steps = 8
	steps.smooth_collision = false
	_sign("Stairs  |  real 25 cm steps", Vector3(-12, 3.4, 3))
	_block("Building", BOX, Vector3(7, 2, 4), Vector3(-12, 0, -5), "grid", "UpperDeck")
	# Gaps of 1.5, 2, 2.5 and 3 m between 2 m-high platforms.
	var z := -7.0
	var n := 1
	for gap in [1.5, 2.0, 2.5, 3.0]:
		var depth := 3.0 if gap >= 3.0 else 2.0
		z -= gap
		_block("Building", BOX, Vector3(3, 2, depth), Vector3(-12, 0, z - depth * 0.5), "grid", "JumpPlatform%d" % n)
		_sign("%.1f m gap%s" % [gap, "  (walk)" if gap < 2.0 else "  (run)"], Vector3(-12, 3.5, z + gap * 0.5))
		z -= depth
		n += 1
	# Ledges to jump onto from the floor.
	var hx := -6.0
	for h in [0.4, 0.8, 1.2]:
		_block("Building", BOX, Vector3(2, h, 2), Vector3(hx, 0, 7), "grid", "Ledge%dcm" % roundi(h * 100))
		_sign("%d cm%s" % [roundi(h * 100), "\n(too high: no mantle yet)" if h > 1.0 else ""], Vector3(hx, h + 1.4, 7))
		hx -= 3.0
	var ramp: JBDBlock = _block("Building", JBDBlock.Shape.RAMP, Vector3(3, 3, 8), Vector3(-20, 0, 2), "grid", "Ramp")
	_block("Building", BOX, Vector3(3, 3, 3), Vector3(-20, 0, -3.5), "grid", "RampTop")
	_sign("Ramp (21°)", Vector3(-20, 4.5, 6))
	_block("Building", JBDBlock.Shape.RAMP, Vector3(3, 4, 3), Vector3(-25, 0, 2), "grid", "SteepRamp")
	_sign("Too steep (53°)", Vector3(-25, 5.2, 4))

	# --- North: door, gate and lever ---------------------------------------
	# An 8 x 8 m room with a door in the south wall and a locked gate in the
	# north wall, opened by a lever outside.
	var rz := -20.0
	for x in [-2.75, 2.75]:
		_block("Building", BOX, Vector3(2.5, 3, 0.5), Vector3(x, 0, rz), "ruin")
		_block("Building", BOX, Vector3(2.5, 3, 0.5), Vector3(x, 0, rz - 8), "ruin")
	_block("Building", JBDBlock.Shape.DOORWAY, Vector3(3, 3, 0.5), Vector3(0, 0, rz), "ruin", "SouthDoorway").opening = Vector2(1.4, 2.4)
	_block("Building", JBDBlock.Shape.DOORWAY, Vector3(3, 3, 0.5), Vector3(0, 0, rz - 8), "ruin", "NorthDoorway").opening = Vector2(1.4, 2.4)
	for x in [-4.25, 4.25]:
		_block("Building", BOX, Vector3(0.5, 3, 8.5), Vector3(x, 0, rz - 4), "ruin")
	_block("Building", BOX, Vector3(9, 0.4, 8.5), Vector3(0, 3, rz - 4), "dark", "Roof")
	_piece("Gameplay", "door", Vector3(0, 0, rz), 0.0, "Door")
	var gate: JBDDoor = _piece("Gameplay", "door", Vector3(0, 0, rz - 8), 0.0, "Gate")
	gate.locked = true
	gate.material = load(M + "iron.tres")
	var lever: JBDLever = _piece("Gameplay", "lever", Vector3(3.2, 0, rz + 1.2), 180.0, "Lever")
	lever.target = NodePath("../Gate")
	var inside: JBDPickup = _piece("Gameplay", "pickup", Vector3(-2.5, 0, rz - 5), 0.0, "RoomPickup")
	inside.item_name = "a rusted key"
	_sign("Door (use it)  |  Lever opens the far gate", Vector3(0, 4.2, rz + 1))

	# --- Far north: the opening-area pieces --------------------------------
	_sign("OPENING-AREA PIECES\nground tiles, cliff + ladder, bridges, plateau, hills, mountains", Vector3(0, 4, -37))
	for gx in [-24.0, -8.0, 8.0, 24.0]:
		for gz in [-43.0, -59.0, -75.0]:
			var tile: JBDLandform = _piece("Ground", "ground_grass_big", Vector3(gx, 0, gz), 0.0)
			tile.rock_seed = rng.randi() % 1000
	_piece("Ground", "hill", Vector3(36, 0, -50))
	_piece("Ground", "ground_slope", Vector3(-38, 0, -44), 0.0)

	# Cliff with a ladder up its face, a rope bridge from its top to a plateau.
	var cliff: JBDLandform = _piece("Mountains", "cliff", Vector3(0, 0, -44), 180.0, "Cliff")
	cliff.size = Vector3(12, 6, 4)
	cliff.roughness = 0.5
	# Stand the ladder just clear of the rock's most protruding bump.
	cliff.rebuild()
	var face := -42.0
	for v in (cliff._collision.shape as ConcavePolygonShape3D).get_faces():
		if absf(v.x) < 0.8 and v.y < 5.5:
			face = maxf(face, -44.0 - v.z)  # turned 180°: local -z is world +z
	var cliff_ladder: JBDLadder = _piece("Mountains", "ladder", Vector3(0, 0, face + 0.08), 180.0, "CliffLadder")
	cliff_ladder.height = 6.2
	var rope: JBDBridge = _piece("Bridges", "rope_bridge", Vector3(0, 6.0, -45.6), 0.0, "RopeBridge")
	rope.length = 9.0
	var mesa: JBDLandform = _piece("Mountains", "mesa", Vector3(0, 0, -61), 0.0, "Plateau")
	mesa.size = Vector3(16, 6, 16)
	mesa.roughness = 0.6

	# Two platforms joined by a plank bridge, a ladder up the first.
	_block("Building", BOX, Vector3(4, 3, 4), Vector3(16, 0, -42), "ruin", "PlankA")
	_block("Building", BOX, Vector3(4, 3, 4), Vector3(16, 0, -56), "ruin", "PlankB")
	var a_ladder: JBDLadder = _piece("Building", "ladder", Vector3(16, 0, -39.94), 180.0, "PlankLadder")
	a_ladder.height = 3.0
	var plank: JBDBridge = _piece("Bridges", "plank_bridge", Vector3(16, 3, -44), 0.0, "PlankBridge")
	plank.length = 10.0

	# Two platforms joined by a stone bridge, stairs up the first.
	_block("Building", BOX, Vector3(4, 3, 4), Vector3(-16, 0, -42), "ruin", "StoneA")
	_block("Building", BOX, Vector3(4, 3, 4), Vector3(-16, 0, -56), "ruin", "StoneB")
	_block("Building", JBDBlock.Shape.STAIRS, Vector3(3, 3, 5), Vector3(-16, 0, -37.5), "ruin", "StoneStairs")
	var stone: JBDBridge = _piece("Bridges", "stone_bridge", Vector3(-16, 3, -44), 0.0, "StoneBridge")

	# Ledge, spires and mountains on the skyline.
	_piece("Mountains", "ledge", Vector3(-30, 2, -52), 90.0)
	_piece("Mountains", "spire", Vector3(28, 0, -68))
	_piece("Mountains", "spire", Vector3(-30, 0, -70))
	_piece("Mountains", "mountain_small", Vector3(14, 0, -95))
	_piece("Mountains", "mountain", Vector3(-45, 0, -120))
	_piece("Mountains", "mountain", Vector3(40, 0, -130))
	_sign("Rope bridge", Vector3(0, 8.5, -50))
	_sign("Plank bridge", Vector3(16, 5.5, -49))
	_sign("Stone bridge", Vector3(-16, 5.5, -49))
