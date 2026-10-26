@tool
class_name Flammable
extends Node3D
## Makes its parent burnable. Put it under a crate, a hay bale, a curtain
## or an oil spill. Fire (a fire arrow, or a burning neighbour) sets it
## alight: a FlameComponent appears, lights the area, can spread to other
## Flammables nearby, can hurt whatever stands in it (a hazard), and burns
## out after Burn Time, optionally destroying its parent. Water puts it out.

signal ignited
signal extinguished
signal burned_out

## Seconds it burns before going out by itself. 0 burns forever.
@export var burn_time := 12.0
## Remove the parent when it burns out (a crate turning to ash).
@export var destroy_parent := false
## Fire jumps to other Flammables within this many metres...
@export var spread_radius := 2.5
## ...after burning this long.
@export var spread_delay := 2.0
@export_group("Hazard")
## Damage per second to anything that can be hurt within Hazard Radius.
@export var hazard_damage_per_second := 0.0
@export var hazard_radius := 1.2
@export_group("Flame")
@export var flame_color := Color(1.0, 0.55, 0.2)
@export var flame_size := Vector3(0.7, 0.9, 0.7)
@export_range(0.0, 16.0, 0.1) var flame_energy := 2.5
@export_range(1.0, 40.0, 0.5) var light_range := 8.0
## Extra reach for splash and burst effects, in metres.
@export var reach_radius := 0.8

var burning := false
var burnt := false
var burn_elapsed := 0.0
var flame: FlameComponent
var _spread_done := false


func _ready() -> void:
	add_to_group("elemental")
	add_to_group("flammable")


func receive_element(effect: ElementalEffect) -> bool:
	match effect.element:
		ElementalEffect.Element.FIRE:
			return ignite()
		ElementalEffect.Element.WATER:
			return extinguish()
	return false


func ignite() -> bool:
	if burning or burnt or Engine.is_editor_hint():
		return false
	burning = true
	burn_elapsed = 0.0
	_spread_done = false
	if flame == null:
		flame = FlameComponent.new()
		flame.lit = false
		flame.color = flame_color
		flame.flame_size = flame_size
		flame.energy = flame_energy
		flame.light_range = light_range
		flame.flicker = 0.6
		# The Flammable handles elements for its own flame.
		flame.can_ignite = false
		flame.can_extinguish = false
		add_child(flame, false, INTERNAL_MODE_BACK)
	flame.ignite()
	Fx.embers(self, global_position + Vector3.UP * 0.3)
	ignited.emit()
	return true


func extinguish() -> bool:
	if not burning:
		return false
	burning = false
	flame.extinguish()
	extinguished.emit()
	return true


func _physics_process(delta: float) -> void:
	if not burning or Engine.is_editor_hint():
		return
	burn_elapsed += delta
	if not _spread_done and burn_elapsed >= spread_delay:
		_spread_done = true
		for f in get_tree().get_nodes_in_group("flammable"):
			if f != self and f.global_position.distance_to(global_position) <= spread_radius:
				f.ignite()
	if hazard_damage_per_second > 0.0:
		_hurt_nearby(delta)
	if burn_time > 0.0 and burn_elapsed >= burn_time:
		burning = false
		burnt = true
		flame.lit = false
		burned_out.emit()
		if destroy_parent and get_parent() != get_tree().current_scene:
			get_parent().queue_free()


func _hurt_nearby(delta: float) -> void:
	var shape := SphereShape3D.new()
	shape.radius = hazard_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.5)
	q.collision_mask = 2 | 4
	var done: Array[Node] = []
	for h in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var r := DamageInfo.find_receiver(h.collider)
		if r and not done.has(r):
			done.append(r)
			r.receive_damage(DamageInfo.make(hazard_damage_per_second * delta, null, global_position, (r as Node3D).global_position, 0.0, "fire"))
