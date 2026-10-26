@tool
class_name FlameComponent
extends Node3D
## An open flame that is a real light source: a flickering flame mesh and
## an OmniLight3D. Fire lights it, water puts it out (through the standard
## elemental interface), and when it's out the Light3D is switched off, so
## the area really gets darker. While lit it joins "light_source" with a
## `light_radius`, which is what Jeffrey's light gem (PlayerStealth) reads,
## so enemies see him less once it's out. Torches, burning crates and fire
## arrows all use it.

signal lit_changed(lit: bool)

@export var lit := true:
	set(v):
		if v == lit:
			return
		lit = v
		_apply()
		if is_inside_tree() and not Engine.is_editor_hint():
			lit_changed.emit(lit)
@export var color := Color(1.0, 0.62, 0.3):
	set(v):
		color = v
		_apply()
@export_range(0.0, 16.0, 0.1) var energy := 1.6:
	set(v):
		energy = v
		_apply()
@export_range(0.5, 40.0, 0.5) var light_range := 9.0:
	set(v):
		light_range = v
		_apply()
@export var shadows := true:
	set(v):
		shadows = v
		_apply()
## Size of the flame mesh, in metres.
@export var flame_size := Vector3(0.2, 0.35, 0.2):
	set(v):
		flame_size = v
		_apply()
## 0 = steady, 1 = wild.
@export_range(0.0, 1.0) var flicker := 0.35
@export_group("Elements")
## Fire (a fire arrow, a burning neighbour) lights it.
@export var can_ignite := true
## Water (a water arrow) puts it out.
@export var can_extinguish := true
## Extra reach for splash and burst effects, in metres.
@export var reach_radius := 0.4
@export_group("Sound")
@export var play_sounds := true

## For PlayerStealth: how far this flame lights things, 0 when out.
var light_radius: float:
	get:
		return light_range if lit else 0.0

var light: OmniLight3D
var flame: MeshInstance3D
var _mat: StandardMaterial3D
var _sfx: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	add_to_group("elemental")
	_t = randf() * 10.0
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 4.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame = MeshInstance3D.new()
	flame.mesh = PrismMesh.new()
	flame.material_override = _mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame, false, INTERNAL_MODE_BACK)
	light = OmniLight3D.new()
	light.position.y = 0.2
	add_child(light, false, INTERNAL_MODE_BACK)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 4.0
	add_child(_sfx, false, INTERNAL_MODE_BACK)
	_apply()


func _apply() -> void:
	if light == null:
		return
	(flame.mesh as PrismMesh).size = flame_size
	flame.position.y = flame_size.y * 0.5
	_mat.albedo_color = color
	_mat.emission = color
	flame.visible = lit
	light.visible = lit
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	if lit:
		add_to_group("light_source")
	elif is_in_group("light_source"):
		remove_from_group("light_source")


func ignite() -> bool:
	if lit:
		return false
	lit = true
	_play(Sfx.ignite(), -4.0)
	return true


func extinguish() -> bool:
	if not lit:
		return false
	lit = false
	_play(Sfx.hiss(), -6.0)
	Fx.steam(self, global_position + Vector3.UP * 0.2)
	return true


## The elemental interface (see ElementalEffect).
func receive_element(effect: ElementalEffect) -> bool:
	match effect.element:
		ElementalEffect.Element.FIRE:
			return can_ignite and ignite()
		ElementalEffect.Element.WATER:
			return can_extinguish and extinguish()
	return false


func _process(delta: float) -> void:
	if not lit or light == null:
		return
	_t += delta
	var f := (sin(_t * 11.0) * 0.6 + sin(_t * 23.0 + 1.3) * 0.4) * flicker
	light.light_energy = energy * (1.0 + f * 0.6)
	flame.scale = Vector3(1.0, 1.0 + f * 0.5, 1.0)


func _play(stream: AudioStream, volume_db: float) -> void:
	if not play_sounds or _sfx == null or Engine.is_editor_hint():
		return
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()
