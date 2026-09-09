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
      for (final hour in everyHour) {
        final pal = Palette.forMoment(hour, 1.0);
        final (near, _) = TownPainter.rangeTone(pal, 0, howMany);
        final (far, _) = TownPainter.rangeTone(pal, howMany - 1, howMany);
        expect(
          far.computeLuminance(),
          lessThan(near.computeLuminance() * 0.62),
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
