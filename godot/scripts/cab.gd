extends RefCounted
## Locomotive + cab interior. Two models:
##  "modern"  - wide-cab road unit (ES44AC-style) with an L-shaped desktop console:
##              PTC + engine displays, analog gauges, desktop throttle, CCB brake stand.
##  "classic" - standard-cab hood unit (GP38-style) with an AAR control stand,
##              round gauge cluster, throttle quadrant and a 26L brake valve.
## Coordinates (from v11): origin at the engineer's eye level, cab front at z = 0,
## +z toward the rear of the locomotive, -z toward the nose.

var m: Dictionary = {}
var model: String = "modern"
var eye := Vector3(0.86, 0.0, 1.08)
var lever_thr: Node3D
var lever_db: Node3D
var lever_auto: Node3D
var lever_ind: Node3D
var needles: Dictionary = {}
var wipers: Array = []
var ui: Dictionary = {}

# ================================================================ materials
func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	s.metallic = metal
	return s

func _unshaded(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return s

func _tri(path: String, scale: float, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_texture = load(path)
	s.uv1_triplanar = true
	s.uv1_scale = Vector3(scale, scale, scale)
	s.roughness = rough
	s.metallic = metal
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s

func _decal(path: String, uv_scale: Vector2 = Vector2.ONE, uv_off: Vector2 = Vector2.ZERO, alpha: bool = false) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_texture = load(path)
	s.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	s.uv1_offset = Vector3(uv_off.x, uv_off.y, 0)
	s.roughness = 0.7
	if alpha:
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		s.alpha_scissor_threshold = 0.5
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s

func _materials() -> void:
	m["paint"] = _mat(Color("2a2f36"), 0.8, 0.05)
	m["hood"] = _tri("res://textures/hood.png", 1.0 / 5.5, 0.78, 0.08)
	m["hood"].uv1_scale = Vector3(1.0 / 5.5, 1.0 / 1.8, 1.0 / 5.5)
	m["wall"] = _tri("res://textures/cab_wall_gray.png", 0.55, 0.85, 0.05)
	m["wall_beige"] = _tri("res://textures/cab_wall_beige.png", 0.55, 0.85, 0.05)
	m["desk"] = _tri("res://textures/desk_gray.png", 0.8, 0.75, 0.05)
	m["console"] = _tri("res://textures/console_black.png", 1.2, 0.65, 0.2)
	m["floor"] = _tri("res://textures/cab_mat.png", 1.6, 0.95)
	m["switches"] = _decal("res://textures/switch_panel.png")
	m["switches_beige"] = _decal("res://textures/switch_panel_beige.png")
	m["warn"] = _decal("res://textures/decals.png", Vector2(0.5, 0.5), Vector2(0, 0))
	m["fuel"] = _decal("res://textures/decals.png", Vector2(0.5, 0.5), Vector2(0.5, 0))
	m["bulletin"] = _decal("res://textures/decals.png", Vector2(1, 0.5), Vector2(0, 0.5))
	m["paper"] = _decal("res://textures/paper.png")
	m["g_speed"] = _decal("res://textures/gauge_speed.png", Vector2.ONE, Vector2.ZERO, true)
	m["g_er"] = _decal("res://textures/gauge_air_er.png", Vector2.ONE, Vector2.ZERO, true)
	m["g_mr"] = _decal("res://textures/gauge_air_mr.png", Vector2.ONE, Vector2.ZERO, true)
	m["seat"] = _tri("res://textures/seat_worn.png", 1.6, 0.95)
	m["grip"] = _tri("res://textures/grip.png", 6.0, 0.55, 0.4)
	m["porcelain"] = _mat(Color(0.88, 0.88, 0.84), 0.25)
	m["nose_dark"] = _mat(Color(0.18, 0.17, 0.15), 0.95)
	m["seat_dark"] = _mat(Color(0.12, 0.12, 0.13), 0.8)
	m["steel_dark"] = _mat(Color("262422"), 0.72, 0.35)
	m["steel"] = _mat(Color(0.45, 0.44, 0.42), 0.55, 0.6)
	m["black"] = _mat(Color("111214"), 0.6)
	m["rubber"] = _mat(Color(0.05, 0.05, 0.05), 0.9)
	m["handrail"] = _mat(Color("e2c021"), 0.45, 0.2)
	m["yellow"] = _mat(Color("e0b51c"), 0.52)
	m["deck"] = _mat(Color("34373b"), 0.9, 0.25)
	m["brass"] = _mat(Color("b08d3c"), 0.35, 0.8)
	m["red"] = _mat(Color("c92a22"), 0.4)
	m["knob_red"] = _mat(Color(0.75, 0.12, 0.1), 0.35)
	m["knob_pink"] = _mat(Color(0.9, 0.55, 0.6), 0.5)
	m["mirror_frame"] = _mat(Color("16181c"), 0.5, 0.6)
	m["mirror_glass"] = _mat(Color("c8d6e0"), 0.05, 0.9)
	m["alerter"] = _unshaded(Color("f5c724"))
	m["dome"] = _unshaded(Color("ffecc2"))
	m["lcd"] = _unshaded(Color(0.35, 0.9, 0.55))
	m["ditch"] = _unshaded(Color("fff6d8"))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.77, 0.86, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["glass"] = glass
	var gg: StandardMaterial3D = glass.duplicate()
	gg.albedo_color = Color(0.8, 0.85, 0.9, 0.035)
	m["gauge_glass"] = gg
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color(0.09, 0.13, 0.11, 0.72)
	visor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["visor"] = visor
	var fan := StandardMaterial3D.new()
	fan.albedo_texture = load("res://textures/fan.png")
	fan.roughness = 0.8
	m["fan"] = fan

# ================================================================ primitives
func box(p: Node, w: float, h: float, d: float, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(x, y, z)
	p.add_child(mi)
	return mi

func cyl(p: Node, rt: float, rb: float, h: float, mat: Material, pos: Vector3, segs: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi

func ball(p: Node, r: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi

func tube(p: Node, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := cyl(p, r, r, a.distance_to(b), mat, (a + b) * 0.5, 8)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi

func quad(p: Node, w: float, h: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

func pivot(p: Node, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	p.add_child(n)
	return n

# ================================================================ instruments
## A round gauge face on parent p (in p's XY plane, facing +z) with needles.
func gauge(p: Node, mat_key: String, r: float, pos: Vector3, needle_keys: Array, needle_cols: Array) -> void:
	box(p, r * 2.25, r * 2.25, 0.03, m["black"], pos.x, pos.y, pos.z - 0.012)
	var face := quad(p, r * 2.0, r * 2.0, m[mat_key], pos + Vector3(0, 0, 0.004), Vector3.ZERO)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in needle_keys.size():
		var pv := pivot(p, pos + Vector3(0, 0, 0.008 + i * 0.003))
		box(pv, r * 0.06, r * 0.78, 0.002, _unshaded(needle_cols[i]), 0, r * 0.3, 0)
		needles[needle_keys[i]] = pv
	var hub := cyl(p, r * 0.08, r * 0.08, 0.01, m["black"], pos + Vector3(0, 0, 0.016), 10)
	hub.rotation.x = PI / 2.0
	quad(p, r * 2.0, r * 2.0, m["gauge_glass"], pos + Vector3(0, 0, 0.02), Vector3.ZERO)

func set_needle(key: String, value: float, vmax: float) -> void:
	if not needles.has(key):
		return
	var t := clampf(value / vmax, 0.0, 1.0)
	needles[key].rotation.z = deg_to_rad(225.0 - 270.0 * t) - PI / 2.0

## A live screen: a SubViewport drawn onto a quad. Only the first screen of each
## kind gets its own viewport; later ones share its picture.
var _vp_tex: Dictionary = {}

func screen(p: Node, w: float, h: float, pos: Vector3, rot: Vector3, kind: String) -> void:
	if not _vp_tex.has(kind):
		var vp := SubViewport.new()
		vp.size = Vector2i(512, 384)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		p.add_child(vp)
		var root := Control.new()
		root.size = Vector2(512, 384)
		vp.add_child(root)
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.03, 0.05)
		bg.size = Vector2(512, 384)
		root.add_child(bg)
		if kind == "ptc":
			_build_ptc(root)
		else:
			_build_eng(root)
		_vp_tex[kind] = vp.get_texture()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _vp_tex[kind]
	var bez := box(p, w + 0.05, h + 0.05, 0.04, m["console"], pos.x, pos.y, pos.z)
	bez.rotation = rot
	var s := quad(p, w, h, mat, pos, rot)
	s.position += s.basis.z * 0.021
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _commas(n: int) -> String:
	var t := str(n)
	return t if t.length() <= 3 else t.left(t.length() - 3) + "," + t.right(3)

func _lbl(root: Control, pos: Vector2, size: int, col: Color, text: String = "") -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.text = text
	root.add_child(l)
	return l

func _rect(root: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	root.add_child(r)
	return r

func _build_eng(root: Control) -> void:
	_rect(root, Vector2(0, 0), Vector2(512, 40), Color(0.12, 0.2, 0.35))
	ui["e_title"] = _lbl(root, Vector2(12, 4), 24, Color.WHITE, "LOCO 8062   MAIN DISPLAY")
	ui["e_speed"] = _lbl(root, Vector2(16, 48), 92, Color(1, 0.86, 0.3), "0")
	_lbl(root, Vector2(22, 150), 24, Color(0.8, 0.8, 0.8), "MPH")
	ui["e_lever"] = _lbl(root, Vector2(200, 52), 34, Color.WHITE, "IDLE")
	_lbl(root, Vector2(200, 100), 20, Color(0.7, 0.75, 0.8), "TRACTIVE EFFORT")
	_rect(root, Vector2(200, 126), Vector2(296, 22), Color(0.15, 0.15, 0.18))
	ui["e_te_bar"] = _rect(root, Vector2(200, 126), Vector2(0, 22), Color(0.2, 0.8, 0.35))
	ui["e_te"] = _lbl(root, Vector2(200, 150), 20, Color(0.6, 1, 0.65), "0 kN")
	_lbl(root, Vector2(200, 178), 20, Color(0.7, 0.75, 0.8), "DYNAMIC BRAKE")
	_rect(root, Vector2(200, 204), Vector2(296, 22), Color(0.15, 0.15, 0.18))
	ui["e_db_bar"] = _rect(root, Vector2(200, 204), Vector2(0, 22), Color(0.95, 0.6, 0.15))
	ui["e_db"] = _lbl(root, Vector2(200, 228), 20, Color(1, 0.75, 0.4), "0 kN")
	_rect(root, Vector2(0, 262), Vector2(512, 2), Color(0.3, 0.35, 0.45))
	ui["e_air1"] = _lbl(root, Vector2(12, 270), 22, Color(0.75, 0.9, 1), "")
	ui["e_air2"] = _lbl(root, Vector2(12, 300), 22, Color(0.75, 0.9, 1), "")
	ui["e_flags"] = _lbl(root, Vector2(12, 336), 24, Color(1, 0.4, 0.3), "")

func _build_ptc(root: Control) -> void:
	_rect(root, Vector2(0, 0), Vector2(512, 36), Color(0.05, 0.35, 0.15))
	_lbl(root, Vector2(10, 3), 22, Color.WHITE, "PTC  ACTIVE")
	ui["p_mp"] = _lbl(root, Vector2(190, 5), 20, Color(0.85, 1, 0.85), "A-LINE SUB  MP 0.0")
	_lbl(root, Vector2(10, 42), 16, Color(0.7, 0.75, 0.8), "SPEED")
	ui["p_speed"] = _lbl(root, Vector2(10, 56), 54, Color.WHITE, "0")
	_rect(root, Vector2(112, 42), Vector2(92, 92), Color(0.95, 0.95, 0.92))
	_lbl(root, Vector2(118, 44), 13, Color.BLACK, "SPEED LIMIT")
	ui["p_limit"] = _lbl(root, Vector2(128, 60), 48, Color.BLACK, "40")
	_lbl(root, Vector2(216, 42), 16, Color(0.7, 0.75, 0.8), "NEXT TARGET")
	ui["p_target"] = _lbl(root, Vector2(216, 60), 22, Color(1, 0.85, 0.3), "--")
	ui["p_target2"] = _lbl(root, Vector2(216, 88), 30, Color(1, 0.85, 0.3), "")
	# distance-to-target bar (fills as you close in)
	_rect(root, Vector2(216, 124), Vector2(284, 10), Color(0.15, 0.15, 0.18))
	ui["p_bar"] = _rect(root, Vector2(216, 124), Vector2(0, 10), Color(1, 0.6, 0.1))
	# 2-mile track strip with markers
	_rect(root, Vector2(10, 150), Vector2(490, 4), Color(0.8, 0.8, 0.8))
	ui["p_marks"] = []
	for k in 8:
		var mk := _rect(root, Vector2(10, 140), Vector2(4, 24), Color(1, 0.6, 0.1))
		mk.visible = false
		ui["p_marks"].append(mk)
	_lbl(root, Vector2(10, 164), 13, Color(0.6, 0.6, 0.6), "0")
	_lbl(root, Vector2(470, 164), 13, Color(0.6, 0.6, 0.6), "2 MI")
	_rect(root, Vector2(0, 184), Vector2(512, 2), Color(0.3, 0.4, 0.35))
	_lbl(root, Vector2(10, 188), 15, Color(0.6, 0.8, 0.65), "AHEAD                                      DISTANCE")
	ui["p_rows"] = []
	for k in 6:
		var row := _lbl(root, Vector2(10, 208 + k * 26), 19, Color(0.9, 0.92, 0.9), "")
		var dist := _lbl(root, Vector2(390, 208 + k * 26), 19, Color(1, 0.85, 0.4), "")
		ui["p_rows"].append([row, dist])
	ui["p_warn"] = _lbl(root, Vector2(300, 42), 18, Color(1, 0.35, 0.3), "")

# ================================================================ build
var has_db: bool = true
var pickables: Array = []

func build(kind: String, dyn_brake: bool = true) -> Node3D:
	model = kind
	has_db = dyn_brake
	pickables.clear()
	_materials()
	needles.clear()
	ui.clear()
	wipers.clear()
	_vp_tex.clear()
	lever_db = null
	var L := Node3D.new()
	if kind == "classic" or kind == "classic_lhf":
		eye = Vector3(0.78, 0.0, 1.08)
		if kind == "classic_lhf":
			_exterior_lhf(L)
		else:
			_exterior_classic(L)
		_interior_classic(L, kind == "classic")
	else:
		eye = Vector3(0.86, 0.0, 1.08)
		_exterior_modern(L)
		_interior_modern(L)
	return L

# ---------------------------------------------------------------- exteriors
func _deck_and_ends(L: Node, w: float, front_len: float, rear_len: float, deck_y: float) -> void:
	var total := front_len + rear_len
	box(L, w, 0.12, total, m["deck"], 0, deck_y, (rear_len - front_len) / 2.0)
	for s in [-1.0, 1.0]:
		box(L, 0.05, 0.05, total, m["yellow"], s * w / 2.0, deck_y + 0.07, (rear_len - front_len) / 2.0)
	_deck_end(L, deck_y, -front_len, w, -1.0)
	_deck_end(L, deck_y, rear_len, w, 1.0)
	for s in [-1.0, 1.0]:
		var sx: float = s * (w / 2.0 - 0.3)
		box(L, 0.28, 0.28, 0.2, m["black"], sx, deck_y + 0.25, -front_len + 0.12)
		var dl := cyl(L, 0.1, 0.1, 0.02, m["ditch"], Vector3(sx, deck_y + 0.25, -front_len + 0.015), 16)
		dl.rotation.x = PI / 2.0

func _long_hood(L: Node, deck_y: float, hood_w: float) -> void:
	var r_len := 10.2
	var r_start := 2.75
	var r_h := 1.65
	box(L, hood_w, r_h, r_len - 2.6, m["hood"], 0, deck_y + r_h / 2.0 + 0.06, r_start + (r_len - 2.6) / 2.0)
	box(L, hood_w + 0.7, r_h + 0.12, 2.6, m["hood"], 0, deck_y + (r_h + 0.12) / 2.0 + 0.06, r_start + r_len - 1.3)
	for z in [r_start + r_len - 1.9, r_start + r_len - 0.7]:
		cyl(L, 0.58, 0.58, 0.02, m["fan"], Vector3(0, deck_y + r_h + 0.19, z), 24)

func _exterior_modern(L: Node) -> void:
	var deck_y := -2.05
	_deck_and_ends(L, 3.18, 4.2, 13.8, deck_y)
	var hm: Material = m["hood"]
	box(L, 2.96, 1.02, 1.85, hm, 0, deck_y + 0.56, -0.92)
	var slope := box(L, 2.96, 0.08, 1.45, hm, 0, deck_y + 0.92, -2.42)
	slope.rotation.x = -0.2
	box(L, 2.96, 0.78, 1.4, hm, 0, deck_y + 0.45, -2.42)
	box(L, 2.98, 0.06, 0.08, m["steel_dark"], 0, deck_y + 1.07, -1.78)
	cyl(L, 0.14, 0.18, 0.2, m["brass"], Vector3(-0.55, deck_y + 0.98, -2.6), 16)
	box(L, 0.6, 0.18, 0.22, m["black"], 0, deck_y + 0.86, -3.13)
	for s in [-1.0, 1.0]:
		tube(L, Vector3(s * 0.95, deck_y + 0.3, -3.16), Vector3(s * 0.95, deck_y + 0.85, -3.16), 0.02, m["handrail"])
	_long_hood(L, deck_y, 1.85)
	_railings(L, deck_y, -0.05, -4.05, [-1.52, 1.52], 0.45)
	_railings(L, deck_y, 2.75, 13.65, [-1.52, 1.52], 0.45)

func _exterior_classic(L: Node) -> void:
	var deck_y := -2.05
	_deck_and_ends(L, 3.04, 4.6, 13.6, deck_y)
	var hm: Material = m["hood"]
	box(L, 1.82, 1.18, 3.15, hm, 0, deck_y + 0.64, -1.62)
	box(L, 1.84, 0.06, 3.18, m["steel_dark"], 0, deck_y + 1.24, -1.62)
	cyl(L, 0.14, 0.18, 0.2, m["brass"], Vector3(-0.48, deck_y + 1.32, -2.85), 16)
	box(L, 0.7, 0.22, 0.1, m["black"], 0, deck_y + 1.0, -3.2)
	for hx in [-0.18, 0.18]:
		var hl := cyl(L, 0.09, 0.09, 0.04, m["ditch"], Vector3(hx, deck_y + 1.0, -3.26), 14)
		hl.rotation.x = PI / 2.0
	_long_hood(L, deck_y, 1.80)
	_railings(L, deck_y, -0.05, -4.45, [-1.46, 1.46], 0.45)
	_railings(L, deck_y, 2.75, 13.45, [-1.46, 1.46], 0.45)

func _exterior_lhf(L: Node) -> void:
	var deck_y := -2.05
	var hood_len := 13.6
	var front_end := -hood_len - 1.2
	var w := 3.04
	var total := absf(front_end) + 4.6
	box(L, w, 0.12, total, m["deck"], 0, deck_y, (4.6 + front_end) / 2.0)
	for s in [-1.0, 1.0]:
		box(L, 0.05, 0.05, total, m["yellow"], s * w / 2.0, deck_y + 0.07, (4.6 + front_end) / 2.0)
	_deck_end(L, deck_y, front_end, w, -1.0)
	_deck_end(L, deck_y, 4.6, w, 1.0)
	for s in [-1.0, 1.0]:
		var sx: float = s * (w / 2.0 - 0.3)
		box(L, 0.28, 0.28, 0.2, m["black"], sx, deck_y + 0.25, front_end + 0.12)
		var dl := cyl(L, 0.1, 0.1, 0.02, m["ditch"], Vector3(sx, deck_y + 0.25, front_end + 0.015), 16)
		dl.rotation.x = PI / 2.0
	var hw := 1.8
	var hh := 1.55
	box(L, hw, hh, hood_len - 3.4, m["hood"], 0, deck_y + hh / 2.0 + 0.06, -(hood_len - 3.4) / 2.0 - 0.1)
	box(L, 2.6, hh + 0.12, 3.3, m["hood"], 0, deck_y + (hh + 0.12) / 2.0 + 0.06, -hood_len + 1.55)
	for z in [-hood_len + 0.75, -hood_len + 2.15]:
		cyl(L, 0.62, 0.62, 0.02, m["fan"], Vector3(0, deck_y + hh + 0.19, z), 24)
	box(L, 0.42, 0.22, 0.9, m["black"], 0, deck_y + hh + 0.17, -6.2)        # exhaust stack
	for z in [-3.6, -8.8]:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.055
		tm.outer_radius = 0.085
		r.mesh = tm
		r.material_override = m["steel_dark"]
		r.position = Vector3(0, deck_y + hh + 0.08, z)
		r.rotation = Vector3(0, 0, PI / 2.0)
		L.add_child(r)
	box(L, 0.06, 0.06, hood_len - 0.4, m["steel_dark"], hw / 2.0 + 0.02, deck_y + hh + 0.02, -hood_len / 2.0)
	cyl(L, 0.14, 0.18, 0.2, m["brass"], Vector3(0.5, deck_y + hh + 0.24, -hood_len + 0.4), 16)
	box(L, 1.82, 1.25, 2.8, m["hood"], 0, deck_y + 0.68, 3.85)    # short hood behind the cab
	_railings(L, deck_y, -0.05, front_end + 0.15, [-1.46, 1.46], 0.45)
	_railings(L, deck_y, 2.75, 4.45, [-1.46, 1.46], 0.45)

func _railings(p: Node, deck_y: float, z0: float, z1: float, xs: Array, step_gap_x: float) -> void:
	var top := deck_y + 1.05
	var mid := deck_y + 0.55
	var dir := signf(z1 - z0)
	var dist := absf(z1 - z0)
	var steps := maxi(1, int(ceil(dist / 1.6)))
	for x in xs:
		tube(p, Vector3(x, top, z0), Vector3(x, top, z1), 0.025, m["handrail"])
		tube(p, Vector3(x, mid, z0), Vector3(x, mid, z1), 0.025, m["handrail"])
		for i in steps + 1:
			var z := z0 + dir * dist * i / steps
			tube(p, Vector3(x, deck_y, z), Vector3(x, top, z), 0.03, m["handrail"])
		var gx: float = signf(x) * step_gap_x
		tube(p, Vector3(x, top, z1), Vector3(gx, top, z1), 0.025, m["handrail"])
		tube(p, Vector3(gx, deck_y, z1), Vector3(gx, top, z1), 0.03, m["handrail"])

func _deck_end(p: Node, deck_y: float, z_end: float, w: float, dir_z: float) -> void:
	box(p, w + 0.04, 0.05, 0.12, m["yellow"], 0, deck_y + 0.07, z_end - dir_z * 0.05)
	box(p, w, 0.45, 0.16, m["paint"], 0, deck_y - 0.3, z_end - dir_z * 0.08)
	box(p, 0.36, 0.28, 0.75, m["steel_dark"], 0, deck_y - 0.34, z_end + dir_z * 0.38)
	for s in [-1.0, 1.0]:
		for i in 3:
			box(p, 0.55, 0.04, 0.3, m["yellow"], s * (w / 2.0 - 0.35), deck_y - 0.35 - i * 0.38, z_end - dir_z * 0.25)

# ---------------------------------------------------------------- shared cab shell
func _shell(p: Node, w: float, cab_len: float, floor_y: float, ceil_y: float, sill_y: float, top_y: float, win_xs: Array, win_w: float, wall: Material, rounded: bool, nose_gap: Vector2 = Vector2.ZERO) -> void:
	var half_w := w / 2.0
	box(p, w - 0.08, 0.06, cab_len, m["floor"], 0, floor_y, cab_len / 2.0)
	box(p, w + 0.08, 0.14, cab_len + 0.2, m["paint"], 0, ceil_y + 0.12, cab_len / 2.0 - 0.05)
	box(p, w - 0.1, 0.05, cab_len, wall, 0, ceil_y, cab_len / 2.0)
	if nose_gap == Vector2.ZERO:
		box(p, w, sill_y - floor_y, 0.1, wall, 0, (sill_y + floor_y) / 2.0, 0.0)
	else:
		# opening (x half-width, top y) down into the nose
		var gx := nose_gap.x
		var gt := nose_gap.y
		box(p, half_w - gx, sill_y - floor_y, 0.1, wall, -(half_w + gx) / 2.0, (sill_y + floor_y) / 2.0, 0.0)
		box(p, half_w - gx, sill_y - floor_y, 0.1, wall, (half_w + gx) / 2.0, (sill_y + floor_y) / 2.0, 0.0)
		box(p, gx * 2.0, sill_y - gt, 0.1, wall, 0, (sill_y + gt) / 2.0, 0.0)
	box(p, w, ceil_y - top_y, 0.1, wall, 0, (ceil_y + top_y) / 2.0, 0.0)
	var edges: Array = [-half_w]
	for x in win_xs:
		edges.append(x - win_w / 2.0)
		edges.append(x + win_w / 2.0)
	edges.append(half_w)
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a > 0.005:
			box(p, b - a, top_y - sill_y, 0.1, wall, (a + b) / 2.0, (top_y + sill_y) / 2.0, 0.0)
	var win_h := top_y - sill_y
	for x in win_xs:
		box(p, win_w, 0.03, 0.12, m["rubber"], x, sill_y + 0.015, 0.0)
		box(p, win_w, 0.03, 0.12, m["rubber"], x, top_y - 0.015, 0.0)
		box(p, 0.03, win_h, 0.12, m["rubber"], x - win_w / 2.0 + 0.015, (sill_y + top_y) / 2.0, 0.0)
		box(p, 0.03, win_h, 0.12, m["rubber"], x + win_w / 2.0 - 0.015, (sill_y + top_y) / 2.0, 0.0)
		if rounded:
			var c := 0.09
			for cx in [-1.0, 1.0]:
				for cy in [-1.0, 1.0]:
					var corner := box(p, c * 1.4, c * 1.4, 0.1, wall, x + cx * (win_w / 2.0 - c * 0.35), (sill_y + top_y) / 2.0 + cy * (win_h / 2.0 - c * 0.35), 0.0)
					corner.rotation.z = PI / 4.0
		quad(p, win_w, win_h, m["glass"], Vector3(x, (sill_y + top_y) / 2.0, -0.02), Vector3.ZERO)
		var wp := pivot(p, Vector3(x - win_w * 0.35, sill_y + 0.04, -0.07), Vector3(0, 0, -1.35))
		box(wp, 0.02, win_h * 0.62, 0.02, m["black"], 0, win_h * 0.31, 0)
		box(wp, 0.035, win_h * 0.55, 0.02, m["black"], 0.02, win_h * 0.34, -0.012)
		wipers.append(wp)
	var side_sill := sill_y + 0.08
	for s in [-1.0, 1.0]:
		var sx: float = s * (half_w - 0.05)
		box(p, 0.1, side_sill - floor_y, cab_len, wall, sx, (side_sill + floor_y) / 2.0, cab_len / 2.0)
		box(p, 0.1, ceil_y - top_y, cab_len, wall, sx, (ceil_y + top_y) / 2.0, cab_len / 2.0)
		box(p, 0.1, top_y - side_sill, 0.3, wall, sx, (top_y + side_sill) / 2.0, 0.15)
		box(p, 0.1, top_y - side_sill, 0.12, wall, sx, (top_y + side_sill) / 2.0, 0.95)
		box(p, 0.1, top_y - side_sill, cab_len - 1.65, wall, sx, (top_y + side_sill) / 2.0, 1.65 + (cab_len - 1.65) / 2.0)
		quad(p, 1.35, top_y - side_sill, m["glass"], Vector3(sx + s * 0.04, (top_y + side_sill) / 2.0, 0.97), Vector3(0, PI / 2.0, 0))
		box(p, 0.04, 0.03, 1.35, m["rubber"], sx - s * 0.06, side_sill, 0.97)
	var back_z := cab_len
	box(p, w - 0.9, ceil_y - floor_y, 0.1, wall, 0.45, (ceil_y + floor_y) / 2.0, back_z)
	box(p, 0.85, ceil_y - floor_y, 0.06, wall, -half_w + 0.47, (ceil_y + floor_y) / 2.0, back_z + 0.02)
	box(p, 0.4, 0.55, 0.02, m["rubber"], -half_w + 0.5, 0.05, back_z - 0.02)
	quad(p, 0.36, 0.5, m["glass"], Vector3(-half_w + 0.5, 0.05, back_z - 0.04), Vector3(0, PI, 0))
	box(p, 0.05, 0.05, 0.14, m["steel"], -half_w + 0.82, -0.45, back_z - 0.08)
	for vx in win_xs:
		var visor := box(p, win_w * 0.42, 0.14, 0.015, m["visor"], vx + win_w * 0.22, top_y - 0.05, 0.1)
		visor.rotation.x = 0.28
	for dz in [0.9, 1.9]:
		box(p, 0.3, 0.05, 0.22, m["dome"], 0.1, ceil_y - 0.04, dz)

func _seat(p: Node, x: float, floor_y: float, z: float, cloth: Material) -> void:
	var g := pivot(p, Vector3(x, floor_y, z))
	box(g, 0.34, 0.12, 0.34, m["seat_dark"], 0, 0.06, 0)
	cyl(g, 0.06, 0.06, 0.42, m["steel"], Vector3(0, 0.3, 0), 10)
	box(g, 0.56, 0.14, 0.54, cloth, 0, 0.55, 0)
	box(g, 0.6, 0.06, 0.56, m["seat_dark"], 0, 0.47, 0)
	for s in [-1.0, 1.0]:
		box(g, 0.08, 0.06, 0.42, m["seat_dark"], s * 0.32, 0.78, 0.02)
		box(g, 0.05, 0.2, 0.05, m["seat_dark"], s * 0.32, 0.68, 0.2)
	var back := box(g, 0.52, 0.72, 0.12, cloth, 0, 0.98, 0.27)
	back.rotation.x = -0.12
	box(g, 0.34, 0.2, 0.1, cloth, 0, 1.44, 0.33)

func _radio(p: Node, pos: Vector3, rot: Vector3) -> void:
	var r := pivot(p, pos, rot)
	box(r, 0.28, 0.12, 0.16, m["black"], 0, 0, 0)
	box(r, 0.12, 0.04, 0.005, m["lcd"], -0.04, 0.02, 0.081)
	for i in 3:
		var k := cyl(r, 0.012, 0.012, 0.02, m["steel"], Vector3(0.07 + i * 0.03, -0.02, 0.085), 8)
		k.rotation.x = PI / 2.0
	box(r, 0.05, 0.11, 0.04, m["black"], -0.2, -0.08, 0.04)
	for i in 10:
		var t := float(i) / 10.0
		ball(r, 0.009, m["black"], Vector3(-0.2 + sin(t * 30.0) * 0.012, -0.16 - t * 0.22, 0.05 + cos(t * 30.0) * 0.012))

# ---------------------------------------------------------------- modern desktop cab
func _interior_modern(p: Node) -> void:
	var w := 3.16
	var floor_y := -1.35
	var sill_y := -0.42
	var top_y := 0.45
	_shell(p, w, 2.75, floor_y, 0.68, sill_y, top_y, [-0.76, 0.76], 1.36, m["wall"], false)
	var desk_y := -0.66
	# engineer's L-shaped desk (right side)
	box(p, 1.4, desk_y - floor_y, 0.55, m["desk"], 0.82, (desk_y + floor_y) / 2.0, 0.33)
	box(p, 1.44, 0.04, 0.6, m["console"], 0.82, desk_y + 0.02, 0.33)
	box(p, 0.38, desk_y - floor_y + 0.05, 0.75, m["desk"], 1.33, (desk_y + floor_y) / 2.0 + 0.025, 0.95)
	box(p, 0.4, 0.04, 0.78, m["console"], 1.33, desk_y + 0.07, 0.95)
	# slanted instrument panel facing the engineer
	var panel := pivot(p, Vector3(0.82, desk_y + 0.17, 0.12), Vector3(-0.42, 0, 0))
	box(panel, 1.42, 0.36, 0.05, m["console"], 0, 0, 0)
	screen(panel, 0.32, 0.24, Vector3(-0.44, 0.0, 0.03), Vector3.ZERO, "ptc")
	screen(panel, 0.32, 0.24, Vector3(-0.07, 0.0, 0.03), Vector3.ZERO, "eng")
	gauge(panel, "g_speed", 0.07, Vector3(0.23, 0.05, 0.03), ["speed"], [Color(1, 1, 1)])
	gauge(panel, "g_er", 0.07, Vector3(0.40, 0.05, 0.03), ["bp", "er"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	gauge(panel, "g_mr", 0.07, Vector3(0.57, 0.05, 0.03), ["mr", "bc"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	quad(panel, 0.5, 0.08, m["switches"], Vector3(0.4, -0.13, 0.028), Vector3.ZERO)
	# desktop throttle (left hand) + reverser
	var tb := pivot(p, Vector3(0.52, desk_y + 0.05, 0.42))
	box(tb, 0.14, 0.05, 0.3, m["console"], 0, 0, 0)
	box(tb, 0.03, 0.01, 0.26, m["rubber"], 0, 0.026, 0)
	for i in 9:
		box(tb, 0.05, 0.004, 0.004, m["steel"], 0.05, 0.027, -0.12 + i * 0.03)
	lever_thr = pivot(tb, Vector3(0, 0.02, 0))
	box(lever_thr, 0.025, 0.16, 0.025, m["steel"], 0, 0.08, 0)
	box(lever_thr, 0.07, 0.04, 0.05, m["grip"], 0, 0.17, 0)
	var rv := pivot(p, Vector3(0.22, desk_y + 0.04, 0.5))
	box(rv, 0.06, 0.05, 0.12, m["console"], 0, 0, 0)
	var rh := box(rv, 0.02, 0.09, 0.02, m["steel"], 0, 0.06, -0.03)
	rh.rotation.x = -0.4
	ball(rv, 0.018, m["black"], Vector3(0, 0.1, -0.05))
	# alerter + switch strip on the desk top
	cyl(p, 0.035, 0.035, 0.03, m["alerter"], Vector3(0.78, desk_y + 0.055, 0.5), 16)
	_pickable(p, Vector3(0.78, desk_y + 0.055, 0.5), 0.07, "alerter")
	box(p, 0.22, 0.03, 0.1, m["console"], 1.02, desk_y + 0.05, 0.5)
	var sw_mats := [m["red"], m["steel"], m["steel"], m["alerter"]]
	for i in 4:
		box(p, 0.02, 0.025, 0.03, sw_mats[i], 0.94 + i * 0.05, desk_y + 0.075, 0.5)
	# CCB brake stand on the right-hand wing: automatic (red knob) + independent
	var bs := pivot(p, Vector3(1.33, desk_y + 0.09, 0.92))
	box(bs, 0.3, 0.06, 0.5, m["console"], 0, 0, 0)
	for z in [-0.12, 0.1]:
		box(bs, 0.03, 0.005, 0.2, m["rubber"], 0, 0.033, z)
	lever_auto = pivot(bs, Vector3(0, 0.03, -0.12))
	box(lever_auto, 0.03, 0.17, 0.03, m["steel"], 0, 0.085, 0)
	ball(lever_auto, 0.035, m["knob_red"], Vector3(0, 0.18, 0))
	lever_ind = pivot(bs, Vector3(0, 0.03, 0.1))
	box(lever_ind, 0.03, 0.14, 0.03, m["steel"], 0, 0.07, 0)
	ball(lever_ind, 0.03, m["grip"], Vector3(0, 0.15, 0))
	quad(p, 0.22, 0.11, m["warn"], Vector3(1.53, desk_y + 0.25, 0.75), Vector3(0, -PI / 2.0, 0))
	_radio(p, Vector3(1.47, 0.05, 1.75), Vector3(0, -PI / 2.0, 0))
	# overhead consoles above the windshields
	for ox in [-0.62, 0.62]:
		var oc := pivot(p, Vector3(ox, 0.56, 0.62), Vector3(1.05, 0, 0))
		box(oc, 1.0, 0.22, 0.24, m["wall"], 0, 0, 0)
		quad(oc, 0.94, 0.2, m["switches"], Vector3(0, 0, 0.125), Vector3.ZERO)
	# conductor's desk (left) with two screens and paperwork
	box(p, 1.1, desk_y - floor_y, 0.6, m["desk"], -0.92, (desk_y + floor_y) / 2.0, 0.36)
	box(p, 1.14, 0.04, 0.64, m["console"], -0.92, desk_y + 0.02, 0.36)
	var cp := pivot(p, Vector3(-0.92, desk_y + 0.2, 0.14), Vector3(-0.3, 0, 0))
	box(cp, 0.9, 0.34, 0.12, m["desk"], 0, 0, -0.04)
	screen(cp, 0.3, 0.22, Vector3(-0.2, 0.0, 0.03), Vector3.ZERO, "ptc")
	screen(cp, 0.3, 0.22, Vector3(0.18, 0.0, 0.03), Vector3.ZERO, "eng")
	quad(p, 0.22, 0.3, m["paper"], Vector3(-0.85, desk_y + 0.045, 0.5), Vector3(-PI / 2.0, 0.15, 0))
	_radio(p, Vector3(-1.45, -0.05, 1.5), Vector3(0, PI / 2.0, 0))
	quad(p, 0.5, 0.25, m["bulletin"], Vector3(-1.52, 0.1, 2.1), Vector3(0, PI / 2.0, 0))
	quad(p, 0.22, 0.11, m["fuel"], Vector3(0.6, 0.0, 2.68), Vector3(0, PI, 0))
	cyl(p, 0.08, 0.08, 0.52, m["red"], Vector3(1.2, -0.95, 2.6), 12)
	_seat(p, 0.86, floor_y, 1.25, m["seat"])
	_seat(p, -0.86, floor_y, 1.25, m["seat"])
	_seat(p, -0.86, floor_y, 2.1, m["seat"])
	_mirrors(p, w / 2.0, -0.05)

# ---------------------------------------------------------------- classic AAR-stand cab
func _interior_classic(p: Node, nose_forward: bool) -> void:
	var w := 3.02
	var floor_y := -1.35
	var sill_y := -0.3
	var top_y := 0.42
	var beige: Material = m["wall_beige"]
	var gap := Vector2(0.3, -0.68) if nose_forward else Vector2.ZERO
	_shell(p, w, 2.6, floor_y, 0.62, sill_y, top_y, [-0.82, 0.82], 0.95, beige, true, gap)
	# conductor's side: the left front opening is a DOOR out to the nose walkway
	var dx := -0.82
	box(p, 0.8, sill_y - floor_y - 0.04, 0.05, m["wall_beige"], dx, (sill_y + floor_y) / 2.0, 0.07)
	for e in [[0.8, 0.03, dx, top_y - 0.02], [0.8, 0.03, dx, floor_y + 0.04]]:
		box(p, e[0], e[1], 0.06, m["rubber"], e[2], e[3], 0.07)
	box(p, 0.03, top_y - floor_y, 0.06, m["rubber"], dx - 0.4, (top_y + floor_y) / 2.0, 0.07)
	box(p, 0.03, top_y - floor_y, 0.06, m["rubber"], dx + 0.4, (top_y + floor_y) / 2.0, 0.07)
	box(p, 0.16, 0.04, 0.05, m["steel"], dx + 0.3, -0.55, 0.12)        # latch handle
	for hy in [-1.1, -0.1]:
		box(p, 0.05, 0.14, 0.04, m["steel_dark"], dx - 0.38, hy, 0.1)  # hinges
	quad(p, 0.3, 0.15, m["warn"], Vector3(dx, -0.85, 0.1), Vector3.ZERO)
	if nose_forward:
		# step down into the short hood: toilet compartment
		var nf := floor_y - 0.42
		box(p, 0.58, 0.06, 0.32, m["floor"], 0, floor_y - 0.2, -0.18)          # step
		box(p, 0.85, 0.06, 1.5, m["floor"], 0, nf, -0.85)
		box(p, 0.06, 0.95, 1.5, m["nose_dark"], -0.44, nf + 0.48, -0.85)
		box(p, 0.06, 0.95, 1.5, m["nose_dark"], 0.44, nf + 0.48, -0.85)
		box(p, 0.85, 0.95, 0.06, m["nose_dark"], 0, nf + 0.48, -1.6)
		box(p, 0.85, 0.06, 1.5, m["nose_dark"], 0, -0.66, -0.85)
		cyl(p, 0.17, 0.13, 0.38, m["porcelain"], Vector3(0, nf + 0.2, -1.25), 16)   # toilet bowl
		box(p, 0.4, 0.06, 0.42, m["porcelain"], 0, nf + 0.4, -1.25)
		box(p, 0.38, 0.4, 0.16, m["porcelain"], 0, nf + 0.6, -1.5)                   # tank
		box(p, 0.12, 0.12, 0.04, m["dome"], 0.2, -0.72, -1.2)                        # dim light
		box(p, 0.25, 0.3, 0.12, m["steel"], -0.3, nf + 0.6, -0.5)                     # paper holder / sink
	# AAR control stand to the engineer's left
	var st := pivot(p, Vector3(0.3, 0, 0.62))
	box(st, 0.36, -0.42 - floor_y, 0.55, beige, 0, (-0.42 + floor_y) / 2.0, 0)
	box(st, 0.3, 0.32, 0.5, m["console"], 0.02, -0.25, -0.02)
	quad(st, 0.48, 0.3, m["switches_beige"], Vector3(0.175, -0.25, -0.02), Vector3(0, PI / 2.0, 0))
	# gauge housing on top, turned toward the engineer and tilted up
	var gh := pivot(st, Vector3(0.06, -0.02, -0.18), Vector3(-0.32, 0.62, 0))
	box(gh, 0.62, 0.2, 0.08, m["black"], 0, 0, 0)
	gauge(gh, "g_speed", 0.075, Vector3(-0.2, 0, 0.045), ["speed"], [Color(1, 1, 1)])
	gauge(gh, "g_er", 0.075, Vector3(0, 0, 0.045), ["bp", "er"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	gauge(gh, "g_mr", 0.075, Vector3(0.2, 0, 0.045), ["mr", "bc"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	# throttle (and dynamic brake if equipped): handles stick out toward the engineer
	lever_thr = pivot(st, Vector3(0.19, -0.33, 0.0))
	box(lever_thr, 0.2, 0.022, 0.022, m["steel"], 0.1, 0, 0)
	box(lever_thr, 0.07, 0.034, 0.034, m["grip"], 0.22, 0, 0)
	if has_db:
		lever_db = pivot(st, Vector3(0.19, -0.2, 0.12))
		box(lever_db, 0.16, 0.02, 0.02, m["steel"], 0.08, 0, 0)
		ball(lever_db, 0.02, m["grip"], Vector3(0.17, 0, 0))
	box(st, 0.06, 0.03, 0.1, m["steel"], 0.2, -0.43, -0.1)                         # reverser
	var al := cyl(st, 0.03, 0.03, 0.03, m["alerter"], Vector3(0.19, -0.1, -0.2), 14)
	al.rotation.z = PI / 2.0
	_pickable(st, Vector3(0.19, -0.1, -0.2), 0.07, "alerter")
	# 26L brake valve on its pedestal, ahead-left of the engineer's seat
	var bv := pivot(p, Vector3(0.42, 0, 1.0))
	cyl(bv, 0.08, 0.1, -0.72 - floor_y, m["console"], Vector3(0, (-0.72 + floor_y) / 2.0, 0), 12)
	box(bv, 0.26, 0.14, 0.26, m["console"], 0, -0.66, 0)
	lever_auto = pivot(bv, Vector3(0, -0.57, 0))
	box(lever_auto, 0.03, 0.03, 0.3, m["steel"], 0, 0, -0.15)
	ball(lever_auto, 0.03, m["grip"], Vector3(0, 0, -0.3))
	lever_ind = pivot(bv, Vector3(0, -0.52, 0))
	box(lever_ind, 0.025, 0.025, 0.24, m["steel"], 0, 0, -0.12)
	var pk := cyl(lever_ind, 0.022, 0.022, 0.1, m["knob_pink"], Vector3(0, 0, -0.25), 10)
	pk.rotation.x = PI / 2.0
	box(p, 0.4, 0.55, 0.3, m["steel_dark"], 1.15, floor_y + 0.28, 0.35)            # cab heater
	# PTC display retrofitted onto the front wall
	var pm := pivot(p, Vector3(1.12, sill_y - 0.2, 0.12), Vector3(-0.15, -0.35, 0))
	box(pm, 0.06, 0.06, 0.1, m["steel_dark"], 0, 0, -0.05)
	screen(pm, 0.3, 0.22, Vector3(0, 0, 0.03), Vector3.ZERO, "ptc")
	_radio(p, Vector3(1.42, 0.05, 1.55), Vector3(0, -PI / 2.0, 0))
	_seat(p, 0.8, floor_y, 1.3, m["seat"])
	_seat(p, -0.8, floor_y, 1.4, m["seat"])
	_mirrors(p, w / 2.0, -0.05)

func _pickable(p: Node, pos: Vector3, r: float, action: String) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	body.add_child(cs)
	body.set_meta("action", action)
	p.add_child(body)
	pickables.append(body)

func _mirrors(p: Node, half_w: float, y: float) -> void:
	for side in [-1.0, 1.0]:
		var mg := pivot(p, Vector3(side * (half_w + 0.18), y, 0.22))
		tube(mg, Vector3(-side * 0.18, 0.26, 0), Vector3(0, 0.26, 0), 0.016, m["mirror_frame"])
		tube(mg, Vector3(-side * 0.18, -0.26, 0), Vector3(0, -0.26, 0), 0.016, m["mirror_frame"])
		var housing := box(mg, 0.14, 0.54, 0.045, m["mirror_frame"], 0, 0, 0)
		housing.rotation.y = side * -0.34
		quad(mg, 0.115, 0.5, m["mirror_glass"], Vector3(0, 0, 0.025), Vector3(0, side * -0.34, 0))

# ================================================================ per-frame
func update(s: Dictionary) -> void:
	var lever: int = s["lever"]
	var auto_h: float = s["auto_h"]
	var ind_h: float = s["ind_h"]
	var em: bool = s["emergency"]
	if model.begins_with("classic"):
		if lever_thr:
			lever_thr.rotation.y = float(maxi(lever, 0)) / 8.0 * 0.9
		if lever_db:
			lever_db.rotation.y = float(maxi(-lever - 1, 0)) / 8.0 * 0.9
		if lever_auto:
			lever_auto.rotation.y = -(1.25 if em else auto_h * 1.1)
		if lever_ind:
			lever_ind.rotation.y = -ind_h * 1.0
	else:
		if lever_thr:
			lever_thr.rotation.x = -float(lever) / 9.0 * 0.6
		if lever_auto:
			lever_auto.rotation.x = (1.0 if em else auto_h) * 0.75
		if lever_ind:
			lever_ind.rotation.x = ind_h * 0.7
	set_needle("speed", float(s["mph"]), 80.0)
	set_needle("er", s["er"], 160.0)
	set_needle("bp", s["bp"], 160.0)
	set_needle("mr", 140.0, 160.0)
	set_needle("bc", s["bc"], 160.0)
	if ui.is_empty():
		return
	var mph: int = s["mph"]
	if ui.has("e_speed"):
		ui["e_title"].text = ("LOCO 2271   " if model.begins_with("classic") else "LOCO 8062   ") + str(s["model"])
		ui["e_speed"].text = str(mph)
		ui["e_lever"].text = s["lever_name"]
		ui["e_te"].text = "%d kN" % int(s["te_kn"])
		ui["e_te_bar"].size.x = 296.0 * clampf(s["te_kn"] / 430.0, 0.0, 1.0)
		ui["e_db"].text = "%d kN" % int(s["db_kn"])
		ui["e_db_bar"].size.x = 296.0 * clampf(s["db_kn"] / 300.0, 0.0, 1.0)
		ui["e_air1"].text = "EQ RES %d   BRK PIPE %d   MAIN RES 140" % [int(s["er"]), int(s["bp"])]
		ui["e_air2"].text = "BRK CYL %d   LOCO CYL %d   FLOW %d" % [int(s["bc"]), int(s["lbc"]), int(s["flow"])]
		var flags := ""
		if em:
			flags += "EMERGENCY  "
		if s["alert"]:
			flags += "ALERTER  "
		if s["sand"]:
			flags += "SAND  "
		if s["bell"]:
			flags += "BELL"
		ui["e_flags"].text = flags
	if not ui.has("p_speed"):
		return
	ui["p_speed"].text = str(mph)
	ui["p_limit"].text = str(s["limit"])
	ui["p_mp"].text = "A-LINE SUB   MP %.1f" % float(s["mp"])
	var nft: float = s["next_ft"]
	if nft >= 0.0:
		ui["p_target"].text = s["next_kind"]
		ui["p_target2"].text = "%d FT" % int(nft)
		ui["p_bar"].size.x = 284.0 * clampf(1.0 - nft / 3300.0, 0.0, 1.0)
	else:
		ui["p_target"].text = "NONE"
		ui["p_target2"].text = ""
		ui["p_bar"].size.x = 0.0
	var ahead: Array = s["ahead"]
	var marks: Array = ui["p_marks"]
	var rows: Array = ui["p_rows"]
	for k in marks.size():
		if k < ahead.size():
			var a: Array = ahead[k]
			marks[k].visible = true
			marks[k].position.x = 10.0 + 486.0 * clampf(a[0] / 3219.0, 0.0, 1.0)
			var txt: String = a[1]
			marks[k].color = Color(0.4, 0.7, 1.0) if txt.begins_with("XING") else (Color(0.7, 0.7, 0.7) if txt.begins_with("MP") else Color(1, 0.6, 0.1))
		else:
			marks[k].visible = false
	for k in rows.size():
		if k < ahead.size():
			var a2: Array = ahead[k]
			rows[k][0].text = str(a2[1]).left(30)
			rows[k][1].text = "%s FT" % _commas(int(a2[0] * 3.281))
		else:
			rows[k][0].text = ""
			rows[k][1].text = ""
	ui["p_warn"].text = "OVERSPEED" if mph > int(s["limit"]) + 2 else ""
