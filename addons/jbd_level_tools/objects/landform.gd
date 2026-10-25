@tool
class_name JBDLandform
extends StaticBody3D
## Natural ground and rock you place like blocks: ground tiles, slopes,
## hills, cliffs, ledges, mesas, spires and mountains. Each one is a
## rough, faceted shape made from noise, different for every Rock Seed, with a
## grassy top and rocky (or earthy) sides. Change Form, Size, Seed and
## Roughness in the Inspector; mesh and collision rebuild themselves.
## The origin is the bottom centre, except ground tiles and slopes, whose
## origin is on their top surface so they sit flush with the floor.

enum Form { GROUND, SLOPE, HILL, CLIFF, LEDGE, MESA, SPIRE, MOUNTAIN }

const GRASS := preload("res://addons/jbd_level_tools/materials/grass.tres")
const ROCK := preload("res://addons/jbd_level_tools/materials/rock.tres")

## GROUND: size.y is the tile's thickness below its top.
## SLOPE: size.y is how much it rises toward -Z.
## Everything else: size.y is the height.
@export var form := Form.CLIFF:
	set(v):
		form = v
		_queue_rebuild()
@export var size := Vector3(12, 10, 4):
	set(v):
		size = v.max(Vector3(0.5, 0.2, 0.5))
		_queue_rebuild()
@export var rock_seed := 1:
	set(v):
		rock_seed = v
		_queue_rebuild()
## How far the surface wanders from the plain shape, in metres.
@export_range(0.0, 8.0, 0.05) var roughness := 0.8:
	set(v):
		roughness = v
		_queue_rebuild()
## Size of the lumps, in metres.
@export_range(0.5, 40.0, 0.5) var feature_size := 4.0:
	set(v):
		feature_size = v
		_queue_rebuild()
## Faces flatter than this get the top material.
@export_range(0.0, 1.0, 0.05) var top_threshold := 0.7:
	set(v):
		top_threshold = v
		_queue_rebuild()
@export var top_material: Material = GRASS:
	set(v):
		top_material = v
		_queue_rebuild()
@export var side_material: Material = ROCK:
	set(v):
		side_material = v
		_queue_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _pending := false
var _noise: Array[FastNoiseLite] = []


func _ready() -> void:
	rebuild()


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
	_setup_noise()
	# Triangles as [a, b, c, outward hint] in the plain shape.
	var tris: Array = []
	match form:
		Form.GROUND, Form.SLOPE:
			var top := 0.0
			_box(tris, Vector3(-size.x * 0.5, -(size.y if form == Form.GROUND else 1.5), -size.z * 0.5),
				Vector3(size.x * 0.5, top, size.z * 0.5), 2.0)
		Form.CLIFF, Form.LEDGE:
			_box(tris, Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(size.x * 0.5, size.y, size.z * 0.5), 1.5)
		Form.HILL:
			_radial(tris, func(v: float) -> float: return sqrt(maxf(1.0 - v * v, 0.0)), false)
		Form.MESA:
			_radial(tris, func(v: float) -> float: return 1.0 - 0.18 * v, true)
		Form.SPIRE:
			_radial(tris, func(v: float) -> float: return 1.0 - 0.8 * v, true)
		Form.MOUNTAIN:
			_radial(tris, func(v: float) -> float: return pow(1.0 - v, 1.1) * 0.97 + 0.03 * (1.0 - v), false)

	var top_st := SurfaceTool.new()
	var side_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	side_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var tops := 0
	var sides := 0
	for t in tris:
		var a: Vector3 = _displace(t[0])
		var b: Vector3 = _displace(t[1])
		var c: Vector3 = _displace(t[2])
		var n := (c - a).cross(b - a)
		if n.length() < 0.000001:
			continue
		n = n.normalized()
		var st := top_st if n.y >= top_threshold else side_st
		if st == top_st:
			tops += 1
		else:
			sides += 1
		for v in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
		faces.append_array([a, b, c])
	var mesh := ArrayMesh.new()
	if tops > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_st.commit_to_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, top_material)
	if sides > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side_st.commit_to_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, side_material)
	_mesh_instance.mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	_collision.shape = shape


func _setup_noise() -> void:
	_noise.clear()
	for i in 3:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = rock_seed * 3 + i
		n.frequency = 1.0 / feature_size
		n.fractal_octaves = 3
		_noise.append(n)


## Move a vertex of the plain shape. The offset depends only on position,
## so vertices shared by two faces move together and the shape stays closed.
func _displace(p: Vector3) -> Vector3:
	var o := Vector3(_noise[0].get_noise_3dv(p), _noise[1].get_noise_3dv(p), _noise[2].get_noise_3dv(p)) * roughness * 1.6
	match form:
		Form.GROUND, Form.SLOPE:
			var depth := size.y if form == Form.GROUND else 1.5
			# Only gentle rolls on top, fading to nothing at the tile's edges
			# (so neighbouring tiles meet) and at its bottom.
			var edge := minf(size.x * 0.5 - absf(p.x), size.z * 0.5 - absf(p.z))
			var w := smoothstep(0.0, 1.5, edge) * clampf((p.y + depth) / depth, 0.0, 1.0)
			o = Vector3(0, o.y * w * 0.5, 0)
			if form == Form.SLOPE and p.y > -1.5 + 0.01:
				o.y += size.y * clampf(0.5 - p.z / size.z, 0.0, 1.0)
		Form.CLIFF:
			# The rock face is toward -Z; the back (+Z) stays flat to sit
			# against terrain. The top stays walkable.
			var face := smoothstep(size.z * 0.5, -size.z * 0.5, p.z)
			o = Vector3(o.x * face, o.y * 0.3 * smoothstep(0.0, 1.0, p.y), o.z * face)
		Form.LEDGE:
			o = Vector3(o.x, o.y * 0.2 * smoothstep(0.0, 0.5, p.y), o.z)
		Form.HILL:
			o = Vector3(o.x * 0.3, o.y * smoothstep(0.0, 1.0, p.y), o.z * 0.3)
		_:
			var base := smoothstep(0.0, maxf(size.y * 0.1, 0.5), p.y)
			var top := 1.0
			if form != Form.MOUNTAIN and p.y > size.y - 0.01:
				top = 0.15  # keep mesa and spire tops flat enough to stand on
			o = Vector3(o.x, o.y * base * top, o.z)
	return p + o


## A box from `lo` to `hi`, split into cells about `cell` metres across.
func _box(tris: Array, lo: Vector3, hi: Vector3, cell: float) -> void:
	var d := hi - lo
	var n := Vector3i(clampi(ceili(d.x / cell), 1, 40), clampi(ceili(d.y / cell), 1, 40), clampi(ceili(d.z / cell), 1, 40))
	var corner := func(fx: float, fy: float, fz: float) -> Vector3:
		return lo + d * Vector3(fx, fy, fz)
	# Each face: origin, u axis, v axis (as fractions), cells along u and v, outward.
	var faces := [
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), n.x, n.z, Vector3.UP],
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), n.x, n.z, Vector3.DOWN],
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), n.x, n.y, Vector3.FORWARD],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), n.x, n.y, Vector3.BACK],
		[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), n.z, n.y, Vector3.LEFT],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), n.z, n.y, Vector3.RIGHT],
	]
	for f in faces:
		var o: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		for i in f[3]:
			for j in f[4]:
				var f00: Vector3 = o + u * (float(i) / f[3]) + v * (float(j) / f[4])
				var f10: Vector3 = o + u * (float(i + 1) / f[3]) + v * (float(j) / f[4])
				var f01: Vector3 = o + u * (float(i) / f[3]) + v * (float(j + 1) / f[4])
				var f11: Vector3 = o + u * (float(i + 1) / f[3]) + v * (float(j + 1) / f[4])
				var p00: Vector3 = corner.call(f00.x, f00.y, f00.z)
				var p10: Vector3 = corner.call(f10.x, f10.y, f10.z)
				var p01: Vector3 = corner.call(f01.x, f01.y, f01.z)
				var p11: Vector3 = corner.call(f11.x, f11.y, f11.z)
				_tri(tris, p00, p10, p11, f[5])
				_tri(tris, p00, p11, p01, f[5])


## A round shape: radius at height fraction v is profile(v) of the base
## radius (an ellipse of size.x by size.z). `cap` closes a flat top.
func _radial(tris: Array, profile: Callable, cap: bool) -> void:
	var h := size.y
	var rx := size.x * 0.5
	var rz := size.z * 0.5
	var segs := clampi(ceili(PI * (rx + rz) / 2.5), 10, 48)
	var rings := clampi(ceili(h / 2.0), 3, 28)
	var ring := func(k: int, s: int) -> Vector3:
		var v := float(k) / rings
		var a := TAU * float(s % segs) / segs
		var r: float = profile.call(v)
		return Vector3(cos(a) * rx * r, v * h, sin(a) * rz * r)
	for k in rings:
		for s in segs:
			var a: Vector3 = ring.call(k, s)
			var b: Vector3 = ring.call(k, s + 1)
			var c: Vector3 = ring.call(k + 1, s)
			var d: Vector3 = ring.call(k + 1, s + 1)
			var out := Vector3(a.x + b.x, 0, a.z + b.z).normalized()
			_tri(tris, a, b, d, out)
			_tri(tris, a, d, c, out)
	# Bottom and (optionally) top: concentric rings to a centre point.
	var top_r: float = profile.call(1.0)
	for end in [0, 1]:
		if end == 1 and (not cap or top_r < 0.02):
			continue
		var y := 0.0 if end == 0 else h
		var r0: float = profile.call(float(end))
		var steps := 1 if end == 0 else 3
		for q in steps:
			var f0 := float(q) / steps
			var f1 := float(q + 1) / steps
			for s in segs:
				var a0 := TAU * float(s) / segs
				var a1 := TAU * float(s + 1) / segs
				var p0 := Vector3(cos(a0) * rx * r0 * f1, y, sin(a0) * rz * r0 * f1)
				var p1 := Vector3(cos(a1) * rx * r0 * f1, y, sin(a1) * rz * r0 * f1)
				var p2 := Vector3(cos(a0) * rx * r0 * f0, y, sin(a0) * rz * r0 * f0)
				var p3 := Vector3(cos(a1) * rx * r0 * f0, y, sin(a1) * rz * r0 * f0)
				var out := Vector3.DOWN if end == 0 else Vector3.UP
				_tri(tris, p0, p1, p3, out)
				if q > 0:
					_tri(tris, p0, p3, p2, out)


## Add a triangle, wound so Godot treats `out` as its front.
func _tri(tris: Array, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (c - a).cross(b - a).dot(out) < 0.0:
		tris.append([a, c, b])
	else:
		tris.append([a, b, c])


## Height of the top surface straight above `world_pos`, or NAN if none.
func height_at(world_pos: Vector3) -> float:
	var from := Vector3(world_pos.x, global_position.y + size.y + 50.0, world_pos.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (size.y + 200.0))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() and hit.collider == self else NAN
