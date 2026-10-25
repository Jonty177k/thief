@tool
class_name JBDTerrain
extends Node3D
## Sculptable, paintable heightmap terrain. Select it and use the
## Terrain tab of the Level Tools dock to raise, lower, smooth, flatten,
## carve cliffs and ramps, and paint four texture layers.
##
## The grid starts at this node's origin and runs along +X and +Z.
## Heights and paint live in `data` (a .res file next to the level).

enum Tool { RAISE, LOWER, SMOOTH, FLATTEN, SET_HEIGHT, PAINT }

const CHUNK := 32
const NOISE := preload("res://addons/jbd_level_tools/materials/noise.tres")
const SHADER := preload("res://addons/jbd_level_tools/terrain/terrain.gdshader")

@export var data: JBDTerrainData:
	set(v):
		data = v
		if is_inside_tree():
			rebuild()

@export_group("Layers")
@export var layer_names := PackedStringArray(["Hide", "Plate", "Bone", "Rock"])
@export var layer_colors: Array[Color] = [
	Color(0.42, 0.38, 0.34), Color(0.5, 0.47, 0.42), Color(0.82, 0.78, 0.68), Color(0.3, 0.27, 0.25),
]:
	set(v):
		layer_colors = v
		_update_material()
## Leave empty to use the game's crunchy noise texture.
@export var layer_textures: Array[Texture2D] = [null, null, null, null]:
	set(v):
		layer_textures = v
		_update_material()
## Texture repeats per metre.
@export var uv_scale := 0.25:
	set(v):
		uv_scale = v
		_update_material()
## Slopes steeper than this show the Rock layer automatically. 90 = off.
@export_range(10.0, 90.0) var cliff_angle := 50.0:
	set(v):
		cliff_angle = v
		_update_material()
## Wooden terrain? Lets the grappling hook bite the ground. Usually off.
@export var grapple_anchor := false

var material: ShaderMaterial
var _chunks := {}  # Vector2i -> {mesh: MeshInstance3D, body: StaticBody3D, shape: CollisionShape3D}


func _ready() -> void:
	rebuild()


## Throw away every chunk and build the whole terrain again.
func rebuild() -> void:
	for c in _chunks.values():
		c.mesh.queue_free()
		c.body.queue_free()
	_chunks.clear()
	_update_material()
	if data == null or not data.is_valid():
		return
	for cz in ceili(float(data.cells_z) / CHUNK):
		for cx in ceili(float(data.cells_x) / CHUNK):
			_build_chunk(Vector2i(cx, cz), true)


## Rebuild only the chunks touching a grid rectangle. Collision is rebuilt
## separately (it's slower), normally when a brush stroke ends.
func rebuild_region(region: Rect2i, with_collision := false) -> void:
	if data == null or not data.is_valid():
		return
	var grown := region.grow(1)
	var c0 := Vector2i(maxi(grown.position.x, 0) / CHUNK, maxi(grown.position.y, 0) / CHUNK)
	var c1 := Vector2i(mini(grown.end.x, data.cells_x - 1) / CHUNK, mini(grown.end.y, data.cells_z - 1) / CHUNK)
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			_build_chunk(Vector2i(cx, cz), with_collision)


func _update_material() -> void:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SHADER
	for i in 4:
		var col: Color = layer_colors[i] if i < layer_colors.size() else Color.WHITE
		var tex: Texture2D = layer_textures[i] if i < layer_textures.size() and layer_textures[i] else NOISE
		material.set_shader_parameter("color_%d" % i, col)
		material.set_shader_parameter("texture_%d" % i, tex)
	material.set_shader_parameter("uv_scale", uv_scale)
	material.set_shader_parameter("cliff_angle", cliff_angle)


func _build_chunk(key: Vector2i, with_collision: bool) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var w := mini(CHUNK, data.cells_x - x0)
	var d := mini(CHUNK, data.cells_z - z0)
	if w <= 0 or d <= 0:
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize((w + 1) * (d + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	var s := data.cell_size
	var i := 0
	for z in range(z0, z0 + d + 1):
		for x in range(x0, x0 + w + 1):
			var idx := data.index(x, z)
			verts[i] = Vector3(x * s, data.heights[idx], z * s)
			normals[i] = data.normal_at(x, z)
			colors[i] = data.paint[idx]
			i += 1
	indices.resize(w * d * 6)
	i = 0
	for z in d:
		for x in w:
			var a := z * (w + 1) + x
			var b := a + 1
			var c := a + w + 1
			var e := c + 1
			# Split each quad along the diagonal that follows the slope.
			if absf(verts[a].y - verts[e].y) < absf(verts[b].y - verts[c].y):
				indices[i] = a; indices[i + 1] = b; indices[i + 2] = e
				indices[i + 3] = a; indices[i + 4] = e; indices[i + 5] = c
			else:
				indices[i] = a; indices[i + 1] = b; indices[i + 2] = c
				indices[i + 3] = b; indices[i + 4] = e; indices[i + 5] = c
			i += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var chunk: Dictionary = _chunks.get(key, {})
	if chunk.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Chunk_%d_%d" % [key.x, key.y]
		add_child(mi, false, INTERNAL_MODE_BACK)
		var body := StaticBody3D.new()
		body.name = "Collision_%d_%d" % [key.x, key.y]
		if grapple_anchor:
			body.add_to_group("grapple")
		var cs := CollisionShape3D.new()
		body.add_child(cs)
		add_child(body, false, INTERNAL_MODE_BACK)
		chunk = {"mesh": mi, "body": body, "shape": cs}
		_chunks[key] = chunk
	chunk.mesh.mesh = mesh
	chunk.mesh.material_override = material
	if with_collision:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		var faces := PackedVector3Array()
		faces.resize(indices.size())
		for k in indices.size():
			faces[k] = verts[indices[k]]
		shape.set_faces(faces)
		chunk.shape.shape = shape


# --- Queries -----------------------------------------------------------------

## Height of the terrain surface under a world position.
func height_at(world_pos: Vector3) -> float:
	var l := to_local(world_pos)
	return to_global(Vector3(l.x, data.sample(l.x, l.z), l.z)).y


func contains(world_pos: Vector3) -> bool:
	var l := to_local(world_pos)
	var sz := data.size()
	return l.x >= 0.0 and l.z >= 0.0 and l.x <= sz.x and l.z <= sz.y


## Where a world-space ray first meets the terrain, or null. Works in the
## editor without physics, straight off the height data.
func raycast(from: Vector3, dir: Vector3, max_dist := 2000.0) -> Variant:
	if data == null or not data.is_valid():
		return null
	var lf := to_local(from)
	var ld := (to_local(from + dir) - lf).normalized()
	var step := data.cell_size * 0.5
	var t := 0.0
	var prev_above := true
	var sz := data.size()
	while t < max_dist:
		var p := lf + ld * t
		var inside := p.x >= 0.0 and p.z >= 0.0 and p.x <= sz.x and p.z <= sz.y
		if inside:
			var above := p.y > data.sample(p.x, p.z)
			if not above and prev_above and t > 0.0:
				# Refine between the last two samples.
				var lo := t - step
				var hi := t
				for _i in 10:
					var mid := (lo + hi) * 0.5
					var m := lf + ld * mid
					if m.y > data.sample(m.x, m.z):
						lo = mid
					else:
						hi = mid
				return to_global(lf + ld * hi)
			prev_above = above
		else:
			prev_above = true
		t += step
	return null


# --- Brushes -----------------------------------------------------------------

## Apply one tick of a brush centred on a local XZ position (metres).
## `strength` is metres per second for raise/lower, 0..1 blend otherwise.
## `hardness` 0 = soft round brush, 1 = hard edge (good for cliffs).
## `target` is the height for FLATTEN / SET_HEIGHT, `layer` for PAINT.
## Returns the grid rectangle that changed.
func apply_brush(tool: Tool, center: Vector2, radius: float, strength: float, hardness: float, delta: float, target := 0.0, layer := 0) -> Rect2i:
	var s := data.cell_size
	var gx0 := clampi(floori((center.x - radius) / s), 0, data.cells_x)
	var gz0 := clampi(floori((center.y - radius) / s), 0, data.cells_z)
	var gx1 := clampi(ceili((center.x + radius) / s), 0, data.cells_x)
	var gz1 := clampi(ceili((center.y + radius) / s), 0, data.cells_z)
	var region := Rect2i(gx0, gz0, gx1 - gx0, gz1 - gz0)
	var src := data.heights.duplicate() if tool == Tool.SMOOTH else data.heights
	var blend := clampf(strength * delta * 8.0, 0.0, 1.0)
	for z in range(gz0, gz1 + 1):
		for x in range(gx0, gx1 + 1):
			var f := _falloff(Vector2(x * s, z * s).distance_to(center) / radius, hardness)
			if f <= 0.0:
				continue
			var idx := data.index(x, z)
			match tool:
				Tool.RAISE:
					data.heights[idx] += strength * delta * f
				Tool.LOWER:
					data.heights[idx] -= strength * delta * f
				Tool.SMOOTH:
					var avg := 0.0
					for oz in range(-1, 2):
						for ox in range(-1, 2):
							avg += src[data.index(clampi(x + ox, 0, data.cells_x), clampi(z + oz, 0, data.cells_z))]
					data.heights[idx] = lerpf(src[idx], avg / 9.0, blend * f)
				Tool.FLATTEN:
					data.heights[idx] = lerpf(data.heights[idx], target, blend * f)
				Tool.SET_HEIGHT:
					data.heights[idx] = lerpf(data.heights[idx], target, f)
				Tool.PAINT:
					var full := Color(0, 0, 0, 0)
					full[layer] = 1.0
					data.paint[idx] = data.paint[idx].lerp(full, blend * f)
	return region


## Carve a straight slope between two local points (x, height, z),
## `width` metres wide. The quickest way to make a path up a cliff.
func apply_ramp(a: Vector3, b: Vector3, width: float, hardness: float) -> Rect2i:
	var s := data.cell_size
	var r := width * 0.5
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2(r, r)
	var gx0 := clampi(floori(lo.x / s), 0, data.cells_x)
	var gz0 := clampi(floori(lo.y / s), 0, data.cells_z)
	var gx1 := clampi(ceili(hi.x / s), 0, data.cells_x)
	var gz1 := clampi(ceili(hi.y / s), 0, data.cells_z)
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var len2 := maxf(ab.length_squared(), 0.0001)
	for z in range(gz0, gz1 + 1):
		for x in range(gx0, gx1 + 1):
			var p := Vector2(x * s, z * s)
			var t := clampf((p - a2).dot(ab) / len2, 0.0, 1.0)
			var f := _falloff(p.distance_to(a2 + ab * t) / r, hardness)
			if f <= 0.0:
				continue
			var idx := data.index(x, z)
			data.heights[idx] = lerpf(data.heights[idx], lerpf(a.y, b.y, t), f)
	return Rect2i(gx0, gz0, gx1 - gx0, gz1 - gz0)


static func _falloff(t: float, hardness: float) -> float:
	if t >= 1.0:
		return 0.0
	var h := clampf(hardness, 0.0, 0.99)
	if t <= h:
		return 1.0
	return 1.0 - smoothstep(h, 1.0, t)


## Swap in a saved copy of the heights and paint (used by undo/redo).
func restore(p_heights: PackedFloat32Array, p_paint: PackedColorArray) -> void:
	data.heights = p_heights.duplicate()
	data.paint = p_paint.duplicate()
	rebuild()
	if Engine.is_editor_hint() and data.resource_path != "" and not data.resource_path.contains("::"):
		ResourceSaver.save(data)
