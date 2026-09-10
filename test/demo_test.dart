import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/demo.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/ui/board_plan.dart';
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

  // El tablón, ahora que es un sitio en el mundo y no una pantalla.
  //
  // Lo que hay que exigirle no es cómo se ve sino que la geometría cierre: que
  // sea horizontal, que ninguna hoja se salga de la madera, que la matriz que
  // planta el texto sobre el papel lo plante donde está el papel, y que la
  // distancia calculada para verlo entero lo enseñe entero de verdad. Todo eso
  // es comprobable sin mirar.
  group('el tablón en tres dimensiones', () {
    final valle = demoValley(DateTime(2026, 3, 12, 21));
    final entrenar = valle.first;
    final obra = TownPlan.of(
      entrenar.place,
    ).underway(entrenar.total, entrenar.chronicle);
    final said = noticesFor(
      entrenar,
      others: valle,
      underway: obra?.$1,
      left: obra?.$2 ?? 0,
      at: DateTime(2026, 3, 12, 21),
    );
    final plan = BoardPlan.of(said);

    test('es más ancho que alto, que era el encargo', () {
      expect(plan.papers.length, said.length);
      expect(
        plan.halfWidth * 2,
        greaterThan((plan.top - plan.low) * 1.5),
        reason: 'el tablón volvió a ser una columna',
      );
    });

    test('ninguna hoja se sale de la madera, ni descolgada', () {
      for (final hoja in plan.papers) {
        for (final open in [0.0, 0.5, 1.0]) {
          for (final v in hoja.cornersAt(open)) {
            expect(
              v.x.abs(),
              lessThanOrEqualTo(plan.halfWidth),
              reason:
                  'la hoja ${hoja.index} se sale por un lado con open=$open',
            );
            expect(
              v.y,
              inInclusiveRange(plan.low, plan.high),
              reason:
                  'la hoja ${hoja.index} se sale por arriba o por abajo con '
                  'open=$open',
            );
          }
        }
      }
    });

    test('y ninguna tapa a otra estando clavadas', () {
      // Descolgada sí puede taparlas —para eso se descuelga—, pero clavadas
      // tienen que poder tocarse una a una.
      for (var i = 0; i < plan.papers.length; i++) {
        for (var j = i + 1; j < plan.papers.length; j++) {
          final a = plan.papers[i], b = plan.papers[j];
          final juntas =
              (a.cx - b.cx).abs() < a.w + b.w &&
              (a.cy - b.cy).abs() < a.h + b.h;
          expect(
            juntas,
            isFalse,
            reason: 'las hojas $i y $j están una encima de la otra',
          );
        }
      }
    });

    test('la matriz del papel pone el texto donde está el papel', () {
      // Es la cuenta que sostiene todo: se maqueta la nota en un rectángulo
      // plano y esto lo estira hasta las cuatro esquinas de la hoja en la
      // pantalla. Si esta matriz miente, el texto flota al lado del papel.
      const src = Size(300, 230);
      for (final quad in [
        // de frente
        const [
          Offset(100, 100),
          Offset(400, 100),
          Offset(400, 330),
          Offset(100, 330),
        ],
        // de lado, con perspectiva de verdad: los dos lados no miden igual
        const [
          Offset(120, 90),
          Offset(380, 140),
          Offset(380, 300),
          Offset(120, 400),
        ],
      ]) {
        final m = paperTransform(src, quad);
        expect(m, isNotNull);
        final esquinas = [
          Offset.zero,
          Offset(src.width, 0),
          Offset(src.width, src.height),
          Offset(0, src.height),
        ];
        for (var i = 0; i < 4; i++) {
          final u = esquinas[i].dx, v = esquinas[i].dy;
          final w = m![3] * u + m[7] * v + m[15];
          final x = (m[0] * u + m[4] * v + m[12]) / w;
          final y = (m[1] * u + m[5] * v + m[13]) / w;
          expect(x, closeTo(quad[i].dx, 0.01), reason: 'esquina $i en x');
          expect(y, closeTo(quad[i].dy, 0.01), reason: 'esquina $i en y');
        }
      }
    });

    test('tocar una hoja acierta dentro y falla fuera', () {
      const quad = [
        Offset(100, 100),
        Offset(300, 120),
        Offset(300, 260),
        Offset(100, 240),
      ];
      expect(insideQuad(quad, const Offset(200, 180)), isTrue);
      expect(insideQuad(quad, const Offset(200, 60)), isFalse);
      expect(insideQuad(quad, const Offset(340, 180)), isFalse);
    });

    test('desde la distancia que dice, se ve entero', () {
      for (final size in [const Size(320, 640), const Size(440, 950)]) {
        final cam = OrbitCamera()
          ..travel = 0
          ..focusY = plan.midY
          ..focusZ = 0
          ..yaw = 0
          ..pitch = 0
          ..distance = plan.fitDistance(size);
        final p = cam.projector(size.width, size.height, 0);
        for (final v in [
          V3(-plan.halfWidth - BoardPlan.eave, plan.low, 0),
          V3(plan.halfWidth + BoardPlan.eave, plan.low, 0),
          V3(plan.halfWidth + BoardPlan.eave, plan.top, 0),
          V3(-plan.halfWidth - BoardPlan.eave, plan.top, 0),
        ]) {
          final at = p.project(v);
          expect(at, isNotNull);
          expect(
            at!.x,
            inInclusiveRange(0, size.width),
            reason: 'una esquina del tablón se sale por un lado en $size',
          );
          expect(
            at.y,
            inInclusiveRange(0, size.height),
            reason:
                'una esquina del tablón se sale por arriba o abajo en $size',
          );
        }
      }
    });

    testWidgets('se abre y se dibuja sin romperse', (tester) async {
      for (final size in [const Size(320, 640), const Size(440, 950)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: NoticeBoardScreen(
                valley: valle,
                habit: entrenar,
                theme: UiTheme(Palette.forMoment(13, 1.0)),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'se rompe en $size');
        // Y tocar en medio no explota: o descuelga una hoja, o acerca.
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'al tocar en $size');
      }
    });
  });
}
