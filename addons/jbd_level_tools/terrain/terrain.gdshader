shader_type spatial;
// Four painted layers blended by vertex colour, projected from three sides
// so steep cliffs don't smear. Crunchy nearest-neighbour sampling to match
// the rest of the game. Slopes steeper than `cliff_angle` fade to layer 4
// on their own, so cliffs read as rock without painting them.

render_mode diffuse_lambert, specular_disabled;

uniform vec4 color_0 : source_color = vec4(0.42, 0.38, 0.34, 1.0);
uniform vec4 color_1 : source_color = vec4(0.50, 0.47, 0.42, 1.0);
uniform vec4 color_2 : source_color = vec4(0.82, 0.78, 0.68, 1.0);
uniform vec4 color_3 : source_color = vec4(0.30, 0.27, 0.25, 1.0);
uniform sampler2D texture_0 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D texture_1 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D texture_2 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D texture_3 : source_color, filter_nearest_mipmap, repeat_enable;
uniform float uv_scale = 0.25;
// Degrees. 90 turns the automatic cliff layer off.
uniform float cliff_angle = 50.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 w) {
	vec3 x = texture(tex, p.zy).rgb;
	vec3 y = texture(tex, p.xz).rgb;
	vec3 z = texture(tex, p.xy).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos * uv_scale;
	vec4 weights = COLOR;
	float steep = 1.0 - smoothstep(cos(radians(cliff_angle + 6.0)), cos(radians(cliff_angle - 6.0)), world_normal.y);
	weights = mix(weights, vec4(0.0, 0.0, 0.0, 1.0), steep);
	weights /= max(weights.r + weights.g + weights.b + weights.a, 0.0001);
	vec3 c = triplanar(texture_0, p, w) * color_0.rgb * weights.r
		+ triplanar(texture_1, p, w) * color_1.rgb * weights.g
		+ triplanar(texture_2, p, w) * color_2.rgb * weights.b
		+ triplanar(texture_3, p, w) * color_3.rgb * weights.a;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
