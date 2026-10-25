@tool
class_name JBDEnemy
extends Node3D
## An enemy post. Pick a kind, tweak its stats, and give it patrol points:
## add Marker3D children (the dock's Patrol Point tool does this when the
## enemy is selected). It walks them in order and loops. With no patrol
## points it stands guard here.
##
## Changing Kind in the Inspector resets the stats to that kind's defaults.

const Enemy := preload("res://scripts/enemy.gd")

@export_enum("warden", "hollow") var kind := "warden":
	set(v):
		kind = v
		if Engine.is_editor_hint() and is_inside_tree():
			load_defaults()
		_dirty = true

@export_group("Stats")
@export var health := 260.0
@export var damage := 38.0
@export var patrol_speed := 1.8
@export var chase_speed := 4.7
## How far it can see you in full light, in metres.
@export var detection_range := 26.0
## Field of view, in degrees.
@export_range(10.0, 360.0) var field_of_view := 100.0
## 1 = normal. Multiplies how far away it hears you.
@export_range(0.0, 4.0, 0.05) var hearing := 1.0
## Seconds between the eyes flaring and the blow landing.
@export var attack_windup := 0.65
@export var attack_cooldown := 1.6
## Only walks at night (and vanishes by day), like the Hollows.
@export var night_only := false

var enemy: CharacterBody3D
var _dirty := true
var _path: MeshInstance3D
var _body: MeshInstance3D
var _redraw_timer := 0.0


func load_defaults() -> void:
	var k: Dictionary = Enemy.KINDS[kind]
	health = k.hp
	damage = k.damage
	patrol_speed = k.patrol_speed
	chase_speed = k.chase_speed
	detection_range = k.view
	field_of_view = k.fov
	hearing = k.hearing
	attack_windup = k.windup
	attack_cooldown = k.cooldown
	night_only = k.night_only
	notify_property_list_changed()


func patrol_points() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for c in get_children():
		if c is Marker3D:
			pts.append(c.global_position)
	return pts


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		return
	var wps := patrol_points()
	if wps.is_empty():
		wps = [global_position]
	enemy = Enemy.new()
	enemy.setup(kind, wps)
	enemy.overrides = {
		"hp": health, "damage": damage, "patrol_speed": patrol_speed, "chase_speed": chase_speed,
		"view": detection_range, "fov": field_of_view, "hearing": hearing,
		"windup": attack_windup, "cooldown": attack_cooldown, "night_only": night_only,
	}
	enemy.top_level = true
	enemy.position = global_position
	enemy.rotation.y = global_rotation.y
	add_child(enemy)


# --- Editor preview: a ghost of the enemy and its patrol route ---------------

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0 or _dirty:
		_redraw_timer = 0.25
		_dirty = false
		_draw_preview()


func _draw_preview() -> void:
	if _body == null:
		_body = MeshInstance3D.new()
		add_child(_body, false, INTERNAL_MODE_BACK)
		_path = MeshInstance3D.new()
		_path.top_level = true
		add_child(_path, false, INTERNAL_MODE_BACK)
	var k: Dictionary = Enemy.KINDS[kind]
	var h: float = k.height
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, h, 0.6)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = k.color
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_body.mesh = bm
	_body.material_override = bmat
	_body.position.y = h * 0.5

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var lift := Vector3.UP * 0.15
	var pts := patrol_points()
	var route_col := Color(1.0, 0.25, 0.2) if night_only else Color(1.0, 0.8, 0.2)
	if not pts.is_empty():
		_line(im, global_position + lift, pts[0] + lift, route_col.darkened(0.5))
		for i in pts.size():
			_line(im, pts[i] + lift, pts[(i + 1) % pts.size()] + lift, route_col)
			_line(im, pts[i], pts[i] + Vector3.UP * 1.5, route_col)
	# The view cone, flat on the ground.
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var half := deg_to_rad(field_of_view * 0.5)
	var eye := global_position + lift
	var cone := Color(0.4, 0.8, 1.0, 0.8)
	var prev := eye
	for i in 13:
		var a := lerpf(-half, half, i / 12.0)
		var p := eye + fwd.rotated(Vector3.UP, a) * detection_range
		_line(im, prev, p, cone)
		prev = p
	_line(im, prev, eye, cone)
	im.surface_end()
	_path.mesh = im
	_path.global_transform = Transform3D.IDENTITY


func _line(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_add_vertex(a)
	im.surface_set_color(c)
	im.surface_add_vertex(b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_dirty = true
