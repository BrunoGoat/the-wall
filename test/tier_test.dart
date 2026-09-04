import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/milestones.dart';
import 'package:la_muralla/engine/layout.dart';
import 'package:la_muralla/engine/structures.dart';
import 'package:la_muralla/model/wall_store.dart';

double peakOf(WallLayout l) {
  var m = 0.0;
  for (final s in l.slots) {
    if (s.top > m) m = s.top;
  }
  return m;
}

void main() {
  group('levelling up', () {
    test('a tier opens exactly at its threshold', () {
      expect(WallTiers.tierAt(0), 0);
      expect(WallTiers.tierAt(99), 0);
      expect(WallTiers.tierAt(100), 1);
      expect(WallTiers.tierAt(349), 1);
      expect(WallTiers.tierAt(350), 2);
      expect(WallTiers.tierAt(1000000), WallTiers.maxTier);
    });

    test('every course belongs to the tier that opened it', () {
      for (var t = 0; t <= WallTiers.maxTier; t++) {
        for (var c = WallTiers.firstCourseOf(t);
            c <= WallTiers.topCourseOf(t);
            c++) {
          expect(WallTiers.tierOfCourse(c), t, reason: 'course $c');
        }
      }
      expect(WallTiers.topCourseOf(WallTiers.maxTier),
          WallDims.totalCourses - 1);
    });

    test('a levelling course rests on the capstone of the tier below', () {
      for (var t = 1; t <= WallTiers.maxTier; t++) {
        final lev = WallTiers.levellingOf(t);
        expect(WallTiers.supportOf(lev), WallTiers.capstoneOf(t - 1));
      }
      expect(WallTiers.supportOf(0), -1);
    });

    test('levelling up never moves a stone on the rampart', () {
      final before = WallLayout(99);
      final after = WallLayout(600);
      var checked = 0;
      for (var i = 0; i < 99; i++) {
        final a = before.slots[i], b = after.slots[i];
        // Landmarks are the exception, and deliberately so: they are rebuilt
        // to the wall's new height out of exactly the same stones.
        if (a.structureIndex >= 0) continue;
        expect(b.x, a.x, reason: 'stone $i moved along the wall');
        expect(b.y, a.y, reason: 'stone $i moved up or down');
        expect(b.w, a.w);
        expect(b.h, a.h);
        checked++;
      }
      expect(checked, greaterThan(25));
    });

    test('a landmark keeps its stones and its stretch when the wall grows', () {
      final before = WallLayout(99);
      final after = WallLayout(600);
      final a = before.structures.first;
      final b = after.structures.first;
      expect(b.type.kind, a.type.kind);
      expect(b.firstBrick, a.firstBrick);
      expect(b.brickCount, a.brickCount, reason: 'a landmark changed its cost');
      expect(b.x0, closeTo(a.x0, 1e-9), reason: 'a landmark slid along the wall');
      expect(b.peakY, greaterThan(a.peakY),
          reason: 'a landmark should rise with the wall it stands on');
    });

    test('the wall gets taller, not just longer', () {
      final small = peakOf(WallLayout(90));
      final big = peakOf(WallLayout(600));
      expect(big, greaterThan(small * 1.4),
          reason: 'a levelled wall should stand clearly higher');
      expect(WallDims.crownOf(1), greaterThan(WallDims.crownOf(0)));
    });

    test('old crenellation gaps are blocked once built over', () {
      expect(WallLayout(90).buried, isEmpty,
          reason: 'nothing has been built over yet');
      final l = WallLayout(600);
      expect(l.buried, isNotEmpty);
      for (final b in l.buried) {
        expect(b.y1, greaterThan(b.y0));
        expect(b.x1, greaterThan(b.x0));
        expect(b.halfDepth, greaterThan(0));
      }
    });

    test('the tier is named for the wall you actually have', () {
      expect(WallStore.tierNameFor(0), 'I');
      expect(WallStore.tierNameFor(100), 'I');
      expect(WallStore.tierNameFor(101), 'II');
      expect(WallStore.bricksToNextTier(0), 100);
      expect(WallStore.bricksToNextTier(99), 1);
      expect(WallStore.bricksToNextTier(100000), isNull);
    });
  });

  group('the landmarks', () {
    test('there are thirty of them, and the rota uses every one', () {
      expect(MilestoneKind.values.length, 30);
      expect(MilestoneCatalog.order.toSet().length, 30);
    });

    test('every one builds a real mass at every tier', () {
      for (var t = 0; t <= WallTiers.maxTier; t++) {
        final top = WallDims.walkTopOf(t);
        for (final kind in MilestoneKind.values) {
          final spec = StructureShapes(top).build(kind, 7.5);
          expect(spec.length, greaterThan(1.0), reason: '$kind at tier $t');
          expect(spec.slabs.length, greaterThanOrEqualTo(3),
              reason: '$kind is too plain to be a landmark');
          var highest = 0.0;
          for (final s in spec.slabs) {
            expect(s.x1, greaterThan(s.x0), reason: '$kind has an empty slab');
            expect(s.y1, greaterThan(s.y0), reason: '$kind has a flat slab');
            if (s.y1 > highest) highest = s.y1;
            for (var i = 0; i <= 12; i++) {
              final x = s.x0 + (s.x1 - s.x0) * i / 12;
              expect(s.halfDepth(x), greaterThan(0.0),
                  reason: '$kind has a slab with no thickness');
            }
          }
          expect(highest, greaterThan(top),
              reason: '$kind never rises above the walkway at tier $t');
        }
      }
    });

    test('each landmark keeps to its own stretch of wall', () {
      for (final kind in MilestoneKind.values) {
        final spec = StructureShapes(WallDims.walkTop).build(kind, 0);
        for (final s in spec.slabs) {
          expect(s.x0, greaterThanOrEqualTo(-0.9), reason: '$kind spills left');
          expect(s.x1, lessThanOrEqualTo(spec.length + 0.9),
              reason: '$kind spills right');
        }
        expect(spec.featureX, inInclusiveRange(0, spec.length));
      }
    });

    test('a landmark always stands at least as tall as the wall it is in', () {
      // A landmark that cannot afford its own parapet reads as a hole in the
      // wall rather than a monument in it, which is worse than no landmark.
      for (final n in [200, 600, 1000]) {
        final l = WallLayout(n);
        var rampart = 0.0;
        for (final s in l.slots) {
          if (s.structureIndex < 0 && s.top > rampart) rampart = s.top;
        }
        for (final st in l.structures) {
          expect(st.peakY, greaterThan(rampart - 0.1),
              reason: '${st.type.name} sank into the wall at $n bricks');
        }
      }
    });

    test('a long wall meets many different landmarks, built of real stones',
        () {
      final l = WallLayout(2400);
      final kinds = l.structures.map((s) => s.type.kind).toSet();
      expect(kinds.length, greaterThanOrEqualTo(8));
      for (final s in l.slots) {
        expect(s.w, greaterThan(0.02));
        expect(s.h, greaterThan(0.02));
        expect(s.halfDepth, greaterThan(0.01));
      }
    });
  });
}
