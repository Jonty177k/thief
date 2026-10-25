@tool
class_name JBDLevelExit
extends Area3D
## Reaching this volume completes the level (the level's goal_reached
## signal fires). Only drawn in the editor.

@export var size := Vector3(6, 4, 6):
	set(v):
		size = v.max(Vector3(0.1, 0.1, 0.1))
		_rebuild()

var _shape: CollisionShape3D
var _preview: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_rebuild()
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(b: Node3D) -> void:
		if not b.is_in_group("player"):
			return
		var n := get_parent()
		while n and not n.has_method("reach_goal"):
			n = n.get_parent()
		if n:
			n.reach_goal())


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape, false, INTERNAL_MODE_BACK)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = size.y * 0.5
	if Engine.is_editor_hint():
		if _preview == null:
			_preview = MeshInstance3D.new()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_preview.material_override = mat
			add_child(_preview, false, INTERNAL_MODE_BACK)
		var bm := BoxMesh.new()
		bm.size = size
		_preview.mesh = bm
		_preview.position.y = size.y * 0.5
