@tool
class_name JBDArrowSwitch
extends StaticBody3D
## A bullseye plate that an arrow (any kind) can trip. Mount it on a wall
## (the face points along -Z) or high up out of reach. When hit it calls
## activate() on Target, like a lever: a door, a gate, anything with that
## method. Reacts through the elemental interface, so swords don't trip it.

signal triggered(on: bool)

## The node to trigger, e.g. a Door.
@export var target: NodePath
## Once tripped, stays tripped.
@export var one_shot := false
@export var plate_size := 0.6:
	set(v):
		plate_size = v
		if is_inside_tree():
			_build()

var on := false
var _plate_mat: StandardMaterial3D
var _parts: Array[Node] = []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()


func _build() -> void:
	for p in _parts:
		p.queue_free()
	_parts.clear()
	var iron := preload("res://addons/jbd_level_tools/materials/iron.tres")
	var back := _box(Vector3(plate_size + 0.1, plate_size + 0.1, 0.08), Vector3(0, 0, -0.04), iron)
	_plate_mat = StandardMaterial3D.new()
	_plate_mat.albedo_color = Color(0.55, 0.12, 0.08)
	_plate_mat.emission_enabled = true
	_plate_mat.emission = Color(0.9, 0.7, 0.3)
	_plate_mat.emission_energy_multiplier = 0.0
	_box(Vector3(plate_size, plate_size, 0.06), Vector3(0, 0, -0.1), _plate_mat)
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.85, 0.8, 0.65)
	_box(Vector3(plate_size * 0.45, plate_size * 0.45, 0.07), Vector3(0, 0, -0.11), ring)
	_box(Vector3(plate_size * 0.18, plate_size * 0.18, 0.08), Vector3(0, 0, -0.12), _plate_mat)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(plate_size + 0.1, plate_size + 0.1, 0.18)
	shape.shape = box
	shape.position.z = -0.08
	add_child(shape, false, INTERNAL_MODE_BACK)
	_parts.append(shape)
	_update_look()


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	add_child(m, false, INTERNAL_MODE_BACK)
	_parts.append(m)
	return m


## The elemental interface: any arrow's knock trips it.
func receive_element(effect: ElementalEffect) -> bool:
	if effect.element != ElementalEffect.Element.PHYSICAL or Engine.is_editor_hint():
		return false
	if one_shot and on:
		return false
	on = not on
	_update_look()
	triggered.emit(on)
	var t := get_node_or_null(target)
	if t and t.has_method("activate"):
		t.activate(effect.source)
	return true


func _update_look() -> void:
	if _plate_mat:
		_plate_mat.emission_energy_multiplier = 1.5 if on else 0.0
