extends Node
## Headless acceptance tests for the melee combat prototype, run in the
## combat arena:
##   godot --headless --path . res://tests/combat_test.tscn
## Drives Jeffrey with the real Input Map actions. Feel, sound and a real
## controller can't be checked here; see docs/COMBAT.md.

var main: Node3D
var p: JBDPlayer
var foe: JBDSwordsman
var dummy: JBDTrainingDummy
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.level_scene = load("res://levels/combat_arena.tscn")
	add_child(main)
	p = main.player
	foe = main.world.get_node("Enemies/Swordsman")
	dummy = main.world.get_node("Gameplay/TrainingDummy")
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	await _run()
	print("COMBAT TEST DONE, failures: %d" % failures)
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
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "block", "look_right", "look_left",
			"attack_heavy", "attack_light"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg := 0.0) -> void:
	release_all()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.camera_rig.set_pitch_degrees(0.0)
	p.dash.recovery_timer = 0.0
	p.sword.cancel()
	p.shield.guard_break_timer = 0.0
	p.stamina.refill()
	p.hp = p.max_hp
	await frames(4)
	while not p.is_on_floor():
		await frames(1)


func face(target: Vector3) -> void:
	var d := target - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await frames(1)


func fresh_dummy() -> void:
	dummy.health = dummy.max_health
	dummy.broken = false


## A blow arriving at Jeffrey from `from_dir` (a world direction from him
## toward the attacker).
func blow(from_dir: Vector3, amount := 35.0) -> DamageInfo:
	var origin := p.global_position + from_dir.normalized() * 2.0
	var info := DamageInfo.make(amount, null, origin, p.global_position, 0.0, "enemy")
	p.receive_damage(info)
	return info


func _run() -> void:
	await wait(1.0)
	var sw := p.sword
	var st := p.stamina

	# --- Light combo ----------------------------------------------------
	await place(Vector3(-6.2, 0, 2), -90.0)
	await face(dummy.global_position)
	fresh_dummy()
	var chain: Array[int] = []
	sw.swing_started.connect(func(_k: String, i: int) -> void: chain.append(i))
	var hits := [0]
	var count_hit := func(_t: Node, _i: DamageInfo) -> void: hits[0] += 1
	sw.hit_landed.connect(count_hit)
	await tap("attack_light")
	await wait(sw.light_windup + 0.05)
	await tap("attack_light")  # buffered during the active frames
	while not (sw.chain_index == 1 and sw.phase == PlayerSword.Phase.RECOVERY):
		await frames(1)
	await tap("attack_light")  # buffered during recovery
	await wait(1.4)
	check("light attacks chain into a three-hit combo", chain == [0, 1, 2] and hits[0] == 3
		and dummy.max_health - dummy.health == sw.light_damage * 3,
		"swings %s, %d hits, %.0f damage" % [chain, hits[0], dummy.max_health - dummy.health])
	check("swings alternate direction", sw.chain_index == 0 and chain[1] % 2 == 1)

	# A press during the windup is not buffered: no instant cancel or double swing.
	fresh_dummy()
	chain.clear()
	await tap("attack_light")
	await frames(2)
	await tap("attack_light")
	await wait(1.2)
	check("a press during the windup doesn't queue another swing", chain == [0], str(chain))

	# --- Stamina costs ----------------------------------------------------
	await place(Vector3(-6.2, 0, 2), -90.0)
	await face(dummy.global_position)
	await tap("attack_light")
	check("light attack costs 15 stamina", absf(st.value - (st.max_stamina - st.light_attack_cost)) < 0.01, "%.1f" % st.value)
	await wait(1.0)
	st.refill()
	await tap("attack_heavy")
	check("heavy attack costs 30 stamina", absf(st.value - (st.max_stamina - st.heavy_attack_cost)) < 0.01, "%.1f" % st.value)
	await wait(0.3)
	var held := st.value
	await wait(0.3)
	check("no regeneration during the 0.75 s delay", absf(st.value - held) < 0.01)
	await wait(0.25)
	var r0 := st.value
	await wait(0.4)
	check("then it regenerates at 25 per second", absf((st.value - r0) - 10.0) < 1.2, "%.1f in 0.4 s" % (st.value - r0))
	await place(Vector3(0, 0, 8), 0.0)
	Input.action_press("move_forward")
	Input.action_press("run")
	await wait(0.6)
	release_all()
	check("walking and running cost nothing", st.value == st.max_stamina)
	await tap("dash")
	check("a dodge costs 20 stamina", absf(st.value - (st.max_stamina - st.dodge_cost)) < 0.01, "%.1f" % st.value)
	await wait(0.5)
	await place(Vector3(0, 0, 8), 0.0)
	st.spend(st.max_stamina)
	await tap("attack_light")
	await tap("dash")
	check("no attacks or dodges with no stamina", not sw.attacking() and not p.dash.active)

	# --- Heavy attack and commitment --------------------------------------
	await place(Vector3(-6.2, 0, 2), -90.0)
	await face(dummy.global_position)
	fresh_dummy()
	var t0 := Time.get_ticks_msec()
	await tap("attack_light")
	while dummy.health == dummy.max_health and Time.get_ticks_msec() - t0 < 1000:
		await frames(1)
	var light_at := (Time.get_ticks_msec() - t0) / 1000.0
	await wait(1.0)
	fresh_dummy()
	t0 = Time.get_ticks_msec()
	await tap("attack_heavy")
	await frames(3)
	Input.action_press("block")
	await tap("dash")
	await tap("attack_light")
	var committed := sw.is_heavy() and sw.phase == PlayerSword.Phase.WINDUP and not p.shield.raised and not p.dash.active
	Input.action_release("block")
	var moved_mult := sw.move_multiplier()
	while dummy.health == dummy.max_health and Time.get_ticks_msec() - t0 < 2000:
		await frames(1)
	var heavy_at := (Time.get_ticks_msec() - t0) / 1000.0
	check("heavy windup can't be cancelled into block, dodge or another attack", committed)
	check("heavy hits harder and much later than light", dummy.max_health - dummy.health == sw.heavy_damage and heavy_at > light_at + 0.3,
		"light lands at %.2f s, heavy at %.2f s" % [light_at, heavy_at])
	check("movement is slowed to 0.55 while attacking", absf(moved_mult - 0.55) < 0.001)
	await wait(1.0)

	# Camera stays free mid-swing.
	await tap("attack_heavy")
	var yaw := p.rotation.y
	Input.action_press("look_right")
	await wait(0.3)
	Input.action_release("look_right")
	check("camera look works during an attack", absf(p.rotation.y - yaw) > 0.1 and sw.attacking())
	await wait(1.2)

	# Optional charged heavy (off by default).
	check("charged heavy is off by default", not sw.charged_heavy_enabled)
	sw.charged_heavy_enabled = true
	await place(Vector3(-6.2, 0, 2), -90.0)
	await face(dummy.global_position)
	fresh_dummy()
	Input.action_press("attack_heavy")
	await wait(sw.heavy_windup + sw.charge_time + 0.15)
	Input.action_release("attack_heavy")
	await wait(0.5)
	check("a fully charged heavy hits harder", absf((dummy.max_health - dummy.health) - minf(sw.heavy_damage * sw.charge_damage_multiplier, dummy.max_health)) < 0.5,
		"%.0f damage" % (dummy.max_health - dummy.health))
	sw.charged_heavy_enabled = false
	await wait(1.0)

	# --- Walls ------------------------------------------------------------
	var hidden: JBDTrainingDummy = JBDTrainingDummy.new()
	main.world.add_child(hidden)
	hidden.global_position = Vector3(-11.6, 0, -2)
	await place(Vector3(-9.5, 0, -2), 90.0)
	await face(hidden.global_position)
	var walled := [false]
	sw.hit_wall.connect(func(_p: Vector3) -> void: walled[0] = true)
	await tap("attack_light")
	await wait(0.9)
	await tap("attack_heavy")
	await wait(1.5)
	check("sword attacks can't hit through a wall", hidden.health == hidden.max_health and walled[0],
		"dummy behind the wall at %.0f hp" % hidden.health)
	hidden.queue_free()

	# --- Shield -----------------------------------------------------------
	await place(Vector3(0, 0, 8), 0.0)
	var fwd := -p.global_basis.z
	Input.action_press("block")
	await frames(3)
	var early := blow(fwd)
	check("the shield needs its raise time before it blocks", not early.blocked and p.hp == p.max_hp - 35.0, "hp %.0f" % p.hp)
	p.hp = p.max_hp
	await wait(p.shield.raise_time + 0.05)
	st.refill()
	var front := blow(fwd)
	check("shield blocks a frontal attack completely", front.blocked and p.hp == p.max_hp, "hp %.0f" % p.hp)
	check("a successful block costs 20 stamina", absf(st.value - (st.max_stamina - st.block_cost)) < 0.01, "%.1f" % st.value)
	var edge := blow(fwd.rotated(Vector3.UP, deg_to_rad(55.0)))
	check("a blow 55° off centre is still inside the 120° arc", edge.blocked)
	p.hp = p.max_hp
	var side := blow(fwd.rotated(Vector3.UP, deg_to_rad(90.0)))
	var back := blow(-fwd)
	check("attacks from the side and behind bypass the shield", not side.blocked and not back.blocked and p.hp == p.max_hp - 70.0, "hp %.0f" % p.hp)
	p.hp = p.max_hp
	await tap("attack_light")
	check("no attacking with the shield up", not sw.attacking() and p.state == JBDPlayer.State.BLOCKING)
	var walk_speed := p.movement.walk_speed
	Input.action_press("move_forward")
	await wait(1.0)
	var block_speed := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	check("moves at 60% speed while blocking", absf(block_speed - walk_speed * 0.6) < 0.05, "%.2f m/s" % block_speed)

	# Guard break.
	st.value = 10.0
	var hp0 := p.hp
	var broke := blow(fwd)
	check("a block that costs more than you have breaks the guard",
		broke.blocked and p.shield.guard_broken_now() and not p.shield.raised and p.hp < hp0 and p.hp > hp0 - 35.0 and st.value == 0.0,
		"hp %.0f, stamina %.0f" % [p.hp, st.value])
	st.value = 100.0
	await tap("attack_light")
	await frames(2)
	check("guard break stops attacking and blocking", not sw.attacking() and not p.shield.raised and p.state == JBDPlayer.State.GUARD_BROKEN)
	await wait(p.shield.guard_break_duration + 0.25)
	check("the guard recovers", p.shield.raised)
	Input.action_release("block")

	# --- Dodge i-frames ---------------------------------------------------
	await place(Vector3(0, 0, 8), 0.0)
	var results := []
	for at in [0.02, 0.1, 0.18, 0.24]:
		p.hp = p.max_hp
		st.refill()
		p.dash.recovery_timer = 0.0
		await tap("dash")
		while p.dash.time < at - 0.001 and p.dash.active:
			await frames(1)
		var info := blow(Vector3.FORWARD)
		results.append(info.dodged)
		await wait(0.6)
	check("dodge i-frames only between 0.06 and 0.20 s", results == [false, true, true, false], str(results))
	await place(Vector3(10, 0, 3), 90.0)
	await tap("dash")
	await wait(0.4)
	check("a dodge stops at walls", p.global_position.x < 14.0 - 0.3, "x %.2f" % p.global_position.x)

	# --- The swordsman ----------------------------------------------------
	await place(Vector3(1, 0, 3.5), 0.0)
	foe.reset_to_post()
	foe.process_mode = Node.PROCESS_MODE_INHERIT
	var starts: Array[float] = []
	foe.attack_started.connect(func(_a: EnemyAttack) -> void: starts.append(Time.get_ticks_msec() / 1000.0))
	var windup_seen := [0.0]
	var t_w := 0.0
	var landed := false
	var hp_before := p.hp
	for i in 600:
		await frames(1)
		if foe.state == JBDSwordsman.State.WINDUP:
			windup_seen[0] = maxf(windup_seen[0], foe.state_time)
		if p.hp < hp_before:
			landed = true
		if starts.size() >= 3:
			break
	check("the swordsman notices, approaches and attacks", starts.size() >= 2 and landed, "%d attacks, hp %.0f" % [starts.size(), p.hp])
	check("its attacks have a clear windup", windup_seen[0] >= 0.5, "%.2f s" % windup_seen[0])
	var gaps_ok := true
	for i in range(1, starts.size()):
		if starts[i] - starts[i - 1] < 0.55 + 0.2 + 0.65 + foe.pause_min - 0.05:
			gaps_ok = false
	check("it pauses between attacks", gaps_ok and starts.size() >= 2, str(starts))

	# Frontal block against the real swing; then from behind.
	await place(Vector3(1, 0, -1.8), 180.0)
	foe.reset_to_post()
	p.hp = p.max_hp
	await face(foe.global_position)
	Input.action_press("block")
	var blocked_n := [0]
	var got_hit := [0]
	var on_hit := func(info: DamageInfo) -> void:
		if info.blocked:
			blocked_n[0] += 1
		else:
			got_hit[0] += 1
	p.took_hit.connect(on_hit)
	for i in 200:
		await frames(1)
		st.refill()
		if blocked_n[0] + got_hit[0] > 0:
			break
	check("the shield blocks the swordsman's swing from the front", blocked_n[0] == 1 and got_hit[0] == 0 and p.hp == p.max_hp,
		"%d blocked, %d hits" % [blocked_n[0], got_hit[0]])
	blocked_n[0] = 0
	foe.reset_to_post()
	await place(Vector3(1, 0, -1.8), 180.0)  # back to the swordsman
	Input.action_press("block")
	for i in 400:
		await frames(1)
		if blocked_n[0] + got_hit[0] > 0:
			break
	check("its swing from behind gets past the shield", got_hit[0] == 1 and blocked_n[0] == 0 and p.hp == p.max_hp - 35.0, "hp %.0f" % p.hp)
	Input.action_release("block")
	p.took_hit.disconnect(on_hit)

	# Hit reactions and stagger.
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	foe.reset_to_post()
	var info := DamageInfo.make(25.0, p, p.global_position, foe.global_position, 2.0, "light")
	foe.receive_damage(info)
	check("a light hit hurts but doesn't stagger", foe.health == 75.0 and foe.state != JBDSwordsman.State.STAGGER)
	foe.reset_to_post()
	foe.receive_damage(DamageInfo.make(55.0, p, p.global_position, foe.global_position, 6.0, "heavy"))
	check("a heavy hit staggers it", foe.state == JBDSwordsman.State.STAGGER)
	foe.reset_to_post()

	# A careful fight: block its windups, hit it in its recovery and pauses.
	await place(Vector3(1, 0, 3.5), 0.0)
	p.hp = p.max_hp
	foe.process_mode = Node.PROCESS_MODE_INHERIT
	var swings := 0
	for i in 60 * 40:
		await frames(1)
		if p.dead or not foe.is_alive():
			break
		await face(foe.global_position)
		var dist := Vector2(foe.global_position.x - p.global_position.x, foe.global_position.z - p.global_position.z).length()
		var danger := foe.state == JBDSwordsman.State.WINDUP or foe.state == JBDSwordsman.State.ACTIVE
		if danger:
			Input.action_release("move_forward")
			Input.action_press("block")
		else:
			Input.action_release("block")
			var opening := foe.state in [JBDSwordsman.State.RECOVERY, JBDSwordsman.State.PAUSE, JBDSwordsman.State.STAGGER]
			if dist > 1.9:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			if opening and dist < 2.2 and not sw.attacking() and st.value > 40.0 and p.shield.raise_progress <= 0.0:
				await tap("attack_light")
				swings += 1
	release_all()
	check("Jeffrey can beat the swordsman by blocking and punishing", not foe.is_alive() and not p.dead,
		"swordsman %.0f hp, Jeffrey %.0f hp, %d swings" % [foe.health, p.hp, swings])
	check("the swordsman dies", foe.state == JBDSwordsman.State.DEAD)
