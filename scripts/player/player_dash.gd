class_name PlayerDash
extends Node
## Circle / Alt: the dodge. A quick, committed sidestep in the direction of
## the left stick, or backward if the stick is centred. It is a burst of
## velocity through move_and_slide, so walls and obstacles stop it; the
## camera stays yours and is never turned. It costs stamina, and Jeffrey
## is invulnerable only inside its i-frame window.

signal started(direction: Vector3)
signal finished

## How far one dash carries Jeffrey on flat ground, in metres.
@export var distance := 3.0
@export var duration := 0.22
## Time after a dash before the next one.
@export var recovery := 0.25
## 0 keeps a constant speed through the dash, 1 slows to a stop by the end.
@export_range(0.0, 1.0, 0.05) var falloff := 0.5
## Speed carried out of the dash (m/s), so it blends back into walking.
@export var exit_speed := 3.2
@export_group("Invincibility")
## Invulnerable from this many seconds after the dash starts...
@export var i_frame_start := 0.06
## ...until this many. Set both to 0 to turn i-frames off.
@export var i_frame_end := 0.2
@export_group("Rules")
@export var allow_in_air := false
## Lets a dash cut a light attack's recovery short.
@export var cancels_light_recovery := true

var active := false
var direction := Vector3.BACK
var time := 0.0
var recovery_timer := 0.0
var player: CharacterBody3D
var _velocity := Vector3.ZERO


func setup(p: CharacterBody3D) -> void:
	player = p


func available() -> bool:
	return not active and recovery_timer <= 0.0


func invulnerable() -> bool:
	return active and time >= i_frame_start and time < i_frame_end


## Called before movement each tick.
func physics_update(delta: float) -> void:
	if not active:
		recovery_timer = maxf(recovery_timer - delta, 0.0)
		if player.input.dash_pressed and player.can_dash():
			player.stamina.spend(player.stamina.dodge_cost)
			_start()
	if not active:
		return
	# Speed falls off linearly; the peak is chosen so the distance comes out
	# right. The last tick is shortened so it doesn't overshoot.
	var peak := distance / (duration * (1.0 - falloff * 0.5))
	var step := minf(delta, duration - time)
	var mid := (time + step * 0.5) / duration
	var speed := peak * (1.0 - falloff * mid) * (step / delta)
	_velocity = direction * speed
	time += delta
	if time >= duration - 0.0001:
		active = false
		recovery_timer = recovery
		_velocity = direction * minf(peak * (1.0 - falloff), exit_speed)
		# Hand the exit speed to movement on the next tick.
		player.velocity.x = _velocity.x
		player.velocity.z = _velocity.z
		finished.emit()


func current_velocity() -> Vector3:
	return _velocity


func _start() -> void:
	var m: Vector2 = player.input.move
	var basis := player.global_basis
	if m.length() < 0.2:
		direction = basis.z  # backward
	else:
		direction = basis.x * m.x + basis.z * m.y
	direction.y = 0.0
	direction = direction.normalized()
	active = true
	time = 0.0
	started.emit(direction)
