extends Node
## Headless test of the level tools:
##   godot --headless --path . res://tests/level_tools_test.tscn
## Checks the terrain brushes, every palette piece, prefabs, new levels,
## and plays levels/example_camp.tscn through the real game.

const Catalog := preload("res://addons/jbd_level_tools/catalog.gd")
const Plugin := preload("res://addons/jbd_level_tools/plugin.gd")
const TMP := "user://level_tools_test/"

var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	_terrain_brushes()
	await _blocks_and_palette()
	await get_tree().process_frame  # let the palette test's pieces go
	_prefab_and_new_level()
	await _play_example_level()
	print("LEVEL TOOLS TEST DONE, failures: %d" % failures)
	get_tree().quit(failures)


func check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		failures += 1


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _terrain_brushes() -> void:
	var data := JBDTerrainData.new()
	data.setup(64, 64, 1.0)
	var t := JBDTerrain.new()
	t.data = data
	add_child(t)
	var c := Vector2(32, 32)

	t.apply_brush(JBDTerrain.Tool.RAISE, c, 5.0, 2.0, 0.0, 1.0)
	check("raise lifts the centre", data.get_height(32, 32) > 1.9, "%.2f" % data.get_height(32, 32))
	check("raise leaves outside the brush alone", data.get_height(32, 38) == 0.0 and data.get_height(40, 32) == 0.0)

	t.apply_brush(JBDTerrain.Tool.LOWER, c, 5.0, 2.0, 0.0, 1.0)
	check("lower undoes raise", absf(data.get_height(32, 32)) < 0.001)

	t.apply_brush(JBDTerrain.Tool.SET_HEIGHT, c, 6.0, 1.0, 1.0, 1.0, 8.0)
	check("cliff tool makes a sheer plateau", data.get_height(32, 32) == 8.0 and data.get_height(36, 32) == 8.0 and data.get_height(39, 32) == 0.0,
		"%.1f %.1f %.1f" % [data.get_height(32, 32), data.get_height(36, 32), data.get_height(39, 32)])
	var edge_before := data.get_height(38, 32)
	t.apply_brush(JBDTerrain.Tool.SMOOTH, Vector2(38, 32), 3.0, 1.0, 0.0, 1.0)
	check("smooth softens the cliff edge", data.get_height(38, 32) != edge_before and data.get_height(38, 32) > 0.0)

	t.apply_brush(JBDTerrain.Tool.FLATTEN, Vector2(10, 10), 4.0, 1.0, 1.0, 1.0, 3.0)
	check("flatten levels to the target", absf(data.get_height(10, 10) - 3.0) < 0.001)

	t.apply_ramp(Vector3(10, 0, 50), Vector3(30, 10, 50), 4.0, 1.0)
	check("ramp slopes evenly", absf(data.get_height(20, 50) - 5.0) < 0.6, "%.2f" % data.get_height(20, 50))

	t.apply_brush(JBDTerrain.Tool.PAINT, Vector2(50, 50), 3.0, 1.0, 1.0, 1.0, 0.0, 2)
	var p: Color = data.paint[data.index(50, 50)]
	check("paint fills a layer and keeps weights normalised", p.b > 0.99 and absf(p.r + p.g + p.b + p.a - 1.0) < 0.001, str(p))

	t.rebuild()
	var hit = t.raycast(Vector3(32, 50, 32), Vector3.DOWN)
	check("terrain raycast finds the plateau", hit != null and absf(hit.y - 8.0) < 0.05, str(hit))
	check("terrain builds chunk meshes", t.get_children(true).filter(func(n): return n is MeshInstance3D and not n.is_queued_for_deletion()).size() == 4)
	t.queue_free()


func _blocks_and_palette() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	var ok := true
	var bad := []
	for id in Catalog.ITEMS:
		var n := Catalog.make(id, rng)
		if n == null:
			ok = false
			bad.append(id)
			continue
		holder.add_child(n)
	check("every palette piece can be made", ok, str(bad))
	await get_tree().process_frame

	var ramp := Catalog.make("ramp", rng)
	ramp.position = Vector3(100, 0, 0)
	holder.add_child(ramp)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := ramp.get_world_3d().direct_space_state
	var high := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100, 20, -3.8), Vector3(100, -1, -3.8)))
	var low := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100, 20, 3.8), Vector3(100, -1, 3.8)))
	check("ramp climbs toward -Z", not high.is_empty() and not low.is_empty() and high.position.y > 2.5 and low.position.y < 0.5,
		"%s %s" % [high.get("position"), low.get("position")])

	var anchor := Catalog.make("hook_anchor", rng)
	holder.add_child(anchor)
	check("hook anchor is grapple-able", anchor.is_in_group("grapple"))
	var wall := Catalog.make("wall", rng)
	holder.add_child(wall)
	check("plain wall is not", not wall.is_in_group("grapple"))

	var arch := Catalog.make("arch", rng)
	arch.position = Vector3(120, 0, 0)
	holder.add_child(arch)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(120, 1, 5), Vector3(120, 1, -5)))
	var solid := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(121.6, 1, 5), Vector3(121.6, 1, -5)))
	check("arch has a hole you can walk through", through.is_empty() and not solid.is_empty())

	var r1 := Catalog.make("rock", rng)
	var r2 := Catalog.make("rock", rng)
	holder.add_child(r1)
	holder.add_child(r2)
	check("rocks come out different", r1.rock_seed != r2.rock_seed)

	var warden := Catalog.make("warden", rng)
	check("warden arrives with a patrol route", warden.get_children().filter(func(n): return n is Marker3D).size() == 2)
	var hollow := Catalog.make("hollow", rng)
	check("hollow defaults to night-only", hollow.night_only and hollow.health == 420.0)
	warden.free()
	hollow.free()
	check("grid snap", Catalog.snap(Vector3(1.26, 3.3, -0.74), 0.5, false) == Vector3(1.5, 3.3, -0.5))
	holder.queue_free()


func _prefab_and_new_level() -> void:
	var scene := Node3D.new()
	add_child(scene)
	var rng := RandomNumberGenerator.new()
	var pieces: Array[Node3D] = []
	for i in 3:
		var b := Catalog.make("platform", rng)
		scene.add_child(b)
		b.owner = scene
		b.position = Vector3(10 + i * 2, 1, 4)
		pieces.append(b)
	var err := Plugin.save_prefab(pieces, "Test steps", TMP + "test_steps.tscn")
	var inst: Node = (load(TMP + "test_steps.tscn") as PackedScene).instantiate()
	check("prefab saves the selected pieces", err == OK and inst.get_child_count() == 3, "err %d children %d" % [err, inst.get_child_count()])
	check("prefab is centred at floor level", inst.get_child(1).position == Vector3(0, 0, 0) and inst.get_child(0).position == Vector3(-2, 0, 0), str(inst.get_child(0).position))
	inst.free()
	scene.queue_free()

	var path := TMP + "brand_new.tscn"
	err = Plugin.create_level(path, "Brand New")
	var lvl: Node = (load(path) as PackedScene).instantiate()
	check("new level has terrain, start and a fire", err == OK and lvl is JBDLevel and lvl.get_node_or_null("Terrain") is JBDTerrain
		and lvl.get_node_or_null("PlayerStart") is JBDPlayerStart and lvl.get_node_or_null("Gameplay/Campfire") is JBDCampfire)
	check("new level's terrain data is saved beside it", ResourceLoader.exists(TMP + "brand_new_terrain.res"))
	lvl.free()


func _play_example_level() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.level_scene = load("res://levels/example_camp.tscn")
	add_child(main)
	var p: CharacterBody3D = main.player
	Game.set_hour(12.0)
	await wait(1.5)
	var start: Node3D = get_tree().get_first_node_in_group("player_start")
	check("Jeffrey starts at the Player Start", start != null and Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(start.global_position.x, start.global_position.z)) < 0.5, str(p.global_position))
	check("and stands on the terrain", p.is_on_floor() and absf(p.global_position.y - main.world.get_node("Terrain").height_at(p.global_position)) < 0.3, str(p.global_position))
	check("campfires are wired up", main.world.campfires.size() == 1 and main.world.campfires[0].fire_name == "Hide Camp")
	var enemies := get_tree().get_nodes_in_group("enemy")
	check("enemies spawn from their posts", enemies.size() == 2, str(enemies.size()))
	var warden = enemies.filter(func(e): return e.kind == "warden")[0]
	check("warden uses its patrol points", warden.waypoints.size() == 3 and absf(warden.waypoints[1].x - 8.0) < 0.01, str(warden.waypoints))
	check("warden stands on the plateau", absf(warden.global_position.y - 10.0) < 0.5, str(warden.global_position))
	check("hook anchors are grapple targets", get_tree().get_nodes_in_group("grapple").size() >= 4)

	# Walk to the campfire.
	var fire: Node3D = main.world.campfires[0]
	p.global_position = fire.global_position + Vector3(2.0, 0.5, 0)
	await wait(0.6)
	check("touching the fire sets the checkpoint", Game.checkpoint_name == "Hide Camp")

	# Stand on the hut's floor (a prefab instance).
	var hut: Node3D = main.world.get_node("Prefabs/Hut")
	p.global_position = hut.global_position + Vector3(0, 1.5, 0)
	await wait(1.0)
	check("prefab buildings are solid", p.is_on_floor() and p.global_position.y > hut.global_position.y + 0.4, str(p.global_position))

	# Walk up the carved ramp onto the plateau.
	p.global_position = Vector3(-32.4, 6, -6)
	await wait(0.8)
	var d := Vector3(-16.4, 10, -26) - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	Input.action_press("move_forward")
	await wait(9.0)
	Input.action_release("move_forward")
	check("the carved ramp is walkable", p.global_position.y > 8.0, str(p.global_position))

	var reached := [false]
	main.world.goal_reached.connect(func(): reached[0] = true)
	p.global_position = Vector3(0, 10.5, -48)
	await wait(0.8)
	check("the level exit ends the level", reached[0])
	main.queue_free()
	await get_tree().process_frame
