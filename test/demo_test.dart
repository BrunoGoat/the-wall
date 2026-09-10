import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:la_muralla/data/demo.dart';
import 'package:la_muralla/data/gossip.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/solids.dart';
import 'package:la_muralla/model/board.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/board_slots.dart';
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
      // Todas menos las del pueblo, que no salen de acá: una cabra perdida no
      // es algo que se sepa de nadie.
      for (final quiere in NoticeKind.values) {
        if (quiere == NoticeKind.pueblo) continue;
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
    final plan = BoardPlan.of(said, slots: _enFila(said.length));

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
      // tienen que poder tocarse una a una. Con los huecos sorteados esto ya
      // no es evidente: se comprueba con el tablón lleno y repartido al azar,
      // que es el caso peor.
      final lleno = BoardPlan.of(
        [
          for (var i = 0; i < BoardPlan.capacity; i++)
            Notice(NoticeKind.pueblo, 'nota \$i', 'porque sí'),
        ],
        slots: [7, 2, 9, 0, 5, 3, 8, 1, 6, 4],
      );
      for (final p in [plan, lleno]) {
        for (var i = 0; i < p.papers.length; i++) {
          for (var j = i + 1; j < p.papers.length; j++) {
            final a = p.papers[i], b = p.papers[j];
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

    // Lo que de verdad hay que exigirle al movimiento: que no deje salirse.
    // El tablón se recorre a los lados y nada más, y el tope tiene que caer
    // exactamente en el filo de la madera — ni antes, que dejaría notas sin
    // alcanzar, ni después, que dejaría arrastrarse al vacío.
    test('no se puede arrastrar fuera del tablón', () {
      for (final size in [const Size(320, 640), const Size(440, 950)]) {
        final cerca = plan.nearLimit(size), lejos = plan.farLimit(size);
        expect(
          cerca,
          lessThan(lejos),
          reason: 'la franja de zoom está al revés',
        );
        for (final d in [cerca, plan.readDistance(size), lejos]) {
          final tope = plan.panLimit(size, d);
          final cam = OrbitCamera()
            ..focusY = plan.midY
            ..focusZ = 0
            ..yaw = 0
            ..pitch = 0
            ..distance = d;
          final borde = plan.halfWidth + BoardPlan.eave;
          if (tope == 0) {
            // Cabe entero: los dos filos tienen que verse.
            cam.travel = 0;
            final p = cam.projector(size.width, size.height, 0);
            for (final x in [-borde, borde]) {
              final at = p.project(V3(x, plan.midY, 0))!;
              expect(at.x, inInclusiveRange(0, size.width));
            }
            continue;
          }
          // Corrido hasta el tope, el filo de la madera llega al filo de la
          // pantalla y ni un dedo más: no queda prado a la vista por ese lado.
          for (final s in [-1.0, 1.0]) {
            cam.travel = s * tope;
            final p = cam.projector(size.width, size.height, 0);
            final at = p.project(V3(s * borde, plan.midY, 0))!;
            expect(
              at.x,
              closeTo(s > 0 ? size.width : 0, 1.5),
              reason:
                  'a $d de distancia el tope deja ver fuera del tablón, o no '
                  'deja llegar al filo, en $size',
            );
          }
        }
      }
    });

    test('y de alto entra siempre, así que no hay nada que subir ni bajar', () {
      for (final size in [const Size(320, 640), const Size(440, 950)]) {
        for (final d in [
          plan.nearLimit(size),
          plan.readDistance(size),
          plan.farLimit(size),
        ]) {
          final cam = OrbitCamera()
            ..focusY = plan.midY
            ..focusZ = 0
            ..yaw = 0
            ..pitch = 0
            ..distance = d;
          final p = cam.projector(size.width, size.height, 0);
          for (final y in [plan.low, plan.top]) {
            final at = p.project(V3(0, y, 0))!;
            expect(
              at.y,
              inInclusiveRange(0, size.height),
              reason:
                  'a $d de distancia el tablón se sale por arriba o por abajo '
                  'en $size, y no hay manera de moverse para verlo',
            );
          }
        }
      }
    });

    // El tablón es siempre igual de grande, tenga una nota o diez. Antes
    // crecía con lo que hubiera que clavar, y al crecer a lo alto la cámara
    // tenía que echarse atrás: las hojas se veían más chicas cuantas más
    // había, o sea que cuanto más tenía que decir el pueblo, menos se leía.
    test('mide siempre lo mismo, y las hojas también', () {
      const size = Size(400, 860);
      BoardPlan conN(int n) => BoardPlan.of([
        for (var i = 0; i < n; i++) Notice(NoticeKind.pueblo, 'x\$i', 'y'),
      ], slots: _enFila(n));
      final uno = conN(1);
      for (final n in [1, 2, 5, 9, 10]) {
        final p = conN(n);
        expect(
          p.halfWidth,
          uno.halfWidth,
          reason: 'con $n notas cambia de ancho',
        );
        expect(p.low, uno.low);
        expect(p.high, uno.high);
        expect(
          p.readDistance(size),
          uno.readDistance(size),
          reason: 'con $n notas hay que mirarlo desde otra distancia',
        );
        for (final hoja in p.papers) {
          expect(
            hoja.w,
            BoardPlan.paperW,
            reason: 'con $n notas la hoja encoge',
          );
          expect(hoja.h, BoardPlan.paperH);
        }
      }
    });

    test('con pocas notas la madera se queda vacía a la derecha', () {
      final p = BoardPlan.of([
        for (var i = 0; i < 2; i++) Notice(NoticeKind.pueblo, 'x\$i', 'y'),
      ], slots: _enFila(2));
      expect(p.papers.length, 2);
      // Las dos en la primera columna, una arriba y otra abajo, y todo lo demás
      // madera. Eso es lo que cuenta la verdad de un pueblo que no sabe casi
      // nada de vos; un tablón chiquito y lleno cuenta lo contrario.
      for (final hoja in p.papers) {
        expect(
          hoja.cx,
          lessThan(-p.halfWidth + BoardPlan.colPitch + BoardPlan.margin),
          reason: 'la nota ${hoja.index} no está en la primera columna',
        );
      }
      expect(p.papers[0].cy, greaterThan(p.papers[1].cy));
    });

    test('y nunca hay más notas de las que caben', () {
      // Si las hubiera, BoardPlan las tiraría en silencio.
      for (final h in valle) {
        expect(
          boardNotices(h, valley: valle, at: DateTime(2026, 3, 12, 21)).length,
          lessThanOrEqualTo(BoardPlan.capacity),
        );
      }
    });

    // El que faltaba, y por faltar salió una versión con el tablón de la plaza
    // usando los huecos sorteados y el de cerca poniendo los papeles en fila:
    // desde el valle estaban a la derecha y al entrar aparecían a la
    // izquierda. Que los dos reciban la misma lista de huecos no basta si
    // luego no la usan igual, así que se comparan las dos colocaciones.
    test('la plaza y el tablón de cerca colocan igual', () {
      final huecos = [7, 1, 8, 6, 5, 0, 4, 3, 9, 2];
      final notas = [
        for (var i = 0; i < huecos.length; i++)
          Notice(NoticeKind.pueblo, 'nota $i', 'porque sí'),
      ];
      final cerca = BoardPlan.of(notas, slots: huecos);
      final plaza = <(double, double)>[];
      for (final sol in NoticeBoard.solidsAt(0, 0, sheets: huecos)) {
        for (final f in sol.faces) {
          for (final d in f.decals ?? const []) {
            plaza.add(((d.v[0].x + d.v[1].x) / 2, (d.v[0].y + d.v[2].y) / 2));
          }
        }
      }
      expect(plaza.length, cerca.papers.length);
      for (var i = 0; i < plaza.length; i++) {
        for (var j = i + 1; j < plaza.length; j++) {
          // Dos papeles de columnas distintas tienen que estar en el mismo
          // orden de izquierda a derecha en los dos tablones, y lo mismo de
          // arriba abajo. Si uno de los dos se diera la vuelta, esto lo canta.
          if (huecos[i] ~/ BoardPlan.rows != huecos[j] ~/ BoardPlan.rows) {
            expect(
              (cerca.papers[i].cx - cerca.papers[j].cx).sign,
              (plaza[i].$1 - plaza[j].$1).sign,
              reason: 'los papeles $i y $j se cruzan de un tablón al otro',
            );
          }
          if (huecos[i] % BoardPlan.rows != huecos[j] % BoardPlan.rows) {
            expect(
              (cerca.papers[i].cy - cerca.papers[j].cy).sign,
              (plaza[i].$2 - plaza[j].$2).sign,
              reason:
                  'los papeles $i y $j cambian de fila de un tablón al otro',
            );
          }
        }
      }
    });

    test('ninguna hoja se queda recta ni copia la de al lado', () {
      // Las inclinaciones salían de un solo sorteo simétrico, así que algunas
      // caían a medio grado —que se lee como recta— y las vecinas coincidían:
      // el desorden se leía como un patrón por columnas.
      final huecos = [for (var i = 0; i < BoardPlan.capacity; i++) i];
      final p = BoardPlan.of([
        for (var i = 0; i < huecos.length; i++)
          Notice(NoticeKind.pueblo, 'nota $i', 'y'),
      ], slots: huecos);
      final grados = [for (final h in p.papers) h.lean * 57.2958];
      for (final g in grados) {
        expect(g.abs(), greaterThan(1.2), reason: 'una hoja quedó recta');
        expect(g.abs(), lessThan(7), reason: 'una hoja quedó de lado');
      }
      // Y de los dos signos: todas cayendo al mismo lado vuelve a ser un patrón.
      expect(grados.where((g) => g > 0).length, inInclusiveRange(2, 8));
    });

    test('el tablón de la plaza clava las notas de verdad', () {
      // Lo que se ve desde el valle tiene que ser la silueta de lo que hay, no
      // tres papeles de adorno: medio lleno se ve medio lleno, y con los
      // papeles en los mismos huecos que al acercarse.
      for (final huecos in [
        <int>[],
        [4],
        [0, 3, 7, 9],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        // Un hueco que no existe se tira, no se dibuja en cualquier parte.
        [1, 99, -3],
      ]) {
        var hojas = 0;
        for (final s in NoticeBoard.solidsAt(0, 0, sheets: huecos)) {
          for (final f in s.faces) {
            hojas += f.decals?.length ?? 0;
          }
        }
        expect(
          hojas,
          huecos.where((h) => h >= 0 && h < NoticeBoard.capacity).length,
          reason: 'con los huecos $huecos la plaza enseña $hojas papeles',
        );
      }
    });

    test('el nombre del hábito no sale estirado', () {
      // La homografía estira lo que le den hasta las cuatro esquinas, así que
      // la caja donde se maqueta el nombre tiene que llevar la proporción del
      // hueco al que va. Con una caja de medidas fijas las letras se alargaban
      // a lo ancho, y cuanto más ancho el tablón —más notas— peor.
      for (final cuantas in [1, 4, 8, 14]) {
        final p = BoardPlan.of([
          for (var i = 0; i < cuantas; i++)
            Notice(NoticeKind.pueblo, 'x\$i', 'y'),
        ], slots: _enFila(cuantas));
        final hueco = 2 * (p.halfWidth - 0.1) / BoardPlan.headHeight;
        expect(
          p.headBox.width / p.headBox.height,
          closeTo(hueco, 1e-6),
          reason: 'con $cuantas notas el nombre sale deformado',
        );
      }
    });

    test('descolgar una nota la trae hacia el ojo, no sólo la agranda', () {
      for (final hoja in plan.papers) {
        final clavada = hoja.cornersAt(0);
        final suelta = hoja.cornersAt(1);
        expect(
          suelta[0].z - clavada[0].z,
          greaterThan(0.3),
          reason: 'la nota ${hoja.index} crece en el sitio y no se despega',
        );
        // Y desde la distancia de leerla, cabe y es de verdad un primer plano.
        const size = Size(400, 860);
        final cam = OrbitCamera()
          ..travel = hoja.openCx
          ..focusY = hoja.openCy
          ..focusZ = 0
          ..yaw = 0
          ..pitch = 0
          ..distance = hoja.closeUpDistance;
        final p = cam.projector(size.width, size.height, 0);
        final alto = (p.project(suelta[3])!.y - p.project(suelta[0])!.y).abs();
        expect(
          alto,
          lessThan(size.height),
          reason: 'la nota ${hoja.index} se sale de cuadro al descolgarla',
        );
        expect(
          alto,
          greaterThan(size.height * 0.55),
          reason: 'descolgar la nota ${hoja.index} apenas se nota',
        );
      }
    });

    test('los papeles son una familia y no un taco de pósits', () {
      final tonos = [
        for (final hoja in plan.papers) HSVColor.fromColor(hoja.paper),
      ];
      final matices = tonos.map((c) => c.hue).toList()..sort();
      expect(
        matices.last - matices.first,
        lessThan(25),
        reason: 'los papeles son de colores distintos y eso parece un código',
      );
      for (final c in tonos) {
        expect(
          c.saturation,
          lessThan(0.3),
          reason: 'un papel está demasiado saturado para ser pergamino',
        );
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

  // Los bandos del pueblo: lo que hay clavado cuando el tablón no habla de vos.
  group('los bandos del pueblo', () {
    test('cambian cada día y no se repiten dentro del mismo', () {
      final vistos = <String>{};
      for (var d = 0; d < 60; d++) {
        final dia = DateTime(2026, 3, 1).add(Duration(days: d));
        final hoy = villageNotices(dia, town: 0, count: 3);
        expect(hoy.length, 3);
        expect(
          {for (final n in hoy) n.said}.length,
          3,
          reason:
              'el ${dia.day}/${dia.month} el pueblo clavó dos veces lo mismo',
        );
        for (final n in hoy) {
          expect(n.kind, NoticeKind.pueblo);
          // Un bando no puede fingir que sabe algo de nadie: ni barras ni
          // párrafo de pruebas, que es lo que llevan las notas de verdad.
          expect(n.bars, isEmpty);
          expect(n.more, isNull);
        }
        vistos.add(hoy.map((n) => n.said).join('|'));
      }
      // En dos meses el pueblo tiene que tener vida propia, no un cartel fijo.
      expect(vistos.length, greaterThan(40));
    });

    test('el mismo día clava siempre lo mismo', () {
      final a = villageNotices(DateTime(2026, 5, 4, 9), town: 2);
      final b = villageNotices(DateTime(2026, 5, 4, 23), town: 2);
      expect(a.map((n) => n.said).toList(), b.map((n) => n.said).toList());
      expect(
        villageNotices(
          DateTime(2026, 5, 5),
          town: 2,
        ).map((n) => n.said).toList(),
        isNot(a.map((n) => n.said).toList()),
      );
    });

    test('a dos pueblos nunca les toca el mismo el mismo día', () {
      // Seis pueblos enseñando la misma cabra perdida no son seis pueblos, son
      // seis copias de una pantalla.
      for (var d = 0; d < 90; d++) {
        final dia = DateTime(2026, 1, 1).add(Duration(days: d));
        final todos = <String>[];
        for (var town = 0; town < Habit.maxSlots; town++) {
          todos.addAll(
            villageNotices(dia, town: town, count: 3).map((n) => n.said),
          );
        }
        expect(
          todos.toSet().length,
          todos.length,
          reason: 'el ${dia.day}/${dia.month} dos pueblos clavaron lo mismo',
        );
      }
    });

    test('pero de un día para otro sí se repiten, que es lo normal', () {
      // Lo que no puede repetirse es entre pueblos el mismo día. Con los días
      // sí: un tablón de plaza vuelve a sacar el bando de la cabra, y en
      // cuatro meses tiene que haber sacado casi todos.
      final vistos = <String>{};
      var total = 0;
      for (var d = 0; d < 120; d++) {
        final hoy = villageNotices(
          DateTime(2026, 1, 1).add(Duration(days: d)),
          town: 0,
        );
        total += hoy.length;
        vistos.addAll(hoy.map((n) => n.said));
      }
      expect(
        total,
        greaterThan(vistos.length),
        reason:
            'en cuatro meses no se repitió ninguno, que sería un reparto '
            'y no una baraja',
      );
      expect(
        vistos.length,
        greaterThan(villageNoticeCount ~/ 2),
        reason: 'el pueblo se quedó girando sobre cuatro bandos',
      );
    });

    test('hay bastantes como para que no canse', () {
      expect(villageNoticeCount, greaterThanOrEqualTo(30));
    });
  });

  // Que un papel clavado no se mueva nunca más.
  //
  // Es lo que separa un tablón de una lista barajada: si el reparto se
  // calculase al vuelo, en cuanto cambiara lo que hay que clavar se
  // recolocaría todo, y la nota que uno recuerda «arriba a la izquierda»
  // aparecería mañana en otra parte. El hueco se sortea una vez y se guarda.
  group('el tablón se acuerda de dónde clavó cada papel', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      BoardSlots.instance.forget();
    });

    List<Notice> notas(List<String> textos) => [
      for (final t in textos) Notice(NoticeKind.pueblo, t, 'porque sí'),
    ];

    test('reparte sin repetir hueco y sin dejarlas en fila', () {
      final said = notas([for (var i = 0; i < 10; i++) 'nota $i']);
      final huecos = BoardSlots.instance.assign(
        'pueblo',
        said,
        slots: NoticeBoard.capacity,
      );
      expect(huecos.length, 10);
      expect(
        huecos.toSet().length,
        10,
        reason: 'dos papeles en el mismo hueco',
      );
      for (final h in huecos) {
        expect(h, inInclusiveRange(0, NoticeBoard.capacity - 1));
      }
      expect(
        huecos,
        isNot([for (var i = 0; i < 10; i++) i]),
        reason: 'los clavó en fila, que es lo que no se quería',
      );
    });

    test('lo que ya estaba clavado no se mueve al cambiar lo demás', () {
      final antes = notas(['la cabra', 'el herrero', 'el ganso', 'los nabos']);
      final a = BoardSlots.instance.assign(
        'pueblo',
        antes,
        slots: NoticeBoard.capacity,
      );
      // Al día siguiente: se cae uno, llegan tres nuevos, y cambia el orden.
      final despues = notas([
        'el puente',
        'el ganso',
        'la cabra',
        'el pozo',
        'la fuente',
        'los nabos',
      ]);
      final b = BoardSlots.instance.assign(
        'pueblo',
        despues,
        slots: NoticeBoard.capacity,
      );
      for (final texto in ['la cabra', 'el ganso', 'los nabos']) {
        expect(
          b[despues.indexWhere((n) => n.said == texto)],
          a[antes.indexWhere((n) => n.said == texto)],
          reason: '«$texto» se movió de sitio',
        );
      }
      expect(b.toSet().length, b.length, reason: 'dos en el mismo hueco');
    });

    test('y dos pueblos no se pisan el tablón', () {
      final said = notas(['la cabra', 'el herrero']);
      final uno = BoardSlots.instance.assign(
        'pueblo-a',
        said,
        slots: NoticeBoard.capacity,
      );
      final otro = BoardSlots.instance.assign(
        'pueblo-b',
        said,
        slots: NoticeBoard.capacity,
      );
      // Pueden coincidir, pero cada uno recuerda el suyo: volver a preguntar
      // devuelve lo mismo que la primera vez.
      expect(
        BoardSlots.instance.assign(
          'pueblo-a',
          said,
          slots: NoticeBoard.capacity,
        ),
        uno,
      );
      expect(
        BoardSlots.instance.assign(
          'pueblo-b',
          said,
          slots: NoticeBoard.capacity,
        ),
        otro,
      );
    });

    test('y sobrevive a cerrar la app', () async {
      final said = notas(['la cabra', 'el herrero', 'el ganso']);
      final antes = BoardSlots.instance.assign(
        'pueblo',
        said,
        slots: NoticeBoard.capacity,
      );
      await BoardSlots.instance.flush();
      // Se apaga y se vuelve a encender.
      BoardSlots.instance.forget();
      await BoardSlots.instance.load();
      expect(
        BoardSlots.instance.assign('pueblo', said, slots: NoticeBoard.capacity),
        antes,
        reason: 'al reabrir la app el tablón se recolocó entero',
      );
    });

    test('el nombre de un papel no cambia porque cambie lo que dice', () {
      // La nota del horario es *la* del horario, diga hoy las siete y mañana
      // las ocho: si su nombre saliera del texto, cambiaría de sitio cada vez
      // que cambia lo que sabe de vos.
      expect(
        noticeId(const Notice(NoticeKind.hour, 'a las 7', 'x')),
        noticeId(const Notice(NoticeKind.hour, 'a las 8', 'y')),
      );
      // Los bandos sí se llaman por lo que dicen, porque no tienen clase
      // propia: son treinta y seis con la misma.
      expect(
        noticeId(const Notice(NoticeKind.pueblo, 'la cabra', 'x')),
        isNot(noticeId(const Notice(NoticeKind.pueblo, 'el ganso', 'x'))),
      );
    });
  });
}

/// Huecos en fila, para los tests a los que el reparto les da igual.
List<int> _enFila(int n) => [for (var i = 0; i < n; i++) i];
