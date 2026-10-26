class_name Gamepad
extends Node
## Makes sure a PS5 DualSense (or PS4 DualShock) maps to the Input Map's
## layout: Cross = jump, Circle = dash, Square = interact, Triangle = crouch,
## L1/R1 shoulders, L2/R2 analog triggers.
##
## Godot already knows these controllers on Windows, macOS and Linux through
## its built-in SDL controller database, so usually there's nothing to do.
## If a Sony controller turns up that Godot doesn't recognise (a new USB or
## Bluetooth ID, a clone), this adds the DualSense's raw button layout for it,
## so the buttons still land in the right places.

signal connected(device: int, name: String)
signal disconnected(device: int)

## Sony's raw DirectInput / macOS HID layout, shared by the DualSense and
## the DualShock 4: Square b0, Cross b1, Circle b2, Triangle b3, L1 b4,
## R1 b5, Create b8, Options b9, L3 b10, R3 b11, PS b12, touchpad b13.
## Left stick a0/a1, right stick a2/a5, L2 a3, R2 a4, D-pad on the hat.
const SONY_LAYOUT := "a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,guide:b12,touchpad:b13," \
		+ "leftshoulder:b4,rightshoulder:b5,leftstick:b10,rightstick:b11," \
		+ "lefttrigger:a3,righttrigger:a4,leftx:a0,lefty:a1,rightx:a2,righty:a5," \
		+ "dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8"

## Bluetooth and USB names a Sony pad reports, lower case.
const SONY_NAMES := ["dualsense", "ps5", "ps4", "dualshock", "wireless controller", "sony"]


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for d in Input.get_connected_joypads():
		ensure_mapped(d)


func _on_joy_connection_changed(device: int, is_connected: bool) -> void:
	if is_connected:
		ensure_mapped(device)
		connected.emit(device, Input.get_joy_name(device))
	else:
		disconnected.emit(device)


static func is_playstation(device: int) -> bool:
	return is_sony_name(Input.get_joy_name(device))


static func is_sony_name(joy_name: String) -> bool:
	var n := joy_name.to_lower()
	for s in SONY_NAMES:
		if n.contains(s):
			return true
	return false


## The SDL mapping line for a Sony pad with this GUID.
static func sony_mapping(guid: String, joy_name: String) -> String:
	var platform := "Mac OS X" if OS.get_name() == "macOS" else OS.get_name()
	return "%s,%s,%s,platform:%s" % [guid, joy_name.replace(",", " "), SONY_LAYOUT, platform]


## Adds the Sony layout for this controller if Godot doesn't know it.
## Returns true if a mapping was added.
static func ensure_mapped(device: int) -> bool:
	if Input.is_joy_known(device):
		return false
	var joy_name := Input.get_joy_name(device)
	# Linux reports Sony pads through the kernel's own driver, already in
	# the standard layout and in Godot's database; the raw layout is for
	# Windows (DirectInput) and macOS.
	if not is_sony_name(joy_name) or OS.get_name() not in ["Windows", "macOS"]:
		return false
	Input.add_joy_mapping(sony_mapping(Input.get_joy_guid(device), joy_name), true)
	push_warning("Gamepad: added the DualSense layout for unrecognised controller '%s'." % joy_name)
	return true


## One line for the debug readout.
static func describe() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "no controller"
	var d: int = pads[0]
	return "%s (%s)" % [Input.get_joy_name(d), "mapped" if Input.is_joy_known(d) else "unknown layout"]
