"""Gray-box SD70ACe cab layout for proportion review. Units: inches (converted to metres).
x: left(-) to right(+, engineer side); y: front wall at 0 (at the sill), back is negative; z: up from cab floor.
Usage: python blockout.py -- OUTDIR
"""
import bpy, bmesh, sys, math
from mathutils import Vector
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/blk"
MODEL = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else "sd70ace"
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
    WIN_W, WIN_H_IN, WIN_H_OUT, WIN_LIFT, WIN_R = 28.0, 22.0, 22.0, 0.0, 3.5
    POST = 13.0                                 # windshields centred 20.5" either side of centre
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

def mat(name, rgb):
    if name not in COL:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*rgb, 1)
        COL[name] = m
    return COL[name]

def finish(o, name, rgb):
    o.name = name
    o.data.materials.append(mat(name.split("_")[0], rgb))
    return o

def box(name, x0, x1, y0, y1, z0, z1, rgb=(0.7, 0.7, 0.7)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = ((x1 - x0) * I, (y1 - y0) * I, (z1 - z0) * I)
    o.location = ((x0 + x1) / 2 * I, (y0 + y1) / 2 * I, (z0 + z1) / 2 * I)
    return finish(o, name, rgb)

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
    box("cabdoor", -HW + 1, -HW + 20, -0.6, 0, 0, SILL + WIN_H_IN + 3, (0.6, 0.55, 0.45))
    box("cabdoor_glass", -HW + 4, -HW + 17, -0.9, -0.6, SILL, SILL + WIN_H_IN, GLASS)
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
    box("back_r", 48, HW, BW, -L, 0, CEIL_C, WALL)
    box("back_win", -44, -24, BW - 0.5, -L + 0.5, 46, 66, GLASS)

# side windows, same on both sides (per the SD70ACe-T4 photo): a narrow pane at the front,
# a two-pane sliding window in the middle, a narrow pane at the rear, set high in the wall
for sd in (-1, 1):
    wx = HW * sd
    for k, (yf, yr) in enumerate(SIDE_PANES):
        fr = rounded([(yr - 1.5, SW_BOT - 1.5), (yf + 1.5, SW_BOT - 1.5), (yf + 1.5, SW_TOP + 1.5), (yr - 1.5, SW_TOP + 1.5)], 3.0)
        prism("sideframe_%d%d" % (sd, k), [(wx - 0.3 * sd, y, z) for y, z in fr], (-0.4 * sd, 0, 0), (0.08, 0.08, 0.08))
        gl = rounded([(yr, SW_BOT), (yf, SW_BOT), (yf, SW_TOP), (yr, SW_TOP)], 2.0)
        prism("sideglass_%d%d" % (sd, k), [(wx - 0.75 * sd, y, z) for y, z in gl], (-0.2 * sd, 0, 0), GLASS)
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

if MODEL == "gp38":
    # freestanding EMD AAR stand, 45 deg, face toward the engineer (rear-right)
    SC, SA = (14.0, -26.0), 45.0
    STK = (0.13, 0.13, 0.14)
    rbox("stand_E", SC, SA, -16, 16, -16, 0, 0, 36, STK)                     # main body
    rbox("standbrake", SC, SA, -16, -5, -16, 0, 36, 46, STK)                  # 26-L brake column (engineer's left)
    rbox("brake_auto", SC, SA, -14, -8, 0, 7, 36, 38, (0.6, 0.15, 0.1))       # automatic brake handle
    rbox("brake_ind", SC, SA, -14, -8, 0, 6, 30, 32, (0.25, 0.25, 0.27))      # independent brake handle
    rbox("standface", SC, SA, -4, 14, 0, 0.4, 20, 35, DARK)                   # controller: DB / throttle / reverser
    for k, z in enumerate((32, 27.5, 23)):
        rbox("lever%d" % k, SC, SA, 9, 12, 0.4, 6, z, z + 1.2, (0.05, 0.05, 0.05))
    rbox("gaugepanel", SC, SA, -5, 16, -10, -4, 36, 50, (0.2, 0.2, 0.22))     # air gauges, ammeter
    for k in range(4):
        rbox("gauge%d" % k, SC, SA, -3 + k * 4.8, 1 + k * 4.8, -4, -3.6, 42, 46.5, (0.85, 0.85, 0.8))
    rbox("radio", SC, SA, -16, -5, -14, -2, 46, 52, (0.08, 0.08, 0.08))
    # heater cabinet ahead of the engineer by the right wall, extinguisher by the hatch
    box("heater", HW - 19, HW, -16, 0, 0, 28, (0.75, 0.75, 0.72))
    box("extinguisher", -18, -14, -18, -14, 0, 16, (0.8, 0.1, 0.1))
    # electrical locker on the back wall, floor to ceiling
    box("locker", -23, 23, -L, -L + 14, 0, CEIL_C - 1, (0.78, 0.76, 0.70))
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
    for k in range(2):
        x0 = DESK_X0 + 3 + k * (SCR_W + 1.5)
        loft("fire_%d" % k, [(-9.2, DESK_H + 1.2), (-8.8, DESK_H + 1.2), (-4.4, DESK_H + 10.2), (-4.8, DESK_H + 10.2)],
                   x0, x0 + SCR_W, (0.1, 0.3, 0.45))
    if MODEL == "es44":
        # GE stand: tall cabinet on the engineer's left, joined to the desk; the control face
        # (throttle + blue CCB brake valves) is set into its right side, angled toward the seat
        sx1 = STAND_X0 + STAND_D
        box("stand_E", STAND_X0, sx1, STAND_Y1, STAND_Y0 + vee(STAND_X0), 0, STAND_H, BROWN)
        face = [(sx1 + 0.2, -6, 20), (sx1 + 0.2, -6, 41), (sx1 - 3.5, -31, 41), (sx1 - 3.5, -31, 20)]
        prism("standface", face, (0.4, 0, 0), DARK)
        box("ccb", sx1 - 2.2, sx1 + 0.8, -26, -14, 26, 36, (0.15, 0.3, 0.7))
        box("standradio", sx1 - 0.2, sx1 + 0.6, -40, -32, 30, 40, DARK)
        box("standscreen", STAND_X0 + 3, STAND_X0 + 15, -9, -6, STAND_H, STAND_H + 10, (0.1, 0.3, 0.45))
    else:
        # EMD AAR control stand on the engineer's left, clear of the stairwell (small base bump into it)
        box("stand_E", STAND_X0, STAND_X0 + STAND_D, STAND_Y1, STAND_Y0, 0, STAND_H, BROWN)
        box("standbump", STAND_X0 - 2, STAND_X0, STAND_Y1 + 6, STAND_Y1 + 16, 0, 6, BROWN)
        side_prism("standface", [(STAND_Y0 - 2, STAND_H), (STAND_Y1 + 4, STAND_H), (STAND_Y1 + 8, STAND_H + 4), (STAND_Y0 - 2, STAND_H + 4)],
                   STAND_X0 + 1, STAND_X0 + STAND_D - 1, DARK)
        box("standscreen", STAND_X0 + 2, STAND_X0 + STAND_D - 2, STAND_Y0 - 4, STAND_Y0 - 1, STAND_H + 4, STAND_H + 14, (0.1, 0.3, 0.45))
    # conductor desk: narrow console at the left front with a radio pod
    loft("desk_C", [(0, 0), (-18, 0), (-18, DESK_H), (0, DESK_H)], -HW, DL - 2, BROWN)
    loft("radio_C", [(-1, DESK_H), (-6, DESK_H), (-6, DESK_H + 12), (-1, DESK_H + 12)], -HW + 4, -HW + 20, (0.62, 0.55, 0.45))
    # seats (with seat backs) + jump seat behind the conductor
    for nm, cx, fy in (("seat_E", SEAT_CX, SEAT_FRONT), ("seat_C", -HW + 22, 30.0), ("seat_J", -HW + 16, 66.0)):
        box(nm, cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D, -fy, 0, SEAT_H, (0.12, 0.12, 0.13))
        box(nm + "back", cx - SEAT_W / 2, cx + SEAT_W / 2, -fy - SEAT_D - 3, -fy - SEAT_D, SEAT_H, SEAT_H + 26, (0.12, 0.12, 0.13))
    box("cooler", -HW + 30, -HW + 48, -82, -70, 0, 14, (0.85, 0.2, 0.2))

# ---- plan labels ----
if MODEL == "gp38":
    label('AAR STAND\n45 deg', 14, -28, size=2.8)
    label('HEATER', HW - 9.5, -8, size=2.6)
    label('ENG SEAT', SEAT_CX, -SEAT_FRONT - SEAT_D / 2)
    label('COND SEAT', -HW + 22, -30 - SEAT_D / 2)
    label('2nd SEAT', -HW + 22, -54 - SEAT_D / 2, size=2.6)
    label('NOSE HATCH\n1 step down', 0, -7, size=2.6)
    label('CAB DOOR', -HW + 10.5, -5, size=2.4)
    label('ELECTRICAL LOCKER', 0, -L + 7, size=2.8)
    label('WINDSHIELDS 28" x 22", upright front wall', 0, 9, size=3.2)
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
