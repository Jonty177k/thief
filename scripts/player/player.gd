class_name JBDPlayer
extends CharacterBody3D
## Jeffrey: the player root. It owns health and the action state, decides
## which actions may start (see the can_* functions), and runs the
## components in a fixed order each physics tick:
##   Input -> Stamina -> Loadout -> Dash -> Sword -> Shield -> Bow -> Tool
##   -> Interaction -> Movement -> Stealth
## Tuning lives on the component nodes: select Movement, Dash, Sword,
## Shield, Stamina, Loadout, Bow, Interaction or Head (camera) in
## scenes/player.tscn.

signal health_changed(hp: float, max_hp: float)
signal took_hit(info: DamageInfo)
signal died
signal state_changed(state: State)
## A short message for the HUD ("Picked up ...").
signal notice(text: String)
signal footstep(loud: bool)

enum State { NORMAL, CROUCHING, AIRBORNE, DASHING, LIGHT_ATTACK, HEAVY_ATTACK, BLOCKING, INTERACTING, CLIMBING, DEAD, GUARD_BROKEN, AIMING_BOW, SWITCHING_WEAPON, HOOK_PULLING, WIRE_TRAVERSAL }

@export var max_hp := 100.0
## Falling below this height kills Jeffrey.
@export var kill_height := -30.0

var hp := 100.0
var dead := false
var state := State.NORMAL
## Set by menus and cutscenes: stops all player input, including look.
var input_locked := false:
	set(v):
		input_locked = v
		if input:
			input.enabled = not v and not dead

@onready var input: PlayerInput = $Input
@onready var movement: PlayerMovement = $Movement
@onready var dash: PlayerDash = $Dash
@onready var sword: PlayerSword = $Sword
@onready var shield: PlayerShield = $Shield
@onready var stamina: PlayerStamina = $Stamina
@onready var loadout: PlayerLoadout = $Loadout
@onready var bow: PlayerBow = $Bow
## The hookshot / wire gun, if Jeffrey has one.
@onready var tool: Node = get_node_or_null("Hookshot")
@onready var interaction: PlayerInteraction = $Interaction
@onready var stealth: PlayerStealth = $Stealth
@onready var camera_rig: PlayerCamera = $Head
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var viewmodel: PlayerViewmodel = $Head/Camera3D/Viewmodel
@onready var collider: CollisionShape3D = $Collision
@onready var capsule: CapsuleShape3D = $Collision.shape
## A downward ray under the capsule: Jeffrey's "leg", which rides up steps.
@onready var leg: CollisionShape3D = $Leg
@onready var leg_shape: SeparationRayShape3D = $Leg.shape
@onready var ground_ray: RayCast3D = $GroundRay
@onready var sfx: AudioStreamPlayer = $Sfx

## An optional add-on (the grappling hook) that takes over movement while
## its `active` is true. Not part of the core controller.
var traversal: Node

## Kept for enemies and the light gem.
var visibility: float:
	get:
		return stealth.visibility
var noise_radius: float:
	get:
		return stealth.noise_radius


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	for c in [movement, dash, sword, shield, stamina, loadout, bow, interaction, stealth, camera_rig, viewmodel]:
		c.setup(self)
	if tool:
		tool.setup(self)
	ground_ray.add_exception(self)
	dash.started.connect(func(_d: Vector3) -> void:
		bow.cancel()
		if sword.attacking():
			sword.cancel())
	bow.draw_started.connect(func() -> void: _play(Sfx.creak(), -8.0))
	bow.fired.connect(func(_a: Arrow) -> void: _play(Sfx.twang(), -4.0))
	sword.swing_started.connect(func(_k: String, _i: int) -> void:
		_play(Sfx.whoosh(), -6.0)
		stealth.make_noise(6.0))
	sword.hit_landed.connect(func(_t: Node, info: DamageInfo) -> void:
		_play(Sfx.thud())
		camera_rig.shake(0.08, 0.02 if info.kind == "light" else 0.05))
	sword.hit_wall.connect(func(_p: Vector3) -> void: _play(Sfx.scrape(), -4.0))
	shield.blocked.connect(func(_i: DamageInfo) -> void:
		_play(Sfx.clank())
		camera_rig.shake(0.12, 0.03))
	shield.guard_broken.connect(func(_i: DamageInfo) -> void:
		_play(Sfx.clank(), 3.0)
		camera_rig.shake(0.3, 0.06))
	movement.landed.connect(func(speed: float) -> void:
		camera_rig.on_landed(speed)
		if speed > 3.0:
			stealth.make_noise(speed * 0.9))
	movement.footstep.connect(func(loud: bool) -> void: footstep.emit(loud))


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	input.poll()
	stamina.physics_update(delta)
	loadout.physics_update(delta)
	dash.physics_update(delta)
	sword.physics_update(delta)
	shield.physics_update(delta)
	bow.physics_update(delta)
	if tool:
		tool.physics_update(delta)
	interaction.physics_update(delta)
	if tool and tool.controls_movement():
		tool.move(delta)
	elif traversal and traversal.active:
		traversal.physics_update(delta)
	else:
		movement.physics_update(delta)
	stealth.physics_update(delta)
	_update_state()
	if global_position.y < kill_height:
		die()


func _update_state() -> void:
	var s := State.NORMAL
	if dead:
		s = State.DEAD
	elif tool and tool.state == PlayerHookshot.State.HOOK_PULLING:
		s = State.HOOK_PULLING
	elif tool and tool.state == PlayerHookshot.State.WIRE_TRAVERSAL:
		s = State.WIRE_TRAVERSAL
	elif dash.active:
		s = State.DASHING
	elif sword.is_heavy():
		s = State.HEAVY_ATTACK
	elif sword.is_light():
		s = State.LIGHT_ATTACK
	elif shield.guard_broken_now():
		s = State.GUARD_BROKEN
	elif bow.drawing:
		s = State.AIMING_BOW
	elif loadout.switching():
		s = State.SWITCHING_WEAPON
	elif shield.raised:
		s = State.BLOCKING
	elif interaction.interacting():
		s = State.INTERACTING
	elif movement.ladder:
		s = State.CLIMBING
	elif not is_on_floor() and not (traversal and traversal.active):
		s = State.AIRBORNE
	elif movement.crouching:
		s = State.CROUCHING
	if s != state:
		state = s
		state_changed.emit(s)


func state_name() -> String:
	return State.keys()[state]


# --- Action priority --------------------------------------------------------
# One place decides what may start, so actions never fight each other.

func _busy_elsewhere() -> bool:
	return dead or (traversal != null and traversal.active) or (tool != null and tool.controls_movement())


## No dash during a heavy attack (windup, swing or recovery), during a light
## swing (its recovery can be cancelled), mid-air, on a ladder, or while
## using something.
func can_dash() -> bool:
	if _busy_elsewhere() or not dash.available() or movement.ladder or interaction.interacting():
		return false
	if not dash.allow_in_air and not is_on_floor() and movement.coyote_timer <= 0.0:
		return false
	if sword.is_heavy():
		return false
	if sword.is_light() and not (sword.in_recovery() and dash.cancels_light_recovery):
		return false
	return stamina.can_afford(stamina.dodge_cost)


## No attacks with the shield up, with a broken guard, mid-dash, on a
## ladder or while using something. `chaining` allows a light attack to
## follow another. Stamina is checked by the sword.
func can_attack(chaining := false) -> bool:
	if _busy_elsewhere() or not loadout.is_ready(PlayerLoadout.Slot.SWORD_SHIELD) or shield.raised \
			or shield.guard_broken_now() or dash.active or movement.ladder or interaction.interacting():
		return false
	return chaining or not sword.attacking()


## Raising the shield never interrupts a swing or a dash, and a broken
## guard can't be raised until it recovers.
func can_block() -> bool:
	return not _busy_elsewhere() and not sword.attacking() and not dash.active and not movement.ladder \
		and not shield.guard_broken_now() and loadout.is_ready(PlayerLoadout.Slot.SWORD_SHIELD)


## The bow draws only when it's in hand, on the ground or a ladder-free
## moment, and not mid-dash.
func can_draw_bow() -> bool:
	return not _busy_elsewhere() and loadout.is_ready(PlayerLoadout.Slot.BOW) and not dash.active \
		and not movement.ladder and not interaction.interacting()


## The hookshot fires (and the wire gun anchors) only when it's in hand and
## Jeffrey isn't dashing, climbing or using something.
func can_use_tool() -> bool:
	return not dead and loadout.is_ready(PlayerLoadout.Slot.TOOL) and not dash.active \
		and not movement.ladder and not interaction.interacting()


## Switching weapons waits for swings, draws and tools to finish.
func can_switch_weapon() -> bool:
	return not dead and not sword.attacking() and not bow.drawing and not dash.active \
		and not (tool != null and tool.busy())


func can_jump() -> bool:
	return not dead and not dash.active and not sword.is_heavy()


func can_interact() -> bool:
	return not _busy_elsewhere() and not sword.attacking() and not dash.active and not shield.raised


func can_run() -> bool:
	return not shield.raised and not bow.drawing


func can_climb() -> bool:
	return not _busy_elsewhere() and not dash.active and not sword.attacking()


## Speed scale from the shield, the sword and the bow.
func speed_multiplier() -> float:
	return (shield.move_multiplier if shield.raised else 1.0) * sword.move_multiplier() * bow.move_multiplier()


# --- Health -----------------------------------------------------------------

## The damage interface (see DamageInfo). Frontal blows inside the shield's
## arc are blocked (and cost stamina); blows from the side or behind land
## in full. A dodge's i-frames ignore blows entirely.
func receive_damage(info: DamageInfo) -> void:
	if dead:
		return
	if dash.invulnerable() and info.kind != "fall":
		info.dodged = true
		return
	var amount := info.amount
	var knock := info.knockback
	match shield.try_block(info):
		"blocked":
			amount *= shield.blocked_damage_multiplier
			knock *= shield.blocked_knockback_multiplier
		"guard_break":
			amount *= shield.guard_break_damage_multiplier
			knock = maxf(knock, shield.guard_break_knockback)
		_:
			if info.kind != "fall":
				camera_rig.shake(0.2, 0.05)
	hp -= amount
	if knock > 0.0:
		velocity += info.direction * knock + (Vector3.ZERO if info.blocked else Vector3.UP * 2.0)
	health_changed.emit(hp, max_hp)
	took_hit.emit(info)
	if hp <= 0.0:
		die()


## Older call used by the first prototype's enemies.
func take_hit(damage: float, from: Vector3) -> void:
	receive_damage(DamageInfo.make(damage, null, from, global_position, 6.0, "enemy"))


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	input.enabled = false
	input.clear()
	sword.cancel()
	bow.cancel()
	if tool:
		tool.cancel()
	dash.active = false
	if traversal and traversal.has_method("cancel"):
		traversal.cancel()
	_update_state()
	health_changed.emit(hp, max_hp)
	died.emit()


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	hp = max_hp
	dead = false
	input.enabled = not input_locked
	stamina.refill()
	shield.guard_break_timer = 0.0
	bow.cancel()
	if tool:
		tool.cancel()
	_update_state()
	health_changed.emit(hp, max_hp)


func heal_full() -> void:
	hp = max_hp
	stamina.refill()
	health_changed.emit(hp, max_hp)


func shake(duration: float, strength: float) -> void:
	camera_rig.shake(duration, strength)


func enter_shadow() -> void:
	stealth.shadow_zones += 1


func exit_shadow() -> void:
	stealth.shadow_zones = maxi(stealth.shadow_zones - 1, 0)


## Metres from the feet to the ground below (INF if nothing is close).
func ground_distance() -> float:
	ground_ray.force_raycast_update()
	if not ground_ray.is_colliding():
		return INF
	return global_position.y - ground_ray.get_collision_point().y


func _play(stream: AudioStream, volume_db := 0.0) -> void:
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.play()
