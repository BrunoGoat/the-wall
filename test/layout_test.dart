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
        // A landmark is the one thing that grows with the wall: when the wall
        // levels up, the landmark is rebuilt taller out of the same stones so
        // it does not end up a notch in a skyline that has passed it by. Its
        // stones stay its stones, in its own stretch of wall.
        if (a.structureIndex >= 0) {
          expect(b.structureIndex, a.structureIndex, reason: 'brick $i');
          expect(b.x, closeTo(a.x, 2.0), reason: 'brick $i left its landmark');
          continue;
        }
        expect(a.x, closeTo(b.x, 1e-9), reason: 'brick $i moved sideways');
        expect(a.y, closeTo(b.y, 1e-9), reason: 'brick $i moved vertically');
        expect(a.w, closeTo(b.w, 1e-9));
        expect(a.seed, b.seed, reason: 'brick $i changed shape');
      }
    });

    test('the ghost is not part of the wall yet', () {
      // One slot beyond the placed bricks is always laid out so the app can
      // show where the next stone lands. It must not lengthen the wall, appear
      // in the distant silhouette, or cast a shadow before it is earned.
      final l = WallLayout(120);
      expect(l.slots.length, 121);
      final ghost = l.slots[120];

      var laid = 0.0;
      for (var i = 0; i < 120; i++) {
        if (l.slots[i].right > laid) laid = l.slots[i].right;
      }
      expect(l.length, closeTo(laid, 1e-9),
          reason: 'the ghost stretched the wall');

      if (ghost.left > laid + 0.05) {
        final bucket = (ghost.x / l.profileStep).floor();
        if (bucket < l.profileTop.length) {
          expect(l.profileTop[bucket], 0,
              reason: 'the ghost showed up in the silhouette and its shadow');
        }
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
      // Measured against the rampart itself. Landmarks are meant to stand
      // above it — a tower is not evidence that the wall stopped being a wall.
      double rampart(WallLayout l) {
        var top = 0.0;
        for (final s in l.slots) {
          if (s.structureIndex < 0 && s.top > top) top = s.top;
        }
        return top;
      }

      for (final n in [300, 1000, 3000]) {
        final l = WallLayout(n);
        expect(l.length / rampart(l), greaterThan(7),
            reason: 'at $n bricks it stopped reading as a wall');
      }
      // And it keeps stretching out faster than it climbs.
      final short = WallLayout(1000);
      final long = WallLayout(4000);
      expect(long.length / rampart(long),
          greaterThan(short.length / rampart(short)));
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

  group('every stone is a solid', () {
    /// Signed area of the built front face, in world XY. Its sign is the
    /// winding direction, and the winding is what every side face's outward
    /// normal is derived from.
    double frontWinding(StoneSlot slot, bool mirror) {
      final mesh = StoneMesh(24);
      mesh.build(slot, StoneProfiles.instance.forSeed(slot.seed),
          mirror: mirror);
      var a = 0.0;
      for (var i = 0; i < mesh.n; i++) {
        final j = (i + 1) % mesh.n;
        a += mesh.front[i * 3] * mesh.front[j * 3 + 1] -
            mesh.front[j * 3] * mesh.front[i * 3 + 1];
      }
      return a;
    }

    StoneSlot sampleSlot(int i) => StoneSlot(
          brickIndex: i,
          x: 1.0,
          y: 0.5,
          w: 0.7,
          h: 0.38,
          zCenter: 0,
          halfDepth: 0.33,
          course: 1,
          kind: SlotKind.body,
          structureIndex: -1,
        );

    test('mirroring a stone does not flip its winding', () {
      // Negating x reverses a polygon's winding, which inverts every side
      // face normal: the top face gets culled as though it faced down and you
      // can see straight into the stone. Half of the wall looked hollow.
      for (var i = 0; i < 120; i++) {
        final slot = sampleSlot(i);
        final plain = frontWinding(slot, false);
        final mirrored = frontWinding(slot, true);
        expect(plain.sign, mirrored.sign,
            reason: 'stone $i winds the other way when mirrored');
        expect(plain.abs(), greaterThan(1e-4));
      }
    });

    test('the front face always winds counter-clockwise', () {
      // The side-face normals assume it. If this flips, the wall turns inside
      // out.
      for (var i = 0; i < 120; i++) {
        expect(frontWinding(sampleSlot(i), i.isEven), greaterThan(0),
            reason: 'stone $i is wound backwards');
      }
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
