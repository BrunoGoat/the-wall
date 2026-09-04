import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/rng.dart';
import 'package:la_muralla/data/pacing.dart';
import 'package:la_muralla/engine/layout.dart';
import 'package:la_muralla/engine/stone.dart';

void main() {
  group('the wall is append-only', () {
    test('a stone laid today is in the same place tomorrow', () {
      final small = WallLayout(40);
      final big = WallLayout(400);
      for (var i = 0; i < 40; i++) {
        final a = small.slots[i];
        final b = big.slots[i];
        expect(a.x, closeTo(b.x, 1e-9), reason: 'brick $i moved sideways');
        expect(a.y, closeTo(b.y, 1e-9), reason: 'brick $i moved vertically');
        expect(a.w, closeTo(b.w, 1e-9));
        expect(a.seed, b.seed, reason: 'brick $i changed shape');
      }
    });

    test('rebuilding the same wall gives exactly the same wall', () {
      final a = WallLayout(220);
      final b = WallLayout(220);
      expect(a.slots.length, b.slots.length);
      for (var i = 0; i < a.slots.length; i++) {
        expect(a.slots[i].x, a.slots[i].x);
        expect(a.slots[i].seed, b.slots[i].seed);
      }
    });
  });

  group('one brick is one stone', () {
    test('n bricks produce n stones, plus one ghost for the next', () {
      for (final n in [0, 1, 7, 12, 33, 60, 200, 500]) {
        final l = WallLayout(n);
        expect(l.slots.length, n + 1, reason: 'at $n bricks');
        for (var i = 0; i < l.slots.length; i++) {
          expect(l.slots[i].brickIndex, i);
        }
      }
    });

    test('no stone is ever degenerate', () {
      final l = WallLayout(600);
      for (final s in l.slots) {
        expect(s.w, greaterThan(0.05), reason: 'brick ${s.brickIndex}');
        expect(s.h, greaterThan(0.05), reason: 'brick ${s.brickIndex}');
        expect(s.halfDepth, greaterThan(0.02));
        expect(s.x.isFinite && s.y.isFinite, isTrue);
        expect(s.y, greaterThan(0.0));
      }
    });
  });

  group('landmarks are built out of real bricks', () {
    test('a landmark occupies exactly the bricks the pacing promised', () {
      final l = WallLayout(700);
      for (final st in l.structures) {
        final owned =
            l.slots.where((s) => s.structureIndex == st.index).toList();
        if (st.firstBrick + st.brickCount > 700 + 1) continue;
        expect(owned.length, st.brickCount,
            reason: '${st.type.name} should cost ${st.brickCount} bricks');
        expect(owned.first.brickIndex, st.firstBrick);
      }
    });

    test('landmarks start where the plan says they do', () {
      final l = WallLayout(700);
      for (var i = 0; i < l.structures.length; i++) {
        expect(l.structures[i].firstBrick, Pacing.milestoneStart(i));
      }
    });

    test('a landmark rises as its bricks are laid, never all at once', () {
      final st = WallLayout(40).structures.first;
      double heightAt(int placed) {
        final l = WallLayout(placed);
        var top = 0.0;
        for (final s in l.slots.take(placed)) {
          if (s.structureIndex >= 0 && s.top > top) top = s.top;
        }
        return top;
      }

      final quarter = heightAt(st.firstBrick + st.brickCount ~/ 4);
      final half = heightAt(st.firstBrick + st.brickCount ~/ 2);
      final whole = heightAt(st.firstBrick + st.brickCount);
      expect(quarter, greaterThan(0));
      expect(half, greaterThan(quarter));
      expect(whole, greaterThan(half));
    });

    test('landmarks do not sit on top of each other along the wall', () {
      final l = WallLayout(900);
      for (var i = 1; i < l.structures.length; i++) {
        expect(l.structures[i].x0,
            greaterThanOrEqualTo(l.structures[i - 1].x1 - 1e-6));
      }
    });
  });

  group('the wall grows lengthwise', () {
    test('more bricks means a longer wall', () {
      var last = 0.0;
      for (final n in [10, 40, 120, 400, 1000]) {
        final len = WallLayout(n).length;
        expect(len, greaterThan(last));
        last = len;
      }
    });

    test('it stays a wall: much longer than it is tall', () {
      final l = WallLayout(1000);
      var top = 0.0;
      for (final s in l.slots) {
        if (s.top > top) top = s.top;
      }
      expect(l.length / top, greaterThan(10));
    });

    test('the profile used for the far silhouette covers the whole wall', () {
      final l = WallLayout(500);
      expect(l.profileCore.length, greaterThan(l.length / l.profileStep));
      var solid = 0;
      for (final v in l.profileCore) {
        if (v > 0) solid++;
      }
      expect(solid * l.profileStep, greaterThan(l.length * 0.9));
    });
  });

  group('stones are irregular, not one rectangle rescaled', () {
    test('shapes differ from each other', () {
      final profiles = StoneProfiles.instance;
      final signatures = <String>{};
      for (var i = 0; i < 600; i++) {
        final p = profiles.forSeed(i);
        signatures.add(p.pts.map((v) => v.toStringAsFixed(3)).join(','));
      }
      expect(signatures.length, 600,
          reason: 'every slot in the profile pool must be its own silhouette');
    });

    test('no stone is a plain rectangle', () {
      final profiles = StoneProfiles.instance;
      for (var i = 0; i < 200; i++) {
        final p = profiles.forSeed(hash32(i, 7));
        expect(p.count, greaterThanOrEqualTo(4));
        var offGrid = 0;
        for (var v = 0; v < p.count; v++) {
          final x = p.pts[v * 2].abs();
          final y = p.pts[v * 2 + 1].abs();
          if ((x - 0.5).abs() > 1e-4 || (y - 0.5).abs() > 1e-4) offGrid++;
        }
        expect(offGrid, p.count, reason: 'every vertex should be displaced');
      }
    });

    test('a stone stays inside its own slot', () {
      final profiles = StoneProfiles.instance;
      for (var i = 0; i < 300; i++) {
        final p = profiles.forSeed(hash32(i, 31));
        for (var v = 0; v < p.count; v++) {
          expect(p.pts[v * 2].abs(), lessThanOrEqualTo(0.5 + 1e-6),
              reason: 'stone $i bulges out of its slot sideways');
          expect(p.pts[v * 2 + 1].abs(), lessThanOrEqualTo(0.5 + 1e-6),
              reason: 'stone $i bulges out of its slot vertically');
        }
      }
    });
  });
}
