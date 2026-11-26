extends RefCounted
## Visual building blocks, ported from the v11 web version (Gemini + Hoganator21):
## textures, real rail profile, ballast section, wood ties + tie plates, rolling
## ground, billboard trees, freight cars, industries, sky and lighting.
## Gameplay never depends on anything in here.

const G := 1.435            # track gauge (rail centre to rail centre, approx)
const TIE_TOP := 0.18
const RAIL_BASE := 0.195
const RAIL_H := 0.185
const RAIL_TOP := 0.38
const TIE_SP := 0.495
const RAIL_PROFILE := [Vector2(-0.076, 0.0), Vector2(0.076, 0.0), Vector2(0.076, 0.012), Vector2(0.014, 0.034),
	Vector2(0.0085, 0.135), Vector2(0.036, 0.148), Vector2(0.036, 0.185), Vector2(-0.036, 0.185),
	Vector2(-0.036, 0.148), Vector2(-0.0085, 0.135), Vector2(-0.014, 0.034), Vector2(-0.076, 0.012)]
const BALLAST := [Vector2(-3.1, -0.46), Vector2(-1.85, 0.135), Vector2(1.85, 0.135), Vector2(3.1, -0.46)]
const STEEL := Color(0.62, 0.62, 0.64)
const RUST := Color(0.2, 0.11, 0.07)
const HEADSIDE := Color(0.26, 0.17, 0.11)
const POINT_STEEL := Color(0.78, 0.78, 0.8)
const POINT_SIDE := Color(0.5, 0.48, 0.46)
const CAR_LEN := {"box": 16.2, "hop": 17.5, "tank": 17.2}
const CAR_COLORS := {
	"box": [Color("6b2d1e"), Color("7a3b22"), Color("3d4a57"), Color("8b6b3d"), Color("2e4a3a")],
	"hop": [Color("9a8f7a"), Color("5b5f61"), Color("b3aa98"), Color("7d8188")],
	"tank": [Color("1d1e20"), Color("2b2c2f"), Color("d8d6d0")],
}
const INDUSTRIES := [["Carolina Feed & Grain", "silos", "hop"], ["Southern Lumber", "lumber", "box"],
	["Tri-County Fertilizer", "warehouse", "hop"], ["Piedmont Plastics", "warehouse", "hop"],
	["Eastline Steel", "warehouse", "box"], ["Coastal Paper", "warehouse", "box"], ["Tidewater Fuel", "tanks", "tank"]]

var mats: Dictionary = {}
var meshes: Dictionary = {}
var renderer: String = ""
var hi_end: bool = false
var rng := RandomNumberGenerator.new()

# ================================================================ setup
func setup() -> void:
	var key := "rendering/renderer/rendering_method"
	if OS.has_feature("mobile"):
		key += ".mobile"
	renderer = str(ProjectSettings.get_setting(key, "forward_plus"))
	if DisplayServer.get_name() == "headless":
		renderer = "gl_compatibility"
	hi_end = renderer == "forward_plus"
	rng.randomize()
	_make_materials()
	_make_meshes()

func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D

func mat(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func shared(key: String, c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	if not mats.has(key):
		mats[key] = mat(c, rough, metal)
	return mats[key]

func _make_materials() -> void:
	var rail := ShaderMaterial.new()
	rail.shader = load("res://shaders/rail.gdshader")
	rail.set_shader_parameter("rust", _tex("res://textures/pbr/rust_coarse_01_diff.jpg"))
	rail.set_shader_parameter("rust_n", _tex("res://textures/pbr/rust_coarse_01_nor.jpg"))
	mats["rail"] = rail
	var ballast := StandardMaterial3D.new()
	ballast.albedo_texture = _tex("res://textures/pbr/rocks_ground_01_diff.jpg")
	ballast.albedo_color = Color(0.92, 0.92, 0.95)
	ballast.normal_enabled = true
	ballast.normal_texture = _tex("res://textures/pbr/rocks_ground_01_nor.jpg")
	ballast.normal_scale = 1.4
	ballast.roughness_texture = _tex("res://textures/pbr/rocks_ground_01_rough.jpg")
	ballast.roughness = 1.0
	ballast.uv1_scale = Vector3(0.8, 0.8, 1.0)
	ballast.cull_mode = BaseMaterial3D.CULL_DISABLED
	ballast.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats["ballast"] = ballast
	var tie := StandardMaterial3D.new()
	tie.albedo_texture = _tex("res://textures/pbr/rough_wood_diff.jpg")
	tie.albedo_color = Color(0.5, 0.42, 0.36)
	tie.normal_enabled = true
	tie.normal_texture = _tex("res://textures/pbr/rough_wood_nor.jpg")
	tie.normal_scale = 1.5
	tie.roughness_texture = _tex("res://textures/pbr/rough_wood_rough.jpg")
	tie.uv1_triplanar = true
	tie.uv1_world_triplanar = true
	tie.uv1_scale = Vector3(0.55, 0.55, 0.55)
	tie.vertex_color_use_as_albedo = true
	tie.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats["tie"] = tie
	mats["plate"] = mat(Color("3b3029"), 0.78, 0.35)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/ground.gdshader")
	ground.set_shader_parameter("grass", _tex("res://textures/pbr/grass_field_diff.jpg"))
	ground.set_shader_parameter("grass_n", _tex("res://textures/pbr/grass_field_nor.jpg"))
	ground.set_shader_parameter("path", _tex("res://textures/pbr/grass_path_2_diff.jpg"))
	ground.set_shader_parameter("path_n", _tex("res://textures/pbr/grass_path_2_nor.jpg"))
	mats["ground"] = ground
	var far: ShaderMaterial = ground.duplicate()
	far.set_shader_parameter("use_vertex_color", 0.0)
	mats["far_ground"] = far
	var road := StandardMaterial3D.new()
	road.albedo_texture = _tex("res://textures/road.png")
	road.normal_enabled = true
	road.normal_texture = _tex("res://textures/pbr/asphalt_02_nor.jpg")
	road.roughness_texture = _tex("res://textures/pbr/asphalt_02_rough.jpg")
	road.roughness = 1.0
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats["road"] = road
	for k in ["oak", "oak2", "pine", "bush"]:
		var lm := StandardMaterial3D.new()
		lm.albedo_texture = _tex("res://textures/leaf_%s.png" % k)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		lm.alpha_scissor_threshold = 0.45
		lm.cull_mode = BaseMaterial3D.CULL_DISABLED
		lm.vertex_color_use_as_albedo = true
		lm.roughness = 1.0
		lm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if k == "bush":
			lm.albedo_color = Color(0.62, 0.66, 0.55)
		mats["leaf_" + k] = lm
	mats["steel_dark"] = mat(Color("262422"), 0.72, 0.35)
	mats["yellow"] = mat(Color("e0b51c"), 0.52)
	mats["white"] = mat(Color("eeeeea"), 0.6)
	mats["black"] = mat(Color("111214"), 0.6)
	mats["pole"] = mat(Color("5b4a3a"), 1.0)
	mats["roof"] = mat(Color("55585c"), 0.7, 0.3)
	mats["door"] = mat(Color("6f6a5c"))
	mats["dock"] = mat(Color("8c8c86"))
	var conc := StandardMaterial3D.new()
	conc.albedo_texture = _tex("res://textures/pbr/concrete_floor_01_diff.jpg")
	conc.normal_enabled = true
	conc.normal_texture = _tex("res://textures/pbr/concrete_floor_01_nor.jpg")
	conc.roughness_texture = _tex("res://textures/pbr/concrete_floor_01_rough.jpg")
	conc.uv1_triplanar = true
	conc.uv1_scale = Vector3(0.4, 0.4, 0.4)
	mats["concrete"] = conc
	mats["silo"] = mat(Color("c9c3b4"), 0.9)
	mats["silo_base"] = mat(Color("8a5a2b"))
	mats["tank_white"] = mat(Color("e8e6df"), 0.4, 0.3)
	mats["tank_stand"] = mat(Color("777777"))
	mats["lumber"] = mat(Color("c8a06a"), 0.9)
	mats["lumber_shed"] = mat(Color("7f6d5a"), 0.9)
	mats["stand"] = mat(Color("2c2c2c"), 0.7, 0.4)
	var red := mat(Color(0.9, 0.05, 0.05))
	red.emission_enabled = true
	red.emission = Color(0.7, 0.0, 0.0)
	mats["redlamp"] = red

func _make_meshes() -> void:
	# crossed-quad billboard used for every tree and bush (same trick as v11)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot in [0.0, PI / 2.0]:
		var b := Basis(Vector3.UP, rot)
		var c := [b * Vector3(-0.5, 0, 0), b * Vector3(0.5, 0, 0), b * Vector3(0.5, 1, 0), b * Vector3(-0.5, 1, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(c[i])
	meshes["cross"] = st.commit()
	var tie := BoxMesh.new()
	tie.size = Vector3(1.0, TIE_TOP, 0.23)
	meshes["tie"] = tie
	var plate := BoxMesh.new()
	plate.size = Vector3(0.36, 0.016, 0.19)
	meshes["plate"] = plate
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 10.0
	pole.radial_segments = 8
	meshes["pole"] = pole
	meshes["hopper"] = _hopper_mesh()

# ================================================================ environment
const SKY_SHADER := """
shader_type sky;
uniform vec3 zenith : source_color = vec3(0.29, 0.5, 0.78);
uniform vec3 horizon : source_color = vec3(0.77, 0.84, 0.91);
uniform vec3 ground : source_color = vec3(0.54, 0.58, 0.45);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.92, 0.75);
void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = h > 0.0 ? mix(horizon, zenith, pow(h, 0.45)) : mix(horizon, ground, clamp(-h * 6.0, 0.0, 1.0));
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += sun_tint * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.25);
	COLOR = col;
}
"""

var env: Environment
var sun: DirectionalLight3D
var quality: int = 2            # 0 low, 1 medium, 2 high, 3 ultra
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
const SKY_YAW := PI
const PANO_SUN := Vector3(0.376, 0.743, -0.553)   # sun direction measured from the HDRI

func make_environment(parent: Node) -> DirectionalLight3D:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_pano.gdshader")
	sm.set_shader_parameter("pano", load("res://textures/pbr/sky_partly_cloudy.hdr"))
	sm.set_shader_parameter("yaw", SKY_YAW)
	sm.set_shader_parameter("exposure", 0.33)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.8, 0.88)
	env.fog_density = 0.00035
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	# sun lined up with the sun in the photographed sky
	var c := cos(SKY_YAW)
	var sn := sin(SKY_YAW)
	var sun_dir := Vector3(c * PANO_SUN.x + sn * PANO_SUN.z, PANO_SUN.y, -sn * PANO_SUN.x + c * PANO_SUN.z).normalized()
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.2
	parent.add_child(sun)
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	apply_quality(quality)
	return sun

## Graphics quality levels. Phones default to MEDIUM, PCs to HIGH.
func apply_quality(q: int) -> void:
	quality = clampi(q, 0, 3)
	if env == null:
		return
	var vp: Viewport = null
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		vp = (ml as SceneTree).root
	var fwd := renderer == "forward_plus"
	var mobile_r := renderer == "mobile"
	env.glow_enabled = quality >= 1 and renderer != "gl_compatibility"
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = fwd and quality >= 2
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssil_enabled = fwd and quality >= 3
	env.ssil_intensity = 0.6
	env.sdfgi_enabled = fwd and quality >= 3
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.volumetric_fog_enabled = fwd and quality >= 3
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color(0.85, 0.88, 0.92)
	env.volumetric_fog_length = 120.0
	if sun:
		sun.directional_shadow_max_distance = [70.0, 110.0, 180.0, 260.0][quality]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.shadow_enabled = quality >= 1 or not mobile_r
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][quality])
	if vp:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if quality == 0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.75 if quality == 0 else 1.0

func foliage_density() -> float:
	return [0.45, 0.75, 1.0, 1.3][quality]

# ================================================================ track pieces
## Order for a quad's two triangles so the front face points along nrm.
func quad_order(v: Array, nrm: Vector3) -> Array:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	if (c - a).cross(b - a).dot(nrm) >= 0.0:
		return [0, 1, 2, 0, 2, 3]
	return [0, 2, 1, 0, 3, 2]

func _outward(profile: Array) -> float:
	var area := 0.0
	for k in profile.size():
		var p: Vector2 = profile[k]
		var q: Vector2 = profile[(k + 1) % profile.size()]
		area += p.x * q.y - q.x * p.y
	return 1.0 if area > 0.0 else -1.0

## Sweep a closed 2D profile (x lateral, y up) along a centre line given as
## Vector2(x_offset, d) points. colors: 0 none, 1 rail, 2 point rail.
func sweep(st: SurfaceTool, profile: Array, line: PackedVector2Array, y0: float, colors: int = 0, uv_scale: float = 0.0) -> void:
	var n := profile.size()
	var sgn := _outward(profile)
	var perim: Array = [0.0]
	for k in n:
		perim.append(perim[k] + (profile[(k + 1) % n] - profile[k]).length())
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		for k in n:
			var p: Vector2 = profile[k]
			var q: Vector2 = profile[(k + 1) % n]
			var nrm := Vector3((q.y - p.y) * sgn, -(q.x - p.x) * sgn, 0.0).normalized()
			var v := [Vector3(a.x + p.x, y0 + p.y, -a.y), Vector3(a.x + q.x, y0 + q.y, -a.y),
				Vector3(b.x + q.x, y0 + q.y, -b.y), Vector3(b.x + p.x, y0 + p.y, -b.y)]
			var uvs := [Vector2(perim[k], a.y), Vector2(perim[k + 1], a.y), Vector2(perim[k + 1], b.y), Vector2(perim[k], b.y)]
			var col := Color.WHITE
			if colors > 0:
				var top := p.y >= RAIL_H - 1e-4 and q.y >= RAIL_H - 1e-4
				var head := p.y > 0.147 and q.y > 0.147
				if colors == 1:
					col = STEEL if top else (HEADSIDE if head else RUST)
				else:
					col = POINT_STEEL if top else (POINT_SIDE if head else RUST)
			for j in quad_order(v, nrm):
				st.set_normal(nrm)
				st.set_color(col)
				if uv_scale > 0.0:
					st.set_uv(uvs[j] * uv_scale)
				st.add_vertex(v[j])

func rail_line(st: SurfaceTool, line: PackedVector2Array) -> void:
	sweep(st, RAIL_PROFILE, line, RAIL_BASE, 1)

func ballast_line(st: SurfaceTool, line: PackedVector2Array, dy: float = 0.0) -> void:
	sweep(st, BALLAST, line, dy, 0, 0.5)

func point_rail_mesh(a: Vector2, b: Vector2) -> ArrayMesh:
	# a and b are Vector2(x, d); the point rail tapers to a thin tip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	sweep(st, RAIL_PROFILE, PackedVector2Array([a, b]), RAIL_BASE + 0.003, 2)
	return st.commit()

func tie_multimesh(list: Array) -> MultiMeshInstance3D:
	# list of [Vector3 position (y ignored), rot_y, length]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = meshes["tie"]
	mm.instance_count = list.size()
	for i in list.size():
		var e: Array = list[i]
		var pos: Vector3 = e[0]
		var b := Basis(Vector3.UP, e[1]).scaled(Vector3(e[2], 1.0, 1.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pos.x, TIE_TOP * 0.5, pos.z)))
		var v := 0.75 + rng.randf() * 0.4
		mm.set_instance_color(i, Color(v, v * (0.95 + rng.randf() * 0.08), v * 0.92))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mats["tie"]
	return mi

func plate_multimesh(list: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = meshes["plate"]
	mm.instance_count = list.size()
	for i in list.size():
		var e: Array = list[i]
		var pos: Vector3 = e[0]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, e[1]), Vector3(pos.x, TIE_TOP + 0.008, pos.z)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mats["plate"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ================================================================ ground
func g_noise(x: float, z: float) -> float:
	return sin(x * 0.013 + sin(z * 0.007) * 2.0) * cos(z * 0.011 - x * 0.004) + 0.5 * sin(x * 0.041 + z * 0.037)

func ground_h(x: float, z: float) -> float:
	var d := absf(x) - 75.0
	return -0.45 + (minf(d, 600.0) * 0.035 * (1.2 + g_noise(x * 0.5, z * 0.5)) if d > 0.0 else 0.0)

func ground_strip(d0: float, d1: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array = []
	var x := -700.0
	while x <= 700.0:
		xs.append(x)
		x += 25.0
	var zs: Array = []
	var nz := maxi(2, int(ceil((d1 - d0) / 25.0)))
	for i in nz + 1:
		zs.append(-lerpf(d0, d1, float(i) / nz))
	for iz in zs.size() - 1:
		for ix in xs.size() - 1:
			var quad := [Vector2(xs[ix], zs[iz]), Vector2(xs[ix + 1], zs[iz]), Vector2(xs[ix + 1], zs[iz + 1]), Vector2(xs[ix], zs[iz + 1])]
			for j in [0, 2, 1, 0, 3, 2]:
				var p: Vector2 = quad[j]
				var h := ground_h(p.x, p.y)
				var e := 1.0
				var nrm := Vector3(ground_h(p.x - e, p.y) - ground_h(p.x + e, p.y), 2.0 * e, ground_h(p.x, p.y - e) - ground_h(p.x, p.y + e)).normalized()
				var n := g_noise(p.x, p.y)
				st.set_normal(nrm)
				st.set_color(Color(0.92 + 0.08 * n, 0.92 + 0.06 * n, 0.85 + 0.05 * n))
				st.set_uv(Vector2(p.x * 0.1, p.y * 0.1))
				st.add_vertex(Vector3(p.x, h, p.y))
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["ground"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func far_ground() -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mats["far_ground"]
	mi.position.y = -3.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func road_strip(x: float, d0: float, d1: float, width: float = 8.0) -> MeshInstance3D:
	# a road running along the track direction (x fixed); use rotate for crossings
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := [Vector3(x - width / 2, 0, -d0), Vector3(x + width / 2, 0, -d0), Vector3(x + width / 2, 0, -d1), Vector3(x - width / 2, 0, -d1)]
	var len := d1 - d0
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, len / 12.0), Vector2(0, len / 12.0)]
	for j in quad_order(c, Vector3.UP):
		st.set_normal(Vector3.UP)
		st.set_uv(uv[j])
		st.add_vertex(c[j])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["road"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ================================================================ foliage
## Scatter v11-style billboard trees and bushes over [d0, d1].
## blocked(x, d) -> bool keeps them off tracks and buildings.
func foliage(parent: Node3D, d0: float, d1: float, blocked: Callable, dens: float = 1.0, srng: RandomNumberGenerator = null) -> void:
	var r := srng if srng != null else rng
	var length := d1 - d0
	var kinds := [["oak", 0.32], ["oak2", 0.32], ["pine", 0.3], ["bush", 0.9]]
	for kd in kinds:
		var k: String = kd[0]
		var want := int(round(length * float(kd[1]) * dens))
		var xf: Array = []
		var tries := 0
		while xf.size() < want and tries < want * 2:
			tries += 1
			var side := -1.0 if r.randf() < 0.5 else 1.0
			var d := d0 + r.randf() * length
			var x: float
			if k == "bush":
				x = side * (11.5 + r.randf() * 18.0)
			else:
				x = side * (22.0 + pow(r.randf(), 1.4) * 360.0)
			if blocked.call(x, d):
				continue
			var h: float
			var w: float
			if k == "bush":
				h = 0.6 + r.randf() * 1.5
				w = h * 1.5
			else:
				h = (10.0 if k == "pine" else 8.0) + r.randf() * 10.0
				w = h * (0.55 if k == "pine" else 0.9 + r.randf() * 0.3)
			var y := -0.5 if k == "bush" else ground_h(x, -d) - 0.2
			var b := Basis(Vector3.UP, r.randf() * 3.0).scaled(Vector3(w, h, w))
			var v := 0.78 + r.randf() * 0.38
			xf.append([Transform3D(b, Vector3(x, y, -d)), Color(v, v, v * 0.93)])
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes["cross"]
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i][0])
			mm.set_instance_color(i, xf[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mats["leaf_" + k]
		if k == "bush" or not hi_end:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

func far_tree_ring() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = meshes["cross"]
	mm.instance_count = 700
	for i in 700:
		var ang := rng.randf() * TAU
		var rad := 800.0 + rng.randf() * 500.0
		var x := cos(ang) * rad
		var z := sin(ang) * rad
		var h := 16.0 + rng.randf() * 10.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(h * 1.2, h, h * 1.2)), Vector3(x, 10.0 if absf(x) > 70.0 else -1.0, z)))
		mm.set_instance_color(i, Color(0.85, 0.85, 0.8))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mats["leaf_oak"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ================================================================ simple shapes
func box(parent: Node, size: Vector3, pos: Vector3, m: Material, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

# ================================================================ rolling stock
func _hopper_mesh() -> ArrayMesh:
	# v11 covered-hopper cross-section: flat sides, curved roof, extruded 16.5 m
	var prof := PackedVector2Array([Vector2(-1.55, 0.9), Vector2(1.55, 0.9), Vector2(1.55, 3.9)])
	for i in range(1, 8):
		var t := float(i) / 8.0
		var p0 := Vector2(1.55, 3.9)
		var c := Vector2(0.0, 4.5)
		var p1 := Vector2(-1.55, 3.9)
		prof.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))
	prof.append(Vector2(-1.55, 3.9))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arr: Array = []
	for p in prof:
		arr.append(p)
	sweep(st, arr, PackedVector2Array([Vector2(0, -8.25), Vector2(0, 8.25)]), 0.0)
	var tri := Geometry2D.triangulate_polygon(prof)
	for zc in [-8.25, 8.25]:
		for idx in tri:
			st.set_normal(Vector3(0, 0, signf(zc)))
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(prof[idx].x, prof[idx].y, zc))
	return st.commit()

func freight_car(kind: String, color: Color, detailed: bool = true) -> Node3D:
	var g := Node3D.new()
	var length: float = CAR_LEN[kind]
	var body_mat := shared("car_%s_%s" % [kind, color.to_html()], color, 0.75, 0.2)
	if kind == "box":
		box(g, Vector3(3.1, 3.6, 15.2), Vector3(0, RAIL_TOP + 2.75, 0), body_mat)
		box(g, Vector3(0.12, 2.9, 3.0), Vector3(1.6, RAIL_TOP + 2.5, 0), shared("car_door", Color("4a3b30"), 0.8))
		box(g, Vector3(0.12, 2.9, 3.0), Vector3(-1.6, RAIL_TOP + 2.5, 0), shared("car_door", Color("4a3b30"), 0.8))
	elif kind == "hop":
		var mi := MeshInstance3D.new()
		mi.mesh = meshes["hopper"]
		mi.material_override = body_mat
		mi.position.y = RAIL_TOP - 0.6
		g.add_child(mi)
	else:
		var t := cyl(g, 1.5, 1.5, 16.0, Vector3(0, RAIL_TOP + 2.55, 0), body_mat, 20)
		t.rotation.x = PI / 2.0
		cyl(g, 0.45, 0.5, 0.5, Vector3(0, RAIL_TOP + 4.1, 0), body_mat, 12)   # dome
	if kind != "box":
		box(g, Vector3(3.0, 0.25, 17.0), Vector3(0, RAIL_TOP - 0.3 + 1.15, 0), mats["steel_dark"])
	for dz in [-length * 0.36, length * 0.36]:
		box(g, Vector3(2.5, 0.7, 2.6), Vector3(0, RAIL_TOP - 0.55 + 0.65, dz), mats["steel_dark"])
		for sx in [-0.72, 0.72]:   # wheelsets riding on the rails
			for wz in [-0.85, 0.85]:
				var w := cyl(g, 0.42, 0.42, 0.14, Vector3(sx, RAIL_TOP + 0.04, dz + wz), mats["black"], 14)
				w.rotation.z = PI / 2.0
	if detailed:
		for e in [-1.0, 1.0]:
			box(g, Vector3(0.32, 0.24, 0.9), Vector3(0, RAIL_TOP - 0.2 + 0.95, e * (length / 2.0 + 0.32)), mats["steel_dark"])
			var hose := box(g, Vector3(0.035, 0.7, 0.035), Vector3(e * 0.24, RAIL_TOP + 0.6, e * (length / 2.0 + 0.25)), mats["black"])
			hose.rotation.z = e * 0.28
		for sx in [-1.42, 1.42]:
			for sz in [-length * 0.46, length * 0.46]:
				box(g, Vector3(0.05, 3.1, 0.05), Vector3(sx, RAIL_TOP - 0.1 + 2.5, sz), mats["steel_dark"])
	return g

func bumper(parent: Node, x: float, d: float, dir: float) -> void:
	var b := Node3D.new()
	box(b, Vector3(G + 0.3, 0.35, 0.35), Vector3(0, RAIL_TOP + 0.55, 0), mats["yellow"])
	for sx in [-1.0, 1.0]:
		var br := box(b, Vector3(0.12, 0.12, 2.2), Vector3(sx * G / 2.0, RAIL_TOP + 0.3, dir * 0.9), mats["steel_dark"])
		br.rotation.x = dir * 0.28
	box(b, Vector3(0.5, 0.5, 0.05), Vector3(0, RAIL_TOP + 1.0, -dir * 0.2), mats["redlamp"])
	b.position = Vector3(x, 0, -d)
	parent.add_child(b)

# ================================================================ industries
func industry(parent: Node, kind: String, side: float, tc: float, d_mid: float, length: float) -> void:
	match kind:
		"silos":
			_silos(parent, side * (tc + 10.0), d_mid, length * 0.6)
		"tanks":
			_tank_farm(parent, side * (tc + 9.0), d_mid, length)
		"lumber":
			_lumber(parent, side * (tc + 10.0), d_mid, length)
		_:
			var cols := [Color("9a9a92"), Color("a89f8c"), Color("7f8a8f")]
			_warehouse(parent, side * (tc + 14.0), d_mid, length, cols[rng.randi() % cols.size()])

func _warehouse(parent: Node, x: float, d: float, length: float, color: Color) -> void:
	var g := Node3D.new()
	var w := 18.0
	var h := 9.0
	box(g, Vector3(w, h, length), Vector3(0, h / 2.0 - 0.4, 0), shared("wh_" + color.to_html(), color, 0.85))
	box(g, Vector3(w + 0.6, 0.4, length + 0.6), Vector3(0, h - 0.2, 0), mats["roof"])
	var face := -signf(x)
	for i in int(floor(length / 14.0)):
		box(g, Vector3(0.1, 3.4, 3.2), Vector3(face * (w / 2.0 + 0.05), 1.3, -length / 2.0 + 7.0 + i * 14.0), mats["door"])
	box(g, Vector3(1.2, 1.2, length), Vector3(face * (w / 2.0 + 0.6), 0.2, 0), mats["dock"])
	g.position = Vector3(x, 0, -d)
	parent.add_child(g)

func _silos(parent: Node, x: float, d: float, length: float) -> void:
	var g := Node3D.new()
	var n := maxi(3, int(floor(length / 9.0)))
	for i in n:
		for j in 2:
			cyl(g, 4.0, 4.0, 32.0, Vector3(j * 8.0 * signf(x), 15.6, -length / 2.0 + 4.0 + i * 8.0), mats["silo"], 20)
	box(g, Vector3(9, 12, 9), Vector3(4.0 * signf(x), 37.0, -length / 2.0 + 4.0), mats["silo"])
	box(g, Vector3(6, 3.5, 10), Vector3(-6.0 * signf(x), 1.4, 0), mats["silo_base"])
	g.position = Vector3(x, 0, -d)
	parent.add_child(g)

func _tank_farm(parent: Node, x: float, d: float, length: float) -> void:
	var g := Node3D.new()
	var n := maxi(2, int(floor(length / 22.0)))
	for i in n:
		var t := cyl(g, 2.2, 2.2, 18.0, Vector3(0, 2.6, -length / 2.0 + 11.0 + i * 22.0), mats["tank_white"], 20)
		t.rotation.x = PI / 2.0
		for dz in [-6.0, 6.0]:
			box(g, Vector3(0.6, 1.6, 0.6), Vector3(0, 0.4, -length / 2.0 + 11.0 + i * 22.0 + dz), mats["tank_stand"])
	box(g, Vector3(6, 0.3, 4), Vector3(-6.0 * signf(x), 2.5, 0), mats["tank_stand"])
	g.position = Vector3(x, 0, -d)
	parent.add_child(g)

func _lumber(parent: Node, x: float, d: float, length: float) -> void:
	var g := Node3D.new()
	for i in int(floor(length / 9.0)):
		box(g, Vector3(4.0 + rng.randf() * 2.0, 1.5 + rng.randf() * 2.5, 6.0), Vector3((rng.randf() - 0.5) * 8.0, 0.6, -length / 2.0 + 5.0 + i * 9.0), mats["lumber"])
	box(g, Vector3(14, 7, 24), Vector3(10.0 * signf(x), 3.0, length / 2.0 - 14.0), mats["lumber_shed"])
	g.position = Vector3(x, 0, -d)
	parent.add_child(g)

# ================================================================ line-side
func pole_line(parent: Node, d0: float, d1: float, x: float, skip: Callable) -> void:
	var pd := ceilf(d0 / 45.0) * 45.0
	var poles: Array = []
	while pd < d1:
		if not skip.call(pd):
			poles.append(pd)
		pd += 45.0
	for p in poles:
		cyl(parent, 0.12, 0.16, 10.0, Vector3(x, -0.45 + 5.0, -p), mats["pole"], 8)
		box(parent, Vector3(2.2, 0.12, 0.12), Vector3(x, -0.45 + 9.3, -p), mats["pole"])
	if poles.size() >= 1:
		for wx in [x - 0.9, x + 0.9]:
			box(parent, Vector3(0.02, 0.02, d1 - d0), Vector3(wx, -0.45 + 9.42, -(d0 + d1) * 0.5), mats["black"], false)

# ================================================================ buildings (scenery zones)
const SIDING_COLS := ["e8e2d4", "c9d3d6", "d8cfb0", "a9b7a0", "f0ece2", "b8a58a", "8fa3b5", "d9c2a7"]
const BRICK_COLS := ["8a4b36", "9a5a41", "7a4231", "a2694d", "6f5a4a"]

func prism(parent: Node, size: Vector3, pos: Vector3, m: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

func _bmats() -> void:
	if mats.has("roof_shingle"):
		return
	mats["roof_shingle"] = mat(Color("3d3b3a"), 0.9)
	mats["roof_brown"] = mat(Color("5a4636"), 0.9)
	mats["roof_tin"] = mat(Color("8d9093"), 0.45, 0.6)
	mats["window"] = mat(Color("1d2328"), 0.15, 0.3)
	mats["trim"] = mat(Color("f2f0ea"), 0.7)
	mats["barn_red"] = mat(Color("8e2c22"), 0.85)
	mats["fence"] = mat(Color("cfc8b8"), 0.9)
	mats["stack"] = mat(Color("7c756c"), 0.9)
	mats["awning"] = mat(Color("2f5d45"), 0.8)

## Gable-roof house facing the track (faces -sign(x)), with door, windows and chimney.
func house(parent: Node, x: float, d: float, srng: RandomNumberGenerator) -> void:
	_bmats()
	var g := Node3D.new()
	var w := srng.randf_range(8.0, 11.0)
	var dp := srng.randf_range(7.0, 9.5)
	var h := 2.9 if srng.randf() < 0.65 else 5.6
	var body := shared("siding_" + str(SIDING_COLS[srng.randi() % SIDING_COLS.size()]), Color(SIDING_COLS[srng.randi() % SIDING_COLS.size()]), 0.85)
	var roofm: Material = mats["roof_shingle"] if srng.randf() < 0.6 else mats["roof_brown"]
	box(g, Vector3(w + 0.3, 0.6, dp + 0.3), Vector3(0, 0.0, 0), mats["concrete"])
	box(g, Vector3(w, h, dp), Vector3(0, 0.3 + h / 2.0, 0), body)
	prism(g, Vector3(w + 0.8, 2.0, dp + 0.8), Vector3(0, 0.3 + h + 1.0, 0), roofm)
	var face := -signf(x)
	var fz := face * (w / 2.0 + 0.03)
	box(g, Vector3(0.06, 2.1, 0.95), Vector3(fz, 0.3 + 1.05, 0.0), mats["door"])
	for wz in [-dp * 0.3, dp * 0.3]:
		for fl in (range(2) if h > 4.0 else range(1)):
			box(g, Vector3(0.06, 1.2, 1.1), Vector3(fz, 0.3 + 1.5 + fl * 2.7, wz), mats["window"])
			box(g, Vector3(0.08, 1.35, 0.12), Vector3(fz, 0.3 + 1.5 + fl * 2.7, wz - 0.62), mats["trim"])
			box(g, Vector3(0.08, 1.35, 0.12), Vector3(fz, 0.3 + 1.5 + fl * 2.7, wz + 0.62), mats["trim"])
	if srng.randf() < 0.6:
		box(g, Vector3(0.9, 2.2, 0.9), Vector3(-face * w * 0.25, 0.3 + h + 1.4, dp * 0.25), shared("brick_0", Color(BRICK_COLS[0]), 0.9))
	if srng.randf() < 0.5:   # porch
		box(g, Vector3(2.0, 0.25, dp * 0.7), Vector3(fz + face * 1.0, 0.45, 0), mats["concrete"])
		box(g, Vector3(2.2, 0.15, dp * 0.75), Vector3(fz + face * 1.0, 0.3 + 2.6, 0), roofm)
	g.position = Vector3(x, ground_h(x, -d) - 0.5, -d)
	g.rotation.y = srng.randf_range(-0.08, 0.08)
	parent.add_child(g)

## Red barn with a gambrel-ish roof, a silo and a fence line.
func farmstead(parent: Node, x: float, d: float, srng: RandomNumberGenerator) -> void:
	_bmats()
	var g := Node3D.new()
	var s := signf(x)
	box(g, Vector3(14, 7, 22), Vector3(0, 3.0, 0), mats["barn_red"])
	prism(g, Vector3(15.2, 4.5, 22.6), Vector3(0, 8.7, 0), mats["roof_tin"])
	box(g, Vector3(0.1, 4.5, 5.0), Vector3(-s * 7.05, 2.4, 0), mats["trim"])
	for k in 2:
		cyl(g, 3.0, 3.0, 16.0, Vector3(s * 11.0 + k * s * 6.8, 7.5, -8.0), mats["silo"], 18)
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.0
		sm.height = 3.0
		sm.is_hemisphere = true
		dome.mesh = sm
		dome.material_override = mats["roof_tin"]
		dome.position = Vector3(s * 11.0 + k * s * 6.8, 15.5, -8.0)
		g.add_child(dome)
	house(g, s * -2.0, -28.0, srng)
	g.position = Vector3(x, ground_h(x, -d) - 0.5, -d)
	parent.add_child(g)
	fence(parent, x - s * 12.0, d - 60.0, d + 60.0)

func fence(parent: Node, x: float, d0: float, d1: float) -> void:
	_bmats()
	var n := int((d1 - d0) / 3.0)
	for i in n + 1:
		box(parent, Vector3(0.12, 1.3, 0.12), Vector3(x, ground_h(x, -(d0 + i * 3.0)) - 0.0, -(d0 + i * 3.0)), mats["fence"], false)
	for y in [0.35, 0.75]:
		box(parent, Vector3(0.05, 0.12, d1 - d0), Vector3(x, ground_h(x, -(d0 + d1) / 2.0) - 0.5 + y + 0.45, -(d0 + d1) / 2.0), mats["fence"], false)

## A block of 1-3 storey brick storefronts along a street parallel to the track.
func storefronts(parent: Node, x: float, d0: float, d1: float, srng: RandomNumberGenerator) -> void:
	_bmats()
	var face := -signf(x)
	var d := d0
	while d < d1:
		var w := srng.randf_range(8.0, 14.0)
		var fl := srng.randi_range(1, 3)
		var h := fl * 3.6
		var bc := Color(BRICK_COLS[srng.randi() % BRICK_COLS.size()])
		var bm := shared("brick_" + bc.to_html(), bc, 0.92)
		var depth := srng.randf_range(14.0, 20.0)
		var bx := x - face * depth / 2.0
		box(parent, Vector3(depth, h, w - 0.2), Vector3(bx, h / 2.0 - 0.4, -(d + w / 2.0)), bm)
		box(parent, Vector3(depth + 0.2, 0.7, w), Vector3(bx, h + 0.0, -(d + w / 2.0)), bm)        # parapet
		box(parent, Vector3(0.08, 2.4, w * 0.75), Vector3(x + face * 0.04, 1.0, -(d + w / 2.0)), mats["window"])
		box(parent, Vector3(1.4, 0.12, w * 0.85), Vector3(x + face * 0.7, 2.7, -(d + w / 2.0)), mats["awning"] if srng.randf() < 0.5 else mats["barn_red"])
		for f in range(1, fl):
			for k in 3:
				box(parent, Vector3(0.08, 1.4, 1.0), Vector3(x + face * 0.04, f * 3.6 + 1.0, -(d + w * (0.22 + 0.28 * k))), mats["window"])
		d += w
	parent.add_child(road_strip(x + face * 7.0, d0 - 10.0, d1 + 10.0, 9.0))

## Town water tower with the town name on the tank.
func water_tower(parent: Node, x: float, d: float, town: String) -> void:
	_bmats()
	var g := Node3D.new()
	for a in 4:
		var ang := a * PI / 2.0 + PI / 4.0
		var leg := cyl(g, 0.25, 0.3, 24.0, Vector3(cos(ang) * 4.5, 12.0, sin(ang) * 4.5), mats["tank_stand"], 8)
		leg.rotation = Vector3(sin(ang) * 0.06, 0, -cos(ang) * 0.06)
	cyl(g, 6.0, 6.0, 7.0, Vector3(0, 27.0, 0), mats["tank_white"], 28)
	var cone := cyl(g, 0.3, 6.3, 3.0, Vector3(0, 32.0, 0), mats["tank_white"], 28)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var lbl := Label3D.new()
	lbl.text = town.to_upper()
	lbl.font_size = 220
	lbl.pixel_size = 0.012
	lbl.modulate = Color(0.12, 0.18, 0.3)
	lbl.outline_size = 0
	lbl.position = Vector3(-signf(x) * 6.05, 27.5, 0)
	lbl.rotation.y = -signf(x) * PI / 2.0
	g.add_child(lbl)
	g.position = Vector3(x, ground_h(x, -d) - 0.5, -d)
	parent.add_child(g)

## White country church with a steeple.
func church(parent: Node, x: float, d: float) -> void:
	_bmats()
	var g := Node3D.new()
	box(g, Vector3(10, 6, 18), Vector3(0, 3.0, 0), mats["trim"])
	prism(g, Vector3(11, 4.0, 18.6), Vector3(0, 8.0, 0), mats["roof_shingle"])
	box(g, Vector3(4, 10, 4), Vector3(0, 5.0, -10.0), mats["trim"])
	var sp := cyl(g, 0.1, 2.6, 7.0, Vector3(0, 13.5, -10.0), mats["roof_shingle"], 4)
	sp.rotation.y = PI / 4.0
	g.position = Vector3(x, ground_h(x, -d) - 0.5, -d)
	parent.add_child(g)

## Factory: big shed, smokestack, tanks.
func factory(parent: Node, x: float, d: float, srng: RandomNumberGenerator) -> void:
	_bmats()
	_warehouse(parent, x, d, srng.randf_range(50.0, 90.0), Color("8e8a80"))
	var s := signf(x)
	cyl(parent, 1.4, 2.2, 38.0, Vector3(x + s * 14.0, 18.5, -(d + 20.0)), mats["stack"], 14)
	_tank_farm(parent, x + s * 22.0, d - 30.0, 40.0)
