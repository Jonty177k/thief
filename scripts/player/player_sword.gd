class_name PlayerSword
extends Node
## R1 / LMB light attack and R2 / F heavy attack with a one-handed
## broadsword. Each swing has a windup, active frames (when it can hit) and
## a recovery, and is committed: once started, the windup and active
## frames always play out, and nothing but a dash (from recovery) cuts it
## short. While active, the blade is swept through its arc as a series of
## shape casts from the eye, so it stops at walls and hits each target at
## most once per swing. The camera stays yours; there is no lock-on or
## auto-aim.

signal swing_started(kind: String, index: int)
## The active frames began (the blade is moving and can hit).
signal swing_active(kind: String)
signal hit_landed(target: Node, info: DamageInfo)
## The blade hit level geometry instead of a target.
signal hit_wall(point: Vector3)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

@export_group("Light Attack")
@export var light_windup := 0.18
## Seconds the blade can hit.
@export var light_active := 0.16
@export var light_recovery := 0.32
@export var light_damage := 25.0
## Reach from the eye, in metres.
@export var light_range := 2.0
@export var light_knockback := 2.0
## Movement speed while swinging, as a fraction of normal.
@export_range(0.0, 1.0, 0.05) var light_move_multiplier := 0.55

@export_group("Light Combo")
## Light attacks chain into a combo of alternating swings.
@export var light_chaining := true
@export_range(1, 6) var light_chain_max := 3
## Presses during the active frames or recovery are remembered (buffered)
## and the next swing starts at this point through the recovery (0..1).
## 0 chains as soon as the blade stops; 1 waits for the full recovery.
@export_range(0.0, 1.0, 0.05) var combo_chain_point := 0.3

@export_group("Heavy Attack")
@export var heavy_windup := 0.55
@export var heavy_active := 0.2
@export var heavy_recovery := 0.55
@export var heavy_damage := 55.0
@export var heavy_range := 2.2
@export var heavy_knockback := 6.0
@export_range(0.0, 1.0, 0.05) var heavy_move_multiplier := 0.55

@export_group("Charged Heavy")
## Holding heavy through the windup keeps winding up, for more damage.
@export var charged_heavy_enabled := false
## Extra windup time for a full charge.
@export var charge_time := 0.8
## Damage multiplier at full charge.
@export var charge_damage_multiplier := 1.6

@export_group("Hit Detection")
## Thickness of the swept blade, in metres.
@export var blade_radius := 0.18
## Shape casts per physics tick while the blade is active.
@export_range(1, 12) var sweep_samples := 4
## Presses this long before an attack can start still count.
@export var input_buffer := 0.15

var player: CharacterBody3D
var phase := Phase.IDLE
var kind := ""
## 0-based swing number within a light chain.
var chain_index := 0
var phase_time := 0.0
## 0..1 charge of a held heavy attack.
var charge := 0.0
## The blade is active this tick (for the debug panel).
var hitbox_active := false
## Last tick's sweep, as [from, to] pairs, for the hitbox debug view.
var debug_sweeps: Array = []
var _arc_prev := 0.0
var _hit: Array[Node] = []
var _blocked_by_wall := false
var _buffered := ""
var _buffer_timer := 0.0
## A press during this swing's active frames or recovery, held until it can be used.
var _queued := ""


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


## Windup and active frames can't be cancelled.
func committed() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE


func phase_name() -> String:
	return Phase.keys()[phase]


func move_multiplier() -> float:
	if not attacking():
		return 1.0
	return heavy_move_multiplier if kind == "heavy" else light_move_multiplier


## Progress through the current phase, 0..1 (for the viewmodel).
func phase_progress() -> float:
	return clampf(phase_time / maxf(_phase_length(), 0.001), 0.0, 1.0)


func blocked_by_wall() -> bool:
	return _blocked_by_wall


func cancel() -> void:
	phase = Phase.IDLE
	kind = ""
	chain_index = 0
	charge = 0.0
	_queued = ""
	hitbox_active = false


func physics_update(delta: float) -> void:
	var inp: PlayerInput = player.input
	hitbox_active = false
	debug_sweeps.clear()
	var pressed := ""
	if inp.light_pressed:
		pressed = "light"
	elif inp.heavy_pressed:
		pressed = "heavy"
	if pressed != "":
		if attacking() and phase != Phase.WINDUP:
			_queued = pressed
		else:
			_buffered = pressed
			_buffer_timer = input_buffer
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered = ""

	if not attacking():
		var want := _queued if _queued != "" else _buffered
		if want != "" and player.can_attack() and _pay(want):
			_start(want, 0)
		_queued = ""
		_buffered = ""
	elif _queued == "light" and is_light() and in_recovery() and light_chaining \
			and phase_progress() >= combo_chain_point and chain_index + 1 < light_chain_max \
			and player.can_attack(true) and _pay("light"):
		_start("light", chain_index + 1)

	if not attacking():
		return
	phase_time += delta
	if phase == Phase.WINDUP and kind == "heavy" and charged_heavy_enabled and inp.heavy_held \
			and phase_time >= heavy_windup and charge < 1.0:
		# Hold at the top of the windup while the button is held, up to a full charge.
		charge = minf(charge + delta / maxf(charge_time, 0.01), 1.0)
		phase_time = heavy_windup
		if charge < 1.0:
			return
	if phase == Phase.ACTIVE:
		_sweep(clampf(phase_time / _phase_length(), 0.0, 1.0))
	if phase_time >= _phase_length():
		phase_time -= _phase_length()
		match phase:
			Phase.WINDUP:
				phase = Phase.ACTIVE
				phase_time = minf(phase_time, delta)
				_arc_prev = 0.0
				swing_active.emit(kind)
				_sweep(clampf(phase_time / _phase_length(), 0.0, 1.0))
			Phase.ACTIVE:
				phase = Phase.RECOVERY
			Phase.RECOVERY:
				var queued := _queued
				cancel()
				# A heavy (or a light past the end of a combo) pressed during
				# the swing starts as soon as this one is over.
				_queued = queued


func _pay(k: String) -> bool:
	var st: PlayerStamina = player.stamina
	var cost := st.heavy_attack_cost if k == "heavy" else st.light_attack_cost
	if not st.can_afford(cost):
		return false
	st.spend(cost)
	return true


func _start(k: String, index: int) -> void:
	kind = k
	chain_index = index
	phase = Phase.WINDUP
	phase_time = 0.0
	charge = 0.0
	_queued = ""
	_buffered = ""
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
## Light swings cut diagonally across, alternating direction in a combo;
## heavy swings chop from high to low. The viewmodel follows the same arc.
func blade_direction(s: float) -> Vector3:
	var yaw := 0.0
	var pitch := 0.0
	if kind == "heavy":
		yaw = lerpf(8.0, -4.0, s)
		pitch = lerpf(40.0, -35.0, s)
	else:
		var from := 55.0 if chain_index % 2 == 0 else -55.0
		yaw = lerpf(from, -from, s)
		pitch = lerpf(12.0, -12.0, s) if chain_index % 2 == 0 else lerpf(-8.0, 10.0, s)
	return (Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))) * Vector3.FORWARD


## Sweep the blade from where it was last tick to arc position `s`.
func _sweep(s: float) -> void:
	if _blocked_by_wall:
		return
	hitbox_active = true
	var cam: Camera3D = player.camera
	var space := player.get_world_3d().direct_space_state
	var reach := light_range if kind == "light" else heavy_range
	var origin := cam.global_position
	var shape := SphereShape3D.new()
	shape.radius = blade_radius
	for i in range(1, sweep_samples + 1):
		var a := lerpf(_arc_prev, s, float(i) / sweep_samples)
		var dir: Vector3 = cam.global_basis * blade_direction(a)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), origin)
		q.motion = dir * reach
		q.collision_mask = 1 | 4
		q.exclude = [player.get_rid()]
		var res := space.cast_motion(q)
		var stop := origin + dir * reach * res[1]
		debug_sweeps.append([origin, stop if res[1] < 1.0 else origin + dir * reach])
		if res[1] >= 1.0:
			continue
		q.transform = Transform3D(Basis(), stop)
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
			# Steel on stone: the swing stops here, and still recovers.
			_blocked_by_wall = true
			hit_wall.emit(stop)
			break
	_arc_prev = s


func _strike(target: Node, origin: Vector3) -> void:
	if _hit.has(target):
		return
	_hit.append(target)
	var heavy := kind == "heavy"
	var dmg := heavy_damage if heavy else light_damage
	if heavy and charge > 0.0:
		dmg *= lerpf(1.0, charge_damage_multiplier, charge)
	var info := DamageInfo.make(dmg, player, origin,
		(target as Node3D).global_position, heavy_knockback if heavy else light_knockback, kind)
	target.receive_damage(info)
	hit_landed.emit(target, info)
