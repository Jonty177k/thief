class_name PlayerLoadout
extends Node
## Which weapon Jeffrey has in hand: sword and shield, the bow, or the
## hookshot / wire gun. Only one is out at a time. D-pad left / right /
## down (1 / 2 / 3) switch; a switch lowers one and raises the other over
## Switch Time, and nothing can attack, block or fire meanwhile.

signal switch_started(from: Slot, to: Slot)
signal changed(slot: Slot)

enum Slot { SWORD_SHIELD, BOW, TOOL }

## Seconds for a full switch (half to lower, half to raise).
@export var switch_time := 0.4
@export var starting_slot := Slot.SWORD_SHIELD
## Which slots Jeffrey has. A missing tool (no Hookshot node) is skipped.
@export var bow_unlocked := true
@export var tool_unlocked := true

var player: CharacterBody3D
## What's in hand (or, mid-switch, what's being lowered).
var current := Slot.SWORD_SHIELD
## What's coming up, mid-switch.
var pending := Slot.SWORD_SHIELD
var switch_timer := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p
	current = starting_slot
	pending = starting_slot


func switching() -> bool:
	return switch_timer > 0.0


## 0..1 through the switch: lowering until 0.5, raising after.
func switch_progress() -> float:
	return 1.0 - switch_timer / maxf(switch_time, 0.001) if switching() else 1.0


func is_ready(slot: Slot) -> bool:
	return current == slot and not switching()


func slot_name(slot: Slot = current) -> String:
	return ["Sword and shield", "Bow", "Hookshot"][slot]


func has_slot(slot: Slot) -> bool:
	match slot:
		Slot.BOW:
			return bow_unlocked and player.get("bow") != null
		Slot.TOOL:
			return tool_unlocked and player.get("tool") != null
	return true


## Start switching to `slot`. Returns false if that can't happen now.
func equip(slot: Slot) -> bool:
	if slot == current and not switching():
		return false
	if not has_slot(slot) or not player.can_switch_weapon():
		return false
	if switching():
		pending = slot
		return true
	pending = slot
	switch_timer = switch_time
	switch_started.emit(current, slot)
	return true


## Skip the animation (respawning, tests).
func equip_now(slot: Slot) -> void:
	current = slot
	pending = slot
	switch_timer = 0.0
	changed.emit(slot)


func physics_update(delta: float) -> void:
	var inp: PlayerInput = player.input
	if inp.equip_sword_pressed:
		equip(Slot.SWORD_SHIELD)
	elif inp.equip_bow_pressed:
		equip(Slot.BOW)
	elif inp.equip_tool_pressed:
		equip(Slot.TOOL)
	if not switching():
		return
	var was_lowering := switch_progress() < 0.5
	switch_timer = maxf(switch_timer - delta, 0.0)
	if was_lowering and switch_progress() >= 0.5 or not switching():
		if current != pending:
			current = pending
			changed.emit(current)
