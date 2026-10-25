extends Node
## Headless playtest: godot --headless --path . res://tests/smoke_test.tscn
## Drives Jeffrey through the core mechanics and prints PASS/FAIL lines.

var main: Node3D
var p: CharacterBody3D
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	p = main.player
	await _run()
	print("SMOKE TEST DONE, failures: %d" % failures)
	get_tree().quit(failures)


func check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		failures += 1


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func place(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO


func aim_at(target: Vector3) -> void:
	var d := target - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await get_tree().physics_frame
	var c: Vector3 = target - p.camera.global_position
	p.head.rotation.x = atan2(c.y, Vector2(c.x, c.z).length())
	await get_tree().physics_frame
	await get_tree().physics_frame


func grapple_to(target: Vector3) -> void:
	await aim_at(target)
	p._update_aim()
	p._try_grapple()
	await wait(3.0)


func _run() -> void:
	Game.set_hour(12.0)
	await wait(1.5)
	check("spawn lands on the haunch", absf(p.global_position.y) < 0.3 and p.is_on_floor(), str(p.global_position))

	# Weighty movement: Jeffrey takes a moment to get up to speed and to stop.
	place(Vector3(0, 0.1, 6))
	p.rotation.y = 0.0
	await wait(0.5)
	var steps := [0]
	p.footstep.connect(func(_loud): steps[0] += 1)
	Input.action_press("move_forward")
	await wait(0.1)
	var early: float = Vector2(p.velocity.x, p.velocity.z).length()
	var cam_y: Array[float] = []
	for i in 30:
		await get_tree().physics_frame
		cam_y.append(p.camera.position.y)
	var cruising: float = Vector2(p.velocity.x, p.velocity.z).length()
	check("ramps up to speed", early < p.walk_speed * 0.5 and cruising > p.walk_speed * 0.9, "%.2f then %.2f" % [early, cruising])
	check("head bobs while walking", cam_y.max() - cam_y.min() > 0.01, "range %.3f" % (cam_y.max() - cam_y.min()))
	await wait(1.0)
	check("footsteps fire while walking", steps[0] >= 2, "%d steps" % steps[0])
	Input.action_release("move_forward")
	await wait(0.1)
	var sliding: float = Vector2(p.velocity.x, p.velocity.z).length()
	await wait(0.5)
	check("slides briefly to a stop", sliding > 0.5 and Vector2(p.velocity.x, p.velocity.z).length() < 0.05, "%.2f" % sliding)

	# Lean shifts the view sideways.
	Input.action_press("lean_right")
	await wait(0.6)
	check("lean right peeks sideways", p.camera.position.x > p.lean_distance * 0.8, "x %.2f" % p.camera.position.x)
	Input.action_release("lean_right")
	await wait(0.6)

	# A long fall hurts and dips the camera; a short one doesn't.
	p.heal_full()
	place(Vector3(0, 1.5, 6))
	await wait(1.0)
	check("short drop is harmless", p.hp == p.max_hp)
	place(Vector3(0, 11.0, 6))
	var dipped := [0.0]
	for i in 90:
		await get_tree().physics_frame
		dipped[0] = maxf(dipped[0], p.land_dip)
	check("long fall hurts and dips the view", p.hp < p.max_hp and dipped[0] > 0.1, "hp %.0f dip %.2f" % [p.hp, dipped[0]])
	p.heal_full()

	# Grapple onto the lookout pillar.
	place(Vector3(10, 0.1, 12))
	await wait(0.5)
	await aim_at(Vector3(10, 6.2, 4))
	p._update_aim()
	check("crosshair sees the wooden anchor", p.aim_grapple_valid)
	p._try_grapple()
	await wait(2.5)
	check("grapple onto lookout pillar", p.global_position.y > 6.0, str(p.global_position))

	# Grapple up the first cliff.
	place(Vector3(6, 0.1, -48))
	await wait(0.5)
	await grapple_to(Vector3(6, 11.7, -57.0))
	check("grapple up cliff to the Ribs", p.global_position.y > 11.5 and p.global_position.z < -56.9, str(p.global_position))

	# Grapple chain up to the Shoulder.
	place(Vector3(8, 12.1, -148))
	await wait(0.5)
	await grapple_to(Vector3(8, 21.5, -156.2))
	check("grapple onto mid ledge", p.global_position.y > 21.5, str(p.global_position))
	await grapple_to(Vector3(15, 31.7, -158.2))
	check("grapple onto the Shoulder", p.global_position.y > 31.5 and p.global_position.z < -157.9, str(p.global_position))

	# Grapple refuses plain stone.
	place(Vector3(0, 0.1, -50))
	await wait(0.5)
	await aim_at(Vector3(0, 6, -60))
	p._update_aim()
	check("grapple ignores stone", not p.aim_grapple_valid)

	# Walk up the guarded left ramp.
	place(Vector3(-27, 0.2, -27))
	await wait(0.3)
	await aim_at(Vector3(-27, 12, -70))
	Input.action_press("move_forward")
	await wait(12.0)
	Input.action_release("move_forward")
	check("ramp to the Ribs is walkable", p.global_position.y > 11.5, str(p.global_position))

	# Daylight vs night visibility.
	place(Vector3(0, 0.1, 5))
	Game.set_hour(12.0)
	await wait(1.5)
	var day_vis: float = p.visibility
	Game.set_hour(1.0)
	await wait(1.5)
	var night_vis: float = p.visibility
	check("more visible by day", day_vis > night_vis + 0.3, "day %.2f night %.2f" % [day_vis, night_vis])

	# A torch (any "light_source") lights Jeffrey up at night.
	var torch := Node3D.new()
	torch.add_to_group("light_source")
	main.add_child(torch)
	torch.global_position = p.global_position + Vector3(1, 1, 0)
	await wait(1.5)
	var torch_vis: float = p.visibility
	torch.queue_free()
	check("torches brighten the light gem", torch_vis > night_vis + 0.3, "%.2f" % torch_vis)

	# Hollows walk only at night.
	var hollows := get_tree().get_nodes_in_group("enemy").filter(func(e): return e.kind == "hollow")
	await wait(0.2)
	check("hollows active at night", hollows.all(func(e): return e.active))
	Game.set_hour(12.0)
	await wait(0.2)
	check("hollows gone by day", hollows.all(func(e): return not e.active))

	# A warden spots Jeffrey in daylight and kills him.
	var warden: Node = get_tree().get_nodes_in_group("enemy")[0]
	warden.reset_to_post()
	# Stand in the warden's path (it walks +X toward its next waypoint).
	place(warden.global_position + Vector3(8, 0.1, 0))
	await wait(4.0)
	check("warden notices and chases", warden.state == warden.State.CHASE, "state %d aw %.2f" % [warden.state, warden.awareness])
	var deaths := [0]
	p.died.connect(func(): deaths[0] += 1)
	await wait(9.0)
	check("warden can kill Jeffrey", deaths[0] > 0 or p.hp < 100.0, "hp %.0f" % p.hp)
	if not p.dead:
		p.die()
	await wait(5.5)
	check("respawn at the campfire", not p.dead and p.global_position.distance_to(Game.checkpoint_position) < 2.0 and p.hp == p.max_hp, str(p.global_position))

	# Sword is pitiful against a warden.
	warden.reset_to_post()
	var hp_before: float = warden.hp
	warden.take_damage(p.sword_damage, p.global_position)
	check("sword barely scratches a warden", warden.hp == hp_before - p.sword_damage and warden.hp > 200)

	# Blocking soaks most of a hit.
	warden.reset_to_post()
	place(Vector3(0, 0.1, 0))
	await wait(0.5)
	p.heal_full()
	p.blocking = true
	p.rotation.y = 0.0
	p.take_hit(40.0, p.global_position + Vector3(0, 0, -2))
	check("shield blocks most damage", p.hp > 90.0, "hp %.0f" % p.hp)

	# Resting at a campfire.
	Game.set_hour(14.0)
	p.hp = 20.0
	await main._rest(Game.MORNING_HOUR, "test")
	check("rest until morning", absf(Game.hour - Game.MORNING_HOUR) < 0.1 and p.hp == p.max_hp, "hour %.2f" % Game.hour)
	await main._rest(Game.EVENING_HOUR, "test")
	check("rest until evening is night", Game.is_night(), "hour %.2f" % Game.hour)

	# Reaching the tree.
	var reached := [false]
	main.world.goal_reached.connect(func(): reached[0] = true)
	place(Vector3(0, 32.2, -214))
	await wait(1.0)
	check("reaching the tree ends the slice", reached[0])
