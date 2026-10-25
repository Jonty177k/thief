extends Node
## Global game state (autoloaded as `Game`): the clock, the checkpoint,
## and shared helpers for daylight and night.

signal hour_changed(hour: float)

## One full day/night cycle in real seconds.
const DAY_LENGTH_SECONDS := 600.0
const MORNING_HOUR := 6.5
const EVENING_HOUR := 19.5

var hour := 8.0
var day := 1
var clock_running := true

var checkpoint_position := Vector3(0, 1, 10)
var checkpoint_name := "Tailbone Fire"


func _process(delta: float) -> void:
	if not clock_running:
		return
	set_hour(hour + delta * 24.0 / DAY_LENGTH_SECONDS)


func set_hour(h: float) -> void:
	if h >= 24.0:
		day += int(h / 24.0)
	hour = fposmod(h, 24.0)
	hour_changed.emit(hour)


## Advance the clock forward to the next time the clock reads `target`.
func rest_until(target: float) -> void:
	var delta_h := fposmod(target - hour, 24.0)
	if delta_h < 0.01:
		delta_h = 24.0
	set_hour(hour + delta_h)


## Sine of the sun's elevation: 1 at noon, 0 at 6:00 and 18:00, -1 at midnight.
func sun_height() -> float:
	return sin((hour - 6.0) / 12.0 * PI)


## 0 in deep night, 1 at noon. Drives how visible Jeffrey is.
func daylight() -> float:
	return clampf(sun_height() * 1.5 + 0.25, 0.0, 1.0)


func is_night() -> bool:
	return hour >= EVENING_HOUR - 0.25 or hour < 5.25


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "Day %d  %02d:%02d  %s" % [day, h, m, "Night" if is_night() else "Day"]
