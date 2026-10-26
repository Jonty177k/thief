@tool
class_name JBDTorch
extends Node3D
## A flickering torch. Mount it on a wall (bracket sticks out along -Z)
## or stand it on the ground. Tweak colour, range and flicker live in the
## Inspector. Its flame is a FlameComponent: a fire arrow lights it, a
## water arrow puts it out (and its light really goes off), and while lit
## it counts as light for Jeffrey's light gem. A small hit box round the
## flame (physics layer 5, "elemental") lets arrows find it.

signal lit_changed(lit: bool)

enum Style { WALL, STANDING, NONE }

const ELEMENTAL_LAYER := 16

@export var style := Style.WALL:
	set(v):
		style = v
		_queue_rebuild()
@export var lit := true:
	set(v):
		lit = v
		if _flame and _flame.lit != v:
			_flame.lit = v
@export var color := Color(1.0, 0.62, 0.3):
	set(v):
		color = v
		_queue_rebuild()
@export_range(0.0, 16.0, 0.1) var energy := 1.6:
	set(v):
		energy = v
		_queue_rebuild()
@export_range(1.0, 40.0, 0.5) var light_range := 9.0:
	set(v):
		light_range = v
		_queue_rebuild()
@export var shadows := true:
	set(v):
		shadows = v
		_queue_rebuild()
## 0 = steady, 1 = wild.
@export_range(0.0, 1.0) var flicker := 0.35:
	set(v):
		flicker = v
		if _flame:
			_flame.flicker = v
## Fire arrows can light it.
@export var can_ignite := true:
	set(v):
		can_ignite = v
		_queue_rebuild()
## Water arrows can put it out.
@export var can_extinguish := true:
	set(v):
		can_extinguish = v
		_queue_rebuild()

var light_radius: float:
	get:
		return light_range if lit else 0.0

var _flame: FlameComponent
var _parts: Array[Node] = []
var _pending := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for p in _parts:
		p.queue_free()
	_parts.clear()
	var wood := preload("res://addons/jbd_level_tools/materials/wood.tres")
	var iron := preload("res://addons/jbd_level_tools/materials/iron.tres")
	var flame_pos := Vector3.ZERO
	match style:
		Style.WALL:
			_part(BoxMesh, Vector3(0.12, 0.3, 0.06), Vector3(0, 0, 0), iron)
			var stick := _part(BoxMesh, Vector3(0.08, 0.5, 0.08), Vector3(0, 0.15, -0.18), wood)
			stick.rotation.x = -0.45
			flame_pos = Vector3(0, 0.38, -0.29)
		Style.STANDING:
			_part(BoxMesh, Vector3(0.12, 1.6, 0.12), Vector3(0, 0.8, 0), wood)
			_part(BoxMesh, Vector3(0.28, 0.12, 0.28), Vector3(0, 1.6, 0), iron)
			flame_pos = Vector3(0, 1.66, 0)
		Style.NONE:
			pass
	# A charred head that shows when the torch is out.
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.08, 0.07, 0.06)
	_part(BoxMesh, Vector3(0.12, 0.12, 0.12), flame_pos, soot)

	_flame = FlameComponent.new()
	_flame.color = color
	_flame.energy = energy
	_flame.light_range = light_range
	_flame.shadows = shadows
	_flame.flicker = flicker
	_flame.can_ignite = can_ignite
	_flame.can_extinguish = can_extinguish
	_flame.lit = lit
	_flame.position = flame_pos + Vector3(0, 0.05, 0)
	add_child(_flame, false, INTERNAL_MODE_BACK)
	_parts.append(_flame)
	_flame.lit_changed.connect(func(on: bool) -> void:
		lit = on
		lit_changed.emit(on))

	# Arrows find the torch through this.
	var body := StaticBody3D.new()
	body.collision_layer = ELEMENTAL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.6, 0.45)
	shape.shape = box
	body.add_child(shape)
	body.position = flame_pos + Vector3(0, 0.1, 0)
	add_child(body, false, INTERNAL_MODE_BACK)
	_parts.append(body)


func _part(kind, part_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m: PrimitiveMesh = kind.new()
	m.size = part_size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi, false, INTERNAL_MODE_BACK)
	_parts.append(mi)
	return mi


## The torch's flame (for the elemental interface and tests).
func flame() -> FlameComponent:
	return _flame


## The elemental interface: handed straight to the flame.
func receive_element(effect: ElementalEffect) -> bool:
	return _flame != null and _flame.receive_element(effect)
