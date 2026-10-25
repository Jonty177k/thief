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
