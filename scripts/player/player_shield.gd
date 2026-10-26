class_name PlayerShield
extends Node
## Hold L1 / RMB to raise a medium shield. It takes Raise Time to come up;
## once up, blows from the front, within the block arc, are caught and
## cost stamina; blows from the side or behind still land. If a blocked
## blow costs more stamina than is left, the guard breaks: the shield is
## knocked aside and Jeffrey can't attack or block for a moment. While the
## shield is up Jeffrey moves slower and can't attack. A raised shield
## can't interrupt a swing that's already under way. There is no parry.

signal raised_changed(up: bool)
signal blocked(info: DamageInfo)
signal guard_broken(info: DamageInfo)

## Seconds from pressing block until the shield actually blocks.
@export var raise_time := 0.15
## Width of the protected cone in front of Jeffrey, in degrees.
@export_range(10.0, 360.0, 5.0) var block_arc_degrees := 120.0
## Damage that still gets through a successful block (0 = blocks all of it).
@export_range(0.0, 1.0, 0.05) var blocked_damage_multiplier := 0.0
## Knockback that still gets through a block, as a fraction.
@export_range(0.0, 1.0, 0.05) var blocked_knockback_multiplier := 0.3
## Movement speed with the shield up, as a fraction of walking speed.
@export_range(0.0, 1.0, 0.05) var move_multiplier := 0.6

@export_group("Guard Break")
## How long a broken guard stops attacking and blocking.
@export var guard_break_duration := 1.1
## Damage that gets through when the guard breaks, as a fraction.
@export_range(0.0, 1.0, 0.05) var guard_break_damage_multiplier := 0.5
## Shove when the guard breaks, in m/s.
@export var guard_break_knockback := 3.0

var player: CharacterBody3D
## The shield is up (or coming up).
var raised := false
## 0..1, how far up the shield is. It blocks only at 1.
var raise_progress := 0.0
var guard_break_timer := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p


## Fully up and able to catch a blow.
func guarding() -> bool:
	return raised and raise_progress >= 1.0


func guard_broken_now() -> bool:
	return guard_break_timer > 0.0


func physics_update(delta: float) -> void:
	guard_break_timer = maxf(guard_break_timer - delta, 0.0)
	var want: bool = player.input.block_held and player.can_block()
	if want != raised:
		raised = want
		raised_changed.emit(raised)
	if raised:
		raise_progress = minf(raise_progress + delta / maxf(raise_time, 0.001), 1.0)
	else:
		raise_progress = maxf(raise_progress - delta / maxf(raise_time, 0.001), 0.0)


## Does the shield cover a blow travelling along `direction`?
func covers(direction: Vector3) -> bool:
	if not guarding():
		return false
	var to_attacker := -direction
	to_attacker.y = 0.0
	if to_attacker.length() < 0.001:
		return false
	var facing := -player.global_basis.z
	facing.y = 0.0
	var angle := rad_to_deg(facing.normalized().angle_to(to_attacker.normalized()))
	return angle <= block_arc_degrees * 0.5


## Called for every incoming blow. Marks it blocked if the shield is in the
## way and pays the stamina. Returns "blocked", "guard_break" or "" (not
## blocked).
func try_block(info: DamageInfo) -> String:
	if info.kind in ["fall", "fire"] or not covers(info.direction):
		return ""
	info.blocked = true
	var st: PlayerStamina = player.stamina
	if st.spend(st.block_cost):
		blocked.emit(info)
		return "blocked"
	# Not enough stamina to hold the blow: the guard breaks.
	guard_break_timer = guard_break_duration
	raised = false
	raise_progress = 0.0
	raised_changed.emit(false)
	guard_broken.emit(info)
	return "guard_break"
