extends Node
## Launched by the dock's Play buttons: loads the game with the level you
## were editing, optionally from the editor camera's position and at a
## chosen hour.

const SETTINGS := "user://jbd_playtest.json"


func _ready() -> void:
	var cfg: Dictionary = {}
	if FileAccess.file_exists(SETTINGS):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if parsed is Dictionary:
			cfg = parsed
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var level_path: String = cfg.get("level", "")
	if level_path != "" and ResourceLoader.exists(level_path):
		main.level_scene = load(level_path)
	add_child(main)

	var hour: float = cfg.get("hour", -1.0)
	if hour < 0.0 and main.world.get("start_hour") != null:
		hour = main.world.start_hour
	if hour >= 0.0:
		Game.set_hour(hour)

	if cfg.has("start"):
		var s: Array = cfg.start
		var pos := Vector3(s[0], s[1], s[2])
		# Drop from the camera onto whatever is underneath it.
		await get_tree().physics_frame
		var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 500.0, 1)
		var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			pos = hit.position + Vector3.UP * 0.1
		main.player.global_position = pos
		main.player.velocity = Vector3.ZERO
		main.player.rotation.y = cfg.get("yaw", 0.0)
		Game.checkpoint_position = pos
