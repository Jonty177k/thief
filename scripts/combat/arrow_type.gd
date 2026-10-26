class_name ArrowType
extends Resource
## One kind of arrow: plain, or fused with an element. The bow holds a list
## of these; edit them in the Inspector or save them as .tres files.

@export var name := "Arrow"
## The element it carries (PHYSICAL for a plain arrow).
@export var element := ElementalEffect.Element.PHYSICAL
## Damage at full draw, as a fraction of the bow's Arrow Damage.
@export_range(0.0, 2.0, 0.05) var damage_multiplier := 1.0
## The element also reaches receivers this close to the impact (metres).
@export var effect_radius := 0.0
## Fletching and tip colour.
@export var color := Color(0.75, 0.7, 0.6)
## A small light on the arrow in flight (fire arrows).
@export var flight_light := false
## Seconds a fire arrow keeps burning where it lands (0 for none).
@export var linger_flame_time := 0.0
## How far its impact can be heard, in metres (see NoiseEvent).
@export var impact_noise_radius := 6.0
## Which inventory charge it uses besides an arrow: "", "fire" or "water".
@export var charge := ""


static func standard() -> ArrowType:
	var t := ArrowType.new()
	t.name = "Arrow"
	return t


static func fire() -> ArrowType:
	var t := ArrowType.new()
	t.name = "Fire arrow"
	t.element = ElementalEffect.Element.FIRE
	t.effect_radius = 0.7
	t.color = Color(1.0, 0.45, 0.12)
	t.flight_light = true
	t.linger_flame_time = 5.0
	t.impact_noise_radius = 5.0
	t.charge = "fire"
	return t


static func water() -> ArrowType:
	var t := ArrowType.new()
	t.name = "Water arrow"
	t.element = ElementalEffect.Element.WATER
	t.damage_multiplier = 0.5
	t.effect_radius = 1.0
	t.color = Color(0.35, 0.6, 0.95)
	t.impact_noise_radius = 2.0
	t.charge = "water"
	return t
