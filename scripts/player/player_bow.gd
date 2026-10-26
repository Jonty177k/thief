class_name PlayerBow
extends Node
## The bow. With it equipped (D-pad right / 2): hold R2 (or LMB / F) to
## draw, release to loose a physical arrow (see Arrow). D-pad up (Q or the
## mouse wheel) cycles plain, fire and water arrows. You can walk, crouch
## and aim while drawing, but not run. A short tap below Min Draw Time
## lets the string down without firing.

signal draw_started
signal fired(arrow: Arrow)
signal selection_changed(type: ArrowType)
signal ammo_changed

@export_group("Shooting")
## Arrow speed at full draw, in m/s.
@export var arrow_speed := 45.0
## Fraction of that speed at the minimum draw.
@export_range(0.1, 1.0, 0.05) var min_speed_fraction := 0.45
@export var arrow_gravity := 9.8
## Seconds to a full draw.
@export var max_draw_time := 0.8
## Releasing before this lets the string down without firing.
@export var min_draw_time := 0.15
## Damage of a plain arrow at full draw.
@export var arrow_damage := 20.0
## Seconds before the next arrow can be drawn.
@export var nock_time := 0.25
@export_group("Handling")
## Movement speed while drawing, as a fraction.
@export_range(0.0, 1.0, 0.05) var draw_move_multiplier := 0.6
## Field of view narrows by this many degrees at full draw.
@export var draw_zoom_degrees := 8.0
@export_group("Arrows")
## The arrow kinds D-pad up cycles through. Empty: plain, fire and water.
@export var arrow_types: Array[ArrowType] = []
@export_group("Inventory")
## Debug: never run out.
@export var unlimited_ammo := true
@export var arrows := 24
@export var fire_charges := 6
@export var water_charges := 6

var player: CharacterBody3D
var selected := 0
var drawing := false
var draw_time := 0.0
var nock_timer := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p
	if arrow_types.is_empty():
		arrow_types = [ArrowType.standard(), ArrowType.fire(), ArrowType.water()]


func current_type() -> ArrowType:
	return arrow_types[selected]


## 0..1 draw.
func draw_amount() -> float:
	return clampf(draw_time / maxf(max_draw_time, 0.001), 0.0, 1.0) if drawing else 0.0


func move_multiplier() -> float:
	return draw_move_multiplier if drawing else 1.0


func count_for(t: ArrowType) -> int:
	if unlimited_ammo:
		return -1
	match t.charge:
		"fire":
			return mini(arrows, fire_charges)
		"water":
			return mini(arrows, water_charges)
	return arrows


func has_ammo(t: ArrowType) -> bool:
	return unlimited_ammo or count_for(t) > 0


func cancel() -> void:
	drawing = false
	draw_time = 0.0


func cycle(step := 1) -> void:
	selected = posmod(selected + step, arrow_types.size())
	selection_changed.emit(current_type())


func physics_update(delta: float) -> void:
	nock_timer = maxf(nock_timer - delta, 0.0)
	var inp: PlayerInput = player.input
	var equipped: bool = player.loadout.is_ready(PlayerLoadout.Slot.BOW)
	if not equipped:
		cancel()
		return
	if inp.cycle_arrow_pressed:
		cycle()
	var held: bool = inp.heavy_held or inp.light_held
	if drawing:
		if not player.can_draw_bow():
			cancel()
			return
		draw_time += delta
		if not held:
			if draw_time >= min_draw_time:
				_fire()
			cancel()
	elif held and (inp.heavy_pressed or inp.light_pressed) and nock_timer <= 0.0 and player.can_draw_bow():
		if has_ammo(current_type()):
			drawing = true
			draw_time = 0.0
			draw_started.emit()
		else:
			player.notice.emit("No %ss left" % current_type().name.to_lower())


func _fire() -> void:
	var t := current_type()
	var k := clampf(inverse_lerp(min_draw_time, max_draw_time, draw_time), 0.0, 1.0)
	var speed := arrow_speed * lerpf(min_speed_fraction, 1.0, k)
	var cam: Camera3D = player.camera
	var dir := -cam.global_basis.z
	var dmg := arrow_damage * t.damage_multiplier * lerpf(0.5, 1.0, k)
	var a := Arrow.spawn(player.get_tree().current_scene if player.get_tree().current_scene else player.get_parent(),
		t, cam.global_position + dir * 0.1, dir * speed, dmg, player, arrow_gravity)
	nock_timer = nock_time
	if not unlimited_ammo:
		arrows -= 1
		if t.charge == "fire":
			fire_charges -= 1
		elif t.charge == "water":
			water_charges -= 1
		ammo_changed.emit()
	Game.emit_noise(player.global_position, 3.0, player, "bow_release", 0.2)
	fired.emit(a)
