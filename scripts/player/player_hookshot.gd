class_name PlayerHookshot
extends Node
## The hookshot / wire gun: one tool, two modes. Equip it with D-pad down
## (3); L1 / RMB switches mode.
##
## HOOKSHOT: aim at a valid surface (anything in Valid Groups: the wooden
## beams and decks) and press R2 / LMB. The hook flies out on its cable; if
## it bites, Jeffrey is hauled toward it through move_and_slide, so walls
## stop him and he never clips or teleports. If something blocks the haul
## he stops where he is and gets control back. At the end he climbs onto
## the ledge if there's one within reach.
##
## WIRE: press R2 on a valid surface to set the first anchor, walk
## somewhere else, and press R2 on a second one. If the wire would be
## walkable (length, incline, a clear line, room for a body along it and
## footing at both ends) a taut wire is strung between them; if not, it
## says why. Look at either end and press Square / E to step onto it.
## On the wire: left stick forward walks toward the far end, back toward
## the near one, Cross jumps off, Circle steps off at an end (or drops).
##
## The tool never decides who hears it: it emits NoiseEvents (Game.emit_noise).

signal mode_changed(mode: Mode)
signal state_changed(state: State)
signal hook_fired(target: Vector3)
signal hook_connected(point: Vector3)
signal hook_failed(point: Vector3, reason: String)
signal pull_finished(arrived: bool)
signal anchor_placed(point: Vector3)
signal wire_created(wire: TightWire)
signal wire_rejected(reason: String)
signal wire_mounted(wire: TightWire)
signal wire_left(how: String)

enum Mode { HOOKSHOT, WIRE }
enum State { NORMAL, HOOK_FIRING, HOOK_PULLING, WIRE_PLACEMENT, WIRE_TRAVERSAL }
enum Aim { NONE, VALID, INVALID }

## How far from each anchor the wire may graze its own surface, in metres.
const ANCHOR_GRAZE := 0.6

@export_group("Hookshot")
@export var max_range := 20.0
## Haul speed, in m/s.
@export var pull_speed := 12.0
## Targets closer than this (from Jeffrey's middle) are refused.
@export var min_attach_distance := 2.0
## Jeffrey stops this far out from where the hook bit.
@export var arrival_offset := 1.0
@export var cooldown := 0.3
## How fast the hook flies out, in m/s.
@export var hook_speed := 60.0
## Seconds of slack before a haul that isn't arriving is given up.
@export var pull_grace := 0.75
## Climb onto a ledge at the end of a haul, if one is within reach.
@export var mantle_on_arrival := true
@export var mantle_height := 2.2

@export_group("Wire")
@export var max_wire_length := 25.0
@export var min_wire_length := 3.0
## Walking speed along a wire, in m/s.
@export var wire_speed := 1.5
@export_range(1, 8) var max_active_wires := 1
@export_range(0.0, 60.0) var max_incline_degrees := 30.0
## How far the wire gun can place an anchor.
@export var anchor_range := 20.0
## Seconds to step on or off a wire.
@export var mount_time := 0.35

@export_group("Surfaces")
## Hook and anchors bite only into members of these groups. Level Tools
## blocks with Grapple Anchor ticked (wooden beams, decks) are in "grapple".
@export var valid_groups: Array[String] = ["grapple", "hookshot"]

@export_group("Noise")
## A moderate mechanical bang.
@export var fire_noise_radius := 10.0
@export var connect_noise_radius := 6.0
@export var fail_noise_radius := 6.0
## Placing an anchor is quieter.
@export var anchor_noise_radius := 4.0
## Footsteps on a wire are very quiet.
@export var wire_step_noise_radius := 1.5
@export var wire_step_distance := 0.8

var player: CharacterBody3D
var mode := Mode.HOOKSHOT
var state := State.NORMAL
## What the crosshair is on, refreshed every tick while the tool is out.
var aim := Aim.NONE
var aim_hit := {}
var aim_reason := ""
var cooldown_timer := 0.0

# Hook
var hook_pos := Vector3.ZERO
var hook_target := Vector3.ZERO
var hook_normal := Vector3.UP
var hook_valid := false
var hook_reason := ""
var feet_target := Vector3.ZERO
var pull_dir := Vector3.ZERO
var pull_time := 0.0
var pull_limit := 1.0
var mantling := false
var _stuck_ticks := 0
var _mantle_top := 0.0
var _mantle_reach := 0.0
var _mantle_dir := Vector3.ZERO
var _mantle_time := 0.0
var _mantle_start := Vector3.ZERO

# Wire
## The first anchor, while placing: {point, normal, collider}.
var pending_anchor := {}
var wires: Array[TightWire] = []
var wire: TightWire
var wire_s := 0.0
## +1 when forward on the stick walks from end A toward B.
var wire_forward_sign := 1.0
var _mount_t := 0.0
var _mount_from := Vector3.ZERO
var _dismount_end := -1
var _dismount_from := Vector3.ZERO
var _step_acc := 0.0

# Visuals
var gun: Node3D
var muzzle: Node3D
var _gun_hook: Node3D
var _hook: MeshInstance3D
var _cable: MeshInstance3D
var _anchor_marker: MeshInstance3D
var _preview: MeshInstance3D
var _preview_mat: StandardMaterial3D
var _sfx: AudioStreamPlayer


func setup(p: CharacterBody3D) -> void:
	player = p
	_build()


# --- Queries ------------------------------------------------------------------

## The tool is moving Jeffrey (hauling or on a wire).
func controls_movement() -> bool:
	return state == State.HOOK_PULLING or state == State.WIRE_TRAVERSAL


## Busy with something that shouldn't be interrupted by a weapon switch.
func busy() -> bool:
	return state in [State.HOOK_FIRING, State.HOOK_PULLING, State.WIRE_TRAVERSAL]


func equipped() -> bool:
	return player.loadout.is_ready(PlayerLoadout.Slot.TOOL)


func state_name() -> String:
	return State.keys()[state]


func mode_name() -> String:
	if mode == Mode.HOOKSHOT:
		return "Hook mode"
	return "Wire mode: aim at a second anchor" if not pending_anchor.is_empty() else "Wire mode"


func is_valid_surface(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false
	for g in valid_groups:
		if (collider as Node).is_in_group(g):
			return true
	return false


# --- Every tick ---------------------------------------------------------------

func physics_update(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if state == State.HOOK_FIRING:
		_fly_hook(delta)
	if not equipped():
		aim = Aim.NONE
		if state == State.WIRE_PLACEMENT:
			_clear_anchor()
		_update_visuals()
		return
	_update_aim()
	var inp: PlayerInput = player.input
	if state == State.NORMAL or state == State.WIRE_PLACEMENT:
		if inp.block_pressed:
			set_mode(Mode.WIRE if mode == Mode.HOOKSHOT else Mode.HOOKSHOT)
		elif (inp.heavy_pressed or inp.light_pressed) and cooldown_timer <= 0.0 and player.can_use_tool():
			if mode == Mode.HOOKSHOT:
				fire_hook()
			else:
				place_anchor()
	_update_visuals()


## Called by the player instead of normal movement while controls_movement().
func move(delta: float) -> void:
	if state == State.HOOK_PULLING:
		_pull(delta)
	elif state == State.WIRE_TRAVERSAL:
		_walk_wire(delta)


func set_mode(m: Mode) -> void:
	if m == mode:
		return
	mode = m
	_clear_anchor()
	_play(Sfx.anchor_tick(), -14.0)
	mode_changed.emit(m)


func cancel() -> void:
	if state == State.WIRE_TRAVERSAL:
		_leave("cancel")
	_clear_anchor()
	mantling = false
	_set_state(State.NORMAL)
	_update_visuals()


func _set_state(s: State) -> void:
	if s != state:
		state = s
		state_changed.emit(s)


func _update_aim() -> void:
	aim_hit = _ray(anchor_range if mode == Mode.WIRE else max_range)
	if aim_hit.is_empty():
		aim = Aim.NONE
		aim_reason = "Out of range"
		return
	if not is_valid_surface(aim_hit.collider):
		aim = Aim.INVALID
		aim_reason = "It won't bite there"
		return
	if mode == Mode.HOOKSHOT and aim_hit.position.distance_to(_middle()) < min_attach_distance:
		aim = Aim.INVALID
		aim_reason = "Too close"
		return
	if mode == Mode.WIRE and not pending_anchor.is_empty():
		var v := validate_wire(pending_anchor, _anchor_from(aim_hit))
		aim = Aim.VALID if v.ok else Aim.INVALID
		aim_reason = v.reason
		return
	aim = Aim.VALID
	aim_reason = ""


func _ray(reach: float) -> Dictionary:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _middle() -> Vector3:
	return player.global_position + Vector3.UP * 0.9


# --- Hookshot -----------------------------------------------------------------

## Fire at whatever the crosshair is on. The hook always flies; whether it
## bites is decided when it gets there.
func fire_hook() -> void:
	var cam: Camera3D = player.camera
	var hit := _ray(max_range)
	if hit.is_empty():
		hook_target = cam.global_position - cam.global_basis.z * max_range
		hook_normal = Vector3.UP
		hook_valid = false
		hook_reason = "Missed"
	else:
		hook_target = hit.position
		hook_normal = hit.normal
		hook_valid = is_valid_surface(hit.collider) and hit.position.distance_to(_middle()) >= min_attach_distance
		hook_reason = "" if hook_valid else ("Too close" if is_valid_surface(hit.collider) else "It won't bite there")
	hook_pos = muzzle.global_position
	_set_state(State.HOOK_FIRING)
	_play(Sfx.hook_fire(), -3.0)
	Game.emit_noise(player.global_position, fire_noise_radius, player, "hookshot_fire", 0.5)
	hook_fired.emit(hook_target)


func _fly_hook(delta: float) -> void:
	var to := hook_target - hook_pos
	var step := hook_speed * delta
	var next := hook_target if to.length() <= step else hook_pos + to.normalized() * step
	# Something may have moved into the hook's path.
	var q := PhysicsRayQueryParameters3D.create(hook_pos, next, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.position.distance_to(hook_target) > 0.05:
		hook_target = hit.position
		hook_normal = hit.normal
		hook_valid = is_valid_surface(hit.collider) and hit.position.distance_to(_middle()) >= min_attach_distance
		hook_reason = "" if hook_valid else "It won't bite there"
		next = hook_target
	hook_pos = next
	if hook_pos.distance_to(hook_target) < 0.01:
		if hook_valid:
			_start_pull()
		else:
			_fail(hook_target, hook_reason)


func _fail(point: Vector3, reason: String) -> void:
	Fx.sparks(player, point, hook_normal)
	_play(Sfx.clink(), -4.0)
	Game.emit_noise(point, fail_noise_radius, player, "hookshot_fail", 0.4)
	cooldown_timer = cooldown
	_set_state(State.NORMAL)
	if reason != "Missed":
		player.notice.emit(reason)
	hook_failed.emit(point, reason)


func _start_pull() -> void:
	var n := hook_normal
	var flat_in := hook_target - player.global_position
	flat_in.y = 0.0
	flat_in = flat_in.normalized() if flat_in.length() > 0.01 else -player.global_basis.z
	if n.y > 0.7:
		# The top of something: land on it, a little way in from the edge.
		feet_target = hook_target + flat_in * 0.6 + Vector3.UP * 0.05
	else:
		# A wall or the underside of a beam: hang off it, Arrival Offset out.
		feet_target = hook_target + n * arrival_offset - Vector3.UP * 0.9
	pull_dir = (feet_target - player.global_position).normalized()
	pull_time = 0.0
	pull_limit = player.global_position.distance_to(feet_target) / maxf(pull_speed, 0.1) + pull_grace
	_stuck_ticks = 0
	mantling = false
	player.velocity = Vector3.ZERO
	_set_state(State.HOOK_PULLING)
	_play(Sfx.arrow_thunk(), 0.0)
	Game.emit_noise(hook_target, connect_noise_radius, player, "hookshot_connect", 0.4)
	hook_connected.emit(hook_target)


func _pull(delta: float) -> void:
	if mantling:
		_mantle(delta)
		return
	pull_time += delta
	var to := feet_target - player.global_position
	if to.length() < 0.25 or to.dot(pull_dir) <= 0.0:
		_arrive()
		return
	var speed := minf(pull_speed, to.length() / delta)
	var dir := to.normalized()
	player.velocity = dir * speed
	var before: Vector3 = player.global_position
	player.move_and_slide()
	var progressed: float = (player.global_position - before).dot(dir)
	# Blocked: barely moving toward the target for a few ticks running.
	_stuck_ticks = _stuck_ticks + 1 if progressed < speed * delta * 0.35 else 0
	if _stuck_ticks >= 3 or pull_time > pull_limit:
		_end_pull(false)
	elif player.input.jump_pressed:
		_end_pull(false)


func _arrive() -> void:
	if mantle_on_arrival and _find_mantle():
		mantling = true
		_mantle_time = 0.0
		_mantle_start = player.global_position
		return
	_end_pull(true)


func _end_pull(arrived: bool) -> void:
	mantling = false
	cooldown_timer = cooldown
	# Hand back a little momentum on arrival, none when blocked, so control
	# returns smoothly and nothing gets pushed into a wall.
	player.velocity = pull_dir * 1.5 if arrived else Vector3.ZERO
	player.velocity.y = maxf(player.velocity.y, 0.0)
	_set_state(State.NORMAL)
	pull_finished.emit(arrived)


## A walkable top within reach, in toward the wall the hook bit.
func _find_mantle() -> bool:
	var inward := -Vector3(hook_normal.x, 0.0, hook_normal.z)
	if inward.length() < 0.3:
		inward = Vector3(pull_dir.x, 0.0, pull_dir.z)
	if inward.length() < 0.01:
		return false
	inward = inward.normalized()
	var space := player.get_world_3d().direct_space_state
	var feet: float = player.global_position.y
	for reach in [0.8, 1.2, 1.6]:
		var from: Vector3 = player.global_position + inward * reach + Vector3.UP * (mantle_height + 0.6)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (mantle_height + 1.2), 1)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var rise: float = hit.position.y - feet
		if rise < -0.1 or rise > mantle_height:
			continue
		if not _room_at(hit.position + Vector3.UP * 0.05):
			continue
		_mantle_top = hit.position.y
		_mantle_dir = inward
		_mantle_reach = reach
		return true
	return false


func _mantle(delta: float) -> void:
	_mantle_time += delta
	var feet: float = player.global_position.y
	if feet < _mantle_top + 0.1 and _mantle_time < 0.9:
		player.velocity = Vector3.UP * 5.0
	else:
		player.velocity = _mantle_dir * 3.0 + Vector3.DOWN * 1.0
	player.move_and_slide()
	var p: Vector3 = player.global_position
	var travelled := Vector2(p.x - _mantle_start.x, p.z - _mantle_start.z).length()
	if _mantle_time > 1.5 or (travelled >= _mantle_reach + 0.3 and p.y > _mantle_top - 0.1):
		_end_pull(true)


## Is there room for Jeffrey standing with his feet at `feet`?
func _room_at(feet: Vector3) -> bool:
	var mv: PlayerMovement = player.movement
	var shape := CapsuleShape3D.new()
	shape.radius = mv.capsule_radius - 0.03
	shape.height = mv.standing_height - 0.15
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (0.1 + shape.height * 0.5))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- Wire: placing ------------------------------------------------------------

func _anchor_from(hit: Dictionary) -> Dictionary:
	return {"point": hit.position, "normal": hit.normal, "collider": hit.collider}


## Press R2 in wire mode: the first anchor, or the second and the wire.
func place_anchor() -> void:
	var hit := _ray(anchor_range)
	if hit.is_empty() or not is_valid_surface(hit.collider):
		_reject("Can't anchor there" if not hit.is_empty() else "Out of range", hit.get("position", Vector3.ZERO))
		return
	if pending_anchor.is_empty():
		pending_anchor = _anchor_from(hit)
		_set_state(State.WIRE_PLACEMENT)
		_play(Sfx.anchor_tick(), -6.0)
		Game.emit_noise(hit.position, anchor_noise_radius, player, "wire_anchor", 0.2)
		anchor_placed.emit(hit.position)
		return
	var v := validate_wire(pending_anchor, _anchor_from(hit))
	if not v.ok:
		_reject(v.reason, hit.position)
		return
	while wires.size() >= max_active_wires:
		remove_wire(wires[0])
	var parent: Node = player.get_tree().current_scene if player.get_tree().current_scene else player.get_parent()
	var w := TightWire.create(parent, v.a, v.b, v.dismount_a, v.dismount_b)
	w.mount_requested.connect(mount)
	wires.append(w)
	pending_anchor = {}
	_set_state(State.NORMAL)
	_play(Sfx.anchor_tick(), -3.0)
	Game.emit_noise(hit.position, anchor_noise_radius, player, "wire_complete", 0.2)
	cooldown_timer = cooldown
	wire_created.emit(w)


func _reject(reason: String, at: Vector3) -> void:
	_play(Sfx.clink(), -8.0)
	if at != Vector3.ZERO:
		Fx.sparks(player, at, Vector3.UP)
	player.notice.emit(reason)
	wire_rejected.emit(reason)


func _clear_anchor() -> void:
	pending_anchor = {}
	if state == State.WIRE_PLACEMENT:
		_set_state(State.NORMAL)


func remove_wire(w: TightWire) -> void:
	if wire == w and state == State.WIRE_TRAVERSAL:
		_leave("drop")
	wires.erase(w)
	if is_instance_valid(w):
		w.queue_free()


## Could Jeffrey walk a wire between these anchors? Returns {ok, reason,
## a, b, dismount_a, dismount_b, length, incline}.
func validate_wire(first: Dictionary, second: Dictionary) -> Dictionary:
	var r := {"ok": false, "reason": "", "length": 0.0, "incline": 0.0}
	if not is_valid_surface(first.get("collider")) or not is_valid_surface(second.get("collider")):
		r.reason = "Both ends need something to bite"
		return r
	var a: Vector3 = first.point + first.normal * 0.04
	var b: Vector3 = second.point + second.normal * 0.04
	var length := a.distance_to(b)
	r.length = length
	if length > max_wire_length:
		r.reason = "Too long (%.0f m)" % length
		return r
	if length < min_wire_length:
		r.reason = "Too short"
		return r
	var incline := rad_to_deg(asin(clampf(absf(b.y - a.y) / length, 0.0, 1.0)))
	r.incline = incline
	if incline > max_incline_degrees:
		r.reason = "Too steep (%d°)" % roundi(incline)
		return r
	# A clear line. Near each end the wire may graze the edge of the thing
	# it's anchored to (a bolt near the lip of a roof), nowhere else.
	var dir := (b - a) / length
	var graze := minf(ANCHOR_GRAZE, length * 0.25)
	var a_in := a + dir * graze
	var b_in := b - dir * graze
	var lines := [[a_in, b_in, []], [b_in, a_in, []], [a, a_in, [first.collider]], [b, b_in, [second.collider]]]
	for l in lines:
		if not _line_clear(l[0], l[1], l[2]):
			r.reason = "Something's in the way"
			return r
	# Room for a body standing on it, from one mount point to the other.
	var ma := a + dir * TightWire.END_INSET
	var mb := b - dir * TightWire.END_INSET
	if not _room_at(ma) or not _room_at(mb) or not _sweep_clear(ma, mb):
		r.reason = "No room to walk it"
		return r
	var da: Variant = _footing(a, -dir)
	var db: Variant = _footing(b, dir)
	if da == null or db == null:
		r.reason = "No footing at one end"
		return r
	r.ok = true
	r.a = a
	r.b = b
	r.dismount_a = da
	r.dismount_b = db
	return r


func _line_clear(from: Vector3, to: Vector3, also_exclude: Array) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var ex: Array[RID] = [player.get_rid()]
	for c in also_exclude:
		if c is CollisionObject3D:
			ex.append(c.get_rid())
	q.exclude = ex
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A body standing on the wire can move from `from` to `to` (feet).
func _sweep_clear(from: Vector3, to: Vector3) -> bool:
	var mv: PlayerMovement = player.movement
	var shape := CapsuleShape3D.new()
	shape.radius = mv.capsule_radius - 0.03
	shape.height = mv.standing_height - 0.15
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), from + Vector3.UP * (0.1 + shape.height * 0.5))
	q.motion = to - from
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var res := player.get_world_3d().direct_space_state.cast_motion(q)
	return res[0] >= 1.0


## Walkable ground near wire end `end`, beyond it along `outward`; null if none.
func _footing(end: Vector3, outward: Vector3) -> Variant:
	var flat := Vector3(outward.x, 0.0, outward.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	var space := player.get_world_3d().direct_space_state
	for k in [0.2, 0.6, 1.0, 1.4]:
		var from: Vector3 = end + flat * k + Vector3.UP * 1.0
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.4, 1)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		if absf(hit.position.y - end.y) > 1.2:
			continue
		if _room_at(hit.position + Vector3.UP * 0.05):
			return hit.position + Vector3.UP * 0.05
	return null


# --- Wire: walking ------------------------------------------------------------

## Step onto `w` at end `end` (0 = A, 1 = B). Usually from its Interactable.
func mount(w: TightWire, end: int) -> void:
	if player.dead or not (state == State.NORMAL or state == State.WIRE_PLACEMENT) or player.dash.active:
		return
	pending_anchor = {}
	wire = w
	wire_s = w.mount_s(end)
	wire_forward_sign = 1.0 if end == 0 else -1.0
	_mount_t = 0.0
	_mount_from = player.global_position
	_dismount_end = -1
	_step_acc = 0.0
	player.velocity = Vector3.ZERO
	# The leg ray would stand Jeffrey up off nearby ledges; on a wire, his
	# feet are on the line.
	player.leg.disabled = true
	w.set_mounts_enabled(false)
	_set_state(State.WIRE_TRAVERSAL)
	wire_mounted.emit(w)


## How far along the wire Jeffrey is, 0..1 from end A.
func wire_progress() -> float:
	return wire_s / wire.length() if wire else 0.0


func _walk_wire(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if wire == null or not is_instance_valid(wire):
		_leave("drop")
		return
	if _dismount_end >= 0:
		_step_off(delta)
		return
	var on_line := wire.point_at(wire_s)
	if _mount_t < mount_time:
		# Step up onto the wire smoothly.
		_mount_t += delta
		var t := clampf(_mount_t / mount_time, 0.0, 1.0)
		var want := _mount_from.lerp(on_line, t * t * (3.0 - 2.0 * t)) + Vector3.UP * sin(t * PI) * 0.15
		if player.move_and_collide(want - player.global_position):
			_leave("drop")
		return
	var inp: PlayerInput = player.input
	if inp.jump_pressed:
		_leave("jump")
		return
	if inp.dash_pressed:
		# Circle: step off at an end if close to one, otherwise drop.
		for end in 2:
			if absf(wire_s - wire.mount_s(end)) < 1.0:
				_begin_step_off(end)
				return
		_leave("drop")
		return
	var push := -inp.move.y * wire_forward_sign
	if absf(push) < 0.05:
		_hold(on_line)
		return
	var lo := wire.mount_s(0)
	var hi := wire.mount_s(1)
	# Walking off the end of the wire steps off onto the ledge there.
	if (push < 0.0 and wire_s <= lo + 0.001) or (push > 0.0 and wire_s >= hi - 0.001):
		_begin_step_off(0 if push < 0.0 else 1)
		return
	var new_s := clampf(wire_s + push * wire_speed * delta, lo, hi)
	var collision := player.move_and_collide(wire.point_at(new_s) - player.global_position)
	if collision:
		# Something's in the way: stay put, back on the line.
		_hold(on_line)
		return
	_step_acc += absf(new_s - wire_s)
	wire_s = new_s
	if _step_acc >= wire_step_distance:
		_step_acc = 0.0
		Game.emit_noise(player.global_position, wire_step_noise_radius, player, "wire_step", 0.05)


## Stay exactly on the line (no drift).
func _hold(on_line: Vector3) -> void:
	var off := on_line - player.global_position
	if off.length() > 0.0001:
		player.move_and_collide(off)


func _begin_step_off(end: int) -> void:
	_dismount_end = end
	_dismount_from = player.global_position
	_mount_t = 0.0


func _step_off(delta: float) -> void:
	_mount_t += delta
	var t := clampf(_mount_t / mount_time, 0.0, 1.0)
	var to := wire.dismount_point(_dismount_end)
	var want := _dismount_from.lerp(to, t * t * (3.0 - 2.0 * t)) + Vector3.UP * sin(t * PI) * 0.2
	var hit := player.move_and_collide(want - player.global_position)
	if hit or t >= 1.0:
		_leave("dismount")


func _leave(how: String) -> void:
	var w := wire
	wire = null
	_dismount_end = -1
	player.leg.disabled = false
	if is_instance_valid(w):
		w.set_mounts_enabled(true)
	match how:
		"jump":
			var fwd: Vector3 = -player.global_basis.z
			fwd.y = 0.0
			player.velocity = fwd.normalized() * 2.5 + Vector3.UP * player.movement.jump_velocity * 0.85
		_:
			player.velocity = Vector3.ZERO
	cooldown_timer = cooldown
	_set_state(State.NORMAL)
	wire_left.emit(how)


# --- Visuals and sound ----------------------------------------------------------

func _build() -> void:
	var vm: PlayerViewmodel = player.viewmodel
	gun = Node3D.new()
	gun.name = "Hookshot"
	gun.position = Vector3(0.24, -0.26, -0.5)
	vm.tool_group.add_child(gun)
	var dark := Color(0.22, 0.21, 0.2)
	var brass := Color(0.55, 0.42, 0.2)
	_part(gun, Vector3(0.07, 0.16, 0.08), Vector3(0, -0.08, 0.05), Color(0.3, 0.2, 0.12)).rotation_degrees.x = 15.0
	_part(gun, Vector3(0.09, 0.09, 0.3), Vector3(0, 0, -0.08), dark)
	_part(gun, Vector3(0.05, 0.05, 0.12), Vector3(0, 0.02, -0.28), brass)
	_part(gun, Vector3(0.11, 0.11, 0.05), Vector3(0, 0, 0.02), brass)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.02, -0.36)
	gun.add_child(muzzle)
	_gun_hook = Node3D.new()
	muzzle.add_child(_gun_hook)
	_part(_gun_hook, Vector3(0.12, 0.025, 0.025), Vector3.ZERO, Color(0.6, 0.6, 0.62))
	_part(_gun_hook, Vector3(0.025, 0.025, 0.07), Vector3(0, 0, -0.03), Color(0.6, 0.6, 0.62))

	_hook = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.14, 0.04, 0.1)
	_hook.mesh = hm
	_hook.material_override = _mat(Color(0.6, 0.6, 0.62))
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)
	_cable = _line_mesh(0.01, Color(0.3, 0.28, 0.25))
	_anchor_marker = MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.12, 0.12, 0.12)
	_anchor_marker.mesh = am
	_anchor_marker.material_override = _mat(Color(0.25, 0.24, 0.24))
	_anchor_marker.top_level = true
	_anchor_marker.visible = false
	add_child(_anchor_marker)
	_preview = _line_mesh(0.008, Color(0.5, 0.9, 0.5, 0.6))
	_preview_mat = _preview.material_override
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


func _part(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(c)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	parent.add_child(m)
	return m


func _mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	return mat


func _line_mesh(radius: float, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 1.0
	cyl.radial_segments = 4
	m.mesh = cyl
	m.material_override = _mat(c)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	m.visible = false
	add_child(m)
	return m


func _update_visuals() -> void:
	if _hook == null:
		return
	var out := state == State.HOOK_FIRING or state == State.HOOK_PULLING
	_hook.visible = out
	_cable.visible = out
	_gun_hook.visible = not out
	if out:
		var at := hook_pos if state == State.HOOK_FIRING else hook_target
		_hook.global_position = at
		_cable.visible = true
		Rope.stretch(_cable, muzzle.global_position, at)
	var placing := state == State.WIRE_PLACEMENT and not pending_anchor.is_empty()
	_anchor_marker.visible = placing
	_preview.visible = placing and not aim_hit.is_empty()
	if placing:
		_anchor_marker.global_position = pending_anchor.point
		if _preview.visible:
			_preview.visible = true
			Rope.stretch(_preview, pending_anchor.point, aim_hit.position)
			_preview_mat.albedo_color = Color(0.5, 0.9, 0.5, 0.7) if aim == Aim.VALID else Color(0.95, 0.35, 0.3, 0.7)


func _play(stream: AudioStream, volume_db: float) -> void:
	if _sfx == null:
		return
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()
