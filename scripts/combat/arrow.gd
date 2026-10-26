class_name Arrow
extends Node3D
## A physical arrow in flight. Each physics tick it falls under gravity and
## ray-casts from where it was to where it's going, so it can't skip
## through thin walls. On impact it damages what it hits (the damage
## interface), hands its element to whatever reacts (the elemental
## interface), sticks into soft surfaces or clatters off hard ones, makes
## a sound for listeners (Game.emit_noise), and stays visible for a while.

const HIT_MASK := 1 | 4 | 16

var type: ArrowType
var velocity := Vector3.ZERO
var gravity := 9.8
var damage := 20.0
var source: Node3D
## Seconds it stays after landing.
var stick_time := 20.0

var flying := true
var struck: Node
var _bounced := false
var _age := 0.0
var _exclude: Array[RID] = []
var _light: OmniLight3D
var _sfx: AudioStreamPlayer3D


static func spawn(parent: Node, p_type: ArrowType, from: Vector3, p_velocity: Vector3, p_damage: float,
		p_source: Node3D, p_gravity := 9.8) -> Arrow:
	var a := Arrow.new()
	a.type = p_type
	a.velocity = p_velocity
	a.damage = p_damage
	a.source = p_source
	a.gravity = p_gravity
	parent.add_child(a)
	a.global_position = from
	a._face()
	return a


func _ready() -> void:
	if source is CollisionObject3D:
		_exclude.append((source as CollisionObject3D).get_rid())
	_build()


func _build() -> void:
	var shaft := StandardMaterial3D.new()
	shaft.albedo_color = Color(0.45, 0.33, 0.2)
	var tip := StandardMaterial3D.new()
	tip.albedo_color = type.color
	if type.element != ElementalEffect.Element.PHYSICAL:
		tip.emission_enabled = true
		tip.emission = type.color
		tip.emission_energy_multiplier = 2.0
	var fletch := StandardMaterial3D.new()
	fletch.albedo_color = type.color.lerp(Color(0.8, 0.8, 0.75), 0.4)
	# The arrow points along -Z; its tip is at the origin.
	_box(Vector3(0.018, 0.018, 0.75), Vector3(0, 0, 0.375), shaft)
	_box(Vector3(0.04, 0.04, 0.08), Vector3(0, 0, 0.03), tip)
	_box(Vector3(0.005, 0.06, 0.14), Vector3(0, 0, 0.68), fletch)
	_box(Vector3(0.06, 0.005, 0.14), Vector3(0, 0, 0.68), fletch)
	if type.flight_light:
		_light = OmniLight3D.new()
		_light.light_color = type.color
		_light.light_energy = 1.2
		_light.omni_range = 3.5
		add_child(_light)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 3.0
	add_child(_sfx)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _face() -> void:
	if velocity.length() > 0.01:
		var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD
		look_at(global_position + velocity, up)


func _physics_process(delta: float) -> void:
	_age += delta
	if not flying:
		if _age > stick_time:
			queue_free()
		return
	if _age > 10.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	q.exclude = _exclude
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		_face()
		return
	_impact(hit)


func _impact(hit: Dictionary) -> void:
	var collider: Node = hit.collider
	var dir := velocity.normalized()
	global_position = hit.position
	if _bounced:
		_land(collider, hit)
		return
	var receiver := DamageInfo.find_receiver(collider)
	if receiver and receiver != source and damage > 0.0:
		var info := DamageInfo.make(damage, source, global_position - dir, global_position + dir, 1.0, "arrow")
		receiver.receive_damage(info)
	var tree := get_tree()
	# Every arrow knocks (switches); fused arrows also carry their element.
	ElementalEffect.apply(collider, ElementalEffect.make(ElementalEffect.Element.PHYSICAL, hit.position, source, 0.0, "arrow"), tree)
	var reacted := 0
	if type.element != ElementalEffect.Element.PHYSICAL:
		reacted = ElementalEffect.apply(collider, ElementalEffect.make(type.element, hit.position, source, type.effect_radius,
			type.name.to_snake_case()), tree)
	Game.emit_noise(hit.position, type.impact_noise_radius, self, "arrow_impact", 0.6)
	match type.element:
		ElementalEffect.Element.WATER:
			_play(Sfx.splash(), -10.0)
			Fx.splash(self, hit.position, hit.normal)
		ElementalEffect.Element.FIRE:
			_play(Sfx.arrow_thunk(), -4.0)
			if reacted == 0 and type.linger_flame_time > 0.0:
				_linger_flame()
		_:
			_play(Sfx.arrow_thunk(), -2.0)
	if receiver == null and Arrow.surface_is_hard(collider):
		# Clatters off stone and iron, and drops.
		_bounced = true
		velocity = velocity.bounce(hit.normal) * 0.04
		global_position = hit.position + hit.normal * 0.05
		Fx.sparks(self, hit.position, hit.normal)
		return
	# Bite in a little way and stay with whatever was hit (so it moves with doors and enemies).
	global_position = hit.position + dir * 0.12
	_land(collider, hit)


func _land(collider: Node, _hit: Dictionary) -> void:
	flying = false
	struck = collider
	_age = 0.0
	if _light:
		_light.queue_free()
		_light = null
	if collider and collider.is_inside_tree():
		reparent(collider, true)


## A fire arrow that hit nothing flammable keeps burning a few seconds:
## temporary illumination.
func _linger_flame() -> void:
	var f := FlameComponent.new()
	f.color = type.color
	f.flame_size = Vector3(0.12, 0.22, 0.12)
	f.energy = 1.0
	f.light_range = 4.0
	f.shadows = false
	f.play_sounds = false
	add_child(f)
	f.global_position = global_position + Vector3.UP * 0.02
	get_tree().create_timer(type.linger_flame_time, false).timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.lit = false)


## Stone, rock and iron don't hold arrows.
static func surface_is_hard(collider: Node) -> bool:
	if collider == null:
		return false
	if collider.is_in_group("hard_surface"):
		return true
	var mat = collider.get("material")
	if mat is Resource and (mat as Resource).resource_path != "":
		var path := (mat as Resource).resource_path
		for hard in ["ruin", "rock", "iron", "plate"]:
			if path.contains(hard):
				return true
	return false


func _play(stream: AudioStream, volume_db: float) -> void:
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()
