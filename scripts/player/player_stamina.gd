class_name PlayerStamina
extends Node
## Combat stamina. Attacks, dodges and blocked blows spend it; walking and
## running never do. It refills after a short pause. Blocking a blow that
## costs more than is left breaks Jeffrey's guard (see PlayerShield).

signal changed(value: float, max_value: float)
## A spend that couldn't be paid in full (for HUD feedback).
signal exhausted

@export var max_stamina := 100.0
@export_group("Costs")
@export var light_attack_cost := 15.0
@export var heavy_attack_cost := 30.0
@export var dodge_cost := 20.0
## Spent each time the shield catches a blow.
@export var block_cost := 20.0
@export_group("Regeneration")
## Per second, once the delay has passed.
@export var regen_per_second := 25.0
## Seconds after spending before stamina starts to refill.
@export var regen_delay := 0.75
@export_group("Rules")
## On (Elden Ring style): an attack or dodge may start with any stamina
## left, and takes it to zero. Off: it needs the full cost.
@export var allow_partial := true

var value := 100.0
var player: CharacterBody3D
var _delay := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p
	value = max_stamina


## Is there enough stamina to start something costing `cost`?
func can_afford(cost: float) -> bool:
	if cost <= 0.0:
		return true
	return value > 0.01 if allow_partial else value >= cost


## Take `cost` (clamped at zero). Returns false if it couldn't all be paid.
func spend(cost: float) -> bool:
	if cost <= 0.0:
		return true
	var paid := value >= cost
	value = maxf(value - cost, 0.0)
	_delay = regen_delay
	changed.emit(value, max_stamina)
	if not paid:
		exhausted.emit()
	return paid


func refill() -> void:
	value = max_stamina
	_delay = 0.0
	changed.emit(value, max_stamina)


func regenerating() -> bool:
	return _delay <= 0.0 and value < max_stamina


func physics_update(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		return
	if value < max_stamina:
		value = minf(value + regen_per_second * delta, max_stamina)
		changed.emit(value, max_stamina)
