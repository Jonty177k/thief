extends Node3D
## Wires the game together: world or level, Jeffrey, HUD, campfires,
## resting, dying, and the Colossus's occasional footsteps. Bindings are
## in Project Settings > Input Map.

const World := preload("res://scripts/world.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Hud := preload("res://scripts/hud.gd")
const DayNight := preload("res://scripts/day_night.gd")
const DebugOverlay := preload("res://scripts/debug_overlay.gd")

## A level built with the Level Tools (addons/jbd_level_tools). Leave it
## empty to play the code-built greybox in world.gd.
@export var level_scene: PackedScene

var world: Node3D
var player: JBDPlayer
var hud: CanvasLayer
var debug: CanvasLayer
var grapple: GrappleHook

var resting_fire: Node3D
var menu_open := false
var busy := false
var tremor_timer := 18.0
var first_tremor := true


func _ready() -> void:
	add_child(DayNight.new())
	world = level_scene.instantiate() if level_scene else World.new()
	add_child(world)
	if _level_setting("start_hour", -1.0) >= 0.0:
		Game.set_hour(_level_setting("start_hour", -1.0))
	var start := get_tree().get_first_node_in_group("player_start") as Node3D
	if start:
		Game.checkpoint_position = start.global_position

	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Game.checkpoint_position
	if start:
		player.rotation.y = start.global_rotation.y
	if _level_setting("allow_grapple", true):
		grapple = GrappleHook.new()
		grapple.name = "GrappleHook"
		player.add_child(grapple)

	hud = Hud.new()
	add_child(hud)
	hud.set_grapple_enabled(grapple != null)
	var gamepad := Gamepad.new()
	gamepad.name = "Gamepad"
	gamepad.connected.connect(func(_d: int, n: String) -> void: hud.show_message("Controller connected: " + n, 2.5))
	gamepad.disconnected.connect(func(_d: int) -> void: hud.show_message("Controller disconnected", 2.5))
	add_child(gamepad)
	debug = DebugOverlay.new()
	debug.player = player
	debug.visible = _level_setting("show_debug_overlay", false)
	add_child(debug)

	player.health_changed.connect(hud.set_health)
	player.took_hit.connect(hud.flash_damage)
	player.died.connect(_on_player_died)
	player.notice.connect(func(text: String) -> void: hud.show_message(text, 1.5))
	player.interaction.prompt_changed.connect(hud.set_prompt)
	for fire in world.campfires:
		fire.player_entered.connect(_on_fire_entered)
		fire.rest_requested.connect(_open_rest_menu)
	world.goal_reached.connect(_on_goal_reached)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade_to(0.0, 2.0)
	hud.show_message(_level_setting("intro_text", "Follow the tree."), 3.0)


## The game starts fullscreen (Project Settings > Display > Window > Mode).
## F11 switches to a window and back.
func _toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
	else:
		w.mode = Window.MODE_FULLSCREEN


## A setting from the level root (JBDLevel), or `default` for the greybox.
func _level_setting(key: String, default: Variant) -> Variant:
	var v = world.get(key) if world else null
	return default if v == null else v


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_debug"):
		debug.visible = not debug.visible
	elif event.is_action_pressed("debug_time"):
		Game.set_hour(Game.hour + 1.0)
	elif menu_open:
		if event.is_action_pressed("rest_morning"):
			_rest(Game.MORNING_HOUR, "Morning. The wardens can see you clearly now.")
		elif event.is_action_pressed("rest_evening"):
			_rest(Game.EVENING_HOUR, "Night falls. The Hollows are walking.")
		elif event.is_action_pressed("interact") or event.is_action_pressed("dash"):
			_close_menu()


func _process(delta: float) -> void:
	hud.set_visibility(player.visibility)
	hud.set_grapple_aim(grapple != null and grapple.aim_valid)
	hud.set_clock(Game.clock_text())

	if not _level_setting("colossus_tremors", true):
		return
	tremor_timer -= delta
	if tremor_timer <= 0.0:
		tremor_timer = randf_range(22.0, 34.0)
		player.shake(1.4, 0.05)
		if first_tremor:
			first_tremor = false
			hud.show_message("The Colossus takes a step.", 2.0)


func _on_fire_entered(fire: Node3D) -> void:
	if not fire.kindled:
		fire.kindled = true
		hud.show_message("%s kindled" % fire.fire_name, 2.0, Color(1.0, 0.7, 0.35))
	Game.checkpoint_position = fire.respawn_point()
	Game.checkpoint_name = fire.fire_name


func _open_rest_menu(fire: Node3D) -> void:
	if player.dead or busy or menu_open:
		return
	_on_fire_entered(fire)
	resting_fire = fire
	menu_open = true
	player.input_locked = true
	hud.open_rest_menu(fire.fire_name, player.input.using_gamepad)


func _close_menu() -> void:
	menu_open = false
	# Let go of the button that closed the menu before Jeffrey can act again.
	await get_tree().physics_frame
	player.input_locked = false
	hud.close_rest_menu()


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
