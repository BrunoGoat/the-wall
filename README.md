# La Muralla

Una app de hábitos donde cada logro se registra colocando **un ladrillo**, y
ladrillo a ladrillo se levanta una muralla que es la visualización de todo lo
conseguido. Si dejás de sumar ladrillos, la muralla empieza a deteriorarse:
mantenerla importa tanto como construirla.

La muralla es 3D y se puede orbitar libremente —desde el costado, desde atrás,
desde arriba— con un estilo gráfico estilizado y piedra caliza.

## La regla que no se negocia

**Un ladrillo es siempre un logro. Nunca un lote de varios.**

Todo lo demás está construido encima de esa regla. El ritmo de la app no se
expresa en días ni en porcentajes sino en cantidad de ladrillos, y no hay ningún
camino en el código que agregue más de una piedra por acción.

## El ritmo, pensado para uso real

Este es el segundo eje del diseño, y es el que decide casi todo lo demás. Las
cifras están elegidas para el uso real, no para una demo con miles de ladrillos.

Con uno o dos hábitos, un mes son unos 30–60 ladrillos. Un año, entre 350 y 1100.

| | |
|---|---|
| Primer épico escondido | ladrillo **4** |
| Primer hito (Torre de Vigía) | empieza en el **12**, termina en el **34** |
| Épicos escondidos en el primer mes | **5 a 10** |
| Hitos distintos en un año | **4 a 10**, todos de formas diferentes |
| Épicos escondidos en un año | **25 a 55** de los 100 |
| Los 100 épicos | recién alrededor del ladrillo 6000 |

Es decir: el primer mes tiene que sentirse vivo, y quien sostiene la muralla un
año entero ya se cruzó con hitos variados y muchos épicos, sin agotar nunca los
cien. Todo esto está fijado con tests (`test/pacing_test.dart`), así que no se
puede desajustar sin que algo se ponga en rojo.

## Qué hay en la muralla

**Ladrillos.** Cada piedra es un polígono irregular distinto, generado a partir
del índice del ladrillo: esquinas comidas, cantos rotos, juntas que no se
alinean, anchos que varían entre 0,36 y 1,04. No es un mismo rectángulo repetido
a distintas escalas. Las piedras atraviesan todo el espesor del muro, así que un
logro es siempre exactamente una piedra visible, se la mire de donde se la mire.

**El frente de obra.** Cada piedra nueva va a la hilada *más alta* donde entre
legalmente, lo que produce el borde escalonado de una muralla realmente en
construcción, en vez de una fila que repta por el suelo.

**Hitos.** Diez siluetas genuinamente distintas —torre de vigía, puerta, torre
mayor, escalinata, puente levadizo, almenara, bastión, arcada, santuario,
barbacana— que se levantan **con los ladrillos reales**, hilada por hilada,
durante las semanas que cuesta ganarlos. Nunca aparecen de golpe. Cuando el
catálogo da la vuelta, el hito vuelve con otro nombre y algo más de costo.

**Cien épicos únicos.** Cien, todos diferentes, ninguno repetido. No se regalan:
cuando el ladrillo que lo lleva se coloca, la piedra queda con una anomalía
tenue, y descubrirlo es trabajo de quien mira su muralla. Se encuentran tocando
la piedra.

**La distancia.** Cuando la muralla se hace larga, lo que está lejos se dibuja
como su propia silueta almenada perdiéndose en la calina, como la Gran Muralla.

**El deterioro.** Después de un día y medio sin ladrillos la muralla empieza a
resentirse: la piedra se apaga, aparece liquen, el mortero se abre, el cielo se
enturbia. Nunca desaparece y nunca se pierde nada de lo construido. **Un solo
ladrillo la repara entera**, con una ola de reparación que recorre el muro.

## Cómo se ve y cómo se siente

- Renderizador 3D propio (`lib/engine/`): rasterizador por algoritmo del pintor,
  sombreado plano, sin dependencias nativas. Presupuesto de detalle adaptativo
  que sube y baja según el tiempo de cuadro, para que vaya a 60 fps.
- Paleta que sigue la hora real del día: amanecer, día, atardecer y noche con
  estrellas, todas atravesadas por el estado de deterioro.
- El momento de colocar: la cámara vuela a la piedra, cae con peso, aterriza con
  polvo, esquirlas, sacudida de cámara, destello, sonido de piedra sintetizado y
  una secuencia de vibración de dos tiempos.

## Correr y compilar

```bash
flutter pub get
flutter test          # 47 tests
flutter analyze
flutter run
flutter build apk --release
```

### APK

Cada push a la rama de desarrollo compila la APK en GitHub Actions
(`.github/workflows/apk.yml`) y la publica como *release* y como artefacto.
Está firmada con la clave de debug, así que se instala directo en el teléfono
(Android 6.0 / API 23 o superior).

### Herramientas de desarrollo

`--dart-define` para inspeccionar estados que de otro modo tardarían un año:

| define | para qué |
|---|---|
| `SEED=365` | arranca con esa cantidad de ladrillos |
| `IDLE_DAYS=13` | los coloca hace N días, para ver el deterioro |
| `HOUR=19` | fija la hora del día |
| `CAM_YAW/CAM_PITCH/CAM_DIST/CAM_AT` | encuadre fijo |
| `BUDGET=340` | fija el presupuesto de detalle |

```bash
dart run tool/inspect.dart        # imprime el ritmo y la geometría
python3 tool/make_sfx.py          # regenera los sonidos
python3 tool/make_icons.py        # regenera los íconos
```

## Mapa del código

```
lib/
  core/      hash determinista y matemática 3D
  data/      los 100 épicos, los 10 hitos, y el ritmo
  model/     hábitos, ladrillos, hallazgos, persistencia
  engine/    trazado de la muralla, piedras, cámara, paleta, renderizador
  fx/        partículas, sonido y vibración
  ui/        la pantalla, las hojas y los momentos de revelación
```

Nada de la forma de la muralla se guarda en disco: se deriva del índice de cada
ladrillo. Una piedra colocada hace un año se vuelve a dibujar idéntica en cada
arranque, y el archivo guardado son sólo los hábitos, los ladrillos y los épicos
encontrados.
