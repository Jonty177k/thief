@tool
class_name JBDPlayerStart
extends Marker3D
## Where Jeffrey wakes up when the level starts. He faces -Z (away from
## the blue gizmo arrow).


func _ready() -> void:
	add_to_group("player_start")
	if not Engine.is_editor_hint():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	body.mesh = cap
	body.material_override = mat
	body.position.y = 0.85
	add_child(body, false, INTERNAL_MODE_BACK)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.15, 0.15, 0.6)
	nose.mesh = nm
	nose.material_override = mat
	nose.position = Vector3(0, 1.5, -0.45)
	add_child(nose, false, INTERNAL_MODE_BACK)
