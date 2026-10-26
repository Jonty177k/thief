class_name TightWire
extends Node3D
## A taut wire between two anchors, laid by the wire gun. It's a straight
## line (no rope physics) with an anchor bolt at each end and a mount point
## a little way in from each end. Look at a mount point and press Interact
## (Square / E) to step onto the wire. The wire itself has no collision:
## walking it is path-following (see PlayerHookshot), so Jeffrey can't
## drift off it.

signal mount_requested(wire: TightWire, end: int)

## Mount points sit this far in from each anchor, in metres.
const END_INSET := 0.55

## The two ends, in world space (on the anchor surfaces).
var a := Vector3.ZERO
var b := Vector3.ZERO
## Where Jeffrey steps off at each end (ground beside the anchor).
var dismount_a := Vector3.ZERO
var dismount_b := Vector3.ZERO

var _line: MeshInstance3D
var _markers: Array[Node3D] = []


static func create(parent: Node, p_a: Vector3, p_b: Vector3, p_dismount_a: Vector3, p_dismount_b: Vector3) -> TightWire:
	var w := TightWire.new()
	w.a = p_a
	w.b = p_b
	w.dismount_a = p_dismount_a
	w.dismount_b = p_dismount_b
	parent.add_child(w)
	w.global_position = Vector3.ZERO
	w._build()
	return w


func length() -> float:
	return a.distance_to(b)


## Unit vector from end A to end B.
func direction() -> Vector3:
	return (b - a).normalized()


## The point `s` metres along the wire from end A.
func point_at(s: float) -> Vector3:
	return a + direction() * clampf(s, 0.0, length())


## Distance along the wire of mount point `end` (0 = A, 1 = B).
func mount_s(end: int) -> float:
	return END_INSET if end == 0 else length() - END_INSET


func end_point(end: int) -> Vector3:
	return a if end == 0 else b


func dismount_point(end: int) -> Vector3:
	return dismount_a if end == 0 else dismount_b


func _build() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.55, 0.58)
	steel.metallic = 0.5
	_line = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 1.0
	cyl.radial_segments = 5
	_line.mesh = cyl
	_line.material_override = steel
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	Rope.stretch(_line, a, b)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.24, 0.24)
	for p in [a, b]:
		var bolt := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.12)
		bolt.mesh = bm
		bolt.material_override = iron
		add_child(bolt)
		bolt.global_position = p
	for end in 2:
		_add_mount(end)


## A faint ring and an interaction target at each mount point.
func _add_mount(end: int) -> void:
	var m := StaticBody3D.new()
	m.collision_layer = 8  # the interaction ray's layer; nothing walks into it
	m.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	m.add_child(shape)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.2
	ring.mesh = tm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.8, 0.5, 0.6)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(ring)
	var use := Interactable.new()
	use.prompt = "Walk the wire"
	use.interacted.connect(func(_by: Node) -> void: mount_requested.emit(self, end))
	m.add_child(use)
	add_child(m)
	m.global_position = point_at(mount_s(end))
	_markers.append(m)


## The mount points stop being usable (while someone is on the wire).
func set_mounts_enabled(on: bool) -> void:
	for m in _markers:
		for c in m.get_children():
			if c is Interactable:
				c.enabled = on
			elif c is MeshInstance3D:
				c.visible = on
