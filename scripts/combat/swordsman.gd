@tool
class_name JBDSwordsman
extends CharacterBody3D
## A humanoid melee enemy with a sword: the combat prototype's opponent.
## It notices Jeffrey, closes in, picks an attack from its list (see
## EnemyAttack), telegraphs it, swings, recovers, and pauses before the
## next one. Its blade is swept along the arm's real arc during the active
## frames, so it stops at walls and Jeffrey's shield catches it from the
## front. Hits make it flinch; enough damage at once breaks its poise and
## staggers it. Everything is in the Inspector.

signal died
signal attack_started(attack: EnemyAttack)
signal staggered

enum State { IDLE, APPROACH, WINDUP, ACTIVE, RECOVERY, PAUSE, STAGGER, RETURN, DEAD }

@export var max_health := 100.0

@export_group("Awareness")
## Notices Jeffrey within this distance (with line of sight).
@export var notice_range := 10.0
## Always notices Jeffrey this close, sight or not.
@export var touch_range := 2.5
## Gives up and goes home past this distance.
@export var lose_range := 20.0
## Scale notice range by Jeffrey's light gem (darker = closer before it sees you).
@export var use_visibility := true

@export_group("Movement")
@export var move_speed := 2.6
@export var turn_speed := 220.0
## Sideways drift while pausing between attacks, in m/s.
@export var circle_speed := 0.9
## Backs off when Jeffrey is closer than this.
@export var personal_space := 1.1

@export_group("Attacks")
## The attacks it can choose from. Empty: two default sword attacks.
@export var attacks: Array[EnemyAttack] = []
## Random pause between attacks, so it never attacks without a break.
@export var pause_min := 0.9
@export var pause_max := 1.8
## Blade thickness for its swept hit detection, in metres.
@export var blade_radius := 0.14

@export_group("Poise and Stagger")
## Damage it can take before it staggers. A blow this big staggers at once.
@export var poise := 50.0
## Poise comes back after this long without being hit.
@export var poise_reset_time := 2.5
@export var stagger_time := 0.9
## Seconds of hit flinch on a blow that doesn't stagger.
@export var flinch_time := 0.18

var health := 100.0
var state := State.IDLE
var current: EnemyAttack
var state_time := 0.0
var target: Node3D
var home := Vector3.ZERO
var home_yaw := 0.0
var poise_left := 50.0
## The blade is live this tick (for the debug panel and hitbox view).
var hitbox_active := false
var debug_sweeps: Array = []

var _pause := 1.0
var _circle_dir := 1.0
var _poise_timer := 0.0
var _flinch := 0.0
var _hit_this_swing := false
var _blade_blocked := false
var _blade_prev: Array[Vector3] = []
var _cooldowns := {}
var _visual: Node3D
var _torso: Node3D
var _arm: Node3D
var _shield_arm: Node3D
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _label: Label3D
var _sfx: AudioStreamPlayer3D

const BODY := Color(0.33, 0.3, 0.27)
const GRAVITY := 19.6
const SHOULDER := Vector3(0.38, 1.42, -0.05)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	health = max_health
	poise_left = poise
	if attacks.is_empty():
		attacks = default_attacks()
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("enemy")
	add_to_group("combat_enemy")
	home = global_position
	home_yaw = rotation.y


## A diagonal slash and an overhead chop, both at the prototype's starting
## numbers (35 damage, 0.55 s windup, 0.65 s recovery).
static func default_attacks() -> Array[EnemyAttack]:
	var slash := EnemyAttack.new()
	slash.name = "Slash"
	slash.pose_windup = Vector3(25, -95, 30)
	slash.pose_finish = Vector3(-25, 75, -20)
	slash.weight = 1.2
	var chop := EnemyAttack.new()
	chop.name = "Chop"
	chop.pose_windup = Vector3(110, -15, 0)
	chop.pose_finish = Vector3(-42, 5, 0)
	chop.max_range = 1.9
	chop.lunge_speed = 1.2
	chop.cooldown = 2.0
	return [slash, chop]


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.85
	shape.shape = cap
	shape.position.y = 0.925
	add_child(shape, false, INTERNAL_MODE_BACK)

	_visual = Node3D.new()
	add_child(_visual, false, INTERNAL_MODE_BACK)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = BODY
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.16, 0.15)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.7, 0.74)
	steel.metallic = 0.6
	steel.roughness = 0.35
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(1.0, 0.55, 0.2)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.45, 0.15)
	_eye_mat.emission_energy_multiplier = 1.5

	for side in [-1.0, 1.0]:
		_box(_visual, Vector3(0.17, 0.85, 0.2), Vector3(side * 0.13, 0.43, 0), dark)
	_torso = Node3D.new()
	_torso.position.y = 0.9
	_visual.add_child(_torso)
	_box(_torso, Vector3(0.58, 0.62, 0.32), Vector3(0, 0.3, 0), _body_mat)
	_box(_torso, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.78, 0), _body_mat)
	for side in [-1.0, 1.0]:
		_box(_torso, Vector3(0.07, 0.04, 0.04), Vector3(side * 0.07, 0.8, -0.16), _eye_mat)

	# Sword arm: a pivot at the right shoulder; the blade runs along -Z.
	_arm = Node3D.new()
	_arm.position = SHOULDER - Vector3(0, 0.9, 0)
	_torso.add_child(_arm)
	_box(_arm, Vector3(0.12, 0.12, 0.45), Vector3(0, 0, -0.22), _body_mat)
	_box(_arm, Vector3(0.22, 0.04, 0.06), Vector3(0, 0, -0.47), dark)
	_box(_arm, Vector3(0.05, 0.015, 1.25), Vector3(0, 0, -1.125), steel)
	_arm.rotation_degrees = _rest_pose()
	# Off arm with a buckler.
	_shield_arm = Node3D.new()
	_shield_arm.position = Vector3(-0.38, 0.52, -0.05)
	_torso.add_child(_shield_arm)
	_box(_shield_arm, Vector3(0.12, 0.45, 0.12), Vector3(0, -0.2, 0), _body_mat)
	_box(_shield_arm, Vector3(0.36, 0.36, 0.05), Vector3(0, -0.3, -0.12), dark)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 36
	_label.outline_size = 10
	_label.position.y = 2.2
	add_child(_label, false, INTERNAL_MODE_BACK)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.position.y = 1.4
	add_child(_sfx, false, INTERNAL_MODE_BACK)
	_update_label()


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _rest_pose() -> Vector3:
	return Vector3(-25, 15, 0)


func is_alive() -> bool:
	return state != State.DEAD


func state_name() -> String:
	return State.keys()[state]


## "SLASH windup" etc., for the debug panel.
func describe() -> String:
	var s := state_name().to_lower()
	if current and state in [State.WINDUP, State.ACTIVE, State.RECOVERY]:
		s = "%s %s" % [current.name, s]
	return s


# --- Damage -----------------------------------------------------------------

## The damage interface (see DamageInfo).
func receive_damage(info: DamageInfo) -> void:
	if not is_alive() or Engine.is_editor_hint():
		return
	health -= info.amount
	_poise_timer = poise_reset_time
	poise_left -= info.amount
	velocity += info.direction * info.knockback * 0.5
	_body_mat.albedo_color = Color(0.85, 0.3, 0.25)
	create_tween().tween_property(_body_mat, "albedo_color", BODY, 0.3)
	_play(Sfx.thud(), -2.0)
	if info.source is Node3D:
		target = info.source
	if health <= 0.0:
		_die(info)
		return
	if poise_left <= 0.0:
		poise_left = poise
		_enter(State.STAGGER)
		staggered.emit()
	else:
		_flinch = flinch_time
	_update_label()


func _die(info: DamageInfo) -> void:
	health = 0.0
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 1
	var fall_axis := Vector3(info.direction.z, 0, -info.direction.x)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation", global_basis.inverse() * fall_axis * -1.45, 0.6)
	_update_label()
	died.emit()


## Back to its post, healed (after resting at a campfire or dying).
func reset_to_post() -> void:
	global_position = home
	rotation.y = home_yaw
	velocity = Vector3.ZERO
	health = max_health
	poise_left = poise
	collision_layer = 4
	collision_mask = 1 | 2
	_visual.rotation = Vector3.ZERO
	target = null
	_enter(State.IDLE)
	_update_label()


# --- Behaviour --------------------------------------------------------------

func _enter(s: State) -> void:
	state = s
	state_time = 0.0
	hitbox_active = false
	if s == State.WINDUP:
		_hit_this_swing = false
		_blade_blocked = false
		_blade_prev.clear()
		_play(Sfx.grunt(), -4.0)
		attack_started.emit(current)
	elif s == State.ACTIVE:
		_play(Sfx.whoosh(), -2.0)
		_arm.rotation_degrees = current.pose_windup
		_blade_prev = blade_points()
	elif s == State.PAUSE:
		_pause = randf_range(pause_min, pause_max)
		_circle_dir = -1.0 if randf() < 0.5 else 1.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	debug_sweeps.clear()
	hitbox_active = false
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 12.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if state == State.DEAD:
		move_and_slide()
		return

	state_time += delta
	_poise_timer -= delta
	if _poise_timer <= 0.0:
		poise_left = poise
	_flinch = maxf(_flinch - delta, 0.0)
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.get("dead"):
		if state != State.IDLE and state != State.RETURN:
			_enter(State.RETURN)
	else:
		_think(player, delta)
	if state == State.RETURN:
		_walk_to(home, move_speed * 0.7, delta)
		if _flat(home - global_position).length() < 0.4:
			rotation.y = home_yaw
			_enter(State.IDLE)
	move_and_slide()
	_animate(delta)
	_update_label()


func _think(player: Node3D, delta: float) -> void:
	var to_p := player.global_position - global_position
	var dist := _flat(to_p).length()
	match state:
		State.IDLE, State.RETURN:
			if _notices(player, dist):
				target = player
				_enter(State.APPROACH)
		State.APPROACH:
			if dist > lose_range:
				_enter(State.RETURN)
				return
			var pick := _choose_attack(dist)
			if pick and _facing(player.global_position) < 25.0:
				current = pick
				_enter(State.WINDUP)
			elif dist > _engage_distance():
				_walk_to(player.global_position, move_speed, delta)
			else:
				_turn_to(player.global_position, turn_speed, delta)
		State.WINDUP:
			_turn_to(player.global_position, current.windup_tracking, delta)
			if state_time >= current.windup:
				_enter(State.ACTIVE)
		State.ACTIVE:
			var fwd := -global_basis.z
			velocity.x = fwd.x * current.lunge_speed
			velocity.z = fwd.z * current.lunge_speed
			_sweep_blade()
			if state_time >= current.active:
				_cooldowns[current] = current.cooldown
				_enter(State.RECOVERY)
		State.RECOVERY:
			if state_time >= current.recovery:
				_enter(State.PAUSE)
		State.PAUSE:
			_turn_to(player.global_position, turn_speed, delta)
			var side := global_basis.x * _circle_dir
			var move := side * circle_speed
			if dist < personal_space:
				move += -_flat(to_p).normalized() * move_speed * 0.6
			velocity.x = move.x
			velocity.z = move.z
			if state_time >= _pause:
				_enter(State.APPROACH)
		State.STAGGER:
			if state_time >= stagger_time:
				_enter(State.PAUSE)


func _notices(player: Node3D, dist: float) -> bool:
	if dist < touch_range:
		return true
	var view := notice_range
	if use_visibility and player.get("visibility") != null:
		view *= 0.4 + 0.6 * clampf(player.visibility, 0.0, 1.0)
	if dist > view:
		return false
	var eye := global_position + Vector3.UP * 1.7
	var q := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * 1.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _engage_distance() -> float:
	var best := 0.0
	for a in attacks:
		best = maxf(best, a.max_range)
	return best * 0.85


## Weighted pick among the attacks that fit the distance and are off cooldown.
func _choose_attack(dist: float) -> EnemyAttack:
	var fits: Array[EnemyAttack] = []
	var total := 0.0
	for a in attacks:
		if dist >= a.min_range and dist <= a.max_range and _cooldowns.get(a, 0.0) <= 0.0:
			fits.append(a)
			total += a.weight
	if fits.is_empty():
		return null
	var r := randf() * total
	for a in fits:
		r -= a.weight
		if r <= 0.0:
			return a
	return fits.back()


func _walk_to(p: Vector3, speed: float, delta: float) -> void:
	var d := _flat(p - global_position)
	_turn_to(p, turn_speed, delta)
	if d.length() < 0.05:
		return
	d = d.normalized()
	velocity.x = d.x * speed
	velocity.z = d.z * speed


func _turn_to(p: Vector3, deg_per_s: float, delta: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-d.x, -d.z), deg_to_rad(deg_per_s) * delta)


## Degrees between where it faces and `p`.
func _facing(p: Vector3) -> float:
	var d := _flat(p - global_position)
	if d.length() < 0.01:
		return 0.0
	return rad_to_deg((-global_basis.z).angle_to(d.normalized()))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- The blade --------------------------------------------------------------

## Points along the blade in world space, hilt to tip.
func blade_points() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var reach := current.reach if current else 1.75
	for f in [0.45, 0.75, 1.0]:
		pts.append(_arm.global_transform * Vector3(0, 0, -0.5 - (reach - 0.5) * f))
	return pts


## Sweep each blade point from last tick's position to this tick's, so the
## hit follows the arm's actual arc and can't skip through Jeffrey.
func _sweep_blade() -> void:
	_pose_arm()
	hitbox_active = not _blade_blocked
	var pts := blade_points()
	if _blade_prev.is_empty():
		_blade_prev = pts
		return
	if _blade_blocked or _hit_this_swing:
		_blade_prev = pts
		return
	var space := get_world_3d().direct_space_state
	var shoulder := _arm.global_position
	var shape := SphereShape3D.new()
	shape.radius = blade_radius
	for i in pts.size():
		var a := _blade_prev[i]
		var b := pts[i]
		debug_sweeps.append([a, b])
		# Steel against stone: a wall between shoulder and blade stops the swing.
		var wall := PhysicsRayQueryParameters3D.create(shoulder, b, 1)
		wall.exclude = [get_rid()]
		var wall_hit := space.intersect_ray(wall)
		if not wall_hit.is_empty():
			_blade_blocked = true
			_play(Sfx.scrape(), -2.0)
			break
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), a)
		q.motion = b - a if a.distance_to(b) > 0.001 else Vector3(0, 0.001, 0)
		q.collision_mask = 2
		q.exclude = [get_rid()]
		var res := space.cast_motion(q)
		if res[1] < 1.0 or not space.intersect_shape(_at(q, b), 1).is_empty():
			_hit_player()
			break
	_blade_prev = pts


func _at(q: PhysicsShapeQueryParameters3D, p: Vector3) -> PhysicsShapeQueryParameters3D:
	var r := PhysicsShapeQueryParameters3D.new()
	r.shape = q.shape
	r.transform = Transform3D(Basis(), p)
	r.collision_mask = q.collision_mask
	r.exclude = q.exclude
	return r


func _hit_player() -> void:
	_hit_this_swing = true
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("receive_damage"):
		return
	var info := DamageInfo.make(current.damage, self, global_position, player.global_position, current.knockback, "enemy")
	player.receive_damage(info)
	if info.blocked:
		# Bounced off the shield: a little recoil.
		_flinch = flinch_time
	elif not info.dodged:
		_play(Sfx.thud(), 0.0)


# --- Looks ------------------------------------------------------------------

func _pose_arm() -> void:
	var rest := _rest_pose()
	match state:
		State.WINDUP:
			var t := clampf(state_time / current.windup, 0.0, 1.0)
			_arm.rotation_degrees = rest.lerp(current.pose_windup, 1.0 - (1.0 - t) * (1.0 - t))
		State.ACTIVE:
			var t := clampf(state_time / current.active, 0.0, 1.0)
			_arm.rotation_degrees = current.pose_windup.lerp(current.pose_finish, t)


func _animate(delta: float) -> void:
	match state:
		State.WINDUP:
			_pose_arm()
			var t := clampf(state_time / current.windup, 0.0, 1.0)
			# Telegraph: eyes flare and the body coils back.
			_eye_mat.emission_energy_multiplier = 1.5 + t * 10.0
			_torso.rotation_degrees = Vector3(-8.0 * t, 12.0 * t, 0)
		State.ACTIVE:
			_eye_mat.emission_energy_multiplier = 8.0
			_torso.rotation_degrees = _torso.rotation_degrees.lerp(Vector3(10, -15, 0), 1.0 - exp(-20.0 * delta))
		State.STAGGER:
			_eye_mat.emission_energy_multiplier = 0.5
			var t := clampf(state_time / stagger_time, 0.0, 1.0)
			_torso.rotation_degrees = Vector3(-25.0 * sin(t * PI), 0, 8.0 * sin(t * PI * 2.0))
			_arm.rotation_degrees = _arm.rotation_degrees.lerp(Vector3(-60, 40, 0), 1.0 - exp(-10.0 * delta))
		_:
			_eye_mat.emission_energy_multiplier = lerpf(_eye_mat.emission_energy_multiplier, 1.5, 1.0 - exp(-8.0 * delta))
			_arm.rotation_degrees = _arm.rotation_degrees.lerp(_rest_pose(), 1.0 - exp(-6.0 * delta))
			var flinch := _flinch / maxf(flinch_time, 0.01)
			_torso.rotation_degrees = _torso.rotation_degrees.lerp(Vector3(-15.0 * flinch, 0, 0), 1.0 - exp(-14.0 * delta))


func _update_label() -> void:
	if _label == null:
		return
	if state == State.DEAD:
		_label.text = ""
		return
	_label.text = "%d / %d" % [ceili(health), roundi(max_health)]
	_label.modulate = Color(1, 0.6, 0.3) if state == State.STAGGER else Color(1, 0.9, 0.85)


func _play(stream: AudioStream, volume_db := 0.0) -> void:
	if _sfx == null:
		return
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()
