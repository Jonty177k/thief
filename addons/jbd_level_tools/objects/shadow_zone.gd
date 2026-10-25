@tool
class_name JBDShadowZone
extends Area3D
## A volume of deep shadow: Jeffrey's light gem dims while he stands in it.
## Only drawn in the editor.

@export var size := Vector3(4, 3, 4):
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
		if b.has_method("enter_shadow"):
			b.enter_shadow())
	body_exited.connect(func(b: Node3D) -> void:
		if b.has_method("exit_shadow"):
			b.exit_shadow())


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
			mat.albedo_color = Color(0.1, 0.0, 0.3, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_preview.material_override = mat
			add_child(_preview, false, INTERNAL_MODE_BACK)
		var bm := BoxMesh.new()
		bm.size = size
		_preview.mesh = bm
		_preview.position.y = size.y * 0.5
