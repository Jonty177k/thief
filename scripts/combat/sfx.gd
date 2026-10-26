class_name Sfx
extends RefCounted
## Placeholder sounds, synthesised once at startup so there are no audio
## files to manage yet. Swap for real samples later.

static var _cache := {}


## A short metallic clank: a shield taking a blow.
static func clank() -> AudioStreamWAV:
	return _synth("clank", func(t: float) -> float:
		var env := exp(-t * 18.0)
		return (sin(TAU * 523.0 * t) * 0.5 + sin(TAU * 1371.0 * t) * 0.35 + sin(TAU * 2253.0 * t) * 0.25 + randf_range(-0.3, 0.3) * exp(-t * 60.0)) * env, 0.35)


## A dull thud: the sword biting into something.
static func thud() -> AudioStreamWAV:
	return _synth("thud", func(t: float) -> float:
		var env := exp(-t * 25.0)
		return (sin(TAU * (110.0 - 60.0 * t) * t) * 0.8 + randf_range(-0.4, 0.4) * exp(-t * 40.0)) * env, 0.25)


## Air rushing past the blade.
static func whoosh() -> AudioStreamWAV:
	return _synth("whoosh", func(t: float) -> float:
		var env := sin(clampf(t / 0.18, 0.0, 1.0) * PI)
		return randf_range(-1.0, 1.0) * env * 0.25, 0.18)


## Blade on stone.
static func scrape() -> AudioStreamWAV:
	return _synth("scrape", func(t: float) -> float:
		var env := exp(-t * 30.0)
		return (sin(TAU * 1800.0 * t) * 0.3 + randf_range(-0.5, 0.5)) * env * 0.6, 0.2)


## A low growl: an enemy winding up a blow.
static func grunt() -> AudioStreamWAV:
	return _synth("grunt", func(t: float) -> float:
		var env := sin(clampf(t / 0.3, 0.0, 1.0) * PI)
		return (sin(TAU * (85.0 + 20.0 * t) * t) * 0.6 + sin(TAU * 170.0 * t) * 0.2 + randf_range(-0.25, 0.25)) * env * 0.7, 0.3)


## A creak of drawing bowstring.
static func creak() -> AudioStreamWAV:
	return _synth("creak", func(t: float) -> float:
		var env := sin(clampf(t / 0.5, 0.0, 1.0) * PI) * 0.35
		var tick := 1.0 if fmod(t * 38.0, 1.0) < 0.15 else 0.2
		return (sin(TAU * 230.0 * t) * 0.5 + randf_range(-0.5, 0.5)) * env * tick, 0.5)


## The bowstring snapping forward.
static func twang() -> AudioStreamWAV:
	return _synth("twang", func(t: float) -> float:
		var env := exp(-t * 14.0)
		return (sin(TAU * (180.0 + 40.0 * exp(-t * 30.0)) * t) * 0.7 + randf_range(-0.3, 0.3) * exp(-t * 80.0)) * env, 0.35)


## An arrow biting into wood or earth.
static func arrow_thunk() -> AudioStreamWAV:
	return _synth("arrow_thunk", func(t: float) -> float:
		var env := exp(-t * 45.0)
		return (sin(TAU * (240.0 - 120.0 * t) * t) * 0.6 + randf_range(-0.5, 0.5) * exp(-t * 90.0)) * env * 0.8, 0.15)


## Fire catching: a soft whoomp and crackle.
static func ignite() -> AudioStreamWAV:
	return _synth("ignite", func(t: float) -> float:
		var env := sin(clampf(t / 0.6, 0.0, 1.0) * PI)
		var crackle := randf_range(-1.0, 1.0) if randf() < 0.04 else 0.0
		return (randf_range(-0.4, 0.4) * env + sin(TAU * 60.0 * t) * 0.3 * exp(-t * 6.0) + crackle * 0.5) * 0.7, 0.6)


## Water on flame: a hiss.
static func hiss() -> AudioStreamWAV:
	return _synth("hiss", func(t: float) -> float:
		var env := exp(-t * 3.5) * minf(t / 0.03, 1.0)
		return randf_range(-1.0, 1.0) * env * 0.35, 0.7)


## A quiet splash: a water arrow landing.
static func splash() -> AudioStreamWAV:
	return _synth("splash", func(t: float) -> float:
		var env := exp(-t * 12.0)
		var bloop := sin(TAU * (500.0 + 900.0 * t) * t) * exp(-t * 30.0) * 0.3
		return (randf_range(-0.6, 0.6) * env + bloop) * 0.5, 0.3)


static func _synth(key: String, wave: Callable, length: float) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var rate := 22050
	var n := int(length * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(wave.call(float(i) / rate), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	_cache[key] = s
	return s
