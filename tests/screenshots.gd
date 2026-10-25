extends Node
## Renders a few views to user://shots (needs a real renderer, not --headless).
## godot --rendering-driver opengl3 res://tests/screenshots.tscn

var shots := [
	# [name, hour, player position, look-at]
	["01_start_day", 9.5, Vector3(0, 0.1, 14), Vector3(0, 60, -222)],
	["02_dusk_cliff", 18.3, Vector3(-4, 0.1, -36), Vector3(4, 10, -60)],
	["03_ribs_night", 23.0, Vector3(-28, 12.1, -106), Vector3(10, 18, -130)],
	["04_shoulder_tree", 12.0, Vector3(14, 32.1, -175), Vector3(0, 55, -222)],
]


func _ready() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p = main.player
	main.hud.help.visible = false
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	await get_tree().create_timer(2.5).timeout
	for s in shots:
		Game.set_hour(s[1])
		p.global_position = s[2]
		var d: Vector3 = s[3] - p.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		var c: Vector3 = s[3] - (p.global_position + Vector3(0, 1.6, 0))
		p.head.rotation.x = atan2(c.y, Vector2(c.x, c.z).length())
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = OS.get_user_data_dir() + "/shots/" + s[0] + ".png"
		img.save_png(path)
		print("saved ", path)
	get_tree().quit()
