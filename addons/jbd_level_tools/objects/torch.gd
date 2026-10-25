@tool
class_name JBDTorch
extends Node3D
## A flickering torch. Mount it on a wall (bracket sticks out along -Z)
## or stand it on the ground. Tweak colour, range and flicker live in the
## Inspector. Torches join the "light_source" group with a `light_radius`
## so stealth code can count them as light.

enum Style { WALL, STANDING, NONE }

@export var style := Style.WALL:
	set(v):
		style = v
		_queue_rebuild()
@export var lit := true:
	set(v):
		lit = v
		_queue_rebuild()
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
@export_range(0.0, 1.0) var flicker := 0.35

var light_radius: float:
	get:
		return light_range if lit else 0.0

var _light: OmniLight3D
var _flame: MeshInstance3D
var _parts: Array[Node] = []
var _pending := false
var _t := 0.0


func _ready() -> void:
	add_to_group("light_source")
	_t = randf() * 10.0
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
			flame_pos = Vector3(0, 0.45, -0.3)
		Style.STANDING:
			_part(BoxMesh, Vector3(0.12, 1.6, 0.12), Vector3(0, 0.8, 0), wood)
			_part(BoxMesh, Vector3(0.28, 0.12, 0.28), Vector3(0, 1.6, 0), iron)
			flame_pos = Vector3(0, 1.8, 0)
		Style.NONE:
			pass
	if lit:
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = color
		fmat.emission_enabled = true
		fmat.emission = color
		fmat.emission_energy_multiplier = 4.0
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame = _part(PrismMesh, Vector3(0.2, 0.35, 0.2), flame_pos, fmat)
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.light_energy = energy
		_light.omni_range = light_range
		_light.shadow_enabled = shadows
		_light.position = flame_pos + Vector3(0, 0.2, 0)
		add_child(_light, false, INTERNAL_MODE_BACK)
		_parts.append(_light)
	else:
		_flame = null
		_light = null


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


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	var f := (sin(_t * 11.0) * 0.6 + sin(_t * 23.0 + 1.3) * 0.4) * flicker
	_light.light_energy = energy * (1.0 + f * 0.6)
	_flame.scale = Vector3(1.0, 1.0 + f * 0.5, 1.0)
