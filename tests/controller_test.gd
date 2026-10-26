extends Node
## Headless acceptance tests for the first-person controller spec, run in
## the controller test level:
##   godot --headless --path . res://tests/controller_test.tscn
## Drives Jeffrey with the real Input Map actions (Input.action_press), so
## keys and controller buttons go through the same path. Real-controller
## feel can't be checked here; see the manual checklist in README.

var main: Node3D
var p: JBDPlayer
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.level_scene = load("res://levels/controller_test.tscn")
	add_child(main)
	p = main.player
	await _run()
	print("CONTROLLER TEST DONE, failures: %d" % failures)
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


## Press an action for exactly one physics tick.
func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame  # the action lands on this tick


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "block", "look_right", "look_left"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg := 0.0) -> void:
	release_all()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.camera_rig.set_pitch_degrees(0.0)
	p.dash.recovery_timer = 0.0
	p.sword.cancel()
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


func hspeed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _run() -> void:
	await wait(1.0)
	var mv := p.movement
	check("spawns standing at the Player Start", p.is_on_floor() and absf(p.global_position.y) < 0.05 and p.state == JBDPlayer.State.NORMAL, str(p.global_position))
	check("debug overlay is on in the test level", main.debug.visible and main.debug.text().contains("STATE"))
	check("no grappling hook in the test level", main.grapple == null)

	# --- Movement --------------------------------------------------------
	await place(Vector3(-20, 0, 26))
	Input.action_press("move_forward")
	await frames(6)
	var early := hspeed()
	await wait(1.0)
	var cruise := hspeed()
	check("accelerates smoothly to walking speed", early > 0.8 and early < 2.0 and absf(cruise - mv.walk_speed) < 0.05,
		"%.2f after 0.1 s, %.2f cruising" % [early, cruise])
	Input.action_press("run")
	await wait(0.4)
	var run := hspeed()
	Input.action_release("run")
	await wait(0.4)
	check("runs only while Run is held", absf(run - mv.run_speed) < 0.05 and absf(hspeed() - mv.walk_speed) < 0.05, "run %.2f then %.2f" % [run, hspeed()])
	Input.action_release("move_forward")
	await frames(6)
	var sliding := hspeed()
	await wait(0.3)
	check("decelerates over a few steps, then stops", sliding > 0.5 and sliding < 2.5 and hspeed() < 0.01, "%.2f after 0.1 s" % sliding)

	Input.action_press("move_forward", 0.5)
	await wait(1.0)
	var half := hspeed()
	Input.action_press("move_forward", 1.0)
	await wait(0.6)
	check("partial stick deflection walks slower", half > 0.8 and half < mv.walk_speed * 0.6, "half stick %.2f m/s" % half)
	Input.action_press("move_right")
	await wait(0.8)
	check("diagonals are normalised", absf(hspeed() - mv.walk_speed) < 0.05, "%.2f" % hspeed())
	release_all()
	Input.action_press("move_back")
	await wait(0.8)
	var back := p.velocity.dot(p.global_basis.z)
	Input.action_release("move_back")
	Input.action_press("move_left")
	await wait(0.8)
	var strafe := -p.velocity.dot(p.global_basis.x)
	release_all()
	check("walks backward and strafes", absf(back - mv.walk_speed) < 0.1 and absf(strafe - mv.walk_speed) < 0.1, "back %.2f strafe %.2f" % [back, strafe])

	# Jumping.
	await place(Vector3(-20, 0, 26))
	var y0 := p.global_position.y
	await tap("jump")
	var peak := y0
	for i in 60:
		await frames(1)
		peak = maxf(peak, p.global_position.y)
	check("jumps about 0.9 m and lands", absf(peak - y0 - 0.92) < 0.06 and p.is_on_floor(), "peak %.2f m" % (peak - y0))
	# Air control is weaker than ground control.
	await place(Vector3(-20, 0, 26))
	await tap("jump")
	Input.action_press("move_forward")
	await wait(0.2)
	var air := hspeed()
	release_all()
	await wait(0.8)
	check("air control is reduced", air < mv.walk_speed * 0.4 and air > 0.2, "%.2f m/s after 0.2 s in the air" % air)
	# Jump buffer: pressed just before landing still jumps.
	await place(Vector3(-20, 1.5, 26))
	await place(Vector3(-20, 0, 26))
	p.global_position.y = 0.5
	await frames(1)
	while p.velocity.y > -2.5 or p.global_position.y > 0.2:
		await frames(1)
	await tap("jump")
	await wait(0.15)
	check("jump buffer: a press just before landing jumps", p.global_position.y > 0.3, "y %.2f" % p.global_position.y)
	await wait(0.8)

	# Coyote time: jump a few frames after walking off the deck's edge.
	await place(Vector3(-12, 2, -6), 0.0)
	Input.action_press("move_forward")
	while mv.grounded:
		await frames(1)
	await frames(1)  # the jump lands about 50 ms after leaving the edge
	await tap("jump")
	await wait(0.9)
	Input.action_release("move_forward")
	await wait(0.3)
	check("coyote time: jump just after the edge clears the 1.5 m gap", p.global_position.y > 1.9 and p.global_position.z < -8.5, str(p.global_position))

	# A running jump over the 2.5 m gap.
	await place(Vector3(-12, 2, -12.5), 0.0)
	Input.action_press("move_forward")
	Input.action_press("run")
	while p.global_position.z > -14.2:
		await frames(1)
	await tap("jump")
	await wait(0.55)
	release_all()
	await wait(0.3)
	check("running jump clears the 2.5 m gap", p.global_position.y > 1.9 and p.global_position.z < -17.0, str(p.global_position))

	# Stairs, real steps, ramps.
	for t in [["smooth stairs", Vector3(-10, 0, 4), 2.8], ["25 cm steps", Vector3(-14, 0, 5), 2.8], ["21° ramp", Vector3(-20, 0, 8), 3.3]]:
		await place(t[1], 0.0)
		Input.action_press("move_forward")
		await wait(t[2])
		Input.action_release("move_forward")
		var top := 3.0 if t[0] == "21° ramp" else 2.0
		check("walks up the %s" % t[0], absf(p.global_position.y - top) < 0.1, str(p.global_position))
	await place(Vector3(-25, 0, 6), 0.0)
	Input.action_press("move_forward")
	await wait(3.0)
	Input.action_release("move_forward")
	await wait(0.5)
	check("can't walk up a 53° slope", p.global_position.y < 1.5, str(p.global_position))

	# Crouch: toggles, slows, fits under the 1.3 m ceiling, won't stand there.
	await place(Vector3(15, 0, 3), 0.0)
	await tap("crouch")
	await wait(0.4)
	check("crouch toggles and shrinks the capsule and view", mv.crouching and absf(mv.current_height - mv.crouch_height) < 0.01
		and p.capsule.height + p.leg_shape.length < mv.crouch_height + 0.01
		and absf(p.head.position.y - mv.current_eye_height()) < 0.01 and p.state == JBDPlayer.State.CROUCHING)
	Input.action_press("move_forward")
	await wait(1.0)
	check("crouch walks slower", absf(hspeed() - mv.crouch_speed) < 0.05, "%.2f" % hspeed())
	await wait(2.0)
	Input.action_release("move_forward")
	await wait(0.3)
	check("fits through the low passage", p.global_position.z < -1.0 and absf(p.global_position.x - 15) < 0.3, str(p.global_position))
	await tap("crouch")
	await wait(0.6)
	check("won't stand up under the ceiling", mv.crouching and mv.stand_blocked and mv.current_height < 1.31, "h %.2f" % mv.current_height)
	Input.action_press("move_forward")
	await wait(3.0)
	Input.action_release("move_forward")
	await wait(0.6)
	check("stands once clear", not mv.crouching and absf(mv.current_height - mv.standing_height) < 0.01, str(p.global_position))

	# --- Dash ---------------------------------------------------------------
	await place(Vector3(-20, 0, 26), 0.0)
	var before := p.global_position
	Input.action_press("move_right")
	await tap("dash")
	check("dash state", p.state == JBDPlayer.State.DASHING)
	await wait(p.dash.duration + 0.02)
	var during := p.global_position
	release_all()
	await wait(0.6)
	var dash_dist := flat(during - before).length()
	var side := (during - before).dot(p.global_basis.x)
	check("dash follows the stick and covers about 3 m in 0.22 s", absf(dash_dist - 3.0) < 0.3 and side > 2.7, "%.2f m" % dash_dist)
	before = p.global_position
	await tap("dash")
	await wait(0.4)
	var back_d := (p.global_position - before).dot(p.global_basis.z)
	check("dash with a centred stick goes backward", back_d > 2.5, "%.2f m back" % back_d)
	await tap("dash")
	var spam := p.dash.active
	await wait(0.3)
	await tap("dash")
	check("recovery prevents dash spam, then dash is available again", not spam and p.dash.active)
	await wait(0.6)
	await place(Vector3(22, 0, -2), 0.0)
	Input.action_press("move_right")
	await tap("dash")
	Input.action_press("look_right")
	var yaw0 := p.rotation.y
	await wait(0.3)
	release_all()
	check("dash stops at a wall without clipping", p.global_position.x < 24.0 - 0.3 and p.global_position.x > 23.0, "x %.2f" % p.global_position.x)
	check("camera look works during a dash", absf(p.rotation.y - yaw0) > 0.1, "turned %.1f°" % rad_to_deg(absf(p.rotation.y - yaw0)))
	await wait(0.3)
	await place(Vector3(-20, 0, 26), 0.0)
	await tap("dash")
	await tap("jump")
	check("no jumping mid-dash", p.velocity.y < 0.5)
	await wait(0.6)

	# --- Sword ----------------------------------------------------------------
	var dummy: JBDTrainingDummy = main.world.get_node("Gameplay/TrainingDummy")
	await place(Vector3(-3, 0, -7.4), 0.0)
	await aim_at(Vector3(-3, 1.3, -9))
	var hp0 := dummy.health
	var t0 := Time.get_ticks_msec()
	await tap("attack_light")
	check("light attack state", p.state == JBDPlayer.State.LIGHT_ATTACK)
	while dummy.health == hp0 and Time.get_ticks_msec() - t0 < 1000:
		await frames(1)
	var light_hit := (Time.get_ticks_msec() - t0) / 1000.0
	await wait(0.5)
	check("light attack hits once for its damage", hp0 - dummy.health == p.sword.light_damage, "%.0f damage" % (hp0 - dummy.health))
	hp0 = dummy.health
	t0 = Time.get_ticks_msec()
	await tap("attack_heavy")
	check("heavy attack state", p.state == JBDPlayer.State.HEAVY_ATTACK)
	while dummy.health == hp0 and Time.get_ticks_msec() - t0 < 2000:
		await frames(1)
	var heavy_hit := (Time.get_ticks_msec() - t0) / 1000.0
	await tap("dash")
	check("no dash during a heavy attack", not p.dash.active and p.sword.is_heavy())
	Input.action_press("block")
	await frames(2)
	check("raising the shield can't interrupt a swing", not p.shield.raised and p.sword.attacking())
	Input.action_release("block")
	await wait(0.8)
	check("heavy hits harder and later than light", hp0 - dummy.health == p.sword.heavy_damage and heavy_hit > light_hit + 0.25,
		"light lands at %.2f s, heavy at %.2f s" % [light_hit, heavy_hit])
	await wait(0.5)
	dummy.health = dummy.max_health
	p.stamina.refill()
	hp0 = dummy.health
	for i in 3:
		await tap("attack_light")
		await wait(p.sword.light_windup + p.sword.light_active + 0.05)
	await wait(0.4)
	check("light attacks chain", hp0 - dummy.health == p.sword.light_damage * 3, "%.0f damage" % (hp0 - dummy.health))
	Input.action_press("look_left")
	var yaw1 := p.rotation.y
	await tap("attack_heavy")
	await wait(0.3)
	Input.action_release("look_left")
	check("camera look works during an attack", absf(p.rotation.y - yaw1) > 0.1)
	await wait(1.0)
	# The blade doesn't pass through walls.
	await place(Vector3(10, 0, 1), 0.0)
	await aim_at(Vector3(10, 1.4, -1))
	p.rotation.y = deg_to_rad(90.0)  # face the corridor wall, dummy far away
	await tap("attack_light")
	await wait(0.5)
	check("blade stops at a wall", p.sword._blocked_by_wall or not p.sword.attacking())

	# --- Shield ---------------------------------------------------------------
	var bully: JBDAttackDummy = main.world.get_node("Gameplay/AttackDummy")
	await place(Vector3(4, 0, -7.2), 0.0)
	await aim_at(Vector3(4, 1.4, -9))
	p.heal_full()
	Input.action_press("block")
	await frames(2)
	await tap("attack_light")
	check("can't attack with the shield up", p.shield.raised and not p.sword.attacking() and p.state == JBDPlayer.State.BLOCKING)
	var hits: Array = []
	p.took_hit.connect(func(i: DamageInfo) -> void: hits.append(i))
	bully._timer = 0.0
	await wait(bully.windup + 0.2)
	var front_ok: bool = hits.size() == 1 and hits[0].blocked and p.hp > p.max_hp - bully.damage * 0.5
	check("frontal attack is blocked", front_ok, "%d hits, hp %.0f" % [hits.size(), p.hp])
	# Side-on (90°) and from behind: the shield doesn't cover.
	for t in [["side", 90.0], ["rear", 180.0]]:
		hits.clear()
		p.heal_full()
		p.global_position = Vector3(4, 0, -7.2)
		p.velocity = Vector3.ZERO
		await frames(2)
		p.rotation.y = atan2(-(bully.global_position - p.global_position).x, -(bully.global_position - p.global_position).z) + deg_to_rad(t[1])
		bully._timer = 0.0
		await wait(bully.windup + 0.2)
		check("%s attack gets past the shield" % t[0], hits.size() == 1 and not hits[0].blocked and p.hp <= p.max_hp - bully.damage + 0.01,
			"%d hits, hp %.0f" % [hits.size(), p.hp])
	Input.action_release("block")
	bully._timer = 99.0
	p.heal_full()

	# --- Interaction ---------------------------------------------------------
	var door: JBDDoor = main.world.get_node("Gameplay/Door")
	await place(Vector3(0, 0, -18.4), 0.0)
	await aim_at(Vector3(0, 1.2, -20))
	await frames(2)
	check("prompt shows when aiming at the door", main.hud.prompt.text.contains("Open door"), main.hud.prompt.text)
	await tap("interact")
	check("interacting state", p.state == JBDPlayer.State.INTERACTING)
	await wait(0.8)
	check("the door opens", door.is_open and absf(door._hinge.rotation.y) > 1.5)
	p.camera_rig.set_pitch_degrees(0.0)
	Input.action_press("move_forward")
	await wait(1.5)
	Input.action_release("move_forward")
	check("and you can walk through it", p.global_position.z < -21.0, str(p.global_position))

	var gate: JBDDoor = main.world.get_node("Gameplay/Gate")
	await place(Vector3(0, 0, -26.4), 0.0)
	await aim_at(Vector3(0, 1.2, -28))
	await frames(2)
	var notices: Array = []
	p.notice.connect(func(t: String) -> void: notices.append(t))
	await tap("interact")
	await wait(0.3)
	check("a locked gate says so and stays shut", not gate.is_open and notices.size() == 1 and main.hud.prompt.text.contains("Locked"))
	await place(Vector3(3.2, 0, -17.2), 0.0)
	await aim_at(Vector3(3.2, 0.6, -18.8))
	await frames(2)
	check("prompt shows for the lever", main.hud.prompt.text.contains("Pull lever"), main.hud.prompt.text)
	await tap("interact")
	await wait(0.8)
	check("the lever opens the gate", gate.is_open)

	var pickup: Node = main.world.get_node("Gameplay/Pickup")
	await place(Vector3(4, 0, 13.4), 0.0)
	await aim_at(Vector3(4, 0.4, 12))
	await tap("interact")
	await frames(2)
	check("a pickup is picked up", not is_instance_valid(pickup) and notices.back().contains("bone charm"))

	await place(Vector3(-4, 0, 15.8), 0.0)
	await aim_at(Vector3(-4, 0.4, 14))
	await frames(2)
	check("prompt shows for the campfire", main.hud.prompt.text.contains("Rest at Test Fire"), main.hud.prompt.text)
	await tap("interact")
	await frames(2)
	check("using the campfire opens the rest menu and locks input", main.menu_open and p.input_locked)
	# Menus read input events, so send a real one.
	var ev := InputEventAction.new()
	ev.action = "dash"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(3)
	check("Circle / Alt closes it", not main.menu_open and not p.input_locked and not p.dash.active)
	await place(Vector3(10, 0, -2), 0.0)
	await aim_at(Vector3(10, 1, -12))
	check("no prompt when nothing is in reach", main.hud.prompt.text == "")

	# --- Ladders and bridges ------------------------------------------------
	await place(Vector3(30, 0, -0.8), 0.0)
	Input.action_press("move_forward")
	await wait(0.6)
	check("walking into a ladder grabs it", p.state == JBDPlayer.State.CLIMBING)
	var t_climb := 0.0
	while (mv.ladder or p.global_position.y < 4.9) and t_climb < 5.0:
		await frames(1)
		t_climb += 1.0 / 60.0
	Input.action_release("move_forward")
	await wait(0.4)
	check("climbs to the top and steps off", p.is_on_floor() and absf(p.global_position.y - 5.0) < 0.1 and p.global_position.z < -2.6, str(p.global_position))
	# And back down: walk off the top over the ladder.
	p.rotation.y = PI
	Input.action_press("move_forward")
	await wait(0.8)
	var went_down: bool = mv.ladder != null
	while mv.ladder and t_climb < 12.0:
		await frames(1)
		t_climb += 1.0 / 60.0
	Input.action_release("move_forward")
	await wait(0.4)
	check("climbs back down from the top", went_down and p.is_on_floor() and p.global_position.y < 0.1 and p.hp == p.max_hp, str(p.global_position))

	# Interact also grabs a ladder, with a prompt.
	await place(Vector3(30, 0, -1.9), 0.0)
	await frames(2)
	check("standing at a ladder prompts Climb", main.hud.prompt.text.ends_with("Climb"), main.hud.prompt.text)
	await tap("interact")
	check("Interact grabs the ladder", p.state == JBDPlayer.State.CLIMBING)
	await frames(2)
	check("on the ladder the prompt says Let go", main.hud.prompt.text.ends_with("Let go"), main.hud.prompt.text)
	await tap("jump")
	check("Jump lets go of the ladder", mv.ladder == null)
	await wait(0.5)

	var cliff_ladder: JBDLadder = main.world.get_node("Mountains/CliffLadder")
	await place(Vector3(0, 0, cliff_ladder.global_position.z + 1.6), 0.0)
	Input.action_press("move_forward")
	t_climb = 0.0
	while (mv.ladder or p.global_position.y < 5.5) and t_climb < 6.0:
		await frames(1)
		t_climb += 1.0 / 60.0
	Input.action_release("move_forward")
	await wait(0.4)
	check("climbs the cliff ladder", p.global_position.y > 5.5, str(p.global_position))
	p.global_position = Vector3(0, 6.3, -46.0)
	p.rotation.y = 0.0
	await wait(0.4)
	Input.action_press("move_forward")
	await wait(3.6)
	Input.action_release("move_forward")
	await wait(0.3)
	check("crosses the rope bridge to the plateau", p.global_position.y > 4.5 and p.global_position.z < -54.0 and p.is_on_floor(), str(p.global_position))
	await place(Vector3(16, 3.2, -44.5), 0.0)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await wait(3.5)
	release_all()
	check("plank bridge railings stop you falling off", p.global_position.y > 2.9 and p.global_position.z < -52.0, str(p.global_position))
	await place(Vector3(-16, 0, -33), 0.0)
	Input.action_press("move_forward")
	await wait(7.0)
	Input.action_release("move_forward")
	check("stairs and stone bridge cross to the far platform", p.global_position.y > 2.9 and p.global_position.z < -54.0, str(p.global_position))

	# --- Head bob, fullscreen, controller mapping -----------------------------
	var walk_bob: float = await _bob_amplitude(false)
	var crouch_bob: float = await _bob_amplitude(true)
	check("walking bobs the head subtly", walk_bob > 0.01 and walk_bob < 0.05, "%.3f m" % walk_bob)
	check("crouch-walking bobs a bit more", crouch_bob > walk_bob * 1.2 and crouch_bob < 0.08, "%.3f m" % crouch_bob)
	check("the game starts fullscreen", ProjectSettings.get_setting("display/window/size/mode") == DisplayServer.WINDOW_MODE_FULLSCREEN)
	check("F11 toggles fullscreen", InputMap.action_has_event("toggle_fullscreen", _key(KEY_F11)))
	p.input.enabled = false
	var pad := {
		"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "crouch": JOY_BUTTON_Y,
		"block": JOY_BUTTON_LEFT_SHOULDER, "attack_light": JOY_BUTTON_RIGHT_SHOULDER,
	}
	var pad_ok := true
	for action in pad:
		_pad_button(pad[action], true)
		if not Input.is_action_pressed(action):
			pad_ok = false
			print("  %s not on its PS5 button" % action)
		_pad_button(pad[action], false)
	check("Cross/Circle/Square/Triangle/L1/R1 map to jump/dash/interact/crouch/block/light", pad_ok)
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var triggers_ok := Input.is_action_pressed("run") and Input.is_action_pressed("attack_heavy")
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	triggers_ok = triggers_ok and not Input.is_action_pressed("run") and not Input.is_action_pressed("attack_heavy")
	check("L2 runs and R2 heavy-attacks as analog triggers", triggers_ok)
	_pad_axis(JOY_AXIS_LEFT_Y, -0.5)
	_pad_axis(JOY_AXIS_RIGHT_X, 0.8)
	var half_stick := Input.get_action_strength("move_forward")
	var sticks_ok := half_stick > 0.3 and half_stick < 0.6 and Input.get_action_strength("look_right") > 0.7
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	check("left stick moves (analog), right stick looks", sticks_ok)
	p.input.enabled = true
	check("a Sony pad is recognised by name", Gamepad.is_sony_name("PS5 Controller") and Gamepad.is_sony_name("DualSense Wireless Controller") and not Gamepad.is_sony_name("Xbox Series Controller"))
	var line := Gamepad.sony_mapping("030000004c050000e60c000000000000", "DualSense Wireless Controller")
	check("the DualSense fallback layout puts Cross on A and L2 on the left trigger",
		line.begins_with("030000004c050000e60c000000000000,DualSense Wireless Controller,") and line.contains("a:b1,") and line.contains("lefttrigger:a3"), line)

	# --- Death ------------------------------------------------------------------
	var died := [false]
	p.died.connect(func() -> void: died[0] = true)
	var dmg := DamageInfo.make(500.0, null, p.global_position + Vector3.FORWARD, p.global_position)
	p.receive_damage(dmg)
	await frames(2)
	check("dead state; input is off", died[0] and p.state == JBDPlayer.State.DEAD and not p.input.enabled)
	await wait(5.5)
	check("respawns at the checkpoint", not p.dead and p.hp == p.max_hp and p.state != JBDPlayer.State.DEAD)


## Peak-to-peak head bob over a second of walking (or crouch-walking).
func _bob_amplitude(crouched: bool) -> float:
	await place(Vector3(0, 0, 12), 180.0)
	if crouched:
		await tap("crouch")
		await wait(0.5)
	Input.action_press("move_forward")
	await wait(0.6)
	var lo := 1.0
	var hi := -1.0
	for i in 60:
		await frames(1)
		lo = minf(lo, p.camera.position.y)
		hi = maxf(hi, p.camera.position.y)
	Input.action_release("move_forward")
	if crouched:
		await tap("crouch")
		await wait(0.5)
	return hi - lo


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	return ev


func _pad_button(b: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = b
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _pad_axis(a: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = a
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
