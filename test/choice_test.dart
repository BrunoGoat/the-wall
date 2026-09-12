import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/ui/choice_sheet.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El plan de un pueblo cualquiera, siempre el mismo.
TownPlan get _plan => TownPlan.of(TownCharacter.all.first);

/// Una pregunta del pueblo, con todo lo que había alrededor cuando la hizo.
typedef Ask = ({
  int at,
  List<String> options,
  String taken,
  List<String> before,
});

/// Levanta un pueblo pieza a pieza, exactamente como hace la app: en cada
/// pieza se escribe en la crónica lo que ya se puede ver, y si el pueblo
/// pregunta, se le contesta con [pick] —o con lo primero que ofrece, que es lo
/// que pasa cuando nadie contesta— y se vuelve a escribir.
///
/// Devuelve todas las preguntas que hizo por el camino. Hace falta simular y
/// no calcular: al contestar distinto, la obra siguiente **empieza en otra
/// pieza**, porque las obras no cuestan todas lo mismo. Cualquier test que dé
/// por hecho dónde cae el segundo hito está mirando otro pueblo.
({List<String> chronicle, List<Ask> asks}) _grow(
  int pieces, {
  String Function(List<String> options)? pick,
}) {
  final plan = _plan;
  final chron = <String>[];
  final asks = <Ask>[];
  void escribir(int n) {
    final want = plan.chronicleFor(n, chron);
    chron
      ..clear()
      ..addAll(want);
  }

  for (var n = 0; n <= pieces; n++) {
    escribir(n);
    final c = plan.choiceFor(n, chron);
    if (c == null) continue;
    final before = [...chron];
    final taken = pick == null ? c.$2.first : pick(c.$2);
    asks.add((at: n, options: c.$2, taken: taken, before: before));
    chron.add(taken);
    escribir(n);
  }
  return (chronicle: chron, asks: asks);
}

/// Cuántas piezas hay que poner para que el pueblo pregunte [n] veces.
int _piecesFor(int n) {
  var pieces = 60;
  while (pieces < 4000) {
    if (_grow(pieces).asks.length >= n) return pieces;
    pieces += 60;
  }
  return -1;
}

void main() {
  group('el pueblo pregunta antes de empezar una obra', () {
    test('no pregunta por las casas, sólo por los hitos', () {
      final g = _grow(400);
      expect(g.asks, isNotEmpty, reason: 'no preguntó nunca en 400 piezas');
      for (final a in g.asks) {
        for (final id in a.options) {
          expect(
            TownPlan.landmarkOf(id),
            isNotNull,
            reason: 'ofreció «$id», que no es un hito',
          );
        }
      }
    });

    test('pregunta justo en la pieza en que la obra empezaría', () {
      // Ni antes —sería preguntar por algo que no se ve venir— ni después:
      // después ya habría piezas puestas de una obra que se elegiría luego, y
      // una pieza no se mueve nunca.
      final plan = _plan;
      for (final a in _grow(400).asks) {
        expect(
          plan.choiceFor(a.at - 1, a.before),
          isNull,
          reason: 'con ${a.at} piezas preguntó una pieza antes de tiempo',
        );
        final obra = plan.underway(a.at, a.before);
        expect(obra, isNotNull);
        expect(
          obra!.$2,
          TownPlan.landmarkOf(a.taken)!.cost,
          reason: 'la obra ya estaba empezada cuando preguntó',
        );
      }
    });

    test('las dos que ofrece son distintas y ninguna está en pie', () {
      for (final a in _grow(600).asks) {
        expect(
          a.options.toSet().length,
          2,
          reason: 'con ${a.at} piezas ofreció dos veces lo mismo',
        );
        for (final id in a.options) {
          expect(
            a.before.contains(id),
            isFalse,
            reason: 'ofreció «$id», que ya está levantado',
          );
        }
      }
    });

    test('deja de preguntar en cuanto se contesta', () {
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      final chron = [...a.before, a.taken];
      expect(plan.choiceFor(a.at, chron), isNull);
    });
  });

  group('contestar no le cambia el pueblo a nadie', () {
    test('lo que ya estaba escrito no se toca', () {
      // La regla de la crónica: sólo crece. Si contestar reescribiera algo de
      // más atrás, a alguien con doscientas piezas puestas le cambiarían las
      // casas por debajo.
      for (final a in _grow(400, pick: (o) => o.last).asks) {
        final chron = [...a.before, a.taken];
        expect(chron.sublist(0, a.before.length), a.before);
      }
    });

    test('la que no sale es la primera de la vez siguiente', () {
      // Elegir no es renunciar, es decidir el orden. Si al descartar una se
      // perdiera, la elección costaría una obra y la app estaría cobrando por
      // dejarte decidir.
      final g = _grow(_piecesFor(4), pick: (o) => o.last);
      expect(g.asks.length, greaterThanOrEqualTo(2));
      for (var i = 0; i + 1 < g.asks.length; i++) {
        final descartada = g.asks[i].options.first;
        expect(
          g.asks[i + 1].options.first,
          descartada,
          reason:
              'se descartó «$descartada» en la pregunta $i y no volvió a '
              'ofrecerse la primera en la siguiente',
        );
      }
    });

    test('la descartada se levanta la vez que se la elige', () {
      // Alternando —una vez la primera, otra la segunda, que es como contesta
      // cualquiera— todo lo que se ofrece acaba en pie.
      var turno = 0;
      final g = _grow(_piecesFor(6), pick: (o) => o[turno++ % 2]);
      for (final a in g.asks) {
        if (a.taken != a.options.first) continue;
        expect(
          g.chronicle.contains(a.options.first),
          isTrue,
          reason: 'se eligió «${a.taken}» y no se construyó',
        );
      }
    });

    test('y si nunca se la elige, sigue en la lista para siempre', () {
      // Contestando siempre la segunda, la primera se aplaza indefinidamente:
      // cada vez vuelve a salir la primera y cada vez se la vuelve a saltar.
      // No es un fallo, es lo que se pidió — y lo que importa es que no se
      // pierde: sigue ahí, la próxima vez que se conteste al revés.
      final g = _grow(_piecesFor(6), pick: (o) => o.last);
      final aplazada = g.asks.first.options.first;
      expect(g.chronicle.contains(aplazada), isFalse);
      expect(
        g.asks.last.options,
        contains(aplazada),
        reason: '«$aplazada» dejó de ofrecerse: se perdió del catálogo',
      );
    });

    test('no contestar levanta exactamente el pueblo de antes', () {
      // El seguro de compatibilidad: quien nunca conteste tiene que ver el
      // mismo pueblo que veía antes de que esto existiera, porque la primera
      // opción es justo la que el plan daba solo.
      final plan = _plan;
      final g = _grow(600);
      for (final a in g.asks) {
        final used = {
          for (final id in a.before)
            if (!id.startsWith(TownPlan.kindMark)) id,
        };
        expect(
          a.taken,
          plan.landmarkFor(0, used),
          reason: 'con ${a.at} piezas no eligió lo que salía solo',
        );
      }
      // Y la crónica entera es, obra por obra, la que el plan levantaba solo
      // antes de que hubiera nada que preguntar.
      final solo = [
        for (final w in plan.walk(const []).take(g.chronicle.length)) w.id,
      ];
      expect(g.chronicle, solo);
    });
  });

  group('la pregunta caduca, y eso es lo que la hace segura', () {
    test('en cuanto cae la pieza siguiente, se escribe sola', () {
      // Lo peligroso de dejar la pregunta abierta: si nadie contesta nunca, la
      // crónica se queda congelada, y una crónica congelada es exactamente lo
      // que la crónica existe para evitar —un hito nuevo en el catálogo le
      // cambiaría las casas a alguien que ya las tiene levantadas—. Así que la
      // pregunta dura una pieza. La siguiente la cierra sola con lo de siempre.
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      expect(plan.choiceFor(a.at, a.before), isNotNull);
      expect(
        plan.choiceFor(a.at + 1, a.before),
        isNull,
        reason: 'la pregunta siguió abierta con la obra ya empezada',
      );
      final escrita = plan.chronicleFor(a.at + 1, a.before);
      expect(
        escrita.length,
        greaterThan(a.before.length),
        reason: 'la crónica se quedó congelada esperando una respuesta',
      );
      expect(escrita[a.before.length], a.options.first);
    });

    test('y la crónica de quien nunca conteste sigue creciendo', () {
      // La misma garantía, dicha a lo largo: se ponen mil piezas sin contestar
      // una sola vez y la crónica tiene que llegar hasta el final.
      final plan = _plan;
      final chron = <String>[];
      for (var n = 0; n <= 1000; n++) {
        final want = plan.chronicleFor(n, chron);
        chron
          ..clear()
          ..addAll(want);
      }
      final obras = plan.walk(chron).takeWhile((w) => w.from <= 999).length;
      expect(
        chron.length,
        greaterThanOrEqualTo(obras - 1),
        reason: 'con mil piezas sin contestar la crónica se quedó corta',
      );
    });
  });

  group('mientras no se conteste', () {
    test('el pueblo se ve como si hubiera elegido la primera', () {
      // Nada se queda a medias esperando una respuesta: el plan sigue dando la
      // primera opción, así que la pieza que cae tiene dónde ir. Lo único que
      // pasa es que todavía no está escrito, y por eso se puede cambiar.
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      final obra = plan.underway(a.at, a.before);
      expect(obra, isNotNull);
      expect(obra!.$1, TownPlan.landmarkOf(a.options.first)!.name);
      expect(obra.$3, isTrue, reason: 'debería estar levantando un hito');
    });

    test('y la crónica se planta ahí, sin escribirlo', () {
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      expect(
        plan.chronicleFor(a.at, a.before).length,
        a.before.length,
        reason: 'escribió el hito sin preguntar',
      );
    });
  });

  group('el store, que es quien lo escribe', () {
    Future<Store> fresh() async {
      SharedPreferences.setMockInitialValues({});
      final s = Store();
      await s.load();
      return s;
    }

    /// Pone piezas hasta que el pueblo pregunte, y devuelve la pregunta.
    Future<List<Landmark>> untilAsks(Store s) async {
      for (var n = 0; n < 4000; n++) {
        final q = s.pendingChoice;
        if (q != null) return q;
        s.placePiece();
      }
      throw StateError('nunca preguntó');
    }

    test('no pregunta nada al empezar un pueblo', () async {
      final s = await fresh();
      expect(s.pendingChoice, isNull);
    });

    test('contestar lo escribe y deja de preguntar', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      expect(q.length, 2);
      s.chooseWork(q.last.id);
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.last.id);
    });

    test('y el pueblo levanta lo que se eligió', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      s.chooseWork(q.last.id);
      final obra = s.plan.underway(s.total, s.habit.chronicle);
      expect(obra, isNotNull);
      expect(obra!.$1, q.last.name);
    });

    test('que decidan ellos escribe la primera', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      s.letThemDecide();
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.first.id);
    });

    test('contestar algo que no se preguntó no rompe nada', () async {
      // Nadie debería poder, pero un pueblo no se queda esperando por una
      // respuesta que no tiene sentido: se escribe la que habría salido sola.
      final s = await fresh();
      final q = await untilAsks(s);
      s.chooseWork('no-existe-esta-obra');
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.first.id);
    });

    test('lo elegido sobrevive a guardar y volver a cargar', () async {
      // Es lo único que hace que la elección signifique algo: si no se
      // guardara, mañana el pueblo estaría levantando la otra.
      SharedPreferences.setMockInitialValues({});
      final s = Store();
      await s.load();
      final q = await untilAsks(s);
      s.chooseWork(q.last.id);
      final piezas = s.total;

      final otra = Store();
      await otra.load();
      expect(otra.total, piezas);
      expect(otra.habit.chronicle.last, q.last.id);
      expect(
        otra.plan.underway(otra.total, otra.habit.chronicle)!.$1,
        q.last.name,
      );
    });
  });

  group('la hoja', () {
    /// La hoja, montada con dos obras cualquiera.
    Future<({List<String> picked, List<int> left})> pump(
      WidgetTester tester,
    ) async {
      final picked = <String>[];
      // Lista y no contador: un registro guarda el valor del momento en que se
      // arma, así que un `int` se quedaría en cero para siempre por mucho que
      // la hoja lo subiera después.
      final left = <int>[];
      await tester.binding.setSurfaceSize(const Size(393, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoiceSheet(
              options: [
                landmarks.firstWhere((l) => l.id == 'acueducto'),
                landmarks.firstWhere((l) => l.id == 'puente'),
              ],
              place: TownCharacter.all.first,
              theme: UiTheme(Palette.forMoment(11, 1.0)),
              onPick: (m) => picked.add(m.id),
              onLeave: () => left.add(1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (picked: picked, left: left);
    }

    testWidgets('no se puede confirmar sin haber elegido', (tester) async {
      // La hoja no llega con una respuesta ya puesta: las dos obras empiezan
      // iguales y el botón no hace nada hasta que se señala una.
      final r = await pump(tester);
      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(r.picked, isEmpty);
    });

    testWidgets('elegir una y confirmar la devuelve', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.text('Puente de piedra'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(r.picked, ['puente']);
    });

    testWidgets('«que decidan ellos» decide, no aplaza', (tester) async {
      // Si cerrar no escribiera nada, la crónica se quedaría un hueco corta
      // hasta la pieza siguiente, y en ese hueco una actualización del
      // catálogo podría cambiar la obra que está a punto de empezar.
      final r = await pump(tester);
      await tester.tap(find.text('Que decidan ellos'));
      await tester.pumpAndSettle();
      expect(r.picked, isEmpty);
      expect(r.left.length, 1);
    });

    testWidgets('las dos obras salen con su nombre y su precio', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Acueducto'), findsOneWidget);
      expect(find.text('Puente de piedra'), findsOneWidget);
      for (final id in ['acueducto', 'puente']) {
        final m = landmarks.firstWhere((l) => l.id == id);
        expect(find.text('${m.cost}'), findsWidgets, reason: id);
      }
    });
  });

  group('el retrato de la obra', () {
    test('la obra entra entera, y las ciento y pico', () {
      // El fallo que esto existe para cazar no se ve leyendo el código: la
      // cámara se fijaba sobre sus valores y no sobre sus objetivos, y
      // `snap()` los pisa, así que el retrato salía desde el sitio por defecto
      // y el castillo aparecía cortado por la mitad. Se ve mirándolo, o
      // midiéndolo — y mirar ciento y pico obras una a una no lo hace nadie.
      const size = Size(82, 82);
      final place = TownCharacter.all.first;
      final malas = <String>[];
      for (final mark in landmarks) {
        final layout = TownLayout.showcase(
          place,
          landmark: mark,
          placed: mark.cost,
        );
        final cam = WorkPortrait.frame(layout, size);
        final p = cam.projector(size.width, size.height, 0);
        var fuera = 0, vistos = 0;
        for (final pieza in layout.pieces) {
          for (final v in [
            V3(pieza.x0, pieza.y0, pieza.z0),
            V3(pieza.x1, pieza.y1, pieza.z1),
            V3(pieza.x0, pieza.y1, pieza.z1),
            V3(pieza.x1, pieza.y0, pieza.z0),
          ]) {
            final at = p.project(v);
            if (at == null) continue;
            vistos++;
            if (at.x < -1 ||
                at.y < -1 ||
                at.x > size.width + 1 ||
                at.y > size.height + 1) {
              fuera++;
            }
          }
        }
        if (vistos == 0 || fuera > 0) malas.add('${mark.name} ($fuera fuera)');
      }
      expect(malas, isEmpty, reason: malas.join(', '));
    });

    test('y no sale tan lejos que no se vea nada', () {
      // El otro extremo del mismo ajuste: encuadrar de sobra es fácil y deja
      // la obra del tamaño de una mosca en una miniatura de ochenta píxeles.
      const size = Size(82, 82);
      final place = TownCharacter.all.first;
      final chicas = <String>[];
      for (final mark in landmarks) {
        final layout = TownLayout.showcase(
          place,
          landmark: mark,
          placed: mark.cost,
        );
        final cam = WorkPortrait.frame(layout, size);
        final p = cam.projector(size.width, size.height, 0);
        // El lado mayor y no el ancho: una atalaya es alta y flaca, así que
        // ocupa poco a lo ancho por bien encuadrada que esté. Lo que se está
        // midiendo es si la obra llena el retrato, y una torre lo llena a lo
        // alto.
        var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
        for (final pieza in layout.pieces) {
          for (final v in [
            V3(pieza.x0, pieza.y0, pieza.z0),
            V3(pieza.x1, pieza.y1, pieza.z1),
            V3(pieza.x0, pieza.y1, pieza.z1),
            V3(pieza.x1, pieza.y0, pieza.z0),
          ]) {
            final at = p.project(v);
            if (at == null) continue;
            if (at.x < x0) x0 = at.x;
            if (at.x > x1) x1 = at.x;
            if (at.y < y0) y0 = at.y;
            if (at.y > y1) y1 = at.y;
          }
        }
        final lado = math.max(x1 - x0, y1 - y0);
        if (lado < size.width * 0.55) {
          chicas.add('${mark.name} (${lado.round()}px de 82)');
        }
      }
      expect(chicas, isEmpty, reason: chicas.join(', '));
    });
  });

  group('preguntar de verdad cambia el pueblo', () {
    test('dos respuestas distintas dan dos valles distintos', () {
      // Si elegir no cambiara nada, sería una pregunta de adorno.
      final iguales = _grow(600).chronicle;
      final otros = _grow(600, pick: (o) => o.last).chronicle;
      expect(otros, isNot(iguales));
    });

    test('pero se pregunta poco: es una decisión, no un trámite', () {
      // Una app de un solo botón no puede estar preguntando cada semana. Con
      // seiscientas piezas —más de un año a una diaria— son un puñado.
      final asks = _grow(600).asks;
      expect(asks.length, inInclusiveRange(4, 12), reason: '${asks.length}');
    });
  });
}
