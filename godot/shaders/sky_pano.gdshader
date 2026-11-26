shader_type sky;
// Real HDRI sky. yaw turns the panorama so the sun sits where the game wants it.
uniform sampler2D pano : source_color, filter_linear, repeat_enable;
uniform float yaw = 0.0;
uniform float exposure = 1.0;
void sky() {
	vec3 d = EYEDIR;
	float c = cos(yaw);
	float s = sin(yaw);
	vec3 r = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	float u = atan(r.x, -r.z) / (2.0 * PI) + 0.5;
	float v = acos(clamp(r.y, -1.0, 1.0)) / PI;
	vec3 col = texture(pano, vec2(u, min(v, 0.499))).rgb;
	// below the horizon fade to a hazy ground colour instead of the mirrored clouds
	col = mix(col, vec3(0.42, 0.44, 0.38) * exposure * 0.6, smoothstep(0.0, -0.08, d.y));
	COLOR = col * exposure;
}
