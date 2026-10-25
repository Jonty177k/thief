class_name DamageInfo
extends RefCounted
## One blow, passed to whatever it hits. Anything that can be hurt has a
## `receive_damage(info: DamageInfo)` method; the receiver fills in
## `blocked` (and may change `amount`) so the attacker can react.

## Damage before any blocking.
var amount := 0.0
## Who struck (may be null for falls and hazards).
var source: Node3D
## Where the blow came from, in world space.
var origin := Vector3.ZERO
## Horizontal direction the blow travels: from the attacker toward the target.
var direction := Vector3.FORWARD
## Shove in m/s applied along `direction`.
var knockback := 0.0
## "light", "heavy", "enemy", "fall"... free text for feedback and tests.
var kind := ""
## Set by the receiver: true when a shield caught it.
var blocked := false


static func make(p_amount: float, p_source: Node3D, p_origin: Vector3, p_target: Vector3, p_knockback := 0.0, p_kind := "") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source = p_source
	info.origin = p_origin
	var d := p_target - p_origin
	d.y = 0.0
	info.direction = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	info.knockback = p_knockback
	info.kind = p_kind
	return info


## The node that takes damage for `hit` (a collider or anything under it):
## the first ancestor, up to four levels, with `receive_damage`.
static func find_receiver(hit: Node) -> Node:
	var n := hit
	for i in 5:
		if n == null:
			return null
		if n.has_method("receive_damage"):
			return n
		n = n.get_parent()
	return null


## Deliver `info` to whatever owns `hit`. Returns the receiver, or null.
static func deliver(hit: Node, info: DamageInfo) -> Node:
	var r := find_receiver(hit)
	if r:
		r.receive_damage(info)
	return r
