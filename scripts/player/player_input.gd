class_name PlayerInput
extends Node
## Reads the Input Map once per physics tick and holds the results, so the
## other components never touch Input directly. Bindings live in
## Project Settings > Input Map (written by tools/write_input_map.gd).

## Below this the left stick counts as centred. Keys always give full speed.
@export_range(0.0, 0.5, 0.01) var move_deadzone := 0.15

## Analog movement, -1..1 per axis. x is right, y is back (forward is -y).
## Partial stick deflection gives a shorter vector, so slower movement.
var move := Vector2.ZERO
## Raw right stick, -1..1 per axis. The camera applies deadzone and curve.
var look_stick := Vector2.ZERO
var run_held := false
var block_held := false
var crouch_held := false
var jump_pressed := false
var dash_pressed := false
var light_pressed := false
var heavy_pressed := false
var interact_pressed := false
var crouch_pressed := false
## True when the last thing touched was a controller (for button prompts).
var using_gamepad := false
## Off while a menu is open or Jeffrey is dead.
var enabled := true


func poll() -> void:
	if not enabled:
		clear()
		return
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back", move_deadzone)
	look_stick = Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.0)
	run_held = Input.is_action_pressed("run")
	block_held = Input.is_action_pressed("block")
	crouch_held = Input.is_action_pressed("crouch")
	jump_pressed = Input.is_action_just_pressed("jump")
	dash_pressed = Input.is_action_just_pressed("dash")
	light_pressed = Input.is_action_just_pressed("attack_light")
	heavy_pressed = Input.is_action_just_pressed("attack_heavy")
	interact_pressed = Input.is_action_just_pressed("interact")
	crouch_pressed = Input.is_action_just_pressed("crouch")


func clear() -> void:
	move = Vector2.ZERO
	look_stick = Vector2.ZERO
	run_held = false
	block_held = false
	crouch_held = false
	jump_pressed = false
	dash_pressed = false
	light_pressed = false
	heavy_pressed = false
	interact_pressed = false
	crouch_pressed = false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		using_gamepad = false


## The button to show in a prompt for `action`, on the device in use.
func glyph(action: String) -> String:
	if using_gamepad:
		return {"interact": "Square", "jump": "Cross", "dash": "Circle", "crouch": "Triangle", "block": "L1",
			"run": "L2", "attack_light": "R1", "attack_heavy": "R2"}.get(action, action)
	return {"interact": "E", "jump": "Space", "dash": "Alt", "crouch": "Ctrl", "block": "RMB",
		"run": "Shift", "attack_light": "LMB", "attack_heavy": "F"}.get(action, action)
