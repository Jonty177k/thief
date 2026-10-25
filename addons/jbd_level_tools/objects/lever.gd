@tool
class_name JBDLever
extends StaticBody3D
## A floor lever. Use it to throw it; it calls activate() on Target (a
## door, or anything with that method).

const IRON := preload("res://addons/jbd_level_tools/materials/iron.tres")
const WOOD := preload("res://addons/jbd_level_tools/materials/wood.tres")

## The node to trigger, e.g. a Door.
@export var target: NodePath
## Once thrown, stays thrown.
@export var one_shot := false

var pulled := false
var _handle: Node3D
var _use: Interactable


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	_use = Interactable.new()
	_use.prompt = "Pull lever"
	_use.interacted.connect(_on_used)
	add_child(_use)


func _build() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.35, 0.35)
	base.mesh = bm
	base.material_override = IRON
	base.position.y = 0.175
	add_child(base, false, INTERNAL_MODE_BACK)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.1, 0.35)
	shape.shape = box
	shape.position.y = 0.55
	add_child(shape, false, INTERNAL_MODE_BACK)
	_handle = Node3D.new()
	_handle.position.y = 0.3
	_handle.rotation_degrees.x = -35
	add_child(_handle, false, INTERNAL_MODE_BACK)
	var stick := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.06, 0.8, 0.06)
	stick.mesh = sm
	stick.material_override = WOOD
	stick.position.y = 0.4
	_handle.add_child(stick)
	var knob := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.14, 0.14, 0.14)
	knob.mesh = km
	knob.material_override = IRON
	knob.position.y = 0.8
	_handle.add_child(knob)


func _on_used(by: Node) -> void:
	if one_shot and pulled:
		return
	pulled = not pulled
	create_tween().tween_property(_handle, "rotation_degrees:x", 35.0 if pulled else -35.0, 0.25)
	if one_shot:
		_use.enabled = false
	var t := get_node_or_null(target)
	if t and t.has_method("activate"):
		t.activate(by)
