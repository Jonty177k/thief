extends CharacterBody3D
## Jeffrey: a weak peasant demon with a sword, a shield and a grappling hook.

signal health_changed(hp: float, max_hp: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal took_hit
signal died

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.8
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 18.0
const MOUSE_SENS := 0.0025

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

const SWORD_DAMAGE := 9.0
const BACKSTAB_MULT := 4.0
const SWORD_REACH := 2.4
const ATTACK_COST := 18.0
const ATTACK_COOLDOWN := 0.55
const BLOCK_COST := 35.0
const SPRINT_COST := 20.0  # per second

const GRAPPLE_RANGE := 36.0
const GRAPPLE_SPEED := 22.0
const GRAPPLE_COOLDOWN := 0.4

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var stamina_delay := 0.0

var crouching := false
var sprinting := false
var blocking := false
var input_locked := false
var dead := false

## 0..1, how visible Jeffrey is right now (the "light gem").
var visibility := 0.5
var shadow_zones := 0
## Radius in metres in which enemies can hear Jeffrey this frame.
var noise_radius := 0.0

var attack_timer := 0.0
var attack_anim := 0.0

var grappling := false
var grapple_point := Vector3.ZERO
## Horizontal direction of the pull, used for the hop over the lip.
var grapple_dir := Vector3.ZERO
var grapple_time := 0.0
var grapple_cooldown := 0.0
var aim_grapple_valid := false

var mantling := false
var mantle_dir := Vector3.ZERO
var mantle_y := 0.0
var mantle_time := 0.0
var mantle_reach := 0.0
var mantle_start := Vector3.ZERO

var shake_time := 0.0
var shake_strength := 0.0

var collider: CollisionShape3D
var capsule: CapsuleShape3D
var head: Node3D
var camera: Camera3D
var sword_pivot: Node3D
var shield_pivot: Node3D
var rope: MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.4

	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	collider = CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = STAND_HEIGHT * 0.5
	add_child(collider)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80.0
	camera.near = 0.05
	camera.far = 900.0
	head.add_child(camera)
	camera.make_current()

	_build_viewmodel()

	rope = MeshInstance3D.new()
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.025
	rope_mesh.bottom_radius = 0.025
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 4
	rope.mesh = rope_mesh
	rope.material_override = _mat(Color(0.55, 0.42, 0.25))
	rope.top_level = true
	rope.visible = false
	add_child(rope)


func _build_viewmodel() -> void:
	# Sword on the right, shield on the left; both are children of the camera.
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.36, -0.36, -0.6)
	camera.add_child(sword_pivot)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.035, 0.5, 0.012)
	blade.mesh = blade_mesh
	blade.material_override = _mat(Color(0.62, 0.62, 0.66))
	blade.position = Vector3(0, 0.3, 0)
	sword_pivot.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.18, 0.03, 0.04)
	guard.mesh = guard_mesh
	guard.material_override = _mat(Color(0.35, 0.28, 0.18))
	guard.position = Vector3(0, 0.05, 0)
	sword_pivot.add_child(guard)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.035, 0.14, 0.035)
	grip.mesh = grip_mesh
	grip.material_override = _mat(Color(0.25, 0.16, 0.1))
	grip.position = Vector3(0, -0.03, 0)
	sword_pivot.add_child(grip)
	sword_pivot.rotation_degrees = Vector3(-20, 0, -12)

	shield_pivot = Node3D.new()
	shield_pivot.position = Vector3(-0.5, -0.42, -0.62)
	camera.add_child(shield_pivot)
	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.26, 0.32, 0.03)
	shield.mesh = shield_mesh
	shield.material_override = _mat(Color(0.4, 0.3, 0.2))
	shield_pivot.add_child(shield)
	var boss := MeshInstance3D.new()
	var boss_mesh := BoxMesh.new()
	boss_mesh.size = Vector3(0.1, 0.1, 0.05)
	boss.mesh = boss_mesh
	boss.material_override = _mat(Color(0.5, 0.5, 0.52))
	boss.position = Vector3(0, 0, -0.03)
	shield_pivot.add_child(boss)
	shield_pivot.rotation_degrees = Vector3(0, 25, 0)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not input_locked:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, deg_to_rad(-88), deg_to_rad(88))


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	grapple_cooldown = maxf(grapple_cooldown - delta, 0.0)
	stamina_delay = maxf(stamina_delay - delta, 0.0)

	var can_act := not input_locked
	var input_dir := Vector2.ZERO
	if can_act:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	_update_crouch(can_act and Input.is_action_pressed("crouch"), delta)
	blocking = can_act and Input.is_action_pressed("block") and stamina > 0.0 and attack_anim <= 0.0
	sprinting = can_act and Input.is_action_pressed("sprint") and not crouching and not blocking \
		and input_dir.y < 0.0 and stamina > 0.0 and is_on_floor()

	if grappling:
		_process_grapple(delta)
	elif mantling:
		_process_mantle(delta)
	else:
		_process_walk(input_dir, delta)

	if can_act:
		if Input.is_action_just_pressed("attack"):
			_try_attack()
		if Input.is_action_just_pressed("grapple"):
			_try_grapple()

	_update_aim()
	_update_stamina(delta)
	_update_viewmodel(delta)
	_update_visibility(input_dir, delta)
	_update_shake(delta)

	if global_position.y < -30.0:
		die()


func _process_walk(input_dir: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if not input_locked and Input.is_action_just_pressed("jump"):
		# Thief-style: jump at a ledge to climb it, otherwise just jump.
		if _try_mantle(true, 0.6):
			return
		if is_on_floor() and not crouching:
			velocity.y = JUMP_VELOCITY

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if blocking:
		speed *= 0.6

	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := dir * speed
	if is_on_floor():
		velocity.x = move_toward(velocity.x, target.x, 12.0 * speed * delta)
		velocity.z = move_toward(velocity.z, target.z, 12.0 * speed * delta)
	elif dir != Vector3.ZERO:
		# Light air control that never kills momentum from a grapple hop.
		velocity.x = move_toward(velocity.x, target.x, 3.0 * speed * delta)
		velocity.z = move_toward(velocity.z, target.z, 3.0 * speed * delta)
	move_and_slide()


func _update_crouch(want: bool, delta: float) -> void:
	if not want and crouching:
		# Only stand if there's room above.
		var q := PhysicsShapeQueryParameters3D.new()
		var probe := SphereShape3D.new()
		probe.radius = 0.3
		q.shape = probe
		q.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT - 0.3, 0))
		q.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(q, 1).size() > 0:
			want = true
	crouching = want
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	capsule.height = h
	collider.position.y = h * 0.5
	head.position.y = lerpf(head.position.y, h - 0.2, minf(delta * 12.0, 1.0))


func _update_stamina(delta: float) -> void:
	if sprinting and velocity.length() > 0.5:
		stamina -= SPRINT_COST * delta
		stamina_delay = 0.6
	elif stamina_delay <= 0.0:
		stamina += (12.0 if blocking else 28.0) * delta
	stamina = clampf(stamina, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	stamina_delay = 0.8


# --- Combat -----------------------------------------------------------------

func _try_attack() -> void:
	if attack_timer > 0.0 or blocking or stamina < 5.0:
		return
	attack_timer = ATTACK_COOLDOWN
	attack_anim = 1.0
	_spend_stamina(ATTACK_COST)
	noise_radius = maxf(noise_radius, 8.0)
	await get_tree().create_timer(0.12).timeout
	if dead:
		return
	var fwd := -camera.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var to_e: Vector3 = e.global_position + Vector3(0, 1.0, 0) - camera.global_position
		if to_e.length() > SWORD_REACH + 0.5:
			continue
		if fwd.dot(to_e.normalized()) < 0.5:
			continue
		var dmg := SWORD_DAMAGE
		if e.is_unaware_of_behind(global_position):
			dmg *= BACKSTAB_MULT
		e.take_damage(dmg, global_position)


## Called by enemies. `from` is the attacker's position.
func take_hit(damage: float, from: Vector3) -> void:
	if dead:
		return
	var to_attacker := (from - global_position)
	to_attacker.y = 0
	to_attacker = to_attacker.normalized()
	var facing := -global_transform.basis.z
	if blocking and facing.dot(to_attacker) > 0.3:
		if stamina >= BLOCK_COST:
			_spend_stamina(BLOCK_COST)
			damage *= 0.15
		else:
			# Guard broken: most of the hit still lands.
			_spend_stamina(stamina)
			damage *= 0.7
	hp -= damage
	velocity += -to_attacker * 6.0 + Vector3.UP * 2.5
	shake(0.25, 0.12)
	health_changed.emit(hp, max_hp)
	took_hit.emit()
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	grappling = false
	rope.visible = false
	health_changed.emit(hp, max_hp)
	died.emit()


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	hp = max_hp
	stamina = max_stamina
	dead = false
	health_changed.emit(hp, max_hp)


func heal_full() -> void:
	hp = max_hp
	stamina = max_stamina
	health_changed.emit(hp, max_hp)


# --- Grappling hook ---------------------------------------------------------

func _aim_ray() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * GRAPPLE_RANGE
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if hit.is_empty() or hit.collider.is_in_group("grapple"):
		return hit
	# Aim assist: a near miss just under or beside a wooden lip still counts.
	var probe := SphereShape3D.new()
	probe.radius = 0.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis(), hit.position)
	q.collision_mask = 1
	for r in space.intersect_shape(q, 8):
		if r.collider.is_in_group("grapple"):
			hit.collider = r.collider
			return hit
	return hit


func _update_aim() -> void:
	var hit := _aim_ray()
	aim_grapple_valid = not hit.is_empty() and hit.collider.is_in_group("grapple")


func _try_grapple() -> void:
	if grappling:
		_end_grapple(false)
		return
	if grapple_cooldown > 0.0:
		return
	var hit := _aim_ray()
	if hit.is_empty() or not hit.collider.is_in_group("grapple"):
		return
	# Aim a little above and in front of the anchor so Jeffrey ends up on top.
	var n: Vector3 = hit.normal
	if n.y < -0.5:
		# Hooked the underside: hang just beside it, then hop up and over.
		var away: Vector3 = global_position - hit.position
		away.y = 0
		grapple_point = hit.position + away.normalized() * 0.9 + Vector3.DOWN * 0.4
	else:
		grapple_point = hit.position + n * 0.6 + Vector3.UP * 0.6
	grapple_dir = grapple_point - global_position
	grapple_dir.y = 0
	grapple_dir = grapple_dir.normalized() if grapple_dir.length() > 0.1 else -global_transform.basis.z
	grappling = true
	grapple_time = 0.0
	rope.visible = true
	noise_radius = maxf(noise_radius, 6.0)


func _process_grapple(delta: float) -> void:
	grapple_time += delta
	var to_target := grapple_point - global_position
	var dist := to_target.length()
	velocity = to_target.normalized() * GRAPPLE_SPEED
	move_and_slide()
	_draw_rope(grapple_point - Vector3.UP * 0.6)
	var stuck := grapple_time > 0.3 and get_real_velocity().length() < 2.0
	if dist < 0.6 or stuck:
		_end_grapple(true)
	elif grapple_time > 3.0 or (not input_locked and Input.is_action_just_pressed("jump")):
		_end_grapple(false)


func _end_grapple(arrived: bool) -> void:
	grappling = false
	rope.visible = false
	grapple_cooldown = GRAPPLE_COOLDOWN
	var fwd := grapple_dir
	if arrived:
		# Clamber onto the nearest ledge, or just hop up and forward.
		if not _try_mantle(false, -0.3):
			velocity = Vector3.UP * 8.0 + fwd * 4.5
	else:
		velocity = velocity * 0.4 + Vector3.UP * 3.0


## Look around for a walkable top within reach and climb onto it.
## `facing_only` limits the search to what Jeffrey is looking at.
func _try_mantle(facing_only: bool, min_rise: float) -> bool:
	var space := get_world_3d().direct_space_state
	var facing := -global_transform.basis.z
	var best_score := -INF
	var found := false
	for i in 16:
		var a := i * TAU / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		var align := d.dot(facing)
		if facing_only and align < 0.7:
			continue
		for r in [0.9, 1.7]:
			var from: Vector3 = global_position + d * r + Vector3.UP * 2.6
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.4, 1))
			if hit.is_empty() or hit.normal.y < 0.7:
				continue
			var rise: float = hit.position.y - global_position.y
			if rise < min_rise or rise > 2.4:
				continue
			var score := rise * 1.5 + align
			# Prefer solid ground over a narrow beam top.
			var beyond: Vector3 = from + d * 1.0
			var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond, beyond + Vector3.DOWN * 3.4, 1))
			if hit2.is_empty() or absf(hit2.position.y - hit.position.y) > 0.3:
				score -= 2.0
			if score > best_score:
				best_score = score
				mantle_dir = d
				mantle_y = hit.position.y
				mantle_reach = r + 0.4
				found = true
	if found:
		mantling = true
		mantle_time = 0.0
		mantle_start = global_position
	return found


func _process_mantle(delta: float) -> void:
	mantle_time += delta
	if global_position.y < mantle_y + 0.15 and mantle_time < 0.8:
		velocity = Vector3.UP * 7.0  # rise first, so the lip can't snag us
	else:
		velocity = mantle_dir * 4.5 + Vector3.DOWN * 2.0
	move_and_slide()
	var travelled := Vector2(global_position.x - mantle_start.x, global_position.z - mantle_start.z).length()
	if mantle_time > 1.2 or (travelled >= mantle_reach and global_position.y > mantle_y - 0.1):
		mantling = false
		velocity = mantle_dir * 2.0


func _draw_rope(anchor: Vector3) -> void:
	var start := camera.global_position + camera.global_transform.basis * Vector3(0.25, -0.3, -0.3)
	var span := anchor - start
	var length := span.length()
	if length < 0.01:
		return
	var y := span / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	rope.global_transform = Transform3D(Basis(x, y * length, z), start + span * 0.5)


# --- Stealth ----------------------------------------------------------------

func enter_shadow() -> void:
	shadow_zones += 1


func exit_shadow() -> void:
	shadow_zones = maxi(shadow_zones - 1, 0)


func _update_visibility(input_dir: Vector2, delta: float) -> void:
	var light := 0.12 + 0.88 * Game.daylight()
	for fire in get_tree().get_nodes_in_group("campfire"):
		var d: float = fire.global_position.distance_to(global_position)
		if d < 10.0:
			light = maxf(light, 0.95 * (1.0 - d / 10.0))
	if shadow_zones > 0:
		light *= 0.35

	var moving := input_dir.length() > 0.1 or grappling
	var stance := 1.0
	if crouching:
		stance = 0.55
	elif sprinting:
		stance = 1.35
	elif not moving:
		stance = 0.8
	var target := clampf(light * stance, 0.0, 1.0)
	visibility = lerpf(visibility, target, minf(delta * 4.0, 1.0))

	# Noise: sprinting and landing are loud, crouch-walking is silent.
	var n := 0.0
	if moving and is_on_floor():
		n = 11.0 if sprinting else (0.0 if crouching else 3.5)
	noise_radius = maxf(n, noise_radius - delta * 20.0)


# --- Feel -------------------------------------------------------------------

func shake(duration: float, strength: float) -> void:
	shake_time = maxf(shake_time, duration)
	shake_strength = maxf(shake_strength, strength)


func _update_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		camera.h_offset = randf_range(-1, 1) * shake_strength
		camera.v_offset = randf_range(-1, 1) * shake_strength
	else:
		shake_strength = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _update_viewmodel(delta: float) -> void:
	attack_anim = maxf(attack_anim - delta * 3.5, 0.0)
	# Swing: a quick chop from upper right to lower left.
	var swing := sin(attack_anim * PI)
	sword_pivot.rotation_degrees = Vector3(-20 - swing * 75.0, swing * 25.0, -12 + swing * 40.0)
	var shield_target := Vector3(-0.18, -0.2, -0.45) if blocking else Vector3(-0.5, -0.42, -0.62)
	shield_pivot.position = shield_pivot.position.lerp(shield_target, minf(delta * 14.0, 1.0))
	shield_pivot.rotation_degrees.y = lerpf(shield_pivot.rotation_degrees.y, 5.0 if blocking else 25.0, minf(delta * 14.0, 1.0))
