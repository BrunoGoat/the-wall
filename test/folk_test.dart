import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/folk.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/season.dart';
import 'package:la_muralla/engine/town.dart';

TownLayout _town(int pieces, [String region = 'Ribera']) =>
    TownLayout(pieces, TownCharacter.all.firstWhere((c) => c.region == region));

/// Las casas corrientes que ya están pagadas enteras.
int _finished(TownLayout t, int placed) => t.buildings
    .where((b) => !b.isLandmark && b.firstPiece + b.cost <= placed)
    .length;

void main() {
  group('quién vive en el pueblo', () {
    test('una casa terminada, un vecino; ni uno más ni uno menos', () {
      for (final n in [1, 5, 20, 80, 300]) {
        final t = _town(n);
        expect(folkOf(t, n).length, _finished(t, n), reason: 'con $n piezas');
      }
    });

    test('un pueblo recién fundado no tiene a nadie', () {
      // La primera casa cuesta dos o tres piezas. Hasta que esté pagada
      // entera no vive nadie en ella, porque no hay ella.
      final t = _town(1);
      expect(folkOf(t, 1), isEmpty);
    });

    test('nadie sale de una casa a medio pagar', () {
      // La regla de siempre, dicha desde aquí: una persona no es un premio ni
      // un adelanto. Aparece cuando la última pieza de su casa está puesta.
      final t = _town(300);
      final casas = {for (final w in folkOf(t, 300)) w.home};
      for (final b in t.buildings) {
        if (b.isLandmark) continue;
        final entera = b.firstPiece + b.cost <= 300;
        expect(
          casas.contains(b.index),
          entera,
          reason: 'el edificio ${b.index} (${b.name}) tiene vecino sin estarlo',
        );
      }
    });

    test('en los hitos no vive nadie', () {
      final t = _town(400);
      final hitos = {
        for (final b in t.buildings)
          if (b.isLandmark) b.index,
      };
      for (final w in folkOf(t, 400)) {
        expect(hitos.contains(w.home), isFalse);
      }
    });

    test('crece con el pueblo y nunca mengua', () {
      var antes = 0;
      for (var n = 0; n <= 400; n += 20) {
        final ahora = folkOf(_town(n), n).length;
        expect(ahora, greaterThanOrEqualTo(antes), reason: 'con $n piezas');
        antes = ahora;
      }
      expect(antes, greaterThan(20));
    });
  });

  group('la ronda', () {
    test('en el mismo segundo están siempre en el mismo sitio', () {
      // No hay simulación que guardar ni que adelantar: es una función del
      // reloj. Si esto fallara, la gente saltaría de sitio al repintar.
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        for (final s in [0.0, 13.7, 91.25, 1200.0]) {
          final a = w.at(s), b = w.at(s);
          expect(a.x, b.x);
          expect(a.z, b.z);
          expect(a.heading, b.heading);
        }
      }
    });

    test('y el pueblo entero da la misma gente dos veces', () {
      final t = _town(200);
      final a = folkOf(t, 200), b = folkOf(t, 200);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].seed, b[i].seed);
        expect(a[i].at(40).x, b[i].at(40).x);
      }
    });

    test('la ronda se cierra: vuelven por donde salieron', () {
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        final a = w.at(0), b = w.at(w.period);
        expect((a.x - b.x).abs(), lessThan(1e-6));
        expect((a.z - b.z).abs(), lessThan(1e-6));
      }
    });

    test('se mueven de verdad, y no se van del pueblo', () {
      final t = _town(200);
      final r = t.radius + 6;
      for (final w in folkOf(t, 200)) {
        var lejos = 0.0;
        final desde = w.at(0);
        for (var k = 0; k <= 40; k++) {
          final at = w.at(w.period * k / 40);
          final d = math.sqrt(
            math.pow(at.x - desde.x, 2) + math.pow(at.z - desde.z, 2),
          );
          if (d > lejos) lejos = d;
          expect(
            math.sqrt(at.x * at.x + at.z * at.z),
            lessThan(r),
            reason: 'alguien se fue del pueblo',
          );
        }
        expect(lejos, greaterThan(1.0), reason: 'alguien no se movió nunca');
      }
    });

    test('no andan ni demasiado rápido ni a saltos', () {
      // Lo que caza un fallo en el reparto de tiempos: un tramo con tiempo
      // cero es una persona teletransportándose.
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        var prev = w.at(0);
        for (var k = 1; k <= 400; k++) {
          final at = w.at(k * 0.25);
          final d = math.sqrt(
            math.pow(at.x - prev.x, 2) + math.pow(at.z - prev.z, 2),
          );
          expect(
            d,
            lessThan(Townsfolk.pace * 0.25 + 0.02),
            reason: 'un salto de $d en un cuarto de segundo',
          );
          prev = at;
        }
      }
    });
  });

  group('no atraviesan las casas', () {
    test('la ronda entera pasa por fuera de lo que está en pie', () {
      // El fallo que esto existe para cazar se ve a simple vista en cuanto uno
      // se acerca: alguien saliendo de una pared. En línea recta de un recado
      // al siguiente pasaba todo el rato.
      const placed = 300;
      final t = _town(placed);
      // Lo que ocupa cada edificio en el suelo, a la altura de una persona.
      final cajas = <(double x0, double z0, double x1, double z1)>[];
      for (var i = 0; i < math.min(placed, t.pieces.length); i++) {
        final p = t.pieces[i];
        if (p.y0 > 0.95) continue;
        cajas.add((p.x0, p.z0, p.x1, p.z1));
      }
      final dentro = <String>[];
      for (final w in folkOf(t, placed)) {
        for (var k = 0; k < 600; k++) {
          final at = w.at(w.period * k / 600);
          for (final c in cajas) {
            if (at.x > c.$1 + 0.06 &&
                at.x < c.$3 - 0.06 &&
                at.z > c.$2 + 0.06 &&
                at.z < c.$4 - 0.06) {
              dentro.add(
                'el de la casa ${w.home} pasa por dentro de una pared '
                'en (${at.x.toStringAsFixed(1)}, ${at.z.toStringAsFixed(1)})',
              );
              break;
            }
          }
          if (dentro.isNotEmpty) break;
        }
      }
      expect(dentro, isEmpty, reason: dentro.join('\n'));
    });

    test('y ni uno solo de los quiebros cae dentro de una pared', () {
      // Más fino que muestrear la ronda: un vértice metido en una pared y un
      // tramo largo que corta una esquina se ven igual muestreando, y tienen
      // arreglos distintos —uno es el sitio al que se va, el otro es el camino
      // por el que se va—. Así se sabe cuál de los dos falló.
      const placed = 300;
      final t = _town(placed);
      final cajas = <(double, double, double, double)>[];
      for (var i = 0; i < math.min(placed, t.pieces.length); i++) {
        final p = t.pieces[i];
        if (p.y0 > 0.95) continue;
        cajas.add((p.x0, p.z0, p.x1, p.z1));
      }
      for (final w in folkOf(t, placed)) {
        for (final q in w.debugPath) {
          for (final c in cajas) {
            final dentro =
                q.$1 > c.$1 + 0.06 &&
                q.$1 < c.$3 - 0.06 &&
                q.$2 > c.$2 + 0.06 &&
                q.$2 < c.$4 - 0.06;
            expect(
              dentro,
              isFalse,
              reason:
                  'el de la casa ${w.home} tiene un quiebro en $q, '
                  'que está dentro de $c',
            );
          }
        }
      }
    });

    test('y las seis regiones se portan igual', () {
      for (final c in TownCharacter.all) {
        final t = TownLayout(200, c);
        final cajas = <(double, double, double, double)>[];
        for (var i = 0; i < math.min(200, t.pieces.length); i++) {
          final p = t.pieces[i];
          if (p.y0 > 0.95) continue;
          cajas.add((p.x0, p.z0, p.x1, p.z1));
        }
        var malos = 0;
        for (final w in folkOf(t, 200)) {
          for (var k = 0; k < 200; k++) {
            final at = w.at(w.period * k / 200);
            for (final b in cajas) {
              if (at.x > b.$1 + 0.06 &&
                  at.x < b.$3 - 0.06 &&
                  at.z > b.$2 + 0.06 &&
                  at.z < b.$4 - 0.06) {
                malos++;
                break;
              }
            }
          }
        }
        expect(malos, 0, reason: '${c.region}: $malos pasos por dentro');
      }
    });
  });

  group('el día y la noche', () {
    double luz(double hora, {Season season = Season.none}) =>
        Palette.forMoment(hora, 1.0, season: season).daylight;

    test('de día están fuera y de noche dentro', () {
      expect(folkHome(luz(13)), 0.0);
      expect(folkHome(luz(9)), 0.0);
      expect(folkHome(luz(23)), 1.0);
      expect(folkHome(luz(3)), 1.0);
    });

    test('y se van yendo, no desaparecen de golpe', () {
      // Un pueblo que se vacía en un fotograma es una luz que se apaga. Lo que
      // tiene que verse es a todo el mundo tirando para su casa.
      var antes = 0.0;
      var subidas = 0;
      for (var h = 16.0; h < 22.0; h += 0.1) {
        final ahora = folkHome(luz(h));
        expect(ahora, greaterThanOrEqualTo(antes - 1e-9));
        if (ahora > antes + 1e-9) subidas++;
        antes = ahora;
      }
      expect(subidas, greaterThan(8), reason: 'se recogen de golpe');
      expect(antes, 1.0);
    });

    test('en invierno se recogen antes que en verano', () {
      // Sin ninguna hora escrita en ningún sitio: sale de la luz que hay.
      final invierno = Season.on(DateTime(2026, 12, 21), Hemisphere.north);
      final verano = Season.on(DateTime(2026, 6, 21), Hemisphere.north);
      expect(
        folkHome(luz(18, season: invierno)),
        greaterThan(folkHome(luz(18, season: verano))),
      );
    });
  });

  group('un pueblo desatendido se queda vacío', () {
    test('cuanto peor está, menos gente sale', () {
      var antes = folkOut(1.0);
      for (final i in [0.9, 0.7, 0.5, 0.3, 0.12]) {
        final ahora = folkOut(i);
        expect(ahora, lessThan(antes), reason: 'con integridad $i');
        antes = ahora;
      }
    });

    test('con el pueblo entero sale todo el mundo', () {
      expect(folkOut(1.0), greaterThanOrEqualTo(1.0));
    });

    test('pero nunca se queda solo del todo', () {
      // Igual que la integridad no llega a cero: el pueblo se apaga, no se
      // muere. Siempre queda alguien.
      expect(folkOut(0.0), greaterThan(0.15));
    });
  });
}
