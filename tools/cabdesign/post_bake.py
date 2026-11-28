import sys
from PIL import Image, ImageFilter
for base in sys.argv[1:]:
    im = Image.open(base + "_ao.png").convert("L").filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.0))
    im.save(base + "_ao.png")
    r, g, b = Image.open(base + "_wear.png").convert("RGB").split()
    Image.merge("RGB", (r.filter(ImageFilter.MedianFilter(3)), g.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.0)), b)).save(base + "_wear.png")
    print("smoothed", base)
