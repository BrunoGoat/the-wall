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

/// Un prado vacío, que es donde se ve el suelo sin nada que lo tape.
Future<ByteData> frame({
  required double hour,
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
    hourOfDay: 12,
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

int _at(ByteData px, int x, int y) => px.getUint32((y * _w + x) * 4);

/// Cuántas veces cambia de color una columna al bajar por ella.
///
/// Es la medida directa de lo que se veía. Una raya es un escalón: veinte
/// filas del mismo verde y de golpe otro, porque a ocho bits un degradado no
/// tiene más remedio que dar el salto en algún sitio. Un relleno plano no da
/// ninguno, y por eso no puede salir a rayas.
int steps(ByteData px, int x, int from, int to) {
  var n = 0;
  for (var y = from + 1; y < to; y++) {
    if (_at(px, x, y) != _at(px, x, y - 1)) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Una franja de prado de primer plano: por debajo del horizonte, por
  // debajo de lo que el pueblo dibuja en el suelo, y dentro del círculo en el
  // que el viñeteado —que es de la atmósfera y no del suelo— todavía vale
  // cero. Lo que se mide aquí es el suelo y nada más que el suelo.
  const from = 700;
  const to = 780;
  const left = 50;
  const right = 270;

  group('el prado no se ve a rayas', () {
    test('la regla mide algo: el cielo, que sí es un degradado', () async {
      // Un test que sólo mira el resultado bueno no distingue «lo arreglé» de
      // «mi regla no mide nada». El cielo del mismo cuadro sigue siendo un
      // degradado, así que sirve de contraste: si la misma cuenta de escalones
      // no lo caza a él, tampoco valdría de nada aplicada al suelo.
      final px = await frame(hour: 12);
      final cielo = steps(px, 160, 40, 200);
      expect(
        cielo,
        greaterThan(3),
        reason:
            'el cielo, que es un degradado, sólo da $cielo escalones en '
            'ciento sesenta filas: la regla no mide lo que dice medir',
      );
    });

    test('el suelo no da un solo escalón en toda su altura', () async {
      for (final hour in [1.0, 7.0, 12.0, 19.0, 21.0]) {
        final px = await frame(hour: hour);
        for (final x in [left, 160, right]) {
          expect(
            steps(px, x, from, to),
            0,
            reason:
                'a las $hour la columna $x del prado cambia de color por el '
                'camino: eso es una raya',
          );
        }
      }
    });

    test('mire donde mire la cámara', () async {
      for (final yaw in [0.0, 1.1, 2.4, 4.0, 5.6]) {
        for (final pitch in [0.10, 0.42, 0.95]) {
          for (final distance in [12.0, 30.0, 190.0]) {
            final px = await frame(
              hour: 12,
              yaw: yaw,
              pitch: pitch,
              distance: distance,
            );
            expect(
              steps(px, 160, from, to),
              0,
              reason:
                  'con yaw $yaw, pitch $pitch y distancia $distance el prado '
                  'cambia de color al bajar',
            );
          }
        }
      }
    });

    test('y tampoco a lo ancho: es un color y nada más', () async {
      for (final hour in [1.0, 12.0, 21.0]) {
        final px = await frame(hour: hour);
        final one = _at(px, left, from);
        for (var y = from; y < to; y += 7) {
          for (var x = left; x < right; x += 5) {
            expect(
              _at(px, x, y),
              one,
              reason: 'a las $hour el píxel ($x, $y) no es el mismo verde',
            );
          }
        }
      }
    });

    test('sigue cambiando con la hora, que es lo que no había que tocar', () {
      // Lo único que se pidió conservar: que el prado sea de otro color a otra
      // hora.
      final noche = TownPainter.meadowTone(Palette.forMoment(1, 1.0));
      final medio = TownPainter.meadowTone(Palette.forMoment(13, 1.0));
      final tarde = TownPainter.meadowTone(Palette.forMoment(19, 1.0));
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
