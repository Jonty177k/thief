@tool
class_name JBDBlock
extends StaticBody3D
## A modular building piece: floors, walls, stairs, ramps, arches, pillars,
## doorways, windows, roofs and rocks. Change Shape and Size in the
## Inspector instead of scaling the node; the mesh and collision rebuild
## themselves. The origin sits at the bottom centre, so pieces drop
## neatly onto floors and the grid. Ramps and stairs climb toward -Z
## (the blue gizmo arrow points down the slope).

enum Shape { BOX, RAMP, STAIRS, PILLAR, ARCH, DOORWAY, WINDOW, ROOF, ROCK }

const WOOD := preload("res://addons/jbd_level_tools/materials/wood.tres")
const RUIN := preload("res://addons/jbd_level_tools/materials/ruin.tres")

@export var shape := Shape.BOX:
	set(v):
		shape = v
		_queue_rebuild()
@export var size := Vector3(4, 0.5, 4):
	set(v):
		size = v.max(Vector3(0.05, 0.05, 0.05))
		_queue_rebuild()
@export var material: Material = RUIN:
	set(v):
		material = v
		_queue_rebuild()
## The grappling hook only bites things marked as anchors (usually wood).
@export var grapple_anchor := false:
	set(v):
		grapple_anchor = v
		_update_group()

@export_group("Openings")
## Arch, doorway and window hole: width and height in metres.
@export var opening := Vector2(1.6, 2.6):
	set(v):
		opening = v
		_queue_rebuild()
## Window only: height of the sill above the floor.
@export var sill := 1.0:
	set(v):
		sill = v
		_queue_rebuild()

@export_group("Stairs")
@export_range(2, 64) var steps := 8:
	set(v):
		steps = v
		_queue_rebuild()
## Collide like a smooth ramp, so walking up never snags on a step.
@export var smooth_collision := true:
	set(v):
		smooth_collision = v
		_queue_rebuild()

@export_group("Rock")
@export var rock_seed := 1:
	set(v):
		rock_seed = v
		_queue_rebuild()
@export_range(0.0, 0.6) var roughness := 0.3:
	set(v):
		roughness = v
		_queue_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _pending := false


func _ready() -> void:
	_update_group()
	rebuild()


func _update_group() -> void:
	if grapple_anchor:
		add_to_group("grapple")
	elif is_in_group("grapple"):
		remove_from_group("grapple")


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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_arrays := []
	var h := size.y
	match shape:
		Shape.BOX:
			_box(st, Vector3(0, h * 0.5, 0), size)
		Shape.RAMP:
			_ramp(st)
		Shape.STAIRS:
			var d := size.z / steps
			for i in steps:
				var top := h * (i + 1) / steps
				_box(st, Vector3(0, top * 0.5, size.z * 0.5 - (i + 0.5) * d), Vector3(size.x, top, d))
			if smooth_collision:
				var rs := SurfaceTool.new()
				rs.begin(Mesh.PRIMITIVE_TRIANGLES)
				_ramp(rs)
				col_arrays = rs.commit_to_arrays()
		Shape.PILLAR:
			var cm := CylinderMesh.new()
			cm.top_radius = size.x * 0.5
			cm.bottom_radius = size.x * 0.5
			cm.height = h
			cm.radial_segments = 8
			cm.rings = 1
			st.append_from(cm, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, size.z / size.x)), Vector3(0, h * 0.5, 0)))
		Shape.ARCH, Shape.DOORWAY, Shape.WINDOW:
			_wall_with_hole(st)
		Shape.ROOF:
			var pm := PrismMesh.new()
			pm.size = size
			st.append_from(pm, 0, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)))
		Shape.ROCK:
			_rock(st)
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	# Collision comes from the raw arrays, not the mesh, so it also works
	# with no GPU (headless tests, servers).
	if shape == Shape.ROCK:
		var convex := ConvexPolygonShape3D.new()
		convex.points = arrays[Mesh.ARRAY_VERTEX]
		_collision.shape = convex
	else:
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(_faces(col_arrays if not col_arrays.is_empty() else arrays))
		_collision.shape = trimesh


static func _faces(arrays: Array) -> PackedVector3Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	if idx == null or idx.is_empty():
		return verts
	var out := PackedVector3Array()
	out.resize(idx.size())
	for i in idx.size():
		out[i] = verts[idx[i]]
	return out


func _box(st: SurfaceTool, center: Vector3, box_size: Vector3) -> void:
	if box_size.x <= 0.001 or box_size.y <= 0.001 or box_size.z <= 0.001:
		return
	var bm := BoxMesh.new()
	bm.size = box_size
	st.append_from(bm, 0, Transform3D(Basis.IDENTITY, center))


## A wedge: full height at -Z, ground level at +Z.
func _ramp(st: SurfaceTool) -> void:
	var pm := PrismMesh.new()
	pm.left_to_right = 1.0
	pm.size = Vector3(size.z, size.y, size.x)
	st.append_from(pm, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, size.y * 0.5, 0)))


func _wall_with_hole(st: SurfaceTool) -> void:
	var w := minf(opening.x, size.x - 0.1)
	var top := minf(opening.y, size.y - 0.05)
	var bottom := clampf(sill, 0.0, top - 0.1) if shape == Shape.WINDOW else 0.0
	if shape == Shape.WINDOW:
		top = minf(bottom + opening.y, size.y - 0.05)
	var side := (size.x - w) * 0.5
	# Posts either side of the hole.
	_box(st, Vector3(-(w + side) * 0.5, size.y * 0.5, 0), Vector3(side, size.y, size.z))
	_box(st, Vector3((w + side) * 0.5, size.y * 0.5, 0), Vector3(side, size.y, size.z))
	# Sill under a window.
	_box(st, Vector3(0, bottom * 0.5, 0), Vector3(w, bottom, size.z))
	if shape != Shape.ARCH:
		_box(st, Vector3(0, (top + size.y) * 0.5, 0), Vector3(w, size.y - top, size.z))
		return
	# A stepped, retro semicircle: vertical strips that hang down to the curve.
	var r := w * 0.5
	var spring := maxf(top - r, 0.0)
	var strips := 10
	var sw := w / strips
	for i in strips:
		var x := -r + (i + 0.5) * sw
		var y := spring + sqrt(maxf(r * r - x * x, 0.0))
		_box(st, Vector3(x, (y + size.y) * 0.5, 0), Vector3(sw, size.y - y, size.z))


## A lumpy low-poly boulder, different for every seed.
func _rock(st: SurfaceTool) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 7
	sm.rings = 4
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	var bumps := {}
	st.set_smooth_group(-1)  # faceted, not smooth
	for i in verts.size():
		# Vertices on the UV seam share a position, so key bumps by position.
		var key := Vector3i((verts[i] * 1000.0).round())
		if not bumps.has(key):
			rng.seed = hash([rock_seed, key])
			bumps[key] = 1.0 + rng.randf_range(-roughness, roughness)
		var v: Vector3 = verts[i] * bumps[key]
		verts[i] = Vector3(v.x * size.x, (v.y + 0.5) * size.y, v.z * size.z)
	for i in idx.size():
		st.add_vertex(verts[idx[i]])
	st.generate_normals()
