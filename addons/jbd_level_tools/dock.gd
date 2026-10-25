@tool
extends VBoxContainer
## The Level Tools dock. Pure UI: it holds the current settings and emits
## signals; plugin.gd does the work.

signal new_terrain_requested(cells_x: int, cells_z: int, cell_size: float)
signal new_level_requested(level_name: String)
signal play_requested(from_camera: bool)
signal save_prefab_requested(prefab_name: String)
signal make_main_level_requested
signal mode_changed

const Catalog := preload("res://addons/jbd_level_tools/catalog.gd")
const RAMP_TOOL := 100
const TOOLS := [
	["Raise", JBDTerrain.Tool.RAISE, "Drag to raise the ground. Hold Shift to lower."],
	["Lower", JBDTerrain.Tool.LOWER, "Drag to dig. Hold Shift to raise."],
	["Smooth", JBDTerrain.Tool.SMOOTH, "Soften bumps and sharp edges."],
	["Flatten", JBDTerrain.Tool.FLATTEN, "Level the ground to the height where the stroke started."],
	["Cliff", JBDTerrain.Tool.SET_HEIGHT, "Snap the ground to the Height value. Hardness 1 makes sheer cliffs. Ctrl+click picks a height."],
	["Ramp", RAMP_TOOL, "Drag from the bottom to the top of a slope to carve a straight ramp."],
	["Paint", JBDTerrain.Tool.PAINT, "Paint the chosen texture layer."],
]
const HOURS := [["Keep level's hour", -1.0], ["Dawn 6:30", 6.5], ["Noon", 12.0], ["Dusk 19:30", 19.5], ["Midnight", 0.0]]

## -1 = no terrain tool.
var terrain_tool := -1
var brush_radius := 4.0
var brush_strength := 0.5
var brush_hardness := 0.3
var target_height := 0.0
var paint_layer := 0

## The palette entry ready to place ("" = none).
var armed_item := ""
var snap_enabled := true
var grid_step := 1.0
var snap_y := false
var yaw_step := 45.0
var scatter := false
var scatter_spacing := 3.0
var random_yaw := false
var scale_jitter := 0.0

var play_hour := -1.0

var _terrain_label: Label
var _tool_group := ButtonGroup.new()
var _place_group := ButtonGroup.new()
var _layer_option: OptionButton
var _height_spin: SpinBox
var _radius_slider: HSlider
var _prefab_box: VBoxContainer
var _status: Label


func _init() -> void:
	name = "Level Tools"
	custom_minimum_size = Vector2(240, 0)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	tabs.add_child(_terrain_tab())
	tabs.add_child(_place_tab())
	tabs.add_child(_level_tab())
	tabs.tab_changed.connect(func(_i: int) -> void: disarm())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1, 1, 1, 0.7)
	add_child(_status)
	_place_group.allow_unpress = true
	_tool_group.allow_unpress = true


func set_status(text: String) -> void:
	_status.text = text


## Drop whatever tool or palette piece is active.
func disarm() -> void:
	for b in _tool_group.get_buttons():
		b.set_pressed_no_signal(false)
	for b in _place_group.get_buttons():
		b.set_pressed_no_signal(false)
	terrain_tool = -1
	armed_item = ""
	mode_changed.emit()


func set_terrain(terrain: JBDTerrain) -> void:
	if terrain == null:
		_terrain_label.text = "No terrain selected. Select one, or add one below."
		return
	_terrain_label.text = "Editing: %s" % terrain.name
	var keep := _layer_option.selected
	_layer_option.clear()
	for i in 4:
		_layer_option.add_item("%d  %s" % [i + 1, terrain.layer_names[i] if i < terrain.layer_names.size() else "Layer %d" % (i + 1)])
	_layer_option.select(clampi(keep, 0, 3))


func set_target_height(h: float) -> void:
	_height_spin.value = h


func resize_brush(factor: float) -> void:
	_radius_slider.value = clampf(brush_radius * factor, _radius_slider.min_value, _radius_slider.max_value)


# --- Tabs ----------------------------------------------------------------

func _terrain_tab() -> Control:
	var box := _tab("Terrain")
	_terrain_label = Label.new()
	_terrain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_terrain_label)
	set_terrain(null)

	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for t in TOOLS:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = t[2]
		b.toggle_mode = true
		b.button_group = _tool_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tool_id: int = t[1]
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_untoggle(_place_group)
				armed_item = ""
			terrain_tool = tool_id if on else (-1 if terrain_tool == tool_id else terrain_tool)
			mode_changed.emit())
		grid.add_child(b)

	_radius_slider = _slider(box, "Size (m)", 0.5, 40.0, brush_radius, func(v): brush_radius = v)
	_slider(box, "Strength", 0.02, 1.0, brush_strength, func(v): brush_strength = v)
	_slider(box, "Hardness", 0.0, 1.0, brush_hardness, func(v): brush_hardness = v)
	_height_spin = _spin(box, "Cliff height (m)", -200.0, 400.0, 0.25, target_height, func(v): target_height = v)

	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Paint layer"
	row.add_child(l)
	_layer_option = OptionButton.new()
	_layer_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_option.item_selected.connect(func(i: int) -> void: paint_layer = i)
	row.add_child(_layer_option)
	box.add_child(row)
	for i in 4:
		_layer_option.add_item("Layer %d" % (i + 1))

	_hint(box, "Left-drag in the viewport to sculpt. [ and ] resize the brush. Ctrl+Z undoes a stroke. Right-click or Esc puts the tool down.")

	box.add_child(HSeparator.new())
	var head := Label.new()
	head.text = "New terrain"
	box.add_child(head)
	var cx := _spin(box, "Width (cells)", 8, 1024, 8, 128, func(_v): pass)
	var cz := _spin(box, "Length (cells)", 8, 1024, 8, 128, func(_v): pass)
	var cs := _spin(box, "Cell size (m)", 0.25, 8.0, 0.25, 1.0, func(_v): pass)
	var add := Button.new()
	add.text = "Add terrain to this level"
	add.pressed.connect(func() -> void: new_terrain_requested.emit(int(cx.value), int(cz.value), cs.value))
	box.add_child(add)
	return _scroll(box)


func _place_tab() -> Control:
	var box := _tab("Place")
	_hint(box, "Pick a piece, then click in the viewport. R turns it, right-click or Esc stops placing.")
	for cat in Catalog.categories():
		_palette_section(box, cat, Catalog.items_in(cat))
	_prefab_box = VBoxContainer.new()
	box.add_child(_prefab_box)
	refresh_prefabs()

	box.add_child(HSeparator.new())
	var snap := CheckBox.new()
	snap.text = "Snap to grid"
	snap.button_pressed = snap_enabled
	snap.toggled.connect(func(on: bool) -> void: snap_enabled = on)
	box.add_child(snap)
	var steps := OptionButton.new()
	for s in [0.25, 0.5, 1.0, 2.0, 4.0]:
		steps.add_item("Grid %s m" % s)
		steps.set_item_metadata(steps.item_count - 1, s)
	steps.select(2)
	steps.item_selected.connect(func(i: int) -> void: grid_step = steps.get_item_metadata(i))
	box.add_child(steps)
	var sy := CheckBox.new()
	sy.text = "Snap height too"
	sy.toggled.connect(func(on: bool) -> void: snap_y = on)
	box.add_child(sy)
	_spin(box, "Turn step (deg)", 1, 180, 1, yaw_step, func(v): yaw_step = v)

	box.add_child(HSeparator.new())
	var sc := CheckBox.new()
	sc.text = "Scatter (drag to paint copies)"
	sc.tooltip_text = "Great for rocks and bone spurs."
	sc.toggled.connect(func(on: bool) -> void: scatter = on)
	box.add_child(sc)
	_spin(box, "Spacing (m)", 0.5, 50.0, 0.5, scatter_spacing, func(v): scatter_spacing = v)
	var ry := CheckBox.new()
	ry.text = "Random turn"
	ry.toggled.connect(func(on: bool) -> void: random_yaw = on)
	box.add_child(ry)
	_slider(box, "Random size ±", 0.0, 0.6, scale_jitter, func(v): scale_jitter = v)
	return _scroll(box)


func _level_tab() -> Control:
	var box := _tab("Level")
	var head := Label.new()
	head.text = "Play-test"
	box.add_child(head)
	var hour := OptionButton.new()
	for h in HOURS:
		hour.add_item(h[0])
	hour.item_selected.connect(func(i: int) -> void: play_hour = HOURS[i][1])
	box.add_child(hour)
	var p1 := Button.new()
	p1.text = "▶  Play from Player Start"
	p1.pressed.connect(func() -> void: play_requested.emit(false))
	box.add_child(p1)
	var p2 := Button.new()
	p2.text = "▶  Play from editor camera"
	p2.tooltip_text = "Jeffrey drops onto whatever is under the camera."
	p2.pressed.connect(func() -> void: play_requested.emit(true))
	box.add_child(p2)
	var mm := Button.new()
	mm.text = "Make this the game's level (F5)"
	mm.tooltip_text = "Sets Main's Level Scene to the open scene. Clear it in scenes/main.tscn to go back to the greybox."
	mm.pressed.connect(func() -> void: make_main_level_requested.emit())
	box.add_child(mm)

	box.add_child(HSeparator.new())
	var h2 := Label.new()
	h2.text = "Prefabs"
	box.add_child(h2)
	_hint(box, "Select some pieces (a hut, a camp…) and save them as one reusable prefab. It appears on the Place tab.")
	var pname := LineEdit.new()
	pname.placeholder_text = "Prefab name, e.g. Bandit camp"
	box.add_child(pname)
	var sp := Button.new()
	sp.text = "Save selection as prefab"
	sp.pressed.connect(func() -> void: save_prefab_requested.emit(pname.text))
	box.add_child(sp)

	box.add_child(HSeparator.new())
	var h3 := Label.new()
	h3.text = "New level"
	box.add_child(h3)
	var lname := LineEdit.new()
	lname.placeholder_text = "Level name, e.g. The Prison"
	box.add_child(lname)
	var nl := Button.new()
	nl.text = "Create level"
	nl.tooltip_text = "Makes levels/<name>.tscn with terrain, a player start and a campfire, and opens it."
	nl.pressed.connect(func() -> void: new_level_requested.emit(lname.text))
	box.add_child(nl)
	return _scroll(box)


func refresh_prefabs() -> void:
	for c in _prefab_box.get_children():
		c.queue_free()
	var paths := Catalog.prefab_paths()
	if not paths.is_empty():
		_palette_section(_prefab_box, "Prefabs", Array(paths))


# --- Widgets -------------------------------------------------------------

func _palette_section(parent: Control, title: String, ids: Array) -> void:
	var head := Label.new()
	head.text = title
	parent.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	for id in ids:
		var b := Button.new()
		b.text = Catalog.label(id)
		b.tooltip_text = Catalog.ITEMS[id][2] if Catalog.ITEMS.has(id) else id
		b.toggle_mode = true
		b.button_group = _place_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_untoggle(_tool_group)
				terrain_tool = -1
				armed_item = id
			elif armed_item == id:
				armed_item = ""
			mode_changed.emit())
		grid.add_child(b)


func _untoggle(group: ButtonGroup) -> void:
	for b in group.get_buttons():
		b.set_pressed_no_signal(false)


func _tab(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


func _scroll(box: VBoxContainer) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = box.name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(box)
	return sc


func _hint(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	l.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(l)


func _slider(parent: Control, text: String, lo: float, hi: float, value: float, on_change: Callable) -> HSlider:
	var l := Label.new()
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.value = value
	var update := func(v: float) -> void:
		l.text = "%s: %.2f" % [text, v]
		on_change.call(v)
	s.value_changed.connect(update)
	update.call(value)
	parent.add_child(s)
	return s


func _spin(parent: Control, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(func(v: float) -> void: on_change.call(v))
	row.add_child(s)
	parent.add_child(row)
	return s
