extends Node3D
## Wires the slice together: input map, world, Jeffrey, HUD, campfires,
## resting, dying, and the Colossus's occasional footsteps.

const World := preload("res://scripts/world.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Hud := preload("res://scripts/hud.gd")
const DayNight := preload("res://scripts/day_night.gd")

## A level built with the Level Tools (addons/jbd_level_tools). Leave it
## empty to play the code-built greybox in world.gd.
@export var level_scene: PackedScene

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer

var current_fire: Node3D
var menu_open := false
var busy := false
var tremor_timer := 18.0
var first_tremor := true


func _ready() -> void:
	_setup_input()
	add_child(DayNight.new())
	world = level_scene.instantiate() if level_scene else World.new()
	add_child(world)
	var start := get_tree().get_first_node_in_group("player_start") as Node3D
	if start:
		Game.checkpoint_position = start.global_position

	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Game.checkpoint_position
	if start:
		player.rotation.y = start.global_rotation.y

	hud = Hud.new()
	add_child(hud)

	player.health_changed.connect(hud.set_health)
	player.stamina_changed.connect(hud.set_stamina)
	player.took_hit.connect(hud.flash_damage)
	player.died.connect(_on_player_died)
	for fire in world.campfires:
		fire.player_entered.connect(_on_fire_entered)
		fire.player_exited.connect(_on_fire_exited)
	world.goal_reached.connect(_on_goal_reached)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade_to(0.0, 2.0)
	hud.show_message("Follow the tree.", 3.0)


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_CTRL, KEY_C])
	_bind("attack", [], [MOUSE_BUTTON_LEFT])
	_bind("block", [], [MOUSE_BUTTON_RIGHT])
	_bind("grapple", [KEY_G], [MOUSE_BUTTON_MIDDLE])
	_bind("lean_left", [KEY_Q])
	_bind("lean_right", [KEY_E])
	_bind("interact", [KEY_F])
	_bind("rest_morning", [KEY_1])
	_bind("rest_evening", [KEY_2])
	_bind("toggle_help", [KEY_H])
	_bind("free_mouse", [KEY_ESCAPE])
	_bind("debug_time", [KEY_T])


func _bind(action: StringName, keys: Array, buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return  # already defined in Project Settings; respect that
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("debug_time"):
		Game.set_hour(Game.hour + 1.0)
	elif menu_open:
		if event.is_action_pressed("rest_morning"):
			_rest(Game.MORNING_HOUR, "Morning. The wardens can see you clearly now.")
		elif event.is_action_pressed("rest_evening"):
			_rest(Game.EVENING_HOUR, "Night falls. The Hollows are walking.")
		elif event.is_action_pressed("interact"):
			_close_menu()
	elif event.is_action_pressed("interact") and current_fire and not player.dead and not busy:
		menu_open = true
		player.input_locked = true
		hud.open_rest_menu(current_fire.fire_name)
		hud.set_prompt("")


func _process(delta: float) -> void:
	hud.set_visibility(player.visibility)
	hud.set_grapple_aim(player.aim_grapple_valid)
	hud.set_clock(Game.clock_text())

	tremor_timer -= delta
	if tremor_timer <= 0.0:
		tremor_timer = randf_range(22.0, 34.0)
		player.shake(1.4, 0.05)
		if first_tremor:
			first_tremor = false
			hud.show_message("The Colossus takes a step.", 2.0)


func _on_fire_entered(fire: Node3D) -> void:
	current_fire = fire
	if not fire.kindled:
		fire.kindled = true
		hud.show_message("%s kindled" % fire.fire_name, 2.0, Color(1.0, 0.7, 0.35))
	Game.checkpoint_position = fire.respawn_point()
	Game.checkpoint_name = fire.fire_name
	hud.set_prompt("[F] Rest at %s" % fire.fire_name)


func _on_fire_exited(fire: Node3D) -> void:
	if current_fire == fire:
		current_fire = null
		hud.set_prompt("")


func _close_menu() -> void:
	menu_open = false
	player.input_locked = false
	hud.close_rest_menu()
	if current_fire:
		hud.set_prompt("[F] Rest at %s" % current_fire.fire_name)


func _rest(hour: float, text: String) -> void:
	menu_open = false
	busy = true
	hud.close_rest_menu()
	await hud.fade_to(1.0, 0.8).finished
	Game.rest_until(hour)
	player.heal_full()
	_reset_enemies()
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 1.2).finished
	player.input_locked = false
	busy = false
	hud.show_message(text, 2.5)
	if current_fire:
		hud.set_prompt("[F] Rest at %s" % current_fire.fire_name)


func _reset_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.reset_to_post()


func _on_player_died() -> void:
	busy = true
	menu_open = false
	hud.close_rest_menu()
	hud.set_prompt("")
	hud.show_message("JEFFREY DIED", 2.0, Color(0.75, 0.08, 0.05))
	await get_tree().create_timer(2.2).timeout
	await hud.fade_to(1.0, 1.0).finished
	player.respawn(Game.checkpoint_position)
	_reset_enemies()
	await get_tree().create_timer(0.5).timeout
	await hud.fade_to(0.0, 1.2).finished
	player.input_locked = false
	busy = false


func _on_goal_reached() -> void:
	hud.show_message("The tree's pulse rattles your bones.\nNot yet, Jeffrey. Not yet.\n\n(End of the prototype slice)", 6.0, Color(1.0, 0.88, 0.5))
