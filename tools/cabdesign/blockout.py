"""Gray-box SD70ACe cab layout for proportion review. Units: inches (converted to metres).
x: left(-) to right(+, engineer side); y: front wall at 0 (at the sill), back is negative; z: up from cab floor.
Usage: python blockout.py -- OUTDIR
"""
import bpy, bmesh, sys, math
from mathutils import Vector
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/blk"
MODEL = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else "sd70ace"
EXPORT = "export" in sys.argv        # write the lite cab .glb (OUT is the file path) instead of review renders
LHF = "lhf" in sys.argv              # GP38 long hood forward: furniture turned to face the back wall
HD = "hd" in sys.argv                # HD cab: same frame + textured materials, detailed seats/stand/fittings, baked AO + wear
REPAINT = "repaint" in sys.argv
I = 0.0254

# ---- dimensions (inches) ----
W = 112.0            # inside wall to wall
HW = W / 2
L = 100.0            # front wall (at sill) to back wall
CEIL_C, CEIL_S, SLOPE_RUN = 80.0, 72.0, 18.0
SILL = 45.0          # bottom of windshield glass above the floor
RAKE = 15.0          # windshields lean back this many degrees from vertical
WIN_W = 46.0         # visible glass width inside (51.5 measured outside incl. gasket)
WIN_H_IN, WIN_H_OUT = 20.0, 16.0   # pane height at the centre post vs at the outer edge (peaked)
POST = 6.5
DESK_H, DESK_D = 31.5, 22.0
HOOD_H = 42.0
DOOR_C, DOOR_W, WELL_D = -7.0, 22.0, 26.0       # nose door/stairwell, slightly toward the conductor side
STAND_D, STAND_H = 17.0, 37.0
STAND_Y0, STAND_Y1 = -3.0, -39.0                # front-to-back along the engineer's left
SEAT_W, SEAT_D, SEAT_H = 20.0, 18.0, 20.0
SEAT_CX = None
VEE = 6.0            # seen from above: centre post furthest forward, outer edges swept back
WIN_LIFT, WIN_R = 1.5, 5.0                      # outer bottom corner lift, corner radius (teardrop)
SW_BOT, SW_TOP = 42.0, 68.0
SIDE_PANES = [(-18, -36), (-38, -56), (-57, -75), (-78, -94)]   # (front y, rear y); panes 1-2 slide
OVER_D, OVER_DROP = 18.0, 6.0
SCREENS = "FIRE"
SLIDE = (1, 2)       # which side panes are the sliding pair
SEAT_FRONT = None

if MODEL == "es44":
    # GE Evolution safety cab: wider inside, shorter front-to-back, lower glare shield,
    # squarer windshields, big GE stand joined to the desk, two-pane slider + narrow front pane
    W, L = 114.0, 96.0
    HW = W / 2
    CEIL_S = 74.0
    SILL, RAKE, VEE = 39.0, 16.0, 4.0
    WIN_W, WIN_H_IN, WIN_H_OUT, WIN_LIFT, WIN_R = 46.0, 18.0, 18.0, 0.0, 4.0
    POST = 5.5
    DESK_H, DESK_D = 31.0, 24.0
    HOOD_H = SILL + 2
    STAND_D, STAND_H = 20.0, 44.0
    STAND_Y0, STAND_Y1 = -2.0, -42.0
    SEAT_CX = HW - 21.0
    SW_BOT, SW_TOP = 38.0, 60.0
    SIDE_PANES = [(-8, -20), (-25, -48), (-49, -72)]
    OVER_D, OVER_DROP = 22.0, 10.0
    SCREENS = "IFD"

if MODEL == "gp38":
    # EMD Spartan cab: narrow nose, flat upright front wall with two separate windshields,
    # no desks; freestanding AAR stand set diagonally at the engineer's left front
    W, L = 110.0, 78.0
    HW = W / 2
    CEIL_C, CEIL_S = 80.0, 74.0
    SILL, RAKE, VEE = 40.0, 0.0, 0.0
    WIN_W, WIN_H_IN, WIN_H_OUT, WIN_LIFT, WIN_R = 24.0, 22.0, 22.0, 0.0, 3.5
    POST = 6.0                                  # two centre windshields over the short hood
    OUT_X0, OUT_X1, OUT_Z0, OUT_Z1 = 35.0, 51.0, 34.0, 64.0   # outer windows beside the nose
    DOOR_C, DOOR_W, WELL_D = 0.0, 24.0, 14.0    # nose hatch, one awkward step down
    SEAT_CX, SEAT_FRONT = HW - 22.0, 37.0
    SW_BOT, SW_TOP = 40.0, 62.0
    SIDE_PANES = [(-14, -37), (-37, -60)]
    SLIDE = (0, 1)
    OVER_D, OVER_DROP = 8.0, 5.0
    SCREENS = ""

STAND_X0 = DOOR_C + DOOR_W / 2 + 1.0            # stand starts just right of the stairwell
DESK_X0 = STAND_X0 + STAND_D                    # engineer desk spans from stand to right wall
if SEAT_CX is None:
    SEAT_CX = (DESK_X0 + HW) / 2 + 1
if SEAT_FRONT is None:
    SEAT_FRONT = DESK_D + 13.0
EYE_Z = SEAT_H + 31.0
TAN = math.tan(math.radians(RAKE))
TANV = math.tan(math.radians(VEE))

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
scene = bpy.context.scene
COL = {}

ROLE = {}
FURN = [False]

def mat(name, rgb):
    key = tuple(round(c, 3) for c in rgb)
    nm = ROLE.get(key, "c%02x%02x%02x" % tuple(int(c * 255) for c in rgb))
    if nm not in COL:
        m = bpy.data.materials.new(nm)
        m.diffuse_color = (*rgb, 1)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            lin = tuple((c / 12.92) if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)   # display colour -> linear
            bsdf.inputs["Base Color"].default_value = (*lin, 1)
            bsdf.inputs["Roughness"].default_value = 0.6 if nm != "screen" else 0.3
            if nm in ("steel", "chrome"):
                bsdf.inputs["Metallic"].default_value = 0.8
        COL[nm] = m
    return COL[nm]

def finish(o, name, rgb):
    o.name = name
    o.data.materials.append(mat(name, rgb))
    o["furn"] = FURN[0]
    return o

def bevel(o, r=0.35):
    """Soft rounded edges for the lite look (furniture only; walls stay crisp)."""
    if FURN[0]:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = r * I
        b.segments = 2
        b.limit_method = "ANGLE"
    return o

def box(name, x0, x1, y0, y1, z0, z1, rgb=(0.7, 0.7, 0.7)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = ((x1 - x0) * I, (y1 - y0) * I, (z1 - z0) * I)
    o.location = ((x0 + x1) / 2 * I, (y0 + y1) / 2 * I, (z0 + z1) / 2 * I)
    finish(o, name, rgb)
    return bevel(o, min(0.6, (x1 - x0) / 4, (y1 - y0) / 4, (z1 - z0) / 4))

CUTTERS = []

def cutter(pts, depth_vec):
    """Prism that punches a window opening through walls and gasket plates."""
    o = prism("cut%d" % len(CUTTERS), pts, depth_vec, (1, 0, 1))
    o.hide_render = True
    o.display_type = "WIRE"
    o["cutter"] = True
    CUTTERS.append(o)
    return o

def cut_box(x0, x1, y0, y1, z0, z1):
    return cutter([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, y1 - y0, 0))

def lever(shaft_name, grip_name, P, d, length, z, rgb_knob=(0.08, 0.08, 0.08)):
    """Handle that swings about a vertical shaft at P (x,y inches) at height z; grip points along d."""
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45 * I, depth=2.2 * I, vertices=12,
                                        location=(P[0] * I, P[1] * I, (z + 0.5) * I))
    finish(bpy.context.object, shaft_name, (0.55, 0.55, 0.57))
    a = math.atan2(d[1], d[0])
    bpy.ops.mesh.primitive_cube_add(size=1)
    g = bpy.context.object
    g.scale = (length * I, 0.9 * I, 0.9 * I)
    g.rotation_euler.z = a
    g.location = ((P[0] + d[0] * length / 2) * I, (P[1] + d[1] * length / 2) * I, (z + 1.2) * I)
    finish(g, grip_name, rgb_knob)
    bevel(g, 0.3)

def screen_plane(name, c, w, h, tilt=0.0, yaw=0.0):
    """Live display quad (UV 0..1, upright), facing the rear (toward the crew)."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=(c[0] * I, c[1] * I, c[2] * I))
    o = bpy.context.object
    o.scale = (w * I, h * I, 1)
    o.rotation_euler = (math.radians(90 - tilt), 0, math.radians(yaw))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, (0.1, 0.3, 0.45))

def gauge(name, c, r, yaw, matname=None):
    """Round gauge face; material g_speed / g_er / g_mr gets live needles in the game."""
    bpy.ops.mesh.primitive_cylinder_add(radius=r * I, depth=0.4 * I, vertices=28,
                                        location=(c[0] * I, c[1] * I, c[2] * I), rotation=(math.radians(90), 0, math.radians(yaw)))
    o = bpy.context.object
    o.name = name
    m = bpy.data.materials.new(matname or "gauge_face")
    m.use_nodes = True
    m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.78, 0.78, 0.72, 1)
    o.data.materials.append(m)
    o["furn"] = FURN[0]
    return o

def prism(name, pts, depth_vec, rgb):
    """Polygon (list of (x,y,z) inches) extruded by depth_vec (inches)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p) * I) for p in pts]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=Vector(depth_vec) * I)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return finish(o, name, rgb)

def side_prism(name, yz, x0, x1, rgb):
    """Profile in (y,z) extruded across x0..x1."""
    return prism(name, [(x0, y, z) for y, z in yz], (x1 - x0, 0, 0), rgb)

def rounded(pts, r, n=4):
    """Round the corners of a 2D polygon."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % m])
        a, b = (p0 - p1).normalized(), (p2 - p1).normalized()
        rr = min(r, (p0 - p1).length / 2, (p2 - p1).length / 2)
        s, e = p1 + a * rr, p1 + b * rr
        for k in range(n + 1):
            t = k / n
            q = (1 - t) ** 2 * s + 2 * (1 - t) * t * p1 + t * t * e
            out.append((q.x, q.y))
    return out

def label(text, x, y, z=90.0, size=3.2, rgb=(1.0, 0.85, 0.2), rot=0):
    bpy.ops.object.text_add(location=(x * I, y * I, z * I))
    t = bpy.context.object
    t.data.body = text
    t.data.size = size * I
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.rotation_euler.z = math.radians(rot)
    t.data.materials.append(mat("lbl", rgb))
    t["plan_only"] = True
    return t

WALL = (0.80, 0.76, 0.66)
BROWN = (0.42, 0.30, 0.20)
DARK = (0.14, 0.14, 0.15)
GLASS = (0.55, 0.75, 0.9)
for _rgb, _nm in ((WALL, "wall"), (BROWN, "console"), (DARK, "panel"), (GLASS, "glass"), ((0.08, 0.08, 0.08), "gasket"),
                  ((0.12, 0.12, 0.13), "seat"), ((0.40, 0.40, 0.42), "floor"), ((0.9, 0.88, 0.82), "ceil"),
                  ((0.86, 0.83, 0.76), "overhead"), ((0.1, 0.3, 0.45), "screen"), ((0.55, 0.5, 0.42), "door"),
                  ((0.6, 0.55, 0.45), "door"), ((0.13, 0.13, 0.14), "stand"), ((0.62, 0.55, 0.45), "hood"),
                  ((0.55, 0.55, 0.57), "steel"), ((0.95, 0.8, 0.1), "yellow")):
    ROLE[tuple(round(c, 3) for c in _rgb)] = _nm
T = 3.0

def rake_y(z):
    return -max(z - SILL, 0) * TAN

def vee(x):
    return -abs(x) * TANV

def front_y(x, z):
    return vee(x) + rake_y(z)

def loft(name, yz, xa, xb, rgb):
    """Profile (y,z) swept from x=xa to x=xb, sliding back with the V of the front wall."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    A = [bm.verts.new(Vector((xa, y + vee(xa), z)) * I) for y, z in yz]
    B = [bm.verts.new(Vector((xb, y + vee(xb), z)) * I) for y, z in yz]
    bm.faces.new(A)
    bm.faces.new(list(reversed(B)))
    n = len(yz)
    for i in range(n):
        bm.faces.new([A[i], A[(i + 1) % n], B[(i + 1) % n], B[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return finish(o, name, rgb)

# floor with the nose stairwell
DL, DR = DOOR_C - DOOR_W / 2, DOOR_C + DOOR_W / 2
box("floor_l", -HW, DL, -L, 0, -1, 0, (0.40, 0.40, 0.42))
box("floor_r", DR, HW, -L, 0, -1, 0, (0.40, 0.40, 0.42))
box("floor_c", DL, DR, -L, -WELL_D, -1, 0, (0.40, 0.40, 0.42))
if MODEL == "gp38":
    box("well_step1", DL, DR, -WELL_D, 0, -9, -8, (0.3, 0.3, 0.32))
else:
    box("well_step1", DL, DR, -WELL_D, -WELL_D / 2, -9, -8, (0.3, 0.3, 0.32))
    box("well_step2", DL, DR, -WELL_D / 2, 0, -17, -16, (0.25, 0.25, 0.27))
# side walls
box("wall_L", -HW - T, -HW, -L, 8, 0, CEIL_S, WALL)
box("wall_R", HW, HW + T, -L, 8, 0, CEIL_S, WALL)
# lower front wall (upright under the glass, V in plan) with the nose door
low = [(0, 0), (T, 0), (T, SILL), (0, SILL)]
loft("front_low_l", low, -HW, DL, WALL)
loft("front_low_r", low, DR, HW, WALL)
HATCH_TOP = 32.0 if MODEL == "gp38" else SILL - 4
lin = [(0, HATCH_TOP), (T, HATCH_TOP), (T, SILL), (0, SILL)]
loft("front_lintel_l", lin, DL, 0, WALL)
loft("front_lintel_r", lin, 0, DR, WALL)
dy = vee(DOOR_C)
box("front_door", DL, DR, dy + 0.5, dy + T, -17, HATCH_TOP, (0.55, 0.5, 0.42))
if MODEL == "gp38":
    # cab door in the front-left corner, out to the front walkway, with a window like the windshields
    # conductor side: cab door with a tall window; engineer side: matching tall window.
    # Both look out past the side of the short hood along the front walkway.
    box("cabdoor", -HW + 1, -OUT_X0 + 2, -0.6, 0, 0, OUT_Z1 + 4, (0.6, 0.55, 0.45))
    for sx in (-1, 1):
        xa, xb = sorted((OUT_X0 * sx, OUT_X1 * sx))
        fr = rounded([(xa - 1.2, OUT_Z0 - 1.2), (xb + 1.2, OUT_Z0 - 1.2), (xb + 1.2, OUT_Z1 + 1.2), (xa - 1.2, OUT_Z1 + 1.2)], 4.0)
        prism("outframe%d" % sx, [(x, -0.7, z) for x, z in fr], (0, -0.2, 0), (0.08, 0.08, 0.08))
        gl = rounded([(xa, OUT_Z0), (xb, OUT_Z0), (xb, OUT_Z1), (xa, OUT_Z1)], 3.0)
        prism("outglass%d" % sx, [(x, -1.0, z) for x, z in gl], (0, -0.2, 0), GLASS)
        cutter([(x, -2.0, z) for x, z in gl], (0, T + 4, 0))
# raked upper front wall, two halves meeting at the centre post
ztop = CEIL_C + 1
up = [(0, SILL), (T, SILL), (T + rake_y(ztop), ztop), (rake_y(ztop), ztop)]
loft("front_rake_l", up, -HW, 0, WALL)
loft("front_rake_r", up, 0, HW, WALL)
# windshields: peaked toward the centre post, rounded (teardrop-ish) outer corners
for s in (-1, 1):
    xi = POST / 2
    xo = POST / 2 + WIN_W
    poly = [(xi, SILL), (xo, SILL + WIN_LIFT), (xo, SILL + WIN_H_OUT), (xi, SILL + WIN_H_IN)]
    pts2 = rounded(poly, WIN_R)
    pts = [(x * s, front_y(x, z) - 0.2, z) for x, z in pts2]
    if s < 0:
        pts.reverse()
    prism("glass%d" % s, pts, (0, -0.4, 0), GLASS)
    cutter([(x * s, front_y(x, z) - 2, z) for x, z in pts2][::(1 if s > 0 else -1)], (0, T + 4, 0))
    big = rounded([(xi - 1.2, SILL - 1.2), (xo + 1.2, SILL + WIN_LIFT - 1.2), (xo + 1.2, SILL + WIN_H_OUT + 1.2), (xi - 1.2, SILL + WIN_H_IN + 1.2)], 6.0)
    fp = [(x * s, front_y(x, z) - 0.05, z) for x, z in big]
    if s < 0:
        fp.reverse()
    prism("gasket%d" % s, fp, (0, -0.1, 0), (0.08, 0.08, 0.08))
# angled overhead valance above the windshields (as in the photos)
oz = SILL + WIN_H_IN + 3
oy = rake_y(oz)
for nm, xa, xb in (("overhead_l", -HW + 4, 0), ("overhead_r", 0, HW - 4)):
    loft(nm, [(oy, oz), (oy - OVER_D, CEIL_C - OVER_DROP), (oy - OVER_D, CEIL_C), (rake_y(CEIL_C), CEIL_C)], xa, xb, (0.86, 0.83, 0.76))
# ceiling: flat centre, sloped edges
box("ceil_c", -HW + SLOPE_RUN, HW - SLOPE_RUN, -L, rake_y(CEIL_C), CEIL_C, CEIL_C + 1, (0.9, 0.88, 0.82))
for s in (-1, 1):
    o = box("ceil_s%d" % s, -SLOPE_RUN / 2 - 1, SLOPE_RUN / 2 + 1, -L, rake_y(CEIL_S), -0.5, 0.5, (0.9, 0.88, 0.82))
    o.location = ((HW - SLOPE_RUN / 2) * s * I, (-L + rake_y(CEIL_S)) / 2 * I, (CEIL_S + CEIL_C) / 2 * I)
    o.rotation_euler.y = math.atan2(CEIL_C - CEIL_S, SLOPE_RUN) * s
    o.scale.x = math.hypot(SLOPE_RUN, CEIL_C - CEIL_S) * I
for o in bpy.data.objects:
    if o.name.startswith(("ceil", "overhead")):
        o["ceil"] = True
if MODEL == "gp38":
    # back wall: two small windows for running long hood forward
    BW = -L - T
    box("back_l", -HW, -46, BW, -L, 0, CEIL_C, WALL)
    box("back_c", -26, 26, BW, -L, 0, CEIL_C, WALL)
    box("back_r", 46, HW, BW, -L, 0, CEIL_C, WALL)
    for sx in (-1, 1):
        x0, x1 = (26, 46) if sx > 0 else (-46, -26)
        box("back_lo%d" % sx, x0, x1, BW, -L, 0, SILL, WALL)
        box("back_hi%d" % sx, x0, x1, BW, -L, SILL + WIN_H_IN, CEIL_C, WALL)
        box("back_win%d" % sx, x0, x1, BW + 1, -L - 1, SILL, SILL + WIN_H_IN, GLASS)
else:
    # back wall: window behind the conductor, door with window behind the engineer
    BW = -L - T
    box("back_l", -HW, -16, BW, -L, 0, CEIL_C, WALL)
    box("back_c", -16, 22, BW, -L, 0, CEIL_C, WALL)
    box("back_door", 22, 48, BW, -L, 0, 76, (0.55, 0.5, 0.42))
    box("back_doorwin", 28, 42, BW - 0.5, -L + 0.5, 50, 68, GLASS)
    cut_box(28, 42, BW - 2, -L + 2, 50, 68)
    box("back_r", 48, HW, BW, -L, 0, CEIL_C, WALL)
    box("back_win", -44, -24, BW - 0.5, -L + 0.5, 46, 66, GLASS)
    cut_box(-44, -24, BW - 2, -L + 2, 46, 66)

# side windows, same on both sides (per the SD70ACe-T4 photo): a narrow pane at the front,
# a two-pane sliding window in the middle, a narrow pane at the rear, set high in the wall
for sd in (-1, 1):
    wx = HW * sd
    for k, (yf, yr) in enumerate(SIDE_PANES):
        fr = rounded([(yr - 1.5, SW_BOT - 1.5), (yf + 1.5, SW_BOT - 1.5), (yf + 1.5, SW_TOP + 1.5), (yr - 1.5, SW_TOP + 1.5)], 3.0)
        prism("sideframe_%d%d" % (sd, k), [(wx - 0.3 * sd, y, z) for y, z in fr], (-0.4 * sd, 0, 0), (0.08, 0.08, 0.08))
        gl = rounded([(yr, SW_BOT), (yf, SW_BOT), (yf, SW_TOP), (yr, SW_TOP)], 2.0)
        prism("sideglass_%d%d" % (sd, k), [(wx - 0.75 * sd, y, z) for y, z in gl], (-0.2 * sd, 0, 0), GLASS)
        cutter([(wx - 2 * sd, y, z) for y, z in gl], ((T + 4) * sd, 0, 0))
    # slider track/handle rail under the middle pair
    box("siderail_%d" % sd, wx - (1.6 if sd > 0 else -0.4) , wx - (0.4 if sd > 0 else -1.6), SIDE_PANES[SLIDE[1]][1], SIDE_PANES[SLIDE[0]][0], SW_BOT - 3, SW_BOT - 1.5, (0.3, 0.3, 0.3))

def rbox(name, C, ang, u0, u1, v0, v1, z0, z1, rgb):
    """Box in a frame rotated by ang (deg): u across the stand face, v out of the face."""
    a = math.radians(ang)
    U = Vector((math.cos(a), math.sin(a), 0))
    N = Vector((math.sin(a), -math.cos(a), 0))
    c = Vector((C[0], C[1], 0)) + U * ((u0 + u1) / 2) + N * ((v0 + v1) / 2)
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = ((u1 - u0) * I, (v1 - v0) * I, (z1 - z0) * I)
    o.location = (c.x * I, c.y * I, (z0 + z1) / 2 * I)
    o.rotation_euler.z = a
    return finish(o, name, rgb)

FURN[0] = True
if MODEL == "gp38":
    # freestanding EMD AAR stand, 45 deg, face toward the engineer (rear-right)
    SC, SA = (14.0, -26.0), 45.0
    STK = (0.13, 0.13, 0.14)
    rbox("stand_E", SC, SA, -16, 16, -16, 0, 0, 36, STK)                     # main body
    rbox("standbrake", SC, SA, -16, -5, -16, 0, 36, 46, STK)                  # 26-L brake column (engineer's left)
    rbox("standface", SC, SA, -4, 14, 0, 0.4, 20, 35, DARK)                   # controller: DB / throttle / reverser
    _a = math.radians(SA)
    _U = (math.cos(_a), math.sin(_a))
    _N = (math.sin(_a), -math.cos(_a))
    def at(u, v):
        return (SC[0] + _U[0] * u + _N[0] * v, SC[1] + _U[1] * u + _N[1] * v)
    lever("st_db", "st_db_k", at(10, 1.0), _N, 6.0, 31.5)                    # dynamic brake (top)
    lever("st_thr", "st_thr_g", at(10, 1.0), _N, 6.5, 27.0)                  # throttle (middle)
    rbox("reverser", SC, SA, 8.5, 11.5, 0.4, 4, 22.5, 23.7, (0.05, 0.05, 0.05))
    lever("b26_auto", "b26_auto_k", at(-11, 1.0), _N, 7.0, 36.5, (0.6, 0.15, 0.1))   # 26-L automatic
    lever("b26_ind", "b26_ind_k", at(-11, 1.0), _N, 6.0, 30.5)                       # 26-L independent
    rbox("st_alerter", SC, SA, 1.5, 3.5, 0.4, 1.2, 30, 32, (0.95, 0.8, 0.1))
    rbox("gaugepanel", SC, SA, -5, 16, -10, -4, 36, 50, (0.2, 0.2, 0.22))     # air gauges, ammeter
    for nm, u, z, r, mn in (("g_mr_face", -1.5, 43.0, 2.3, "g_mr"), ("g_er_face", 4.0, 43.0, 2.3, "g_er"),
                            ("g_amp_face", 9.5, 43.0, 2.1, "gauge_face"), ("g_speed_face", 14.0, 46.5, 1.6, "g_speed")):
        q = at(u, -3.6)
        gauge(nm, (q[0], q[1], z), r, SA, mn)
    rbox("radio", SC, SA, -16, -5, -14, -2, 46, 52, (0.08, 0.08, 0.08))
    # heater cabinet ahead of the engineer by the right wall, extinguisher by the hatch
    box("heater", HW - 19, HW, -18, -2, 0, 28, (0.75, 0.75, 0.72))
    box("extinguisher", -18, -14, -18, -14, 0, 16, (0.8, 0.1, 0.1))
    # electrical locker on the back wall, floor to ceiling
    FURN[0] = False
    box("locker", -23, 23, -L, -L + 14, 0, CEIL_C - 1, (0.78, 0.76, 0.70))
    FURN[0] = True
    for nm, cx, fy in (("seat_E", SEAT_CX, SEAT_FRONT), ("seat_C", -HW + 22, 30.0), ("seat_J", -HW + 22, 54.0)):
        box(nm, cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D, -fy, 0, SEAT_H, (0.12, 0.12, 0.13))
        box(nm + "back", cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D - 3, -fy - SEAT_D, SEAT_H, SEAT_H + 26, (0.12, 0.12, 0.13))
else:
    # engineer desk: rounded ledge, angled two-screen hood under the windshield
    ledge = rounded([(DESK_X0, 0), (HW, 0), (HW, -DESK_D), (DESK_X0, -DESK_D)], 6.0)
    prism("desk_E", [(x, y + vee(x), DESK_H - 1.5) for x, y in ledge], (0, 0, 1.5), BROWN)
    loft("deskbase_E", [(0, 0), (-DESK_D + 4, 0), (-DESK_D + 4, DESK_H - 1.5), (0, DESK_H - 1.5)], DESK_X0 + 2, HW, BROWN)
    loft("hood_E", [(0, DESK_H), (-9, DESK_H), (-4, HOOD_H), (0, HOOD_H)], DESK_X0, HW, (0.62, 0.55, 0.45))
    SCR_W = 12.5 if MODEL == "es44" else 11.5
    SCR_NAMES = ("smart_scr0", "smart_scr1") if MODEL == "es44" else ("screen0", "screen1")
    for k in range(2):
        x0 = DESK_X0 + 3 + k * (SCR_W + 1.5)
        cx = x0 + SCR_W / 2
        zc = (DESK_H + HOOD_H) / 2 + 0.3
        yc = -9 + 5 * (zc - DESK_H) / (HOOD_H - DESK_H) - 0.25 + vee(cx)
        tilt = math.degrees(math.atan2(5, HOOD_H - DESK_H))
        screen_plane(SCR_NAMES[k], (cx, yc, zc), SCR_W - 1.0, min(HOOD_H - DESK_H - 2.0, (SCR_W - 1.0) * 0.78), tilt, -VEE)
    if MODEL == "es44":
        # GE stand: tall cabinet on the engineer's left, joined to the desk; the control face
        # (throttle + blue CCB brake valves) is set into its right side, angled toward the seat
        sx1 = STAND_X0 + STAND_D
        box("stand_E", STAND_X0, sx1, STAND_Y1, STAND_Y0 + vee(STAND_X0), 0, STAND_H, BROWN)
        face = [(sx1 + 0.2, -6, 20), (sx1 + 0.2, -6, 41), (sx1 - 3.5, -31, 41), (sx1 - 3.5, -31, 20)]
        prism("standface", face, (0.4, 0, 0), DARK)
        box("ccb", sx1 - 0.6, sx1 + 0.3, -27, -15, 26, 37, (0.15, 0.3, 0.7))
        box("standradio", sx1 - 0.2, sx1 + 0.6, -40, -32, 30, 40, DARK)
        box("standpod", STAND_X0 + 2, STAND_X0 + 16, -10, -5, STAND_H, STAND_H + 11, DARK)
        screen_plane("wab_scr", (STAND_X0 + 9, -10.2, STAND_H + 5.5), 11, 8.5, 8)
        lever("ge_lever0", "ge_grip0", (sx1 + 0.6, -11), (1, 0), 5.5, 36.5)       # throttle
        lever("ge_lever1", "ge_grip1", (sx1 + 0.6, -11), (1, 0), 5.0, 33.0)       # dynamic brake
        lever("ccb_auto", "ccb_auto_k", (sx1 + 0.6, -21), (1, 0), 6.0, 33.0, (0.05, 0.05, 0.05))
        lever("ccb_ind", "ccb_ind_k", (sx1 + 0.6, -21), (1, 0), 5.0, 28.5)
        box("desk_btn1", DESK_X0 + 2, DESK_X0 + 4, -15, -13, DESK_H, DESK_H + 0.8, (0.95, 0.8, 0.1))
    else:
        # EMD AAR control stand on the engineer's left, clear of the stairwell (small base bump into it)
        box("stand_E", STAND_X0, STAND_X0 + STAND_D, STAND_Y1, STAND_Y0, 0, STAND_H, BROWN)
        box("standbump", STAND_X0 - 2, STAND_X0, STAND_Y1 + 6, STAND_Y1 + 16, 0, 6, BROWN)
        side_prism("standface", [(STAND_Y0 - 2, STAND_H), (STAND_Y1 + 4, STAND_H), (STAND_Y1 + 8, STAND_H + 4), (STAND_Y0 - 2, STAND_H + 4)],
                   STAND_X0 + 1, STAND_X0 + STAND_D - 1, DARK)
        box("standpod", STAND_X0 + 1.5, STAND_X0 + STAND_D - 1.5, STAND_Y0 - 4, STAND_Y0 - 0.5, STAND_H + 3.5, STAND_H + 14.5, DARK)
        screen_plane("stscreen", (STAND_X0 + STAND_D / 2, STAND_Y0 - 4.2, STAND_H + 9), STAND_D - 5, 8.5, 5)
        sxr = STAND_X0 + STAND_D
        lever("dynbrake_shaft", "dynbrake_knob", (sxr - 2, -12), (1, 0), 5.5, STAND_H + 4.3)
        lever("throttle_shaft", "throttle_grip", (sxr - 2, -17), (1, 0), 6.0, STAND_H + 4.3)
        lever("brake0_shaft", "brake0_knob", (sxr - 2, -28), (1, 0), 6.5, STAND_H + 4.3, (0.6, 0.15, 0.1))
        lever("brake1_shaft", "brake1_knob", (sxr + 0.3, -33), (1, 0), 5.5, STAND_H - 4.0)
        box("alerter", sxr, sxr + 0.8, -23, -21, 30, 32, (0.95, 0.8, 0.1))
    # conductor desk: narrow console at the left front with a radio pod
    loft("desk_C", [(0, 0), (-18, 0), (-18, DESK_H), (0, DESK_H)], -HW, DL - 2, BROWN)
    loft("radio_C", [(-1, DESK_H), (-6, DESK_H), (-6, DESK_H + 12), (-1, DESK_H + 12)], -HW + 4, -HW + 20, (0.62, 0.55, 0.45))
    _cx = -HW + 12
    screen_plane("cscreen", (_cx, -6.25 + vee(_cx), DESK_H + 6), 10, 8, 0, VEE)
    # seats (with seat backs) + jump seat behind the conductor
    for nm, cx, fy in (("seat_E", SEAT_CX, SEAT_FRONT), ("seat_C", -HW + 22, 30.0), ("seat_J", -HW + 16, 66.0)):
        box(nm, cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D, -fy, 0, SEAT_H, (0.12, 0.12, 0.13))
        box(nm + "back", cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D - 3, -fy - SEAT_D, SEAT_H, SEAT_H + 26, (0.12, 0.12, 0.13))
    box("cooler", -HW + 30, -HW + 48, -82, -70, 0, 14, (0.85, 0.2, 0.2))
FURN[0] = False

# ---- punch the window openings through the walls and gasket plates
cut_col = bpy.data.collections.new("cutters")
scene.collection.children.link(cut_col)
for c in CUTTERS:
    for uc in list(c.users_collection):
        uc.objects.unlink(c)
    cut_col.objects.link(c)
for o in list(bpy.data.objects):
    if o.type != "MESH" or o.get("cutter") or o.get("furn"):
        continue
    nm = o.name
    if "glass" in nm or "_win" in nm or "doorwin" in nm:
        continue
    if nm.startswith(("front_", "wall_", "back_", "gasket", "sideframe_", "outframe", "cabdoor")):
        b = o.modifiers.new("win", "BOOLEAN")
        b.operation = "DIFFERENCE"
        b.operand_type = "COLLECTION"
        b.collection = cut_col
        b.solver = "EXACT"

# ---- plan labels ----
if MODEL == "gp38":
    label('AAR STAND\n45 deg', 14, -28, size=2.8)
    label('HEATER', HW - 9.5, -8, size=2.6)
    label('ENG SEAT', SEAT_CX, -SEAT_FRONT - SEAT_D / 2)
    label('COND SEAT', -HW + 22, -30 - SEAT_D / 2)
    label('2nd SEAT', -HW + 22, -54 - SEAT_D / 2, size=2.6)
    label('NOSE HATCH\n1 step down', 0, -7, size=2.6)
    label('CAB DOOR\n+ window', -HW + 10.5, -5, size=2.4)
    label('FRONT\nWINDOW', 43, 5, size=2.2)
    label('ELECTRICAL LOCKER', 0, -L + 7, size=2.8)
    label('4 front windows: door | 2 over the nose | engineer', 0, 12, size=3.2)
    label('EMD GP38-2   INSIDE WIDTH %d"' % W, 0, -L - 10, size=4)
    label('%d" front to back' % L, -HW - 14, -L / 2, size=3.4, rot=90)
else:
    label('ENGINEER DESK\n%d" wide, ledge %.1f"\n2 %s screens' % (HW - DESK_X0, DESK_H, SCREENS), (DESK_X0 + HW) / 2, -DESK_D / 2 - 1)
    label('COND DESK', (-HW + DL - 2) / 2, -9)
    label('%s\nSTAND\n%d" x %d"' % ("GE" if MODEL == "es44" else "AAR", STAND_D, STAND_Y0 - STAND_Y1), STAND_X0 + STAND_D / 2, (STAND_Y0 + STAND_Y1) / 2, size=2.6)
    label('ENG SEAT', SEAT_CX, -SEAT_FRONT - SEAT_D / 2)
    label('COND SEAT', -HW + 22, -30 - SEAT_D / 2)
    label('JUMP SEAT', -HW + 16, -66 - SEAT_D / 2, size=2.6)
    label('STAIRS\nto nose door', DOOR_C, -WELL_D / 2, size=2.8)
    label('BACK WINDOW', -34, -L + 5)
    label('BACK DOOR', 35, -L + 5)
    label('WINDSHIELDS: V %d deg (centre post forward), lean back %d deg' % (VEE, RAKE), 0, 9, size=3.2)
    label('%s   INSIDE WIDTH %d"' % ("GE ES44AC" if MODEL == "es44" else "EMD SD70ACe", W), 0, -L - 10, size=4)
    label('%d" front to back' % L, -HW - 14, -L / 2, size=3.4, rot=90)


# ---- HD: same approved frame, dressed with the detailed materials and fittings ----
if HD:
    import os
    HDS = open("/home/claude/cabdesign/build_cab.py").read()
    NS = {"bpy": bpy, "bmesh": bmesh, "math": math, "Vector": Vector, "TEX": "/home/claude/rail-road-game/godot/textures/",
          "scene": scene, "col": scene.collection, "FLOOR": -1.35}
    from mathutils import Euler
    NS["Euler"] = Euler
    exec("def g(x, y, z):\n    return Vector((x, -z, y))\n", NS)
    exec(HDS[HDS.index("# ------------------------------------------------------------------ materials"):HDS.index("# ------------------------------------------------------------------ cab shell")], NS)
    exec(HDS[HDS.index("def soft("):HDS.index("\n\nseat(")], NS)
    exec(HDS[HDS.index("def _bake_ao("):HDS.index("# ------------------------------------------------------------------ world, lights, camera")]
         .replace('if o.type != "MESH" or o.hide_render or o.name.startswith(skip)', 'if (o.type not in ("MESH", "EMPTY")) or o.hide_render or o.name.startswith(skip)'), NS)
    M = NS["M"]
    mat_col, mat_img, mat_tex = NS["mat_col"], NS["mat_img"], NS["mat_tex"]
    STAINLESS = mat_col("stainless", (0.6, 0.6, 0.58), 0.38, 0.85)
    WHITE = mat_col("cab_white", (0.75, 0.75, 0.72), 0.55)
    DANGER = mat_img("danger", "/tmp/cabdesign/danger.png", 0.5)
    GPSTAND = mat_tex("stand_k", "stand_brown.png", 1.5, 0.5, 0.25, tint=(0.17, 0.17, 0.18), bump=0.12) if REPAINT else M["stand"]
    NS.update({"STAINLESS": STAINLESS, "WHITE": WHITE, "DANGER": DANGER, "STAND": GPSTAND})
    if MODEL == "es44":
        CONSOLE = mat_tex("console_ge", "stand_brown.png", 1.5, 0.45, 0.2, tint=(1.25, 0.95, 0.72))
    else:
        CONSOLE = M["stand"]
    SCR = {"eng": mat_img("scr_eng", "/tmp/cabdesign/scr_eng.png", 0.2, emit=1.4), "ptc": mat_img("scr_ptc", "/tmp/cabdesign/scr_ptc.png", 0.2, emit=1.4)}
    ROLE_HD = {"wall": M["wall"], "ceil": M["ceil"], "floor": M["floor"], "console": CONSOLE, "hood": CONSOLE,
               "panel": M["console"], "glass": M["glass"], "gasket": M["rubber"], "overhead": M["wall"],
               "door": M["wall"], "stand": GPSTAND, "steel": M["chrome"], "yellow": M["alerter"], "seat": M["seat"]}
    # every blockout part: bake scale into the mesh so the box-projected textures come out at real size
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.get("cutter"):
            continue
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mname = o.active_material.name if o.active_material else ""
        if mname in ROLE_HD:
            o.data.materials.clear()
            o.data.materials.append(ROLE_HD[mname])
        elif mname.startswith("c"):
            o.data.materials.clear()
            o.data.materials.append(M["cast"])
    for o in bpy.data.objects:
        if o.name.startswith(("screen", "smart_scr", "stscreen", "wab_scr", "cscreen")) and o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(SCR["eng" if o.name in ("screen0", "smart_scr0") else "ptc"])
        if o.name == "cooler":
            o.data.materials.clear()
            o.data.materials.append(M["red"])
        if o.name in ("heater", "locker"):
            o.data.materials.clear()
            o.data.materials.append(WHITE if o.name == "heater" else M["wall"])
    if REPAINT:
        GW = mat_tex("wall_g", "cab_wall_green.png", 1.6, 0.62, 0.05, bump=0.15)
        GC = mat_tex("ceil_g", "ceiling_green.png", 1.4, 0.85, bump=0.25)
        for o in bpy.data.objects:
            if o.type == "MESH" and o.active_material in (M["wall"], M["ceil"]):
                m0 = o.active_material
                o.data.materials.clear()
                o.data.materials.append(GW if m0 == M["wall"] else GC)

    before = set(bpy.data.objects)

    def track(furn):
        """Mark everything made since the last call, shift it from the HD scripts' frame (floor at -1.35) onto ours."""
        global before
        for o in bpy.data.objects:
            if o not in before:
                if o.parent is None:
                    o.location.z += 1.35
                o["furn"] = furn
        bpy.context.view_layer.update()
        before = set(bpy.data.objects)

    def G(x, y, z):
        """blockout inches -> HD game metres"""
        return (x * I, z * I - 1.35, -y * I)

    # handles: chrome collar on each shaft, rounded grip + knob joined into the grip piece
    def dress_lever(shaft, grip, knob_mat):
        sh = bpy.data.objects.get(shaft)
        gr = bpy.data.objects.get(grip)
        if sh is None or gr is None:
            return
        sh.data.materials.clear()
        sh.data.materials.append(M["chrome"])
        gr.data.materials.clear()
        gr.data.materials.append(M["grip"])
        bpy.context.view_layer.update()
        tip = gr.matrix_world @ Vector((max(v.co.x for v in gr.data.vertices), 0, 0))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.95 * I, segments=16, ring_count=8, location=tip)
        kb = bpy.context.object
        kb.data.materials.append(knob_mat)
        bpy.ops.object.select_all(action="DESELECT")
        kb.select_set(True)
        gr.select_set(True)
        bpy.context.view_layer.objects.active = gr
        bpy.ops.object.join()
        for p_ in gr.data.polygons:
            p_.use_smooth = True
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0 * I, depth=0.8 * I, vertices=20, location=sh.matrix_world @ Vector((0, 0, min(v.co.z for v in sh.data.vertices) + 0.4 * I)))
        cl = bpy.context.object
        cl.name = shaft + "_collar"
        cl.data.materials.append(M["cast"])
        cl["furn"] = sh.get("furn", False)

    def disc(name, c, r, yaw, mkey, tilt=0.0):
        """Textured round gauge face (planar UV, texture up = up) on a black can with a chrome ring."""
        rot = (math.radians(90 - tilt), 0, math.radians(yaw))
        n = Vector((0, 0, 1))
        n.rotate(Euler(rot))
        loc = Vector(c) * I
        bpy.ops.mesh.primitive_cylinder_add(radius=r * 1.1 * I, depth=0.6 * I, vertices=32, location=loc - n * 0.3 * I, rotation=rot)
        bpy.context.object.data.materials.append(M["black"])
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.06 * I, minor_radius=0.18 * I, major_segments=40, minor_segments=8, location=loc + n * 0.05 * I, rotation=rot)
        bpy.context.object.data.materials.append(M["chrome"])
        bpy.ops.mesh.primitive_circle_add(vertices=40, radius=r * I, fill_type="NGON", location=loc + n * 0.02 * I, rotation=rot)
        f = bpy.context.object
        f.name = name
        f.data.uv_layers.new()
        d = 2 * r * I
        for li, loop in enumerate(f.data.loops):
            co = f.data.vertices[loop.vertex_index].co
            f.data.uv_layers.active.data[li].uv = (co.x / d + 0.5, co.y / d + 0.5)
        f.data.materials.append(M[mkey])

    def plane_on(name, c, w, h, mat, tilt=0.0, yaw=0.0):
        o = screen_plane(name, c, w, h, tilt, yaw)
        o.data.materials.clear()
        o.data.materials.append(mat)
        return o

    def bezel(scr_name, w, h, depth=0.8):
        """Black bezel behind a screen quad, slightly larger, with a row of soft keys underneath."""
        sc = bpy.data.objects.get(scr_name)
        if sc is None:
            return
        bpy.context.view_layer.update()
        n = sc.matrix_world.to_3x3() @ Vector((0, 0, 1))
        up = sc.matrix_world.to_3x3() @ Vector((0, 1, 0))
        bpy.ops.mesh.primitive_cube_add(size=1, location=sc.matrix_world.translation - n.normalized() * depth / 2 * I - up.normalized() * 0.9 * I)
        b = bpy.context.object
        b.rotation_euler = sc.rotation_euler
        b.scale = ((w + 2.0) * I, (h + 3.6) * I, depth * I)
        b.data.materials.append(M["black"])
        bv = b.modifiers.new("bv", "BEVEL")
        bv.width = 0.3 * I
        bv.segments = 2
        fk = screen_plane(scr_name + "_keys", tuple(v / I for v in (sc.matrix_world.translation - up.normalized() * (h / 2 + 1.1) * I + n.normalized() * 0.02 * I)), w - 0.5, 1.1)
        fk.rotation_euler = sc.rotation_euler
        fk.data.materials.clear()
        fk.data.materials.append(M["fkeys"])

    if MODEL == "gp38":
        # the detailed EMD AAR stand from the GP38 design, set on the approved spot and angle
        for nm in ("stand_E", "standbrake", "standface", "reverser", "st_db", "st_db_k", "st_thr", "st_thr_g", "b26_auto",
                   "b26_auto_k", "b26_ind", "b26_ind_k", "st_alerter", "gaugepanel", "g_mr_face", "g_er_face",
                   "g_amp_face", "g_speed_face", "radio"):
            o = bpy.data.objects.get(nm)
            if o:
                bpy.data.objects.remove(o)
        G38 = open("/home/claude/cabdesign/build_gp38.py").read()
        exec(G38[G38.index("def group("):G38.index("group(build_stand")], NS)
        exec(G38[G38.index("VINYL = mat_col"):G38.index("# heater cabinet")], NS)
        e = NS["group"](NS["build_stand"], G(6.93, -18.93, 0)[0:1] + (0.0,) + (G(6.93, -18.93, 0)[2],), -math.radians(45))
        track(True)
        for nm, cx, fy in (("eseat", SEAT_CX, SEAT_FRONT), ("cseat", -HW + 22, 30.0), ("cseat2", -HW + 22, 54.0)):
            for o in list(bpy.data.objects):
                if o.name in ("seat_" + {"eseat": "E", "cseat": "C", "cseat2": "J"}[nm], "seat_" + {"eseat": "E", "cseat": "C", "cseat2": "J"}[nm] + "back"):
                    bpy.data.objects.remove(o)
            NS["gp_seat"](nm, cx * I, (fy + SEAT_D / 2) * I)
        track(True)
        # heater grille, extinguisher, locker doors with HIGH VOLTAGE plates
        box("heater_grille", HW - 16, HW - 3, -18.3, -18.0, 4, 10, (0.05, 0.05, 0.05))
        FURN[0] = False
        for k, (lx, lz) in enumerate(((-11.5, 18), (11.5, 18), (-11.5, 52), (11.5, 52))):
            d_ = box("lk_door%d" % k, lx - 10.5, lx + 10.5, -L + 14, -L + 14.6, lz - 15, lz + 15, (0.78, 0.76, 0.70))
            d_.data.materials.clear()
            d_.data.materials.append(M["wall"])
            plane_on("lk_danger%d" % k, (lx - 3, -L + 14.8, lz + 7), 6, 3, DANGER, 0, 180)
            box("lk_handle%d" % k, lx + 7, lx + 8.2, -L + 14.6, -L + 15.8, lz - 3, lz + 3, (0.55, 0.55, 0.57))
        FURN[0] = True
    else:
        for nm, cx, fy in (("eseat", SEAT_CX, SEAT_FRONT), ("cseat", -HW + 22, 30.0), ("cseat2", -HW + 16, 66.0)):
            key = {"eseat": "E", "cseat": "C", "cseat2": "J"}[nm]
            for o in list(bpy.data.objects):
                if o.name in ("seat_" + key, "seat_" + key + "back"):
                    bpy.data.objects.remove(o)
            NS["seat"](nm, cx * I, (fy + SEAT_D / 2) * I)
        track(True)
        if MODEL == "es44":
            levers = (("ge_lever0", "ge_grip0", M["grip"]), ("ge_lever1", "ge_grip1", M["grip"]),
                      ("ccb_auto", "ccb_auto_k", M["knob_red"]), ("ccb_ind", "ccb_ind_k", M["grip"]))
            scr = (("smart_scr0", SCR_W - 1.0), ("smart_scr1", SCR_W - 1.0), ("wab_scr", 11), ("cscreen", 10))
            sx1 = STAND_X0 + STAND_D
            plane_on("st_switches", (sx1 + 0.45, -35, 25), 9, 6, M["switches"], 0, 90)
            for k, yy in enumerate((-21,)):
                bpy.ops.mesh.primitive_cylinder_add(radius=2.6 * I, depth=1.6 * I, location=((sx1 + 0.8) * I, yy * I, 30.5 * I), rotation=(0, math.radians(90), 0))
                bpy.context.object.data.materials.append(M["cast"])
        else:
            levers = (("throttle_shaft", "throttle_grip", M["grip"]), ("dynbrake_shaft", "dynbrake_knob", M["grip"]),
                      ("brake0_shaft", "brake0_knob", M["knob_red"]), ("brake1_shaft", "brake1_knob", M["chrome"]))
            scr = (("screen0", 10.5), ("screen1", 10.5), ("stscreen", STAND_D - 5), ("cscreen", 10))
            sxr = STAND_X0 + STAND_D
            box("notch_plate", sxr - 4.5, sxr - 0.5, -20, -9, STAND_H, STAND_H + 0.4, (0.05, 0.05, 0.05))
            plane_on("st_switches", (sxr + 0.05, -10, 24), 10, 7, M["switches"], 0, 90)
            for yy, zz in ((-28, STAND_H), (-33, STAND_H - 8.0)):
                bpy.ops.mesh.primitive_cylinder_add(radius=3.2 * I, depth=1.6 * I, location=((sxr - 2 if zz == STAND_H else sxr + 0.4) * I, yy * I, (zz + 0.8) * I))
                bpy.context.object.data.materials.append(M["cast"])
            # handset in its cradle at the back of the stand
            box("handset", STAND_X0 + 6, STAND_X0 + 9, STAND_Y1 + 2, STAND_Y1 + 10, STAND_H, STAND_H + 1.8, (0.05, 0.05, 0.05))
        for sh, gr, km in levers:
            dress_lever(sh, gr, km)
        for nm, w in scr:
            sc = bpy.data.objects.get(nm)
            if sc:
                bezel(nm, w, w * 0.75)
        # desk dressing: alerter base, water bottle, track warrant
        bx = DESK_X0 + 22
        bpy.ops.mesh.primitive_cylinder_add(radius=1.3 * I, depth=8 * I, vertices=20, location=(bx * I, (-17 + vee(bx)) * I, (DESK_H + 4) * I))
        bpy.context.object.data.materials.append(M["bottle"])
        plane_on("warrant", (DESK_X0 + 10, -16 + vee(DESK_X0 + 10), DESK_H + 0.05), 8.5, 11, M["paper"], 90, -8)
        plane_on("warrant_c", (-HW + 12, -13 + vee(-HW + 12), DESK_H + 0.05), 8.5, 11, M["paper"], 90, 5)
        track(True)
    # windshield wipers parked at the bottom of each pane, sun visors on rails, dome light
    FURN[0] = False
    if MODEL != "gp38":
        for s_ in (-1, 1):
            xm = s_ * (POST / 2 + WIN_W * 0.55)
            yb = front_y(xm, SILL + 1.5) - 0.6
            box("wiper_arm%d" % s_, xm - 0.4, xm + 0.4, yb - 0.4, yb, SILL - 1, SILL + 9, (0.05, 0.05, 0.05)).data.materials[0] = M["black"]
            box("wiper_blade%d" % s_, xm - 11, xm + 11, yb - 0.5, yb - 0.1, SILL + 1.2, SILL + 2.0, (0.05, 0.05, 0.05)).data.materials[0] = M["black"]
            vz = SILL + WIN_H_IN + 2
            box("visor%d" % s_, s_ * (POST / 2 + 4) if s_ > 0 else s_ * (POST / 2 + 24), s_ * (POST / 2 + 24) if s_ > 0 else s_ * (POST / 2 + 4),
                front_y(s_ * 14, vz) - 3, front_y(s_ * 14, vz) - 2.6, vz - 12, vz, (0.1, 0.1, 0.1)).data.materials[0] = mat_col("visor", (0.05, 0.05, 0.04), 0.2, alpha=0.75)
    bpy.ops.mesh.primitive_cylinder_add(radius=4 * I, depth=1.2 * I, vertices=24, location=(0, -L * 0.55 * I, (CEIL_C - 0.5) * I))
    bpy.context.object.data.materials.append(M["dome"])
    for o in bpy.data.objects:
        if o not in before:
            o["furn"] = False
    before = set(bpy.data.objects)

# ---- lite cab export ----
if EXPORT:
    import json
    for o in list(bpy.data.objects):
        if o.get("plan_only") or o.name == "eye":
            bpy.data.objects.remove(o)
    # apply modifiers (bevels, window booleans), then drop the cutters
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.modifiers and not o.get("cutter"):
            bpy.context.view_layer.objects.active = o
            for md in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    for c in CUTTERS:
        bpy.data.objects.remove(c)
    root = bpy.data.objects.new("cab_lite", None)
    scene.collection.objects.link(root)
    furn = bpy.data.objects.new("furniture", None)
    scene.collection.objects.link(furn)
    furn.parent = root
    furn.location = (0, -L / 2 * I, 0)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        par = furn if o.get("furn") else root
        mw = o.matrix_world.copy()
        o.parent = par
        bpy.context.view_layer.update()
        o.matrix_world = mw
    if LHF:
        furn.rotation_euler.z = math.pi
    root.location.z = -1.35          # Blender cabs: floor 1.35 m below the model origin (game frame)
    if HD:
        NS["export_glb"](OUT)
    else:
        bpy.ops.object.select_all(action="DESELECT")
        for o in bpy.data.objects:
            if o.type in ("MESH", "EMPTY"):
                o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    eye_x, eye_back = SEAT_CX, SEAT_FRONT + SEAT_D / 2 - 2
    info = {"eye": [round(eye_x * I, 3), round(EYE_Z * I - 1.35, 3), round(eye_back * I, 3)],
            "cab_len": round(L * I, 3), "outer_len": round((L + T) * I, 3)}
    print("LITE_INFO", json.dumps(info))
    sys.exit(0)

# ---- render ----
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_shadows = True
sh.shadow_intensity = 0.35
sh.show_cavity = False

def cam(name, loc, rot, ortho=None, fov=None):
    c = bpy.data.cameras.new(name)
    if ortho:
        c.type = "ORTHO"
        c.ortho_scale = ortho
    if fov:
        c.sensor_fit = "HORIZONTAL"
        c.angle = math.radians(fov)
    o = bpy.data.objects.new(name, c)
    scene.collection.objects.link(o)
    o.location = [v * I for v in loc]
    o.rotation_euler = [math.radians(a) for a in rot]
    return o

def vis(pred, hidden):
    for o in bpy.data.objects:
        if o.type in ("MESH", "FONT") and pred(o):
            o.hide_render = hidden

def shot(c, path, rx, ry):
    scene.camera = c
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

vis(lambda o: o.get("ceil") or o.name.startswith("front_rake"), True)
shot(cam("plan", (0, -L / 2 - 2, 240), (0, 0, 0), ortho=(W + 40) * I), OUT + "/plan.png", 1300, 1300)
vis(lambda o: o.get("plan_only"), True)
shot(cam("over", (-HW + 8, -L - 34, 118), (56, 0, -24), fov=72), OUT + "/overview.png", 1400, 900)
vis(lambda o: o.get("ceil") or o.name.startswith("front_rake"), False)
# same spot as the NS SD70ACU photo: behind/left of the conductor seat, low, looking forward-right
shot(cam("photo", (-HW + 14, -L + 6, 58), (80, 0, -32), fov=100), OUT + "/photo_match.png", 1400, 930)
shot(cam("eng", (SEAT_CX, -SEAT_FRONT - SEAT_D / 2 + 2, EYE_Z), (86, 0, 14), fov=100), OUT + "/engineer.png", 1400, 800)
# side section through the engineer seat (cut away the right wall)
vis(lambda o: o.name == "wall_R" or o.name.startswith(("sideframe_1", "sideglass_1", "siderail_1")), True)
shot(cam("side", (HW + 60, -L / 2 + 5, 42), (90, 0, 90), ortho=(L + 30) * I), OUT + "/side.png", 1300, 900)
print("DONE")
