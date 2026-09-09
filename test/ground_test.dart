import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

const int _w = 320;
const int _h = 900;

/// Un prado vacío, que es donde se ve el defecto sin nada que lo tape.
Future<ByteData> frame({
  required double hour,
  required bool coat,
  double yaw = 0.4,
  double pitch = 0.42,
  double distance = 30,
}) async {
  final cam = OrbitCamera()
    ..yaw = yaw
    ..yawTarget = yaw
    ..pitch = pitch
    ..pitchTarget = pitch
    ..distance = distance
    ..distanceTarget = distance;
  final scene = TownScene(
    placed: 0,
    palette: Palette.forMoment(hour, 1.0),
    camera: cam,
    integrity: 1,
    time: 0,
    effects: EffectSystem(),
    labelledBricks: const {},
    budget: 22000,
    towns: [
      TownEntry(
        layout: TownLayout(0, TownCharacter.all.first),
        name: 'Prueba',
        symbol: 'torre',
        integrity: 1,
        placed: 0,
      ),
    ],
    active: 0,
    coat: coat,
  );
  final rec = ui.PictureRecorder();
  TownPainter(
    scene,
    [],
    [],
    [],
    [],
    [],
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  final img = await rec.endRecording().toImage(_w, _h);
  final data = await img.toByteData();
  img.dispose();
  return data!;
}

int _green(ByteData px, int x, int y) => px.getUint8((y * _w + x) * 4 + 1);

/// Cuánto varía el prado **a lo largo de una fila**, en unidades de color.
///
/// Es la medida del defecto y no una aproximación suya. Lo que el usuario ve
/// como rayas es que toda la variación del suelo va en vertical: dentro de una
/// fila no pasa nada, así que lo único que el ojo encuentra son bordes
/// horizontales de lado a lado de la pantalla. Un prado con manchas varía
/// también a lo ancho, y entonces no hay ninguna raya recta que seguir.
double acrossRows(ByteData px, int from, int to) {
  var sum = 0.0;
  var rows = 0;
  for (var y = from; y < to; y += 3) {
    var mean = 0.0;
    for (var x = 0; x < _w; x++) {
      mean += _green(px, x, y);
    }
    mean /= _w;
    var v = 0.0;
    for (var x = 0; x < _w; x++) {
      final d = _green(px, x, y) - mean;
      v += d * d;
    }
    sum += math.sqrt(v / _w);
    rows++;
  }
  return sum / rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final meadow = (_h * 0.62).round();

  group('el prado no se ve a rayas', () {
    test('sin manchas toda la variación del suelo va en vertical', () async {
      // Primero se comprueba que la medida sirve. Un test que sólo mira el
      // resultado bueno no distingue «lo arreglé» de «mi regla no mide nada».
      for (final hour in [1.0, 12.0, 21.0]) {
        final px = await frame(hour: hour, coat: false);
        final wide = acrossRows(px, meadow, _h - 2);
        expect(
          wide,
          lessThan(0.9),
          reason:
              'a las $hour el prado sin manchas ya variaba $wide unidades a '
              'lo ancho de una fila: si varía, no es esto lo que se ve a rayas',
        );
      }
    });

    test('con manchas varía también a lo ancho', () async {
      for (final hour in [1.0, 7.0, 12.0, 19.0, 21.0]) {
        final px = await frame(hour: hour, coat: true);
        final wide = acrossRows(px, meadow, _h - 2);
        expect(
          wide,
          greaterThan(1.6),
          reason:
              'a las $hour el prado sólo varía $wide unidades a lo ancho: eso '
              'sigue siendo un degradado liso, y un degradado liso se raya',
        );
      }
    });

    test('las manchas llegan a todo el prado, mire donde mire', () async {
      // El paño se recorta al medio plano que está delante del ojo. Si ese
      // recorte se queda corto quedan tramos de prado liso, y si se pasa, el
      // plano se dobla sobre sí mismo al dividir por la profundidad y deja el
      // trozo doblado sin pintar. Las dos cosas se ven igual desde aquí: un
      // pedazo de suelo idéntico, píxel a píxel, al que habría sin paño.
      //
      // Se mira por celdas y por el máximo de cada una, no por el promedio:
      // en un promedio un trozo sin pintar se compensa con otro bien puesto al
      // lado, y de lo que se trata es justamente de que no haya ninguno.
      for (final yaw in [0.0, 1.1, 2.4, 4.0, 5.6]) {
        for (final pitch in [0.10, 0.42, 0.95]) {
          for (final distance in [12.0, 30.0, 90.0]) {
            final where = 'yaw $yaw, pitch $pitch, distancia $distance';
            final plain = await frame(
              hour: 12,
              coat: false,
              yaw: yaw,
              pitch: pitch,
              distance: distance,
            );
            final mottled = await frame(
              hour: 12,
              coat: true,
              yaw: yaw,
              pitch: pitch,
              distance: distance,
            );
            const cell = _w ~/ 4;
            for (var y = meadow; y < _h - 40; y += 40) {
              for (var x = 0; x + cell <= _w; x += cell) {
                var most = 0;
                for (var row = y; row < y + 40; row++) {
                  for (var c = x; c < x + cell; c++) {
                    final d = (_green(mottled, c, row) - _green(plain, c, row))
                        .abs();
                    if (d > most) most = d;
                  }
                }
                // Uno basta: lo que se está comprobando es que el paño llegue,
                // y de muy cerca una celda entera puede caer dentro de una
                // sola mancha y quedarse a una unidad. Un trozo sin pintar da
                // cero exacto, que es lo que esto caza.
                expect(
                  most,
                  greaterThanOrEqualTo(1),
                  reason:
                      'con $where el trozo de prado en ($x, $y) salió igual '
                      'que sin paño: ahí no llegó',
                );
              }
            }
          }
        }
      }
    });

    test('las manchas no se hacen moqueta al alejarse', () async {
      // El paño está anclado al mundo, así que al subir el ojo entran más
      // repeticiones suyas en la pantalla. Desde el valle eran treinta, y
      // treinta repeticiones de lo mismo no se leen como un prado sino como
      // una moqueta: se ve la baldosa. Crecen con la altura del ojo para que
      // en pantalla midan siempre lo mismo, y esto lo comprueba contando cuán
      // fino es el dibujo desde cerca y desde lejos.
      // Se cuenta cuántas veces cruza la fila su propio promedio: es contar
      // manchas por pantalla, que es exactamente lo que no tiene que cambiar.
      // La diferencia entre píxeles vecinos no vale —el filtrado la iguala
      // aunque el dibujo sea el triple de denso— y se comprobó que no valía
      // antes de cambiar de regla.
      double patches(ByteData px) {
        var sum = 0.0;
        var n = 0;
        for (var y = meadow; y < _h - 2; y += 3) {
          var mean = 0.0;
          for (var x = 0; x < _w; x++) {
            mean += _green(px, x, y);
          }
          mean /= _w;
          var crossed = 0;
          var was = _green(px, 0, y) > mean;
          for (var x = 1; x < _w; x++) {
            final now = _green(px, x, y) > mean;
            if (now != was) crossed++;
            was = now;
          }
          sum += crossed;
          n++;
        }
        return sum / n;
      }

      final cerca = patches(await frame(hour: 12, coat: true, distance: 30));
      for (final far in [90.0, 190.0]) {
        final lejos = patches(await frame(hour: 12, coat: true, distance: far));
        expect(
          lejos,
          lessThan(cerca * 1.35),
          reason:
              'a distancia $far el prado tiene $lejos manchas por fila y de '
              'cerca $cerca: se está viendo la baldosa',
        );
      }
    });

    test('y el prado sigue siendo del color que era', () async {
      // Las manchas suman y el degradado se descuenta de antemano lo mismo que
      // suman. El promedio tiene que salir igual: si se corre, se está
      // aclarando u oscureciendo la escena en vez de darle textura.
      //
      // Se promedia dando la vuelta entera, porque desde un solo sitio lo que
      // se mide es qué mancha ha caído delante, no el promedio del paño.
      for (final hour in [1.0, 7.0, 12.0, 19.0, 21.0]) {
        var sum = 0.0;
        var n = 0;
        for (var t = 0; t < 12; t++) {
          final yaw = t * math.pi / 6;
          final distance = 18.0 + (t % 3) * 24;
          final plain = await frame(
            hour: hour,
            coat: false,
            yaw: yaw,
            distance: distance,
          );
          final mottled = await frame(
            hour: hour,
            coat: true,
            yaw: yaw,
            distance: distance,
          );
          for (var y = meadow; y < _h - 2; y += 3) {
            for (var x = 0; x < _w; x += 7) {
              final at = (y * _w + x) * 4;
              for (var c = 0; c < 3; c++) {
                sum += mottled.getUint8(at + c) - plain.getUint8(at + c);
                n++;
              }
            }
          }
        }
        final drift = sum / n;
        expect(
          drift.abs(),
          lessThan(1.2),
          reason: 'a las $hour las manchas corrieron el color $drift unidades',
        );
      }
    });

    test('sigue cambiando con la hora, que es lo que no había que tocar', () {
      // Lo único que se pidió conservar: que el prado sea de otro color a otra
      // hora. Se mide en la fuente y no en el píxel, que ya lleva manchas.
      final noche = TownPainter.meadowTone(Palette.forMoment(1, 1.0)).$2;
      final medio = TownPainter.meadowTone(Palette.forMoment(13, 1.0)).$2;
      final tarde = TownPainter.meadowTone(Palette.forMoment(19, 1.0)).$2;
      expect(
        noche.computeLuminance(),
        lessThan(medio.computeLuminance() * 0.4),
      );
      expect(tarde.r, greaterThan(medio.r * 0.85));
      for (final c in [noche, medio, tarde]) {
        expect(c.g, greaterThan(c.b * 0.7));
      }
    });
  });
}
