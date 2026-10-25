@tool
extends EditorPlugin
## JBD Level Tools: terrain sculpting and painting, click-to-place gameplay
## objects and building blocks with grid snapping, prefabs, and one-click
## play-testing. Everything goes through the editor's undo history.

const Dock := preload("res://addons/jbd_level_tools/dock.gd")
const Catalog := preload("res://addons/jbd_level_tools/catalog.gd")
const PLAYTEST_SCENE := "res://addons/jbd_level_tools/playtest/playtest.tscn"
const PLAYTEST_SETTINGS := "user://jbd_playtest.json"
const LEVEL_DIR := "res://levels/"

var dock: Dock
var terrain: JBDTerrain

# Brush cursor, drawn straight into the edited world (never saved).
var _cursor_mesh: ImmediateMesh
var _cursor_instance := RID()
var _cursor_hit: Variant = null

# Terrain stroke in progress.
var _stroking := false
var _stroke_inverted := false
var _stroke_target := 0.0
var _stroke_region := Rect2i()
var _stroke_old_heights: PackedFloat32Array
var _stroke_old_paint: PackedColorArray
var _ramp_start: Variant = null

# Placement.
var _ghost: Node3D
var _ghost_id := ""
var _ghost_yaw := 0.0
var _place_pos := Vector3.ZERO
var _place_normal := Vector3.UP
var _place_valid := false
var _scatter_last: Variant = null
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	dock = Dock.new()
	dock.new_terrain_requested.connect(_on_new_terrain)
	dock.new_level_requested.connect(_on_new_level)
	dock.play_requested.connect(_on_play)
	dock.save_prefab_requested.connect(_on_save_prefab)
	dock.make_main_level_requested.connect(_on_make_main_level)
	dock.mode_changed.connect(_on_mode_changed)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	set_input_event_forwarding_always_enabled()
	_cursor_mesh = ImmediateMesh.new()
	_cursor_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_cursor_instance, _cursor_mesh.get_rid())
	RenderingServer.instance_set_visible(_cursor_instance, false)
	set_process(true)


func _exit_tree() -> void:
	_clear_ghost()
	if _cursor_instance.is_valid():
		RenderingServer.free_rid(_cursor_instance)
	remove_control_from_docks(dock)
	dock.queue_free()


func _handles(object: Object) -> bool:
	return object is JBDTerrain


func _edit(object: Object) -> void:
	if object is JBDTerrain:
		_set_terrain(object)


func _set_terrain(t: JBDTerrain) -> void:
	terrain = t
	dock.set_terrain(t)


func _on_selection_changed() -> void:
	for n in get_editor_interface().get_selection().get_selected_nodes():
		if n is JBDTerrain:
			_set_terrain(n)
			return


func _on_mode_changed() -> void:
	_ramp_start = null
	if dock.armed_item != _ghost_id:
		_clear_ghost()
	if dock.terrain_tool >= 0 and (terrain == null or not is_instance_valid(terrain) or not terrain.is_inside_tree()):
		_set_terrain(_find_terrain())
		if terrain == null:
			dock.set_status("Add a terrain first (Terrain tab, bottom).")
	if dock.terrain_tool < 0:
		RenderingServer.instance_set_visible(_cursor_instance, false)


func _find_terrain() -> JBDTerrain:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	if root is JBDTerrain:
		return root
	var found := root.find_children("*", "JBDTerrain", true, true)
	return found[0] if not found.is_empty() else null


# --- Viewport input -------------------------------------------------------

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if get_editor_interface().get_edited_scene_root() == null:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (dock.terrain_tool >= 0 or dock.armed_item != ""):
		dock.disarm()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (dock.terrain_tool >= 0 or dock.armed_item != ""):
		if not _stroking:
			dock.disarm()
			return AFTER_GUI_INPUT_STOP
	if dock.terrain_tool >= 0 and terrain and is_instance_valid(terrain) and terrain.data:
		return _terrain_input(camera, event)
	if dock.armed_item != "":
		return _place_input(camera, event)
	return AFTER_GUI_INPUT_PASS


func _terrain_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			dock.resize_brush(1.0 / 1.2)
			return AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_BRACKETRIGHT:
			dock.resize_brush(1.2)
			return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouse:
		_cursor_hit = terrain.raycast(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		_draw_cursor(camera)
	if event is InputEventMouseMotion:
		# Let the camera orbit/fly through, but swallow drags while painting.
		return AFTER_GUI_INPUT_STOP if _stroking else AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _cursor_hit == null:
				return AFTER_GUI_INPUT_PASS
			if event.ctrl_pressed and dock.terrain_tool in [JBDTerrain.Tool.SET_HEIGHT, JBDTerrain.Tool.FLATTEN]:
				dock.set_target_height(terrain.to_local(_cursor_hit).y)
				dock.set_status("Height picked: %.2f m" % terrain.to_local(_cursor_hit).y)
				return AFTER_GUI_INPUT_STOP
			_begin_stroke(event.shift_pressed)
		elif _stroking:
			_end_stroke()
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _begin_stroke(inverted: bool) -> void:
	_stroking = true
	_stroke_inverted = inverted
	_stroke_old_heights = terrain.data.heights.duplicate()
	_stroke_old_paint = terrain.data.paint.duplicate()
	var local: Vector3 = terrain.to_local(_cursor_hit)
	_stroke_target = local.y if dock.terrain_tool == JBDTerrain.Tool.FLATTEN else dock.target_height
	_stroke_region = Rect2i()
	if dock.terrain_tool == Dock.RAMP_TOOL:
		_ramp_start = local


func _process(delta: float) -> void:
	if not _stroking or dock.terrain_tool < 0 or dock.terrain_tool == Dock.RAMP_TOOL or _cursor_hit == null:
		return
	if terrain == null or not is_instance_valid(terrain):
		_stroking = false
		return
	var tool: int = dock.terrain_tool
	if _stroke_inverted:
		if tool == JBDTerrain.Tool.RAISE:
			tool = JBDTerrain.Tool.LOWER
		elif tool == JBDTerrain.Tool.LOWER:
			tool = JBDTerrain.Tool.RAISE
	var local: Vector3 = terrain.to_local(_cursor_hit)
	# Raise/lower run at up to 10 m/s; the blend tools take strength as 0..1.
	var strength := dock.brush_strength * (10.0 if tool <= JBDTerrain.Tool.LOWER else 1.0)
	var r := terrain.apply_brush(tool, Vector2(local.x, local.z), dock.brush_radius, strength, dock.brush_hardness, minf(delta, 0.05), _stroke_target, dock.paint_layer)
	_grow_region(r)
	terrain.rebuild_region(r)


func _end_stroke() -> void:
	_stroking = false
	if dock.terrain_tool == Dock.RAMP_TOOL and _ramp_start != null and _cursor_hit != null:
		var b: Vector3 = terrain.to_local(_cursor_hit)
		_grow_region(terrain.apply_ramp(_ramp_start, b, dock.brush_radius * 2.0, dock.brush_hardness))
	_ramp_start = null
	if _stroke_region.size == Vector2i.ZERO and _stroke_region.position == Vector2i.ZERO:
		return
	terrain.rebuild_region(_stroke_region, true)
	var ur := get_undo_redo()
	ur.create_action("Sculpt terrain", UndoRedo.MERGE_DISABLE, terrain)
	ur.add_do_method(terrain, "restore", terrain.data.heights.duplicate(), terrain.data.paint.duplicate())
	ur.add_undo_method(terrain, "restore", _stroke_old_heights, _stroke_old_paint)
	ur.commit_action(false)
	_save_terrain_data()


func _grow_region(r: Rect2i) -> void:
	if _stroke_region.size == Vector2i.ZERO and _stroke_region.position == Vector2i.ZERO:
		_stroke_region = r
	else:
		_stroke_region = _stroke_region.merge(r)


func _save_terrain_data() -> void:
	var d := terrain.data
	if d.resource_path != "" and not d.resource_path.contains("::"):
		ResourceSaver.save(d)


func _draw_cursor(camera: Camera3D) -> void:
	_cursor_mesh.clear_surfaces()
	if _cursor_hit == null:
		RenderingServer.instance_set_visible(_cursor_instance, false)
		return
	RenderingServer.instance_set_scenario(_cursor_instance, camera.get_world_3d().scenario)
	RenderingServer.instance_set_visible(_cursor_instance, true)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var c: Vector3 = _cursor_hit
	var col := Color(1.0, 0.85, 0.3)
	for ring: float in [dock.brush_radius, dock.brush_radius * dock.brush_hardness]:
		if ring < 0.05:
			continue
		var prev := Vector3.ZERO
		for i in 49:
			var a := i * TAU / 48.0
			var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * ring
			p.y = terrain.height_at(p) + 0.08 if terrain.contains(p) else c.y
			if i > 0:
				_cursor_mesh.surface_set_color(col)
				_cursor_mesh.surface_add_vertex(prev)
				_cursor_mesh.surface_set_color(col)
				_cursor_mesh.surface_add_vertex(p)
			prev = p
		col = col.darkened(0.4)
	if _ramp_start != null:
		_cursor_mesh.surface_set_color(Color(0.4, 0.9, 1.0))
		_cursor_mesh.surface_add_vertex(terrain.to_global(_ramp_start))
		_cursor_mesh.surface_set_color(Color(0.4, 0.9, 1.0))
		_cursor_mesh.surface_add_vertex(c)
	_cursor_mesh.surface_end()


# --- Placement --------------------------------------------------------------

func _place_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and not event.ctrl_pressed:
		_ghost_yaw += deg_to_rad(-dock.yaw_step if event.shift_pressed else dock.yaw_step)
		_update_ghost()
		return AFTER_GUI_INPUT_STOP
	if not event is InputEventMouse:
		return AFTER_GUI_INPUT_PASS
	_pick(camera, event.position)
	_update_ghost()
	if event is InputEventMouseMotion:
		if dock.scatter and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _place_valid:
			if _scatter_last == null or _place_pos.distance_to(_scatter_last) >= dock.scatter_spacing:
				_place()
			return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _place_valid:
			_place()
		elif not event.pressed:
			_scatter_last = null
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


## Find the surface under the mouse: physics first (blocks, terrain
## collision), then the terrain's own heights, then the ground plane.
func _pick(camera: Camera3D, screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var root := get_editor_interface().get_edited_scene_root()
	var best := INF
	_place_valid = false
	if root is Node3D:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0)
		var hit := (root as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			best = from.distance_to(hit.position)
			_place_pos = hit.position
			_place_normal = hit.normal
			_place_valid = true
	var t := terrain if terrain and is_instance_valid(terrain) and terrain.is_inside_tree() else _find_terrain()
	if t:
		var th = t.raycast(from, dir)
		if th != null and from.distance_to(th) < best:
			best = from.distance_to(th)
			_place_pos = th
			_place_normal = Vector3.UP
			_place_valid = true
	if not _place_valid and absf(dir.y) > 0.001:
		var k := -from.y / dir.y
		if k > 0.0:
			_place_pos = from + dir * k
			_place_normal = Vector3.UP
			_place_valid = true


func _placement_transform(node: Node3D = null) -> Transform3D:
	var pos := _place_pos
	var yaw := _ghost_yaw
	if Catalog.wall_mounted(dock.armed_item) and absf(_place_normal.y) < 0.7:
		yaw = atan2(-_place_normal.x, -_place_normal.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
		var root := get_editor_interface().get_edited_scene_root()
		if node and root is Node3D:
			xf = Catalog.fit_to_wall(node, xf, _place_normal, (root as Node3D).get_world_3d().direct_space_state)
		return xf
	elif dock.snap_enabled:
		pos = Catalog.snap(pos, dock.grid_step, dock.snap_y)
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _update_ghost() -> void:
	if dock.armed_item == "":
		_clear_ghost()
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root is Node3D:
		return
	if _ghost == null or _ghost_id != dock.armed_item:
		_clear_ghost()
		_ghost_id = dock.armed_item
		_ghost = Catalog.make(_ghost_id, _rng)
		# A sibling of the scene root: drawn in the level, never saved.
		root.get_parent().add_child(_ghost)
		_disable_collision(_ghost)
	_ghost.visible = _place_valid
	_ghost.global_transform = _placement_transform(_ghost)


func _disable_collision(n: Node) -> void:
	if n is CollisionObject3D:
		n.collision_layer = 0
		n.collision_mask = 0
	for c in n.get_children(true):
		_disable_collision(c)


func _clear_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_id = ""


func _place() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	var id := dock.armed_item
	var node := Catalog.make(id, _rng)
	var xf := _placement_transform(node)
	if dock.scatter:
		if dock.random_yaw:
			xf.basis = Basis(Vector3.UP, _rng.randf() * TAU)
		if dock.scale_jitter > 0.0 and node is JBDBlock:
			node.size *= 1.0 + _rng.randf_range(-dock.scale_jitter, dock.scale_jitter)
	_scatter_last = _place_pos

	var parent := root
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if id == "patrol_point":
		var enemy: Node = null
		for s in selected:
			var n: Node = s
			while n and not n is JBDEnemy:
				n = n.get_parent()
			if n:
				enemy = n
				break
		if enemy == null:
			dock.set_status("Select an enemy first, then place patrol points.")
			return
		parent = enemy
	var ur := get_undo_redo()
	ur.create_action("Place %s" % Catalog.label(id), UndoRedo.MERGE_DISABLE, root)
	var group_name := Catalog.container_for(id)
	if parent == root and group_name != "":
		var existing := root.get_node_or_null(group_name)
		if existing:
			parent = existing
		else:
			var g := Node3D.new()
			g.name = group_name
			ur.add_do_method(root, "add_child", g, true)
			ur.add_do_method(g, "set_owner", root)
			ur.add_do_reference(g)
			ur.add_undo_method(root, "remove_child", g)
			parent = g
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(self, "_own", node, root)
	ur.add_do_method(node, "set_global_transform", xf)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	if not dock.scatter:
		var sel := get_editor_interface().get_selection()
		if id != "patrol_point":
			sel.clear()
			sel.add_node(node)
	dock.set_status("Placed %s at %s" % [Catalog.label(id), xf.origin.snapped(Vector3.ONE * 0.01)])


func _own(node: Node, root: Node) -> void:
	Catalog.set_owner_recursive(node, root)


# --- Dock actions -----------------------------------------------------------

func _on_new_terrain(cells_x: int, cells_z: int, cell_size: float) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		dock.set_status("Save the level scene first, so the terrain data has somewhere to live.")
		return
	var t := new_terrain(root.scene_file_path, cells_x, cells_z, cell_size)
	var ur := get_undo_redo()
	ur.create_action("Add terrain", UndoRedo.MERGE_DISABLE, root)
	ur.add_do_method(root, "add_child", t, true)
	ur.add_do_method(t, "set_owner", root)
	ur.add_do_reference(t)
	ur.add_undo_method(root, "remove_child", t)
	ur.commit_action()
	_set_terrain(t)
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(t)
	dock.set_status("Terrain added, centred on the origin. Its heights save to %s" % t.data.resource_path)


## A flat terrain centred on the origin, with its data saved beside the scene.
static func new_terrain(scene_path: String, cells_x: int, cells_z: int, cell_size: float) -> JBDTerrain:
	var base := scene_path.get_basename() + "_terrain"
	var path := base + ".res"
	var i := 2
	while ResourceLoader.exists(path):
		path = "%s_%d.res" % [base, i]
		i += 1
	var data := JBDTerrainData.new()
	data.setup(cells_x, cells_z, cell_size)
	ResourceSaver.save(data, path)
	data = load(path)
	var t := JBDTerrain.new()
	t.name = "Terrain"
	t.data = data
	t.position = Vector3(-cells_x * cell_size * 0.5, 0, -cells_z * cell_size * 0.5)
	return t


func _on_new_level(level_name: String) -> void:
	level_name = level_name.strip_edges()
	if level_name == "":
		dock.set_status("Give the level a name first.")
		return
	var path := LEVEL_DIR + level_name.to_snake_case() + ".tscn"
	if ResourceLoader.exists(path):
		dock.set_status("%s already exists. Opening it." % path)
		get_editor_interface().open_scene_from_path(path)
		return
	var err := create_level(path, level_name)
	if err != OK:
		dock.set_status("Couldn't save %s (error %d)." % [path, err])
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().open_scene_from_path(path)
	dock.set_status("Created %s. Sculpt the terrain, place things, press Play." % path)


## Write a starter level: terrain, player start and a campfire.
static func create_level(path: String, level_name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var root := JBDLevel.new()
	root.name = level_name.to_pascal_case()
	root.level_name = level_name
	var t := new_terrain(path, 96, 96, 1.0)
	root.add_child(t)
	t.owner = root
	var start := JBDPlayerStart.new()
	start.name = "PlayerStart"
	start.position = Vector3(0, 0, 8)
	root.add_child(start)
	start.owner = root
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	gameplay.owner = root
	var fire := JBDCampfire.new()
	fire.name = "Campfire"
	fire.fire_name = "%s Fire" % level_name
	fire.position = Vector3(-3, 0, 6)
	gameplay.add_child(fire)
	fire.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ResourceSaver.save(ps, path)


func _on_play(from_camera: bool) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path == "":
		dock.set_status("Open (and save) a level scene first.")
		return
	get_editor_interface().save_scene()
	var cfg := {"level": root.scene_file_path, "hour": dock.play_hour}
	if from_camera:
		var cam := get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
		var p := cam.global_position
		cfg.start = [p.x, p.y, p.z]
		cfg.yaw = cam.global_rotation.y
	var f := FileAccess.open(PLAYTEST_SETTINGS, FileAccess.WRITE)
	f.store_string(JSON.stringify(cfg))
	f.close()
	get_editor_interface().play_custom_scene(PLAYTEST_SCENE)


func _on_save_prefab(prefab_name: String) -> void:
	prefab_name = prefab_name.strip_edges()
	var nodes: Array[Node3D] = []
	for n in get_editor_interface().get_selection().get_top_selected_nodes():
		if n is Node3D and n != get_editor_interface().get_edited_scene_root():
			nodes.append(n)
	if prefab_name == "" or nodes.is_empty():
		dock.set_status("Select the pieces in the scene and give the prefab a name.")
		return
	var path := Catalog.PREFAB_DIR + prefab_name.to_snake_case() + ".tscn"
	var err := save_prefab(nodes, prefab_name, path)
	if err != OK:
		dock.set_status("Couldn't save %s (error %d)." % [path, err])
		return
	get_editor_interface().get_resource_filesystem().scan()
	dock.refresh_prefabs()
	dock.set_status("Saved %s. It's on the Place tab under Prefabs." % path)


## Pack copies of `nodes` (all from one saved scene) into a prefab scene.
## The prefab's origin is the middle of the pieces at floor level, so it
## drops neatly onto the ground.
static func save_prefab(nodes: Array[Node3D], prefab_name: String, path: String) -> Error:
	var scene_root := nodes[0].owner if nodes[0].owner else nodes[0]
	var center := Vector3.ZERO
	var floor_y := INF
	for n in nodes:
		center += n.global_position
		floor_y = minf(floor_y, n.global_position.y)
	center = (center / nodes.size()).snapped(Vector3(0.5, 0, 0.5))
	center.y = floor_y
	# Copy through a packed snapshot of the scene, so only the saved nodes
	# come along (not the meshes the tool scripts generate on the fly).
	var snapshot := PackedScene.new()
	snapshot.pack(scene_root)
	var copy_root: Node = snapshot.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var root := Node3D.new()
	root.name = prefab_name.to_pascal_case()
	for n in nodes:
		var copy: Node3D = copy_root.get_node_or_null(scene_root.get_path_to(n)) if n != scene_root else null
		if copy == null:
			continue
		Catalog.set_owner_recursive(copy, null)
		copy.get_parent().remove_child(copy)
		root.add_child(copy, true)
		copy.transform = Transform3D(n.global_basis, n.global_position - center)
		Catalog.set_owner_recursive(copy, root)
	copy_root.free()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var ps := PackedScene.new()
	var err := ps.pack(root)
	root.free()
	if err != OK:
		return err
	return ResourceSaver.save(ps, path)


func _on_make_main_level() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path == "" or root.scene_file_path == "res://scenes/main.tscn":
		dock.set_status("Open the level you want the game to start in first.")
		return
	get_editor_interface().save_scene()
	var main: Node = load("res://scenes/main.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	main.level_scene = load(root.scene_file_path)
	var ps := PackedScene.new()
	ps.pack(main)
	main.free()
	ResourceSaver.save(ps, "res://scenes/main.tscn")
	dock.set_status("F5 now starts in %s. Clear Level Scene on scenes/main.tscn to go back to the greybox." % root.scene_file_path)
