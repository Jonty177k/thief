class_name PlayerStealth
extends Node
## How visible and how loud Jeffrey is, for enemies and the light gem.
## Daylight, campfires, torches and shadow zones light him; crouching and
## standing still hide him; running and hard landings are loud.

## 0..1, how visible Jeffrey is right now (the light gem).
var visibility := 0.5
## Radius in metres in which enemies can hear Jeffrey this frame.
var noise_radius := 0.0
var shadow_zones := 0
var player: CharacterBody3D
## Lights only count when nothing solid stands between them and Jeffrey.
var light_occlusion := true


func setup(p: CharacterBody3D) -> void:
	player = p


func make_noise(radius: float) -> void:
	noise_radius = maxf(noise_radius, radius)


func physics_update(delta: float) -> void:
	var light := 0.12 + 0.88 * Game.daylight()
	# Campfires, plus anything in the "light_source" group (e.g. torches),
	# which can set its own `light_radius`.
	var lights := get_tree().get_nodes_in_group("campfire") + get_tree().get_nodes_in_group("light_source")
	for l in lights:
		var radius: float = l.get("light_radius") if l.get("light_radius") != null else 10.0
		var d: float = l.global_position.distance_to(player.global_position)
		if d < radius and _lit_by(l):
			light = maxf(light, 0.95 * (1.0 - d / radius))
	if shadow_zones > 0:
		light *= 0.35

	var mv: PlayerMovement = player.movement
	var moving := mv.is_moving()
	var stance := 1.0
	if mv.crouching:
		stance = 0.55
	elif mv.running and moving:
		stance = 1.35
	elif not moving:
		stance = 0.8
	visibility = lerpf(visibility, clampf(light * stance, 0.0, 1.0), minf(delta * 4.0, 1.0))

	var n := 0.0
	if moving and player.is_on_floor():
		n = 11.0 if mv.running else (0.0 if mv.crouching else 3.5)
	noise_radius = maxf(n, noise_radius - delta * 20.0)


## Is there a clear line from light `l` to Jeffrey's chest?
func _lit_by(l: Node3D) -> bool:
	if not light_occlusion:
		return true
	var from := l.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * 1.2, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
