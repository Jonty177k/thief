@tool
class_name JBDCampfire
extends Node3D
## A campfire checkpoint. In the game it becomes a real campfire: touch it
## to set your respawn point, rest at it to heal and skip to morning or
## evening. You respawn on its blue (+Z) side.

const Campfire := preload("res://scripts/campfire.gd")

@export var fire_name := "Campfire"

var fire: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_preview()
		return
	fire = Campfire.new()
	fire.fire_name = fire_name
	add_child(fire)


func _build_preview() -> void:
	var logs := StandardMaterial3D.new()
	logs.albedo_color = Color(0.3, 0.2, 0.12)
	for i in 3:
		var wood := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.18, 0.18, 1.1)
		wood.mesh = m
		wood.material_override = logs
		wood.position.y = 0.12
		wood.rotation.y = i * PI / 3.0
		add_child(wood, false, INTERNAL_MODE_BACK)
	var flame := MeshInstance3D.new()
	var fm := PrismMesh.new()
	fm.size = Vector3(0.45, 0.7, 0.45)
	flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.55, 0.15)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = fmat
	flame.position.y = 0.5
	add_child(flame, false, INTERNAL_MODE_BACK)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 11.0
	light.light_energy = 2.0
	light.position.y = 1.0
	add_child(light, false, INTERNAL_MODE_BACK)
	var label := Label3D.new()
	label.text = fire_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.position.y = 1.6
	add_child(label, false, INTERNAL_MODE_BACK)
	# Where Jeffrey will respawn.
	var spot := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.3
	sm.bottom_radius = 0.3
	sm.height = 0.05
	spot.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spot.material_override = smat
	spot.position = Vector3(0, 0.03, 1.8)
	add_child(spot, false, INTERNAL_MODE_BACK)
