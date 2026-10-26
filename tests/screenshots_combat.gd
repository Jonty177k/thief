extends Node
## Renders views of the combat and traversal test levels to user://shots
## (needs a real renderer, not --headless):
##   godot --rendering-driver opengl3 res://tests/screenshots_combat.tscn

var main: Node3D
var p: JBDPlayer

var only := OS.get_cmdline_user_args()
var shots := [
	# [name, level, hour, player position, look-at, setup]
	["combat_01_arena", "res://levels/combat_arena.tscn", 12.0, Vector3(0, 0, 11), Vector3(0, 1.0, -6), "freeze"],
	["combat_02_windup", "res://levels/combat_arena.tscn", 12.0, Vector3(1, 0, -1.6), Vector3(1, 1.5, -4), "windup"],
	["combat_03_block", "res://levels/combat_arena.tscn", 12.0, Vector3(1, 0, -1.6), Vector3(1, 1.5, -4), "block"],
	["combat_04_light_hitbox", "res://levels/combat_arena.tscn", 12.0, Vector3(-6.4, 0, 2), Vector3(-8, 1.3, 2), "light"],
	["bow_01_range", "res://levels/archery_range.tscn", 23.0, Vector3(0, 0, 11), Vector3(0, 1.5, -8), "bow"],
	["bow_02_draw_fire", "res://levels/archery_range.tscn", 23.0, Vector3(6, 0, 5), Vector3(12, 2.2, 2), "draw_fire"],
	["bow_03_torch_lit", "res://levels/archery_range.tscn", 23.0, Vector3(-6, 0, 5), Vector3(-12, 1.5, 2), "bow"],
	["bow_04_torch_out", "res://levels/archery_range.tscn", 23.0, Vector3(-6, 0, 5), Vector3(-12, 1.5, 2), "douse"],
	["bow_05_crates_burning", "res://levels/archery_range.tscn", 23.0, Vector3(2, 0, 3), Vector3(5, 0.8, -3), "burn"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	for s in shots:
		if only.is_empty() or s[0] in only:
			await _shoot(s)
	get_tree().quit()


func _shoot(s: Array) -> void:
	if main == null or main.level_scene.resource_path != s[1]:
		if main:
			main.queue_free()
			await get_tree().process_frame
		main = load("res://scenes/main.tscn").instantiate()
		main.level_scene = load(s[1])
		add_child(main)
		p = main.player
		main.hud.help.visible = false
		await get_tree().create_timer(3.0).timeout
	Game.set_hour(s[2])
	p.global_position = s[3]
	p.velocity = Vector3.ZERO
	var d: Vector3 = s[4] - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await get_tree().physics_frame
	var c: Vector3 = s[4] - p.camera.global_position
	p.camera_rig.set_pitch_degrees(rad_to_deg(atan2(c.y, Vector2(c.x, c.z).length())))
	var foe = main.world.get_node_or_null("Enemies/Swordsman")
	if foe:
		foe.reset_to_post()
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.6).timeout
	match s[5]:
		"windup", "block":
			if s[5] == "block":
				Input.action_press("block")
			foe.process_mode = Node.PROCESS_MODE_INHERIT
			while foe.state != JBDSwordsman.State.WINDUP:
				await get_tree().physics_frame
			while foe.state == JBDSwordsman.State.WINDUP and foe.state_time < (0.45 if s[5] == "windup" else 0.6):
				await get_tree().physics_frame
			foe.process_mode = Node.PROCESS_MODE_DISABLED
		"light":
			await _press("attack_light")
			await get_tree().create_timer(p.sword.light_windup + 0.1).timeout
		"bow", "draw_fire", "douse", "burn":
			p.loadout.equip_now(PlayerLoadout.Slot.BOW)
			match s[5]:
				"draw_fire":
					p.bow.selected = 1
					Input.action_press("attack_heavy")
					await get_tree().create_timer(0.9).timeout
				"douse":
					main.world.get_node("Gameplay/LitTorch").lit = false
					await get_tree().create_timer(0.5).timeout
				"burn":
					main.world.get_node("Building/Crates/Flammable").ignite()
					await get_tree().create_timer(2.6).timeout
				_:
					await get_tree().create_timer(0.5).timeout
	main.hud.message.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path: String = OS.get_user_data_dir() + "/shots/" + s[0] + ".png"
	img.save_png(path)
	print("saved ", path)
	Input.action_release("block")
	Input.action_release("attack_heavy")
	if p.bow.drawing:
		p.bow.cancel()
	await get_tree().create_timer(0.4).timeout


func _press(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
