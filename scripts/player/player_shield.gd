class_name PlayerShield
extends Node
## Hold L1 / RMB to raise the shield. Blows from the front, within the
## block arc, are caught; blows from the side or behind still land. While
## the shield is up Jeffrey moves slower and can't attack. A raised shield
## can't interrupt a swing that's already under way. No parry yet.

signal raised_changed(up: bool)
signal blocked(info: DamageInfo)

## Width of the protected cone in front of Jeffrey, in degrees.
@export_range(10.0, 360.0, 5.0) var block_arc_degrees := 120.0
## Damage that still gets through a block, as a fraction.
@export_range(0.0, 1.0, 0.05) var blocked_damage_multiplier := 0.15
## Knockback that still gets through a block, as a fraction.
@export_range(0.0, 1.0, 0.05) var blocked_knockback_multiplier := 0.4
## Movement speed with the shield up, as a fraction.
@export_range(0.0, 1.0, 0.05) var move_multiplier := 0.55

var player: CharacterBody3D
var raised := false


func setup(p: CharacterBody3D) -> void:
	player = p


func physics_update(_delta: float) -> void:
	var want: bool = player.input.block_held and player.can_block()
	if want != raised:
		raised = want
		raised_changed.emit(raised)


## Does a raised shield cover a blow travelling along `direction`?
func covers(direction: Vector3) -> bool:
	if not raised:
		return false
	var to_attacker := -direction
	to_attacker.y = 0.0
	if to_attacker.length() < 0.001:
		return false
	var facing := -player.global_basis.z
	facing.y = 0.0
	var angle := rad_to_deg(facing.normalized().angle_to(to_attacker.normalized()))
	return angle <= block_arc_degrees * 0.5


## Called for every incoming blow. Marks it blocked and softens it if the
## shield is in the way.
func try_block(info: DamageInfo) -> bool:
	if info.kind == "fall" or not covers(info.direction):
		return false
	info.blocked = true
	blocked.emit(info)
	return true
