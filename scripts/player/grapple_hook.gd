class_name GrappleHook
extends Node
## Optional add-on, not part of the core controller: the grappling hook
## from the first prototype. Main adds it to Jeffrey when the level allows
## it (JBDLevel.allow_grapple). G / middle mouse / R3 fires at brown wood
## (anything in the "grapple" group); press again or jump to let go. At the
## end of a pull Jeffrey clambers onto the ledge.

@export var grapple_range := 36.0
@export var grapple_speed := 22.0
@export var cooldown_time := 0.4

## True while the hook (or the clamber after it) is moving Jeffrey.
var active := false
## The crosshair is on something the hook can bite.
var aim_valid := false

var player: JBDPlayer
var pulling := false
var clambering := false
var point := Vector3.ZERO
var dir := Vector3.ZERO
var time := 0.0
var cooldown := 0.0
var rope: MeshInstance3D

var _clamber_dir := Vector3.ZERO
var _clamber_y := 0.0
var _clamber_time := 0.0
var _clamber_reach := 0.0
var _clamber_start := Vector3.ZERO


func _ready() -> void:
	player = get_parent()
	player.traversal = self
	rope = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.025
	rm.bottom_radius = 0.025
	rm.height = 1.0
	rm.radial_segments = 4
	rope.mesh = rm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.25)
	rope.material_override = mat
	rope.top_level = true
	rope.visible = false
	add_child(rope)


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	aim_valid = _aim_valid()
	if player.dead or not player.input.enabled:
		return
	if Input.is_action_just_pressed("grapple"):
		if pulling:
			_end(false)
		elif _can_fire():
			fire()


func _can_fire() -> bool:
	return cooldown <= 0.0 and not active and not player.dash.active and not player.sword.attacking() and player.movement.ladder == null


func _aim_ray() -> Dictionary:
	var from := player.camera.global_position
	var to := from - player.camera.global_basis.z * grapple_range
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or hit.collider.is_in_group("grapple"):
		return hit
	# Aim assist: a near miss just under or beside a wooden lip still counts.
	var probe := SphereShape3D.new()
	probe.radius = 0.7
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = probe
	sq.transform = Transform3D(Basis(), hit.position)
	sq.collision_mask = 1
	for r in space.intersect_shape(sq, 8):
		if r.collider.is_in_group("grapple"):
			hit.collider = r.collider
			return hit
	return hit


func _aim_valid() -> bool:
	var hit := _aim_ray()
	return not hit.is_empty() and hit.collider.is_in_group("grapple")


## Fire at whatever the crosshair is on. Returns false if it can't bite.
func fire() -> bool:
	var hit := _aim_ray()
	if hit.is_empty() or not hit.collider.is_in_group("grapple"):
		return false
	# Aim a little above and in front of the anchor so Jeffrey ends up on top.
	var n: Vector3 = hit.normal
	if n.y < -0.5:
		# Hooked the underside: hang just beside it, then hop up and over.
		var away: Vector3 = player.global_position - hit.position
		away.y = 0
		point = hit.position + away.normalized() * 0.9 + Vector3.DOWN * 0.4
	else:
		point = hit.position + n * 0.6 + Vector3.UP * 0.6
	dir = point - player.global_position
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else -player.global_basis.z
	pulling = true
	active = true
	time = 0.0
	rope.visible = true
	player.stealth.make_noise(6.0)
	return true


func cancel() -> void:
	pulling = false
	clambering = false
	active = false
	rope.visible = false


func physics_update(delta: float) -> void:
	if pulling:
		_pull(delta)
	elif clambering:
		_clamber(delta)
	else:
		active = false


func _pull(delta: float) -> void:
	time += delta
	var to_target := point - player.global_position
	player.velocity = to_target.normalized() * grapple_speed
	player.move_and_slide()
	_draw_rope(point - Vector3.UP * 0.6)
	var stuck := time > 0.3 and player.get_real_velocity().length() < 2.0
	if to_target.length() < 0.6 or stuck:
		_end(true)
	elif time > 3.0 or player.input.jump_pressed:
		_end(false)


func _end(arrived: bool) -> void:
	pulling = false
	rope.visible = false
	cooldown = cooldown_time
	active = false
	if arrived:
		if not _find_ledge():
			player.velocity = Vector3.UP * 8.0 + dir * 4.5
	else:
		player.velocity = player.velocity * 0.4 + Vector3.UP * 3.0


## Look around for a walkable top within reach to clamber onto.
func _find_ledge() -> bool:
	var space := player.get_world_3d().direct_space_state
	var facing := dir
	var best := -INF
	var found := false
	for i in 16:
		var a := i * TAU / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		var align := d.dot(facing)
		for r in [0.9, 1.7]:
			var from: Vector3 = player.global_position + d * r + Vector3.UP * 2.6
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.4, 1))
			if hit.is_empty() or hit.normal.y < 0.7:
				continue
			var rise: float = hit.position.y - player.global_position.y
			if rise < -0.3 or rise > 2.4:
				continue
			var score := rise * 1.5 + align
			# Prefer solid ground over a narrow beam top.
			var beyond: Vector3 = from + d * 1.0
			var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond, beyond + Vector3.DOWN * 3.4, 1))
			if hit2.is_empty() or absf(hit2.position.y - hit.position.y) > 0.3:
				score -= 2.0
			if score > best:
				best = score
				_clamber_dir = d
				_clamber_y = hit.position.y
				_clamber_reach = r + 0.4
				found = true
	if found:
		clambering = true
		active = true
		_clamber_time = 0.0
		_clamber_start = player.global_position
	return found


func _clamber(delta: float) -> void:
	_clamber_time += delta
	if player.global_position.y < _clamber_y + 0.15 and _clamber_time < 0.8:
		player.velocity = Vector3.UP * 7.0  # rise first, so the lip can't snag us
	else:
		player.velocity = _clamber_dir * 4.5 + Vector3.DOWN * 2.0
	player.move_and_slide()
	var p := player.global_position
	var travelled := Vector2(p.x - _clamber_start.x, p.z - _clamber_start.z).length()
	if _clamber_time > 1.2 or (travelled >= _clamber_reach and p.y > _clamber_y - 0.1):
		clambering = false
		active = false
		player.velocity = _clamber_dir * 2.0


func _draw_rope(anchor: Vector3) -> void:
	var cam := player.camera
	var start := cam.global_position + cam.global_basis * Vector3(0.25, -0.3, -0.3)
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
