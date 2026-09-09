import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/engine/renderer.dart';

/// Una cámara mirando en `yaw`, inclinada `pitch`, desde donde se le diga.
Projector camera({
  double yaw = 0.4,
  double pitch = -0.25,
  V3 eye = const V3(0, 6, 0),
  double focal = 620,
}) {
  final forward = V3(
    math.sin(yaw) * math.cos(pitch),
    math.sin(pitch),
    math.cos(yaw) * math.cos(pitch),
  );
  final right = V3(math.cos(yaw), 0, -math.sin(yaw));
  final up = V3(
    -math.sin(yaw) * math.sin(pitch),
    math.cos(pitch),
    -math.cos(yaw) * math.sin(pitch),
  );
  return Projector(
    eye: eye,
    right: right,
    up: up,
    forward: forward,
    focal: focal,
    cx: 220,
    cy: 440,
  );
}

void main() {
  group('lo que está lejos se queda quieto', () {
    test('caminar por el valle no mueve las montañas ni un píxel', () {
      // El defecto que se veía: las cordilleras se muestreaban en
      // «ojo + dirección × radio», con la posición horizontal siguiendo a la
      // cámara pero la altura en coordenadas del mundo. Las dos mitades no
      // pegaban, así que mover el ojo las movía — y con el radio de la primera
      // en ciento cincuenta, moverse veinte unidades era moverla un séptimo de
      // su tamaño. Una masa de tierra a esa distancia no se mueve.
      const eyes = [
        V3(0, 6, 0),
        V3(140, 6, -60),
        V3(-320, 6, 210),
        V3(0, 6, 0),
      ];
      for (final az in [0.0, 0.3, -0.4]) {
        for (final el in [0.0, 0.05, 0.2, 0.5]) {
          final first = TownPainter.skyPoint(camera(eye: eyes.first), az, el);
          expect(first, isNotNull, reason: 'az=$az el=$el');
          for (final eye in eyes.skip(1)) {
            final at = TownPainter.skyPoint(camera(eye: eye), az, el);
            expect(at, isNotNull);
            expect(at!.dx, closeTo(first!.dx, 1e-9), reason: 'az=$az el=$el');
            expect(at.dy, closeTo(first.dy, 1e-9), reason: 'az=$az el=$el');
          }
        }
      }
    });

    test('ni alejarse, que es lo que sube el ojo y lo hacía notorio', () {
      for (final y in [2.0, 18.0, 45.0, 120.0]) {
        final a = TownPainter.skyPoint(
          camera(eye: const V3(0, 3, 0)),
          0.2,
          0.3,
        );
        final b = TownPainter.skyPoint(camera(eye: V3(0, y, 0)), 0.2, 0.3);
        expect(b!.dy, closeTo(a!.dy, 1e-9), reason: 'con el ojo a $y');
      }
    });

    test('el pie de una montaña cae justo en el horizonte, siempre', () {
      // Y esto es lo que hace imposible que el prado se coma una montaña: la
      // elevación cero es una línea horizontal, la misma a la que el suelo
      // empieza. No es un ajuste, sale de la proyección.
      for (final pitch in [-0.6, -0.25, 0.0, 0.3]) {
        final p = camera(pitch: pitch);
        double? first;
        for (var k = -6; k <= 6; k++) {
          final at = TownPainter.skyPoint(p, k * 0.09, 0.0);
          if (at == null) continue;
          first ??= at.dy;
          expect(at.dy, closeTo(first, 1e-6), reason: 'con inclinación $pitch');
        }
        expect(first, isNotNull, reason: 'con inclinación $pitch');
      }
    });

    test('girar la cámara sí las mueve, que para eso están', () {
      final a = TownPainter.skyPoint(camera(yaw: 0.0), 0.0, 0.2);
      final b = TownPainter.skyPoint(camera(yaw: 0.35), 0.0, 0.2);
      expect((a!.dx - b!.dx).abs(), greaterThan(50));
    });

    test('lo que queda detrás del ojo no se dibuja', () {
      expect(TownPainter.skyPoint(camera(yaw: 0.0), math.pi, 0.1), isNull);
      expect(
        TownPainter.skyPoint(camera(yaw: 0.0), math.pi * 0.9, 0.1),
        isNull,
      );
    });

    test('más alto en el cielo es más arriba en la pantalla', () {
      final p = camera();
      var last = double.infinity;
      for (final el in [0.0, 0.1, 0.3, 0.6, 0.9]) {
        final at = TownPainter.skyPoint(p, 0.4, el);
        expect(at, isNotNull, reason: 'el=$el');
        expect(at!.dy, lessThan(last), reason: 'el=$el');
        last = at.dy;
      }
    });
  });
}
