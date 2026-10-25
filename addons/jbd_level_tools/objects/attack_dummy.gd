@tool
class_name JBDAttackDummy
extends JBDTrainingDummy
## A dummy that turns to face Jeffrey and swings a club at whatever is in
## front of it, with a clear windup (its eyes flare). Use it to test the
## shield: face it and block, then turn your back on it and block.

@export var attack_interval := 2.2
@export var windup := 0.6
@export var damage := 12.0
@export var reach := 2.6
## Width of its swing, in degrees.
@export var swing_arc := 100.0
@export var knockback := 4.0
## Only wakes up when Jeffrey is this close.
@export var notice_range := 7.0
@export var turn_to_face := true
@export var turn_speed := 120.0

var _arm: Node3D
var _eye_mat: StandardMaterial3D
var _timer := 1.0
var _winding := -1.0
var _player: Node3D


func _build() -> void:
	super._build()
	_arm = Node3D.new()
	_arm.position = Vector3(0.45, 1.45, 0)
	visual.add_child(_arm)
	var club := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.14, 0.14, 1.2)
	club.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.12)
	club.material_override = mat
	club.position = Vector3(0, 0, -0.6)
	_arm.add_child(club)
	_arm.rotation_degrees.x = -50
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(1, 0.3, 0.1)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1, 0.3, 0.1)
	for side in [-1.0, 1.0]:
		var eye := _part(Vector3(0.07, 0.05, 0.04), Vector3(side * 0.08, 1.78, -0.17), _eye_mat)
		eye.name = "Eye"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint() or broken:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null or _player.get("dead"):
		_winding = -1.0
		return
	var to_p := _player.global_position - global_position
	to_p.y = 0.0
	if to_p.length() > notice_range:
		_winding = -1.0
		_arm.rotation_degrees.x = -50
		return
	if turn_to_face and _winding < 0.0:
		var want := atan2(-to_p.x, -to_p.z)
		rotation.y = rotate_toward(rotation.y, want, deg_to_rad(turn_speed) * delta)
	if _winding >= 0.0:
		_winding += delta
		var t := clampf(_winding / windup, 0.0, 1.0)
		_arm.rotation_degrees.x = lerpf(-50.0, 70.0, t)
		_eye_mat.emission_energy_multiplier = 1.0 + t * 8.0
		if _winding >= windup:
			_strike()
		return
	_timer -= delta
	if _timer <= 0.0:
		_winding = 0.0


func _strike() -> void:
	_winding = -1.0
	_timer = attack_interval
	_eye_mat.emission_energy_multiplier = 1.0
	var tw := create_tween()
	tw.tween_property(_arm, "rotation_degrees:x", -90.0, 0.08)
	tw.tween_property(_arm, "rotation_degrees:x", -50.0, 0.4)
	var to_p := _player.global_position - global_position
	to_p.y = 0.0
	var forward := -global_basis.z
	if to_p.length() > reach or rad_to_deg(forward.angle_to(to_p.normalized())) > swing_arc * 0.5:
		show_result("MISS")
		return
	var info := DamageInfo.make(damage, self, global_position, _player.global_position, knockback, "dummy")
	_player.receive_damage(info)
	if info.blocked:
		show_result("BLOCKED")
		_timer += 0.8  # staggered by the shield
		_wobble_vel += Vector3(1.5, 0, 0)
	else:
		show_result("HIT %d" % roundi(damage))
