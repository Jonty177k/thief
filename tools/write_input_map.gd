extends SceneTree
## Writes the game's Input Map into project.godot, so every binding can be
## changed later in Project Settings > Input Map.
##   godot --headless --path . --script res://tools/write_input_map.gd
## Joypad events use device -1 (any controller), so no device index is
## assumed. Godot reports a DualSense with SDL's layout: Cross = A,
## Circle = B, Square = X, Triangle = Y, L2/R2 = trigger axes.

const ACTIONS := {
	# name: [deadzone, keys, mouse buttons, joypad buttons, joypad axes [axis, sign]]
	"move_forward": [0.1, [KEY_W, KEY_UP], [], [], [[JOY_AXIS_LEFT_Y, -1.0]]],
	"move_back": [0.1, [KEY_S, KEY_DOWN], [], [], [[JOY_AXIS_LEFT_Y, 1.0]]],
	"move_left": [0.1, [KEY_A, KEY_LEFT], [], [], [[JOY_AXIS_LEFT_X, -1.0]]],
	"move_right": [0.1, [KEY_D, KEY_RIGHT], [], [], [[JOY_AXIS_LEFT_X, 1.0]]],
	"look_left": [0.05, [], [], [], [[JOY_AXIS_RIGHT_X, -1.0]]],
	"look_right": [0.05, [], [], [], [[JOY_AXIS_RIGHT_X, 1.0]]],
	"look_up": [0.05, [], [], [], [[JOY_AXIS_RIGHT_Y, -1.0]]],
	"look_down": [0.05, [], [], [], [[JOY_AXIS_RIGHT_Y, 1.0]]],
	"run": [0.3, [KEY_SHIFT], [], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]]],
	"block": [0.5, [], [MOUSE_BUTTON_RIGHT], [JOY_BUTTON_LEFT_SHOULDER], []],
	"attack_light": [0.5, [], [MOUSE_BUTTON_LEFT], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"attack_heavy": [0.4, [KEY_F], [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]],
	"jump": [0.5, [KEY_SPACE], [], [JOY_BUTTON_A], []],
	"dash": [0.5, [KEY_ALT], [], [JOY_BUTTON_B], []],
	"interact": [0.5, [KEY_E], [], [JOY_BUTTON_X], []],
	"crouch": [0.5, [KEY_CTRL, KEY_C], [], [JOY_BUTTON_Y], []],
	"grapple": [0.5, [KEY_G], [MOUSE_BUTTON_MIDDLE], [JOY_BUTTON_RIGHT_STICK], []],
	"rest_morning": [0.5, [KEY_1], [], [JOY_BUTTON_DPAD_UP], []],
	"rest_evening": [0.5, [KEY_2], [], [JOY_BUTTON_DPAD_DOWN], []],
	"toggle_help": [0.5, [KEY_H], [], [JOY_BUTTON_BACK], []],
	"toggle_debug": [0.5, [KEY_F3], [], [JOY_BUTTON_START], []],
	"toggle_fullscreen": [0.5, [KEY_F11], [], [], []],
	"free_mouse": [0.5, [KEY_ESCAPE], [], [], []],
	"debug_time": [0.5, [KEY_T], [], [], []],
}


func _init() -> void:
	for name in ACTIONS:
		var a: Array = ACTIONS[name]
		var events := []
		for k in a[1]:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = k
			events.append(ev)
		for b in a[2]:
			var ev := InputEventMouseButton.new()
			ev.device = -1
			ev.button_index = b
			events.append(ev)
		for b in a[3]:
			var ev := InputEventJoypadButton.new()
			ev.device = -1
			ev.button_index = b
			events.append(ev)
		for ax in a[4]:
			var ev := InputEventJoypadMotion.new()
			ev.device = -1
			ev.axis = ax[0]
			ev.axis_value = ax[1]
			events.append(ev)
		ProjectSettings.set_setting("input/" + name, {"deadzone": a[0], "events": events})
	# Old names from the first prototype.
	for old in ["sprint", "attack", "lean_left", "lean_right"]:
		if ProjectSettings.has_setting("input/" + old):
			ProjectSettings.set_setting("input/" + old, null)
	print("Input map written: ", ProjectSettings.save())
	quit()
