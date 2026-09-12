import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/season.dart';

/// Un cuarto de vuelta al año, en días.
const int _quarter = 91;

Season _n(int month, int day) =>
    Season.on(DateTime(2026, month, day), Hemisphere.north);
Season _s(int month, int day) =>
    Season.on(DateTime(2026, month, day), Hemisphere.south);

void main() {
  group('el año da la vuelta', () {
    test('los solsticios caen donde dice el calendario', () {
      // Lo que hay que acertar y es fácil errar por un mes: en diciembre el
      // norte está en lo más crudo y el sur en lo más alto del verano.
      expect(_n(12, 21).winter, greaterThan(0.99));
      expect(_n(6, 21).summer, greaterThan(0.99));
      expect(_s(12, 21).summer, greaterThan(0.99));
      expect(_s(6, 21).winter, greaterThan(0.99));
    });

    test('los equinoccios reparten mitad y mitad', () {
      for (final (m, d) in [(3, 21), (9, 21)]) {
        final e = _n(m, d);
        expect(e.winter, closeTo(0.5, 0.06), reason: '$d/$m');
        expect(e.summer, closeTo(0.5, 0.06), reason: '$d/$m');
      }
    });

    test('primavera y otoño no coinciden nunca', () {
      // Son los dos caminos entre invierno y verano, así que a lo sumo uno de
      // los dos está encendido. Si los dos pesaran a la vez, las hojas
      // estarían brotando y cayéndose el mismo día.
      for (var d = 0; d < 366; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        expect(
          s.spring * s.autumn,
          lessThan(1e-9),
          reason: 'el día $d es primavera y otoño a la vez',
        );
      }
    });

    test('cada estación tiene su pico en su sitio', () {
      expect(_n(3, 21).spring, greaterThan(0.98));
      expect(_n(9, 21).autumn, greaterThan(0.98));
      expect(_n(3, 21).autumn, lessThan(0.02));
      expect(_n(9, 21).spring, lessThan(0.02));
    });

    test('el nombre acompaña al número', () {
      expect(_n(1, 15).name, 'Invierno');
      expect(_n(4, 15).name, 'Primavera');
      expect(_n(7, 15).name, 'Verano');
      expect(_n(10, 15).name, 'Otoño');
      // Y en el sur, al revés, el mismo día.
      expect(_s(1, 15).name, 'Verano');
      expect(_s(7, 15).name, 'Invierno');
    });

    test('el sur va medio año por delante del norte', () {
      for (var d = 0; d < 366; d += 7) {
        final day = DateTime(2026).add(Duration(days: d));
        final n = Season.on(day, Hemisphere.north);
        final s = Season.on(day, Hemisphere.south);
        expect(
          n.winter,
          closeTo(s.summer, 1e-9),
          reason: 'el día $d los dos lados están en lo mismo',
        );
      }
    });

    test('nada da un salto de un día para el otro', () {
      // Un mundo que cambia de color de golpe una noche está mal. Lo más que
      // se puede mover cualquiera de estos números en un día es lo que se
      // mueve un coseno en un día, que es muy poco.
      var prev = Season.on(DateTime(2026), Hemisphere.north);
      for (var d = 1; d < 400; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        for (final (nombre, a, b) in [
          ('invierno', prev.winter, s.winter),
          ('nieve', prev.snow, s.snow),
          ('hoja', prev.bare, s.bare),
          ('amanecer', prev.sunrise, s.sunrise),
        ]) {
          expect(
            (a - b).abs(),
            lessThan(0.09),
            reason: '$nombre pegó un salto en el día $d',
          );
        }
        prev = s;
      }
    });
  });

  group('la luz del día', () {
    test('el día más largo es el de verano y el más corto el de invierno', () {
      final verano = _n(6, 21).daylightHours;
      final invierno = _n(12, 21).daylightHours;
      expect(verano, greaterThan(invierno + 4));
      // Y son duraciones de un sitio donde vive gente, no de Islandia.
      expect(verano, inInclusiveRange(13.0, 15.5));
      expect(invierno, inInclusiveRange(8.5, 11.0));
    });

    test('el mediodía solar no se mueve', () {
      for (var d = 0; d < 366; d += 11) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        expect((s.sunrise + s.sunset) / 2, closeTo(Season.noon, 1e-9));
      }
    });

    test('en los equinoccios el día y la noche se parecen', () {
      expect(_n(3, 21).daylightHours, closeTo(12.1, 0.6));
    });
  });

  group('la nieve y la hoja', () {
    test('no hay nieve fuera de lo más crudo del invierno', () {
      // Una escarcha de nueve meses sería peor que no tener estaciones.
      var conNieve = 0;
      for (var d = 0; d < 365; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        if (s.snow > 0.02) conNieve++;
      }
      expect(conNieve, inInclusiveRange(40, 130), reason: '$conNieve días');
      expect(_n(6, 21).snow, 0);
      expect(_n(9, 21).snow, 0);
      expect(_n(1, 5).snow, greaterThan(0.5));
    });

    test('primero se doran las hojas y después se caen', () {
      // El orden importa: un árbol pelado en pleno otoño dorado es un árbol
      // que se saltó la mitad bonita.
      final dorado = _n(10, 20);
      expect(dorado.autumn, greaterThan(0.6));
      expect(dorado.bare, lessThan(0.45));
      final pelado = _n(1, 10);
      expect(pelado.bare, greaterThan(0.8));
      expect(pelado.autumn, lessThan(0.35));
    });
  });

  group('de qué lado del mundo', () {
    test('el país del idioma decide, y se puede equivocar hacia el norte', () {
      expect(Season.hemisphereOf('AR'), Hemisphere.south);
      expect(Season.hemisphereOf('AU'), Hemisphere.south);
      expect(Season.hemisphereOf('ES'), Hemisphere.north);
      expect(Season.hemisphereOf('US'), Hemisphere.north);
      // Sin país, el norte, que es lo que sale por defecto en todo.
      expect(Season.hemisphereOf(null), Hemisphere.north);
      expect(Season.hemisphereOf(''), Hemisphere.north);
    });
  });

  group('el año que no existe', () {
    test('Season.none es verano pleno, que es la luz de siempre', () {
      // Todo lo que estaba medido antes de que hubiera estaciones se midió con
      // esta luz. Si esto cambiara, cambiarían de golpe todas las capturas y
      // ninguna prueba diría por qué.
      expect(Season.none.summer, 1.0);
      expect(Season.none.snow, 0.0);
      expect(Season.none.bare, 0.0);
      // Y exactamente de seis a ocho, que es el día que supone el ciclo de
      // colores. Con eso, remapear la hora con Season.none es no hacer nada.
      expect(Season.none.sunrise, 6.0);
      expect(Season.none.sunset, 20.0);
    });
  });

  group('la hora, llevada al horario del ciclo', () {
    // La paleta guarda en `hour` la hora ya remapeada, así que se puede leer
    // desde fuera sin abrir nada privado.
    double cycle(double clock, Season s) =>
        Palette.forMoment(clock, 1.0, season: s).hour;

    test('sin estación no se mueve nada', () {
      // Lo que protege todo lo que ya estaba: las capturas, los tests de cielo
      // y de silueta, los colores elegidos a mano. Si esto falla, añadir el
      // año le cambió el aspecto a la app entera sin querer.
      // Hasta las veinticuatro sin incluirlas: la paleta trabaja en módulo
      // veinticuatro, así que las veinticuatro son las cero y siempre lo
      // fueron.
      for (var h = 0.0; h < 24.0; h += 0.25) {
        expect(cycle(h, Season.none), closeTo(h, 1e-9), reason: 'a las $h');
      }
    });

    test('el amanecer de hoy cae siempre en las seis', () {
      for (final s in [_n(1, 15), _n(4, 15), _n(7, 15), _n(10, 15)]) {
        expect(cycle(s.sunrise, s), closeTo(6.0, 1e-9), reason: s.name);
        expect(cycle(s.sunset, s), closeTo(20.0, 1e-9), reason: s.name);
        expect(cycle(Season.noon, s), closeTo(Season.noon, 1e-9));
      }
    });

    test('la hora nunca va para atrás', () {
      // Es la única propiedad que no se puede romper: con un remapeo que no
      // sea monótono, el cielo daría marcha atrás a alguna hora del día.
      for (final s in [_n(1, 15), _n(4, 15), _n(7, 15), _n(10, 15)]) {
        var prev = -1.0;
        for (var h = 0.0; h < 24.0; h += 0.05) {
          final c = cycle(h, s);
          expect(c, greaterThanOrEqualTo(prev - 1e-9), reason: '${s.name} $h');
          prev = c;
        }
        expect(cycle(0, s), closeTo(0, 1e-9));
        expect(cycle(23.999, s), greaterThan(23.99));
      }
    });

    test('una mañana de invierno todavía está amaneciendo', () {
      // El asunto entero, dicho como se ve: a las ocho de un enero del norte
      // el cielo tiene que estar todavía en el amanecer —el ciclo pone el
      // amanecer entre las 5,6 y las 7,2— y a las ocho de julio ya no.
      final enero = _n(1, 15), julio = _n(7, 15);
      expect(cycle(8.0, enero), lessThan(7.2));
      expect(cycle(8.0, julio), greaterThan(7.2));
      // Y la tarde al revés: a las siete y media anochece en enero y todavía
      // es de día en julio.
      expect(cycle(19.5, enero), greaterThan(20.0));
      expect(cycle(19.5, julio), lessThan(19.6));
    });
  });

  group('y se ve en el prado', () {
    Color prado(Season s, [double h = 13]) =>
        TownPainter.meadowTone(Palette.forMoment(h, 1.0, season: s));

    test('sin estación, ni un bit de diferencia', () {
      // El seguro de todo lo anterior a las estaciones: con el año apagado,
      // el prado tiene que salir exactamente el de siempre, a cualquier hora.
      for (var h = 0.0; h < 24.0; h += 0.5) {
        final antes = TownPainter.meadowTone(Palette.forMoment(h, 1.0));
        final ahora = prado(Season.none, h);
        expect(ahora, antes, reason: 'a las $h');
      }
    });

    test('las cuatro se distinguen a simple vista', () {
      // Cuatro estaciones que hay que mirar dos veces para notar no son
      // cuatro estaciones. El umbral está en lo que separa dos colores que
      // cualquiera diría que son distintos.
      final cuatro = {
        'invierno': prado(_n(12, 21)),
        'primavera': prado(_n(3, 21)),
        'verano': prado(_n(6, 21)),
        'otoño': prado(_n(9, 21)),
      };
      final nombres = cuatro.keys.toList();
      for (var i = 0; i < nombres.length; i++) {
        for (var j = i + 1; j < nombres.length; j++) {
          final a = cuatro[nombres[i]]!, b = cuatro[nombres[j]]!;
          final d = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
          expect(
            d,
            greaterThan(0.10),
            reason: '${nombres[i]} y ${nombres[j]} son el mismo prado',
          );
        }
      }
    });

    test('el otoño es más cálido que el verano y no es Marte', () {
      // Lo que salió mal al teñir por razón entre colores: el ocre subía el
      // rojo vez y media y el valle quedaba plantado en Marte.
      final o = prado(_n(9, 21)), v = prado(_n(6, 21));
      expect(o.r - o.g, greaterThan(v.r - v.g), reason: 'el otoño no calienta');
      expect(o.r, lessThan(0.47), reason: 'demasiado rojo: ${o.r}');
    });

    test('la primavera es más clara y más verde que el verano', () {
      final p = prado(_n(3, 21)), v = prado(_n(6, 21));
      expect(p.computeLuminance(), greaterThan(v.computeLuminance()));
    });

    test('el invierno está nevado y las otras tres no', () {
      final i = prado(_n(12, 21));
      expect(i.computeLuminance(), greaterThan(0.28));
      for (final (m, d) in [(3, 21), (6, 21), (9, 21)]) {
        expect(prado(_n(m, d)).computeLuminance(), lessThan(0.22));
      }
    });

    test('y la nieve de noche sigue siendo de noche', () {
      // Nieve casi blanca en un paisaje nocturno es un agujero recortado. Se
      // ve —tiene que verse, es lo único claro que hay— pero no alumbra.
      final noche = prado(_n(12, 21), 2);
      final dia = prado(_n(12, 21), 13);
      expect(noche.computeLuminance(), lessThan(dia.computeLuminance() * 0.62));
      expect(
        noche.b,
        greaterThan(noche.r),
        reason: 'la nieve de noche es azul',
      );
    });
  });

  test('un cuarto de año es una estación', () {
    // Guarda contra que la vuelta se descuadre: del pico de una al pico de la
    // siguiente hay un cuarto de vuelta y ni un día más.
    final a = _n(12, 21).turn;
    final b = Season.on(
      DateTime(2026, 12, 21).add(const Duration(days: _quarter)),
      Hemisphere.north,
    ).turn;
    expect((b - a + 1) % 1.0, closeTo(0.25, 0.01));
  });
}
