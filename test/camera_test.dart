import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';

/// Lo que `town_view` le dice a la cámara sobre el mundo, calculado igual.
void reachAllTowns(OrbitCamera cam, List<TownLayout> towns) {
  var lo = double.infinity, hi = double.negativeInfinity;
  for (final t in towns) {
    final reach = t.radius + 4;
    if (t.cx - reach < lo) lo = t.cx - reach;
    if (t.cx + reach > hi) hi = t.cx + reach;
  }
  cam.reaches(lo, hi);
}

List<TownLayout> valleyOf(int howMany, int pieces) => [
  for (var slot = 0; slot < howMany; slot++)
    () {
      final (cx, cz) = Habit.centreOf(slot);
      return TownLayout(pieces, TownCharacter.forSlot(slot), cx: cx, cz: cz);
    }(),
];

void main() {
  group('la cámara alcanza a todos los pueblos', () {
    // El defecto: `travelTo` recortaba a [-2, wallLength + 2], que era lo
    // correcto cuando esto era una muralla recta que empezaba en el origen.
    // El valle se abre a los dos lados hasta setenta y ocho, así que a cuatro
    // de los seis pueblos la cámara no podía ni mirarlos: al poner una pieza
    // se quedaba apuntando al campo vacío del medio. Y no fallaba nada —
    // simplemente no se veía lo que se estaba construyendo.
    test('mirar a cualquier pueblo lleva la cámara a ese pueblo', () {
      final towns = valleyOf(Habit.maxSlots, 60);
      final cam = OrbitCamera();
      reachAllTowns(cam, towns);
      for (final t in towns) {
        cam.travelTo(t.cx, animate: false);
        expect(
          cam.travelTarget,
          closeTo(t.cx, 0.001),
          reason:
              'un pueblo en x=${t.cx.toStringAsFixed(1)} quedó recortado a '
              '${cam.travelTarget.toStringAsFixed(1)}: la cámara apunta al '
              'campo vacío en vez de a lo que se está construyendo',
        );
      }
    });

    test('y a cada pieza suya, que es lo que pasa al colocar una', () {
      final towns = valleyOf(Habit.maxSlots, 90);
      final cam = OrbitCamera();
      reachAllTowns(cam, towns);
      for (final t in towns) {
        for (final piece in t.pieces) {
          cam.travelTo(piece.cx, animate: false);
          expect(
            cam.travelTarget,
            closeTo(piece.cx, 0.001),
            reason:
                'la pieza ${piece.index} del pueblo en x=${t.cx} '
                'quedó fuera del alcance de la cámara',
          );
        }
      }
    });

    test('un solo pueblo también, y sin dejarlo salir al vacío', () {
      final towns = valleyOf(1, 40);
      final cam = OrbitCamera();
      reachAllTowns(cam, towns);
      final reach = towns.single.radius + 4;
      cam.travelTo(1000, animate: false);
      expect(cam.travelTarget, closeTo(reach, 0.001));
      cam.travelTo(-1000, animate: false);
      expect(cam.travelTarget, closeTo(-reach, 0.001));
    });

    test('arrastrar tampoco puede salirse del valle', () {
      final towns = valleyOf(Habit.maxSlots, 60);
      final cam = OrbitCamera();
      reachAllTowns(cam, towns);
      for (var k = 0; k < 400; k++) {
        cam.travelBy(k.isEven ? 9 : -13);
        expect(
          cam.travelTarget,
          inInclusiveRange(cam.travelMin, cam.travelMax),
        );
      }
      // Y el valle entero está dentro, no sólo el pueblo del medio.
      final far = towns.map((t) => t.cx.abs()).reduce(math.max);
      expect(cam.travelMax, greaterThanOrEqualTo(far));
      expect(cam.travelMin, lessThanOrEqualTo(-far));
    });
  });

  group('cuánto se puede alejar uno', () {
    test('desde bastante más lejos que el propio pueblo', () {
      final cam = OrbitCamera();
      final town = TownLayout(300, TownCharacter.all.first);
      cam.wallLength = town.radius * 2;
      // Alejarse todo lo que deje.
      for (var k = 0; k < 60; k++) {
        cam.zoomBy(1.2);
      }
      expect(
        cam.distanceTarget,
        greaterThan(town.radius * 3),
        reason: 'el tope deja el pueblo llenando la pantalla',
      );
    });

    test('y el valle entero entra sin toparse con el tope', () {
      final towns = valleyOf(Habit.maxSlots, 200);
      var far = 20.0;
      for (final t in towns) {
        final d = math.sqrt(t.cx * t.cx + t.cz * t.cz) + t.radius;
        if (d > far) far = d;
      }
      final cam = OrbitCamera()..wallLength = far * 2;
      expect(cam.usefulDistance, greaterThanOrEqualTo(far * 2.4));
    });
  });
}
