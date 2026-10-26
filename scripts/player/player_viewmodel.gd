class_name PlayerViewmodel
extends Node3D
## Placeholder first-person weapons built from boxes and posed in code:
## sword (lower right) and shield (lower left), the bow, and whatever tool
## builds itself under `tool_group`. Replace with real models and an
## AnimationPlayer later: everything here reads the weapons' state,
## nothing drives gameplay.

## How much the hands lag behind mouse look.
@export var sway_amount := 0.6

const SWORD_REST := Vector3(0.36, -0.36, -0.6)
const SHIELD_REST := Vector3(-0.55, -0.48, -0.62)
const SHIELD_UP := Vector3(-0.2, -0.17, -0.48)
const SHIELD_BROKEN := Vector3(-0.7, -0.62, -0.5)
const BOW_REST := Vector3(-0.3, -0.3, -0.55)
const BOW_DRAWN := Vector3(-0.1, -0.13, -0.55)
## How far a weapon drops out of view while switching.
const LOWERED := Vector3(0.0, -0.5, 0.1)

var player: CharacterBody3D
var sword_pivot: Node3D
var shield_pivot: Node3D
var sword_group: Node3D
var bow_group: Node3D
## A tool (the hookshot) builds its model under here.
var tool_group: Node3D
var bow_pivot: Node3D
var _string_top: MeshInstance3D
var _string_bottom: MeshInstance3D
var _nocked: Node3D
var _nocked_tip: StandardMaterial3D
var _bow_kick := 0.0
var _jolt := 0.0
## Sword recoil: 1 on a hit, more off a wall.
var _recoil := 0.0
var _sway := Vector3.ZERO


func setup(p: CharacterBody3D) -> void:
	player = p
	_build()
	player.shield.blocked.connect(func(_i: DamageInfo) -> void: _jolt = 1.0)
	player.shield.guard_broken.connect(func(_i: DamageInfo) -> void: _jolt = 1.6)
	player.sword.hit_landed.connect(func(_t: Node, _i: DamageInfo) -> void: _recoil = 0.6)
	player.sword.hit_wall.connect(func(_p: Vector3) -> void: _recoil = 1.0)
	player.bow.fired.connect(func(_a: Arrow) -> void: _bow_kick = 1.0)


func _build() -> void:
	sword_group = Node3D.new()
	sword_group.name = "SwordAndShield"
	add_child(sword_group)
	bow_group = Node3D.new()
	bow_group.name = "Bow"
	add_child(bow_group)
	tool_group = Node3D.new()
	tool_group.name = "Tool"
	add_child(tool_group)

	sword_pivot = Node3D.new()
	sword_pivot.name = "Sword"
	sword_pivot.position = SWORD_REST
	sword_group.add_child(sword_pivot)
	_box(sword_pivot, Vector3(0.035, 0.55, 0.012), Vector3(0, 0.33, 0), Color(0.62, 0.62, 0.66))
	_box(sword_pivot, Vector3(0.18, 0.03, 0.04), Vector3(0, 0.05, 0), Color(0.35, 0.28, 0.18))
	_box(sword_pivot, Vector3(0.035, 0.14, 0.035), Vector3(0, -0.03, 0), Color(0.25, 0.16, 0.1))

	shield_pivot = Node3D.new()
	shield_pivot.name = "Shield"
	shield_pivot.position = SHIELD_REST
	sword_group.add_child(shield_pivot)
	_box(shield_pivot, Vector3(0.32, 0.4, 0.03), Vector3.ZERO, Color(0.4, 0.3, 0.2))
	_box(shield_pivot, Vector3(0.1, 0.1, 0.05), Vector3(0, 0, -0.03), Color(0.5, 0.5, 0.52))
	shield_pivot.rotation_degrees = Vector3(0, 25, 0)
	_build_bow()


## A short recurve held upright in the left hand; the string meets at a
## nock that pulls back as you draw.
func _build_bow() -> void:
	bow_pivot = Node3D.new()
	bow_pivot.position = BOW_REST
	bow_group.add_child(bow_pivot)
	var wood := Color(0.36, 0.24, 0.13)
	_box(bow_pivot, Vector3(0.06, 0.14, 0.05), Vector3.ZERO, Color(0.2, 0.13, 0.08))
	for side in [-1.0, 1.0]:
		var limb := _box(bow_pivot, Vector3(0.05, 0.3, 0.035), Vector3(0, side * 0.19, 0.035), wood)
		limb.rotation_degrees.x = side * -14.0
		var tip := _box(bow_pivot, Vector3(0.022, 0.07, 0.022), Vector3(0, side * 0.36, 0.055), wood)
		tip.rotation_degrees.x = side * 30.0
	_string_top = _box(bow_pivot, Vector3(0.004, 1.0, 0.004), Vector3.ZERO, Color(0.85, 0.82, 0.7))
	_string_bottom = _box(bow_pivot, Vector3(0.004, 1.0, 0.004), Vector3.ZERO, Color(0.85, 0.82, 0.7))
	_nocked = Node3D.new()
	bow_pivot.add_child(_nocked)
	_box(_nocked, Vector3(0.012, 0.012, 0.7), Vector3(0, 0, -0.35), Color(0.45, 0.33, 0.2))
	_nocked_tip = StandardMaterial3D.new()
	var tip_mesh := _box(_nocked, Vector3(0.03, 0.03, 0.06), Vector3(0, 0, -0.71), Color.WHITE)
	tip_mesh.material_override = _nocked_tip
	_box(_nocked, Vector3(0.004, 0.04, 0.1), Vector3(0, 0, -0.05), Color(0.8, 0.8, 0.75))


## Stretch a thin box `m` between `a` and `b` (in its parent's space).
func _segment(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.001)
	var y := d / length
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	m.transform = Transform3D(Basis(x, y * length, z), a + d * 0.5)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	parent.add_child(m)
	return m


func _process(delta: float) -> void:
	if player == null:
		return
	_pose_sword(delta)
	_pose_shield(delta)
	_pose_bow(delta)
	_show_loadout()
	# Hands trail the view a touch and counter the head bob.
	var rig: PlayerCamera = player.camera_rig
	var target := Vector3(-rig.look_delta.x, rig.look_delta.y, 0.0) * 0.0006 * sway_amount
	target -= rig.bob_offset() * 0.5 * sway_amount
	if player.dash.active:
		target -= player.global_basis.inverse() * player.dash.direction * 0.05
	target = target.clamp(Vector3(-0.08, -0.08, -0.08), Vector3(0.08, 0.08, 0.08))
	_sway = _sway.lerp(target, 1.0 - exp(-10.0 * delta))
	position = _sway
	rig.look_delta = Vector2.ZERO


func _pose_sword(delta: float) -> void:
	var sw: PlayerSword = player.sword
	var rest := Vector3(-20, 0, -12)
	var pos := SWORD_REST
	var rot := rest
	if sw.attacking():
		var t := sw.phase_progress()
		if sw.kind == "heavy":
			# Raise high, chop down hard, come back slowly.
			var high := Vector3(55, 10, -5)
			var low := Vector3(-95, -10, -20)
			match sw.phase:
				PlayerSword.Phase.WINDUP:
					rot = rest.lerp(high, _ease_out(t))
					pos = SWORD_REST + Vector3(-0.05, 0.12, 0.08) * _ease_out(t)
				PlayerSword.Phase.ACTIVE:
					rot = high.lerp(low, t)
					pos = SWORD_REST + Vector3(-0.15, 0.12 - 0.2 * t, -0.15 * t)
				PlayerSword.Phase.RECOVERY:
					rot = low.lerp(rest, _ease_in_out(t))
					pos = (SWORD_REST + Vector3(-0.15, -0.08, -0.15)).lerp(SWORD_REST, _ease_in_out(t))
		else:
			# Cut across; every other swing in a chain goes back the other way.
			var dir := 1.0 if sw.chain_index % 2 == 0 else -1.0
			var start := Vector3(-30, 60 * dir, -70 * dir)
			var finish := Vector3(-40, -60 * dir, -80 * dir)
			match sw.phase:
				PlayerSword.Phase.WINDUP:
					rot = rest.lerp(start, _ease_out(t))
				PlayerSword.Phase.ACTIVE:
					rot = start.lerp(finish, t)
					pos = SWORD_REST + Vector3(-0.35 * t * dir, 0.05, -0.1)
				PlayerSword.Phase.RECOVERY:
					rot = finish.lerp(rest, _ease_in_out(t))
					pos = (SWORD_REST + Vector3(-0.35 * dir, 0.05, -0.1)).lerp(SWORD_REST, _ease_in_out(t))
		sword_pivot.rotation_degrees = rot
		sword_pivot.position = pos
	else:
		sword_pivot.rotation_degrees = sword_pivot.rotation_degrees.lerp(rest, 1.0 - exp(-14.0 * delta))
		sword_pivot.position = sword_pivot.position.lerp(SWORD_REST, 1.0 - exp(-14.0 * delta))
	# Recoil: the blade jars back on impact.
	_recoil = move_toward(_recoil, 0.0, delta * 4.0)
	if _recoil > 0.0:
		sword_pivot.position += Vector3(0.03, 0.04, 0.08) * _recoil
		sword_pivot.rotation_degrees += Vector3(18, 0, 0) * _recoil
	# Hold a charged heavy at the top with a slight tremble.
	if sw.is_heavy() and sw.charge > 0.0 and sw.phase == PlayerSword.Phase.WINDUP:
		sword_pivot.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004 * sw.charge
	# Tuck the sword away while the shield is up.
	if player.shield.raised:
		sword_pivot.position = sword_pivot.position.lerp(SWORD_REST + Vector3(0.08, -0.12, 0.05), 0.5)


func _pose_shield(delta: float) -> void:
	var sh: PlayerShield = player.shield
	# Follows the real raise progress, so it's only fully up when it blocks.
	var up := _ease_in_out(sh.raise_progress)
	var target := SHIELD_REST.lerp(SHIELD_UP, up)
	var rot := Vector3(0, lerpf(25.0, 5.0, up), 0)
	if sh.guard_broken_now():
		target = SHIELD_BROKEN
		rot = Vector3(-35, 60, -25)
	_jolt = move_toward(_jolt, 0.0, delta * 5.0)
	target += Vector3(0, 0.02, 0.12) * minf(_jolt, 1.0)
	rot += Vector3(-8.0 * _jolt, 0, 0)
	shield_pivot.position = shield_pivot.position.lerp(target, 1.0 - exp(-24.0 * delta))
	shield_pivot.rotation_degrees = shield_pivot.rotation_degrees.lerp(rot, 1.0 - exp(-24.0 * delta))


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _pose_bow(delta: float) -> void:
	var bow: PlayerBow = player.bow
	var draw := bow.draw_amount()
	_bow_kick = move_toward(_bow_kick, 0.0, delta * 5.0)
	bow_pivot.position = bow_pivot.position.lerp(BOW_REST.lerp(BOW_DRAWN, minf(draw * 3.0, 1.0)), 1.0 - exp(-14.0 * delta))
	bow_pivot.position += Vector3(0, 0.01, 0.04) * _bow_kick
	var up := minf(draw * 3.0, 1.0)
	bow_pivot.rotation_degrees = Vector3(-4.0 * _bow_kick, lerpf(25.0, 20.0, up), lerpf(-35.0, -20.0, up))
	var nock := Vector3(0, 0, 0.1 + 0.22 * draw)
	_segment(_string_top, Vector3(0, 0.39, 0.075), nock)
	_segment(_string_bottom, Vector3(0, -0.39, 0.075), nock)
	_nocked.position = nock
	_nocked.visible = bow.nock_timer <= 0.0
	# Narrow the view a little as the draw comes up.
	var rig: PlayerCamera = player.camera_rig
	player.camera.fov = lerpf(player.camera.fov, rig.fov - bow.draw_zoom_degrees * draw, 1.0 - exp(-10.0 * delta))
	var c: Color = bow.current_type().color
	_nocked_tip.albedo_color = c
	_nocked_tip.emission_enabled = bow.current_type().element != ElementalEffect.Element.PHYSICAL
	_nocked_tip.emission = c
	# A slight tremble near full draw.
	if draw >= 1.0:
		bow_pivot.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0015


## Show the weapon in hand; while switching, drop the old one out of view
## and raise the new one.
func _show_loadout() -> void:
	var lo: PlayerLoadout = player.loadout
	var shown := lo.current
	var lower := 0.0
	if lo.switching():
		var t := lo.switch_progress()
		lower = t / 0.5 if t < 0.5 else 1.0 - (t - 0.5) / 0.5
	var groups := [sword_group, bow_group, tool_group]
	for i in groups.size():
		var g: Node3D = groups[i]
		g.visible = i == shown
		g.position = LOWERED * _ease_in_out(clampf(lower, 0.0, 1.0))
		g.rotation_degrees = Vector3(-25.0 * lower, 0, 0)
