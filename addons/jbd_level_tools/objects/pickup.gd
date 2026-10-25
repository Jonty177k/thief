@tool
class_name JBDPickup
extends StaticBody3D
## Something small to pick up. There's no inventory yet: it just says what
## you found and disappears. Not solid (only the interaction ray sees it).

signal picked_up(item_name: String)

@export var item_name := "Bone charm"

var _gem: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	shape.position.y = 0.4
	add_child(shape, false, INTERNAL_MODE_BACK)
	_gem = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 0.3, 0.22)
	_gem.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.7, 0.3)
	mat.emission_energy_multiplier = 1.5
	_gem.material_override = mat
	_gem.position.y = 0.4
	add_child(_gem, false, INTERNAL_MODE_BACK)
	if Engine.is_editor_hint():
		return
	var use := Interactable.new()
	use.prompt = "Pick up %s" % item_name
	use.interacted.connect(_on_used)
	add_child(use)


func _process(delta: float) -> void:
	_t += delta
	_gem.rotation.y = _t * 1.5
	_gem.position.y = 0.4 + sin(_t * 2.0) * 0.04


func _on_used(by: Node) -> void:
	if by.has_signal("notice"):
		by.notice.emit("Picked up %s" % item_name)
	picked_up.emit(item_name)
	queue_free()
