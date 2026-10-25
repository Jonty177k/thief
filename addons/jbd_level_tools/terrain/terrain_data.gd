@tool
class_name JBDTerrainData
extends Resource
## Heights and paint for a JBDTerrain, saved as its own .res file so a
## level scene stays small and readable.
##
## The terrain is a grid of (cells_x + 1) * (cells_z + 1) vertices,
## `cell_size` metres apart, starting at the terrain node's origin.
## Each vertex has a height and four paint weights (one per texture layer,
## stored in a Color as r, g, b, a).

@export var cells_x := 128
@export var cells_z := 128
@export var cell_size := 1.0
@export var heights := PackedFloat32Array()
@export var paint := PackedColorArray()


func setup(p_cells_x: int, p_cells_z: int, p_cell_size: float, base_height := 0.0) -> void:
	cells_x = p_cells_x
	cells_z = p_cells_z
	cell_size = p_cell_size
	heights = PackedFloat32Array()
	heights.resize(vertex_count())
	heights.fill(base_height)
	paint = PackedColorArray()
	paint.resize(vertex_count())
	paint.fill(Color(1, 0, 0, 0))


func vertex_count() -> int:
	return (cells_x + 1) * (cells_z + 1)


func is_valid() -> bool:
	return cells_x > 0 and cells_z > 0 and heights.size() == vertex_count() and paint.size() == vertex_count()


func index(x: int, z: int) -> int:
	return z * (cells_x + 1) + x


func get_height(x: int, z: int) -> float:
	return heights[index(clampi(x, 0, cells_x), clampi(z, 0, cells_z))]


func size() -> Vector2:
	return Vector2(cells_x, cells_z) * cell_size


## Bilinear height at a local position (metres from the terrain origin).
func sample(local_x: float, local_z: float) -> float:
	var gx := clampf(local_x / cell_size, 0.0, cells_x)
	var gz := clampf(local_z / cell_size, 0.0, cells_z)
	var x0 := mini(int(gx), cells_x - 1)
	var z0 := mini(int(gz), cells_z - 1)
	var fx := gx - x0
	var fz := gz - z0
	var a := lerpf(get_height(x0, z0), get_height(x0 + 1, z0), fx)
	var b := lerpf(get_height(x0, z0 + 1), get_height(x0 + 1, z0 + 1), fx)
	return lerpf(a, b, fz)


func normal_at(x: int, z: int) -> Vector3:
	var hl := get_height(x - 1, z)
	var hr := get_height(x + 1, z)
	var hd := get_height(x, z - 1)
	var hu := get_height(x, z + 1)
	return Vector3(hl - hr, 2.0 * cell_size, hd - hu).normalized()
