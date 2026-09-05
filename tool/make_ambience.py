"""The valley's own noise.

Three loops that stack rather than swap: the field is always there, the town
murmur comes in as the place grows, and the busy layer only once it is both big
and lived in. A town that has been left keeps only the field and the wind, which
is what abandonment sounds like — not silence, just nobody.

Plus a handful of one-shots that fire now and then, chosen by whether the place
is alive (a bell, a cockerel, a hammer) or empty (a crow, a door on its hinges).
"""
import math, struct, wave, random, os

SR = 22050
OUT = 'assets/sfx'
os.makedirs(OUT, exist_ok=True)


def write(name, samples, gain=0.89):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = gain / peak
    frames = b''.join(
        struct.pack('<h', int(max(-32767, min(32767, s * norm * 32767))))
        for s in samples)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(name, round(len(samples) / SR, 2), 'sec',
          round(len(frames) / 1024), 'KB')


def lowpass(sig, cutoff, prev=0.0):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out = []
    for s in sig:
        prev = (1 - a) * s + a * prev
        out.append(prev)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [s - l for s, l in zip(sig, lp)]


def seamless(sig, fade=0.6):
    """Crossfades the tail over the head so the loop has no seam."""
    n = int(fade * SR)
    out = list(sig[:-n])
    for i in range(n):
        k = i / n
        out[i] = out[i] * k + sig[len(sig) - n + i] * (1 - k)
    return out


def chirp(out, at, seed, pitch=2600, dur=0.10):
    rnd = random.Random(seed)
    n = int(dur * SR)
    start = int(at * SR)
    for i in range(n):
        if start + i >= len(out):
            break
        t = i / SR
        f = pitch * (1 + 0.5 * math.sin(2 * math.pi * 18 * t))
        a = math.sin(math.pi * (i / n)) ** 2
        out[start + i] += math.sin(2 * math.pi * f * t) * a * 0.16 * rnd.uniform(0.7, 1.0)


LOOP = 8.0


def field():
    """Wind over grass, and a bird or two a long way off."""
    n = int(LOOP * SR)
    rnd = random.Random(11)
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    air = lowpass(raw, 900)
    out = []
    for i in range(n):
        t = i / SR
        # Two slow swells, out of step, so the wind never has a period you can
        # hear.
        gust = (0.55 + 0.45 * math.sin(2 * math.pi * t / 6.3)) * \
               (0.7 + 0.3 * math.sin(2 * math.pi * t / 2.7 + 1.1))
        out.append(air[i] * gust * 0.5)
    for at, p in ((1.4, 3100), (4.9, 2500), (6.2, 3400)):
        chirp(out, at, int(at * 100), pitch=p)
    return seamless(out)


def town():
    """A village at work: a murmur, and a hammer somewhere behind it."""
    n = int(LOOP * SR)
    rnd = random.Random(23)
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    voices = lowpass(highpass(raw, 180), 780)
    out = []
    for i in range(n):
        t = i / SR
        swell = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 4.1)) * \
                (0.6 + 0.4 * math.sin(2 * math.pi * t / 1.7 + 0.6))
        out.append(voices[i] * swell * 0.42)
    # A mallet on wood, unevenly, like somebody actually working.
    hits = [0.55, 1.2, 1.75, 3.4, 4.0, 4.55, 6.1, 6.7]
    for k, at in enumerate(hits):
        start = int(at * SR)
        m = int(0.09 * SR)
        for i in range(m):
            if start + i >= n:
                break
            t = i / SR
            a = math.exp(-t / 0.018)
            out[start + i] += (math.sin(2 * math.pi * 190 * t) * 0.6 +
                               math.sin(2 * math.pi * 420 * t) * 0.4) * a * 0.20
    return seamless(out)


def life():
    """A market day: busier, with a bell across the roofs."""
    n = int(LOOP * SR)
    rnd = random.Random(37)
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    crowd = lowpass(highpass(raw, 240), 1400)
    out = []
    for i in range(n):
        t = i / SR
        swell = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 3.3 + 2.0))
        out.append(crowd[i] * swell * 0.40)
    # A bell, twice, well inside the loop.
    for at in (2.1, 5.6):
        start = int(at * SR)
        m = int(2.2 * SR)
        for i in range(m):
            if start + i >= n:
                break
            t = i / SR
            a = math.exp(-t / 0.75) * min(1.0, t / 0.004)
            out[start + i] += (math.sin(2 * math.pi * 523 * t) * 0.5 +
                               math.sin(2 * math.pi * 784 * t) * 0.3 +
                               math.sin(2 * math.pi * 1318 * t) * 0.2) * a * 0.16
    return seamless(out)


def bell():
    """One stroke, far off. For a town that is doing well."""
    n = int(2.6 * SR)
    out = []
    for i in range(n):
        t = i / SR
        a = math.exp(-t / 0.85) * min(1.0, t / 0.004)
        out.append((math.sin(2 * math.pi * 440 * t) * 0.5 +
                    math.sin(2 * math.pi * 660 * t) * 0.28 +
                    math.sin(2 * math.pi * 1100 * t) * 0.16 +
                    math.sin(2 * math.pi * 1760 * t) * 0.06) * a)
    return out


def crow():
    """Two harsh notes over an empty place."""
    n = int(1.1 * SR)
    rnd = random.Random(5)
    out = [0.0] * n
    for k, at in enumerate((0.02, 0.42)):
        start = int(at * SR)
        m = int(0.26 * SR)
        for i in range(m):
            if start + i >= n:
                break
            t = i / SR
            f = 620 - 180 * (t / 0.26)
            rasp = 1 + 0.55 * math.sin(2 * math.pi * 62 * t)
            a = math.sin(math.pi * min(1.0, i / m)) ** 1.4
            out[start + i] += math.sin(2 * math.pi * f * t * rasp) * a * 0.8 * \
                rnd.uniform(0.85, 1.0)
    return lowpass(out, 2600)


def creak():
    """A hinge nobody has oiled. The sound of nobody home."""
    n = int(1.5 * SR)
    rnd = random.Random(9)
    out = []
    for i in range(n):
        t = i / SR
        f = 210 + 260 * (t / 1.5) ** 2
        # Stick and slip, which is the whole character of a creak.
        grind = 0.5 + 0.5 * math.sin(2 * math.pi * (9 + 7 * t) * t)
        a = min(1.0, t / 0.18) * math.exp(-max(0.0, t - 0.7) / 0.35)
        out.append(math.sin(2 * math.pi * f * t) * grind * a * 0.7 +
                   rnd.uniform(-1, 1) * 0.05 * a)
    return lowpass(out, 3000)


def cock():
    """A cockerel, for a town with people in it."""
    n = int(1.0 * SR)
    out = [0.0] * n
    steps = ((0.00, 760, 0.16), (0.18, 980, 0.13), (0.34, 640, 0.30))
    for at, f0, dur in steps:
        start = int(at * SR)
        m = int(dur * SR)
        for i in range(m):
            if start + i >= n:
                break
            t = i / SR
            f = f0 * (1 - 0.18 * (t / dur))
            rasp = 1 + 0.35 * math.sin(2 * math.pi * 48 * t)
            a = math.sin(math.pi * (i / m)) ** 0.8
            out[start + i] += math.sin(2 * math.pi * f * t * rasp) * a * 0.7
    return lowpass(out, 4200)


write('amb_field.wav', field(), gain=0.62)
write('amb_town.wav', town(), gain=0.62)
write('amb_life.wav', life(), gain=0.62)
write('bell.wav', bell(), gain=0.72)
write('crow.wav', crow(), gain=0.70)
write('creak.wav', creak(), gain=0.62)
write('cock.wav', cock(), gain=0.70)
