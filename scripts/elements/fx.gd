class_name Fx
extends RefCounted
## Small one-shot placeholder effects (steam, splash, sparks, embers),
## built from CPUParticles3D so there are no assets to manage. Each frees
## itself when done. Restrained on purpose: this is a dark game.


## A puff of grey steam: a flame put out.
static func steam(ctx: Node, pos: Vector3) -> void:
	_burst(ctx, pos, 14, 0.9, Color(0.75, 0.75, 0.75, 0.5), Vector3.UP, 25.0, 0.6, 1.4, 0.12, -0.6)


## A small splash of water droplets.
static func splash(ctx: Node, pos: Vector3, normal := Vector3.UP) -> void:
	_burst(ctx, pos, 16, 0.5, Color(0.45, 0.6, 0.75, 0.8), normal, 70.0, 1.5, 3.0, 0.04, 9.8)


## Sparks off metal or stone: a hook that didn't bite.
static func sparks(ctx: Node, pos: Vector3, normal := Vector3.UP) -> void:
	_burst(ctx, pos, 10, 0.3, Color(1.0, 0.8, 0.4), normal, 60.0, 2.0, 4.0, 0.025, 9.8, true)


## A burst of embers: something catching fire.
static func embers(ctx: Node, pos: Vector3) -> void:
	_burst(ctx, pos, 12, 0.8, Color(1.0, 0.5, 0.15), Vector3.UP, 40.0, 0.8, 2.0, 0.03, -1.0, true)


static func _burst(ctx: Node, pos: Vector3, amount: int, life: float, color: Color, dir: Vector3, spread: float,
		v_min: float, v_max: float, size: float, gravity: float, glow := false) -> void:
	if ctx == null or not ctx.is_inside_tree() or Engine.is_editor_hint():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.direction = dir if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0, -gravity, 0)
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	m.material = mat
	p.mesh = m
	var root: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene else ctx.get_tree().root
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
