class_name PlayerSword
extends Node
## R1 / LMB light attack and R2 / F heavy attack. Each swing has a windup,
## active frames (when it can hit) and a recovery. While active, the blade
## is swept through its arc as a shape cast from the eye, so it stops at
## walls and hits each target at most once per swing. The camera stays
## yours throughout. No lock-on, stamina or combo trees.

signal swing_started(kind: String, index: int)
signal hit_landed(target: Node, info: DamageInfo)
## The blade hit level geometry instead of a target.
signal hit_wall(point: Vector3)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

@export_group("Light Attack")
@export var light_windup := 0.08
## Seconds the blade can hit (0.12 s is about 7 frames at 60 Hz).
@export var light_active := 0.12
@export var light_recovery := 0.22
@export var light_damage := 10.0
## Reach from the eye, in metres.
@export var light_range := 2.0
@export var light_knockback := 2.0
## Movement speed while swinging, as a fraction.
@export_range(0.0, 1.0, 0.05) var light_move_multiplier := 0.75
## Pressing light again during recovery chains another swing.
@export var light_chaining := true
@export_range(1, 6) var light_chain_max := 3

@export_group("Heavy Attack")
@export var heavy_windup := 0.42
@export var heavy_active := 0.16
@export var heavy_recovery := 0.55
@export var heavy_damage := 30.0
@export var heavy_range := 2.4
@export var heavy_knockback := 7.0
@export_range(0.0, 1.0, 0.05) var heavy_move_multiplier := 0.35

@export_group("Hit Detection")
## Thickness of the swept blade, in metres.
@export var blade_radius := 0.18
## Presses this long before an attack can start still count.
@export var input_buffer := 0.15

var player: CharacterBody3D
var phase := Phase.IDLE
var kind := ""
## 0-based swing number within a light chain.
var chain_index := 0
var phase_time := 0.0
var _arc_prev := 0.0
var _hit: Array[Node] = []
var _blocked_by_wall := false
var _buffered := ""
var _buffer_timer := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p


func attacking() -> bool:
	return phase != Phase.IDLE


func is_heavy() -> bool:
	return attacking() and kind == "heavy"


func is_light() -> bool:
	return attacking() and kind == "light"


func in_recovery() -> bool:
	return phase == Phase.RECOVERY


func phase_name() -> String:
	return Phase.keys()[phase]


func move_multiplier() -> float:
	if not attacking():
		return 1.0
	return heavy_move_multiplier if kind == "heavy" else light_move_multiplier


## Progress through the current phase, 0..1 (for the viewmodel).
func phase_progress() -> float:
	return clampf(phase_time / maxf(_phase_length(), 0.001), 0.0, 1.0)


func cancel() -> void:
	phase = Phase.IDLE
	kind = ""
	chain_index = 0


func physics_update(delta: float) -> void:
	var inp: PlayerInput = player.input
	if inp.light_pressed:
		_buffered = "light"
		_buffer_timer = input_buffer
	elif inp.heavy_pressed:
		_buffered = "heavy"
		_buffer_timer = input_buffer
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered = ""

	if _buffered != "":
		if not attacking() and player.can_attack():
			_start(_buffered, 0)
			_buffered = ""
		elif _buffered == "light" and is_light() and in_recovery() and light_chaining \
				and chain_index + 1 < light_chain_max and player.can_attack(true):
			_start("light", chain_index + 1)
			_buffered = ""

	if not attacking():
		return
	phase_time += delta
	if phase == Phase.ACTIVE:
		_sweep(clampf(phase_time / _phase_length(), 0.0, 1.0))
	if phase_time >= _phase_length():
		phase_time -= _phase_length()
		match phase:
			Phase.WINDUP:
				phase = Phase.ACTIVE
				_arc_prev = 0.0
				_sweep(clampf(phase_time / _phase_length(), 0.0, 1.0))
			Phase.ACTIVE:
				phase = Phase.RECOVERY
			Phase.RECOVERY:
				cancel()


func _start(k: String, index: int) -> void:
	kind = k
	chain_index = index
	phase = Phase.WINDUP
	phase_time = 0.0
	_hit.clear()
	_blocked_by_wall = false
	swing_started.emit(k, index)


func _phase_length() -> float:
	match phase:
		Phase.WINDUP:
			return light_windup if kind == "light" else heavy_windup
		Phase.ACTIVE:
			return light_active if kind == "light" else heavy_active
		Phase.RECOVERY:
			return light_recovery if kind == "light" else heavy_recovery
	return 1.0


## The blade direction (camera space) at arc position `s` (0..1).
## Light swings cut sideways, alternating direction in a chain; heavy
## swings chop from high to low.
func blade_direction(s: float) -> Vector3:
	var yaw := 0.0
	var pitch := 0.0
	if kind == "heavy":
		pitch = lerpf(35.0, -30.0, s)
	else:
		var from := 50.0 if chain_index % 2 == 0 else -50.0
		yaw = lerpf(from, -from, s)
		pitch = lerpf(5.0, -10.0, s)
	return (Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))) * Vector3.FORWARD


## Sweep the blade from where it was last tick to arc position `s`.
func _sweep(s: float) -> void:
	if _blocked_by_wall:
		return
	var cam: Camera3D = player.camera
	var space := player.get_world_3d().direct_space_state
	var reach := light_range if kind == "light" else heavy_range
	var origin := cam.global_position
	var shape := SphereShape3D.new()
	shape.radius = blade_radius
	var samples := 4
	for i in range(1, samples + 1):
		var a := lerpf(_arc_prev, s, float(i) / samples)
		var dir: Vector3 = cam.global_basis * blade_direction(a)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), origin)
		q.motion = dir * reach
		q.collision_mask = 1 | 4
		q.exclude = [player.get_rid()]
		var res := space.cast_motion(q)
		if res[1] >= 1.0:
			continue
		q.transform = Transform3D(Basis(), origin + dir * reach * res[1])
		q.motion = Vector3.ZERO
		var hits := space.intersect_shape(q, 6)
		var struck_wall := false
		for h in hits:
			var receiver := DamageInfo.find_receiver(h.collider)
			if receiver and receiver != player:
				_strike(receiver, origin)
			elif receiver == null:
				struck_wall = true
		if struck_wall and hits.all(func(h): return DamageInfo.find_receiver(h.collider) == null):
			_blocked_by_wall = true
			hit_wall.emit(origin + dir * reach * res[1])
			break
	_arc_prev = s


func _strike(target: Node, origin: Vector3) -> void:
	if _hit.has(target):
		return
	_hit.append(target)
	var heavy := kind == "heavy"
	var info := DamageInfo.make(heavy_damage if heavy else light_damage, player, origin,
		(target as Node3D).global_position, heavy_knockback if heavy else light_knockback, kind)
	target.receive_damage(info)
	hit_landed.emit(target, info)
