"""Generates the launcher icons: a limestone wall against a night-slate ground.

No imaging library is available here, so this writes PNGs directly (zlib +
struct) and antialiases by supersampling 4x.
"""
import os, struct, zlib

BG = (0x2E, 0x38, 0x50)          # deep slate, so the limestone reads at 48px
STONE_HI = (0xF3, 0xE8, 0xCB)
STONE_MID = (0xDE, 0xCE, 0xA9)
STONE_LO = (0xB6, 0xA5, 0x82)
JOINT = (0x4A, 0x44, 0x3A)
SKY = (0x6E, 0x88, 0xB4)

def png(path, w, h, px):
    raw = b''.join(b'\x00' + bytes(px[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    out = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 9))
           + chunk(b'IEND', b''))
    open(path, 'wb').write(out)

# --- the picture, drawn in a 0..1 square ---
COURSES = [
    # (y0, y1, [(x0, x1, shade)])
    (0.62, 0.78, [(0.10, 0.36, 0), (0.38, 0.62, 1), (0.64, 0.90, 2)]),
    (0.46, 0.60, [(0.10, 0.30, 1), (0.32, 0.58, 2), (0.60, 0.90, 0)]),
    (0.30, 0.44, [(0.10, 0.42, 2), (0.44, 0.68, 0), (0.70, 0.90, 1)]),
]
MERLONS = [(0.10, 0.24), (0.32, 0.46), (0.54, 0.68), (0.76, 0.90)]
SHADES = [STONE_HI, STONE_MID, STONE_LO]

def sample(x, y, transparent_bg):
    """Colour at a point, or None for transparent."""
    # crenellations
    for (mx0, mx1) in MERLONS:
        if 0.16 <= y < 0.30 and mx0 <= x < mx1:
            return STONE_HI if x < mx0 + (mx1 - mx0) * 0.55 else STONE_MID
    for (y0, y1, blocks) in COURSES:
        if y0 <= y < y1:
            for (x0, x1, s) in blocks:
                if x0 <= x < x1:
                    # a lit top edge on every stone
                    if y - y0 < (y1 - y0) * 0.18:
                        c = SHADES[s]
                        return tuple(min(255, int(v * 1.10)) for v in c)
                    return SHADES[s]
            return JOINT if 0.10 <= x < 0.90 else (None if transparent_bg else BG)
    if 0.30 <= y < 0.78 and 0.10 <= x < 0.90:
        return JOINT
    # ground line under the wall
    if 0.78 <= y < 0.82 and 0.06 <= x < 0.94:
        return JOINT
    return None if transparent_bg else BG

def render(size, transparent_bg, inset):
    """inset: fraction of the canvas the drawing occupies (adaptive safe zone)."""
    ss = 4
    n = size * ss
    px = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            r = g = b = a = 0
            for sy in range(ss):
                for sx in range(ss):
                    fx = (x * ss + sx + 0.5) / n
                    fy = (y * ss + sy + 0.5) / n
                    ux = (fx - 0.5) / inset + 0.5
                    uy = (fy - 0.5) / inset + 0.5
                    c = None
                    if 0 <= ux < 1 and 0 <= uy < 1:
                        c = sample(ux, uy, transparent_bg)
                    elif not transparent_bg:
                        c = BG
                    if c is not None:
                        r += c[0]; g += c[1]; b += c[2]; a += 255
            k = ss * ss
            i = (y * size + x) * 4
            px[i] = r // k; px[i+1] = g // k; px[i+2] = b // k; px[i+3] = a // k
    return px

res = 'android/app/src/main/res'
legacy = {'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
          'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192}
fore = {'mipmap-mdpi': 108, 'mipmap-hdpi': 162, 'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324, 'mipmap-xxxhdpi': 432}

for d, s in legacy.items():
    os.makedirs(f'{res}/{d}', exist_ok=True)
    png(f'{res}/{d}/ic_launcher.png', s, s, render(s, False, 0.84))
    print(d, 'ic_launcher', s)
for d, s in fore.items():
    # The adaptive foreground must keep its art inside the central 66%.
    png(f'{res}/{d}/ic_launcher_foreground.png', s, s, render(s, True, 0.60))
    print(d, 'foreground', s)

os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
open(f'{res}/values/ic_launcher_background.xml', 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">#2E3850</color>\n'
    '</resources>\n')
print('adaptive icon written')
