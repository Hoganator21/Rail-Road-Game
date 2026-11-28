"""Design mockups: improved PTC and locomotive/engine displays (1024x768, 4:3 like the real units)."""
import math
from PIL import Image, ImageDraw, ImageFont

FB = "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf"
FR = "/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf"
FM = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"


def f(size, bold=True, mono=False):
    return ImageFont.truetype(FM if mono else (FB if bold else FR), size)


BG = (8, 11, 16)
PANEL = (18, 23, 31)
LINE = (44, 52, 64)
TXT = (226, 230, 236)
DIM = (130, 140, 155)
AMBER = (255, 196, 64)
GREEN = (70, 220, 120)
CYAN = (60, 200, 230)
RED = (240, 70, 60)
BLUE = (70, 140, 255)
W, H = 1024, 768


def panel(d, box, title=None):
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=10, fill=PANEL, outline=LINE, width=2)
    if title:
        d.text((x0 + 14, y0 + 8), title, font=f(15, False), fill=DIM)


def softkeys(d, labels, active=()):
    y0 = H - 62
    d.rectangle([0, y0 - 6, W, H], fill=(12, 15, 20))
    kw = W / len(labels)
    for i, lab in enumerate(labels):
        x0 = i * kw + 6
        on = i in active
        d.rounded_rectangle([x0, y0, x0 + kw - 12, H - 8], radius=8, fill=(40, 70, 120) if on else (30, 35, 44), outline=(70, 80, 95), width=1)
        d.text((x0 + 10, y0 + 6), "F%d" % (i + 1), font=f(13, False), fill=DIM)
        tw = d.textlength(lab, font=f(17))
        d.text((x0 + (kw - 12 - tw) / 2, y0 + 22), lab, font=f(17), fill=TXT)


# ====================================================================== PTC
def ptc():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # status bar
    d.rectangle([0, 0, W, 54], fill=(10, 70, 40))
    d.text((18, 10), "PTC  ACTIVE", font=f(26), fill=(255, 255, 255))
    d.text((250, 16), "A-LINE SUB   TRACK  MAIN 1", font=f(19, False), fill=(200, 240, 210))
    d.text((W - 150, 14), "14:32:07", font=f(22, mono=True), fill=(230, 255, 235))
    # warning banner
    d.rectangle([0, 54, W, 110], fill=(255, 200, 40))
    d.text((24, 62), "WARNING", font=f(28), fill=(20, 20, 20))
    d.text((210, 62), "BRAKING IN 29 SEC  -  REDUCE TO 25 MPH", font=f(28), fill=(20, 20, 20))
    # left: speed + limit + target
    panel(d, (14, 124, 330, 470))
    d.text((34, 134), "SPEED", font=f(16, False), fill=DIM)
    d.text((30, 150), "42", font=f(130), fill=(255, 255, 255))
    d.text((250, 250), "MPH", font=f(20), fill=DIM)
    d.rounded_rectangle([34, 320, 150, 452], radius=8, fill=(245, 245, 240))
    d.text((48, 326), "SPEED", font=f(15), fill=(20, 20, 20))
    d.text((48, 344), "LIMIT", font=f(15), fill=(20, 20, 20))
    d.text((52, 368), "50", font=f(58), fill=(10, 10, 10))
    d.text((170, 322), "NEXT TARGET", font=f(15, False), fill=DIM)
    d.text((170, 342), "25 MPH", font=f(30), fill=AMBER)
    d.text((170, 380), "2,829 FT", font=f(30), fill=AMBER)
    d.text((170, 420), "Diverging route", font=f(16, False), fill=TXT)
    # right: track map
    panel(d, (344, 124, W - 14, 470), "TRACK AHEAD")
    x0, x1, ym = 370, W - 40, 330
    # warning zone (red hatched) where braking would start
    zx0, zx1 = 650, 880
    d.rectangle([zx0, 160, zx1, 440], fill=(60, 18, 18))
    for k in range(zx0 - 300, zx1, 18):
        d.line([(max(zx0, k), 160 + max(0, zx0 - k)), (min(zx1, k + 280), 160 + min(280, zx1 - k))], fill=(150, 40, 35), width=2)
    d.text((zx0 + 40, 166), "25 MPH DIVERGING", font=f(15), fill=(255, 140, 120))
    # mileposts
    for i, mp in enumerate(range(64, 69)):
        x = x0 + 40 + i * 140
        d.line([(x, 180), (x, 440)], fill=(36, 42, 52), width=1)
        d.text((x - 14, 448), str(mp), font=f(16), fill=DIM)
    # main line + train
    d.line([(x0, ym), (x1, ym)], fill=(210, 215, 220), width=5)
    d.rectangle([x0, ym - 9, x0 + 120, ym + 9], fill=GREEN)
    d.polygon([(x0 + 120, ym - 13), (x0 + 140, ym), (x0 + 120, ym + 13)], fill=GREEN)
    d.text((x0, ym + 16), "YOUR TRAIN  6,300 FT", font=f(14), fill=GREEN)
    # siding with fit check
    sx0, sx1 = 700, 960
    d.line([(sx0, ym), (sx0 + 40, ym - 70), (sx1 - 40, ym - 70), (sx1, ym)], fill=AMBER, width=4)
    d.text((sx0 + 30, ym - 98), "DORSEY SDG 8,200 FT", font=f(15), fill=AMBER)
    d.rounded_rectangle([sx0 + 50, ym - 64, sx0 + 128, ym - 40], radius=5, fill=(30, 110, 60))
    d.text((sx0 + 62, ym - 63), "FITS", font=f(16), fill=(255, 255, 255))
    for sx in (sx0, sx1):   # switch points
        d.ellipse([sx - 7, ym - 7, sx + 7, ym + 7], fill=AMBER)
    # spur + crossing + signal
    d.line([(540, ym), (575, ym + 55), (612, ym + 55)], fill=(170, 170, 170), width=3)
    d.rectangle([608, ym + 47, 616, ym + 63], fill=RED)
    d.text((510, ym + 66), "SPUR OCCUPIED", font=f(13), fill=(200, 200, 200))
    d.line([(520, ym - 40), (520, ym + 40)], fill=CYAN, width=4)
    d.text((488, ym - 66), "XING", font=f(13), fill=CYAN)
    d.text((468, ym + 44), "OLD TOWN RD", font=f(13), fill=CYAN)
    d.ellipse([975, 196, 995, 216], fill=RED)
    # stop / warning distance markers
    d.line([(zx0, 180), (zx0, 440)], fill=AMBER, width=2)
    d.text((zx0 + 6, 190), "WD", font=f(15), fill=AMBER)
    d.line([(zx0 + 120, 180), (zx0 + 120, 440)], fill=RED, width=2)
    d.text((zx0 + 126, 190), "SD", font=f(15), fill=RED)
    # ahead list
    panel(d, (14, 484, W - 14, H - 80), "AHEAD")
    rows = [("FACING SWITCH  DORSEY SIDING", "8,200 FT  FITS", "2,829 FT", AMBER),
            ("CROSSING  OLD TOWN RD", "BLOW FOR CROSSING", "3,960 FT", CYAN),
            ("MILEPOST 65", "", "4,180 FT", DIM),
            ("TRAILING SWITCH  DORSEY SIDING END", "", "10,340 FT", AMBER)]
    for i, (a, b, c, colr) in enumerate(rows):
        y = 518 + i * 40
        d.rectangle([30, y + 6, 38, y + 26], fill=colr)
        d.text((52, y), a, font=f(20), fill=TXT)
        d.text((560, y + 2), b, font=f(17, False), fill=colr)
        d.text((W - 150, y), c, font=f(20, mono=True), fill=AMBER)
    d.text((780, 488), "STOP DIST  1,161 FT    WARN DIST  1.3 MI", font=f(13, False), fill=DIM)
    softkeys(d, ["MENU", "DETAILS", "DIST START", "TRACK", "RESTRICT", "ZOOM", "DIM", "HELP"])
    return im


# ====================================================================== ENGINE / LOCOMOTIVE DISPLAY
def bar(d, x, y, w, h, frac, col, label, value, ticks=(0, 40, 80, 120, 160)):
    d.text((x, y - 24), label, font=f(16, False), fill=DIM)
    d.rounded_rectangle([x, y, x + w, y + h], radius=5, fill=(30, 36, 46))
    d.rounded_rectangle([x, y, x + w * frac, y + h], radius=5, fill=col)
    for t in ticks:
        tx = x + w * t / ticks[-1]
        d.line([(tx, y + h), (tx, y + h + 6)], fill=DIM, width=2)
        d.text((tx - 10, y + h + 6), str(t), font=f(12, False), fill=DIM)
    d.text((x + w + 14, y - 6), value, font=f(30, mono=True), fill=TXT)


def readout(d, x, y, label, value, unit="", col=TXT, w=150):
    d.rounded_rectangle([x, y, x + w, y + 74], radius=8, fill=(24, 30, 40), outline=LINE)
    d.text((x + 12, y + 6), label, font=f(14, False), fill=DIM)
    d.text((x + 12, y + 26), value, font=f(30, mono=True), fill=col)
    if unit:
        d.text((x + w - 12 - d.textlength(unit, font=f(13, False)), y + 46), unit, font=f(13, False), fill=DIM)


def engine():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 50], fill=(18, 40, 80))
    d.text((18, 9), "LOCO 4417   SD70ACe", font=f(24), fill=(255, 255, 255))
    d.text((W - 300, 13), "REVERSER  FWD", font=f(20), fill=GREEN)
    # air brake panel
    panel(d, (14, 64, 520, 330), "AIR BRAKES  (PSI)")
    bar(d, 34, 120, 330, 22, 90 / 160, BLUE, "EQUALIZING RES", "90")
    bar(d, 34, 196, 330, 22, 88 / 160, CYAN, "BRAKE PIPE", "88")
    readout(d, 34, 246, "EOT REAR", "86", "PSI", GREEN, 110)
    readout(d, 152, 246, "FLOW", "3", "CFM", TXT, 110)
    readout(d, 270, 246, "MAIN RES", "135", "PSI", TXT, 110)
    readout(d, 388, 246, "BRAKE CYL", "0", "PSI", TXT, 118)
    # speed dial
    panel(d, (534, 64, W - 14, 330))
    cx, cy, r = 650, 214, 112
    for k in range(0, 81, 5):
        a = math.radians(225 - 270 * k / 80)
        r0 = r - (16 if k % 10 == 0 else 8)
        d.line([(cx + math.cos(a) * r0, cy - math.sin(a) * r0), (cx + math.cos(a) * r, cy - math.sin(a) * r)], fill=TXT if k % 10 == 0 else DIM, width=3 if k % 10 == 0 else 1)
        if k % 20 == 0:
            d.text((cx + math.cos(a) * (r - 36) - 12, cy - math.sin(a) * (r - 36) - 12), str(k), font=f(16), fill=TXT)
    lim = math.radians(225 - 270 * 50 / 80)
    d.arc([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], start=-math.degrees(lim), end=-math.degrees(lim) + 60, fill=RED, width=6)
    a = math.radians(225 - 270 * 42 / 80)
    d.line([(cx, cy), (cx + math.cos(a) * (r - 22), cy - math.sin(a) * (r - 22))], fill=AMBER, width=6)
    d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=AMBER)
    d.text((cx - 30, cy + 40), "42", font=f(44), fill=(255, 255, 255))
    d.text((cx - 16, cy + 92), "MPH", font=f(14), fill=DIM)
    readout(d, 790, 84, "THROTTLE", "N8", "", GREEN, 200)
    readout(d, 790, 166, "TRACTIVE EFFORT", "128", "KLB", TXT, 200)
    readout(d, 790, 248, "DISTANCE", "4,212", "FT  (COUNT)", AMBER, 200)
    # consist + profile
    panel(d, (14, 344, W - 14, 600), "TRAIN  -  6,300 FT  12,768 T  100 CARS  -  3 UNITS + REAR DPU")
    px0, px1, base = 40, W - 40, 560
    pts = []
    for i in range(0, 101):
        x = px0 + (px1 - px0) * i / 100
        h = 60 + 30 * math.sin(i / 14.0) + 18 * math.sin(i / 5.3)
        pts.append((x, base - h))
    d.polygon([(px0, base)] + pts + [(px1, base)], fill=(20, 90, 110))
    d.line(pts, fill=CYAN, width=3)
    spd = [(px0, 430), (px0 + 300, 430), (px0 + 330, 470), (px0 + 520, 470), (px0 + 550, 430), (px1, 430)]
    d.line(spd, fill=GREEN, width=3)
    d.text((px0 + 340, 476), "25", font=f(15), fill=AMBER)
    d.rectangle([px0, 380, px0 + 8, 560], fill=AMBER)
    d.text((px0 + 14, 384), "YOU", font=f(14), fill=AMBER)
    for i, mp in enumerate(range(64, 69)):
        x = px0 + 40 + i * 220
        d.text((x - 10, 568), "MP %d" % mp, font=f(14, False), fill=DIM)
    # status line
    panel(d, (14, 612, W - 14, H - 80))
    d.text((30, 630), "IND BRK  LEAD", font=f(17), fill=TXT)
    d.text((230, 630), "AUTO BRK  CUT IN", font=f(17), fill=TXT)
    d.text((470, 630), "DYN BRK  READY", font=f(17), fill=TXT)
    d.text((690, 630), "SAND  OFF   BELL  OFF", font=f(17), fill=DIM)
    softkeys(d, ["MENU", "DIST START", "DIST RESET", "AIR", "CONSIST", "FAULTS", "DIM", "HELP"], active=(1,))
    return im


ptc().save("/home/claude/cabdesign/mock_ptc.png")
engine().save("/home/claude/cabdesign/mock_engine.png")
print("ok")
