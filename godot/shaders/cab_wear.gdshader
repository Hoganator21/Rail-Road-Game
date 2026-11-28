shader_type spatial;
// Cab surfaces: original albedo/normal/roughness on UV1, plus baked occlusion and wear on UV2.
// wear map: R = worn edges, G = grime in corners/crevices, B = large blotchy variation.
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform float normal_strength = 1.0;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform float roughness = 0.7;
uniform float metallic = 0.0;
uniform sampler2D ao_tex : hint_default_white, filter_linear;
uniform sampler2D wear_tex : hint_default_black, filter_linear;
uniform float edge_amount = 0.6;     // how much edges are rubbed through / polished
uniform float grime_amount = 0.6;    // how dirty corners and crevices get
uniform vec3 worn_tint = vec3(1.35); // edge colour relative to the base (lighter = paint rubbed thin)
uniform float worn_metal = 0.0;      // 1 = bare metal shows through on worn edges
uniform float worn_floor = 0.0;      // minimum brightness of a worn edge (dark parts rub to grey)

void fragment() {
	vec4 base = texture(albedo_tex, UV) * albedo_color;
	vec3 w = texture(wear_tex, UV2).rgb;
	float blotch = smoothstep(0.3, 0.75, w.b);
	float edge = clamp(smoothstep(0.06, 0.45, w.r) * (0.35 + 1.0 * blotch), 0.0, 1.0) * edge_amount;
	float grime = clamp(smoothstep(0.4, 0.98, w.g) * (0.5 + 0.8 * blotch), 0.0, 1.0) * grime_amount;
	vec3 col = base.rgb;
	col = mix(col, col * 0.42 + vec3(0.035, 0.028, 0.02), grime);
	col = mix(col, clamp(max(col * worn_tint, vec3(worn_floor)), 0.0, 1.0), edge);
	ALBEDO = col;
	float r = roughness * texture(rough_tex, UV).g;
	// hand-polished patches on top surfaces (desk tops, armrests): shinier and a little lighter
	float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	float polish = smoothstep(0.62, 0.8, w.b) * smoothstep(0.7, 0.95, up) * edge_amount;
	ALBEDO = mix(ALBEDO, clamp(max(ALBEDO * 1.5, vec3(worn_floor * 0.8)), 0.0, 1.0), polish * 0.6);
	ROUGHNESS = clamp(r + grime * 0.12 - edge * 0.3 - polish * 0.25, 0.05, 1.0);
	METALLIC = clamp(metallic + edge * worn_metal, 0.0, 1.0);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	AO = texture(ao_tex, UV2).r;
	AO_LIGHT_AFFECT = 0.8;
}
