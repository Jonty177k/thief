class_name EnemyAttack
extends Resource
## One attack an enemy can choose. Enemies hold a list of these and pick
## among the ones that fit (range, cooldown) by weight, so a new enemy type
## is mostly a new list. Edit them in the Inspector, or save them as .tres.

## Shown in the debug panel.
@export var name := "Slash"
## Seconds of telegraph before the blade moves.
@export var windup := 0.55
## Seconds the blade can hit.
@export var active := 0.2
## Seconds of vulnerability after the swing.
@export var recovery := 0.65
@export var damage := 35.0
@export var knockback := 4.0
## Only chosen when the target is between these distances (metres).
@export var min_range := 0.0
@export var max_range := 2.0
## Blade length from the shoulder, in metres.
@export var reach := 1.75
## Relative chance of being chosen among the attacks that fit.
@export var weight := 1.0
## Seconds before this attack can be chosen again.
@export var cooldown := 0.0
## Forward step during the active frames, in m/s (0 for none).
@export var lunge_speed := 0.0
## How fast the enemy keeps turning toward its target during the windup
## (degrees per second). Nothing during the swing itself, so sidesteps work.
@export var windup_tracking := 140.0

@export_group("Arc")
## Arm pose (degrees: pitch, yaw, roll) at the top of the windup...
@export var pose_windup := Vector3(70, -40, 0)
## ...and at the end of the swing. The blade sweeps between them.
@export var pose_finish := Vector3(-60, 40, 0)
