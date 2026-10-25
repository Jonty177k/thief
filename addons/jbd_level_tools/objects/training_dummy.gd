@tool
class_name JBDTrainingDummy
extends StaticBody3D
## A straw dummy to hit. Shows its health and what the last blow did,
## wobbles with knockback, and stands back up a few seconds after it breaks.

@export var max_health := 100.0
@export var respawn_time := 3.0

var health := 100.0
var broken := false
var visual: Node3D
var _label: Label3D
var _body_mat: StandardMaterial3D
var _wobble := Vector3.ZERO
var _wobble_vel := Vector3.ZERO
var _last := ""
var _last_timer := 0.0

const STRAW := Color(0.62, 0.52, 0.3)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	health = max_health
	_build()


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.8, 0.5)
	shape.shape = box
	shape.position.y = 0.9
	add_child(shape, false, INTERNAL_MODE_BACK)
	visual = Node3D.new()
	add_child(visual, false, INTERNAL_MODE_BACK)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = STRAW
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.24, 0.14)
	_part(Vector3(0.12, 0.9, 0.12), Vector3(0, 0.45, 0), wood)
	_part(Vector3(0.6, 0.75, 0.4), Vector3(0, 1.2, 0), _body_mat)
	_part(Vector3(0.32, 0.32, 0.32), Vector3(0, 1.75, 0), _body_mat)
	_part(Vector3(1.1, 0.1, 0.1), Vector3(0, 1.4, 0), wood)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = 2.35
	add_child(_label, false, INTERNAL_MODE_BACK)
	_update_label()


func _part(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	visual.add_child(m)
	return m


## The damage interface (see DamageInfo).
func receive_damage(info: DamageInfo) -> void:
	if broken:
		return
	health -= info.amount
	_wobble_vel += Vector3(info.direction.z, 0, -info.direction.x) * info.knockback * -0.25
	_body_mat.albedo_color = Color(1, 0.4, 0.3)
	create_tween().tween_property(_body_mat, "albedo_color", STRAW, 0.25)
	show_result("-%d %s" % [roundi(info.amount), info.kind.to_upper()])
	if health <= 0.0:
		_break()


func show_result(text: String) -> void:
	_last = text
	_last_timer = 1.5
	_update_label()


func _break() -> void:
	broken = true
	health = 0.0
	create_tween().tween_property(visual, "rotation_degrees:x", -80.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	health = max_health
	broken = false
	create_tween().tween_property(visual, "rotation_degrees:x", 0.0, 0.5)
	_update_label()


func _update_label() -> void:
	_label.text = "%d / %d%s" % [ceili(health), roundi(max_health), "\n" + _last if _last != "" else ""]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or broken:
		return
	# A springy wobble from knockback.
	_wobble_vel += (-_wobble * 60.0 - _wobble_vel * 6.0) * delta
	_wobble += _wobble_vel * delta
	visual.rotation = _wobble
	if _last_timer > 0.0:
		_last_timer -= delta
		if _last_timer <= 0.0:
			_last = ""
			_update_label()
