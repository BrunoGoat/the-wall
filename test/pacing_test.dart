import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/milestones.dart';
import 'package:la_muralla/data/pacing.dart';

void main() {
  group('milestone pacing', () {
    test('the first landmark starts inside the first two weeks', () {
      expect(Pacing.milestoneStart(0), 12);
    });

    test('the first landmark also finishes inside the first month', () {
      final first = MilestoneCatalog.typeFor(0);
      expect(Pacing.milestoneStart(0) + first.brickCost, lessThanOrEqualTo(60));
    });

    test('landmarks never overlap each other', () {
      for (var n = 0; n < 40; n++) {
        final start = Pacing.milestoneStart(n);
        final end = start + MilestoneCatalog.typeFor(n).brickCost;
        expect(end, lessThan(Pacing.milestoneStart(n + 1)),
            reason: 'landmark $n runs into the next one');
      }
    });

    test('a year of ordinary use meets several different landmarks', () {
      for (final year in [365, 1100]) {
        final kinds = <MilestoneKind>{};
        for (var n = 0; n < 40; n++) {
          if (Pacing.milestoneStart(n) + MilestoneCatalog.typeFor(n).brickCost <=
              year) {
            kinds.add(MilestoneCatalog.typeFor(n).kind);
          }
        }
        expect(kinds.length, greaterThanOrEqualTo(4),
            reason: 'at $year bricks the landmarks must be varied');
      }
    });

    test('two landmarks in a row are never the same shape', () {
      for (var n = 0; n < 40; n++) {
        expect(MilestoneCatalog.typeFor(n).kind,
            isNot(MilestoneCatalog.typeFor(n + 1).kind));
      }
    });

    test('a returning landmark takes a fresh name', () {
      final a = MilestoneCatalog.typeFor(0);
      final b = MilestoneCatalog.typeFor(MilestoneCatalog.order.length);
      expect(a.kind, b.kind);
      expect(a.name, isNot(b.name));
    });
  });

  group('decay', () {
    test('a day off costs nothing', () {
      expect(Pacing.integrityFor(0), 1.0);
      expect(Pacing.integrityFor(1.0), 1.0);
    });

    test('neglect shows up gradually, not all at once', () {
      final threeDays = Pacing.integrityFor(3);
      final week = Pacing.integrityFor(7);
      expect(threeDays, lessThan(1.0));
      expect(week, lessThan(threeDays));
    });

    test('the wall weathers but never disappears', () {
      expect(Pacing.integrityFor(3650), Pacing.minIntegrity);
      expect(Pacing.minIntegrity, greaterThan(0.0));
    });
  });

  group('the plan', () {
    test('every brick maps to exactly one segment, in order', () {
      final plan = WallPlan(600);
      var cursor = 0;
      for (final s in plan.segments) {
        expect(s.firstBrick, cursor, reason: 'segments must be contiguous');
        expect(s.length, greaterThan(0));
        cursor += s.length;
      }
      expect(cursor, greaterThan(600));
    });

    test('reports the landmark under construction', () {
      final plan = WallPlan(60);
      expect(plan.activeMilestone(20)?.milestoneNo, 0);
      expect(plan.activeMilestone(40), isNull);
    });
  });
}
