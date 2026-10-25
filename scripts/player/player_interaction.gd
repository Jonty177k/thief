class_name PlayerInteraction
extends Node
## Square / E: use whatever the centre of the screen is on, within reach.
## Uses the InteractRay (a RayCast3D on the camera) and the Interactable
## component, so nothing about doors or levers lives in the player.

## Text for the on-screen prompt; empty when there's nothing to use.
signal prompt_changed(text: String)
signal used(target: Interactable)

## Reach from the eye, in metres.
@export var interaction_range := 2.2:
	set(v):
		interaction_range = v
		if ray:
			ray.target_position = Vector3(0, 0, -v)
## How long using something holds Jeffrey in the Interacting state.
@export var interact_time := 0.25

var player: CharacterBody3D
var ray: RayCast3D
var target: Interactable
var busy_timer := 0.0
var _prompt := ""


func setup(p: CharacterBody3D) -> void:
	player = p
	ray = p.get_node("Head/Camera3D/InteractRay")
	ray.target_position = Vector3(0, 0, -interaction_range)
	ray.add_exception(p)
	ray.enabled = true


func interacting() -> bool:
	return busy_timer > 0.0


func physics_update(delta: float) -> void:
	busy_timer = maxf(busy_timer - delta, 0.0)
	ray.force_raycast_update()
	var found: Interactable = null
	if ray.is_colliding():
		found = Interactable.find(ray.get_collider())
		if found and (not found.enabled or found.is_queued_for_deletion()):
			found = null
	target = found
	var text := ""
	if target and player.can_interact():
		text = "[%s] %s" % [player.input.glyph("interact"), target.get_prompt()]
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	if target and player.input.interact_pressed and player.can_interact():
		busy_timer = interact_time
		var used_target := target
		target = null  # it may free itself (pickups)
		used_target.interact(player)
		used.emit(used_target)
		_prompt = ""  # the prompt may change (Open -> Close); refresh next tick
