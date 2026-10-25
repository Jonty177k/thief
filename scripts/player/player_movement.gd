class_name PlayerMovement
extends Node
## Walking, running, crouching, jumping, falling, slopes, steps and ladders.
## Grounded and deliberate: Jeffrey builds up to speed and slows down over a
## few steps, steers only a little in the air, and never slides or sprints
## on his own. Everything moves through move_and_slide().

signal jumped
signal landed(fall_speed: float)
## Fired on each footfall, for sounds and noise. `loud` when running.
signal footstep(loud: bool)

@export_group("Speeds")
## Full stick or a key, in m/s. Partial stick deflection scales it down.
@export var walk_speed := 3.2
## While Run (L2 / Shift) is held.
@export var run_speed := 5.4
@export var crouch_speed := 1.6

@export_group("Acceleration")
## How quickly Jeffrey gets up to speed, in m/s².
@export var ground_acceleration := 14.0
## How quickly he slows down or turns around, in m/s².
@export var ground_deceleration := 18.0
## Steering in the air, as a fraction of ground acceleration.
@export_range(0.0, 1.0, 0.01) var air_acceleration_ratio := 0.25

@export_group("Jump and Gravity")
@export var gravity := 19.6
## Take-off speed. 6.0 at 19.6 m/s² gives a jump about 0.9 m high.
@export var jump_velocity := 6.0
## Grace period after walking off an edge in which a jump still works.
@export var coyote_time := 0.10
## A jump pressed this long before landing still happens on landing.
@export var jump_buffer := 0.12
@export var max_fall_speed := 45.0

@export_group("Slopes and Steps")
## Steeper than this, the ground is a wall and Jeffrey slides off it.
@export_range(10.0, 80.0, 1.0) var max_slope_degrees := 46.0
## How fast Jeffrey slides down ground steeper than that, in m/s.
@export var steep_slide_speed := 5.0
## Ledges up to this height are stepped onto without jumping. The capsule
## sits this far off the ground on a ray "leg" that rides up steps.
@export var step_height := 0.35
## Step height while crouched (the crouched capsule is shorter).
@export var crouch_step_height := 0.2
## Keeps Jeffrey glued to the ground over bumps and down slopes.
@export var floor_snap := 0.4

@export_group("Body and Crouch")
@export var standing_height := 1.8
@export var eye_height := 1.65
@export var crouch_height := 1.0
@export var capsule_radius := 0.35
## Toggle (press once) or hold-to-crouch.
@export var crouch_toggle := true
## How fast the capsule shrinks and grows, in m/s.
@export var crouch_transition_speed := 5.0

@export_group("Ladders")
@export var climb_speed := 2.2
## Sideways speed along a ladder.
@export var climb_strafe_speed := 1.0
## Push off when jumping away from a ladder, in m/s.
@export var ladder_jump_off := 3.5

@export_group("Falling")
## Fall speed (m/s) above which landing hurts. 13 is about a 4.3 m drop.
@export var fall_damage_threshold := 13.0
@export var fall_damage_per_speed := 9.0
## Metres between footsteps.
@export var stride := 1.1

var player: CharacterBody3D

var crouch_wanted := false
var crouching := false
## Blocked from standing up by something overhead.
var stand_blocked := false
var current_height := 1.8
var running := false
## Standing on ground steeper than max_slope_degrees.
var on_steep := false
## Feet on walkable ground this tick (the leg, not just the capsule).
var grounded := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_time := 0.0
var was_on_floor := true
var stride_distance := 0.0
## Last horizontal target speed, for the debug overlay.
var target_speed := 0.0

## Ladders Jeffrey is touching, and the one he is on.
var ladders: Array[Node3D] = []
var ladder: Node3D


func setup(p: CharacterBody3D) -> void:
	player = p
	current_height = standing_height
	player.floor_max_angle = deg_to_rad(max_slope_degrees)
	player.floor_snap_length = floor_snap
	player.floor_constant_speed = true
	player.floor_stop_on_slope = true
	player.floor_block_on_wall = true
	_apply_height()


func physics_update(delta: float) -> void:
	var inp: PlayerInput = player.input
	_update_crouch(delta)
	if ladder:
		_climb(delta)
		return
	_try_grab_ladder()
	if ladder:
		_climb(delta)
		return

	var on_floor := player.is_on_floor()
	# Only the capsule's rounded bottom on a ledge's corner, not the leg on
	# the ground: slip off rather than hang there.
	var slip := Vector3.ZERO
	if on_floor and not _leg_on_ground():
		on_floor = false
		var n := player.get_floor_normal()
		slip = Vector3(n.x, 0.0, n.z)
		slip = slip.normalized() if slip.length() > 0.05 else Vector3.ZERO
	var steep_dir := _steep_downhill() if on_floor else Vector3.ZERO
	on_steep = steep_dir != Vector3.ZERO
	if on_steep:
		on_floor = false  # too steep to stand, walk or jump on
	grounded = on_floor
	if on_floor:
		coyote_timer = coyote_time
		air_time = 0.0
	else:
		coyote_timer -= delta
		air_time += delta
	jump_buffer_timer = jump_buffer if inp.jump_pressed else jump_buffer_timer - delta

	if not on_floor:
		player.velocity.y = maxf(player.velocity.y - gravity * delta, -max_fall_speed)
	var jumping := false
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and player.can_jump():
		player.velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jumping = true
		jumped.emit()

	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if player.dash.active:
		horizontal = player.dash.current_velocity()
	else:
		var target := wish_velocity()
		if on_floor and not jumping:
			# Speed up at one rate, slow down or turn around at another.
			var speeding_up := target.length() > 0.01 and horizontal.dot(target) >= 0.0 and target.length() >= horizontal.length() - 0.01
			horizontal = horizontal.move_toward(target, (ground_acceleration if speeding_up else ground_deceleration) * delta)
		elif target.length() > 0.01:
			# A little steering, without bleeding off a running jump.
			var steered := horizontal.move_toward(target, ground_acceleration * air_acceleration_ratio * delta)
			if steered.length() < horizontal.length() and horizontal.dot(target) > 0.0:
				steered = steered.normalized() * horizontal.length()
			horizontal = steered
	if slip != Vector3.ZERO and horizontal.dot(slip) < 1.5:
		horizontal += slip * (1.5 - horizontal.dot(slip))
	if on_steep:
		# No walking up it; slide down it.
		var uphill := horizontal.dot(-steep_dir)
		if uphill > 0.0:
			horizontal += steep_dir * uphill
		horizontal = horizontal.move_toward(steep_dir * steep_slide_speed, gravity * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z

	var fall_speed := -player.velocity.y
	was_on_floor = on_floor
	var y_before := player.global_position.y
	# Snap down stairs and slopes, but never onto a ledge's corner.
	var leg_ok := _leg_on_ground()
	player.floor_snap_length = floor_snap if leg_ok else 0.0
	player.move_and_slide()
	if on_floor and not jumping and leg_ok and not _leg_on_ground():
		var drop := y_before - player.global_position.y
		if drop > 0.02:
			# Just walked off an edge and got snapped onto its corner: undo
			# that, and let him fall (or jump, within coyote time) from here.
			player.move_and_collide(Vector3.UP * drop)
			player.velocity.y = 0.0
	if player.is_on_floor() and not was_on_floor:
		landed.emit(fall_speed)
		_land(fall_speed)
	elif on_floor and player.is_on_floor() and player.global_position.y - y_before > 0.06:
		# The leg just rode up a step: let the view catch up smoothly.
		player.camera_rig.absorb_step(player.global_position.y - y_before)
	_count_steps(delta)


func _leg_on_ground() -> bool:
	var ray: RayCast3D = player.ground_ray
	ray.force_raycast_update()
	return ray.is_colliding() and player.global_position.y - ray.get_collision_point().y < _leg_length() + 0.1


## Horizontal downhill direction if the ground underfoot is too steep to
## stand on, otherwise zero. The leg ray always stands Jeffrey up, so the
## slope is read from the ground ray instead.
func _steep_downhill() -> Vector3:
	var ray: RayCast3D = player.ground_ray
	ray.force_raycast_update()
	if not ray.is_colliding():
		return Vector3.ZERO
	var n := ray.get_collision_normal()
	if n.y >= cos(deg_to_rad(max_slope_degrees)):
		return Vector3.ZERO
	var down := Vector3(n.x, 0.0, n.z)
	return down.normalized() if down.length() > 0.001 else Vector3.ZERO


## Where the stick (or keys) wants Jeffrey to go, in m/s, world space.
func wish_velocity() -> Vector3:
	var inp: PlayerInput = player.input
	var m := inp.move
	running = inp.run_held and not crouching and m.length() > 0.1 and player.can_run()
	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed
	speed *= player.speed_multiplier()
	target_speed = speed * m.length()
	var basis := player.global_basis
	var dir := basis.x * m.x + basis.z * m.y
	dir.y = 0.0
	return dir * speed


func is_moving() -> bool:
	return Vector2(player.velocity.x, player.velocity.z).length() > 0.3


# --- Crouch -----------------------------------------------------------------

func _update_crouch(delta: float) -> void:
	var inp: PlayerInput = player.input
	if crouch_toggle:
		if inp.crouch_pressed:
			crouch_wanted = not crouch_wanted
	else:
		crouch_wanted = inp.crouch_held
	if ladder:
		crouch_wanted = false
	var target := crouch_height if crouch_wanted else standing_height
	stand_blocked = false
	if target > current_height + 0.001 and not _room_for(target):
		stand_blocked = true
		target = current_height
	current_height = move_toward(current_height, target, crouch_transition_speed * delta)
	crouching = crouch_wanted or current_height < standing_height - 0.05
	_apply_height()


## The capsule rides on the ray leg, `leg` metres off the ground.
func _leg_length() -> float:
	return lerpf(crouch_step_height, step_height, inverse_lerp(crouch_height, standing_height, current_height))


func _apply_height() -> void:
	var leg := _leg_length()
	player.capsule.radius = capsule_radius
	player.capsule.height = maxf(current_height - leg, capsule_radius * 2.0)
	player.collider.position.y = leg + player.capsule.height * 0.5
	player.leg_shape.length = leg
	player.leg.position.y = leg


## Eye height for the capsule's current height.
func current_eye_height() -> float:
	return current_height - (standing_height - eye_height)


## Is there room for a capsule `height` tall where Jeffrey stands?
func _room_for(height: float) -> bool:
	var leg := _leg_length()
	var shape := CapsuleShape3D.new()
	shape.radius = capsule_radius - 0.02
	shape.height = maxf(height - leg - 0.04, shape.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), player.global_position + Vector3.UP * (leg + 0.02 + shape.height * 0.5))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- Ladders ----------------------------------------------------------------

func ladder_entered(l: Node3D) -> void:
	if not ladders.has(l):
		ladders.append(l)


func ladder_exited(l: Node3D) -> void:
	ladders.erase(l)
	if ladder == l:
		_let_go(Vector3.ZERO)


func _try_grab_ladder() -> void:
	if ladders.is_empty() or not player.can_climb():
		return
	var m: Vector2 = player.input.move
	if m.y > -0.3:
		return  # only when pushing forward
	var forward := -player.global_basis.z
	for l in ladders:
		var facing: float = forward.dot(l.out_direction())
		# Walk into it from below, or walk off a ledge over it from above.
		var from_above: bool = player.global_position.y > l.top_height() - 0.3
		var falling_past := not player.is_on_floor()
		if facing < -0.3 or ((from_above or falling_past) and facing > 0.3):
			ladder = l
			crouch_wanted = false
			player.velocity = Vector3.ZERO
			return


## Which way "forward" on the stick climbs: up while looking at the ladder
## (or up it), down while looking down or facing away from it.
func _climb_sign(out: Vector3) -> float:
	var sign := 1.0
	if player.camera_rig.pitch_degrees() < -35.0:
		sign = -1.0
	if (-player.global_basis.z).dot(out) > 0.2:
		sign = -sign
	return sign


func _climb(delta: float) -> void:
	var inp: PlayerInput = player.input
	var out: Vector3 = ladder.out_direction()
	var top: float = ladder.top_height()
	var feet := player.global_position.y
	if inp.jump_pressed:
		_let_go(out * ladder_jump_off + Vector3.UP * 2.0)
		return
	var up := -inp.move.y * _climb_sign(out)
	var side := out.cross(Vector3.UP).normalized()
	var near_top := feet > top - 0.3
	# How far out from the ladder's face Jeffrey's centre is.
	var off := (player.global_position - ladder.global_position).dot(out)
	var v: Vector3
	if near_top and up > 0.0:
		# Over the top: rise clear of the lip, then step onto the ledge.
		v = Vector3.UP * climb_speed + (-out * 2.5 if feet > top - 0.05 else Vector3.ZERO)
	elif up < 0.0 and off < capsule_radius + 0.01:
		# Coming down from the ledge: swing out over the ladder first.
		v = out * 1.5 + Vector3.UP * up * climb_speed * 0.3
	else:
		v = Vector3.UP * up * climb_speed + side * side.dot(player.global_basis.x * inp.move.x) * climb_strafe_speed
		v += -out * 0.6  # lean in so we stay on it
	player.velocity = v
	player.move_and_slide()
	if player.is_on_floor():
		if up < 0.0 and player.global_position.y < ladder.global_position.y + 0.3:
			_let_go(Vector3.ZERO)  # reached the bottom
		elif up > 0.0 and player.global_position.y > top - 0.05:
			_let_go(-out * 1.0)  # stepped off at the top
	_count_steps(delta)


func _let_go(push: Vector3) -> void:
	ladder = null
	player.velocity = push


func _count_steps(delta: float) -> void:
	if not (player.is_on_floor() or ladder):
		return
	var speed := player.velocity.length() if ladder else Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.5:
		return
	var before := stride_distance
	stride_distance += speed * delta
	if floorf(before / stride) != floorf(stride_distance / stride):
		footstep.emit(running)


func _land(fall_speed: float) -> void:
	if fall_speed > fall_damage_threshold:
		var info := DamageInfo.new()
		info.amount = (fall_speed - fall_damage_threshold) * fall_damage_per_speed
		info.kind = "fall"
		info.direction = Vector3.DOWN
		player.receive_damage(info)
