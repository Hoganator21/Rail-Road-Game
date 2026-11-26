shader_type spatial;
render_mode cull_disabled;
// Rails: rusty scanned steel on the sides, polished running surface on top.
// The rail mesh marks the running surface with a bright vertex colour.
uniform sampler2D rust : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_n : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying float top;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top = COLOR.r;
}
void fragment() {
	vec2 uv = vec2(wpos.z * 0.45, wpos.y * 3.0 + wpos.x * 0.7);
	vec3 r = texture(rust, uv).rgb;
	float t = step(0.6, top);
	float streak = texture(rust, vec2(wpos.z * 0.08, wpos.x * 2.0)).r;
	vec3 steel = vec3(0.7, 0.69, 0.67) * (0.82 + 0.25 * streak);
	ALBEDO = mix(r * vec3(0.8, 0.68, 0.6), steel, t);
	METALLIC = mix(0.35, 0.95, t);
	ROUGHNESS = mix(0.85, 0.18 + 0.15 * streak, t);
}
