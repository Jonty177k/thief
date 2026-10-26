extends CanvasLayer
## F3 / Options: live readout of the controller for tuning. On by default in
## the controller test level (JBDLevel.show_debug_overlay).

var player: JBDPlayer
var label: Label


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -170
	panel.offset_right = -6
	panel.offset_top = 22
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	label.text = text()


func text() -> String:
	var p := player
	var h := Vector2(p.velocity.x, p.velocity.z)
	var mv := p.movement
	var sw := p.sword
	var d := p.dash
	var attack := "-"
	if sw.attacking():
		attack = "%s %s%s" % [sw.kind, sw.phase_name().to_lower(), " #%d" % (sw.chain_index + 1) if sw.kind == "light" else ""]
	var dash := "ready"
	if d.active:
		dash = "dashing %.2fs" % d.time
	elif d.recovery_timer > 0.0:
		dash = "recovering %.2fs" % d.recovery_timer
	elif not p.can_dash():
		dash = "blocked by state"
	var t = p.interaction.target
	var target: String = t.get_prompt() if is_instance_valid(t) else "-"
	var lines := [
		"STATE     %s" % p.state_name(),
		"grounded  %s   ground %.2f m" % ["yes" if p.is_on_floor() else "no", p.ground_distance()],
		"speed     %.2f m/s  (target %.2f)" % [h.length(), mv.target_speed],
		"h-vel     x %+.2f  z %+.2f" % [h.x, h.y],
		"v-vel     %+.2f" % p.velocity.y,
		"stick     %.2f  %s" % [p.input.move.length(), "RUN" if mv.running else ""],
		"crouch    %s  height %.2f%s" % ["on" if mv.crouching else "off", mv.current_height, "  (ceiling)" if mv.stand_blocked else ""],
		"attack    %s" % attack,
		"block     %s" % ("UP" if p.shield.raised else "down"),
		"dash      %s" % dash,
		"use       %s" % target,
		"hp        %.0f / %.0f" % [p.hp, p.max_hp],
		"input     %s   fps %d" % ["gamepad" if p.input.using_gamepad else "keyboard/mouse", Engine.get_frames_per_second()],
		"pad       %s" % Gamepad.describe(),
	]
	return "\n".join(lines)
