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

    test('a landmark is not touched again once it is built', () {
      // A landmark belongs to the day it was begun: same shape, same stones,
      // same stretch of ground, however tall the wall around it later becomes.
      // The wall closes over the top of it instead of it being rebuilt.
      final before = WallLayout(99);
      final after = WallLayout(1400);
      final a = before.structures.first;
      final b = after.structures.first;
      expect(b.type.kind, a.type.kind);
      expect(b.firstBrick, a.firstBrick);
      expect(b.brickCount, a.brickCount, reason: 'a landmark changed its cost');
      expect(b.x0, closeTo(a.x0, 1e-9), reason: 'a landmark slid along the wall');
      expect(b.peakY, closeTo(a.peakY, 1e-9),
          reason: 'a landmark was rebuilt under the wall that grew past it');
      for (var i = 0; i < a.brickCount; i++) {
        final p = before.slots[a.firstBrick + i];
        final q = after.slots[a.firstBrick + i];
        expect(q.x, closeTo(p.x, 1e-9));
        expect(q.y, closeTo(p.y, 1e-9));
      }
    });

    test('the wall gets taller, not just longer', () {
      // Measured on the rampart, not on the tallest tower: a watchtower on a
      // ninety-brick wall is already tall, and that says nothing about whether
      // the wall itself has grown.
      double rampart(WallLayout l) {
        var top = 0.0;
        for (final s in l.slots) {
          if (s.structureIndex < 0 && s.top > top) top = s.top;
        }
        return top;
      }

      final small = rampart(WallLayout(90));
      final big = rampart(WallLayout(600));
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

    test('a landmark stands above the wall of its own day', () {
      // Each landmark is built to the wall as it stood when it was begun. It
      // must clear *that* wall — a landmark that cannot even reach the parapet
      // it was built against reads as a hole rather than a monument. The wall
      // may later be heightened past it, and then it sits low, the way the
      // oldest stretch of a real wall does.
      for (final n in [200, 600, 1200, 3000]) {
        final l = WallLayout(n);
        for (final st in l.structures) {
          final era = WallTiers.tierAt(st.firstBrick);
          expect(st.peakY, greaterThan(WallDims.walkTopOf(era) + 0.2),
              reason: '${st.type.name} did not reach the wall it was built '
                  'against, at $n bricks');
        }
      }
    });

    test('a landmark never leaves part of itself hanging in the air', () {
      // When a landmark cannot afford everything it is meant to have, what it
      // gives up must be the top: its mass is built whole first. Paying for the
      // parapet before the tower under it left the parapet floating over the
      // hole where the tower should have been.
      for (final n in [200, 600, 1200, 3000]) {
        final l = WallLayout(n);
        for (final st in l.structures) {
          final bands = <List<double>>[];
          for (final s in l.slots) {
            if (s.structureIndex == st.index) bands.add([s.y - s.h / 2, s.top]);
          }
          if (bands.length < 4) continue;
          bands.sort((a, b) => a[0].compareTo(b[0]));
          var reach = bands.first[0];
          var gap = 0.0, at = 0.0;
          for (final b in bands) {
            if (b[0] - reach > gap) {
              gap = b[0] - reach;
              at = reach;
            }
            if (b[1] > reach) reach = b[1];
          }
          expect(gap, lessThan(0.7),
              reason: '${st.type.name} is in two pieces around y=$at '
                  'at $n bricks');
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
