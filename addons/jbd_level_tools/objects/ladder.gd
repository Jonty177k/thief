@tool
class_name JBDLadder
extends StaticBody3D
## A climbable ladder. Walk into it to climb: forward climbs toward where
## you look, back goes the other way, Jump lets go. At the top you step off
## onto the ledge behind it; from a ledge, walk off over the ladder to climb
## down. The origin is the bottom centre and the climbing side faces -Z,
## so the wall goes on its +Z side (the blue arrow points into the wall).
## Click a wall or cliff to place it: it stands on the ground below and
## reaches the top of the wall.

const WOOD := preload("res://addons/jbd_level_tools/materials/wood.tres")

@export var height := 4.0:
	set(v):
		height = maxf(v, 0.5)
		_queue_rebuild()
@export var width := 0.6:
	set(v):
		width = maxf(v, 0.3)
		_queue_rebuild()
@export var rung_spacing := 0.3:
	set(v):
		rung_spacing = maxf(v, 0.1)
		_queue_rebuild()
@export var material: Material = WOOD:
	set(v):
		material = v
		_queue_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _zone: Area3D
var _zone_shape: CollisionShape3D
var _pending := false


func _ready() -> void:
	add_to_group("ladder")
	rebuild()
	if Engine.is_editor_hint():
		return
	_zone.body_entered.connect(func(b: Node3D) -> void:
		if b.get("movement") != null:
			b.movement.ladder_entered(self))
	_zone.body_exited.connect(func(b: Node3D) -> void:
		if b.get("movement") != null:
			b.movement.ladder_exited(self))


func _queue_rebuild() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance, false, INTERNAL_MODE_BACK)
		_collision = CollisionShape3D.new()
		add_child(_collision, false, INTERNAL_MODE_BACK)
		_zone = Area3D.new()
		_zone.collision_layer = 0
		_zone.collision_mask = 2
		add_child(_zone, false, INTERNAL_MODE_BACK)
		_zone_shape = CollisionShape3D.new()
		_zone.add_child(_zone_shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(side * width * 0.5, height * 0.5 + 0.1, 0), Vector3(0.07, height + 0.2, 0.07))
	var y := 0.25
	while y < height:
		_box(st, Vector3(0, y, 0), Vector3(width, 0.045, 0.05))
		y += rung_spacing
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = material
	var slab := BoxShape3D.new()
	slab.size = Vector3(width + 0.07, height, 0.08)
	_collision.shape = slab
	_collision.position = Vector3(0, height * 0.5, 0)
	# Where Jeffrey can grab on: in front of the ladder, and a bit above
	# its top so he can climb over onto the ledge.
	var zone := BoxShape3D.new()
	zone.size = Vector3(width + 0.4, height + 1.0, 0.9)
	_zone_shape.shape = zone
	_zone_shape.position = Vector3(0, (height + 1.0) * 0.5, -0.04 - 0.45)


func _box(st: SurfaceTool, center: Vector3, box_size: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = box_size
	st.append_from(bm, 0, Transform3D(Basis.IDENTITY, center))


## Horizontal direction from the ladder toward the climber.
func out_direction() -> Vector3:
	var d := -global_basis.z
	d.y = 0.0
	return d.normalized()


func top_height() -> float:
	return global_position.y + height
