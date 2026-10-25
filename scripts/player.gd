extends CharacterBody3D
## Jeffrey: a weak peasant demon with a sword, a shield and a grappling hook.

signal health_changed(hp: float, max_hp: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal took_hit
signal died
## Fired on each footfall, for sounds later. `loud` when sprinting.
signal footstep(loud: bool)

# Every value below shows up in the Inspector: open scenes/player.tscn and
# select the root node to tune Jeffrey without touching code.

@export_group("Movement")
@export var walk_speed := 3.6
@export var sprint_speed := 6.2
@export var crouch_speed := 1.7
## How quickly Jeffrey gets up to speed, in m/s². Lower feels heavier.
@export var acceleration := 11.0
## How quickly he stops when you let go, in m/s². Lower means more slide.
@export var deceleration := 16.0
## Steering while airborne, in m/s². Thief gives you very little.
@export var air_control := 2.5
@export var jump_velocity := 5.8
@export var gravity := 18.0
@export var stand_height := 1.8
@export var crouch_height := 1.0
## Eye height below the top of the capsule.
@export var eye_drop := 0.2
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.0022
@export_range(50.0, 110.0) var fov := 75.0

@export_group("Head Bob")
@export var head_bob_enabled := true
## Metres travelled per full bob cycle (two footsteps).
@export var stride_length := 2.2
## Vertical bob height at walking speed, in metres.
@export var bob_height := 0.045
## Side-to-side sway at walking speed, in metres.
@export var bob_sway := 0.025
@export_range(0.0, 1.0) var crouch_bob_scale := 0.6
## How much faster speeds exaggerate the bob.
@export var sprint_bob_scale := 1.5
## Camera roll when strafing, in degrees.
@export var strafe_tilt := 1.2
## How much the sword and shield lag behind the view.
@export var weapon_sway := 0.6

@export_group("Landing")
## Fall speed (m/s) before a landing makes the camera dip.
@export var land_dip_threshold := 3.0
@export var land_dip_per_speed := 0.025
@export var land_dip_max := 0.3
## Fall speed (m/s) above which landing hurts. 13 is roughly a 5 m drop.
@export var fall_damage_threshold := 13.0
@export var fall_damage_per_speed := 9.0

@export_group("Lean")
@export var lean_distance := 0.55
@export var lean_angle := 9.0
@export var lean_speed := 8.0

@export_group("Combat")
@export var sword_damage := 9.0
@export var backstab_multiplier := 4.0
@export var sword_reach := 2.4
@export var attack_cost := 18.0
@export var attack_cooldown := 0.55
@export var block_cost := 35.0
## Stamina per second.
@export var sprint_cost := 20.0

@export_group("Grappling Hook")
@export var grapple_range := 36.0
@export var grapple_speed := 22.0
@export var grapple_cooldown_time := 0.4

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

# Camera feel state.
var bob_distance := 0.0
var bob_weight := 0.0
var land_dip := 0.0
var lean := 0.0
var tilt := 0.0
var look_delta := Vector2.ZERO
var was_on_floor := true

var shake_time := 0.0
var shake_strength := 0.0

var collider: CollisionShape3D
var capsule: CapsuleShape3D
var head: Node3D
var camera: Camera3D
## Holds the sword and shield so they can sway as one.
var hands: Node3D
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
	capsule.height = stand_height
	collider = CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = stand_height * 0.5
	add_child(collider)

	head = Node3D.new()
	head.position.y = stand_height - eye_drop
	add_child(head)
	camera = Camera3D.new()
	camera.fov = fov
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
	# Sword on the right, shield on the left, both held in `hands` on the camera.
	hands = Node3D.new()
	camera.add_child(hands)
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.36, -0.36, -0.6)
	hands.add_child(sword_pivot)
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
	hands.add_child(shield_pivot)
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
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_delta += event.relative
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-88), deg_to_rad(88))


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

	# A grapple pull isn't a fall, so it never counts as a hard landing.
	var fall_speed := 0.0 if grappling else -velocity.y
	was_on_floor = is_on_floor()
	if grappling:
		_process_grapple(delta)
	elif mantling:
		_process_mantle(delta)
	else:
		_process_walk(input_dir, delta)
	if is_on_floor() and not was_on_floor and not mantling:
		_on_land(fall_speed)

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
	_update_camera_feel(input_dir, delta)

	if global_position.y < -30.0:
		die()


func _process_walk(input_dir: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not input_locked and Input.is_action_just_pressed("jump"):
		# Thief-style: jump at a ledge to climb it, otherwise just jump.
		if _try_mantle(true, 0.6):
			return
		if is_on_floor() and not crouching:
			velocity.y = jump_velocity

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	if blocking:
		speed *= 0.6

	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := dir * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if is_on_floor():
		# Weighty: build up to speed, then slide a little when stopping.
		var rate := acceleration if dir != Vector3.ZERO else deceleration
		horizontal = horizontal.move_toward(target, rate * delta)
	elif dir != Vector3.ZERO:
		# Light air control that never kills momentum from a grapple hop.
		horizontal = horizontal.move_toward(target, air_control * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _update_crouch(want: bool, delta: float) -> void:
	if not want and crouching:
		# Only stand if there's room above.
		var q := PhysicsShapeQueryParameters3D.new()
		var probe := SphereShape3D.new()
		probe.radius = 0.3
		q.shape = probe
		q.transform = Transform3D(Basis(), global_position + Vector3(0, stand_height - 0.3, 0))
		q.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(q, 1).size() > 0:
			want = true
	crouching = want
	var h := crouch_height if crouching else stand_height
	capsule.height = h
	collider.position.y = h * 0.5
	head.position.y = lerpf(head.position.y, h - eye_drop, minf(delta * 10.0, 1.0))


func _update_stamina(delta: float) -> void:
	if sprinting and velocity.length() > 0.5:
		stamina -= sprint_cost * delta
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
	attack_timer = attack_cooldown
	attack_anim = 1.0
	_spend_stamina(attack_cost)
	noise_radius = maxf(noise_radius, 8.0)
	await get_tree().create_timer(0.12).timeout
	if dead:
		return
	var fwd := -camera.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var to_e: Vector3 = e.global_position + Vector3(0, 1.0, 0) - camera.global_position
		if to_e.length() > sword_reach + 0.5:
			continue
		if fwd.dot(to_e.normalized()) < 0.5:
			continue
		var dmg := sword_damage
		if e.is_unaware_of_behind(global_position):
			dmg *= backstab_multiplier
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
		if stamina >= block_cost:
			_spend_stamina(block_cost)
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
	var to := from - camera.global_transform.basis.z * grapple_range
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
	velocity = to_target.normalized() * grapple_speed
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
	grapple_cooldown = grapple_cooldown_time
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


func _on_land(fall_speed: float) -> void:
	if fall_speed > land_dip_threshold:
		land_dip = minf(land_dip + (fall_speed - land_dip_threshold) * land_dip_per_speed, land_dip_max)
		noise_radius = maxf(noise_radius, fall_speed * 0.9)
		footstep.emit(fall_speed > 8.0)
	if fall_speed > fall_damage_threshold and not dead:
		hp -= (fall_speed - fall_damage_threshold) * fall_damage_per_speed
		shake(0.3, 0.1)
		health_changed.emit(hp, max_hp)
		took_hit.emit()
		if hp <= 0.0:
			die()


## Head bob, landing dip, strafe tilt, lean and weapon sway.
func _update_camera_feel(input_dir: Vector2, delta: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var on_ground := is_on_floor() and not grappling and not mantling

	# Bob is driven by distance walked, so it always matches the footsteps.
	var target_weight := 0.0
	if head_bob_enabled and on_ground and ground_speed > 0.3:
		target_weight = clampf(ground_speed / walk_speed, 0.0, sprint_bob_scale)
		if crouching:
			target_weight *= crouch_bob_scale
	bob_weight = lerpf(bob_weight, target_weight, minf(delta * 8.0, 1.0))
	if on_ground:
		var before := bob_distance
		bob_distance += ground_speed * delta
		# One footstep every half stride, at the bottom of each bob.
		var half := stride_length * 0.5
		if ground_speed > 0.5 and floorf(before / half) != floorf(bob_distance / half):
			footstep.emit(sprinting)
	var phase := bob_distance / stride_length * TAU
	var bob_y := -absf(sin(phase)) * bob_height * bob_weight
	var bob_x := sin(phase) * bob_sway * bob_weight

	land_dip = move_toward(land_dip, 0.0, delta * 1.2)

	# Lean (Thief's Q/E peek), stopped short of walls.
	var want_lean := 0.0
	if not input_locked and on_ground and not sprinting:
		want_lean = Input.get_axis("lean_left", "lean_right")
	if want_lean != 0.0:
		var side := global_transform.basis.x * signf(want_lean)
		var from := head.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + side * (lean_distance + 0.25), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var room: float = maxf(from.distance_to(hit.position) - 0.25, 0.0)
			want_lean *= room / lean_distance
	lean = lerpf(lean, want_lean, minf(delta * lean_speed, 1.0))

	tilt = lerpf(tilt, -input_dir.x * strafe_tilt if on_ground else 0.0, minf(delta * 6.0, 1.0))

	camera.position = Vector3(bob_x + lean * lean_distance, bob_y - land_dip, 0.0)
	camera.rotation.z = deg_to_rad(-lean * lean_angle + tilt)

	# Hands trail the view a touch and counter the bob, so they feel held.
	var sway_target := Vector3(-look_delta.x, look_delta.y, 0.0) * 0.0006 * weapon_sway
	sway_target += Vector3(-bob_x * 0.5, -bob_y * 0.6 + land_dip * 0.4, 0.0) * weapon_sway
	sway_target = sway_target.clamp(Vector3(-0.06, -0.06, 0), Vector3(0.06, 0.06, 0))
	hands.position = hands.position.lerp(sway_target, minf(delta * 10.0, 1.0))
	look_delta = Vector2.ZERO


func _update_viewmodel(delta: float) -> void:
	attack_anim = maxf(attack_anim - delta * 3.5, 0.0)
	# Swing: a quick chop from upper right to lower left.
	var swing := sin(attack_anim * PI)
	sword_pivot.rotation_degrees = Vector3(-20 - swing * 75.0, swing * 25.0, -12 + swing * 40.0)
	var shield_target := Vector3(-0.18, -0.2, -0.45) if blocking else Vector3(-0.5, -0.42, -0.62)
	shield_pivot.position = shield_pivot.position.lerp(shield_target, minf(delta * 14.0, 1.0))
	shield_pivot.rotation_degrees.y = lerpf(shield_pivot.rotation_degrees.y, 5.0 if blocking else 25.0, minf(delta * 14.0, 1.0))
