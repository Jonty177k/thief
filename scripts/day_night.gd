extends Node3D
## Sun, moon, sky and fog driven by Game.hour.

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

const DAY_TOP := Color(0.32, 0.46, 0.66)
const DAY_HORIZON := Color(0.70, 0.72, 0.70)
const DUSK_TOP := Color(0.25, 0.20, 0.32)
const DUSK_HORIZON := Color(0.85, 0.45, 0.25)
const NIGHT_TOP := Color(0.02, 0.025, 0.06)
const NIGHT_HORIZON := Color(0.06, 0.07, 0.12)


func _ready() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.06)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_sky_affect = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	add_child(moon)

	Game.hour_changed.connect(_apply)
	_apply(Game.hour)


func _apply(hour: float) -> void:
	var elev := (hour - 6.0) / 12.0 * 180.0  # degrees above the eastern horizon
	var h := Game.sun_height()
	var dl := Game.daylight()
	# How close the sun is to the horizon: 1 at sunrise/sunset.
	var dusk := clampf(1.0 - absf(h) * 3.0, 0.0, 1.0)

	sun.rotation_degrees = Vector3(-elev, 35.0, 0.0)
	sun.light_energy = clampf(h * 2.0, 0.0, 1.0) * 1.3
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.3), dusk)
	sun.visible = h > -0.05

	moon.rotation_degrees = Vector3(-(elev + 180.0), 35.0, 0.0)
	moon.light_energy = clampf(-h * 2.0, 0.0, 1.0) * 0.28
	moon.visible = h < 0.05

	var top := NIGHT_TOP.lerp(DAY_TOP, dl).lerp(DUSK_TOP, dusk * 0.6)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, dl).lerp(DUSK_HORIZON, dusk * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.3)

	env.ambient_light_color = Color(0.22, 0.26, 0.4).lerp(Color(0.62, 0.6, 0.56), dl)
	env.ambient_light_energy = lerpf(0.35, 0.75, dl)
	env.fog_light_color = horizon
	env.fog_density = lerpf(0.011, 0.005, dl)
