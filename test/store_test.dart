import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/pacing.dart';
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
      final id = s.activeHabits.first.id;
      expect(s.total, 0);
      s.placeBrick(id);
      expect(s.total, 1);
      s.placeBrick(id);
      s.placeBrick(id);
      expect(s.total, 3);
    });

    test('bricks are numbered in the order they were earned', () async {
      final s = await freshStore();
      final a = s.activeHabits[0].id;
      final b = s.activeHabits[1].id;
      s.placeBrick(a);
      s.placeBrick(b);
      s.placeBrick(a);
      expect(s.bricks.map((x) => x.index), [0, 1, 2]);
      expect(s.bricks.map((x) => x.habitId), [a, b, a]);
    });

    test('a brick records which habit earned it and when', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      final before = DateTime.now();
      final r = s.placeBrick(id);
      expect(r.brick.habitId, id);
      expect(r.brick.placedAt.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('landmarks and epics report themselves', () {
    test('finishing a landmark is announced exactly once', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      final first = s.plan.segments.firstWhere((x) => x.isMilestone);
      var completions = 0;
      var starts = 0;
      for (var i = 0; i < first.firstBrick + first.length + 5; i++) {
        final r = s.placeBrick(id);
        if (r.milestoneCompleted != null) completions++;
        if (r.milestoneStarted != null) starts++;
      }
      expect(starts, 1);
      expect(completions, 1);
    });

    test('epics are seeded but never revealed by placing', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      var seeded = 0;
      for (var i = 0; i < 60; i++) {
        if (s.placeBrick(id).epicSeeded != null) seeded++;
      }
      expect(seeded, Pacing.epicsHiddenBy(60));
      expect(s.discoveries, isEmpty,
          reason: 'an epic must be found, not handed over');
      expect(s.hiddenRemaining, seeded);
    });

    test('an epic can only be discovered once', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      for (var i = 0; i < 30; i++) {
        s.placeBrick(id);
      }
      final n = s.seededEpics.first;
      expect(s.discover(n), isNotNull);
      expect(s.discover(n), isNull);
      expect(s.discoveries.length, 1);
      expect(s.isFound(n), isTrue);
    });
  });

  group('decay and repair', () {
    test('a fresh wall is intact', () async {
      final s = await freshStore();
      s.placeBrick(s.activeHabits.first.id);
      expect(s.integrity, 1.0);
      expect(s.isDecaying, isFalse);
    });

    test('time away wears the wall down, one brick brings it back', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      s.debugFill(20, endedDaysAgo: 9);
      expect(s.integrity, lessThan(0.6));
      expect(s.isDecaying, isTrue);

      final r = s.placeBrick(id);
      expect(r.repaired, isTrue);
      expect(r.repairedFrom, lessThan(0.6));
      expect(s.integrity, 1.0);
    });

    test('an empty wall cannot decay', () async {
      final s = await freshStore();
      expect(s.integrity, 1.0);
    });
  });

  group('habits', () {
    test('archiving a habit keeps every brick it earned', () async {
      final s = await freshStore();
      final h = s.activeHabits.first;
      for (var i = 0; i < 5; i++) {
        s.placeBrick(h.id);
      }
      s.archiveHabit(h);
      expect(s.total, 5, reason: 'nothing built is ever taken away');
      expect(s.activeHabits.any((x) => x.id == h.id), isFalse);
      expect(s.habitById(h.id), isNotNull);
    });

    test("today's count is per habit", () async {
      final s = await freshStore();
      final a = s.activeHabits[0].id;
      final b = s.activeHabits[1].id;
      s.placeBrick(a);
      s.placeBrick(a);
      s.placeBrick(b);
      expect(s.todayCount(a), 2);
      expect(s.todayCount(b), 1);
      expect(s.todayTotal, 3);
    });
  });

  group('persistence', () {
    test('the wall survives a restart exactly as it was', () async {
      SharedPreferences.setMockInitialValues({});
      final a = WallStore();
      await a.load();
      final id = a.activeHabits.first.id;
      for (var i = 0; i < 14; i++) {
        a.placeBrick(id);
      }
      a.discover(a.seededEpics.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final b = WallStore();
      await b.load();
      expect(b.total, a.total);
      expect(b.discoveries.length, a.discoveries.length);
      expect(b.habits.length, a.habits.length);
      expect(b.bricks.first.habitId, a.bricks.first.habitId);
    });

    test('a corrupt save starts clean instead of failing', () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.la_muralla_state_v1': 'not json at all'});
      final s = WallStore();
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.activeHabits, isNotEmpty);
    });
  });

  group('streaks', () {
    test('consecutive days count, gaps break the run', () async {
      final s = await freshStore();
      final id = s.activeHabits.first.id;
      final today = dayStart(DateTime.now());
      for (final offset in [0, 1, 2, 5, 6]) {
        s.bricks.add(Brick(
          index: s.total,
          habitId: id,
          placedAt: today.subtract(Duration(days: offset, hours: -12)),
        ));
      }
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });
  });
}
