@tool
class_name JBDBridge
extends StaticBody3D
## A bridge you can walk across: planks with railings, a sagging rope
## bridge, or a stone arch. It starts at the origin and spans toward -Z
## (away from the blue arrow), with the deck's top at the origin's height:
## click the near edge of a gap, turn it to face across, then set Length.

enum Style { PLANK, ROPE, STONE }

const WOOD := preload("res://addons/jbd_level_tools/materials/wood.tres")
const ROPE := preload("res://addons/jbd_level_tools/materials/rope.tres")
const RUIN := preload("res://addons/jbd_level_tools/materials/ruin.tres")

@export var style := Style.PLANK:
	set(v):
		style = v
		_queue_rebuild()
@export var length := 8.0:
	set(v):
		length = maxf(v, 1.0)
		_queue_rebuild()
@export var width := 1.6:
	set(v):
		width = maxf(v, 0.6)
		_queue_rebuild()
## Rope bridges only: how far the middle hangs below the ends.
@export var sag := 0.8:
	set(v):
		sag = maxf(v, 0.0)
		_queue_rebuild()
## Railings (or hand ropes, or parapets) you can't fall through.
@export var railings := true:
	set(v):
		railings = v
		_queue_rebuild()
## Stone bridges only: how deep the arch is under the middle.
@export var arch_depth := 2.5:
	set(v):
		arch_depth = maxf(v, 0.0)
		_queue_rebuild()
## Wooden bridges can take the grappling hook.
@export var grapple_anchor := true:
	set(v):
		grapple_anchor = v
		_update_group()

var _deck_mesh: MeshInstance3D
var _trim_mesh: MeshInstance3D
var _collision: CollisionShape3D
var _pending := false


func _ready() -> void:
	_update_group()
	rebuild()


func _update_group() -> void:
	if grapple_anchor and style != Style.STONE:
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
	_update_group()
	if _deck_mesh == null:
		_deck_mesh = MeshInstance3D.new()
		add_child(_deck_mesh, false, INTERNAL_MODE_BACK)
		_trim_mesh = MeshInstance3D.new()
		add_child(_trim_mesh, false, INTERNAL_MODE_BACK)
		_collision = CollisionShape3D.new()
		add_child(_collision, false, INTERNAL_MODE_BACK)
	var deck := SurfaceTool.new()
	var trim := SurfaceTool.new()
	var col := SurfaceTool.new()
	for st in [deck, trim, col]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match style:
		Style.PLANK:
			_plank(deck, trim, col)
		Style.ROPE:
			_rope(deck, trim, col)
		Style.STONE:
			_stone(deck, trim, col)
	_deck_mesh.mesh = _commit(deck)
	_deck_mesh.material_override = RUIN if style == Style.STONE else WOOD
	_trim_mesh.mesh = _commit(trim)
	_trim_mesh.material_override = RUIN if style == Style.STONE else (ROPE if style == Style.ROPE else WOOD)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(JBDBlock._faces(col.commit_to_arrays()))
	_collision.shape = shape


static func _commit(st: SurfaceTool) -> ArrayMesh:
	var arrays := st.commit_to_arrays()
	var verts = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or verts.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	st.append_from(bm, 0, Transform3D(basis, center))


func _plank(deck: SurfaceTool, trim: SurfaceTool, col: SurfaceTool) -> void:
	var n := maxi(int(length / 0.3), 1)
	var step := length / n
	for i in n:
		_box(deck, Vector3(0, -0.04, -(i + 0.5) * step), Vector3(width, 0.08, step - 0.03))
	# Two stringers underneath.
	for side in [-1.0, 1.0]:
		_box(deck, Vector3(side * (width * 0.5 - 0.1), -0.18, -length * 0.5), Vector3(0.14, 0.2, length))
	_box(col, Vector3(0, -0.14, -length * 0.5), Vector3(width, 0.28, length))
	if railings:
		var posts := maxi(int(length / 2.0), 1)
		for side in [-1.0, 1.0]:
			var x: float = side * (width * 0.5 - 0.04)
			for i in posts + 1:
				_box(trim, Vector3(x, 0.5, -length * i / posts), Vector3(0.09, 1.0, 0.09))
			_box(trim, Vector3(x, 1.0, -length * 0.5), Vector3(0.07, 0.07, length))
			_box(trim, Vector3(x, 0.55, -length * 0.5), Vector3(0.05, 0.05, length))
			_box(col, Vector3(x, 0.55, -length * 0.5), Vector3(0.08, 1.1, length))


## Height of a rope bridge's deck at fraction t (0..1) along it.
func _sag_at(t: float) -> float:
	return -sag * 4.0 * t * (1.0 - t)


func _rope(deck: SurfaceTool, trim: SurfaceTool, col: SurfaceTool) -> void:
	var n := maxi(int(length / 0.32), 2)
	var step := length / n
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a := Vector3(0, _sag_at(t0), -t0 * length)
		var b := Vector3(0, _sag_at(t1), -t1 * length)
		var mid := (a + b) * 0.5
		var tilt := Basis(Vector3.RIGHT, atan2(b.y - a.y, length / n))
		_box(deck, mid + Vector3(0, -0.04, 0), Vector3(width, 0.06, step - 0.06), tilt)
		_box(col, mid + Vector3(0, -0.06, 0), Vector3(width, 0.12, step + 0.02), tilt)
	# End posts and the hand ropes, which follow the deck's sag.
	var segs := 16
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 + 0.05)
		for end in [0.0, 1.0]:
			_box(trim, Vector3(x, 0.55, -end * length), Vector3(0.14, 1.5, 0.14))
		if not railings:
			continue
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var a := Vector3(x, _sag_at(t0) * 0.6 + 1.1, -t0 * length)
			var b := Vector3(x, _sag_at(t1) * 0.6 + 1.1, -t1 * length)
			var d := b - a
			var basis := Basis(Vector3.RIGHT, atan2(d.y, -d.z))
			_box(trim, (a + b) * 0.5, Vector3(0.04, 0.04, d.length() + 0.02), basis)
			# Side netting you can't fall through, from deck to rope.
			var deck_y := (_sag_at(t0) + _sag_at(t1)) * 0.5
			var top := (a.y + b.y) * 0.5
			_box(col, Vector3(x, (deck_y + top) * 0.5, (a.z + b.z) * 0.5), Vector3(0.06, top - deck_y, d.length() + 0.02))
			if k % 2 == 0:
				var dy := (top - deck_y)
				_box(trim, Vector3(x, (deck_y + top) * 0.5, (a.z + b.z) * 0.5), Vector3(0.02, dy, 0.02))


func _stone(deck: SurfaceTool, trim: SurfaceTool, col: SurfaceTool) -> void:
	var thick := 0.6
	var strips := maxi(int(length / 0.5), 4)
	var sw := length / strips
	# The span is solid from the deck down to an arch curve: shallow in the
	# middle, deep at the ends.
	for i in strips:
		var t := (i + 0.5) / strips
		var under := thick + arch_depth * (1.0 - sin(t * PI))
		_box(deck, Vector3(0, -under * 0.5, -t * length), Vector3(width, under, sw + 0.001))
		_box(col, Vector3(0, -under * 0.5, -t * length), Vector3(width, under, sw + 0.001))
	if railings:
		for side in [-1.0, 1.0]:
			var x: float = side * (width * 0.5 - 0.15)
			_box(trim, Vector3(x, 0.4, -length * 0.5), Vector3(0.3, 0.8, length))
			_box(col, Vector3(x, 0.4, -length * 0.5), Vector3(0.3, 0.8, length))
