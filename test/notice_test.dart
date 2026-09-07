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

Notice? _of(List<Notice> all, NoticeKind kind) {
  for (final n in all) {
    if (n.kind == kind) return n;
  }
  return null;
}

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
  });
}
