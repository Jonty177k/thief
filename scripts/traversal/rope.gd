class_name Rope
extends RefCounted
## Helpers for drawing straight lines (wires, hook cables) with a
## unit-height CylinderMesh.


## Stretch `m` (a CylinderMesh of height 1 along Y, top_level or under an
## untransformed parent) from `from` to `to` in world space.
static func stretch(m: Node3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var length := span.length()
	if length < 0.001:
		m.visible = false
		return
	var y := span / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	m.global_transform = Transform3D(Basis(x, y * length, z), from + span * 0.5)
