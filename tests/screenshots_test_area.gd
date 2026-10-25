extends Node
## Renders views of the controller test area to user://shots (needs a real
## renderer, not --headless):
##   godot --rendering-driver opengl3 res://tests/screenshots_test_area.tscn

var main: Node3D
var p: JBDPlayer

var shots := [
	# [name, player position, look-at, setup]
	["controller_01_yard", Vector3(1, 0, 17), Vector3(0, 1.0, -12), ""],
	["controller_02_heavy_swing", Vector3(-3, 0, -7.2), Vector3(-3, 1.4, -9), "heavy"],
	["controller_03_block", Vector3(4, 0, -7.0), Vector3(4, 1.6, -9), "block"],
	["controller_04_course", Vector3(-3, 0, 11), Vector3(-15, 0.5, -4), ""],
	["controller_05_door", Vector3(1.5, 0, -15.5), Vector3(0, 1.2, -20), "door"],
	["controller_06_opening_pieces", Vector3(-2, 1.5, -31), Vector3(2, 3, -60), ""],
	["controller_07_rope_bridge", Vector3(0, 6.1, -44.8), Vector3(0, 5.5, -60), ""],
	["controller_08_stone_bridge", Vector3(-5, 1.5, -47), Vector3(-16, 2.0, -50), ""],
	["controller_09_plank_bridge", Vector3(22, 3.5, -38), Vector3(16, 3, -50), ""],
]


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	p = main.player
	main.hud.help.visible = false
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	await get_tree().create_timer(4.5).timeout
	for s in shots:
		Game.set_hour(11.0)
		p.global_position = s[1]
		p.velocity = Vector3.ZERO
		var d: Vector3 = s[2] - p.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		await get_tree().physics_frame
		var c: Vector3 = s[2] - p.camera.global_position
		p.camera_rig.set_pitch_degrees(rad_to_deg(atan2(c.y, Vector2(c.x, c.z).length())))
		await get_tree().create_timer(0.8).timeout
		match s[3]:
			"heavy":
				await _press("attack_heavy")
				await get_tree().create_timer(p.sword.heavy_windup + 0.05).timeout
			"block":
				Input.action_press("block")
				var bully = main.world.get_node("Gameplay/AttackDummy")
				bully._timer = 0.0
				await get_tree().create_timer(bully.windup - 0.1).timeout
			"door":
				await get_tree().create_timer(0.2).timeout
		main.hud.message.visible = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = OS.get_user_data_dir() + "/shots/" + s[0] + ".png"
		img.save_png(path)
		print("saved ", path)
		Input.action_release("block")
		await get_tree().create_timer(0.6).timeout
	get_tree().quit()


func _press(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
