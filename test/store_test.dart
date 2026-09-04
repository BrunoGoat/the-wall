import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/models.dart';
import 'package:la_muralla/model/wall_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<WallStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = WallStore();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('one brick is one achievement', () {
    test('placing adds exactly one brick, never a batch', () async {
      final s = await freshStore();
      expect(s.total, 0);
      s.placeBrick();
      expect(s.total, 1);
      s.placeBrick();
      s.placeBrick();
      expect(s.total, 3);
    });

    test('bricks are numbered in the order they were earned', () async {
      final s = await freshStore();
      s.placeBrick();
      s.placeBrick();
      s.placeBrick();
      expect(s.bricks.map((x) => x.index), [0, 1, 2]);
    });

    test('a brick starts with no note at all', () async {
      final s = await freshStore();
      final r = s.placeBrick();
      expect(r.brick.hasLabel, isFalse);
      expect(r.brick.label, isNull);
    });
  });

  group('landmarks report themselves', () {
    test('finishing a landmark is announced exactly once', () async {
      final s = await freshStore();
      final first = s.plan.segments.firstWhere((x) => x.isMilestone);
      var completions = 0;
      var starts = 0;
      for (var i = 0; i < first.firstBrick + first.length + 5; i++) {
        final r = s.placeBrick();
        if (r.milestoneCompleted != null) completions++;
        if (r.milestoneStarted != null) starts++;
      }
      expect(starts, 1);
      expect(completions, 1);
    });
  });

  group('notes on a stone', () {
    test('a note is optional and can be written later', () async {
      final s = await freshStore();
      s.placeBrick();
      s.placeBrick();
      expect(s.labelled, isEmpty);

      s.setLabel(0, 'Leí');
      expect(s.brickAt(0)!.label, 'Leí');
      expect(s.brickAt(1)!.hasLabel, isFalse);
      expect(s.labelled.map((b) => b.index), [0]);
    });

    test('a note can be rewritten and cleared', () async {
      final s = await freshStore();
      s.placeBrick();
      s.setLabel(0, 'Corrí');
      s.setLabel(0, 'Corrí 10k');
      expect(s.brickAt(0)!.label, 'Corrí 10k');
      s.setLabel(0, '   ');
      expect(s.brickAt(0)!.hasLabel, isFalse,
          reason: 'blank should clear the note, not store whitespace');
    });

    test('writing a note never changes what the wall is', () async {
      final s = await freshStore();
      for (var i = 0; i < 5; i++) {
        s.placeBrick();
      }
      final before = s.total;
      s.setLabel(2, 'Algo');
      expect(s.total, before);
    });

    test('the newest note comes first in the log', () async {
      final s = await freshStore();
      for (var i = 0; i < 4; i++) {
        s.placeBrick();
      }
      s.setLabel(0, 'uno');
      s.setLabel(3, 'cuatro');
      expect(s.labelled.map((b) => b.index), [3, 0]);
    });
  });

  group('decay and repair', () {
    test('a fresh wall is intact', () async {
      final s = await freshStore();
      s.placeBrick();
      expect(s.integrity, 1.0);
      expect(s.isDecaying, isFalse);
    });

    test('time away wears the wall down, one brick brings it back', () async {
      final s = await freshStore();
      s.debugFill(20, endedDaysAgo: 9);
      expect(s.integrity, lessThan(0.6));
      expect(s.isDecaying, isTrue);

      final r = s.placeBrick();
      expect(r.repaired, isTrue);
      expect(r.repairedFrom, lessThan(0.6));
      expect(s.integrity, 1.0);
    });

    test('an empty wall cannot decay', () async {
      final s = await freshStore();
      expect(s.integrity, 1.0);
    });
  });

  group('persistence', () {
    test('the wall survives a restart exactly as it was', () async {
      SharedPreferences.setMockInitialValues({});
      final a = WallStore();
      await a.load();
      for (var i = 0; i < 14; i++) {
        a.placeBrick();
      }
      a.setLabel(3, 'Leí');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final b = WallStore();
      await b.load();
      expect(b.total, a.total);
      expect(b.brickAt(3)!.label, 'Leí');
      expect(b.labelled.length, 1);
    });

    test('a corrupt save starts clean instead of failing', () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.la_muralla_state_v2': 'not json at all'});
      final s = WallStore();
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.total, 0);
    });
  });

  group('streaks', () {
    test('consecutive days count, gaps break the run', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [0, 1, 2, 5, 6]) {
        s.bricks.add(Brick(
          index: s.total,
          placedAt: today.subtract(Duration(days: offset, hours: -12)),
        ));
      }
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });
  });
}
