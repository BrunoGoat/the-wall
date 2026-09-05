import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/city.dart';
import 'package:la_muralla/engine/mason.dart';

void main() {
  group('one achievement is one piece', () {
    test('n achievements produce n pieces, plus one ghost for the next', () {
      for (final n in [0, 1, 7, 30, 200, 900]) {
        expect(CityLayout(n).pieces.length, n + 1, reason: 'with $n placed');
      }
    });

    test('a piece laid today is in the same place tomorrow', () {
      final now = CityLayout(140);
      final later = CityLayout(900);
      for (var i = 0; i < now.pieces.length - 1; i++) {
        final a = now.pieces[i], b = later.pieces[i];
        expect(b.kind, a.kind, reason: 'piece $i changed kind');
        expect(b.cx, closeTo(a.cx, 1e-9), reason: 'piece $i moved');
        expect(b.cz, closeTo(a.cz, 1e-9), reason: 'piece $i moved');
        expect(b.y0, closeTo(a.y0, 1e-9), reason: 'piece $i moved');
        expect(b.y1, closeTo(a.y1, 1e-9), reason: 'piece $i moved');
        expect(b.building, a.building, reason: 'piece $i changed house');
      }
    });

    test('the same town is rebuilt exactly the same way', () {
      final a = CityLayout(333), b = CityLayout(333);
      for (var i = 0; i < a.pieces.length; i++) {
        expect(b.pieces[i].cx, a.pieces[i].cx);
        expect(b.pieces[i].y1, a.pieces[i].y1);
      }
    });
  });

  group('the buildings', () {
    test('every finished building cost exactly what the plan says', () {
      final city = CityLayout(900);
      for (final b in city.buildings) {
        if (!b.finished) continue;
        final mine = city.pieces.where((p) => p.building == b.index).length;
        expect(mine, b.cost, reason: '${b.name} #${b.index}');
      }
    });

    test('a house is built from the ground up, with nothing left floating', () {
      final city = CityLayout(900);
      for (final b in city.buildings) {
        final mine = city.pieces.where((p) => p.building == b.index).toList();
        if (mine.isEmpty) continue;
        // Something has to touch the ground, and every piece above it has to
        // stand on something already built rather than hang in the air. Water
        // and ploughed rows are cut into the ground, so they sit below it.
        expect(mine.map((p) => p.y0).reduce(math.min), lessThan(0.001),
            reason: '${b.name} floats');
        final tops = <double>[0];
        for (final p in mine) {
          final rests = tops.any((t) => (p.y0 - t).abs() < 0.02 || p.y0 < t);
          expect(rests, isTrue,
              reason: '${b.name}: a ${p.kind.name} hangs at ${p.y0}');
          tops.add(p.y1);
        }
      }
    });

    test('nothing is stacked on top of a roof', () {
      // The way a house goes wrong is the last piece landing above the ridge:
      // a door or a clock face left hanging over the tiles. Only a chimney is
      // allowed to come out through a roof.
      const caps = {PieceKind.roof, PieceKind.spire};
      final city = CityLayout(900);
      bool over(CityPiece a, CityPiece b) =>
          (a.cx - b.cx).abs() < (a.w + b.w) * 0.4 &&
          (a.cz - b.cz).abs() < (a.d + b.d) * 0.4;
      for (final b in city.buildings) {
        final mine = city.pieces.where((p) => p.building == b.index).toList();
        for (final p in mine) {
          // A church has a nave and a bell tower, so the comparison is per
          // column: only a roof this piece actually stands over counts.
          const crowns = {
            PieceKind.chimney,
            PieceKind.sail,
            PieceKind.banner,
            PieceKind.dome,
            PieceKind.spire,
          };
          if (caps.contains(p.kind) || crowns.contains(p.kind)) continue;
          for (final cap in mine) {
            if (!caps.contains(cap.kind) || !over(p, cap)) continue;
            expect(p.y0, lessThan(cap.y1 - 0.01),
                reason: '${b.name}: a ${p.kind.name} sits on the roof');
          }
        }
      }
    });

    test('no two houses are built on the same plot', () {
      final city = CityLayout(900);
      final seen = <String>{};
      for (final b in city.buildings) {
        expect(seen.add('${b.cx.toStringAsFixed(3)},${b.cz.toStringAsFixed(3)}'),
            isTrue,
            reason: 'two houses on the same plot');
      }
    });

    test('a year of use meets several different landmarks', () {
      final city = CityLayout(900);
      final names = city.buildings
          .where((b) => b.isLandmark && b.finished)
          .map((b) => b.name)
          .toList();
      expect(names.length, greaterThanOrEqualTo(8),
          reason: 'a year should meet a good handful of landmarks');
      expect(names.toSet().length, names.length,
          reason: 'and not the same one twice: \$names');
    });
  });

  group('the town keeps its shape', () {
    test('it grows outward from the middle, never as a single line', () {
      for (final n in [30, 200, 900]) {
        final city = CityLayout(n);
        var maxX = 0.0, maxZ = 0.0;
        for (final b in city.buildings) {
          if (b.cx.abs() > maxX) maxX = b.cx.abs();
          if (b.cz.abs() > maxZ) maxZ = b.cz.abs();
        }
        final ratio = maxX / maxZ;
        expect(ratio, greaterThan(0.5), reason: 'with $n it is a strip');
        expect(ratio, lessThan(2.0), reason: 'with $n it is a strip');
      }
    });

    test('the town spreads slowly enough to stay one place', () {
      // A hundred times more achievements must not put the far side of town
      // a hundred times further away.
      expect(CityLayout(9000).radius, lessThan(CityLayout(90).radius * 12));
    });
  });

  group('the catalogue', () {
    test('there are at least a hundred different landmarks', () {
      expect(landmarks.length, greaterThanOrEqualTo(100));
    });

    test('every landmark has its own id and its own name', () {
      expect(landmarks.map((l) => l.id).toSet().length, landmarks.length);
      expect(landmarks.map((l) => l.name).toSet().length, landmarks.length);
    });

    test('every tier has enough in it to keep a long town varied', () {
      for (var t = 0; t < 3; t++) {
        final n = landmarks.where((l) => l.tier == t).length;
        expect(n, greaterThanOrEqualTo(20), reason: 'tier $t has only $n');
      }
    });

    test('every landmark builds to exactly what it costs', () {
      for (final l in landmarks) {
        final m = Mason(0, 0, 12345, true);
        l.build(m);
        expect(m.count, greaterThanOrEqualTo(l.cost),
            reason: '${l.name} lays ${m.count} pieces but costs ${l.cost}, so '
                'the last ones would be padding');
        expect(m.count, lessThanOrEqualTo(l.cost + 3),
            reason: '${l.name} lays ${m.count} pieces but costs only ${l.cost}, '
                'so it would never be finished');
      }
    });

    test('every landmark stands on the ground and holds together', () {
      for (final l in landmarks) {
        final m = Mason(0, 0, 999, true);
        l.build(m);
        final built = m.finish(l.cost);
        expect(built.first.y0, lessThan(0.001),
            reason: '${l.name} starts in the air');
        final tops = <double>[0];
        for (final s in built) {
          final rests =
              s.y0 < 0.02 || tops.any((t) => s.y0 < t + 0.03);
          expect(rests, isTrue,
              reason: '${l.name}: a ${s.kind.name} hangs at ${s.y0}');
          tops.add(s.y1);
        }
      }
    });

    test('no landmark sprawls further than its own plot allows', () {
      for (final l in landmarks) {
        final m = Mason(0, 0, 7, true);
        l.build(m);
        var reach = 0.0;
        for (final s in m.finish(l.cost)) {
          final r = math.max(
              s.cx.abs() + s.w / 2, s.cz.abs() + s.d / 2);
          if (r > reach) reach = r;
        }
        expect(reach, closeTo(l.reach, 1e-9),
            reason: '${l.name} does not know how far it reaches');
        // Nothing may be so big the town has to be laid out around it.
        final allowed = l.tier >= 2 ? 7.0 : 4.0;
        expect(reach, lessThanOrEqualTo(allowed),
            reason: '${l.name} sprawls ${reach.toStringAsFixed(2)}');
      }
    });

    test('a long life meets a hundred landmarks without repeating one', () {
      final seen = <String>[];
      for (var b = 0; b < 12000; b++) {
        if (!CityPlan.isLandmarkSlot(b)) continue;
        seen.add(CityPlan.landmarkFor(b).id);
        if (seen.length >= 100) break;
      }
      expect(seen.length, 100, reason: 'only ${seen.length} landmarks come up');
      expect(seen.toSet().length, 100, reason: 'a landmark came round twice');
    });
  });
}
