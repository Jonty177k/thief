@tool
class_name JBDDoor
extends Node3D
## A hinged door. Use it to open or close; it swings away from you. A
## locked door only opens from a lever (or anything calling activate()).
## The origin is the bottom centre, so it drops into a Doorway block's
## opening; the hinge is on its left (-X) edge.

const WOOD := preload("res://addons/jbd_level_tools/materials/wood.tres")

@export var size := Vector2(1.3, 2.3):
	set(v):
		size = v
		_rebuild()
@export var thickness := 0.1:
	set(v):
		thickness = v
		_rebuild()
@export_range(10.0, 170.0) var open_angle := 100.0
@export var swing_time := 0.6
## Locked doors ignore the Interact button and say so.
@export var locked := false:
	set(v):
		locked = v
		_update_prompt()
@export var material: Material = WOOD:
	set(v):
		material = v
		_rebuild()

var is_open := false
var _hinge: Node3D
var _panel: AnimatableBody3D
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _use: Interactable
var _tween: Tween


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_use = Interactable.new()
	_use.interacted.connect(_on_used)
	_panel.add_child(_use)
	_update_prompt()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _hinge == null:
		_hinge = Node3D.new()
		add_child(_hinge, false, INTERNAL_MODE_BACK)
		_panel = AnimatableBody3D.new()
		# The hinge (its parent) does the moving, so follow the global transform.
		_panel.sync_to_physics = false
		_panel.collision_layer = 1
		_panel.collision_mask = 0
		_hinge.add_child(_panel)
		_mesh = MeshInstance3D.new()
		_panel.add_child(_mesh)
		_shape = CollisionShape3D.new()
		_panel.add_child(_shape)
	_hinge.position = Vector3(-size.x * 0.5, 0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x - 0.04, size.y - 0.02, thickness)
	_mesh.mesh = bm
	_mesh.material_override = material
	var box := BoxShape3D.new()
	box.size = bm.size
	_shape.shape = box
	_panel.position = Vector3(size.x * 0.5, size.y * 0.5, 0)


func _update_prompt() -> void:
	if _use:
		_use.prompt = "Locked" if locked else ("Close door" if is_open else "Open door")


func _on_used(by: Node) -> void:
	if locked:
		if by.has_signal("notice"):
			by.notice.emit("Locked. There must be a lever somewhere.")
		return
	set_open(not is_open, by)


## Levers call this: opens (or closes) regardless of the lock.
func activate(by: Node = null) -> void:
	set_open(not is_open, by)


func set_open(open: bool, by: Node = null) -> void:
	is_open = open
	var angle := 0.0
	if open:
		# Swing away from whoever opened it.
		var side := 1.0
		if by is Node3D:
			side = signf((by.global_position - global_position).dot(global_basis.z))
			if side == 0.0:
				side = 1.0
		angle = deg_to_rad(open_angle) * side
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_hinge, "rotation:y", angle, swing_time).set_trans(Tween.TRANS_SINE)
	_update_prompt()
