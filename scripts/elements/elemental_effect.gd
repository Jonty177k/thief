class_name ElementalEffect
extends RefCounted
## One elemental effect reaching the world: a fire arrow's flame, a water
## arrow's splash, a plain arrow's knock. Anything that reacts to elements
## has a `receive_element(effect: ElementalEffect) -> bool` method (usually
## a component node such as FlameComponent, Flammable or ArrowSwitch) and
## decides its own response; nothing about torches or crates lives in the
## arrows. Return true if the effect did something.

enum Element { PHYSICAL, FIRE, WATER }

var element := Element.PHYSICAL
## Where it landed, in world space.
var position := Vector3.ZERO
## Who caused it (may be null).
var source: Node
## Receivers within this many metres of `position` are also reached (a
## splash, a burst of flame). 0 reaches only what was hit.
var radius := 0.0
## Free text for feedback and tests: "arrow", "fire_arrow"...
var kind := ""


static func make(p_element: Element, p_position: Vector3, p_source: Node = null, p_radius := 0.0, p_kind := "") -> ElementalEffect:
	var e := ElementalEffect.new()
	e.element = p_element
	e.position = p_position
	e.source = p_source
	e.radius = p_radius
	e.kind = p_kind
	return e


func element_name() -> String:
	return Element.keys()[element].to_lower()


## Every receiver this effect reaches: the ones on (or under) `hit` and its
## ancestors, then any in the "elemental" group within `radius`.
static func receivers(hit: Node, effect: ElementalEffect, tree: SceneTree) -> Array[Node]:
	var found: Array[Node] = []
	var n := hit
	for i in 5:
		if n == null or not is_instance_valid(n):
			break
		if n.has_method("receive_element") and not found.has(n):
			found.append(n)
		for c in n.get_children():
			if c.has_method("receive_element") and not found.has(c):
				found.append(c)
		n = n.get_parent()
	if effect.radius > 0.0:
		for r in tree.get_nodes_in_group("elemental"):
			if found.has(r) or not (r is Node3D):
				continue
			if (r as Node3D).global_position.distance_to(effect.position) <= effect.radius + float(r.get("reach_radius") if r.get("reach_radius") != null else 0.0):
				found.append(r)
	return found


## Apply `effect` to everything it reaches. Returns how many responded.
static func apply(hit: Node, effect: ElementalEffect, tree: SceneTree) -> int:
	var count := 0
	for r in receivers(hit, effect, tree):
		if r.receive_element(effect):
			count += 1
	return count
