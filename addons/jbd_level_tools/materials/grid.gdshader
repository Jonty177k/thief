shader_type spatial;
// Greybox grid: a line every metre and a stronger one every 4 m, in world
// space, so distances read at a glance.

uniform vec4 base_color : source_color = vec4(0.3, 0.3, 0.32, 1.0);
uniform vec4 line_color : source_color = vec4(0.2, 0.2, 0.22, 1.0);
uniform vec4 major_color : source_color = vec4(0.45, 0.36, 0.22, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

float grid(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing + 0.5) - 0.5) * spacing;
	return 1.0 - step(width, min(g.x, g.y));
}

void fragment() {
	vec2 p = world_normal.y > 0.5 ? world_pos.xz : (world_normal.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec3 c = base_color.rgb;
	c = mix(c, line_color.rgb, grid(p, 1.0, 0.02));
	c = mix(c, major_color.rgb, grid(p, 4.0, 0.035));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
