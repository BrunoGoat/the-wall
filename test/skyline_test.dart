import 'dart:math' as math;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/landscape.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';

/// Las veinticuatro horas, de media en media, que es donde la luz cambia.
Iterable<double> get everyHour sync* {
  for (var q = 0; q < 48; q++) {
    yield q / 2;
  }
}

void main() {
  final howMany = Landscape.ridges.length;

  group('las cordilleras del fondo', () {
    test('la de más lejos es siempre la más oscura', () {
      // Lo que se veía al revés: la neblina crecía con la distancia, así que
      // la cordillera del fondo salía la más clara y se ponía por delante de
      // las otras dos a ojo.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        var last = double.infinity;
        for (var li = 0; li < howMany; li++) {
          final (body, _) = TownPainter.rangeTone(pal, li, howMany);
          final lum = body.computeLuminance();
          expect(
            lum,
            lessThan(last),
            reason:
                'a las ${hour.toStringAsFixed(1)} la cordillera $li no es más '
                'oscura que la que tiene delante',
          );
          last = lum;
        }
      }
    });

    test('y se distinguen unas de otras, no son tres veces la misma', () {
      // En proporción y no en diferencia: de noche el valle entero es oscuro,
      // y ahí «se ve más oscura» quiere decir una fracción de lo otro, no una
      // cantidad fija que sólo tiene sentido a mediodía.
      //
      // Y sin decir cuál de las dos es la oscura, que es lo que cambió. De día
      // manda la perspectiva aérea y lo lejano se lava contra el cielo; de
      // noche lo cercano es una silueta negra contra un cielo que todavía
      // tiene algo de luz. Las dos cosas son ciertas a su hora, y lo que hay
      // que exigir es que no sean el mismo color.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        final (near, _) = TownPainter.rangeTone(pal, 0, howMany);
        final (far, _) = TownPainter.rangeTone(pal, howMany - 1, howMany);
        final a = near.computeLuminance(), b = far.computeLuminance();
        expect(
          (a - b).abs(),
          greaterThan(math.max(a, b) * 0.30),
          reason:
              'a las ${hour.toStringAsFixed(1)} la más lejana y la más cercana '
              'son prácticamente del mismo color',
        );
      }
    });

    test('el pie de cada una se va hacia la neblina', () {
      // Se desvanecen hacia la neblina donde tocan el horizonte, y no hacia el
      // color del suelo: fundirse con el suelo justo donde se encuentran las
      // dos cosas era lo que disolvía el horizonte. Hacia la neblina, sea la
      // neblina más clara o más oscura que la ladera a esta hora — cuál de las
      // dos lo es cambia con la hora, y ésa fue la trampa la primera vez.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        for (var li = 0; li < howMany; li++) {
          final (body, foot) = TownPainter.rangeTone(pal, li, howMany);
          expect(
            _apart(foot, pal.haze),
            lessThan(_apart(body, pal.haze)),
            reason:
                'a las ${hour.toStringAsFixed(1)}, el pie de la $li no se '
                'acerca a la neblina',
          );
        }
      }
    });

    test('ninguna se confunde con el cielo justo encima de ella', () {
      // Una cordillera del color exacto del cielo que tiene detrás no es una
      // cordillera.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        for (var li = 0; li < howMany; li++) {
          final (body, _) = TownPainter.rangeTone(pal, li, howMany);
          final d = _apart(body, pal.skyHorizon);
          expect(
            d,
            greaterThan(0.02),
            reason:
                'a las ${hour.toStringAsFixed(1)} la cordillera $li es del '
                'mismo color que el cielo detrás',
          );
        }
      }
    });

    test('el pasto se distingue de las colinas, a cualquier hora', () {
      // Lo que se veía de noche: el verde del prado sólo se aplicaba de día,
      // así que en cuanto se ponía el sol el campo caía al color crudo del
      // suelo — el mismo azul negruzco del que están hechas las colinas — y el
      // prado y el horizonte se volvían una sola mancha con una raya en medio.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        final grass = TownPainter.meadowTone(pal);
        final (hill, _) = TownPainter.rangeTone(pal, 0, howMany);
        expect(
          _apart(grass, hill),
          greaterThan(0.10),
          reason:
              'a las ${hour.toStringAsFixed(1)} el prado y la colina más '
              'cercana son casi del mismo color',
        );
      }
    });

    test('y sigue siendo pasto de noche: verde, aunque oscuro', () {
      // Sólo con el sol bajo el horizonte. A la hora dorada un prado es más
      // rojo que verde y así tiene que ser: lo está alumbrando un sol naranja
      // a ras del suelo. Lo que no puede pasar es que de noche deje de ser
      // pasto, que es lo que pasaba.
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        if (pal.daylight > 0.2) continue;
        final grass = TownPainter.meadowTone(pal);
        expect(
          grass.g,
          greaterThan(grass.r),
          reason: 'a las ${hour.toStringAsFixed(1)} el pasto no tiene verde',
        );
      }
    });

    test('y de noche es oscuro, no un prado de mediodía a oscuras', () {
      final noche = TownPainter.meadowTone(Palette.forMoment(2, 1.0));
      final medio = TownPainter.meadowTone(Palette.forMoment(13, 1.0));
      expect(
        noche.computeLuminance(),
        lessThan(medio.computeLuminance() * 0.30),
        reason: 'el prado de noche tiene que ser mucho más oscuro',
      );
      // Y azulado: de noche el azul le gana al rojo con holgura.
      expect(noche.b, greaterThan(noche.r * 1.3));
    });

    test('una sola cordillera no divide por cero', () {
      final pal = Palette.forMoment(12, 1.0);
      final (body, foot) = TownPainter.rangeTone(pal, 0, 1);
      expect(body.a, 1.0);
      expect(foot.a, 1.0);
    });
  });
}

/// Cuánto se separan dos colores, sumando sus tres canales.
double _apart(Color a, Color b) =>
    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
