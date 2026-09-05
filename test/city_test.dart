import 'package:flutter_test/flutter_test.dart';

import 'package:la_muralla/engine/city.dart';

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
        // stand on something already built rather than hang in the air.
        expect(mine.first.y0, closeTo(0, 1e-6), reason: '${b.name} floats');
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
          if (caps.contains(p.kind) || p.kind == PieceKind.chimney) continue;
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
      final kinds = city.buildings
          .where((b) => b.isLandmark && b.finished)
          .map((b) => b.kind)
          .toSet();
      expect(kinds.length, greaterThanOrEqualTo(3));
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
}
