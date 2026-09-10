# Towny

Una app donde cada logro se registra colocando **una pieza**, y pieza a pieza se
levanta un pueblo que es la visualización de todo lo conseguido. Si dejás de
sumar piezas, el pueblo se va apagando: mantenerlo importa tanto como
construirlo.

Hay un solo control: un botón que se mantiene apretado un segundo y cuarto.
Cuando el anillo se cierra, la pieza cae. Después, si querés, tocás esa pieza y
le escribís una leyenda —«Leí», «Corrí», lo que sea—. Es opcional: la pieza
cuenta igual.

El pueblo es 3D y se puede orbitar libremente —desde el costado, desde atrás,
desde arriba—, con un estilo de sólidos planos y sin texturas.

## La regla que no se negocia

**Una pieza es siempre un logro. Nunca un lote de varias.**

Todo lo demás está construido encima de esa regla. El ritmo de la app no se
expresa en días ni en porcentajes sino en cantidad de piezas, y no hay ningún
camino en el código que coloque más de una por acción. La única excepción es el
*modo rápido*, que existe para poder mirar un pueblo grande sin esperar un año,
vive escondido en ajustes y viene apagado.

## Un hábito, un pueblo

Cada hábito tiene su propio pueblo, con su nombre, su marca y su **región**, que
se elige el día que se funda y no se cambia nunca. Las seis regiones no son seis
paletas del mismo pueblo: cambian la altura de las casas, el ancho de los
solares, la inclinación de los tejados, el grosor de los muros, cuántas ventanas
se abren y qué mezcla de teja, pizarra y paja se usa.

| | |
|---|---|
| **Ribera** | Casas anchas y bajas, encaladas de blanco, casi todas de teja. |
| **Sierra** | Alta y apretada, de piedra gris y pizarra, con tejados agudos. |
| **Marca** | De frontera: muros gruesos, ocre, pocas ventanas y todo junto. |
| **Valle** | Madera y paja, solares grandes y huerta en casi todas. |
| **Costa** | Cal y añil, tejados casi planos y mucho aire entre las casas. |
| **Robledal** | Madera oscura bajo los robles, tejados de paja muy inclinados. |

Los pueblos se ven todos juntos alejando la cámara: el **valle**, con cada uno
en su sitio y su cartel. Desde ahí se entra a cualquiera.

## Qué se construye

**Casas.** El tejido semana a semana. Siete clases, que cuestan entre 2 y 8
logros: cobertizo, casa, taller, casona, granero, casa de vecinos y posada. La
gracia frente a una muralla es ésa — un ladrillo sólo puede significar «la
muralla es un ladrillo más larga», pero una pieza de una casa significa «la casa
está casi terminada», y tres días después la casa **está** terminada. Siempre hay
un final cerca, más cerca que el próximo hito.

**Hitos.** Ciento trece obras genuinamente distintas —pozo, horno, molino de
viento, puente, castillo, faro, iglesia, lagar, observatorio…—, repartidas en
tres categorías según lo grandes que son, y levantadas **con las piezas reales**,
una a una, durante las semanas que cuesta ganarlas. Nunca aparecen de golpe.
Llegan con una cadencia que se va abriendo: el primero pronto, para que valga la
pena esperarlo, y el vigésimo no cada quince días.

No son cajas a distintas escalas. Cada hito trae su propia receta de albañilería
—zócalos, contrafuertes, arcos con dovelas, cubiertas, remates— y las obras de
apertura están elegidas a mano, porque los dos primeros años de un pueblo tienen
que enseñar de lo que es capaz el sitio y no una pocilga detrás de otra. Cuál de
ellas le toca a cada pueblo, y en qué orden, es cosa suya: dos hábitos no
recorren nunca el mismo camino.

**El catálogo puede crecer sin mover una piedra.** Ésta es la parte que costó
más y la que menos se ve. Añadir un hito nuevo no reordena nada de lo ya
construido: un pueblo con treinta piezas sigue exactamente igual, y a lo mejor lo
siguiente que levanta es justamente el hito nuevo. Se consigue con dos cosas —
cada obra se puntúa por su **identificador** y no por su posición en la lista, y
cada pueblo lleva una **crónica** donde queda escrito lo que ya decidió. Lo
decidido no se vuelve a sortear.

## El ritmo

Las cifras están elegidas para el uso real, no para una demo con miles de
piezas. Un mes corriente son unas 30–60 piezas; un año, entre 350 y 1100.

Y el deterioro tiene su propio ritmo, que es el único que la app se reserva
fuera del plan del pueblo:

| | |
|---|---|
| Días de gracia antes de que algo se note | **1,6** |
| De ahí a lo más apagado que llega | **14 días** |
| Suelo | **12 %** — nunca llega a cero |

Un día y medio de gracia porque la vida pasa, y un hábito que castiga una sola
noche perdida es un hábito que nadie sostiene. Quince días de bajada porque tiene
que ser lo bastante lenta como para notarla y lo bastante marcada como para que
importe. Y no se pierde nunca nada de lo construido: sólo se apagan las luces,
se apaga el color y se enturbia el cielo. **Una sola pieza lo repara entero.**

## Leyendas y bitácora

Cualquier pieza se puede tocar para ver cuándo se colocó y dejarle una nota. El
área que responde es la del sólido entero y no se atraviesa: si hay una pieza
encima de otra, gana la de encima.

**La leyenda se escribe en la misma tarjeta donde se lee**, y sin moverse del
sitio aunque salga el teclado. Se toca el texto y el texto se convierte en el
campo; se toca fuera y queda guardado. No hay botón
de guardar y no hay una segunda pantalla: una hoja aparte con su título, su
explicación y sus botones es mucha pantalla para una frase de sesenta letras que
ya estaba delante. Desde la bitácora es lo mismo —tocar una entrada lleva la
cámara hasta esa pieza y abre su tarjeta—, así que hay una sola manera de
escribir una leyenda y está en un solo sitio.

Las que llevan leyenda quedan marcadas, y todas juntas forman la bitácora — la
pestaña *Leyendas* es una hoja de papiro que se lee de la primera pieza a la
última, por meses, como la crónica de una obra.

Al lado están *El pueblo*, con lo que llevás en pie y las rachas, e *Hitos*, con
lo terminado, lo que está en obra y lo que viene.

## El cielo

Ciclo día/noche real: el sol sale por el este, cruza, se pone, y después la luna
recorre el arco opuesto; las sombras giran con él. La paleta atraviesa noche,
alba, mañana, mediodía, hora dorada, atardecer y crepúsculo.

**Estrellas fugaces**, de noche y desde el primer día, sin desbloquear nada.

**Constelaciones**, ocho, reales, con sus coordenadas de verdad: Orión, la Osa
Mayor, Casiopea, la Cruz del Sur, el Cisne, Escorpio, la Lira y el Can Mayor. Se
proyectan sobre el cielo conservando su forma, cada noche sale una, y tocarla la
registra. Aparecen a partir del momento en que hay un **observatorio** en pie en
cualquier pueblo del valle —y lo que se registra es del valle, no del pueblo, así
que no hace falta un observatorio por hábito—. Lo registrado se lee después en el
cuaderno de cualquier observatorio.

## El tablón

El pueblo va anotando lo que nota de vos, y lo cuelga en su tablón: a qué hora
sueles aparecer, qué día de la semana se te da mejor y cuál peor, qué pasa al día
siguiente de un día en blanco, cuánto tardás en volver después de un hueco, qué
dos hábitos van juntos y cuáles nunca, cuánto hace que esto dura y quién va
delante en el valle.

## Cómo está hecho el render

Un rasterizador propio (`lib/engine/`), sin dependencias nativas, escrito
alrededor de tres reglas:

1. **Todo lo que se construye es un sólido cerrado.** No cáscaras. Un tejado
   tiene sus dos faldones, sus dos hastiales y su suelo.
2. **Dentro de un sólido cerrado no hace falta ordenar nada**: descartar las
   caras que miran para el otro lado es exacto desde cualquier ángulo. Cero
   heurística.
3. **Entre sólidos se ordena por geometría exacta, no por una media.** Un BSP por
   edificio, construido una vez cuando ese edificio gana una pieza y guardado; y
   entre edificios, un árbol de separación por planos. Donde dos sólidos se
   atraviesan de verdad, la geometría se corta **una vez al construir**, no se
   compensa cada cuadro.

No hay z-buffer ni ordenación por profundidad. El mundo es *append-only* y
estático: una pieza colocada no se mueve nunca, así que todo el trabajo caro se
hace cuando cae la pieza y no sesenta veces por segundo.

Hay un test (`test/depth_test.dart`) que recorre las estructuras del catálogo
desde un barrido de cámaras y exige que, para todo par de polígonos que se solapan
en pantalla, el que se pinta después no esté más lejos. Es exactamente el fallo
que se ve, comprobado por máquina, porque «se ve mal desde ciertos ángulos» a ojo
se escapa.

## Sonido

Cinco sonidos —poner una pieza, toque, reparar, obra terminada, hito del pueblo—
y dos temas de música de fondo, *Tarde* y *Sendero*, cada uno con su propio
reparto por hora del día: suena uno de los dos al abrir la app. Todo está
generado por `tool/make_sfx.py` y `tool/make_music.py`, no grabado.

Se escribieron cinco temas y se probaron los cinco durante un tiempo con un
selector en ajustes; quedaron dos. Los otros tres siguen escritos en
`tool/make_music.py` por si alguno vuelve, pero no se generan: un asset que no
suena en ninguna parte son doscientos kilos de APK por nada.

**El volumen de la música no sube en línea recta.** La mitad del deslizador
suena al quince por ciento, que es donde acaba quien la usa de verdad —es música
de fondo—, y de ahí al tope crece rápido para que subirla sirva de algo. La
curva es la potencia que pasa por esos dos puntos y sale de ellos, así que
cambiar cuánto suena la mitad la recalcula sola.

## Correr y compilar

```bash
flutter pub get
flutter test          # 188 tests
flutter analyze
flutter run
flutter build apk --release
```

### APK

Cada push a la rama de desarrollo compila la APK en GitHub Actions
(`.github/workflows/apk.yml`) y la publica como *release*. Va firmada **siempre
con la misma clave**, y el propio flujo lo verifica antes de publicar: es lo
único que permite instalar una build encima de la anterior sin perder los
pueblos. Android 7.0 (API 24) o superior.

> El certificado sigue diciendo `CN=La Muralla`, que es como se llamaba esto
> antes, y tiene que seguir diciéndolo. Renombrarlo sería cambiar de clave. Por
> lo mismo el `applicationId` sigue siendo `com.lamuralla.la_muralla` y el
> paquete de Dart, `la_muralla`.

### Herramientas de desarrollo

`--dart-define` para ver estados que de otro modo tardarían un año:

| define | para qué |
|---|---|
| `SEED=365` | arranca con esa cantidad de piezas |
| `IDLE_DAYS=13` | las coloca hace N días, para ver el deterioro |
| `REGION=2` | funda el pueblo en esa región |
| `VALLEY=300,120:9,40` | un valle entero: piezas y días parado por pueblo |
| `HOUR=19` | fija la hora del día (entero — `1.5` se ignora en silencio) |
| `GALLERY=1` | abre el expositor de estructuras en vez del pueblo |
| `CAM_YAW/CAM_PITCH/CAM_DIST/CAM_X/CAM_Z` | encuadre fijo |
| `BUDGET=340` | fija el presupuesto de detalle |

Y dentro de la app, en *Ajustes*: **el expositor**, con todo lo que el pueblo
sabe construir; **ver el pueblo a futuro**, con atajos a 100, 500 y 5000 piezas,
que es sólo una vista y no escribe nada; **tus datos**, para copiar el valle
entero y volver a meterlo; y **quitar la última pieza**, que dice qué leyenda se
va con ella antes de hacerlo.

```bash
python3 tool/make_sfx.py          # regenera los sonidos
python3 tool/make_music.py        # regenera la música
python3 tool/make_icons.py        # recorta el icono desde tool/icon/towny.png
```

## Mapa del código

```
lib/
  core/      hash determinista y matemática 3D
  data/      hitos, regiones, marcas, constelaciones y temas de música
  model/     hábitos, piezas, leyendas, hallazgos, persistencia
  engine/    trazado del pueblo, albañilería, sólidos, BSP, cámara, paleta, render
  fx/        partículas, sonido y vibración
  ui/        la pantalla, el botón, las hojas
```

Nada de la **forma** del pueblo se guarda en disco: se deriva del identificador
de cada pieza. Una casa levantada hace un año se vuelve a dibujar idéntica en
cada arranque. Lo que sí se guarda son las piezas con su fecha y su leyenda, los
hábitos, la crónica de obra de cada pueblo —lo que ya se decidió construir— y las
constelaciones vistas.
