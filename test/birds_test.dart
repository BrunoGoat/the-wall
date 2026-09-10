import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/town.dart';

void main() {
  group('los pájaros vuelan sobre su pueblo', () {
    // El valle reparte los pueblos por sus plazas, y sólo uno de ellos cae
    // cerca del origen. Los pájaros trazaban su círculo sobre el origen, así
    // que ése era el único pueblo que los tenía: los demás los tenían dando
    // vueltas a cientos de unidades, fuera de cuadro.
    test('cada bandada gira alrededor del centro de su pueblo', () {
      for (var slot = 0; slot < 6; slot++) {
        // Las mismas plazas que reparte el valle de verdad.
        final (cx, cz) = Habit.centreOf(slot);
        final town = TownLayout(
          60,
          TownCharacter.forSlot(slot),
          cx: cx,
          cz: cz,
        );
        for (var flock = 0; flock < 2; flock++) {
          final (radius, height) = TownPainter.flockRing(town, flock);
          for (var i = 0; i < 5; i++) {
            for (final t in [0.0, 3.7, 41.0, 900.0]) {
              final at = TownPainter.birdAt(town, t, flock, i, radius, height);
              final lejos = math.sqrt(
                (at.x - town.cx) * (at.x - town.cx) +
                    (at.z - town.cz) * (at.z - town.cz),
              );
              expect(
                lejos,
                lessThan(radius + 2),
                reason:
                    'el pájaro $i de la bandada $flock del pueblo $slot vuela '
                    'a $lejos de su centro, con un radio de $radius',
              );
              expect(
                at.y,
                greaterThan(4),
                reason: 'un pájaro de la bandada $flock vuela por el suelo',
              );
            }
          }
        }
      }
    });

    test('y los de dos pueblos distintos no vuelan en el mismo sitio', () {
      final (ax, az) = Habit.centreOf(0);
      final (bx, bz) = Habit.centreOf(3);
      final uno = TownLayout(60, TownCharacter.forSlot(0), cx: ax, cz: az);
      final otro = TownLayout(60, TownCharacter.forSlot(3), cx: bx, cz: bz);
      final (r, h) = TownPainter.flockRing(uno, 0);
      final a = TownPainter.birdAt(uno, 12, 0, 0, r, h);
      final b = TownPainter.birdAt(otro, 12, 0, 0, r, h);
      expect(
        math.sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)),
        greaterThan(10),
        reason: 'los dos pueblos comparten pájaros, así que uno se queda sin',
      );
    });
  });
}
