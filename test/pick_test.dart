import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

const Size _screen = Size(420, 860);

/// Pinta un pueblo y devuelve los blancos táctiles que salieron, junto con la
/// cámara con la que se pintó.
(List<PickTarget>, TownLayout, OrbitCamera) shot({
  required int placed,
  required double pitch,
  required double yaw,
  TownCharacter? place,
}) {
  final where = place ?? TownCharacter.all.first;
  final layout = TownLayout(placed, where);
  final cam = OrbitCamera()
    ..yaw = yaw
    ..yawTarget = yaw
    ..pitch = pitch
    ..pitchTarget = pitch
    ..distance = 26
    ..distanceTarget = 26;
  final scene = TownScene(
    placed: placed,
    palette: Palette.forMoment(11, 1.0),
    camera: cam,
    integrity: 1,
    time: 0,
    hourOfDay: 12,
    effects: EffectSystem(),
    labelledBricks: const {},
    budget: 22000,
    towns: [
      TownEntry(
        layout: layout,
        name: 'Prueba',
        symbol: 'torre',
        integrity: 1,
        placed: placed,
      ),
    ],
    active: 0,
  );
  final picks = <PickTarget>[];
  final rec = ui.PictureRecorder();
  TownPainter(scene, picks, [], [], [], []).paint(Canvas(rec), _screen);
  rec.endRecording().dispose();
  return (picks, layout, cam);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tocar una pieza', () {
    test('el blanco es la pieza entera y no un círculo dentro', () {
      // Lo que se rompía: se registraba **una** cara por pieza —la primera que
      // se pintaba, que casi nunca es la que se está mirando— y se guardaba
      // como un círculo alrededor de su centro. El resultado era un blanco más
      // chico que la pieza y, a veces, en otro sitio que la pieza.
      //
      // Esto lo mide contra el mundo: el centro real de la pieza, proyectado a
      // la pantalla, tiene que caer dentro de su propio blanco. Con un círculo
      // sobre una cara lateral, no caía.
      for (final pitch in [0.25, 0.7, 1.2]) {
        final (picks, layout, cam) = shot(placed: 60, pitch: pitch, yaw: 0.4);
        expect(picks, isNotEmpty, reason: 'inclinación $pitch');
        final p = cam.projector(_screen.width, _screen.height, 0);
        var checked = 0;
        for (final t in picks) {
          final piece = layout.pieces[t.brickIndex];
          final at = p.project(
            V3(piece.cx, (piece.y0 + piece.y1) / 2, piece.cz),
          );
          if (at == null) continue;
          if (at.x < 0 || at.x > _screen.width) continue;
          if (at.y < 0 || at.y > _screen.height) continue;
          checked++;
          expect(
            t.holds(at.x, at.y, 0),
            isTrue,
            reason:
                'inclinación $pitch: el centro de la pieza ${t.brickIndex} '
                'cae fuera de su propio blanco',
          );
        }
        expect(checked, greaterThan(10), reason: 'inclinación $pitch');
      }
    });

    test('cada pieza tiene un blanco y sólo uno', () {
      final (picks, _, _) = shot(placed: 90, pitch: 0.5, yaw: 1.1);
      final seen = picks.map((t) => t.brickIndex).toList();
      expect(seen.toSet().length, seen.length, reason: 'una pieza dos veces');
    });

    test('y no es un punto: se puede acertar con un dedo', () {
      final (picks, _, _) = shot(placed: 40, pitch: 0.45, yaw: 0.2);
      var big = 0;
      for (final t in picks) {
        if ((t.x1 - t.x0) >= 8 && (t.y1 - t.y0) >= 8) big++;
      }
      expect(
        big,
        greaterThan(picks.length ~/ 2),
        reason: 'la mitad de los blancos son más chicos que una yema',
      );
    });

    test('desde arriba gana la de encima, no la de debajo', () {
      // La otra queja: mirando desde arriba, el centro de la pieza de abajo
      // podía quedar más cerca del dedo que el de la de arriba, y salía la de
      // abajo. Ahora, de los que ocupan ese punto, gana el que está más cerca
      // del ojo — y una pieza apilada sobre otra está más cerca desde arriba.
      final (picks, layout, _) = shot(placed: 60, pitch: 1.25, yaw: 0.3);
      var pairs = 0;
      for (final t in picks) {
        final piece = layout.pieces[t.brickIndex];
        // Alguien apilado justo encima, en la misma columna.
        for (final other in picks) {
          if (other.brickIndex == t.brickIndex) continue;
          final o = layout.pieces[other.brickIndex];
          if ((o.cx - piece.cx).abs() > 0.15) continue;
          if ((o.cz - piece.cz).abs() > 0.15) continue;
          if (o.y0 < piece.y1 - 0.01) continue;
          // El de arriba tiene que estar más cerca del ojo que el de abajo.
          pairs++;
          expect(
            other.near,
            lessThanOrEqualTo(t.near + 1e-6),
            reason:
                'la pieza ${other.brickIndex} está encima de la '
                '${t.brickIndex} y se dice más lejos',
          );
        }
      }
      expect(pairs, greaterThan(3), reason: 'no había nada apilado que mirar');
    });

    test('lo que queda fuera de la pantalla no se registra', () {
      final (picks, _, _) = shot(placed: 60, pitch: 0.5, yaw: 0.4);
      for (final t in picks) {
        expect(t.x1, greaterThanOrEqualTo(0));
        expect(t.y1, greaterThanOrEqualTo(0));
        expect(t.x0, lessThanOrEqualTo(_screen.width));
        expect(t.y0, lessThanOrEqualTo(_screen.height));
        expect(t.near, greaterThan(0));
      }
    });
  });
}
