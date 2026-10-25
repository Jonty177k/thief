@tool
class_name JBDLevel
extends Node3D
## Root of a level built with the Level Tools. The game plays it when it's
## set as Main's Level Scene, or when you press Play Level in the dock.

signal goal_reached

@export var level_name := "Untitled level"
## Hour of day the level starts at when play-tested. -1 keeps the clock.
@export_range(-1.0, 23.9, 0.5) var start_hour := -1.0
## Shown when the level starts.
@export var intro_text := "Follow the tree."
## Give Jeffrey the grappling hook in this level.
@export var allow_grapple := true
## Start with the controller debug overlay showing (F3 toggles it).
@export var show_debug_overlay := false
## The Colossus takes the odd step and shakes the world.
@export var colossus_tremors := true

## Filled at runtime with every campfire in the level (Main wires them up).
var campfires: Array[Node3D] = []
var goal_announced := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for fire in get_tree().get_nodes_in_group("campfire"):
		if is_ancestor_of(fire):
			campfires.append(fire)


func reach_goal() -> void:
	if not goal_announced:
		goal_announced = true
		goal_reached.emit()
