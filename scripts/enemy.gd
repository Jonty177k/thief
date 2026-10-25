extends CharacterBody3D
## A sentry far too strong for Jeffrey to fight fairly.
## Wardens patrol day and night; Hollows only walk at night and are worse.

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, DEAD }

const KINDS := {
	"warden": {
		"hp": 260.0, "patrol_speed": 1.8, "chase_speed": 4.7,
		"view": 26.0, "fov": 100.0, "hearing": 1.0,
		"damage": 38.0, "windup": 0.65, "cooldown": 1.6,
		"height": 2.4, "color": Color(0.28, 0.29, 0.32), "eye": Color(1.0, 0.75, 0.3),
		"night_only": false,
	},
	"hollow": {
		"hp": 420.0, "patrol_speed": 2.4, "chase_speed": 6.4,
		"view": 34.0, "fov": 130.0, "hearing": 1.6,
		"damage": 65.0, "windup": 0.45, "cooldown": 1.2,
		"height": 2.9, "color": Color(0.75, 0.74, 0.68), "eye": Color(1.0, 0.15, 0.1),
		"night_only": true,
	},
}

const GRAVITY := 18.0
const ATTACK_RANGE := 2.2
const LOSE_TIME := 3.5
const SEARCH_TIME := 6.0

var kind := "warden"
var waypoints: Array[Vector3] = []
## Per-enemy tweaks on top of KINDS[kind] (any of its keys), e.g. set by a
## level's Enemy node.
var overrides := {}
var stats: Dictionary
var home := Vector3.ZERO

var state := State.PATROL
var awareness := 0.0
var hp := 1.0
var wp_index := 0
var last_known := Vector3.ZERO
var lost_timer := 0.0
var search_timer := 0.0
var attack_cd := 0.0
var windup := -1.0
var active := true
var can_see_player := false

var player: Node3D
var body_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var label: Label3D


func setup(p_kind: String, p_waypoints: Array[Vector3]) -> void:
	kind = p_kind
	waypoints = p_waypoints


func _ready() -> void:
	add_to_group("enemy")
	stats = KINDS[kind].duplicate()
	stats.merge(overrides, true)
	hp = stats.hp
	home = global_position
	if waypoints.is_empty():
		waypoints = [home]
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(48.0)
	_build_body()
	_set_active(not stats.night_only or Game.is_night())


func _build_body() -> void:
	var h: float = stats.height
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = h
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = h * 0.5
	add_child(col)

	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = stats.color
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = stats.eye
	eye_mat.emission_enabled = true
	eye_mat.emission = stats.eye
	eye_mat.emission_energy_multiplier = 3.0

	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(1.0, h * 0.62, 0.6)
	torso.mesh = torso_mesh
	torso.material_override = body_mat
	torso.position.y = h * 0.45
	add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.5, 0.5)
	head.mesh = head_mesh
	head.material_override = body_mat
	head.position.y = h * 0.86
	add_child(head)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.1, 0.06, 0.05)
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12, h * 0.88, -0.26)
		add_child(eye)
		# Big weapon arm / club on the right, plate arm on the left.
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.25, h * 0.55, 0.25) if side < 0 else Vector3(0.3, h * 0.75, 0.3)
		arm.mesh = arm_mesh
		arm.material_override = body_mat
		arm.position = Vector3(side * 0.65, h * 0.4, -0.1)
		add_child(arm)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 96
	label.outline_size = 16
	label.no_depth_test = true
	label.position.y = h + 0.6
	add_child(label)


func is_alive() -> bool:
	return active and state != State.DEAD


## True when Jeffrey is behind an enemy that hasn't noticed him: backstab.
func is_unaware_of_behind(from: Vector3) -> bool:
	if state == State.CHASE:
		return false
	var to_from := from - global_position
	to_from.y = 0
	return _forward().dot(to_from.normalized()) < -0.3


func take_damage(amount: float, from: Vector3) -> void:
	if not is_alive():
		return
	hp -= amount
	body_mat.albedo_color = Color(0.9, 0.3, 0.25)
	var t := create_tween()
	t.tween_property(body_mat, "albedo_color", stats.color, 0.25)
	if hp <= 0.0:
		state = State.DEAD
		_set_active(false)
		return
	awareness = 1.0
	last_known = from
	state = State.CHASE
	lost_timer = 0.0


## Put the enemy back on its post, fully healed (after resting or dying).
func reset_to_post() -> void:
	global_position = home
	velocity = Vector3.ZERO
	hp = stats.hp
	state = State.PATROL
	awareness = 0.0
	windup = -1.0
	wp_index = 0
	_set_active(not stats.night_only or Game.is_night())


func _set_active(on: bool) -> void:
	active = on
	visible = on
	collision_layer = 4 if on else 0
	collision_mask = (1 | 2) if on else 0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var should_be_active: bool = not stats.night_only or Game.is_night()
	if should_be_active != active:
		if should_be_active:
			reset_to_post()
		elif state != State.CHASE:
			_set_active(false)
	if not active:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")
	attack_cd = maxf(attack_cd - delta, 0.0)

	_sense(delta)
	match state:
		State.PATROL:
			_patrol()
		State.SUSPICIOUS:
			_suspicious()
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_update_label()


func _eye_pos() -> Vector3:
	return global_position + Vector3(0, stats.height * 0.88, 0)


func _forward() -> Vector3:
	return -global_transform.basis.z


func _sense(delta: float) -> void:
	can_see_player = false
	if player == null or player.dead:
		awareness = maxf(awareness - delta * 0.5, 0.0)
		if state == State.CHASE or state == State.SEARCH:
			state = State.PATROL
		return
	var target: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var to_p := target - _eye_pos()
	var dist := to_p.length()
	var vis: float = player.visibility
	var view_range: float = stats.view * (0.25 + 0.75 * vis)
	if state == State.CHASE:
		view_range = maxf(view_range, stats.view * 0.6)  # hard to shake once hunting

	var in_cone := _forward().dot(to_p.normalized()) > cos(deg_to_rad(stats.fov * 0.5))
	var bumped := dist < 1.8 and vis > 0.1
	if dist < view_range and (in_cone or bumped) and _line_of_sight(target):
		can_see_player = true
		last_known = player.global_position
		var closeness := 1.0 - dist / view_range
		var gain := (1.4 * closeness + 0.35) * vis
		if state == State.CHASE or state == State.SEARCH:
			gain *= 2.5
		awareness += gain * delta * 1.6
	else:
		awareness -= delta * 0.12

	var heard_radius: float = player.noise_radius * stats.hearing
	if dist < heard_radius:
		last_known = player.global_position
		awareness = maxf(awareness, 0.5) + delta * 0.4

	awareness = clampf(awareness, 0.0, 1.0)


func _line_of_sight(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_eye_pos(), target, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _patrol() -> void:
	var wp: Vector3 = waypoints[wp_index]
	if _flat_dist(wp) < 0.8:
		wp_index = (wp_index + 1) % waypoints.size()
	_move_toward(wp, stats.patrol_speed)
	if awareness > 0.3:
		state = State.SUSPICIOUS


func _suspicious() -> void:
	_face(last_known)
	if awareness > 0.65:
		_move_toward(last_known, stats.patrol_speed * 0.8)
	else:
		_stop()
	if awareness >= 1.0:
		state = State.CHASE
		lost_timer = 0.0
	elif awareness < 0.1:
		state = State.PATROL


func _chase(delta: float) -> void:
	if can_see_player:
		awareness = 1.0
		lost_timer = 0.0
	else:
		lost_timer += delta
	var dist := _flat_dist(last_known)
	if windup >= 0.0:
		_attack_windup(delta)
		return
	if can_see_player and dist < ATTACK_RANGE and attack_cd <= 0.0:
		windup = 0.0
		_stop()
		return
	if dist > ATTACK_RANGE * 0.8:
		_move_toward(last_known, stats.chase_speed)
	else:
		_stop()
		_face(last_known)
	if lost_timer > LOSE_TIME:
		state = State.SEARCH
		search_timer = 0.0
		awareness = 0.7


func _attack_windup(delta: float) -> void:
	_stop()
	_face(player.global_position)
	windup += delta
	# Telegraph: the eyes flare before the blow lands.
	eye_mat.emission_energy_multiplier = 3.0 + windup / stats.windup * 12.0
	if windup >= stats.windup:
		windup = -1.0
		attack_cd = stats.cooldown
		eye_mat.emission_energy_multiplier = 3.0
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0
		if to_p.length() < ATTACK_RANGE + 0.6 and _forward().dot(to_p.normalized()) > 0.4:
			player.take_hit(stats.damage, global_position)


func _search(delta: float) -> void:
	search_timer += delta
	if _flat_dist(last_known) > 1.0 and search_timer < SEARCH_TIME * 0.5:
		_move_toward(last_known, stats.patrol_speed * 1.3)
	else:
		_stop()
		rotation.y += delta * 1.2  # look around
	if awareness >= 1.0 and can_see_player:
		state = State.CHASE
		lost_timer = 0.0
	elif search_timer > SEARCH_TIME:
		state = State.PATROL
		awareness = 0.2


func _flat_dist(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0
	return d.length()


func _move_toward(target: Vector3, speed: float) -> void:
	var dir := target - global_position
	dir.y = 0
	if dir.length() < 0.05:
		_stop()
		return
	dir = dir.normalized()
	_face(global_position + dir)
	if not _ground_ahead(dir):
		_stop()  # never walk off the Colossus
		return
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _stop() -> void:
	velocity.x = 0
	velocity.z = 0


func _face(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.15)


func _ground_ahead(dir: Vector3) -> bool:
	var from := global_position + dir * 0.9 + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_label() -> void:
	match state:
		State.CHASE:
			label.text = "!"
			label.modulate = Color(1, 0.2, 0.15)
		State.SUSPICIOUS, State.SEARCH:
			label.text = "?"
			label.modulate = Color(1, 0.85, 0.3).lerp(Color(1, 0.4, 0.2), awareness)
		_:
			label.text = ""
