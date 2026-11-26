shader_type spatial;
render_mode cull_disabled;
// Ground: gravelly, weedy right-of-way near the track blending into grass fields,
// with two texture scales mixed to break up tiling.
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float use_vertex_color = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uvg = wpos.xz / 4.5;
	vec2 uvp = wpos.xz / 3.2;
	float lowf = texture(grass, wpos.xz / 131.0).g;
	float edge = smoothstep(6.5, 13.0, abs(wpos.x) + (lowf - 0.35) * 10.0);
	vec3 ga = mix(texture(grass, uvg).rgb, texture(grass, uvg * 0.23 + 0.31).rgb, 0.4);
	ga *= 0.82 + 0.4 * lowf;
	vec3 pa = mix(texture(path, uvp).rgb, texture(path, uvp * 0.29 + 0.13).rgb, 0.3);
	vec3 vc = mix(vec3(1.0), COLOR.rgb, use_vertex_color);
	ALBEDO = mix(pa, ga, edge) * vc;
	NORMAL_MAP = mix(texture(path_n, uvp).rgb, texture(grass_n, uvg).rgb, edge);
	ROUGHNESS = 0.96;
}
