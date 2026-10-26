class_name PlayerCamera
extends Node3D
## Sits on the Head node: mouse and right-stick look, pitch limits, and the
## optional camera feel (head bob, dash lean, landing dip, step smoothing,
## shake). Look always works while Jeffrey is alive, including mid-attack
## and mid-dash, and the camera is never turned for you.

@export_group("Mouse")
## Degrees of turn per pixel of mouse movement.
@export_range(0.01, 1.0, 0.005) var mouse_sensitivity := 0.12
@export var invert_y := false

@export_group("Gamepad Look")
## Full right stick turns this many degrees per second.
@export var stick_yaw_speed := 200.0
@export var stick_pitch_speed := 140.0
## Right stick movement below this is ignored (drift).
@export_range(0.0, 0.5, 0.01) var stick_deadzone := 0.12
## 1 is linear. Higher gives finer aim near the centre of the stick.
@export_range(1.0, 3.0, 0.1) var stick_response_curve := 1.6
## How quickly stick look reaches its speed. Higher is snappier.
@export_range(1.0, 40.0, 0.5) var stick_smoothing := 14.0

@export_group("Limits")
@export_range(-89.0, 0.0) var pitch_min := -85.0
@export_range(0.0, 89.0) var pitch_max := 85.0
@export_range(50.0, 110.0) var fov := 75.0:
	set(v):
		fov = v
		if camera:
			camera.fov = v

@export_group("Feel")
## A subtle bob while walking. Keep it small: the camera should feel
## stable and grounded.
@export var head_bob_enabled := true
## Metres travelled per full bob cycle (two footsteps).
@export var bob_stride := 2.2
## Up-and-down movement at walking speed, in metres.
@export var bob_height := 0.025
## Side-to-side movement at walking speed, in metres.
@export var bob_sway := 0.012
## Extra bob while running (1 = same as walking).
@export var run_bob_multiplier := 1.3
## Crouch-walking bobs a little more, with shorter, heavier steps.
@export var crouch_bob_multiplier := 1.6
@export var crouch_bob_stride := 1.4
## Slight roll into the dash direction. Off by default.
@export var dash_lean_enabled := false
@export var dash_lean_degrees := 3.0
## Small dip when landing from a fall.
@export var landing_dip_enabled := true
@export var land_dip_threshold := 3.0
@export var land_dip_per_speed := 0.02
@export var land_dip_max := 0.2
## How quickly the view catches up after stepping up a stair.
@export var step_smoothing := 12.0

var player: CharacterBody3D
var camera: Camera3D

var _stick := Vector2.ZERO
var _bob_phase := 0.0
var _bob_weight := 0.0
var _land_dip := 0.0
var _step_offset := 0.0
var _lean := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0
## Mouse movement since the last frame (the viewmodel uses it for sway).
var look_delta := Vector2.ZERO


func setup(p: CharacterBody3D) -> void:
	player = p
	camera = get_node("Camera3D")
	camera.fov = fov
	camera.make_current()


func can_look() -> bool:
	return not player.dead and player.input.enabled


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player and can_look():
		var r: Vector2 = event.relative * deg_to_rad(mouse_sensitivity)
		look_delta += event.relative
		_turn(-r.x, -r.y * (-1.0 if invert_y else 1.0))


func _process(delta: float) -> void:
	if player == null:
		return
	var raw: Vector2 = player.input.look_stick if can_look() else Vector2.ZERO
	var target := Vector2.ZERO
	if raw.length() > stick_deadzone:
		var mag := inverse_lerp(stick_deadzone, 1.0, minf(raw.length(), 1.0))
		target = raw.normalized() * pow(mag, stick_response_curve)
	_stick = _stick.lerp(target, 1.0 - exp(-stick_smoothing * delta))
	if _stick.length() > 0.0001:
		_turn(-_stick.x * deg_to_rad(stick_yaw_speed) * delta,
			-_stick.y * deg_to_rad(stick_pitch_speed) * delta * (-1.0 if invert_y else 1.0))
	_update_feel(delta)


## Yaw turns the whole body; pitch tilts the head.
func _turn(yaw: float, pitch: float) -> void:
	player.rotate_y(yaw)
	rotation.x = clampf(rotation.x + pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))


func pitch_degrees() -> float:
	return rad_to_deg(rotation.x)


func set_pitch_degrees(d: float) -> void:
	rotation.x = deg_to_rad(clampf(d, pitch_min, pitch_max))


## The capsule just stepped up `amount` metres: keep the eye where it was
## and let it catch up smoothly.
func absorb_step(amount: float) -> void:
	_step_offset -= amount


func on_landed(fall_speed: float) -> void:
	if landing_dip_enabled and fall_speed > land_dip_threshold:
		_land_dip = minf(_land_dip + (fall_speed - land_dip_threshold) * land_dip_per_speed, land_dip_max)


func shake(duration: float, strength: float) -> void:
	_shake_time = maxf(_shake_time, duration)
	_shake_strength = maxf(_shake_strength, strength)


func _update_feel(delta: float) -> void:
	# Eye height follows the crouch.
	position.y = player.movement.current_eye_height()
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - exp(-step_smoothing * delta))
	_land_dip = move_toward(_land_dip, 0.0, delta * 1.0)

	var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var crouched: bool = player.movement.crouching
	var stride := crouch_bob_stride if crouched else bob_stride
	var bob_target := 0.0
	if head_bob_enabled and player.is_on_floor() and ground_speed > 0.3 and not player.dash.active:
		# Full bob at the gait's own speed, so a slow crouch-walk still bobs.
		var gait_speed: float = player.movement.crouch_speed if crouched else player.movement.walk_speed
		bob_target = clampf(ground_speed / gait_speed, 0.0, 1.0)
		if crouched:
			bob_target *= crouch_bob_multiplier
		elif player.movement.running:
			bob_target *= lerpf(1.0, run_bob_multiplier, clampf((ground_speed - player.movement.walk_speed) / (player.movement.run_speed - player.movement.walk_speed), 0.0, 1.0))
	_bob_weight = lerpf(_bob_weight, bob_target, 1.0 - exp(-8.0 * delta))
	# Advance the phase rather than store distance, so changing stride
	# (crouching mid-step) doesn't jump the camera.
	_bob_phase = fmod(_bob_phase + ground_speed * delta / stride * TAU, TAU * 1000.0)
	var bob := Vector2(sin(_bob_phase) * bob_sway, -absf(sin(_bob_phase)) * bob_height) * _bob_weight

	var lean_target := 0.0
	if dash_lean_enabled and player.dash.active:
		lean_target = -player.dash.direction.dot(player.global_basis.x) * dash_lean_degrees
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-14.0 * delta))

	var shake_offset := Vector2.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		_shake_strength = 0.0

	camera.position = Vector3(bob.x, bob.y - _land_dip + _step_offset, 0.0)
	camera.h_offset = shake_offset.x
	camera.v_offset = shake_offset.y
	camera.rotation.z = deg_to_rad(_lean)


## Current bob offset, so the viewmodel can counter it.
func bob_offset() -> Vector3:
	return Vector3(camera.position.x, camera.position.y + _land_dip - _step_offset, 0.0)
