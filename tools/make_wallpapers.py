"""Generate a small set of smooth abstract wallpapers for the TV's theme directory.

They are deliberately soft: WallpaperPlayer blurs whatever it decodes once, so these
are meant to read as colour fields behind the glass panels, not as photographs.
"""
import math, pathlib
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
OUT = pathlib.Path(r"C:/Users/ryuen/Documents/Projects/TCLTV/.debloat/wallpapers")
OUT.mkdir(parents=True, exist_ok=True)

# name -> (top-left, bottom-right, accent glow)
PALETTES = {
    "ember":    ((36, 8, 10),  (8, 4, 6),    (168, 46, 32)),
    "midnight": ((12, 18, 40), (5, 6, 14),   (38, 78, 120)),
    "plum":     ((34, 12, 38), (9, 5, 12),   (116, 44, 104)),
    "forest":   ((10, 30, 26), (4, 10, 10),  (28, 96, 78)),
    "ocean":    ((8, 26, 40),  (4, 8, 14),   (24, 104, 128)),
}

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def make(name, c0, c1, glow):
    # diagonal base gradient, built small then scaled up so it is perfectly smooth
    small = Image.new("RGB", (64, 36))
    px = small.load()
    for y in range(36):
        for x in range(64):
            px[x, y] = lerp(c0, c1, (x / 63) * 0.6 + (y / 35) * 0.4)
    img = small.resize((W, H), Image.BICUBIC)

    # two soft elliptical glows, off-centre, for depth
    for cx, cy, rad, strength in ((0.28, 0.30, 0.55, 1.0), (0.78, 0.72, 0.42, 0.55)):
        g = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(g)
        d.ellipse([W * (cx - rad), H * (cy - rad * 0.75),
                   W * (cx + rad), H * (cy + rad * 0.75)],
                  fill=int(255 * strength))
        g = g.filter(ImageFilter.GaussianBlur(180))
        tint = Image.new("RGB", (W, H), glow)
        img = Image.composite(tint, img, g.point(lambda v: v // 3))

    # one more pass so there is no banding anywhere
    img = img.filter(ImageFilter.GaussianBlur(24))
    img.save(OUT / f"{name}.jpg", quality=88, optimize=True)
    return img.size

for name, (c0, c1, glow) in PALETTES.items():
    print(name, make(name, c0, c1, glow))

print("written to", OUT)
for f in sorted(OUT.glob("*.jpg")):
    print(" ", f.name, f.stat().st_size, "bytes")
