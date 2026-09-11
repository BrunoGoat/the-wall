import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';

final _now = DateTime(2026, 3, 1, 20, 0);

Habit _habit(String name, Iterable<DateTime> when) {
  final list = when.toList()..sort();
  return Habit(
    id: name,
    name: name,
    symbol: 'libro',
    slot: 0,
    createdAt: list.isEmpty ? _now : list.first,
    pieces: [
      for (var i = 0; i < list.length; i++) Piece(index: i, placedAt: list[i]),
    ],
  );
}

/// Every day of the last [days] days, at [hour].
Habit _daily(String name, int days, {int hour = 8, int minute = 0}) =>
    _habit(name, [
      for (var i = 0; i < days; i++)
        DateTime(_now.year, _now.month, _now.day - i, hour, minute),
    ]);

void main() {
  group('the board says nothing it cannot back up', () {
    // The rule the whole thing stands on. A town that tells you something
    // about yourself on four days of evidence is a town that will tell you
    // anything, and then none of it is worth reading.
    test('a habit with almost no history is left alone', () {
      for (final n in [0, 1, 3, 8]) {
        final said = noticesFor(_daily('Leer', n), at: _now);
        expect(said, isEmpty, reason: '$n días ya decían algo');
      }
    });

    test('every notice carries the counts it came from', () {
      final said = noticesFor(
        _daily('Leer', 200),
        others: [_daily('Correr', 200, hour: 19)],
        underway: 'la Catedral',
        left: 12,
        at: _now,
      );
      expect(said, isNotEmpty);
      for (final n in said) {
        expect(n.said.trim(), isNotEmpty);
        expect(n.because.trim(), isNotEmpty);
        expect(n.said.endsWith('.'), isTrue, reason: n.said);
        expect(n.because.endsWith('.'), isTrue, reason: n.because);
      }
    });
  });

  group('the hour of the day', () {
    test('a habit kept at one hour is told that hour, not a band', () {
      final said = peakHour(_daily('Leer', 90, hour: 8, minute: 10));
      expect(said, isNotNull);
      expect(said!.said, contains('a las 8'));
      expect(said.said, contains('mañana'));
    });

    test('a habit spread over a morning is told the whole stretch', () {
      final when = <DateTime>[];
      for (var i = 0; i < 90; i++) {
        when.add(DateTime(_now.year, _now.month, _now.day - i, 7 + i % 3, 30));
      }
      final said = peakHour(_habit('Leer', when));
      expect(said, isNotNull);
      expect(said!.said, contains('entre las 7 y las 10'));
    });

    test('a habit with no hour of its own says nothing about hours', () {
      final when = <DateTime>[];
      for (var i = 0; i < 120; i++) {
        when.add(DateTime(_now.year, _now.month, _now.day - i, i % 24, 0));
      }
      expect(peakHour(_habit('Leer', when)), isNull);
    });
  });

  group('the day of the week', () {
    test('a weekday never kept is named, against the rest of the week', () {
      final when = <DateTime>[];
      for (var i = 0; i < 120; i++) {
        final d = DateTime(_now.year, _now.month, _now.day - i, 9);
        if (d.weekday == DateTime.sunday) continue;
        when.add(d);
      }
      final said = standoutDay(_habit('Leer', when), _now);
      expect(said, isNotNull);
      expect(said!.said, contains('domingos'));
      expect(said.because, contains('0%'));
    });

    test('a habit kept every day has no day that stands out', () {
      expect(standoutDay(_daily('Leer', 120), _now), isNull);
    });
  });

  group('what one blank day costs', () {
    test('misses that come in runs are reported as such', () {
      // Three weeks on, four days off, over and over: after a blank day the
      // next one is blank three times out of four, against one in four
      // overall.
      final when = <DateTime>[];
      for (var i = 0; i < 200; i++) {
        if (i % 25 >= 21) continue;
        when.add(DateTime(_now.year, _now.month, _now.day - i, 9));
      }
      final said = relapse(_habit('Leer', when), _now);
      expect(said, isNotNull);
      expect(said!.said, contains('se lleva al siguiente'));
    });

    test('a miss that never repeats is reported the other way round', () {
      // One day off in every four, always alone. After a blank day the next
      // one is never blank, and saying so is as true and as useful as the
      // opposite — and much rarer to hear.
      final when = <DateTime>[];
      for (var i = 0; i < 200; i++) {
        if (i % 4 == 0) continue;
        when.add(DateTime(_now.year, _now.month, _now.day - i, 9));
      }
      final said = relapse(_habit('Leer', when), _now);
      expect(said, isNotNull);
      expect(said!.said, contains('no te tumba'));
    });

    test('too few blank days to tell says nothing', () {
      final when = <DateTime>[];
      for (var i = 0; i < 60; i++) {
        if (i == 10 || i == 30) continue;
        when.add(DateTime(_now.year, _now.month, _now.day - i, 9));
      }
      expect(relapse(_habit('Leer', when), _now), isNull);
    });
  });

  group('coming back', () {
    test('the usual gap and the worst one ever climbed out of', () {
      // A two-day gap every fortnight, and one gap of nine days.
      final when = <DateTime>[];
      for (var i = 0; i < 150; i++) {
        if (i % 14 >= 12) continue;
        if (i >= 40 && i < 49) continue;
        when.add(DateTime(_now.year, _now.month, _now.day - i, 9));
      }
      final said = comeback(_habit('Leer', when));
      expect(said, isNotNull);
      expect(said!.said, contains('a los 2 días'));
      expect(said.because, contains('9 días'));
    });
  });

  group('two habits at once', () {
    test('habits kept on the same days are named as a pair', () {
      // Three days on, two off, and reading nearly always rides along with
      // running. A habit kept every single day could not be paired with
      // anything: with no day without it there is nothing to compare against.
      final run = <DateTime>[], read = <DateTime>[];
      for (var i = 0; i < 150; i++) {
        final d = DateTime(_now.year, _now.month, _now.day - i, 9);
        if (i % 5 < 3) {
          run.add(d);
          if (i % 10 != 0) read.add(d);
        } else if (i % 7 == 0) {
          read.add(d);
        }
      }
      final said = pairing(_habit('Correr', run), [_habit('Leer', read)], _now);
      expect(said, isNotNull);
      expect(said!.said, contains('Correr arrastra a Leer'));
      expect(said.because, contains('%'));
    });

    test('a habit kept every single day cannot be paired with anything', () {
      final said = pairing(_daily('Correr', 150), [
        _daily('Leer', 150, hour: 22),
      ], _now);
      expect(said, isNull);
    });

    test('habits that never share a day are named as that', () {
      final odd = <DateTime>[], even = <DateTime>[];
      for (var i = 0; i < 150; i++) {
        final d = DateTime(_now.year, _now.month, _now.day - i, 9);
        (i.isEven ? even : odd).add(d);
      }
      final said = pairing(_habit('Correr', even), [_habit('Leer', odd)], _now);
      expect(said, isNotNull);
      expect(said!.said, contains('casi nunca el mismo día'));
    });

    test('one habit on its own is never paired with anything', () {
      expect(pairing(_daily('Leer', 200), const [], _now), isNull);
    });
  });

  group('the crown of the valley', () {
    test('whoever has laid the most wears it, and the rest are told by how '
        'much', () {
      final big = _daily('Leer', 120);
      final small = _daily('Correr', 90, hour: 19);
      final mine = crownOf(big, [big, small]);
      expect(mine, isNotNull);
      expect(mine!.said, contains('Leer lleva la corona'));
      expect(mine.because, contains('30 más que Correr'));

      final theirs = crownOf(small, [big, small]);
      expect(theirs, isNotNull);
      expect(theirs!.said, contains('La corona la tiene Leer'));
      expect(theirs.because, contains('30'));
      // Both notices carry the same bars: the valley seen from either town.
      expect(mine.bars.length, 2);
      expect(theirs.bars.length, 2);
      expect(theirs.bars.first, 1.0);
    });

    test('one town is not a valley', () {
      final only = _daily('Leer', 90);
      expect(crownOf(only, [only]), isNull);
    });

    test('a town nobody has begun is not in the running', () {
      final live = _daily('Leer', 90);
      final empty = _habit('Correr', const []);
      expect(crownOf(live, [live, empty]), isNull);
    });
  });

  group('every notice can show its work', () {
    // The board lets you take a notice down and look at it up close, and what
    // it shows there is the evidence the sentence was read off. A notice with
    // a chart whose labels do not line up with its bars would be worse than
    // no chart at all.
    test('the bars and their labels agree, and the mark is inside them', () {
      final said = noticesFor(
        _daily('Leer', 300),
        others: [_daily('Correr', 300, hour: 19)],
        underway: 'la Catedral',
        left: 9,
        at: _now,
      );
      expect(said, isNotEmpty);
      for (final n in said) {
        if (n.bars.isEmpty) continue;
        expect(
          n.ticks.isEmpty || n.ticks.length == n.bars.length,
          isTrue,
          reason: '${n.kind}: ${n.bars.length} barras, ${n.ticks.length} pies',
        );
        for (final b in n.bars) {
          expect(b, inInclusiveRange(0.0, 1.0), reason: '${n.kind}');
        }
        if (n.mark >= 0) {
          expect(
            n.mark + n.span,
            lessThanOrEqualTo(n.bars.length),
            reason: '${n.kind}',
          );
        }
      }
    });
  });

  group('lo que escribís una y otra vez', () {
    Habit conLeyendas(Map<String, int> cuantas) {
      final piezas = <Piece>[];
      var i = 0;
      cuantas.forEach((texto, n) {
        for (var k = 0; k < n; k++) {
          piezas.add(
            Piece(
              index: i,
              placedAt: _now.subtract(Duration(days: i ~/ 2, hours: i % 5)),
              label: texto,
            ),
          );
          i++;
        }
      });
      return Habit(
        id: 'h',
        name: 'Higiene',
        symbol: 'libro',
        slot: 0,
        createdAt: _now.subtract(const Duration(days: 200)),
        pieces: piezas,
      );
    }

    test('junta las leyendas por lo que tienen en común', () {
      // El encargo, con sus números: un hábito de higiene con las mismas tres
      // cosas escritas de tres maneras. Lo que hay que decir no es que hay
      // tres leyendas distintas, es que hay una sola cosa hecha de tres
      // maneras — y cuántas veces cada una.
      final dice = chore(
        conLeyendas({
          'Lavarse los dientes al despertar': 60,
          'Lavarse los dientes después de comer': 50,
          'Lavarse los dientes por la noche': 30,
        }),
      );
      expect(dice, isNotNull);
      expect(dice!.said, contains('Lavarse los dientes'));
      expect(dice.said, contains('140'));
      // Y el reparto, que es lo que no se ve leyendo las leyendas una por una.
      expect(dice.because, contains('tres maneras'));
      expect(dice.because, contains('al despertar (60)'));
      expect(dice.because, contains('después de comer (50)'));
      expect(dice.because, contains('por la noche (30)'));
      expect(dice.bars.length, 3);
      expect(dice.ticks.length, 3);
    });

    test('el trozo común no empieza ni acaba en relleno', () {
      // «corrí por la mañana» y «corrí por la tarde» daban «corrí por la»,
      // que abarca exactamente lo mismo que «corrí» y se lee como una frase
      // cortada por la mitad.
      final dice = chore(
        conLeyendas({
          'Corrí por la mañana': 20,
          'Corrí por la tarde': 18,
          'Fui al gimnasio': 12,
        }),
      );
      expect(dice, isNotNull);
      expect(dice!.said, contains('«Corrí»'));
      expect(dice.because, contains('por la mañana (20)'));
    });

    test('una sola cosa repetida se dice como lo que es', () {
      final dice = chore(
        conLeyendas({'Leí': 80, 'Leí en el tren': 3, 'Nada': 2}),
      );
      expect(dice, isNotNull);
      expect(dice!.said, contains('«Leí»'));
      expect(dice.said, contains('80'));
    });

    test('y donde no hay costumbre no se inventa una', () {
      // Veinte leyendas distintas que se parecen no son una costumbre: son
      // veinte leyendas distintas. Sin esto salía «de veinte maneras», con
      // veinte barras de una pieza cada una.
      expect(
        chore(
          conLeyendas({
            for (var i = 0; i < 20; i++) 'cosa distinta número $i': 1,
          }),
        ),
        isNull,
      );
      // Y con poco escrito tampoco: dos leyendas repetidas cuatro veces no
      // dicen nada de nadie.
      expect(chore(conLeyendas({'Corrí': 4, 'Corrí lento': 3})), isNull);
      // Ni sin leyendas ningunas.
      expect(chore(_daily('Leer', 90)), isNull);
    });
  });

  group('what the town will have finished', () {
    test('a rate becomes a date', () {
      final said = ahead(_daily('Leer', 90), 'la Catedral', 20, _now);
      expect(said, isNotNull);
      expect(said!.said, contains('la Catedral'));
      expect(said.because, contains('20 piezas'));
    });

    test('nothing is promised at a pace that would take years', () {
      final when = <DateTime>[
        for (var i = 0; i < 60; i += 3)
          DateTime(_now.year, _now.month, _now.day - i, 9),
      ];
      expect(ahead(_habit('Leer', when), 'la Catedral', 900, _now), isNull);
    });

    test('a town with nothing under way promises nothing', () {
      expect(ahead(_daily('Leer', 90), null, 0, _now), isNull);
    });

    test('el ritmo se mide desde que hay pueblo, no sobre treinta días', () {
      // El caso que se vio en el teléfono. Nueve piezas repartidas en cuatro
      // días, tres para acabar la casa. Dividiendo entre treinta salían a 0,3
      // al día y la casa quedaba en pie dentro de diez; el ritmo de verdad es
      // 2,25 al día y son dos.
      final cuando = <DateTime>[
        for (final (atras, cuantas) in [(3, 2), (2, 2), (1, 3), (0, 2)])
          for (var k = 0; k < cuantas; k++)
            DateTime(_now.year, _now.month, _now.day - atras, 8 + k),
      ];
      final dice = ahead(_habit('Casa', cuando), 'Casa', 3, _now);
      expect(dice, isNotNull);
      expect(
        dice!.because,
        contains('9 en 4 días'),
        reason: 'sigue repartiendo las piezas entre días que no existieron',
      );
      // Dos días, no diez.
      expect(dice.said, contains('${_now.day + 2} de'));
    });

    test('y las barras son esos mismos días, uno cada una', () {
      // Con doce semanas en un pueblo de cuatro días, once salían vacías y la
      // que quedaba se llevaba las nueve piezas: el dibujo decía «todo de una
      // vez» cuando habían sido cuatro días seguidos.
      final cuando = <DateTime>[
        for (final (atras, cuantas) in [(3, 2), (2, 2), (1, 3), (0, 2)])
          for (var k = 0; k < cuantas; k++)
            DateTime(_now.year, _now.month, _now.day - atras, 8 + k),
      ];
      final dice = ahead(_habit('Casa', cuando), 'Casa', 3, _now)!;
      expect(dice.bars.length, 4);
      for (final b in dice.bars) {
        expect(b, greaterThan(0), reason: 'un día del hábito salió vacío');
      }
      expect(dice.mark, 3, reason: 'la marca no está en hoy');

      // Y en un pueblo con historia siguen siendo semanas: doce barras de un
      // día para medio año no dicen nada.
      final viejo = ahead(_daily('Leer', 120), 'la Catedral', 20, _now)!;
      expect(viejo.bars.length, 12);
      expect(viejo.because, contains('en 30 días'));
    });

    test('una tarde entera de golpe no promete el pueblo para mañana', () {
      // Ocho piezas el mismo día son ocho piezas ese día, no ocho al día. Sin
      // suelo, la ventana valía uno y el ritmo salía disparado.
      final dice = ahead(
        _habit('Casa', [
          for (var k = 0; k < 8; k++)
            DateTime(_now.year, _now.month, _now.day, 9 + k),
        ]),
        'Casa',
        6,
        _now,
      );
      expect(dice, isNotNull);
      expect(dice!.said, isNot(contains('mañana')));
      // Y dice los días que hubo, no los tres del reparto: el reparto es para
      // que la cuenta no se dispare, no para inventar dos días.
      expect(dice.because, contains('8 en un día'));
    });
  });
}
