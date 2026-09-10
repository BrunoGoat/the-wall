"""Recorta el icono de la app a partir de `tool/icon/towny.png`.

El dibujo —la casa de tres piezas sobre el campo, con su sombra en diagonal—
viene hecho de fuera y aquí no se retoca: sólo se recorta, se escala y se
reparte por los tamaños que pide cada sitio.

Lo único que hay que pensar es el recorte. El campo del dibujo es plano de
verdad —sus píxeles caen todos a menos de tres unidades de un mismo verde,
medido— así que separar la casa de él es cuestión de distancia de color, con
una rampa corta en medio para que los bordes queden suavizados y no dentados.
La sombra está a treinta y siete unidades y entra entera; la casa, a cien y
pico.

El icono adaptativo de Android quiere dos capas de 108dp de las que sólo los
72dp centrales están a salvo de la máscara, sea círculo, cuadrado redondeado o
lo que el lanzador decida. Así que el fondo es el verde a secas, la casa va en
la capa de delante y encogida a esos 72dp, y no hay máscara que le corte la
chimenea.
"""

import math
import os

from PIL import Image

ORIGEN = 'tool/icon/towny.png'
RES = 'android/app/src/main/res'
WEB = 'web'

# Cuánto del lado ocupa la casa en cada sitio. En la capa adaptativa tiene que
# caber en los 72dp centrales de 108 —el 66%— y se le deja algo de aire; el
# icono de siempre no lleva una máscara tan agresiva y puede permitirse más.
DENTRO_ADAPTATIVO = 0.64
DENTRO_LEGADO = 0.74

DENSIDADES = {
    'mipmap-mdpi': 1,
    'mipmap-hdpi': 1.5,
    'mipmap-xhdpi': 2,
    'mipmap-xxhdpi': 3,
    'mipmap-xxxhdpi': 4,
}


def _campo(im):
    """El verde del fondo, tomado del borde, que es todo fondo."""
    px = im.load()
    w, h = im.size
    borde = [px[x, y] for x in range(0, w, 5) for y in (1, h - 2)]
    borde += [px[x, y] for y in range(0, h, 5) for x in (1, w - 2)]
    return tuple(round(sum(p[i] for p in borde) / len(borde)) for i in range(3))


def _verdoso(p):
    """Si un píxel es sombra sobre la hierba y no parte de la casa.

    La sombra es verde oscuro: el verde le domina y el azul se le queda muy
    atrás. En la casa eso no pasa nunca — el muro es casi blanco, el tejado
    tira a azul, y la chimenea y las ventanas a rojo.
    """
    r, g, b = p[:3]
    return g >= r and g - b > 25


def recorta(cerrar_sombra):
    """El dibujo con el fondo quitado.

    `cerrar_sombra` deja fuera también la sombra, que es lo que hace falta para
    la capa monocroma: ahí Android tiñe la silueta de un color plano, y una
    silueta que se lleve la sombra pegada deja de parecer una casa y pasa a ser
    un manchón.
    """
    im = Image.open(ORIGEN).convert('RGB')
    campo = _campo(im)
    px = im.load()
    w, h = im.size
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if cerrar_sombra and _verdoso(p):
                continue
            d = math.dist(p, campo)
            # Nada por debajo de ocho, todo a partir de veinte y una rampa en
            # medio: es el suavizado del borde del dibujo original, que si se
            # corta en seco se ve dentado a cuarenta y ocho píxeles.
            a = 0.0 if d <= 8 else 1.0 if d >= 20 else (d - 8) / 12
            if a > 0:
                dst[x, y] = p + (round(a * 255),)
    return out, campo


def coloca(recorte, size, dentro, fondo=None):
    """La casa centrada y a escala en un cuadrado, sobre `fondo` o en el aire."""
    caja = recorte.getbbox()
    lado = max(caja[2] - caja[0], caja[3] - caja[1])
    k = size * dentro / lado
    trozo = recorte.crop(caja)
    nuevo = (max(1, round(trozo.width * k)), max(1, round(trozo.height * k)))
    trozo = trozo.resize(nuevo, Image.LANCZOS)
    lienzo = Image.new(
        'RGBA', (size, size), (fondo + (255,)) if fondo else (0, 0, 0, 0))
    lienzo.alpha_composite(
        trozo, ((size - nuevo[0]) // 2, (size - nuevo[1]) // 2))
    return lienzo


if __name__ == '__main__':
    con_sombra, campo = recorta(False)
    sin_sombra, _ = recorta(True)
    print('campo', campo, '->', '#%02X%02X%02X' % campo)

    for carpeta, escala in DENSIDADES.items():
        os.makedirs(f'{RES}/{carpeta}', exist_ok=True)
        legado = round(48 * escala)
        capa = round(108 * escala)
        coloca(con_sombra, legado, DENTRO_LEGADO, campo).convert('RGB').save(
            f'{RES}/{carpeta}/ic_launcher.png')
        coloca(con_sombra, capa, DENTRO_ADAPTATIVO).save(
            f'{RES}/{carpeta}/ic_launcher_foreground.png')
        coloca(sin_sombra, capa, DENTRO_ADAPTATIVO).save(
            f'{RES}/{carpeta}/ic_launcher_monochrome.png')
        print(carpeta, legado, capa)

    os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
    open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n')
    open(f'{RES}/values/ic_launcher_background.xml', 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
        '</resources>\n' % campo)
    print('icono adaptativo escrito')

    # Y la web, que también tiene su pestaña y su pantalla de inicio.
    for size in (192, 512):
        coloca(con_sombra, size, DENTRO_LEGADO, campo).convert('RGB').save(
            f'{WEB}/icons/Icon-{size}.png')
        coloca(con_sombra, size, DENTRO_ADAPTATIVO, campo).convert('RGB').save(
            f'{WEB}/icons/Icon-maskable-{size}.png')
    coloca(con_sombra, 64, DENTRO_LEGADO, campo).convert('RGB').save(
        f'{WEB}/favicon.png')
    print('iconos de la web escritos')
