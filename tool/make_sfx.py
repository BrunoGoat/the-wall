import math, struct, wave, random, os

SR = 22050
OUT = 'assets/sfx'
os.makedirs(OUT, exist_ok=True)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = 0.89 / peak
    frames = b''.join(struct.pack('<h', int(max(-32767, min(32767, s * norm * 32767)))) for s in samples)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(frames)
    print(name, len(samples)/SR, 'sec')

def env(i, n, attack, decay, curve=2.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-t / decay) ** 1.0
    return a * d

def lowpass(sig, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, prev = [], 0.0
    for s in sig:
        prev = (1 - a) * s + a * prev
        out.append(prev)
    return out

# ---- place.wav : a stone landing. Click, crack, then a low body thump.
def place():
    n = int(0.42 * SR)
    rnd = random.Random(7)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    crack = lowpass(noise, 2600)
    out = []
    for i in range(n):
        t = i / SR
        # sharp contact transient
        click = crack[i] * math.exp(-t / 0.012) * 0.85
        # gritty scrape as it seats
        grit = crack[i] * math.exp(-t / 0.075) * 0.30
        # the weight: two low damped modes
        body = (math.sin(2 * math.pi * 88 * t) * math.exp(-t / 0.13) * 0.85 +
                math.sin(2 * math.pi * 132 * t) * math.exp(-t / 0.09) * 0.45 +
                math.sin(2 * math.pi * 58 * t) * math.exp(-t / 0.17) * 0.55)
        # a touch of stone ring
        ring = math.sin(2 * math.pi * 940 * t) * math.exp(-t / 0.035) * 0.16
        out.append(click + grit + body + ring)
    return lowpass(out, 6500)

# ---- epic.wav : something ancient waking up.
def epic():
    n = int(2.3 * SR)
    out = []
    partials = [(523.25, 1.0, 1.9), (659.25, 0.62, 1.6), (783.99, 0.72, 1.7),
                (1046.5, 0.45, 1.2), (1318.5, 0.30, 0.9), (1567.98, 0.22, 0.7)]
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, amp, dec in partials:
            s += math.sin(2 * math.pi * f * t + 0.4 * math.sin(2 * math.pi * 3.1 * t)) \
                 * amp * math.exp(-t / dec)
        # a slow swell underneath
        sweep = 220 + 500 * (1 - math.exp(-t / 0.5))
        s += math.sin(2 * math.pi * sweep * t) * min(1.0, t / 0.18) * math.exp(-t / 0.9) * 0.5
        out.append(s * min(1.0, t / 0.02))
    return out

# ---- milestone.wav : a horn call for a finished landmark.
def milestone():
    n = int(2.0 * SR)
    out = []
    chord = [196.0, 261.63, 293.66, 392.0]
    for i in range(n):
        t = i / SR
        s = 0.0
        for k, f in enumerate(chord):
            delay = k * 0.055
            if t < delay:
                continue
            tt = t - delay
            a = min(1.0, tt / 0.07) * math.exp(-tt / 1.05)
            # a few harmonics so it reads as brass rather than a sine
            s += (math.sin(2 * math.pi * f * tt) +
                  0.42 * math.sin(2 * math.pi * 2 * f * tt) +
                  0.20 * math.sin(2 * math.pi * 3 * f * tt)) * a * (0.9 - k * 0.11)
        out.append(s)
    return lowpass(out, 4200)

# ---- repair.wav : the wall knitting itself back together.
def repair():
    n = int(1.2 * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = 320 + 900 * (t / 1.2) ** 0.7
        trem = 0.75 + 0.25 * math.sin(2 * math.pi * 11 * t)
        a = min(1.0, t / 0.05) * math.exp(-t / 0.55)
        out.append((math.sin(2 * math.pi * f * t) * 0.7 +
                    math.sin(2 * math.pi * f * 1.5 * t) * 0.3) * a * trem)
    return out

# ---- tap.wav : a small dry UI tick.
def tap():
    n = int(0.07 * SR)
    rnd = random.Random(3)
    noise = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 3800)
    return [noise[i] * math.exp(-(i / SR) / 0.008) for i in range(n)]

write('place.wav', place())
write('epic.wav', epic())
write('milestone.wav', milestone())
write('repair.wav', repair())
write('tap.wav', tap())
