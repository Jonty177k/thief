class_name Interactable
extends Node
## Makes its parent usable with the Interact button (E / Square). Add it as
## a child of a door, lever, pickup, campfire... and connect `interacted`,
## or extend it and override `interact()`. The player finds it by looking
## at the parent's collider, so the parent (or a child of the parent) needs
## a collision shape on a layer the interaction ray sees.

signal interacted(by: Node)

## What the on-screen prompt says, e.g. "Open door".
@export var prompt := "Use"
@export var enabled := true


func get_prompt() -> String:
	return prompt


func interact(by: Node) -> void:
	if enabled:
		interacted.emit(by)


## The Interactable that belongs to `hit`: `hit` itself, a child of it, or
## the same on one of its ancestors (up to four levels).
static func find(hit: Node) -> Interactable:
	var n := hit
	for i in 5:
		if n == null or not is_instance_valid(n):
			return null
		if n is Interactable:
			return n
		for c in n.get_children():
			if c is Interactable:
				return c
		n = n.get_parent()
	return null
