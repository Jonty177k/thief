extends Node
## Headless acceptance tests for the hookshot and wire gun, run in the
## tower yard:
##   godot --headless --path . res://tests/hookshot_test.tscn
## Drives Jeffrey with the real Input Map actions.

var main: Node3D
var p: JBDPlayer
var tool: PlayerHookshot
var lvl: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.level_scene = load("res://levels/tower_yard.tscn")
	add_child(main)
	p = main.player
	tool = p.tool
	lvl = main.world
	await _run()
	print("HOOKSHOT TEST DONE, failures: %d" % failures)
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
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "block", "attack_heavy",
			"attack_light", "look_right", "look_left"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg := 0.0) -> void:
	release_all()
	if tool.state != PlayerHookshot.State.NORMAL:
		tool.cancel()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.camera_rig.set_pitch_degrees(0.0)
	p.hp = p.max_hp
	tool.cooldown_timer = 0.0
	await frames(4)
	while not p.is_on_floor():
		await frames(1)


func aim_at(target: Vector3) -> void:
	var d := target - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await frames(1)
	var c: Vector3 = target - p.camera.global_position
	p.camera_rig.set_pitch_degrees(rad_to_deg(atan2(c.y, Vector2(c.x, c.z).length())))
	await frames(2)


func block(name: String) -> JBDBlock:
	for g in ["Building", "Hookable"]:
		var n := lvl.get_node_or_null(g + "/" + name)
		if n:
			return n
	return null


## Fire and wait for the hook (and any haul) to finish. Returns
## [connected, arrived, max step per tick, ticks].
func hook_and_wait(timeout := 4.0) -> Array:
	var connected := [false]
	var arrived := [null]
	var c1 := func(_pt: Vector3) -> void: connected[0] = true
	var c2 := func(ok: bool) -> void: arrived[0] = ok
	tool.hook_connected.connect(c1)
	tool.pull_finished.connect(c2)
	await tap("attack_heavy")
	var last := p.global_position
	var max_step := 0.0
	var ticks := 0
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < timeout:
		await frames(1)
		ticks += 1
		max_step = maxf(max_step, p.global_position.distance_to(last))
		last = p.global_position
		if tool.state == PlayerHookshot.State.NORMAL and (arrived[0] != null or not connected[0]) and ticks > 3:
			break
	tool.hook_connected.disconnect(c1)
	tool.pull_finished.disconnect(c2)
	return [connected[0], arrived[0], max_step, ticks]


func _run() -> void:
	await wait(1.0)
	var lo := p.loadout
	var noises: Array[NoiseEvent] = []
	Game.noise_made.connect(func(e: NoiseEvent) -> void: noises.append(e))

	# --- Equipping and modes ---------------------------------------------------
	await place(Vector3(-10, 0, 6), 180.0)
	await tap("equip_tool")
	await wait(lo.switch_time + 0.05)
	check("D-pad down / 3 equips the hookshot", lo.is_ready(PlayerLoadout.Slot.TOOL) and main.hud.weapon.text.begins_with("Hookshot"),
		main.hud.weapon.text.replace("\n", " / "))
	await tap("block")
	var wire_mode: bool = tool.mode == PlayerHookshot.Mode.WIRE and main.hud.weapon.text.contains("Wire")
	await tap("block")
	check("L1 / RMB switches hook and wire modes (and the HUD says which)", wire_mode and tool.mode == PlayerHookshot.Mode.HOOKSHOT)
	check("L1 doesn't raise a shield with the hookshot out", not p.shield.raised)

	# --- Aiming ---------------------------------------------------------------
	var beam_top := block("BeamA_Top")
	await aim_at(beam_top.global_position + Vector3(0, 0.2, 0.6))
	var on_beam := tool.aim
	await aim_at(Vector3(-12, 4, -1.0))
	var on_stone := tool.aim
	p.camera_rig.set_pitch_degrees(80.0)
	await frames(2)
	var on_sky := tool.aim
	check("the aim indicator: wood bites, stone doesn't, sky is out of range",
		on_beam == PlayerHookshot.Aim.VALID and on_stone == PlayerHookshot.Aim.INVALID and on_sky == PlayerHookshot.Aim.NONE)
	await aim_at(beam_top.global_position + Vector3(0, 0.2, 0.6))
	check("the crosshair shows it", main.hud.crosshair.text == "o")

	# --- Hookshot: a valid target ---------------------------------------------
	noises.clear()
	var start := p.global_position
	var yaw := p.rotation.y
	await aim_at(Vector3(-10, 12.15, -0.79))
	yaw = p.rotation.y
	check("the deck's wooden edge is a target", tool.aim == PlayerHookshot.Aim.VALID, tool.aim_reason)
	Input.action_press("look_right")
	get_tree().create_timer(0.3).timeout.connect(func() -> void: Input.action_release("look_right"))
	var r := await hook_and_wait()
	check("the hook flies out, bites the deck edge and hauls Jeffrey up", r[0] and r[1] == true, "connected %s, arrived %s" % [r[0], r[1]])
	check("no teleporting: never more than one tick of pull speed at a time", r[2] <= tool.pull_speed / 60.0 + 0.12, "max %.2f m per tick" % r[2])
	await wait(0.3)
	check("he climbs onto the roof at the end", p.global_position.y > 12.0 and p.is_on_floor(), str(p.global_position))
	check("the camera stayed under control while hauled", absf(angle_difference(yaw, p.rotation.y)) > 0.2)
	var fire_noise := noises.filter(func(e: NoiseEvent) -> bool: return e.kind == "hookshot_fire")
	check("firing emits a moderate noise event", fire_noise.size() == 1 and fire_noise[0].radius == tool.fire_noise_radius)

	# During a haul: no attacks, no dodges, no switching.
	await place(Vector3(-10, 0, 6), 180.0)
	await aim_at(beam_top.global_position + Vector3(0, 0.2, 0.6))
	await tap("attack_heavy")
	while tool.state != PlayerHookshot.State.HOOK_PULLING:
		await frames(1)
	await tap("dash")
	await tap("equip_sword")
	check("hauling overrides movement and blocks dodging and switching",
		p.state == JBDPlayer.State.HOOK_PULLING and not p.dash.active and lo.current == PlayerLoadout.Slot.TOOL and not lo.switching())
	while tool.state != PlayerHookshot.State.NORMAL:
		await frames(1)

	# --- Hookshot: invalid targets ---------------------------------------------
	await place(Vector3(-4, 0, 14), 180.0)
	await aim_at(Vector3(-4, 4, 11.05))
	var fails := []
	var on_fail := func(_pt: Vector3, why: String) -> void: fails.append(why)
	tool.hook_failed.connect(on_fail)
	start = p.global_position
	r = await hook_and_wait()
	check("stone: the hook fails and Jeffrey doesn't move", not r[0] and fails.size() == 1 and p.global_position.distance_to(start) < 0.05 and tool.state == PlayerHookshot.State.NORMAL,
		"%s, moved %.2f m" % [fails, p.global_position.distance_to(start)])
	p.camera_rig.set_pitch_degrees(80.0)
	await frames(2)
	await wait(0.35)
	r = await hook_and_wait()
	check("a miss: no movement", not r[0] and fails.size() == 2 and p.global_position.distance_to(start) < 0.05)
	await place(Vector3(-10, 0, 6.3), 180.0)
	await aim_at(block("LowBeam").global_position + Vector3(0, 0.6, 0.8))
	check("too close (under 2 m) is refused", tool.aim == PlayerHookshot.Aim.INVALID and tool.aim_reason == "Too close", tool.aim_reason)
	tool.hook_failed.disconnect(on_fail)

	# --- Hookshot: obstructed ---------------------------------------------------
	await place(Vector3(0, 0, 16), 180.0)
	var hidden_beam := block("BeamBehindWall")
	await aim_at(hidden_beam.global_position + Vector3(0, 0.2, 0.42))
	check("the beam behind the wall is a valid target", tool.aim == PlayerHookshot.Aim.VALID)
	r = await hook_and_wait()
	check("the wall stops the haul safely, short of it, with control back",
		r[0] and r[1] == false and p.global_position.z > 12.3 and tool.state == PlayerHookshot.State.NORMAL and not tool.controls_movement(),
		"arrived %s at %s" % [r[1], p.global_position])
	await wait(1.0)
	check("and he's back on his feet, not stuck in the wall", p.is_on_floor() and p.global_position.z > 12.3 and p.global_position.y < 0.2, str(p.global_position))

	# --- Wire placement ---------------------------------------------------------
	await place(Vector3(-8, 12.3, -5), -90.0)
	await tap("block")  # wire mode
	var east_edge_a := Vector3(-6.3, 12.3, -5)
	await aim_at(east_edge_a)
	noises.clear()
	await tap("attack_heavy")
	check("R2 sets the first anchor", tool.state == PlayerHookshot.State.WIRE_PLACEMENT and not tool.pending_anchor.is_empty())
	check("placing an anchor is a smaller noise", noises.size() == 1 and noises[0].radius < tool.fire_noise_radius)
	var west_edge_b := Vector3(6.3, 10.3, -5)
	await aim_at(west_edge_b)
	check("the preview says the second anchor will work", tool.aim == PlayerHookshot.Aim.VALID, tool.aim_reason)
	var made := [null]
	tool.wire_created.connect(func(w: TightWire) -> void: made[0] = w)
	await tap("attack_heavy")
	var w: TightWire = made[0]
	check("R2 on a second surface strings a wire between them", w != null and tool.wires.size() == 1 and tool.state == PlayerHookshot.State.NORMAL)
	if w == null:
		return
	var incline := rad_to_deg(asin(absf(w.b.y - w.a.y) / w.length()))
	check("it's a straight, taut, walkable wire", w.length() > 12.0 and w.length() < 13.5 and incline < tool.max_incline_degrees,
		"%.1f m at %.0f°" % [w.length(), incline])

	# Validation.
	var v := func(a: Vector3, an: Vector3, a_name: String, b: Vector3, bn: Vector3, b_name: String) -> Dictionary:
		return tool.validate_wire({"point": a, "normal": an, "collider": block(a_name)}, {"point": b, "normal": bn, "collider": block(b_name)})
	var too_long: Dictionary = v.call(Vector3(-14.2, 12.15, -5), Vector3.LEFT, "TowerADeck", Vector3(14.2, 10.15, -5), Vector3.RIGHT, "TowerBDeck")
	check("too long is refused", not too_long.ok and too_long.reason.begins_with("Too long"), too_long.reason)
	var too_short: Dictionary = v.call(Vector3(-9, 12.3, -5), Vector3.UP, "TowerADeck", Vector3(-7, 12.3, -5), Vector3.UP, "TowerADeck")
	check("too short is refused", not too_short.ok and too_short.reason == "Too short", too_short.reason)
	var steep: Dictionary = v.call(Vector3(-10, 1.0, 4), Vector3.UP, "LowBeam", Vector3(-10, 12.3, -1.0), Vector3.UP, "TowerADeck")
	check("too steep is refused", not steep.ok and steep.reason.begins_with("Too steep"), steep.reason)
	var through: Dictionary = v.call(Vector3(-7.75, 6.0, -22), Vector3.UP, "PostWest", Vector3(7.75, 6.0, -22), Vector3.UP, "PostEast")
	check("a wire can't pass through a stone pillar", not through.ok and through.reason == "Something's in the way", through.reason)
	var stone: Dictionary = tool.validate_wire({"point": Vector3(-6, 6, -5), "normal": Vector3.RIGHT, "collider": block("TowerA")},
		{"point": Vector3(6, 6, -5), "normal": Vector3.LEFT, "collider": block("TowerB")})
	check("stone walls aren't anchors", not stone.ok, stone.reason)
	var low: Dictionary = v.call(Vector3(15.2, 5.3, 12), Vector3.UP, "LowHouseRoof", Vector3(10, 10.3, -0.95), Vector3.UP, "TowerBDeck")
	check("the low roof wires up to tower B", low.ok, "%s %.1f m at %.0f°" % [low.reason, low.length, low.incline])

	# --- Walking the wire -------------------------------------------------------
	await place(Vector3(-7.3, 12.3, -5), -90.0)
	await aim_at(w.point_at(w.mount_s(0)))
	check("looking at the end of the wire offers to walk it", main.hud.prompt.text.contains("Walk the wire"), main.hud.prompt.text)
	await tap("interact")
	await wait(tool.mount_time + 0.1)
	check("Square / E steps onto the wire", p.state == JBDPlayer.State.WIRE_TRAVERSAL and p.global_position.distance_to(w.point_at(tool.wire_s)) < 0.01)
	p.camera_rig.set_pitch_degrees(0.0)
	var drift := 0.0
	var speeds: Array[float] = []
	var last := p.global_position
	var yaw0 := p.rotation.y
	Input.action_press("move_forward")
	Input.action_press("look_left")
	for i in 120:
		await frames(1)
		var off := (p.global_position - w.a) - w.direction() * (p.global_position - w.a).dot(w.direction())
		drift = maxf(drift, off.length())
		speeds.append(p.global_position.distance_to(last) * 60.0)
		last = p.global_position
	Input.action_release("look_left")
	var spread: float = speeds.slice(5).max() - speeds.slice(5).min()
	check("forward walks the wire at 1.5 m/s, smoothly", absf(speeds.back() - tool.wire_speed) < 0.1 and spread < 0.15,
		"%.2f m/s, jitter %.3f" % [speeds.back(), spread])
	check("no drift off the line, even turning the camera", drift < 0.001 and absf(p.rotation.y - yaw0) > 0.3, "%.5f m" % drift)
	var steps := noises.filter(func(e: NoiseEvent) -> bool: return e.kind == "wire_step")
	check("walking a wire is quiet", steps.size() >= 1 and steps.all(func(e: NoiseEvent) -> bool: return e.radius <= 1.5))
	var timeout := 0
	while p.state == JBDPlayer.State.WIRE_TRAVERSAL and timeout < 60 * 12:
		await frames(1)
		timeout += 1
	Input.action_release("move_forward")
	await wait(0.4)
	check("reaching the far end steps off onto tower B", p.state != JBDPlayer.State.WIRE_TRAVERSAL and p.is_on_floor()
		and absf(p.global_position.y - 10.3) < 0.2 and p.global_position.x > 6.0, str(p.global_position))

	# Back from B: walk a little, then step off at the near end with Circle.
	tool.mount(w, 1)
	await wait(tool.mount_time + 0.1)
	Input.action_press("move_forward")
	await wait(0.4)
	Input.action_release("move_forward")
	var s_before := tool.wire_s
	Input.action_press("move_back")
	await wait(0.3)
	Input.action_release("move_back")
	check("back on the stick walks toward the starting end", tool.wire_s > s_before)
	await tap("dash")
	await wait(tool.mount_time + 0.3)
	check("Circle near an end steps off there", p.state != JBDPlayer.State.WIRE_TRAVERSAL and p.is_on_floor() and p.global_position.x > 6.0, str(p.global_position))

	# From A: walk to the middle and jump off.
	await place(Vector3(-7.3, 12.3, -5), -90.0)
	tool.mount(w, 0)
	await wait(tool.mount_time + 0.1)
	Input.action_press("move_forward")
	while tool.wire_s < w.length() * 0.5:
		await frames(1)
	Input.action_release("move_forward")
	var y_mid := p.global_position.y
	await tap("jump")
	var peak := y_mid
	for i in 20:
		await frames(1)
		peak = maxf(peak, p.global_position.y)
	check("Cross jumps off the wire", p.state != JBDPlayer.State.WIRE_TRAVERSAL and peak > y_mid + 0.3, "rose %.2f m" % (peak - y_mid))
	await wait(2.0)
	check("and he falls to the yard", p.global_position.y < 1.0)

	# From A again: Circle in the middle drops.
	await place(Vector3(-7.3, 12.3, -5), -90.0)
	tool.mount(w, 0)
	await wait(tool.mount_time + 0.1)
	Input.action_press("move_forward")
	await wait(2.5)
	Input.action_release("move_forward")
	y_mid = p.global_position.y
	await tap("dash")
	await wait(0.5)
	check("Circle mid-wire drops off it", p.state != JBDPlayer.State.WIRE_TRAVERSAL and p.global_position.y < y_mid - 0.5)
	await wait(2.0)

	# One wire at a time.
	var low_w: Array = [null, ""]
	tool.wire_created.connect(func(nw: TightWire) -> void: low_w[0] = nw)
	tool.wire_rejected.connect(func(why: String) -> void: low_w[1] = why)
	await place(Vector3(17, 5.3, 12), 0.0)
	await aim_at(Vector3(15.3, 5.3, 12))
	await tap("attack_heavy")
	await aim_at(Vector3(10, 10.3, -0.95))
	await tap("attack_heavy")
	await frames(2)
	check("only one wire at a time: a new one replaces the old", low_w[0] != null and tool.wires.size() == 1 and not is_instance_valid(w), "%s %s" % [low_w[1], tool.state_name()])

	# --- Everything else still works -----------------------------------------
	await place(Vector3(0, 0, 20), 0.0)
	await tap("equip_sword")
	await wait(lo.switch_time + 0.05)
	await tap("attack_light")
	var swung := p.sword.attacking()
	await wait(0.8)
	Input.action_press("block")
	await wait(0.3)
	var guarding := p.shield.guarding()
	Input.action_release("block")
	Input.action_press("move_forward")
	await wait(1.0)
	var walk := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	check("sword, shield and walking still work afterwards", swung and guarding and absf(walk - p.movement.walk_speed) < 0.1)
