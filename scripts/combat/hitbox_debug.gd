class_name HitboxDebug
extends MeshInstance3D
## Draws live melee hitboxes as lines: Jeffrey's swept blade (white) and
## enemy blades (red). Each sweep lingers for a moment so a swing's whole
## arc stays readable. Only while the debug panel is showing.

## Seconds a sweep stays on screen.
@export var linger := 0.4

var player: JBDPlayer
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
## [from, to, colour, age]
var _lines: Array = []


func _ready() -> void:
	mesh = _mesh
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	material_override = _mat


func _physics_process(delta: float) -> void:
	for l in _lines:
		l[3] += delta
	_lines = _lines.filter(func(l): return l[3] < linger)
	if not is_visible_in_tree() or player == null:
		return
	for s in player.sword.debug_sweeps:
		_lines.append([s[0], s[1], Color(1, 1, 1), 0.0])
	for e in get_tree().get_nodes_in_group("combat_enemy"):
		for s in e.debug_sweeps:
			_lines.append([s[0], s[1], Color(1, 0.2, 0.15), 0.0])


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if _lines.is_empty() or not is_visible_in_tree():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for l in _lines:
		_mesh.surface_set_color(l[2])
		_mesh.surface_add_vertex(l[0])
		_mesh.surface_add_vertex(l[1])
	_mesh.surface_end()
