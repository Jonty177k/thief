extends Node
## Headless acceptance tests for the bow, arrows and elemental fusion, run
## in the archery range:
##   godot --headless --path . res://tests/bow_test.tscn
## Drives Jeffrey with the real Input Map actions.

var main: Node3D
var p: JBDPlayer
var lvl: Node
var warden: CharacterBody3D
var failures := 0
var last_arrow: Arrow


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.level_scene = load("res://levels/archery_range.tscn")
	add_child(main)
	p = main.player
	lvl = main.world
	warden = lvl.get_node("Enemies/Warden").enemy
	warden.process_mode = Node.PROCESS_MODE_DISABLED
	p.bow.fired.connect(func(a: Arrow) -> void: last_arrow = a)
	await _run()
	print("BOW TEST DONE, failures: %d" % failures)
	get_tree().quit(failures)


func check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		failures += 1


func wait(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "block", "attack_heavy", "attack_light"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg := 0.0) -> void:
	release_all()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.camera_rig.set_pitch_degrees(0.0)
	p.bow.cancel()
	p.bow.nock_timer = 0.0
	p.hp = p.max_hp
	await frames(4)
	while not p.is_on_floor():
		await frames(1)


## Aim the crosshair at `target`, allowing for the arrow's drop at full draw.
func aim_at(target: Vector3) -> void:
	var d := target - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await frames(1)
	var c: Vector3 = target - p.camera.global_position
	var flat := Vector2(c.x, c.z).length()
	var t := flat / p.bow.arrow_speed
	c.y += 0.5 * p.bow.arrow_gravity * t * t
	p.camera_rig.set_pitch_degrees(rad_to_deg(atan2(c.y, flat)))
	await frames(2)


## Draw fully and loose; wait for the arrow to land.
func shoot(type_index: int) -> Arrow:
	p.bow.selected = type_index
	p.bow.nock_timer = 0.0
	last_arrow = null
	Input.action_press("attack_heavy")
	await wait(p.bow.max_draw_time + 0.1)
	Input.action_release("attack_heavy")
	await frames(2)
	var a := last_arrow
	for i in 90:
		if a == null or not is_instance_valid(a) or not a.flying:
			break
		await frames(1)
	await frames(2)
	return a


func dummy(path: String) -> JBDTrainingDummy:
	var d: JBDTrainingDummy = lvl.get_node(path)
	d.health = d.max_health
	d.broken = false
	return d


func torch(path: String) -> JBDTorch:
	return lvl.get_node(path)


func _run() -> void:
	await wait(1.0)
	var bow := p.bow
	var lo := p.loadout

	# --- Weapon switching ----------------------------------------------------
	await place(Vector3(0, 0, 10), 0.0)
	check("starts with sword and shield", lo.current == PlayerLoadout.Slot.SWORD_SHIELD)
	await tap("equip_bow")
	check("D-pad right / 2 starts a switch to the bow", lo.switching() and lo.pending == PlayerLoadout.Slot.BOW)
	await tap("attack_light")
	check("no attacking mid-switch", not p.sword.attacking() and not bow.drawing)
	await wait(lo.switch_time + 0.05)
	check("then the bow is in hand", lo.is_ready(PlayerLoadout.Slot.BOW) and main.hud.weapon.text.begins_with("Bow"), main.hud.weapon.text.replace("\n", " / "))
	await tap("attack_light")
	await frames(2)
	check("swords don't swing with the bow out", not p.sword.attacking())
	Input.action_release("attack_light")
	bow.cancel()

	# --- Fusion selection ------------------------------------------------------
	bow.selected = 0
	var seen: Array[String] = []
	for i in 3:
		await tap("cycle_arrow")
		seen.append(bow.current_type().name)
	check("D-pad up / Q cycles fire, water, plain", seen == ["Fire arrow", "Water arrow", "Arrow"], str(seen))
	await tap("cycle_arrow")
	check("the HUD shows the selected arrow", main.hud.weapon.text.contains("Fire arrow"), main.hud.weapon.text.replace("\n", " / "))
	check("ammo is unlimited in debug", bow.unlimited_ammo and bow.has_ammo(bow.current_type()))

	# --- Draw and release ----------------------------------------------------
	await place(Vector3(0, 0, 10), 0.0)
	bow.selected = 0
	last_arrow = null
	await tap("attack_heavy")
	await frames(3)
	check("a tap below the minimum draw doesn't fire", last_arrow == null and not bow.drawing)
	bow.nock_timer = 0.0
	Input.action_press("attack_heavy")
	await wait(0.4)
	var half := bow.draw_amount()
	await wait(0.5)
	check("holding R2 draws the bow to full", half > 0.35 and half < 0.65 and bow.draw_amount() >= 1.0 and p.state == JBDPlayer.State.AIMING_BOW,
		"%.2f after 0.4 s" % half)
	Input.action_press("move_forward")
	Input.action_press("run")
	await wait(0.8)
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	check("you can walk while drawing, but not run", speed > 0.5 and speed <= p.movement.walk_speed * bow.draw_move_multiplier + 0.05, "%.2f m/s" % speed)
	Input.action_release("move_forward")
	Input.action_release("run")
	await wait(0.3)
	p.camera_rig.set_pitch_degrees(0.0)
	await frames(2)
	var start := p.camera.global_position
	Input.action_release("attack_heavy")
	await frames(2)
	check("releasing R2 fires an arrow", last_arrow != null and not bow.drawing)

	# --- Ballistics --------------------------------------------------------
	var a := last_arrow
	var t0 := Time.get_ticks_msec()
	var p0 := a.global_position
	var vy0 := a.velocity.y
	await frames(12)
	var travelled := a.global_position - p0
	var horizontal := Vector2(travelled.x, travelled.z).length() / (12.0 / 60.0)
	var drop := -travelled.y
	var expected := 0.5 * bow.arrow_gravity * pow(12.0 / 60.0, 2.0) - vy0 * (12.0 / 60.0)
	check("arrows fly at 45 m/s and fall under 9.8 m/s² gravity", absf(horizontal - bow.arrow_speed) < 1.0 and absf(drop - expected) < 0.05,
		"%.1f m/s, dropped %.3f m in 0.2 s (expected %.3f)" % [horizontal, drop, expected])
	await wait(1.0)
	check("and stick where they land", a == null or not is_instance_valid(a) or not a.flying)

	# --- Standard arrow --------------------------------------------------------
	await place(Vector3(-7.5, 0, 8), 0.0)
	var dmy := dummy("Gameplay/Dummy")
	await aim_at(dmy.global_position + Vector3.UP * 1.2)
	a = await shoot(0)
	check("a plain arrow damages the dummy", dmy.max_health - dmy.health == bow.arrow_damage, "%.0f damage" % (dmy.max_health - dmy.health))
	check("and sticks in it", is_instance_valid(a) and not a.flying and a.struck == dmy)
	dmy = dummy("Gameplay/Dummy")
	a = await shoot(2)
	check("a water arrow does reduced damage", dmy.max_health - dmy.health == bow.arrow_damage * 0.5, "%.0f damage" % (dmy.max_health - dmy.health))

	# --- Elevated target -------------------------------------------------------
	await place(Vector3(8, 0, 2), 0.0)
	var high := dummy("Gameplay/HighDummy")
	await aim_at(high.global_position + Vector3.UP * 1.2)
	await shoot(0)
	check("arrows reach the elevated target", high.health < high.max_health, "%.0f hp" % high.health)

	# --- Walls -----------------------------------------------------------------
	await place(Vector3(-4, 0, 2), 0.0)
	var hidden := dummy("Gameplay/HiddenDummy")
	await aim_at(hidden.global_position + Vector3.UP * 1.2)
	a = await shoot(0)
	await wait(0.6)
	check("arrows don't pass through the stone wall", hidden.health == hidden.max_health and is_instance_valid(a) and a.global_position.z > -4.4,
		"dummy %.0f hp, arrow at z %.2f" % [hidden.health, a.global_position.z if is_instance_valid(a) else 0.0])

	# --- Torches -------------------------------------------------------------
	var unlit := torch("Gameplay/UnlitTorch")
	check("the unlit torch starts dark, with no light", not unlit.lit and not unlit.flame().light.visible)
	await place(Vector3(5, 0, 4), 90.0)
	await aim_at(unlit.flame().global_position)
	await shoot(1)
	check("a fire arrow lights the torch", unlit.lit and unlit.flame().light.visible and unlit.flame().is_in_group("light_source"))

	var lit := torch("Gameplay/LitTorch")
	Game.set_hour(23.0)
	await place(Vector3(-9.5, 0, 2), -90.0)
	await wait(2.0)
	var vis_lit := p.visibility
	await place(Vector3(-4, 0, 6), -90.0)
	await aim_at(lit.flame().global_position)
	a = await shoot(2)
	check("a water arrow puts the torch out", not lit.lit)
	check("its Light3D is switched off and it stops counting as light",
		not lit.flame().light.visible and not lit.flame().is_in_group("light_source") and lit.flame().light_radius == 0.0)
	await place(Vector3(-9.5, 0, 2), -90.0)
	await wait(2.0)
	var vis_dark := p.visibility
	check("standing there, the light gem is darker", vis_dark < vis_lit - 0.3, "%.2f lit, %.2f out" % [vis_lit, vis_dark])

	# Enemy detection follows the light.
	var guard := torch("Gameplay/GuardTorch")
	var spot := Vector3(1.5, 0, -6.5)
	var aware := []
	for on in [true, false]:
		guard.lit = on
		warden.reset_to_post()
		await place(spot, 180.0)
		await wait(1.5)
		warden.awareness = 0.0
		warden.state = 0
		warden.process_mode = Node.PROCESS_MODE_INHERIT
		await wait(1.0)
		aware.append(warden.awareness)
		warden.process_mode = Node.PROCESS_MODE_DISABLED
	check("the warden notices Jeffrey slower once the torch is out", aware[1] < aware[0] * 0.6, "awareness %.2f lit, %.2f out" % aware)
	guard.lit = true

	# Noise: an arrow clattering near the warden makes it look.
	warden.reset_to_post()
	await place(Vector3(4, 0, 6), 0.0)
	warden.process_mode = Node.PROCESS_MODE_INHERIT
	await aim_at(warden.global_position + Vector3(2.5, 0.0, 1.5))
	var heard := []
	var listen := func(e: NoiseEvent) -> void: heard.append([e.kind, e.position.distance_to(warden.global_position)])
	Game.noise_made.connect(listen)
	await shoot(0)
	await frames(2)
	Game.noise_made.disconnect(listen)
	check("an arrow's impact is a noise the warden investigates", warden.state == 1, "state %d, heard %s" % [warden.state, heard])
	warden.process_mode = Node.PROCESS_MODE_DISABLED
	warden.reset_to_post()

	# --- Fire and flammables -------------------------------------------------
	var crates: Flammable = lvl.get_node("Building/Crates/Flammable")
	var straw: Flammable = lvl.get_node("Building/Straw/Flammable")
	await place(Vector3(4, 0, 4), 0.0)
	await aim_at(crates.get_parent().global_position + Vector3(0, 1.0, 0.75))
	await shoot(0)
	check("a plain arrow doesn't light wood", not crates.burning)
	await shoot(1)
	check("a fire arrow sets the crates alight", crates.burning and crates.flame.light.visible)
	await wait(crates.spread_delay + 0.3)
	check("fire spreads to the straw beside it", straw.burning)
	var hurt := dummy("Gameplay/Dummy")
	hurt.global_position = straw.global_position + Vector3(0.8, -0.5, 0)
	await wait(0.6)
	check("burning straw is a hazard that hurts what stands in it", hurt.health < hurt.max_health, "%.0f hp" % hurt.health)
	await shoot(2)
	check("a water arrow puts burning crates out", not crates.burning and not crates.flame.light.visible)

	# --- Switch --------------------------------------------------------------
	var gate: JBDDoor = lvl.get_node("Gameplay/VaultGate")
	var sw: JBDArrowSwitch = lvl.get_node("Gameplay/ArrowSwitch")
	await place(Vector3(-5, 0, -6), 180.0)
	await aim_at(sw.global_position + Vector3(0, 0, 0.12))
	await shoot(0)
	await wait(0.8)
	check("an arrow trips the switch and opens the gate", sw.on and gate.is_open)

	# --- The sword still works -------------------------------------------------
	await place(Vector3(-6.0, 0, 0), 90.0)
	dmy = dummy("Gameplay/Dummy")
	dmy.global_position = Vector3(-7.5, 0, 0)
	await frames(2)
	dmy.health = dmy.max_health
	await tap("equip_sword")
	await wait(lo.switch_time + 0.05)
	var d := dmy.global_position - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await tap("attack_light")
	await wait(0.6)
	check("switch back to the sword and it still hits", lo.is_ready(PlayerLoadout.Slot.SWORD_SHIELD) and dmy.max_health - dmy.health == p.sword.light_damage,
		"%.3f damage, %s in hand%s" % [dmy.max_health - dmy.health, lo.slot_name(), " (switching)" if lo.switching() else ""])
	Input.action_press("block")
	await wait(0.3)
	check("and the shield still blocks", p.shield.guarding())
	Input.action_release("block")
