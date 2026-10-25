class_name PlayerViewmodel
extends Node3D
## Placeholder first-person sword (lower right) and shield (lower left),
## built from boxes and posed in code. Replace with real models and an
## AnimationPlayer later: everything here reads the sword's phase and the
## shield's state, nothing drives gameplay.

## How much the hands lag behind mouse look.
@export var sway_amount := 0.6

const SWORD_REST := Vector3(0.36, -0.36, -0.6)
const SHIELD_REST := Vector3(-0.55, -0.48, -0.62)
const SHIELD_UP := Vector3(-0.24, -0.24, -0.5)

var player: CharacterBody3D
var sword_pivot: Node3D
var shield_pivot: Node3D
var _jolt := 0.0
var _sway := Vector3.ZERO


func setup(p: CharacterBody3D) -> void:
	player = p
	_build()
	player.shield.blocked.connect(func(_i: DamageInfo) -> void: _jolt = 1.0)


func _build() -> void:
	sword_pivot = Node3D.new()
	sword_pivot.name = "Sword"
	sword_pivot.position = SWORD_REST
	add_child(sword_pivot)
	_box(sword_pivot, Vector3(0.035, 0.55, 0.012), Vector3(0, 0.33, 0), Color(0.62, 0.62, 0.66))
	_box(sword_pivot, Vector3(0.18, 0.03, 0.04), Vector3(0, 0.05, 0), Color(0.35, 0.28, 0.18))
	_box(sword_pivot, Vector3(0.035, 0.14, 0.035), Vector3(0, -0.03, 0), Color(0.25, 0.16, 0.1))

	shield_pivot = Node3D.new()
	shield_pivot.name = "Shield"
	shield_pivot.position = SHIELD_REST
	add_child(shield_pivot)
	_box(shield_pivot, Vector3(0.28, 0.34, 0.03), Vector3.ZERO, Color(0.4, 0.3, 0.2))
	_box(shield_pivot, Vector3(0.1, 0.1, 0.05), Vector3(0, 0, -0.03), Color(0.5, 0.5, 0.52))
	shield_pivot.rotation_degrees = Vector3(0, 25, 0)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
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


func _process(delta: float) -> void:
	if player == null:
		return
	_pose_sword(delta)
	_pose_shield(delta)
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
	# Tuck the sword away while the shield is up.
	if player.shield.raised:
		sword_pivot.position = sword_pivot.position.lerp(SWORD_REST + Vector3(0.08, -0.12, 0.05), 0.5)


func _pose_shield(delta: float) -> void:
	var up: bool = player.shield.raised
	var target := SHIELD_UP if up else SHIELD_REST
	_jolt = move_toward(_jolt, 0.0, delta * 5.0)
	target += Vector3(0, 0.02, 0.12) * _jolt
	shield_pivot.position = shield_pivot.position.lerp(target, 1.0 - exp(-18.0 * delta))
	var yaw := 5.0 if up else 25.0
	shield_pivot.rotation_degrees = shield_pivot.rotation_degrees.lerp(Vector3(-8.0 * _jolt, yaw, 0), 1.0 - exp(-18.0 * delta))


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
