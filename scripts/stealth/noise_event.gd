class_name NoiseEvent
extends RefCounted
## A sound something made, for anything that listens (enemy hearing, the
## stealth system). Tools and projectiles never decide who hears them:
## they emit one of these with Game.emit_noise() and listeners connect to
## Game.noise_made and decide for themselves.

## Where the sound came from.
var position := Vector3.ZERO
## How far away it can be heard by an average listener, in metres.
var radius := 5.0
## Who or what made it (may be null).
var source: Node
## "arrow_impact", "hookshot_fire", "wire_place", "wire_step"...
var kind := ""
## 0..1: how alarming it is (a clatter vs. a footstep).
var alarm := 0.5


static func make(p_position: Vector3, p_radius: float, p_source: Node = null, p_kind := "", p_alarm := 0.5) -> NoiseEvent:
	var e := NoiseEvent.new()
	e.position = p_position
	e.radius = p_radius
	e.source = p_source
	e.kind = p_kind
	e.alarm = p_alarm
	return e
