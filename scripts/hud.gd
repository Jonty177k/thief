extends CanvasLayer
## Health, stamina, the light gem, the clock, prompts and the rest menu.
## Everything is built in code so the scene file stays tiny.

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var gem: Panel
var gem_style: StyleBoxFlat
var clock: Label
var crosshair: Label
var prompt: Label
var message: Label
var rest_menu: PanelContainer
var rest_title: Label
var help: Label
var fade: ColorRect
var flash: ColorRect
var message_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	health_bar = _bar(Color(0.65, 0.12, 0.1), Vector2(8, 8), Vector2(120, 6))
	stamina_bar = _bar(Color(0.25, 0.55, 0.2), Vector2(8, 17), Vector2(100, 5))
	root.add_child(health_bar)
	root.add_child(stamina_bar)

	# The light gem, Thief-style: bright means seen.
	gem_style = StyleBoxFlat.new()
	gem_style.bg_color = Color(0.2, 0.2, 0.2)
	gem_style.set_corner_radius_all(8)
	gem_style.border_color = Color(0.45, 0.38, 0.25)
	gem_style.set_border_width_all(2)
	gem = Panel.new()
	gem.add_theme_stylebox_override("panel", gem_style)
	gem.size = Vector2(36, 14)
	gem.anchor_left = 0.5
	gem.anchor_right = 0.5
	gem.anchor_top = 1.0
	gem.anchor_bottom = 1.0
	gem.offset_left = -18
	gem.offset_right = 18
	gem.offset_top = -22
	gem.offset_bottom = -8
	root.add_child(gem)

	clock = _label(12, HORIZONTAL_ALIGNMENT_RIGHT)
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -200
	clock.offset_right = -8
	clock.offset_top = 6
	root.add_child(clock)

	crosshair = _label(12, HORIZONTAL_ALIGNMENT_CENTER)
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10
	crosshair.offset_right = 10
	crosshair.offset_top = -9
	crosshair.offset_bottom = 9
	root.add_child(crosshair)

	prompt = _label(12, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.anchor_left = 0.0
	prompt.anchor_right = 1.0
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_top = -52
	prompt.offset_bottom = -30
	root.add_child(prompt)

	message = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	message.anchor_left = 0.0
	message.anchor_right = 1.0
	message.anchor_top = 0.3
	message.anchor_bottom = 0.3
	message.offset_bottom = 60
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.modulate.a = 0.0
	root.add_child(message)

	help = _label(10, HORIZONTAL_ALIGNMENT_LEFT)
	help.position = Vector2(8, 30)
	help.text = "WASD move   Shift sprint   Ctrl/C crouch   Space jump\n" \
		+ "LMB sword   RMB shield   G / MMB grapple (wood only)   Q/E lean\n" \
		+ "F rest at campfire   Esc free mouse   H hide this"
	help.modulate = Color(1, 1, 1, 0.8)
	root.add_child(help)

	_build_rest_menu(root)

	flash = ColorRect.new()
	flash.color = Color(0.7, 0.05, 0.02, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func _bar(c: Color, pos: Vector2, sz: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.max_value = 100
	b.value = 100
	return b


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_rest_menu(root: Control) -> void:
	rest_menu = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.85)
	style.border_color = Color(0.7, 0.5, 0.25)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	rest_menu.add_theme_stylebox_override("panel", style)
	rest_menu.set_anchors_preset(Control.PRESET_CENTER)
	rest_menu.offset_left = -110
	rest_menu.offset_right = 110
	rest_menu.offset_top = -50
	rest_menu.offset_bottom = 50
	var box := VBoxContainer.new()
	rest_menu.add_child(box)
	rest_title = _label(14, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(rest_title)
	var opts := _label(11, HORIZONTAL_ALIGNMENT_LEFT)
	opts.text = "[1]  Rest until morning\n[2]  Rest until evening\n[F]  Get up"
	box.add_child(opts)
	rest_menu.visible = false
	root.add_child(rest_menu)


func set_health(hp: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp


func set_stamina(st: float, max_st: float) -> void:
	stamina_bar.max_value = max_st
	stamina_bar.value = st


func set_visibility(v: float) -> void:
	gem_style.bg_color = Color(0.08, 0.08, 0.07).lerp(Color(1.0, 0.95, 0.75), v)


func set_clock(text: String) -> void:
	clock.text = text


func set_grapple_aim(valid: bool) -> void:
	crosshair.text = "o" if valid else "+"
	crosshair.modulate = Color(0.95, 0.75, 0.35) if valid else Color(1, 1, 1, 0.6)


func set_prompt(text: String) -> void:
	prompt.text = text


func show_message(text: String, hold := 2.5, color := Color(0.95, 0.88, 0.7)) -> void:
	message.text = text
	message.add_theme_color_override("font_color", color)
	if message_tween:
		message_tween.kill()
	message.modulate.a = 0.0
	message_tween = create_tween()
	message_tween.tween_property(message, "modulate:a", 1.0, 0.4)
	message_tween.tween_interval(hold)
	message_tween.tween_property(message, "modulate:a", 0.0, 0.8)


func open_rest_menu(fire_name: String) -> void:
	rest_title.text = fire_name
	rest_menu.visible = true


func close_rest_menu() -> void:
	rest_menu.visible = false


func toggle_help() -> void:
	help.visible = not help.visible


func flash_damage() -> void:
	flash.color.a = 0.45
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


## Fade to/from black. Await the returned tween's `finished`.
func fade_to(alpha: float, duration: float) -> Tween:
	var t := create_tween()
	t.tween_property(fade, "color:a", alpha, duration)
	return t
