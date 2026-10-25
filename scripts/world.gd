extends Node3D
## Greybox of the Colossus's back: three plateaus climbing toward the
## glowing tree on its shoulder. Brown wood is the only thing the
## grappling hook will bite into.

signal goal_reached

const Enemy := preload("res://scripts/enemy.gd")
const Campfire := preload("res://scripts/campfire.gd")

var campfires: Array[Node3D] = []
var goal_announced := false

var noise_tex: NoiseTexture2D
var m_hide: StandardMaterial3D
var m_plate: StandardMaterial3D
var m_bone: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_ruin: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_tree: StandardMaterial3D
var m_leaf: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_haunch()
	_build_ribs()
	_build_shoulder()
	_build_tree()
	_build_colossus_silhouette()
	_spawn_enemies()


# --- Helpers ----------------------------------------------------------------

func _make_materials() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 64
	noise_tex.height = 64
	noise_tex.seamless = true
	noise_tex.noise = noise
	m_hide = _mat(Color(0.42, 0.38, 0.34))
	m_plate = _mat(Color(0.5, 0.47, 0.42))
	m_bone = _mat(Color(0.82, 0.78, 0.68))
	m_wood = _mat(Color(0.5, 0.3, 0.12), 0.5)
	m_ruin = _mat(Color(0.55, 0.52, 0.46))
	m_dark = _mat(Color(0.2, 0.18, 0.17), 0.08)
	m_tree = _glow(Color(0.9, 0.6, 0.22), 1.6)
	m_leaf = _glow(Color(1.0, 0.9, 0.5), 1.6)


## A crunchy, low-res, triplanar textured material. `tex_scale` is
## texture repeats per metre.
func _mat(c: Color, tex_scale := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = noise_tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tex_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true  # the tree must read as a landmark from anywhere
	return m


func box(pos: Vector3, size: Vector3, mat: Material, rot_deg := Vector3.ZERO, grapple := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if grapple:
		body.add_to_group("grapple")
	add_child(body)
	return body


## A wooden grapple anchor.
func beam(pos: Vector3, size: Vector3, rot_deg := Vector3.ZERO) -> StaticBody3D:
	return box(pos, size, m_wood, rot_deg, true)


## Visual-only geometry, for things the player can never reach.
func deco(pos: Vector3, mesh: Mesh, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


## A volume that darkens Jeffrey's light gem while he stands in it.
func shadow_zone(pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.has_method("enter_shadow"):
			b.enter_shadow())
	area.body_exited.connect(func(b: Node3D) -> void:
		if b.has_method("exit_shadow"):
			b.exit_shadow())
	add_child(area)


func campfire(pos: Vector3, fire_name: String) -> Node3D:
	var fire := Campfire.new()
	fire.fire_name = fire_name
	fire.position = pos
	add_child(fire)
	campfires.append(fire)
	return fire


func enemy(kind: String, wps: Array[Vector3]) -> void:
	var e := Enemy.new()
	e.setup(kind, wps)
	e.position = wps[0]
	add_child(e)


# --- Section A: the Haunch (y = 0) -------------------------------------------

func _build_haunch() -> void:
	box(Vector3(0, -2, -20), Vector3(64, 4, 84), m_hide)
	# The tail, sloping away into the clouds behind the start.
	box(Vector3(0, -4.5, 34), Vector3(12, 3, 26), m_hide, Vector3(15, 0, 0))

	# Raised hide plates and boulders for cover.
	box(Vector3(-18, 0.6, 0), Vector3(8, 1.2, 10), m_plate, Vector3(0, 10, 0))
	box(Vector3(16, 0.8, -8), Vector3(10, 1.6, 7), m_plate, Vector3(0, -15, 0))
	box(Vector3(-8, 0.5, -40), Vector3(7, 1, 6), m_plate)
	box(Vector3(20, 1.0, -42), Vector3(6, 2, 9), m_plate)
	box(Vector3(-4, 1, -12), Vector3(3, 2, 2.5), m_ruin, Vector3(0, 20, 0))
	box(Vector3(8, 1.2, -30), Vector3(2.5, 2.4, 3), m_ruin)
	box(Vector3(-20, 1.5, -30), Vector3(4, 3, 3), m_ruin, Vector3(0, 30, 0))
	box(Vector3(24, 1.5, -18), Vector3(3, 3, 3), m_ruin, Vector3(0, 45, 0))

	# Lookout pillar by the start: the first, safe grapple.
	box(Vector3(10, 3, 4), Vector3(2, 6, 2), m_ruin)
	beam(Vector3(10, 6.2, 4), Vector3(3, 0.4, 3))

	# Ruined shrine, dark inside.
	box(Vector3(0, 2, -28), Vector3(10, 4, 0.8), m_ruin)
	box(Vector3(-5, 1.5, -24), Vector3(0.8, 3, 8), m_ruin)
	box(Vector3(5, 1, -22), Vector3(0.8, 2, 4), m_ruin)
	box(Vector3(-1.5, 4.2, -25.5), Vector3(7, 0.5, 5), m_ruin)
	beam(Vector3(-1.5, 4.65, -22.8), Vector3(6, 0.4, 0.4))
	shadow_zone(Vector3(-1, 1.5, -24.5), Vector3(8, 3, 6))

	campfire(Vector3(-3, 0, 12), "Tailbone Fire")

	# --- The climb to the Ribs, three ways up a 12 m cliff ---
	# 1. The obvious ramp on the left (guarded).
	box(Vector3(-27, 5.5, -45), Vector3(6, 1, 32.3), m_plate, Vector3(21.8, 0, 0))
	# 2. Wooden beams jutting from the cliff lip: grapple straight up.
	beam(Vector3(6, 11.7, -58.5), Vector3(1.4, 0.6, 3))
	beam(Vector3(-8, 11.7, -58.5), Vector3(1.4, 0.6, 3))
	# 3. A staircase of scale ridges along the face on the right.
	for i in 15:
		var top := 0.8 * (i + 1)
		box(Vector3(12 + i * 1.4, top - 0.25, -59.1), Vector3(1.5, 0.5, 1.8), m_bone)


# --- Section B: the Ribs (y = 12) --------------------------------------------

func _build_ribs() -> void:
	box(Vector3(0, 5, -110), Vector3(70, 14, 100), m_hide)

	# Rib arches. The middle two have wooden crossbeams you can grapple onto
	# and walk along for a view of the routes ahead.
	for z in [-78.0, -100.0, -122.0, -144.0]:
		var wooden: bool = z == -100.0 or z == -122.0
		for side in [-1.0, 1.0]:
			box(Vector3(22 * side, 20, z), Vector3(2.5, 16, 2.5), m_bone)
			box(Vector3(17 * side, 26.5, z), Vector3(8, 1.5, 2), m_bone, Vector3(0, 0, 25 * side))
		if wooden:
			beam(Vector3(0, 29, z), Vector3(47, 2, 2.5))
		else:
			box(Vector3(0, 29, z), Vector3(47, 2, 2.5), m_bone)

	# A thicket of bone spurs for cover.
	var spurs := [
		Vector2(4, -104), Vector2(7, -108), Vector2(11, -103), Vector2(5, -113),
		Vector2(10, -115), Vector2(14, -110), Vector2(2, -118), Vector2(13, -119),
	]
	for i in spurs.size():
		var p: Vector2 = spurs[i]
		var h := 3.5 + (i % 3) * 0.8
		box(Vector3(p.x, 12 + h * 0.5, p.y), Vector3(0.8, h, 0.8), m_bone, Vector3(0, i * 17, 0))

	# Low folds of hide to crouch behind.
	box(Vector3(-10, 12.6, -90), Vector3(14, 1.2, 1.2), m_plate)
	box(Vector3(12, 12.6, -132), Vector3(16, 1.2, 1.2), m_plate)
	box(Vector3(-6, 12.6, -138), Vector3(10, 1.2, 1.2), m_plate)

	# A scale overhang with deep shadow beneath.
	box(Vector3(15, 16, -86), Vector3(12, 0.8, 10), m_plate, Vector3(0, 0, -4))
	box(Vector3(10, 14, -82), Vector3(1, 4, 1), m_bone)
	box(Vector3(20, 14, -90), Vector3(1, 4, 1), m_bone)
	shadow_zone(Vector3(15, 13.8, -86), Vector3(11, 3.6, 9))

	# Alcove with the second fire, tucked against the left flank.
	box(Vector3(-33, 14.5, -112), Vector3(1, 5, 8), m_ruin)
	box(Vector3(-29.5, 14.5, -116), Vector3(8, 5, 1), m_ruin)
	box(Vector3(-29.5, 14.5, -108), Vector3(8, 5, 1), m_ruin)
	box(Vector3(-29.5, 17.2, -112), Vector3(8, 0.5, 9), m_ruin)
	campfire(Vector3(-30, 12, -112), "Rib Hollow")

	# --- The climb to the Shoulder, 20 m ---
	# 1. Long ramp up the left flank, onto a landing.
	box(Vector3(-30, 21.55, -144), Vector3(6, 1, 37.7), m_plate, Vector3(32, 0, 0))
	box(Vector3(-30, 31.5, -166), Vector3(8, 1, 12), m_plate)
	# 2. Grapple chain: a wooden ledge halfway, then a beam at the lip.
	beam(Vector3(8, 21.5, -158), Vector3(8, 1, 4))
	beam(Vector3(15, 31.7, -159), Vector3(1.4, 0.6, 2))
	beam(Vector3(-2, 31.7, -159), Vector3(1.4, 0.6, 2))


# --- Section C: the Shoulder (y = 32) ----------------------------------------

func _build_shoulder() -> void:
	box(Vector3(0, 21, -205), Vector3(52, 22, 90), m_hide)
	box(Vector3(-14, 33, -190), Vector3(4, 2, 3), m_ruin, Vector3(0, 25, 0))
	box(Vector3(18, 33.2, -200), Vector3(3, 2.4, 4), m_ruin)
	box(Vector3(-8, 32.6, -238), Vector3(10, 1.2, 1.2), m_plate)
	box(Vector3(12, 32.6, -242), Vector3(8, 1.2, 1.2), m_plate, Vector3(0, -20, 0))
	campfire(Vector3(16, 32, -172), "Shoulder Watch")


func _build_tree() -> void:
	var base := Vector3(0, 32, -222)
	var trunk_h := 75.0
	var trunk := StaticBody3D.new()
	trunk.position = base + Vector3(0, trunk_h * 0.5, 0)
	var tm := CylinderMesh.new()
	tm.top_radius = 2.2
	tm.bottom_radius = 4.5
	tm.height = trunk_h
	tm.radial_segments = 8
	var tmi := MeshInstance3D.new()
	tmi.mesh = tm
	tmi.material_override = m_tree
	trunk.add_child(tmi)
	var tcs := CollisionShape3D.new()
	var tshape := CylinderShape3D.new()
	tshape.radius = 4.0
	tshape.height = trunk_h
	tcs.shape = tshape
	trunk.add_child(tcs)
	add_child(trunk)

	# Roots clawing into the Colossus.
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var root := box(base + dir * 6.0 + Vector3.UP * 0.6, Vector3(1.6, 1.4, 7), m_tree)
		root.rotation = Vector3(0.18, atan2(dir.x, dir.z), 0)

	# Branches and a glowing canopy.
	for i in 5:
		var a := i * TAU / 5.0
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 1.4, 22)
		var b := deco(base + Vector3(cos(a) * 9, trunk_h - 8 - i * 3, sin(a) * 9), bm, m_tree)
		b.rotation = Vector3(-0.35, atan2(cos(a), sin(a)), 0)
	var canopy := [
		[Vector3(0, trunk_h + 10, 0), 22.0], [Vector3(16, trunk_h + 2, 6), 14.0],
		[Vector3(-15, trunk_h + 4, -8), 15.0], [Vector3(4, trunk_h + 2, -18), 13.0],
		[Vector3(-6, trunk_h + 1, 16), 12.0],
	]
	for c in canopy:
		var sm := SphereMesh.new()
		sm.radius = c[1]
		sm.height = c[1] * 1.6
		sm.radial_segments = 10
		sm.rings = 6
		deco(base + c[0], sm, m_leaf)

	var crown := OmniLight3D.new()
	crown.position = base + Vector3(0, trunk_h - 5, 0)
	crown.light_color = Color(1.0, 0.85, 0.5)
	crown.omni_range = 140.0
	crown.light_energy = 2.5
	crown.omni_attenuation = 1.6
	add_child(crown)
	var foot := OmniLight3D.new()
	foot.position = base + Vector3(0, 4, 0)
	foot.light_color = Color(1.0, 0.8, 0.4)
	foot.omni_range = 30.0
	foot.light_energy = 2.0
	add_child(foot)

	# Wooden scaffolding up the trunk, a hint of the mansion to come.
	beam(base + Vector3(0, 8, 6.5), Vector3(8, 0.5, 3))
	beam(base + Vector3(6.5, 16, 0), Vector3(3, 0.5, 8))
	beam(base + Vector3(0, 24, -6.5), Vector3(8, 0.5, 3))

	var goal := Area3D.new()
	goal.position = base + Vector3(0, 2, 0)
	goal.collision_layer = 0
	goal.collision_mask = 2
	var gcs := CollisionShape3D.new()
	var gshape := CylinderShape3D.new()
	gshape.radius = 9.0
	gshape.height = 6.0
	gcs.shape = gshape
	goal.add_child(gcs)
	goal.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player") and not goal_announced:
			goal_announced = true
			goal_reached.emit())
	add_child(goal)


# --- The rest of the Colossus, seen but never reached -----------------------

func _build_colossus_silhouette() -> void:
	# Neck and head beyond the shoulder (walkable, a dead end with a view).
	box(Vector3(0, 22, -265), Vector3(26, 16, 30), m_hide)
	box(Vector3(0, 12, -300), Vector3(30, 26, 40), m_dark)
	box(Vector3(-14, 34, -300), Vector3(3, 18, 3), m_bone, Vector3(-20, 0, 25))
	box(Vector3(14, 34, -300), Vector3(3, 18, 3), m_bone, Vector3(-20, 0, -25))

	var arm := BoxMesh.new()
	arm.size = Vector3(16, 90, 16)
	deco(Vector3(-56, -15, -190), arm, m_dark, Vector3(-10, 0, 14))
	deco(Vector3(56, -15, -190), arm, m_dark, Vector3(10, 0, -14))
	var leg := BoxMesh.new()
	leg.size = Vector3(18, 80, 18)
	deco(Vector3(-42, -40, 8), leg, m_dark, Vector3(8, 0, 6))
	deco(Vector3(42, -40, 8), leg, m_dark, Vector3(-8, 0, -6))

	# A sea of cloud far below.
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.8, 0.8, 0.82, 0.9)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	deco(Vector3(0, -45, -120), pm, cloud_mat)


# --- Enemies ----------------------------------------------------------------

func _spawn_enemies() -> void:
	# Wardens: always on watch.
	enemy("warden", [Vector3(-10, 0, -18), Vector3(12, 0, -18), Vector3(12, 0, -46), Vector3(-12, 0, -46)])
	enemy("warden", [Vector3(-27, 12, -66), Vector3(-10, 12, -70)])
	enemy("warden", [Vector3(0, 12, -90), Vector3(14, 12, -128), Vector3(-14, 12, -128)])
	enemy("warden", [Vector3(-30, 32, -166), Vector3(-14, 32, -176)])
	enemy("warden", [Vector3(-12, 32, -210), Vector3(12, 32, -210), Vector3(12, 32, -236), Vector3(-12, 32, -236)])
	# Hollows: only walk at night, faster, sharper, deadlier.
	enemy("hollow", [Vector3(-15, 0, -5), Vector3(15, 0, -50)])
	enemy("hollow", [Vector3(20, 0, 5), Vector3(-20, 0, -35), Vector3(0, 0, -55)])
	enemy("hollow", [Vector3(-10, 12, -100), Vector3(18, 12, -150), Vector3(-18, 12, -150)])
	enemy("hollow", [Vector3(25, 12, -70), Vector3(25, 12, -150)])
	enemy("hollow", [Vector3(0, 32, -180), Vector3(-15, 32, -228), Vector3(15, 32, -228)])
