# La Muralla

Una app donde cada logro se registra colocando **un ladrillo**, y ladrillo a
ladrillo se levanta una muralla que es la visualización de todo lo conseguido.
Si dejás de sumar ladrillos, la muralla empieza a deteriorarse: mantenerla
importa tanto como construirla.

Hay un solo control: un botón que se mantiene apretado un segundo largo. Cuando
el anillo se cierra, la piedra cae. Después, si querés, tocás ese ladrillo y le
escribís una leyenda —"Leí", "Corrí", lo que sea—. Es opcional: el ladrillo
cuenta igual.

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

Un mes de uso corriente son unos 30–60 ladrillos. Un año, entre 350 y 1100.

| | |
|---|---|
| Primer hito (Torre de Vigía) | empieza en el **12**, termina en el **34** |
| Hitos distintos en un año | **4 a 10**, todos de formas diferentes |

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

**Niveles.** A los 100 ladrillos la muralla **sube de nivel**: se abre una
banda entera de hiladas nuevas por encima de las almenas viejas, y a partir de
ahí cada piedra que ponés va levantando la muralla que ya tenías, desde el
principio hacia adelante. No se recoloca nada: la piedra de hace un año sigue
exactamente donde estaba, sólo que ahora tiene muralla encima. Los niveles
siguen a los 350 y a los 900, y ahí la muralla deja de crecer en alto y sigue
creciendo a lo largo. Las almenas que quedan enterradas se ciegan con
mampostería a medida que la banda nueva las alcanza.

Los hitos son la excepción a la regla de que nada se mueve: cuando la muralla
sube de nivel, el hito se rehace más alto **con las mismas piedras**, porque si
no cada hito viejo terminaría siendo un hueco en el perfil de una muralla que lo
dejó atrás. Su presupuesto de ladrillos se reparte por lo que cada parte es: la
corona se paga primero, la masa después y las molduras al final, así un hito
corto de ladrillos pierde el adorno y nunca la cabeza.

**El frente de obra.** Cada piedra nueva va a la hilada *más alta* donde entre
legalmente, lo que produce el borde escalonado de una muralla realmente en
construcción, en vez de una fila que repta por el suelo.

**Hitos.** Treinta siluetas genuinamente distintas —torre de vigía, puerta,
torre mayor, escalinata, puente levadizo, almenara, bastión, arcada, santuario,
barbacana, torre albarrana, cubo redondo, aljibe, puerta en recodo, revellín,
poterna, matacán, campanario, torre del reloj, molino, arcada de dos órdenes,
escalinata doble, puente del foso, torre de espolón, arco triunfal, casamata,
contrafuertes, torre octogonal, palomar y faro— que se levantan **con los
ladrillos reales**, hilada por hilada, durante las semanas que cuesta ganarlos.
Nunca aparecen de golpe.

No son cajas a distintas escalas: los cuerpos redondos son circulares en planta,
los octogonales son facetados, y todos llevan el vocabulario que hace que una
piedra parezca arquitectura y no geometría —zócalo en talud, impostas, cornisas,
ménsulas bajo el matacán, dovelas alrededor de los arcos, aspilleras, remates—.
Cuando el catálogo da la vuelta, el hito vuelve con otro nombre y algo más de
costo.

**Marcas, no emojis.** Cada hito se identifica con su propia silueta, dibujada
muestreando la geometría con la que se construye: la marca que acompaña a
«Puerta de Piedra» es el alzado de esa puerta, con su arco. Las partes que
sobresalen del muro se dibujan un tono más claras, así una escalinata se lee
como una escalinata y no como un bloque almenado más.

**Leyendas.** Cualquier ladrillo se puede tocar para ver cuándo se colocó y
dejarle una nota. Los que tienen una quedan marcados con un punto tenue en la
muralla, y todas juntas forman la **bitácora**: la pestaña *Leyendas* es una
hoja de papiro —trama, manchas, bordes gastados, tipografía con serifas, capital
rubricada, numeración romana en el margen— que se lee de la primera piedra a la
última, por meses, como la crónica de una obra medieval.

**La distancia.** Los ladrillos siguen siendo ladrillos hasta donde alcanza la
vista: pasada la banda de detalle cercano cada piedra se dibuja como su bloque,
en su sitio, con su color y sus juntas —sin las esquinas comidas, que a esa
distancia miden menos de un píxel—. Sólo más allá de eso, en murallas mucho más
largas que cualquiera que alguien vaya a construir, se convierte en su propia
silueta almenada perdiéndose en la calina, como la Gran Muralla.

**El mortero.** En *Ajustes → Mortero y juntas* hay cinco maneras de rejuntar
la muralla, y se cambian en vivo, con la muralla a la vista: junta viva, junta
rehundida, junta fina, junta enrasada y piedra seca. Cambian el ancho de la
junta, cuánto se mete el mortero hacia adentro, su tono respecto de la piedra y
cuánto sobresale cada piedra de sus vecinas. No tocan ningún ladrillo.

**El deterioro.** Después de un día y medio sin ladrillos la muralla empieza a
resentirse: la piedra se apaga, aparece liquen, el mortero se abre, el cielo se
enturbia. Nunca desaparece y nunca se pierde nada de lo construido. **Un solo
ladrillo la repara entera**, con una ola de reparación que recorre el muro.

## Cómo se ve y cómo se siente

- Renderizador 3D propio (`lib/engine/`): rasterizador por algoritmo del pintor,
  sombreado plano, sin dependencias nativas. Presupuesto de detalle adaptativo
  que sube y baja según el tiempo de cuadro, para que vaya a 60 fps.
- **Ciclo día/noche real.** El sol sale por el este a las 6, cruza el cielo y se
  pone a las 20; después la luna recorre el arco opuesto. Las sombras giran con
  él a lo largo del día. La paleta atraviesa noche, alba, mañana, mediodía, hora
  dorada, atardecer y crepúsculo, con las estrellas apareciendo y apagándose, y
  todo eso además teñido por el estado de deterioro.
- El momento de colocar: mientras sostenés el botón la cámara se desliza hasta
  el hueco donde va la piedra y el fantasma se enciende; al cerrarse el anillo
  la piedra cae con peso y aterriza con polvo, esquirlas, sacudida de cámara,
  destello, sonido de piedra sintetizado y vibración en dos tiempos.

## Correr y compilar

```bash
flutter pub get
flutter test          # 55 tests
flutter analyze
flutter run
flutter build apk --release
```

### APK

Cada push a la rama de desarrollo compila la APK en GitHub Actions
(`.github/workflows/apk.yml`) y la publica como *release* y como artefacto.
Está firmada con la clave de debug, así que se instala directo en el teléfono
(Android 7.0 / API 24 o superior).

### Herramientas de desarrollo

`--dart-define` para inspeccionar estados que de otro modo tardarían un año:

| define | para qué |
|---|---|
| `SEED=365` | arranca con esa cantidad de ladrillos |
| `IDLE_DAYS=13` | los coloca hace N días, para ver el deterioro |
| `HOUR=19` | fija la hora del día |
| `CAM_YAW/CAM_PITCH/CAM_DIST/CAM_AT` | encuadre fijo |
| `BUDGET=340` | fija el presupuesto de detalle |
| `MORTAR=seca` | fija el rejuntado, para comparar los cinco |
| `DEBUG_CORE=true` | pinta de magenta el núcleo de mortero, para ver dónde asoma |

Y dentro de la app, en *La Muralla → Ajustes → Ver la muralla a futuro*: un
control con deslizador y atajos a 50, 100, 200, 500, 1000 y 5000 ladrillos que
muestra cómo se vería la muralla con esa cantidad. Es sólo una vista: no toca
los ladrillos reales ni escribe nada en disco, y un solo toque vuelve a la
muralla de uno.

```bash
dart run tool/inspect.dart        # imprime el ritmo y la geometría
python3 tool/make_sfx.py          # regenera los sonidos
python3 tool/make_icons.py        # regenera los íconos
```

## Mapa del código

```
lib/
  core/      hash determinista y matemática 3D
  data/      los 30 hitos y el ritmo
  model/     ladrillos, leyendas, persistencia
  engine/    trazado, niveles, hitos, piedras, cámara, paleta, paisaje, render
  fx/        partículas, sonido y vibración
  ui/        la pantalla, el botón, las hojas
```

Nada de la forma de la muralla se guarda en disco: se deriva del índice de cada
ladrillo. Una piedra colocada hace un año se vuelve a dibujar idéntica en cada
arranque, y el archivo guardado son sólo los ladrillos, su fecha y su leyenda si
tienen.
