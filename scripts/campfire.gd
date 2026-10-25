extends Node3D
## A campfire checkpoint. Touch it to make it your respawn point,
## use it (Interact) to rest: heal and skip to morning or evening.

signal player_entered(fire: Node3D)
signal player_exited(fire: Node3D)
## Jeffrey used the fire. Main opens the rest menu.
signal rest_requested(fire: Node3D)

var fire_name := "Campfire"
var kindled := false

var light: OmniLight3D
var flame: MeshInstance3D
var flame_mat: StandardMaterial3D
var t := 0.0


func _ready() -> void:
	add_to_group("campfire")
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.3, 0.2, 0.12)
	log_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	for i in 3:
		var wood := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.18, 0.18, 1.1)
		wood.mesh = m
		wood.material_override = log_mat
		wood.position.y = 0.12
		wood.rotation.y = i * PI / 3.0
		add_child(wood)

	flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.1)
	flame_mat.emission_energy_multiplier = 4.0
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame = MeshInstance3D.new()
	var fm := PrismMesh.new()
	fm.size = Vector3(0.45, 0.7, 0.45)
	flame.mesh = fm
	flame.material_override = flame_mat
	flame.position.y = 0.5
	add_child(flame)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 11.0
	light.light_energy = 2.0
	light.shadow_enabled = true
	light.position.y = 1.0
	add_child(light)

	# Something for the interaction ray to land on (layer 4: not solid).
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 1.0
	body_shape.shape = cyl
	body_shape.position.y = 0.5
	body.add_child(body_shape)
	add_child(body)
	var use := Interactable.new()
	use.prompt = "Rest at %s" % fire_name
	use.interacted.connect(func(_by: Node) -> void: rest_requested.emit(self))
	body.add_child(use)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			player_entered.emit(self))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			player_exited.emit(self))


func _process(delta: float) -> void:
	t += delta
	var flicker := sin(t * 11.0) * 0.15 + sin(t * 23.0 + 1.3) * 0.1
	light.light_energy = 2.0 + flicker * 2.0
	flame.scale = Vector3(1.0, 1.0 + flicker, 1.0)
	flame.rotation.y = t * 1.5


## Where the player respawns: just beside the fire, not in it.
func respawn_point() -> Vector3:
	return global_position + global_transform.basis.z * 1.8 + Vector3.UP * 0.2
