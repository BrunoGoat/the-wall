import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/demo.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/ui/board_look.dart';
import 'package:la_muralla/ui/notice_board.dart';
import 'package:la_muralla/ui/style.dart';

void main() {
  // El valle de mentira existe para una sola cosa: enseñar el tablón lleno.
  // Si el reparto de horas o de días de la semana se afloja, el tablón vuelve
  // a quedarse en dos notas y el ajuste deja de servir para lo que se hizo,
  // sin que nada falle. Esto lo exige.
  group('el valle de mentira', () {
    // Un jueves cualquiera, para que el test no dependa del día que se corra.
    final hoy = DateTime(2026, 3, 12, 21);
    final valle = demoValley(hoy);

    test('son dos pueblos, y el de entrenar tiene unas 200 piezas', () {
      expect(valle.length, 2);
      final entrenar = valle.first;
      expect(entrenar.name, 'Entrenar');
      expect(entrenar.total, inInclusiveRange(170, 230));
      expect(valle[1].name, 'Leer');
      expect(valle[1].total, inInclusiveRange(80, 170));
      // Y el de entrenar va por delante, que es lo que le da sentido a la
      // corona: dos pueblos empatados no dicen nada.
      expect(entrenar.total, greaterThan(valle[1].total));
    });

    test('repartidas por unos 300 días, con días de varias y días de cero', () {
      final entrenar = valle.first;
      final dias = daysOf(entrenar);
      final desde = hoy.difference(entrenar.pieces.first.placedAt).inDays;
      expect(desde, inInclusiveRange(280, 305));
      // Ni todos los días ni un puñado: un pueblo que se construyó de verdad.
      expect(dias.length, inInclusiveRange(140, 210));
      expect(
        dias.length,
        lessThan(entrenar.total),
        reason: 'nunca dos el mismo día',
      );
      // Y huecos largos de los que se volvió.
      final huecos = <int>[];
      for (var i = 1; i < dias.length; i++) {
        final falta = dias[i].difference(dias[i - 1]).inDays - 1;
        if (falta > 0) huecos.add(falta);
      }
      expect(huecos.length, greaterThan(20));
      expect(huecos.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(9));
    });

    test('las piezas llevan hora de entrenar, no de cualquier momento', () {
      for (final p in valle.first.pieces) {
        final h = p.placedAt.hour;
        expect(
          (h >= 6 && h <= 9) || (h >= 19 && h <= 20),
          isTrue,
          reason: 'una pieza de entrenar a las $h',
        );
      }
      // Y algo más de la mitad llevan leyenda, que es lo que se quería ver.
      final conLeyenda = valle.first.pieces.where((p) => p.hasLabel).length;
      expect(conLeyenda / valle.first.total, inInclusiveRange(0.4, 0.7));
      expect({
        for (final p in valle.first.pieces)
          if (p.hasLabel) p.label,
      }, contains('Andar en bici'));
    });

    test('el mismo día enseña siempre el mismo pueblo', () {
      final otra = demoValley(hoy);
      expect(otra.first.total, valle.first.total);
      expect(otra.first.pieces.last.placedAt, valle.first.pieces.last.placedAt);
      expect(otra.first.pieces.last.label, valle.first.pieces.last.label);
    });

    // Lo que de verdad importa: que el tablón tenga qué decir. Cada una de
    // estas notas tiene su propio listón —veinte piezas y siete de cada diez
    // en la misma franja para la hora, seis huecos para la vuelta, veinte
    // puntos de diferencia para el par— y ninguna aparece por pedirlo.
    test('y el tablón sale lleno', () {
      final entrenar = valle.first;
      final obra = TownPlan.of(
        entrenar.place,
      ).underway(entrenar.total, entrenar.chronicle);
      final notas = noticesFor(
        entrenar,
        others: valle,
        underway: obra?.$1,
        left: obra?.$2 ?? 0,
        at: hoy,
      );
      final tipos = {for (final n in notas) n.kind};
      for (final quiere in NoticeKind.values) {
        expect(
          tipos,
          contains(quiere),
          reason:
              'al tablón de mentira le falta la nota «${quiere.name}», que es '
              'una de las que se hizo para poder mirar',
        );
      }
    });

    // Y lleno cualquier día, no sólo el que se eligió para el test: el ajuste
    // se abre el día que uno lo abre, y un tablón que sólo se llena los
    // jueves no vale para comparar cinco fondos.
    test('cualquier día que se abra', () {
      for (var d = 0; d < 21; d++) {
        final cuando = DateTime(2026, 3, 12, 21).add(Duration(days: d));
        final v = demoValley(cuando);
        final obra = TownPlan.of(
          v.first.place,
        ).underway(v.first.total, v.first.chronicle);
        final notas = noticesFor(
          v.first,
          others: v,
          underway: obra?.$1,
          left: obra?.$2 ?? 0,
          at: cuando,
        );
        expect(
          notas.length,
          greaterThanOrEqualTo(7),
          reason:
              'abierto el ${cuando.day}/${cuando.month} el tablón sólo tiene '
              '${notas.length} notas: ${notas.map((n) => n.kind.name)}',
        );
        expect(v.first.total, inInclusiveRange(170, 230));
      }
    });
  });

  // Los diez tablones, con el pueblo lleno encima y en dos teléfonos.
  //
  // Cada uno rediseña el remate, el marco, los postes, la forma del papel y
  // con qué se clava, así que cualquiera de ellos puede romper lo de delante
  // sin que se note al mirar uno solo: la moldura de nueve píxeles del roble
  // come ancho, los recortes del clavado se corren a los lados y se pueden
  // salir, y el nombre del hábito se escribe sobre la madera en varios de
  // ellos. Esto exige que los diez quepan, que ninguno escriba en su propio
  // color y que ninguno vuelva a comerse la pantalla de arriba.
  group('los diez tablones', () {
    const pantallas = [Size(320, 640), Size(440, 950)];

    testWidgets('caben todas, con el pueblo de mentira encima', (tester) async {
      final valle = demoValley(DateTime(2026, 3, 12, 21));
      for (final look in BoardLook.values) {
        for (final size in pantallas) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 34, bottom: 22),
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: NoticeBoardScreen(
                  valley: valle,
                  habit: valle.first,
                  theme: UiTheme(Palette.forMoment(13, 1.0)),
                  look: look,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${look.label} se rompe en $size',
          );
          for (final e in find.byType(Text).evaluate()) {
            final box = e.renderObject! as RenderBox;
            final at = box.localToGlobal(Offset.zero);
            expect(
              at.dx,
              greaterThan(-1),
              reason: '${look.label} se sale por la izquierda en $size',
            );
            expect(
              at.dx + box.size.width,
              lessThan(size.width + 1),
              reason: '${look.label} se sale por la derecha en $size',
            );
          }
        }
      }
    });

    test('ninguno se come la pantalla por arriba', () {
      for (final look in BoardLook.values) {
        // El tejado del modelo es un sexto de lo que mide la plancha. El de
        // la pantalla medía cuarenta y dos píxeles y encima se le reservaban
        // otros treinta y cuatro para el botón de volver: entre los dos, más
        // de lo que ocupa una nota entera.
        expect(
          look.skin.topHeight,
          lessThanOrEqualTo(26),
          reason: '${look.label} vuelve a llevarse la pantalla de arriba',
        );
      }
    });

    test('ninguno escribe con el color de su propio fondo', () {
      for (final look in BoardLook.values) {
        final s = look.skin;
        // El nombre del hábito va sobre la superficie, no sobre un papel.
        // El listón es flojo a propósito: el de tablones está quemado en la
        // madera y es de los suaves que hay (0,13), y así tiene que seguir
        // siendo. Lo que esto caza es lo otro, que alguien elija un fondo
        // nuevo y se olvide de que ahí encima se escribe.
        expect(
          _lejos(s.heading, s.wood),
          greaterThan(0.12),
          reason: '${look.label} escribe el nombre casi del color del fondo',
        );
        // Y los papeles tienen que despegarse de ella de una de las dos
        // maneras que hay: por el color, o por la sombra que echan. Sobre una
        // pared de cal casi blanca un papel claro nunca va a separarse por el
        // color —y no tiene por qué, es lo que pasa en una pared de verdad—,
        // pero entonces la sombra tiene que hacer ese trabajo. Lo que no vale
        // es ninguna de las dos.
        for (final p in s.papers) {
          expect(
            _lejos(p, s.wood) > 0.1 || s.shadow >= 0.3,
            isTrue,
            reason:
                'un papel de ${look.label} no se separa del fondo ni por el '
                'color ni por la sombra',
          );
          expect(
            _luz(p),
            greaterThan(0.75),
            reason:
                'un papel de ${look.label} es demasiado oscuro para la '
                'tinta que lleva encima',
          );
        }
      }
    });
  });
}

double _luz(Color c) => (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);

double _lejos(Color a, Color b) => (_luz(a) - _luz(b)).abs();
