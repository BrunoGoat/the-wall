"""Minimal PNG reader + differ, to locate exactly what changed between renders."""
import struct, zlib, sys

def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i, idat, w, h, bd, ct = 8, b'', 0, 0, 0, 0
    while i < len(d):
        ln = struct.unpack('>I', d[i:i+4])[0]
        typ = d[i+4:i+8]
        body = d[i+8:i+8+ln]
        if typ == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', body[:10])
        elif typ == b'IDAT':
            idat += body
        i += 12 + ln
    raw = zlib.decompress(idat)
    ch = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos+stride]); pos += stride
        if f == 1:
            for x in range(ch, stride):
                line[x] = (line[x] + line[x-ch]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x-ch] if x >= ch else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-ch] if x >= ch else 0
                b = prev[x]
                c = prev[x-ch] if x >= ch else 0
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        out[y*stride:(y+1)*stride] = line
        prev = line
    return w, h, ch, out

a = read_png(sys.argv[1])
b = read_png(sys.argv[2])
assert a[0] == b[0] and a[1] == b[1]
w, h, ch = a[0], a[1], a[2]
pa, pb = a[3], b[3]
minx, miny, maxx, maxy, n = w, h, -1, -1, 0
regions = []
for y in range(h):
    for x in range(w):
        i = (y*w + x)*ch
        if abs(pa[i]-pb[i]) + abs(pa[i+1]-pb[i+1]) + abs(pa[i+2]-pb[i+2]) > 24:
            n += 1
            minx = min(minx, x); maxx = max(maxx, x)
            miny = min(miny, y); maxy = max(maxy, y)
            if len(regions) < 6 and (not regions or abs(regions[-1][0]-x) + abs(regions[-1][1]-y) > 60):
                regions.append((x, y))
print(f'differing pixels: {n}')
if n:
    print(f'bounding box: x {minx}..{maxx}  y {miny}..{maxy}')
    print('sample spots:', regions)
