"""Lo que suena de fondo mientras el pueblo está ahí.

Tres capas en re dórico —el modo de las cantigas, y el único que suena
medieval sin disfrazarse— a sesenta pulsos por minuto, que es el paso de
alguien que no va a ningún lado:

  mus_bordon  6 compases  el bordón de zanfoña: re y la, sin moverse nunca
  mus_laud    8 compases  el laúd, punteado, cuerda por cuerda
  mus_flauta 10 compases  una melodía de flauta, con más silencio que notas

Las tres duran un número entero de compases del mismo pulso, así que caen
siempre en el mismo sitio del compás, pero sus frases son de largo distinto:
seis contra ocho contra diez. La combinación no se repite igual hasta los
ciento veinte compases — ocho minutos — y como la armonía es un bordón que no
se mueve, cualquier desfase entre ellas suena bien. Es la vieja treta de hacer
mucha música con poco archivo, y aquí además es exactamente lo que hacía un
juglar con una zanfoña: una nota que no para, y encima lo que se le ocurra.

El laúd es Karplus-Strong: ruido en un tubo que se muerde la cola y se va
apagando, que es literalmente lo que hace una cuerda pulsada. La flauta es
aire con dos armónicos. Y todo pasa por una reverberación pequeña, de sala de
piedra, porque esta música no se toca al aire libre.

Los bucles cierran sin costura: al bordón se le encajan las frecuencias en
múltiplos exactos de la duración del bucle, y a las capas con notas se les
deja una cola de cuatro segundos que se suma otra vez al principio, así que
la última campanada del laúd sigue sonando cuando el bucle vuelve a empezar.
"""
import math, struct, wave, random, os

SR = 16000
OUT = 'assets/sfx'
BPM = 60.0
BEAT = 60.0 / BPM          # 1.0 s
BAR = 4 * BEAT             # 4.0 s
TAIL = 4.0                 # cuánto se deja sonar más allá del bucle
os.makedirs(OUT, exist_ok=True)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# Re dórico: re mi fa sol la si do
D2, A2, D3, F3, G3, A3, B3, C4, D4, E4, F4, G4, A4, B4, C5, D5 = (
    38, 45, 50, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74)


def write(name, samples, scale):
    """Sin normalizar por archivo: las tres capas tienen que conservar entre
    ellas el volumen con el que se escribieron, o el bordón se come la flauta."""
    peak = max(abs(s) for s in samples) * scale
    frames = b''.join(
        struct.pack('<h', int(max(-32767, min(32767, s * scale * 32767))))
        for s in samples)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print('%-16s %5.1f s  %5d KB  pico %.2f' %
          (name, len(samples) / SR, len(frames) / 1024, peak))


def lowpass(sig, cutoff, cyclic=False):
    """Con `cyclic`, el filtro se carga dando una vuelta en vacío antes de
    escribir nada. Importa: un filtro que arranca en cero deja un transitorio
    al principio del archivo que no existe al final, y eso es justo un chasquido
    en el empalme del bucle — que era el defecto que tenía el bordón."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    prev = 0.0
    if cyclic:
        for x in sig:
            prev = (1 - a) * x + a * prev
    out = []
    for x in sig:
        prev = (1 - a) * x + a * prev
        out.append(prev)
    return out


# ------------------------------------------------------------------- voces

def pluck(out, at, note, dur, vel, damp=0.9965, seed=0):
    """Una cuerda pulsada. El ruido inicial se filtra: una cuerda de tripa
    pulsada con la yema no tiene el brillo que tiene una púa."""
    f = midi(note)
    n = max(4, int(round(SR / f - 0.5)))
    rnd = random.Random(seed * 7919 + note)
    buf = [rnd.uniform(-1, 1) for _ in range(n)]
    # dos pasadas de media móvil: quita el filo del ruido blanco
    for _ in range(2):
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(n)]
    # y fuera la media: el lazo de Karplus-Strong es un promediador, así que
    # cualquier continua que traiga el ruido inicial no se apaga nunca y se
    # queda de pedestal debajo de toda la cuerda.
    avg = sum(buf) / n
    buf = [v - avg for v in buf]
    start = int(at * SR)
    total = int(dur * SR)
    idx = 0
    for i in range(total):
        a = buf[idx]
        b = buf[(idx + 1) % n]
        buf[idx] = damp * 0.5 * (a + b)
        idx = (idx + 1) % n
        j = start + i
        if j >= len(out):
            break
        # el arranque, suavizado, para que no chasquee
        k = min(1.0, i / 90.0)
        out[j] += a * vel * k


def blow(out, at, note, dur, vel, seed=0):
    """Flauta de pico: el fundamental, un poco de octava, un soplo de aire y
    un vibrato que entra tarde, como el de alguien que sostiene la nota."""
    f = midi(note)
    rnd = random.Random(seed * 104729 + note)
    start = int(at * SR)
    total = int(dur * SR)
    fade = min(total * 0.35, 0.22 * SR)
    rise = 0.10 * SR
    ph = rnd.uniform(0, 6.28)
    breath = 0.0
    for i in range(total):
        j = start + i
        if j >= len(out):
            break
        t = i / SR
        env = min(1.0, i / rise) * min(1.0, (total - i) / fade)
        vib = 1 + 0.006 * math.sin(2 * math.pi * 4.7 * t) * min(1.0, t / 0.8)
        w = 2 * math.pi * f * vib * t + ph
        s = math.sin(w) + 0.22 * math.sin(2 * w) + 0.06 * math.sin(3 * w)
        breath = 0.93 * breath + 0.07 * rnd.uniform(-1, 1)
        out[j] += (s * 0.62 + breath * 0.10) * env * vel


# -------------------------------------------------------------- la sala

def reverb(sig, wet=0.30):
    """Cuatro peines y dos passtodo: una sala de piedra pequeña. Barata, y es
    la diferencia entre tres instrumentos y tres instrumentos en un sitio."""
    n = len(sig)
    out = [0.0] * n
    for delay, gain in ((1231, 0.80), (1607, 0.78), (1913, 0.76), (2251, 0.74)):
        buf = [0.0] * delay
        p = 0
        prev = 0.0
        for i in range(n):
            v = buf[p]
            out[i] += v * 0.25
            prev = 0.72 * v + 0.28 * prev      # las paredes se comen los agudos
            buf[p] = sig[i] + prev * gain
            p = p + 1 if p + 1 < delay else 0
    for delay, gain in ((331, 0.7), (109, 0.7)):
        buf = [0.0] * delay
        p = 0
        for i in range(n):
            v = buf[p]
            y = v - gain * out[i]
            buf[p] = out[i] + gain * y
            out[i] = y
            p = p + 1 if p + 1 < delay else 0
    return [s * (1 - wet) + w * wet for s, w in zip(sig, out)]


def wrap(sig, bars):
    """Cierra el bucle: lo que sigue sonando después del último compás se suma
    otra vez al principio, que es donde va a sonar cuando el bucle vuelva."""
    n = int(round(bars * BAR * SR))
    out = sig[:n]
    for i in range(min(len(sig) - n, n)):
        out[i] += sig[n + i]
    return out


# ------------------------------------------------------------- las capas

def bordon(bars=6):
    """La zanfoña. Re y la, y nada más en veinticuatro segundos.

    Cada parcial se encaja en un múltiplo entero de la duración del bucle, así
    que todos cierran un número entero de ciclos y el empalme es exacto: no
    hace falta ni un desvanecido."""
    n = int(round(bars * BAR * SR))
    dur = n / SR
    out = [0.0] * n

    def snap(f):
        return max(1, round(f * dur)) / dur

    voices = []
    for root, gain in ((D2, 1.00), (A2, 0.62), (D3, 0.40)):
        f0 = midi(root)
        for h in range(1, 7):
            for det in (-1.6, 1.6):
                voices.append((snap(f0 * h + det * 0.01 * h),
                               gain / h ** 1.45 * (0.55 if h > 1 else 1.0)))
    swell = snap(1 / dur)
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, a in voices:
            s += math.sin(2 * math.pi * f * t) * a
        # una respiración por bucle, y otra más corta encima
        env = 0.74 + 0.18 * math.sin(2 * math.pi * swell * t) \
                   + 0.08 * math.sin(2 * math.pi * swell * 3 * t + 1.1)
        out[i] = s * env
    out = lowpass(out, 1500, cyclic=True)
    return [s * 0.16 for s in out]


def laud(bars=8):
    """Ocho compases punteados. Arpegios sobre el bordón, con el bajo en el
    primer tiempo y las cuerdas altas a contratiempo."""
    P1 = [(0, D3, 1.00), (0.75, A3, 0.58), (1.5, D4, 0.70),
          (2.25, A3, 0.52), (3.0, F4, 0.62), (3.5, D4, 0.46)]
    P2 = [(0, D3, 0.96), (0.75, A3, 0.56), (1.5, C4, 0.68),
          (2.25, A3, 0.50), (3.0, E4, 0.58), (3.5, C4, 0.44)]
    P3 = [(0, F3, 0.92), (0.75, C4, 0.56), (1.5, F4, 0.66),
          (2.25, C4, 0.48), (3.0, A4, 0.56), (3.5, F4, 0.42)]
    P4 = [(0, G3, 0.90), (0.75, D4, 0.54), (1.5, B3, 0.62),
          (2.25, D4, 0.46), (3.0, A3, 0.56), (3.5, G3, 0.40)]
    plan = [P1, P2, P1, P3, P1, P2, P3, P4]

    n = int(round((bars * BAR + TAIL) * SR))
    out = [0.0] * n
    for b, pattern in enumerate(plan):
        for k, (off, note, vel) in enumerate(pattern):
            at = b * BAR + off * BEAT
            pluck(out, at, note, 2.6, vel * 0.30, seed=b * 13 + k)
    return wrap(reverb(out, 0.34), bars)


def flauta(bars=10):
    """Diez compases, y dos de ellos son silencio entero. Una melodía de fondo
    que no calla nunca deja de ser fondo."""
    tune = [
        (0.0, A4, 2.0), (2.0, G4, 1.0), (3.0, A4, 1.0),
        (4.0, F4, 2.0), (6.0, E4, 2.0),
        (8.0, D4, 3.0),
        # compás 3: callado
        (16.0, A4, 1.0), (17.0, B4, 1.0), (18.0, C5, 2.0),
        (20.0, B4, 2.0), (22.0, A4, 2.0),
        (24.0, G4, 3.0),
        # compás 7: callado
        (32.0, F4, 1.5), (33.5, G4, 0.5), (34.0, E4, 2.0),
        (36.0, D4, 3.0),
    ]
    n = int(round((bars * BAR + TAIL) * SR))
    out = [0.0] * n
    for i, (beat, note, length) in enumerate(tune):
        blow(out, beat * BEAT, note, length * BEAT * 0.94, 0.26, seed=i)
    return wrap(reverb(out, 0.38), bars)


# Cada archivo se escribe aprovechando los dieciséis bits enteros —pico 0.85—
# y el equilibrio entre las tres capas lo pone el volumen de cada reproductor
# en `Sensory._musWant`. Se hace así y no al revés porque un bordón escrito al
# veinte por ciento de la escala son tres bits de resolución tirados.
if __name__ == '__main__':
    for name, layer in (('mus_bordon.wav', bordon()),
                        ('mus_laud.wav', laud()),
                        ('mus_flauta.wav', flauta())):
        write(name, layer, 0.85 / max(abs(s) for s in layer))
