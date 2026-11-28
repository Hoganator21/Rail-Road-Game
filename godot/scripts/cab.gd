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
	m["seat"] = _tri("res://textures/seat_black.png", 2.2, 0.9)
	m["wall_tan"] = _tri("res://textures/cab_wall_tan.png", 0.5, 0.82, 0.05)
	m["wall_green"] = _tri("res://textures/cab_wall_green.png", 0.5, 0.82, 0.05)
	m["stand_brown"] = _tri("res://textures/stand_brown.png", 0.7, 0.62, 0.15)
	m["stand_green"] = _tri("res://textures/stand_green.png", 0.7, 0.62, 0.15)
	m["ceil_tan"] = _tri("res://textures/ceiling_tan.png", 0.6, 0.92)
	m["ceil_green"] = _tri("res://textures/ceiling_green.png", 0.6, 0.92)
	m["bezel_tan"] = _decal("res://textures/bezel_tan.png", Vector2.ONE, Vector2.ZERO, true)
	m["bezel_green"] = _decal("res://textures/bezel_green.png", Vector2.ONE, Vector2.ZERO, true)
	for k in ["bezel_tan", "bezel_green"]:
		m[k].cull_mode = BaseMaterial3D.CULL_DISABLED
	m["fkeys"] = _decal("res://textures/fkeys.png")
	m["hv"] = _decal("res://textures/decals2.png", Vector2(0.5, 0.5), Vector2(0, 0))
	m["ebv"] = _decal("res://textures/decals2.png", Vector2(0.5, 0.5), Vector2(0.5, 0))
	m["cabsig"] = _decal("res://textures/decals2.png", Vector2(0.5, 0.5), Vector2(0, 0.5))
	m["caution"] = _decal("res://textures/decals2.png", Vector2(0.5, 0.5), Vector2(0.5, 0.5))
	m["vinyl"] = _mat(Color(0.07, 0.07, 0.075), 0.55)
	m["chrome"] = _mat(Color(0.82, 0.82, 0.8), 0.18, 1.0)
	m["cast"] = _mat(Color(0.16, 0.16, 0.17), 0.7, 0.4)
	m["radio_red"] = _mat(Color(0.82, 0.18, 0.12), 0.45)
	m["stainless"] = _mat(Color(0.72, 0.72, 0.7), 0.32, 0.85)
	m["ext_red"] = _mat(Color(0.7, 0.08, 0.06), 0.35, 0.1)
	m["leather"] = _mat(Color(0.62, 0.48, 0.32), 0.85)
	var bottle := StandardMaterial3D.new()
	bottle.albedo_color = Color(0.8, 0.9, 1.0, 0.35)
	bottle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bottle.roughness = 0.1
	m["bottle"] = bottle
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
	m["glass_dark"] = _mat(Color(0.05, 0.07, 0.09), 0.08, 0.6)
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
	var can := cyl(p, r * 1.08, r * 1.08, 0.05, m["black"], pos + Vector3(0, 0, -0.022), 24)
	can.rotation.x = PI / 2.0
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.98
	tm.outer_radius = r * 1.14
	tm.rings = 24
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = m["chrome"]
	ring.position = pos + Vector3(0, 0, 0.012)
	ring.rotation.x = PI / 2.0
	p.add_child(ring)
	var face := quad(p, r * 2.0, r * 2.0, m[mat_key], pos + Vector3(0, 0, 0.004), Vector3.ZERO)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in needle_keys.size():
		var pv := pivot(p, pos + Vector3(0, 0, 0.008 + i * 0.003))
		box(pv, r * 0.06, r * 0.78, 0.002, _unshaded(needle_cols[i]), 0, r * 0.3, 0)
		_add_needle_pivot(needle_keys[i], pv)
	var hub := cyl(p, r * 0.08, r * 0.08, 0.01, m["black"], pos + Vector3(0, 0, 0.016), 10)
	hub.rotation.x = PI / 2.0
	quad(p, r * 2.0, r * 2.0, m["gauge_glass"], pos + Vector3(0, 0, 0.02), Vector3.ZERO)

func set_needle(key: String, value: float, vmax: float) -> void:
	if not needles.has(key):
		return
	var t := clampf(value / vmax, 0.0, 1.0)
	for pv in needles[key]:
		pv.rotation.z = deg_to_rad(225.0 - 270.0 * t) - PI / 2.0

func _add_needle_pivot(key: String, pv: Node3D) -> void:
	if not needles.has(key):
		needles[key] = []
	needles[key].append(pv)

## Live needles on a gauge face from a Blender cab. The face is a disc whose local Y is its
## normal (glTF Y-up) and whose texture "up" is local -Z.
const GAUGE_NEEDLES := {"g_speed": [["speed", Color(1, 1, 1)]], "g_er": [["bp", Color(1, 1, 1)], ["er", Color(0.95, 0.15, 0.1)]],
	"g_mr": [["mr", Color(1, 1, 1)], ["bc", Color(0.95, 0.15, 0.1)]]}
func _gauge_needles(face: MeshInstance3D, kind: String) -> void:
	var ab := face.get_aabb()
	var r := maxf(ab.size.x, ab.size.z) * 0.5
	var nrm := face.transform.basis.y.normalized()
	var up := -face.transform.basis.z.normalized()
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(up.cross(nrm).normalized(), up, nrm), face.transform * ab.get_center())
	face.get_parent().add_child(holder)
	var k := 0
	for nd in GAUGE_NEEDLES[kind]:
		var pv := Node3D.new()
		pv.position = Vector3(0, 0, 0.004 + k * 0.003)
		holder.add_child(pv)
		box(pv, r * 0.06, r * 0.78, 0.002, _unshaded(nd[1]), 0, r * 0.3, 0)
		_add_needle_pivot(nd[0], pv)
		k += 1
	var hub := cyl(holder, r * 0.08, r * 0.08, 0.01, m["black"], Vector3(0, 0, 0.01), 10)
	hub.rotation.x = PI / 2.0

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
	ui["e_flags"] = _lbl(root, Vector2(12, 336), 22, Color(1, 0.4, 0.3), "")
	ui["e_consist"] = _lbl(root, Vector2(16, 182), 15, Color(0.7, 0.8, 0.9), "")
	ui["e_dpu"] = _lbl(root, Vector2(16, 204), 15, Color(0.6, 1, 0.65), "")
	ui["e_counter"] = _lbl(root, Vector2(16, 226), 17, Color(1, 0.85, 0.3), "")

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
	ui["p_train"] = _lbl(root, Vector2(10, 362), 15, Color(0.6, 0.8, 0.65), "")

# ================================================================ build
var has_db: bool = true
var pickables: Array = []

var exterior_only := false

func build(kind: String, dyn_brake: bool = true, outside_only: bool = false, lay: String = "") -> Node3D:
	exterior_only = outside_only
	layout = lay if lay != "" else (LAYOUTS[kind][0] if LAYOUTS.has(kind) else "")
	var spec := hd_spec(kind, layout)
	hd = not spec.is_empty()
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
	model_interior = false
	if (kind == "classic" or kind == "classic_lhf") and not exterior_only and hd:
		_gp38(L, kind == "classic_lhf", spec)
		return L
	if kind == "classic" or kind == "classic_lhf":
		eye = Vector3(0.78, 0.0, 1.08)
		if kind == "classic_lhf":
			_exterior_lhf(L)
		else:
			_exterior_classic(L)
		if not exterior_only:
			_interior_classic(L, kind == "classic")
		else:
			_cab_box(L, 3.02, 2.6)
	elif kind == "sd70ace":
		eye = Vector3(1.08, -0.4, 1.15) if hd else Vector3(0.86, 0.0, 1.12)
		_exterior_modern(L)
		if exterior_only:
			_cab_box(L, 3.16, 2.8)
		elif hd:
			_interior_model(L, spec)
		else:
			_interior_aar(L)
	else:
		eye = Vector3(1.08, -0.4, 1.15) if hd else Vector3(0.86, 0.0, 1.08)
		_exterior_modern(L)
		if exterior_only:
			_cab_box(L, 3.16, 2.75)
		elif hd:
			_interior_model(L, spec)
		else:
			_interior_modern(L)
	return L

## Trailing units seen from outside only need the cab's outer shell and windows.
func _cab_box(L: Node, w: float, cab_len: float) -> void:
	box(L, w, 2.05, cab_len, m["hood"], 0, -0.33, cab_len / 2.0)
	box(L, w + 0.08, 0.14, cab_len + 0.2, m["paint"], 0, 0.75, cab_len / 2.0 - 0.05)
	for x in [-0.76, 0.76]:
		box(L, 1.2, 0.75, 0.02, m["glass_dark"], x, 0.05, -0.01)
	for sx in [-1.0, 1.0]:
		box(L, 0.02, 0.7, 1.2, m["glass_dark"], sx * (w / 2.0 + 0.005), 0.05, 0.95)

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

func _long_hood(L: Node, deck_y: float, hood_w: float, r_h: float = 1.65) -> void:
	var r_len := 10.2
	var r_start := 2.75
	box(L, hood_w, r_h, r_len - 2.6, m["hood"], 0, deck_y + r_h / 2.0 + 0.06, r_start + (r_len - 2.6) / 2.0)
	box(L, hood_w + 0.7, r_h + 0.12, 2.6, m["hood"], 0, deck_y + (r_h + 0.12) / 2.0 + 0.06, r_start + r_len - 1.3)
	for z in [r_start + r_len - 1.9, r_start + r_len - 0.7]:
		cyl(L, 0.58, 0.58, 0.02, m["fan"], Vector3(0, deck_y + r_h + 0.19, z), 24)

func _exterior_modern(L: Node) -> void:
	if (model == "sd70ace" or model == "modern") and hd:
		_exterior_sd70(L)
		return
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
	_running_gear(L, deck_y, 4.8, 6.4, 3, 5.6)
	_railings(L, deck_y, -0.05, -4.05, [-1.52, 1.52], 0.45)
	_railings(L, deck_y, 2.75, 13.65, [-1.52, 1.52], 0.45)

## GP38-2: the Blender cab plus a matching exterior, built short hood forward. For long hood
## forward the whole unit (cab, hoods, trucks) is turned around so the long hood leads; the
## LHF model already has the stand and seats facing its back wall, which then faces forward.
func _gp38(L: Node, lhf: bool, spec: Dictionary) -> void:
	const CAB_LEN := 2.3
	var holder := Node3D.new()
	L.add_child(holder)
	_exterior_gp38(holder)
	_interior_model(holder, spec)
	eye = Vector3(0.8, -0.65, 1.15)
	if lhf:
		holder.rotation.y = PI
		holder.position.z = CAB_LEN

func _exterior_gp38(L: Node) -> void:
	const CAB_LEN := 2.3
	var rail := -3.75
	var deck_y := rail + 1.55
	var sh_top := -1.12
	var lh_top := -1.04
	_deck_and_ends(L, 3.04, 4.6, 13.6, deck_y)
	var hm: Material = m["hood"]
	box(L, 1.75, sh_top - deck_y, 2.95, hm, 0, (sh_top + deck_y) / 2.0, -1.56)
	box(L, 1.77, 0.05, 2.97, m["steel_dark"], 0, sh_top + 0.02, -1.56)
	box(L, 1.2, 0.18, 0.06, m["black"], 0, sh_top - 0.14, -3.05)
	for hx in [-0.18, 0.18]:
		var hl := cyl(L, 0.09, 0.09, 0.04, m["ditch"], Vector3(hx, sh_top - 0.36, -3.06), 14)
		hl.rotation.x = PI / 2.0
	cyl(L, 0.1, 0.1, 0.16, m["yellow"], Vector3(-0.45, sh_top + 0.08, -1.2), 12)
	var lh_len := 13.45 - (CAB_LEN + 0.05)
	box(L, 1.8, lh_top - deck_y, lh_len, hm, 0, (lh_top + deck_y) / 2.0, CAB_LEN + 0.05 + lh_len / 2.0)
	box(L, 1.82, 0.05, lh_len, m["steel_dark"], 0, lh_top + 0.02, CAB_LEN + 0.05 + lh_len / 2.0)
	for z in [CAB_LEN + 8.5, CAB_LEN + 10.3]:
		cyl(L, 0.55, 0.55, 0.04, m["fan"], Vector3(0, lh_top + 0.05, z), 24)
	box(L, 0.35, 0.18, 0.8, m["black"], 0, lh_top + 0.09, CAB_LEN + 4.2)
	_running_gear(L, deck_y, 4.5, 5.1, 2, 4.6)
	_railings(L, deck_y, -0.05, -4.45, [-1.46, 1.46], 0.45)
	_railings(L, deck_y, CAB_LEN + 0.15, 13.45, [-1.46, 1.46], 0.45)

## SD70ACe at the measured heights the Blender cab uses: walkway 72.5 in above the rail,
## nose top just under the windshield, long hood top just under the rear cab windows.
func _exterior_sd70(L: Node) -> void:
	var rail := -3.75
	var deck_y := rail + 1.84
	var nose_top := -0.66
	var hood_top := -0.64
	_deck_and_ends(L, 3.18, 4.2, 13.8, deck_y)
	var hm: Material = m["hood"]
	var nh := nose_top - deck_y
	box(L, 2.96, nh, 1.85, hm, 0, deck_y + nh / 2.0, -0.92)
	var slope := box(L, 2.96, 0.08, 1.5, hm, 0, nose_top - 0.12, -2.45)
	slope.rotation.x = -0.18
	box(L, 2.96, nh - 0.25, 1.4, hm, 0, deck_y + (nh - 0.25) / 2.0, -2.45)
	box(L, 2.98, 0.06, 0.08, m["steel_dark"], 0, nose_top + 0.02, -1.8)
	cyl(L, 0.14, 0.18, 0.2, m["brass"], Vector3(-0.55, nose_top - 0.05, -2.6), 16)
	box(L, 0.6, 0.18, 0.22, m["black"], 0, nose_top - 0.2, -3.13)
	for s in [-1.0, 1.0]:
		tube(L, Vector3(s * 0.95, deck_y + 0.3, -3.16), Vector3(s * 0.95, nose_top - 0.15, -3.16), 0.02, m["handrail"])
	_long_hood(L, deck_y, 1.85, hood_top - deck_y)
	_running_gear(L, deck_y, 4.8, 6.4, 3, 5.6)
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
	_running_gear(L, deck_y, 4.5, 5.1, 2, 4.6)
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
	_running_gear(L, deck_y, -5.1, 5.1, 2, 4.6)
	_railings(L, deck_y, -0.05, front_end + 0.15, [-1.46, 1.46], 0.45)
	_railings(L, deck_y, 2.75, 4.45, [-1.46, 1.46], 0.45)

## Trucks (wheels, side frames, springs, traction motors), fuel tank and air reservoirs.
## Rail top is at y = -3.75 in cab-model space.
func _running_gear(L: Node, deck_y: float, z_mid: float, truck_off: float, axles: int, tank_len: float) -> void:
	var rail := -3.75
	var wr := 0.52
	var sp := 1.95 if axles == 3 else 2.6
	for tz in [z_mid - truck_off, z_mid + truck_off]:
		var first: float = tz - sp * (axles - 1) / 2.0
		for a in axles:
			var az: float = first + a * sp
			for sx in [-0.78, 0.78]:
				var w := cyl(L, wr, wr, 0.14, m["steel_dark"], Vector3(sx, rail + wr, az), 18)
				w.rotation.z = PI / 2.0
			var axle := cyl(L, 0.09, 0.09, 1.7, m["steel_dark"], Vector3(0, rail + wr, az), 8)
			axle.rotation.z = PI / 2.0
			box(L, 0.9, 0.55, 0.7, m["steel_dark"], 0, rail + wr + 0.15, az)            # traction motor
		for sx in [-1.0, 1.0]:
			var len := sp * (axles - 1) + 1.4
			box(L, 0.16, 0.42, len, m["deck"], sx * 0.98, rail + wr + 0.08, tz)         # side frame
			for a in axles:
				var bz: float = first + a * sp
				box(L, 0.2, 0.22, 0.38, m["steel_dark"], sx * 1.02, rail + wr, bz)       # journal box
			for k in 2:
				cyl(L, 0.09, 0.09, 0.32, m["steel"], Vector3(sx * 0.98, rail + wr + 0.46, tz + (k - 0.5) * 0.7), 8)   # springs
		box(L, 2.3, 0.25, 1.2, m["deck"], 0, deck_y - 0.35, tz)                            # bolster
	# fuel tank and main air reservoirs between the trucks
	var t_top := deck_y - 0.1
	var t_bot := rail + 0.5
	var ty := (t_top + t_bot) / 2.0
	box(L, 2.5, t_top - t_bot, tank_len, m["paint"], 0, ty, z_mid)
	for e in [-1.0, 1.0]:
		var cap := cyl(L, (t_top - t_bot) / 2.0, (t_top - t_bot) / 2.0, 2.5, m["paint"], Vector3(0, ty, z_mid + e * tank_len / 2.0), 16)
		cap.rotation.z = PI / 2.0
		cap.scale = Vector3(1, 1, 0.45)
	for sx in [-1.12, 1.12]:
		var res := cyl(L, 0.2, 0.2, tank_len * 0.7, m["steel_dark"], Vector3(sx, deck_y - 0.35, z_mid), 12)
		res.rotation.x = PI / 2.0
	box(L, 0.5, 0.5, 0.3, m["black"], 1.2, ty, z_mid - tank_len * 0.2)   # fuel gauge / filler

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
var tone := "tan"   # interior paint scheme: "tan" (modern GE/EMD) or "green" (older EMD)

func _shell(p: Node, w: float, cab_len: float, floor_y: float, ceil_y: float, sill_y: float, top_y: float, win_xs: Array, win_w: float, wall: Material, rounded: bool, nose_gap: Vector2 = Vector2.ZERO) -> void:
	var half_w := w / 2.0
	box(p, w - 0.08, 0.06, cab_len, m["floor"], 0, floor_y, cab_len / 2.0)
	box(p, w + 0.08, 0.14, cab_len + 0.2, m["paint"], 0, ceil_y + 0.12, cab_len / 2.0 - 0.05)
	box(p, w - 0.1, 0.05, cab_len, m["ceil_" + tone], 0, ceil_y, cab_len / 2.0)
	for rz in [0.75, 1.55, 2.3]:          # ceiling ribs
		if rz < cab_len:
			box(p, w - 0.12, 0.03, 0.06, wall, 0, ceil_y - 0.035, rz)
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
	var wi := 0
	for x in win_xs:
		_bezel(p, Vector3(x, (sill_y + top_y) / 2.0, 0.052 + wi * 0.003), win_w, win_h, Vector3.ZERO)
		quad(p, win_w, win_h, m["glass"], Vector3(x, (sill_y + top_y) / 2.0, -0.02), Vector3.ZERO)
		# pantograph wiper hanging from above the glass (outside), parked at an angle
		var side := -1.0 if x < 0.0 else 1.0   # park along the outer edge of each windshield
		var wp := pivot(p, Vector3(x + side * win_w * 0.4, top_y + 0.02, -0.08), Vector3(0, 0, side * 0.06))
		box(wp, 0.016, win_h * 0.5, 0.012, m["black"], 0, -win_h * 0.25, 0)
		box(wp, 0.012, win_h * 0.46, 0.012, m["black"], -side * 0.05, -win_h * 0.23, 0.0)
		box(wp, 0.07, 0.025, 0.02, m["black"], 0.025, -win_h * 0.5, 0)
		var blade := box(wp, 0.022, win_h * 0.6, 0.018, m["rubber"], 0.025, -win_h * 0.5, -0.01)
		blade.rotation.z = 0.12
		box(p, 0.08, 0.06, 0.06, m["black"], x + side * win_w * 0.4, top_y + 0.02, 0.07)   # motor housing inside
		wipers.append(wp)
		wi += 1
	var side_sill := sill_y + 0.08
	for s in [-1.0, 1.0]:
		var sx: float = s * (half_w - 0.05)
		box(p, 0.1, side_sill - floor_y, cab_len, wall, sx, (side_sill + floor_y) / 2.0, cab_len / 2.0)
		box(p, 0.1, ceil_y - top_y, cab_len, wall, sx, (ceil_y + top_y) / 2.0, cab_len / 2.0)
		box(p, 0.1, top_y - side_sill, 0.3, wall, sx, (top_y + side_sill) / 2.0, 0.15)
		box(p, 0.1, top_y - side_sill, 0.12, wall, sx, (top_y + side_sill) / 2.0, 0.95)
		box(p, 0.1, top_y - side_sill, cab_len - 1.65, wall, sx, (top_y + side_sill) / 2.0, 1.65 + (cab_len - 1.65) / 2.0)
		quad(p, 1.35, top_y - side_sill, m["glass"], Vector3(sx + s * 0.04, (top_y + side_sill) / 2.0, 0.97), Vector3(0, PI / 2.0, 0))
		_bezel(p, Vector3(sx - s * 0.055, (top_y + side_sill) / 2.0, 0.97), 1.33, top_y - side_sill, Vector3(0, -s * PI / 2.0, 0))
		box(p, 0.06, 0.03, 1.2, m["stainless"], sx - s * 0.09, side_sill - 0.02, 0.97)   # window slide track
	var back_z := cab_len
	box(p, w - 0.9, ceil_y - floor_y, 0.1, wall, 0.45, (ceil_y + floor_y) / 2.0, back_z)
	box(p, 0.85, ceil_y - floor_y, 0.06, wall, -half_w + 0.47, (ceil_y + floor_y) / 2.0, back_z + 0.02)
	box(p, 0.4, 0.55, 0.02, m["rubber"], -half_w + 0.5, 0.05, back_z - 0.02)
	quad(p, 0.36, 0.5, m["glass"], Vector3(-half_w + 0.5, 0.05, back_z - 0.04), Vector3(0, PI, 0))
	box(p, 0.05, 0.05, 0.14, m["steel"], -half_w + 0.82, -0.45, back_z - 0.08)
	_overhead(p, w, ceil_y, top_y, wall)
	# padded sun visors on swing arms, tucked up under the overhead
	var vi := 0
	for vx in win_xs:
		var vp := pivot(p, Vector3(vx + (0.2 if vi == 1 else -0.2), top_y - 0.03, 0.42), Vector3(1.25 if vi == 1 else 1.0, 0, 0))
		box(vp, 0.5, 0.26, 0.03, m["vinyl"], 0, -0.13, 0)
		box(vp, 0.46, 0.22, 0.032, m["seat"], 0, -0.13, 0.001)
		tube(p, Vector3(vx + (0.2 if vi == 1 else -0.2) - 0.27, top_y - 0.03, 0.42), Vector3(vx + (0.2 if vi == 1 else -0.2) - 0.27, top_y + 0.05, 0.42), 0.008, m["steel"])
		vi += 1
	for dz in [1.0, 1.9]:
		box(p, 0.34, 0.06, 0.2, m["black"], 0.1, ceil_y - 0.04, dz)
		box(p, 0.28, 0.02, 0.15, m["dome"], 0.1, ceil_y - 0.07, dz)

## A painted frame + rubber gasket with rounded corners, sized so its hole matches (w, h).
func _bezel(p: Node, pos: Vector3, w: float, h: float, rot: Vector3) -> void:
	var b := 0.125   # border fraction of the texture (64 px of 512)
	var q := quad(p, w / (1.0 - 2.0 * b), h / (1.0 - 2.0 * b), m["bezel_" + tone], pos, rot)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The overhead console above the windshields: body + three textured sub-panels
## (event recorder / unit number + breakers / FRA sticker, fuel readout, radio).
func _overhead(p: Node, w: float, ceil_y: float, top_y: float, wall: Material) -> void:
	var bot := top_y - 0.05
	box(p, w - 0.12, ceil_y - bot, 0.45, wall, 0, (ceil_y + bot) / 2.0, 0.28)
	var face_h := ceil_y - bot + 0.1
	var fy := (ceil_y + bot) / 2.0 - 0.05
	var face := pivot(p, Vector3(0, fy, 0.52), Vector3(0.28, 0, 0))
	box(face, w - 0.12, face_h, 0.03, wall, 0, 0, -0.015)
	var tex: Texture2D = load("res://textures/overhead_" + tone + ".png")
	var px_per_m := 512.0 / face_h
	var spans := [[0.0, 560.0, -0.95], [560.0, 1330.0, 0.02], [1330.0, 2048.0, 0.98]]
	for sp in spans:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.75
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_scale = Vector3((sp[1] - sp[0]) / 2048.0, 1, 1)
		mat.uv1_offset = Vector3(sp[0] / 2048.0, 0, 0)
		var q := quad(face, (sp[1] - sp[0]) / px_per_m, face_h, mat, Vector3(sp[2], 0, 0.002), Vector3.ZERO)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# small oscillating cab fan in the engineer-side corner
	var fp := pivot(p, Vector3(w / 2.0 - 0.22, ceil_y - 0.12, 0.75), Vector3(0.3, -0.7, 0))
	box(fp, 0.24, 0.24, 0.08, m["black"], 0, 0, 0)
	var fan := cyl(fp, 0.1, 0.1, 0.01, m["fan"], Vector3(0, 0, 0.045), 18)
	fan.rotation.x = PI / 2.0
	for gi in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.025 * (gi + 1) - 0.003
		tm.outer_radius = 0.025 * (gi + 1)
		ring.mesh = tm
		ring.material_override = m["steel"]
		ring.position = Vector3(0, 0, 0.055)
		ring.rotation.x = PI / 2.0
		fp.add_child(ring)

## Round lever: tapered shaft along local +x (or +y), chrome collar, knob at the end.
func _lever_shaft(p: Node, length: float, along_y: bool, knob: Material, knob_r: float, knob_kind: String = "ball") -> void:
	var shaft := cyl(p, 0.009, 0.014, length, m["chrome"], Vector3(0, length / 2.0, 0) if along_y else Vector3(length / 2.0, 0, 0), 10)
	if not along_y:
		shaft.rotation.z = -PI / 2.0
	var c := cyl(p, 0.022, 0.022, 0.025, m["cast"], Vector3.ZERO, 14)
	if not along_y:
		c.rotation.z = PI / 2.0
	var end := Vector3(0, length, 0) if along_y else Vector3(length, 0, 0)
	if knob_kind == "ball":
		ball(p, knob_r, knob, end)
	else:   # cylindrical grip
		var g := cyl(p, knob_r, knob_r * 0.85, knob_r * 3.0, knob, end + (Vector3(0, knob_r, 0) if along_y else Vector3(knob_r, 0, 0)), 12)
		if not along_y:
			g.rotation.z = -PI / 2.0

## Cast brake-valve housing with a notched quadrant on top (handle pivots around +y).
func _brake_valve(p: Node, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var v := pivot(p, pos, Vector3(0, rot_y, 0))
	box(v, 0.2, 0.1, 0.22, m["cast"], 0, -0.05, 0)
	var dome := cyl(v, 0.09, 0.1, 0.04, m["cast"], Vector3(0, 0.02, 0), 18)
	dome.rotation.y = 0.0
	for i in 7:   # detent teeth around the quadrant
		var a := -0.2 + i * 0.22
		box(v, 0.012, 0.012, 0.02, m["chrome"], cos(a) * 0.095, 0.035, -sin(a) * 0.095)
	return v

## Wall phone / radio handset in a cradle with a coiled cord hanging down.
func _handset(p: Node, pos: Vector3, rot: Vector3, cord_len: float = 0.35) -> void:
	var h := pivot(p, pos, rot)
	box(h, 0.07, 0.2, 0.05, m["black"], 0, 0, 0)
	var hs := pivot(h, Vector3(0, 0, 0.045))
	box(hs, 0.045, 0.2, 0.035, m["vinyl"], 0, 0, 0)
	box(hs, 0.06, 0.05, 0.045, m["vinyl"], 0, 0.09, 0.008)
	box(hs, 0.06, 0.05, 0.045, m["vinyl"], 0, -0.09, 0.008)
	var n := int(cord_len / 0.012)
	for i in n:
		var t := float(i) / float(n)
		ball(h, 0.008, m["black"], Vector3(sin(t * 60.0) * 0.016, -0.12 - t * cord_len, 0.04 + cos(t * 60.0) * 0.016))

func _extinguisher(p: Node, pos: Vector3) -> void:
	cyl(p, 0.075, 0.075, 0.42, m["ext_red"], pos + Vector3(0, 0.21, 0), 14)
	ball(p, 0.075, m["ext_red"], pos + Vector3(0, 0.42, 0))
	box(p, 0.04, 0.06, 0.03, m["black"], pos.x, pos.y + 0.5, pos.z)
	box(p, 0.1, 0.012, 0.02, m["steel"], pos.x + 0.03, pos.y + 0.54, pos.z)
	quad(p, 0.08, 0.12, m["paper"], pos + Vector3(0, 0.22, 0.076), Vector3.ZERO)

func _bottle(p: Node, pos: Vector3) -> void:
	cyl(p, 0.032, 0.032, 0.2, m["bottle"], pos + Vector3(0, 0.1, 0), 12)
	cyl(p, 0.013, 0.013, 0.025, m["seat_dark"], pos + Vector3(0, 0.215, 0), 8)

func _seat(p: Node, x: float, floor_y: float, z: float, cloth: Material) -> void:
	var g := pivot(p, Vector3(x, floor_y, z))
	# pedestal: floor plate, suspension column with bellows, slide rails
	box(g, 0.42, 0.03, 0.42, m["steel_dark"], 0, 0.02, 0)
	cyl(g, 0.09, 0.11, 0.18, m["rubber"], Vector3(0, 0.12, 0), 12)
	cyl(g, 0.055, 0.055, 0.22, m["steel"], Vector3(0, 0.3, 0), 10)
	box(g, 0.4, 0.04, 0.46, m["steel_dark"], 0, 0.42, 0)
	box(g, 0.06, 0.03, 0.08, m["steel"], 0.22, 0.42, -0.2)        # adjust lever
	# cushion with rolled front edge and side bolsters
	box(g, 0.54, 0.12, 0.5, cloth, 0, 0.5, 0.01)
	var roll := cyl(g, 0.065, 0.065, 0.54, cloth, Vector3(0, 0.505, -0.235), 12)
	roll.rotation.z = PI / 2.0
	for s in [-1.0, 1.0]:
		var bol := cyl(g, 0.05, 0.05, 0.46, m["vinyl"], Vector3(s * 0.26, 0.56, 0.02), 10)
		bol.rotation.x = PI / 2.0
	# backrest (reclined), lumbar bolsters, headrest on posts
	var bk := pivot(g, Vector3(0, 0.56, 0.25), Vector3(-0.16, 0, 0))
	box(bk, 0.52, 0.68, 0.13, cloth, 0, 0.36, 0)
	box(bk, 0.56, 0.7, 0.08, m["vinyl"], 0, 0.36, 0.06)
	for s in [-1.0, 1.0]:
		var lb := cyl(bk, 0.05, 0.05, 0.6, m["vinyl"], Vector3(s * 0.25, 0.36, -0.04), 10)
		lb.rotation.z = 0.0
	var top := cyl(bk, 0.065, 0.065, 0.52, cloth, Vector3(0, 0.71, 0), 12)
	top.rotation.z = PI / 2.0
	for s in [-1.0, 1.0]:
		cyl(bk, 0.008, 0.008, 0.12, m["steel"], Vector3(s * 0.08, 0.8, 0.0), 6)
	box(bk, 0.32, 0.16, 0.1, cloth, 0, 0.9, 0.0)
	# padded armrests on hinged posts
	for s in [-1.0, 1.0]:
		var arm := cyl(g, 0.035, 0.035, 0.36, m["vinyl"], Vector3(s * 0.33, 0.76, 0.0), 10)
		arm.rotation.x = PI / 2.0
		box(g, 0.03, 0.22, 0.04, m["steel_dark"], s * 0.33, 0.66, 0.16)

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
	tone = "tan"
	_shell(p, w, 2.75, floor_y, 0.68, sill_y, top_y, [-0.76, 0.76], 1.36, m["wall_tan"], false)
	var desk_y := -0.66
	# engineer's L-shaped desk (right side)
	box(p, 1.4, desk_y - floor_y, 0.55, m["stand_brown"], 0.82, (desk_y + floor_y) / 2.0, 0.33)
	box(p, 1.44, 0.04, 0.6, m["console"], 0.82, desk_y + 0.02, 0.33)
	box(p, 0.38, desk_y - floor_y + 0.05, 0.75, m["stand_brown"], 1.33, (desk_y + floor_y) / 2.0 + 0.025, 0.95)
	box(p, 0.4, 0.04, 0.78, m["console"], 1.33, desk_y + 0.07, 0.95)
	# slanted instrument panel facing the engineer
	var panel := pivot(p, Vector3(0.82, desk_y + 0.17, 0.12), Vector3(-0.42, 0, 0))
	box(panel, 1.42, 0.36, 0.05, m["stand_brown"], 0, 0, 0)
	for fx in [-0.44, -0.07]:
		quad(panel, 0.3, 0.038, m["fkeys"], Vector3(fx, -0.155, 0.028), Vector3.ZERO)
		for hx in [-0.19, 0.19]:
			box(panel, 0.018, 0.14, 0.03, m["black"], fx + hx, 0.0, 0.04)     # screen pull handles
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
	_lever_shaft(lever_thr, 0.15, true, m["grip"], 0.022, "grip")
	var tbar := cyl(lever_thr, 0.016, 0.016, 0.09, m["grip"], Vector3(0, 0.21, 0), 12)
	tbar.rotation.z = PI / 2.0
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
	_lever_shaft(lever_auto, 0.16, true, m["knob_red"], 0.032)
	lever_ind = pivot(bs, Vector3(0, 0.03, 0.1))
	_lever_shaft(lever_ind, 0.13, true, m["chrome"], 0.028)
	quad(p, 0.22, 0.11, m["warn"], Vector3(1.53, desk_y + 0.25, 0.75), Vector3(0, -PI / 2.0, 0))
	_radio(p, Vector3(1.47, 0.05, 1.75), Vector3(0, -PI / 2.0, 0))
	_handset(p, Vector3(1.5, -0.58, 1.45), Vector3(0, -PI / 2.0, 0), 0.3)
	quad(p, 0.24, 0.12, m["cabsig"], Vector3(1.52, -0.75, 1.9), Vector3(0, -PI / 2.0, 0))
	_bottle(p, Vector3(1.22, desk_y + 0.11, 0.62))
	# conductor's desk (left) with two screens and paperwork
	box(p, 1.1, desk_y - floor_y, 0.6, m["stand_brown"], -0.92, (desk_y + floor_y) / 2.0, 0.36)
	box(p, 1.14, 0.04, 0.64, m["console"], -0.92, desk_y + 0.02, 0.36)
	var cp := pivot(p, Vector3(-0.92, desk_y + 0.2, 0.14), Vector3(-0.3, 0, 0))
	box(cp, 0.9, 0.34, 0.12, m["stand_brown"], 0, 0, -0.04)
	quad(cp, 0.28, 0.035, m["fkeys"], Vector3(-0.2, -0.145, 0.025), Vector3.ZERO)
	quad(cp, 0.28, 0.035, m["fkeys"], Vector3(0.18, -0.145, 0.025), Vector3.ZERO)
	_handset(p, Vector3(-1.5, -0.6, 1.45), Vector3(0, PI / 2.0, 0), 0.3)
	quad(p, 0.24, 0.12, m["ebv"], Vector3(-1.53, -0.75, 0.75), Vector3(0, PI / 2.0, 0))
	box(p, 0.12, 0.16, 0.1, m["red"], -1.47, -0.95, 0.75)        # conductor's emergency valve
	box(p, 0.2, 0.08, 0.14, m["leather"], -0.6, desk_y + 0.06, 0.55)   # work gloves
	screen(cp, 0.3, 0.22, Vector3(-0.2, 0.0, 0.03), Vector3.ZERO, "ptc")
	screen(cp, 0.3, 0.22, Vector3(0.18, 0.0, 0.03), Vector3.ZERO, "eng")
	quad(p, 0.22, 0.3, m["paper"], Vector3(-0.85, desk_y + 0.045, 0.5), Vector3(-PI / 2.0, 0.15, 0))
	_radio(p, Vector3(-1.45, -0.05, 1.5), Vector3(0, PI / 2.0, 0))
	quad(p, 0.5, 0.25, m["bulletin"], Vector3(-1.52, 0.1, 2.1), Vector3(0, PI / 2.0, 0))
	quad(p, 0.22, 0.11, m["fuel"], Vector3(0.6, 0.0, 2.68), Vector3(0, PI, 0))
	_extinguisher(p, Vector3(1.25, floor_y, 2.55))
	quad(p, 0.3, 0.15, m["caution"], Vector3(-1.0, 0.1, 2.69), Vector3(0, PI, 0))
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
	tone = "green"
	var beige: Material = m["wall_green"]
	var gap := Vector2(0.3, -0.68) if nose_forward else Vector2.ZERO
	_shell(p, w, 2.6, floor_y, 0.62, sill_y, top_y, [-0.82, 0.82], 0.95, beige, true, gap)
	# conductor's side: the left front opening is a DOOR out to the nose walkway
	var dx := -0.82
	box(p, 0.8, sill_y - floor_y - 0.04, 0.05, beige, dx, (sill_y + floor_y) / 2.0, 0.07)
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
	box(st, 0.36, -0.42 - floor_y, 0.55, m["stand_green"], 0, (-0.42 + floor_y) / 2.0, 0)
	quad(st, 0.16, 0.08, m["hv"], Vector3(0.181, -0.85, 0.05), Vector3(0, PI / 2.0, 0))
	box(st, 0.3, 0.32, 0.5, m["console"], 0.02, -0.25, -0.02)
	quad(st, 0.48, 0.3, m["switches_beige"], Vector3(0.175, -0.25, -0.02), Vector3(0, PI / 2.0, 0))
	# gauge housing on top, turned toward the engineer and tilted up
	var gh := pivot(st, Vector3(0.06, -0.02, -0.18), Vector3(-0.32, 0.62, 0))
	box(gh, 0.62, 0.2, 0.08, m["black"], 0, 0, 0)
	gauge(gh, "g_speed", 0.075, Vector3(-0.2, 0, 0.045), ["speed"], [Color(1, 1, 1)])
	gauge(gh, "g_er", 0.075, Vector3(0, 0, 0.045), ["bp", "er"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	gauge(gh, "g_mr", 0.075, Vector3(0.2, 0, 0.045), ["mr", "bc"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	# throttle (and dynamic brake if equipped): handles stick out toward the engineer
	_notch_plate(st, Vector3(0.185, -0.33, 0.0))
	lever_thr = pivot(st, Vector3(0.19, -0.33, 0.0))
	_lever_shaft(lever_thr, 0.18, false, m["grip"], 0.02, "grip")
	if has_db:
		lever_db = pivot(st, Vector3(0.19, -0.2, 0.12))
		_lever_shaft(lever_db, 0.15, false, m["grip"], 0.022)
	box(st, 0.06, 0.03, 0.1, m["steel"], 0.2, -0.43, -0.1)                         # reverser
	var al := cyl(st, 0.03, 0.03, 0.03, m["alerter"], Vector3(0.19, -0.1, -0.2), 14)
	al.rotation.z = PI / 2.0
	_pickable(st, Vector3(0.19, -0.1, -0.2), 0.07, "alerter")
	# 26L brake valve on its pedestal, ahead-left of the engineer's seat
	var bv := pivot(p, Vector3(0.42, 0, 1.0))
	cyl(bv, 0.07, 0.11, -0.72 - floor_y, m["stand_green"], Vector3(0, (-0.72 + floor_y) / 2.0, 0), 14)
	_brake_valve(bv, Vector3(0, -0.62, 0))
	lever_auto = pivot(bv, Vector3(0, -0.57, 0))
	var la := pivot(lever_auto, Vector3.ZERO, Vector3(0, PI / 2.0, 0))
	_lever_shaft(la, 0.3, false, m["grip"], 0.03)
	lever_ind = pivot(bv, Vector3(0, -0.52, 0))
	var li := pivot(lever_ind, Vector3.ZERO, Vector3(0, PI / 2.0, 0))
	_lever_shaft(li, 0.24, false, m["knob_pink"], 0.02, "grip")
	box(p, 0.4, 0.55, 0.3, m["steel_dark"], 1.15, floor_y + 0.28, 0.35)            # cab heater
	# PTC display retrofitted onto the front wall
	var pm := pivot(p, Vector3(1.12, sill_y - 0.2, 0.12), Vector3(-0.15, -0.35, 0))
	box(pm, 0.06, 0.06, 0.1, m["steel_dark"], 0, 0, -0.05)
	screen(pm, 0.3, 0.22, Vector3(0, 0, 0.03), Vector3.ZERO, "ptc")
	_radio(p, Vector3(1.42, 0.05, 1.55), Vector3(0, -PI / 2.0, 0))
	_handset(st, Vector3(0.19, -0.6, 0.2), Vector3(0, PI / 2.0, 0), 0.3)
	# conductor's side: stainless desk top, emergency valve, extinguisher
	box(p, 0.7, 0.04, 0.45, m["stainless"], -1.05, -0.62, 1.0)
	box(p, 0.66, -0.64 - floor_y, 0.42, m["stand_green"], -1.05, (-0.64 + floor_y) / 2.0, 1.0)
	quad(p, 0.3, 0.15, m["ebv"], Vector3(-1.05, -0.95, 0.785), Vector3.ZERO)
	tube(p, Vector3(-0.7, -0.62, 0.78), Vector3(-0.7, -1.3, 0.78), 0.02, m["stainless"])
	_extinguisher(p, Vector3(1.2, floor_y, 2.35))
	_bottle(p, Vector3(-1.2, -0.6, 1.05))
	_seat(p, 0.8, floor_y, 1.3, m["seat"])
	_seat(p, -0.8, floor_y, 1.4, m["seat"])
	_mirrors(p, w / 2.0, -0.05)

## Throttle notch quadrant: a curved plate with 9 detents, mounted on a stand face (+x).
func _notch_plate(p: Node, pos: Vector3) -> void:
	box(p, 0.012, 0.06, 0.26, m["cast"], pos.x, pos.y, pos.z - 0.02)
	for i in 9:
		var a := float(i) / 8.0 * 0.9
		box(p, 0.02, 0.018, 0.008, m["chrome"], pos.x + 0.012 + cos(a) * 0.0, pos.y + 0.035, pos.z - sin(a) * 0.12 + 0.02)

# ---------------------------------------------------------------- EMD wide cab with an AAR control stand (SD70ACe)
func _interior_aar(p: Node) -> void:
	var w := 3.16
	var floor_y := -1.35
	var sill_y := -0.42
	var top_y := 0.45
	tone = "tan"
	_shell(p, w, 2.8, floor_y, 0.68, sill_y, top_y, [-0.76, 0.76], 1.36, m["wall_tan"], false)
	var brown: Material = m["stand_brown"]
	# AAR stand ahead-left of the engineer, controls on its right (+x) face
	var st := pivot(p, Vector3(0.3, 0, 0.78))
	var top := -0.36
	box(st, 0.4, top - floor_y, 0.62, brown, 0, (top + floor_y) / 2.0, 0)
	box(st, 0.42, 0.03, 0.64, m["cast"], 0, top + 0.015, 0)
	# gauge housing on top, angled toward the engineer
	var gh := pivot(st, Vector3(0.05, top + 0.12, -0.18), Vector3(-0.35, 0.55, 0))
	box(gh, 0.5, 0.2, 0.1, brown, 0, 0, -0.03)
	gauge(gh, "g_speed", 0.062, Vector3(-0.16, 0, 0.025), ["speed"], [Color(1, 1, 1)])
	gauge(gh, "g_er", 0.062, Vector3(0, 0, 0.025), ["bp", "er"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	gauge(gh, "g_mr", 0.062, Vector3(0.16, 0, 0.025), ["mr", "bc"], [Color(1, 1, 1), Color(0.95, 0.15, 0.1)])
	# red radio + keypad box on top of the stand (like the SD60E/SD70 photos)
	var rr := pivot(st, Vector3(-0.08, top + 0.06, 0.2), Vector3(0, 0.5, 0))
	box(rr, 0.22, 0.09, 0.15, m["radio_red"], 0, 0, 0)
	box(rr, 0.09, 0.03, 0.005, m["lcd"], -0.04, 0.02, 0.076)
	for i in 4:
		box(rr, 0.018, 0.014, 0.01, m["black"], 0.04 + (i % 2) * 0.026, 0.02 - (i / 2) * 0.022, 0.075)
	# throttle / dynamic brake / reverser on the right face
	var fx := 0.2
	_notch_plate(st, Vector3(fx - 0.005, -0.5, -0.05))
	lever_thr = pivot(st, Vector3(fx, -0.5, -0.05))
	_lever_shaft(lever_thr, 0.17, false, m["grip"], 0.02, "grip")
	lever_db = pivot(st, Vector3(fx, -0.42, 0.12))
	_lever_shaft(lever_db, 0.14, false, m["grip"], 0.022)
	var rv := pivot(st, Vector3(fx, -0.62, -0.2))
	_lever_shaft(rv, 0.09, false, m["black"], 0.018)
	quad(st, 0.34, 0.18, m["switches"], Vector3(fx + 0.002, -0.85, 0.0), Vector3(0, PI / 2.0, 0))
	quad(st, 0.14, 0.07, m["hv"], Vector3(fx + 0.002, -1.05, 0.15), Vector3(0, PI / 2.0, 0))
	# CCB brake valves on a shelf on the right face, below the throttle
	var shelf := pivot(st, Vector3(fx + 0.1, -0.7, 0.0))
	box(shelf, 0.2, 0.04, 0.5, m["cast"], 0, -0.02, 0)
	_brake_valve(shelf, Vector3(0, 0.07, -0.1))
	lever_auto = pivot(shelf, Vector3(0, 0.11, -0.1))
	_lever_shaft(lever_auto, 0.2, false, m["knob_red"], 0.028)
	_brake_valve(shelf, Vector3(0, 0.07, 0.15))
	lever_ind = pivot(shelf, Vector3(0, 0.11, 0.15))
	_lever_shaft(lever_ind, 0.16, false, m["chrome"], 0.024)
	# alerter + bell/sand buttons
	_handset(st, Vector3(0, -0.6, 0.33), Vector3.ZERO, 0.35)
	# engineer's front desk with two displays (PTC + engine)
	var desk_y := -0.6
	box(p, 1.0, desk_y - floor_y, 0.5, brown, 1.0, (desk_y + floor_y) / 2.0, 0.3)
	box(p, 1.04, 0.04, 0.54, m["console"], 1.0, desk_y + 0.02, 0.3)
	var dp := pivot(p, Vector3(1.0, desk_y + 0.2, 0.12), Vector3(-0.35, 0, 0))
	box(dp, 0.94, 0.34, 0.1, brown, 0, 0, -0.03)
	screen(dp, 0.32, 0.24, Vector3(-0.2, 0.01, 0.03), Vector3.ZERO, "eng")
	screen(dp, 0.32, 0.24, Vector3(0.21, 0.01, 0.03), Vector3.ZERO, "ptc")
	quad(dp, 0.3, 0.036, m["fkeys"], Vector3(-0.2, -0.15, 0.025), Vector3.ZERO)
	quad(dp, 0.3, 0.036, m["fkeys"], Vector3(0.21, -0.15, 0.025), Vector3.ZERO)
	# alerter reset: yellow push button on the front edge of the desk, right under the screens
	box(p, 0.12, 0.03, 0.09, m["cast"], 0.6, desk_y + 0.055, 0.46)
	cyl(p, 0.032, 0.032, 0.03, m["alerter"], Vector3(0.6, desk_y + 0.085, 0.46), 16)
	_pickable(p, Vector3(0.6, desk_y + 0.085, 0.46), 0.07, "alerter")
	_bottle(p, Vector3(1.35, desk_y + 0.04, 0.45))
	quad(p, 0.22, 0.3, m["paper"], Vector3(0.8, desk_y + 0.045, 0.42), Vector3(-PI / 2.0, -0.2, 0))   # track warrant
	_radio(p, Vector3(1.47, 0.05, 1.8), Vector3(0, -PI / 2.0, 0))
	quad(p, 0.24, 0.12, m["cabsig"], Vector3(1.52, -0.75, 1.9), Vector3(0, -PI / 2.0, 0))
	# conductor's desk
	box(p, 1.1, -0.66 - floor_y, 0.6, brown, -0.92, (-0.66 + floor_y) / 2.0, 0.36)
	box(p, 1.14, 0.04, 0.64, m["console"], -0.92, -0.64, 0.36)
	var cp := pivot(p, Vector3(-0.92, -0.46, 0.14), Vector3(-0.3, 0, 0))
	box(cp, 0.9, 0.34, 0.12, brown, 0, 0, -0.04)
	screen(cp, 0.3, 0.22, Vector3(-0.2, 0.0, 0.03), Vector3.ZERO, "ptc")
	quad(cp, 0.28, 0.035, m["fkeys"], Vector3(-0.2, -0.145, 0.025), Vector3.ZERO)
	quad(p, 0.22, 0.3, m["paper"], Vector3(-0.85, -0.615, 0.5), Vector3(-PI / 2.0, 0.15, 0))
	_handset(p, Vector3(-1.5, -0.6, 1.45), Vector3(0, PI / 2.0, 0), 0.3)
	quad(p, 0.24, 0.12, m["ebv"], Vector3(-1.53, -0.75, 0.75), Vector3(0, PI / 2.0, 0))
	box(p, 0.12, 0.16, 0.1, m["red"], -1.47, -0.95, 0.75)
	_extinguisher(p, Vector3(1.25, floor_y, 2.6))
	_seat(p, 0.86, floor_y, 1.3, m["seat"])
	_seat(p, -0.86, floor_y, 1.25, m["seat"])
	_seat(p, -0.86, floor_y, 2.15, m["seat"])
	_mirrors(p, w / 2.0, -0.05)

## The Blender cabs put the eye 3.35 m above the rail (real SD70ACe); the old builder used 3.75.
const MODEL_DROP := -0.4

## Cab interiors designed in Blender (tools/cabdesign) and exported as glTF with baked
## occlusion + wear maps. Each spec names the model, how far to drop it so its rail height
## matches the game's (Blender cabs use measured heights), which nodes form each handle,
## which quads show live screens, and the alerter button.
const STAND_LEVERS := {"thr": ["throttle_shaft", "throttle_grip"], "db": ["dynbrake_shaft", "dynbrake_knob"],
	"auto": ["brake0_shaft", "brake0_knob"], "ind": ["brake1_shaft", "brake1_knob"]}
const DESK_LEVERS := {"thr": ["dt_thr", "dt_thr_grip"], "db": [],
	"auto": ["dt_auto", "dt_auto_k"], "ind": ["dt_ind", "dt_ind_k"]}
const GE_LEVERS := {"thr": ["ge_lever0", "ge_grip0"], "db": ["ge_lever1", "ge_grip1"],
	"auto": ["ccb_auto", "ccb_auto_k"], "ind": ["ccb_ind", "ccb_ind_k"]}
const GP_LEVERS := {"thr": ["st_thr", "st_thr_g"], "db": ["st_db", "st_db_k"],
	"auto": ["b26_auto", "b26_auto_k"], "ind": ["b26_ind", "b26_ind_k"]}
const CAB_SPECS := {
	"sd70ace:stand": {"path": "res://models/sd70ace_stand.glb", "drop": -0.4, "levers": STAND_LEVERS, "axis": "y",
		"screens": {"screen0": "eng", "screen1": "ptc", "cscreen": "ptc"}, "alerter": "alerter"},
	"sd70ace:desktop": {"path": "res://models/sd70ace_desktop.glb", "drop": -0.4, "levers": DESK_LEVERS, "axis": "x",
		"screens": {"dt_screen0": "eng", "dt_screen1": "ptc", "cscreen": "ptc"}, "alerter": "alerter"},
	"modern:ge": {"path": "res://models/es44ac_ge.glb", "drop": -0.4, "levers": GE_LEVERS, "axis": "y",
		"screens": {"smart_scr0": "eng", "smart_scr1": "ptc", "wab_scr": "ptc", "cscreen": "ptc"}, "alerter": "desk_btn1"},
	"modern:desktop": {"path": "res://models/es44ac_desktop.glb", "drop": -0.4, "levers": DESK_LEVERS, "axis": "x",
		"screens": {"dt_screen0": "eng", "dt_screen1": "ptc", "cscreen": "ptc"}, "alerter": "alerter"},
	"classic": {"path": "res://models/gp38_factory.glb", "drop": -0.65, "levers": GP_LEVERS, "axis": "y",
		"screens": {}, "alerter": "st_alerter"},
	"classic_lhf": {"path": "res://models/gp38_factory_lhf.glb", "drop": -0.65, "levers": GP_LEVERS, "axis": "y",
		"screens": {}, "alerter": "st_alerter"},
}
## Cab layouts the player can pick per locomotive (first = default). GP38 options are paint schemes.
const LAYOUTS := {"sd70ace": ["stand", "desktop"], "modern": ["ge", "desktop"], "classic": ["factory", "repaint"], "classic_lhf": ["factory", "repaint"]}
const LAYOUT_NAMES := {"stand": "AAR CONTROL STAND", "desktop": "DESKTOP CONSOLE", "ge": "GE CONTROL STAND", "factory": "EMD FACTORY TAN", "repaint": "GREEN REPAINT"}
var layout := ""
var lever_axis := "y"

## Spec for this locomotive + layout, or {} if that HD cab isn't installed (then the built-in cab is used).
func hd_spec(kind: String, lay: String) -> Dictionary:
	var key := kind if kind.begins_with("classic") else kind + ":" + lay
	if not CAB_SPECS.has(key):
		key = kind + ":" + LAYOUTS[kind][0] if LAYOUTS.has(kind) else kind
	if not CAB_SPECS.has(key):
		return {}
	var sp: Dictionary = CAB_SPECS[key]
	return sp if ResourceLoader.exists(sp["path"]) else {}

var model_interior := false
var hd := false

func _interior_model(p: Node, spec: Dictionary) -> void:
	model_interior = true
	var path: String = spec["path"]
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	inst.position.y = spec["drop"]
	p.add_child(inst)
	# handles: each one's pieces go under a pivot at the base of its shaft so update() can swing it
	lever_axis = spec["axis"]
	var piv := {}
	var levers: Dictionary = spec["levers"]
	for key in ["thr", "db", "auto", "ind"]:
		var names: Array = levers[key]
		if names.is_empty():
			continue
		var shaft := inst.find_child(names[0], true, false) as MeshInstance3D
		if shaft == null:
			continue
		var st := _xform_to(shaft, p)
		var base := st * Vector3(0.0, shaft.get_aabb().position.y, 0.0)
		var pv := pivot(p, base)
		piv[key] = pv
		for nm in names:
			var n := inst.find_child(nm, true, false) as Node3D
			if n == null:
				continue
			var t := _xform_to(n, p)
			n.get_parent().remove_child(n)
			pv.add_child(n)
			n.transform = pv.transform.affine_inverse() * t
	lever_thr = piv.get("thr")
	lever_db = piv.get("db") if has_db else null
	lever_auto = piv.get("auto")
	lever_ind = piv.get("ind")
	_ao_tex = load(path.replace(".glb", "_ao.png"))
	_wear_tex = load(path.replace(".glb", "_wear.png")) if ResourceLoader.exists(path.replace(".glb", "_wear.png")) else null
	_fix_materials(inst)
	# hand the textured screens over to the live displays
	var screens: Dictionary = spec["screens"]
	for k in screens:
		var n := inst.find_child(k, true, false)
		if n is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture = _screen_tex(p, screens[k])
			n.material_override = mat
	var al := inst.find_child(spec["alerter"], true, false) as Node3D
	if al:
		_pickable(p, _xform_to(al, p).origin, 0.07, "alerter")

var _ao_tex: Texture2D
var _wear_tex: Texture2D
var _wear_shader: Shader = preload("res://shaders/cab_wear.gdshader")

## [edge wear, grime, worn tint, bare metal] for each Blender material name.
func _wear_profile(name: String) -> Array:
	var n := name.get_slice(".", 0)
	match n:
		"wall", "ceil": return [0.45, 0.55, 1.3, 0.0]
		"stand": return [1.0, 0.6, 1.7, 0.35, 0.2]
		"console": return [1.0, 0.5, 2.6, 0.5, 0.22]
		"floor": return [0.3, 0.8, 1.6, 0.0]
		"seat": return [0.5, 0.45, 1.5, 0.0, 0.08]
		"vinyl": return [0.7, 0.4, 2.2, 0.0, 0.1]
		"cast", "black", "rubber", "grip": return [0.7, 0.35, 2.0, 0.4, 0.14]
		"red", "red_radio", "yellow": return [0.6, 0.5, 1.4, 0.4]
	return []

func _wear_material(sm: StandardMaterial3D) -> ShaderMaterial:
	var p: Array = _wear_profile(sm.resource_name)
	var w := ShaderMaterial.new()
	w.shader = _wear_shader
	var albedo_tex := sm.albedo_texture
	var albedo_col := sm.albedo_color
	var nm := sm.resource_name.get_slice(".", 0)
	if layout == "repaint":
		# the green repaint reuses the factory model with different paint
		if nm == "wall":
			albedo_tex = load("res://textures/cab_wall_green.png")
		elif nm == "ceil":
			albedo_tex = load("res://textures/ceiling_green.png")
		elif nm == "stand":
			albedo_col = Color(0.22, 0.22, 0.23)
	if albedo_tex:
		w.set_shader_parameter("albedo_tex", albedo_tex)
	w.set_shader_parameter("albedo_color", albedo_col)
	if sm.normal_enabled and sm.normal_texture:
		w.set_shader_parameter("normal_tex", sm.normal_texture)
		w.set_shader_parameter("has_normal", true)
		w.set_shader_parameter("normal_strength", sm.normal_scale)
	if sm.roughness_texture:
		w.set_shader_parameter("rough_tex", sm.roughness_texture)
	w.set_shader_parameter("roughness", sm.roughness)
	w.set_shader_parameter("metallic", sm.metallic)
	w.set_shader_parameter("ao_tex", _ao_tex)
	w.set_shader_parameter("wear_tex", _wear_tex)
	w.set_shader_parameter("edge_amount", p[0])
	w.set_shader_parameter("grime_amount", p[1])
	w.set_shader_parameter("worn_tint", Vector3(p[2], p[2], p[2]))
	w.set_shader_parameter("worn_metal", p[3])
	w.set_shader_parameter("worn_floor", p[4] if p.size() > 4 else 0.0)
	return w

## Glass comes out of glTF opaque; replace it. Let the baked occlusion darken direct light too
## (corners, under the desks), which is most of what makes the cab read as a real enclosed space.
func _fix_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat == null:
				continue
			var mname := mat.resource_name.get_slice(".", 0)
			if GAUGE_NEEDLES.has(mname):
				_gauge_needles(mi, mname)
			if mat.resource_name.begins_with("glass") or mi.name.contains("glass") or mi.name.begins_with("windshield"):
				mi.set_surface_override_material(i, m["glass"])
			elif mat is StandardMaterial3D and _wear_tex and mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_TEX_UV2 and _wear_profile(mat.resource_name).size() > 0:
				mi.set_surface_override_material(i, _wear_material(mat as StandardMaterial3D))
			elif mat is StandardMaterial3D:
				var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				if _ao_tex and mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_TEX_UV2:
					sm.ao_enabled = true
					sm.ao_texture = _ao_tex
					sm.ao_on_uv2 = true
					sm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
					sm.ao_light_affect = 0.8
				sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mi.set_surface_override_material(i, sm)
	for c in n.get_children():
		_fix_materials(c)

## Transform of n relative to ancestor a (works before the nodes are in the scene tree).
func _xform_to(n: Node3D, a: Node) -> Transform3D:
	var t := n.transform
	var q := n.get_parent()
	while q != null and q != a:
		if q is Node3D:
			t = (q as Node3D).transform * t
		q = q.get_parent()
	return t

## The live screen texture for a kind, creating its viewport the first time.
func _screen_tex(p: Node, kind: String) -> Texture2D:
	if not _vp_tex.has(kind):
		screen(p, 0.01, 0.01, Vector3(0, -50, 0), Vector3.ZERO, kind)
	return _vp_tex[kind]

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
	if (model != "modern" or model_interior) and lever_axis == "y":
		if lever_thr:
			lever_thr.rotation.y = float(maxi(lever, 0)) / 8.0 * 0.9
		if lever_db:
			lever_db.rotation.y = float(maxi(-lever - 1, 0)) / 8.0 * 0.9
		if lever_auto:
			lever_auto.rotation.y = -(1.25 if em else auto_h * 1.1)
		if lever_ind:
			lever_ind.rotation.y = -ind_h * 1.0
	elif model_interior:
		# desktop handles push forward (toward the windshield) to notch up / apply
		if lever_thr:
			lever_thr.rotation.x = -float(lever) / 9.0 * 0.55
		if lever_auto:
			lever_auto.rotation.x = -(1.0 if em else auto_h) * 0.7
		if lever_ind:
			lever_ind.rotation.x = -ind_h * 0.6
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
		ui["e_title"].text = ("LOCO 2236   " if model.begins_with("classic") else "LOCO 4417   ") + str(s["model"])
		ui["e_speed"].text = str(mph)
		ui["e_lever"].text = s["lever_name"]
		ui["e_te"].text = "%d kN" % int(s["te_kn"])
		ui["e_te_bar"].size.x = 296.0 * clampf(s["te_kn"] / maxf(1.0, s["te_max_kn"]), 0.0, 1.0)
		ui["e_db"].text = "%d kN" % int(s["db_kn"])
		ui["e_db_bar"].size.x = 296.0 * clampf(s["db_kn"] / maxf(1.0, s["db_max_kn"]), 0.0, 1.0)
		ui["e_consist"].text = s["consist"]
		ui["e_dpu"].text = "" if s["dpu"] == "none" else "DPU %s: SYNC" % str(s["dpu"]).to_upper()
		var cm: int = s["counter"]
		ui["e_counter"].text = "" if cm == 0 else ("REAR CLEARS %s FT" % _commas(s["counter_ft"]) if (cm == 1 and s["counter_ft"] > 0) else ("REAR CLEAR" if cm == 1 else "COUNT %s FT" % _commas(s["counter_ft"])))
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
	ui["p_warn"].text = "OVERSPEED" if mph > int(s["limit"]) + 2 else ("REAR ON TURNOUT 25" if s["rear_turnout"] else "")
	ui["p_train"].text = "TRAIN " + str(s["consist"])
