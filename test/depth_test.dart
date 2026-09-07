import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/solid.dart';
import 'package:la_muralla/engine/solids.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/engine/world.dart';

/// Every structure the town can build: the seven houses and the hundred and
/// twelve landmarks, the same list the exhibition hall shows.
List<(String, Landmark?, BuildingKind?, int)> _catalogue() => [
  for (final k in BuildingKind.values)
    (buildingName[k]!, null, k, buildingCost[k]!),
  for (final m in landmarks) (m.name, m, null, m.cost),
];

TownLayout _show(Landmark? mark, BuildingKind? kind, int pieces) =>
    TownLayout.showcase(
      TownCharacter.all.first,
      landmark: mark,
      kind: kind,
      placed: pieces,
    );

void main() {
  group('nothing is ever a shell', () {
    // A face can only go missing at some angle if the thing it belongs to is
    // open somewhere — a roof with no floor, a dome with no base. Culling the
    // faces turned away from the camera is exact and free, but only on a solid
    // that is genuinely shut: on a shell it leaves a hole you can see the
    // grass through, which is precisely how half a roof used to disappear.
    //
    // Shut means every edge is walked twice, once each way. Nothing else has
    // to be checked, and nothing weaker is enough.
    test('every piece of every structure is a closed solid', () {
      final open = <String>[];
      for (final (name, mark, kind, cost) in _catalogue()) {
        final layout = _show(mark, kind, cost);
        for (final piece in layout.pieces) {
          for (final solid in solidsOf(piece)) {
            final edges = <String, int>{};
            for (final f in solid.faces) {
              for (var i = 0; i < f.v.length; i++) {
                final a = f.v[i], b = f.v[(i + 1) % f.v.length];
                final key = '${_k(a)}|${_k(b)}';
                edges[key] = (edges[key] ?? 0) + 1;
              }
            }
            for (final e in edges.entries) {
              final parts = e.key.split('|');
              final back = '${parts[1]}|${parts[0]}';
              if (e.value != 1 || edges[back] != 1) {
                open.add('$name ${piece.kind.name} @${piece.index}');
                break;
              }
            }
          }
        }
      }
      expect(
        open,
        isEmpty,
        reason: 'these are open shells, and a shell loses faces: $open',
      );
    });
  });

  group('a face knows where its own plane is', () {
    // A normal that is not square to its own face is not a shading nicety gone
    // slightly wrong: it is a lie about where the plane of that face lies, and
    // what is culled, how the tree is cut and what order things come out in
    // are all built on that plane being the truth. Two of these were sitting
    // in the town for as long as there have been roofs — a whole orientation
    // of gable lit as though it were shallow when it is steep, and a dome
    // whose faces each claimed a plane none of them was on — and neither was
    // ever going to be caught by looking at a picture.
    test('every normal is square to the face it belongs to', () {
      final bent = <String>[];
      for (final (name, mark, kind, cost) in _catalogue()) {
        for (final piece in _show(mark, kind, cost).pieces) {
          for (final solid in solidsOf(piece)) {
            for (final f in solid.faces) {
              final d = f.n.dot(f.v.first);
              for (final p in f.v) {
                if ((f.n.dot(p) - d).abs() > 1e-6) {
                  bent.add(
                    '$name ${piece.kind.name} @${piece.index} '
                    '${f.surface.name} n=${f.n}',
                  );
                  break;
                }
              }
              if ((f.n.length - 1).abs() > 1e-6) {
                bent.add(
                  '$name ${piece.kind.name} @${piece.index} '
                  'normal is not a unit vector',
                );
              }
            }
          }
        }
      }
      expect(bent.toSet().toList(), isEmpty);
    });
  });

  group('the cost of cutting', () {
    // Cutting geometry is what makes the order exact, and cutting badly is the
    // one way this could get expensive: a splitting plane chosen carelessly
    // slices half the town in two and every frame pays for it from then on.
    // Almost everything in a town is a box standing clear of the next one, and
    // between two of those the plane is the street — it cuts nothing at all.
    // Only what genuinely runs through something else gets cut.
    test('filing a town away does not run the faces away with it', () {
      final layout = TownLayout(400, TownCharacter.all.first);
      var raw = 0;
      for (var i = 0; i < 400; i++) {
        for (final s in solidsOf(layout.pieces[i])) {
          for (final f in s.faces) {
            raw += 1 + (f.decals?.length ?? 0);
          }
        }
      }
      var cut = 0;
      for (final c in builtTown(layout, 400).clusters) {
        cut += c.faces;
      }
      expect(cut, greaterThan(0));
      expect(
        cut,
        lessThan(raw * 8 ~/ 5),
        reason: 'cutting turned $raw faces into $cut',
      );
    });

    // And laying a piece re-files that piece's own corner of the town, not the
    // town. The world is append-only: the two hundred houses that did not
    // change did not need looking at.
    test('one more achievement costs one more achievement', () {
      // Warm: five years of daily use standing before this morning's piece.
      builtTown(TownLayout(1800, TownCharacter.all.first), 1800);
      final clock = Stopwatch()..start();
      final after = builtTown(TownLayout(1801, TownCharacter.all.first), 1801);
      clock.stop();
      expect(after.clusters, isNotEmpty);
      expect(
        clock.elapsedMilliseconds,
        lessThan(220),
        reason:
            'laying the 1801st piece took '
            '\${clock.elapsedMilliseconds}ms',
      );
    });
  });

  group('the order is right from every angle', () {
    // The whole reason this renderer was rebuilt. It has no depth buffer: it
    // paints polygons one after another, so the order they go down in *is* the
    // depth test. The old order was a guess — how far away the middle of each
    // face was — and a guess is wrong exactly when two faces overlap in depth,
    // which is what a chimney standing on a roof does.
    //
    // So: put every structure on a turntable, and for every pair of polygons
    // that land on top of each other on screen, check the one painted second
    // is genuinely the nearer of the two where they overlap. That is the bug
    // the eye kept catching, asked of the machine instead.
    test('nothing is painted over something that stands in front of it', () {
      final bad = <String>[];
      for (final (name, mark, kind, cost) in _catalogue()) {
        final layout = _show(mark, kind, cost);
        var top = 1.0;
        for (final p in layout.pieces) {
          if (p.y1 > top) top = p.y1;
        }
        final dist = math.max(6.0, top * 2.6);
        for (var yi = 0; yi < 8 && bad.isEmpty; yi++) {
          for (var pi = 0; pi < 3 && bad.isEmpty; pi++) {
            final yaw = yi * math.pi / 4 + 0.21;
            final pitch = 0.10 + pi * 0.42;
            final where = _fault(layout, cost, yaw, pitch, dist, top * 0.5);
            if (where != null) {
              bad.add(
                '$name: $where '
                '(yaw ${(yaw * 57.3).round()}°, '
                'pitch ${(pitch * 57.3).round()}°)',
              );
            }
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  });
}

String _k(V3 p) =>
    '${p.x.toStringAsFixed(6)},${p.y.toStringAsFixed(6)},${p.z.toStringAsFixed(6)}';

/// Looks for one polygon painted over another that stands in front of it, and
/// says which two if it finds a pair.
String? _fault(
  TownLayout layout,
  int placed,
  double yaw,
  double pitch,
  double dist,
  double focusY,
) {
  final target = V3(0, focusY, 0);
  final cp = math.cos(pitch);
  final eye =
      target +
      V3(math.sin(yaw) * cp, math.sin(pitch), math.cos(yaw) * cp) * dist;
  final forward = (target - eye).normalized;
  var right = forward.cross(const V3(0, 1, 0));
  right = right.length < 1e-4 ? const V3(1, 0, 0) : right.normalized;
  final up = right.cross(forward).normalized;
  const focal = 640.0;

  final seq = paintSequence(layout, placed, eye);
  final polys = <_Poly>[];
  for (final f in seq) {
    final p = _Poly.of(f, eye, right, up, forward, focal);
    if (p != null) polys.add(p);
  }

  for (var j = 1; j < polys.length; j++) {
    final later = polys[j];
    for (var i = 0; i < j; i++) {
      final under = polys[i];
      if (!later.touches(under)) continue;
      // Sample inside the polygon painted second: if any of those points falls
      // inside the one painted first, the later one is covering it there, and
      // it had better be the nearer of the two.
      for (final s in later.samples) {
        if (!under.holds(s)) continue;
        final a = later.depthAt(s, focal);
        final b = under.depthAt(s, focal);
        if (a == null || b == null) continue;
        if (a > b + 0.012) {
          return 'a ${later.what} was painted over a ${under.what} '
              'standing ${(a - b).toStringAsFixed(2)} in front of it'
              '\n  painted second: ${later.world}'
              '\n  painted first:  ${under.world}';
        }
      }
    }
  }
  return null;
}

/// One face, projected, with the plane it came from kept in camera space so
/// its depth can be asked for at any point on screen.
class _Poly {
  _Poly(
    this.xs,
    this.ys,
    this.n,
    this.d,
    this.what,
    this.samples,
    this.x0,
    this.y0,
    this.x1,
    this.y1,
    this.world,
  );

  static _Poly? of(Facet f, V3 eye, V3 right, V3 up, V3 forward, double focal) {
    final cam = <V3>[];
    for (final p in f.v) {
      final v = p - eye;
      final c = V3(v.dot(right), v.dot(up), v.dot(forward));
      if (c.z < 0.2) return null; // behind or across the near plane
      cam.add(c);
    }
    final n = V3(f.n.dot(right), f.n.dot(up), f.n.dot(forward));
    final d = n.dot(cam.first);
    final xs = <double>[], ys = <double>[];
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final c in cam) {
      final sx = c.x * focal / c.z, sy = -c.y * focal / c.z;
      xs.add(sx);
      ys.add(sy);
      if (sx < x0) x0 = sx;
      if (sx > x1) x1 = sx;
      if (sy < y0) y0 = sy;
      if (sy > y1) y1 = sy;
    }
    if (x1 - x0 < 0.5 || y1 - y0 < 0.5) return null; // edge-on, nothing to see
    var mx = 0.0, my = 0.0;
    for (var i = 0; i < xs.length; i++) {
      mx += xs[i];
      my += ys[i];
    }
    mx /= xs.length;
    my /= ys.length;
    // Points well inside, so a shared edge never reads as an overlap.
    final samples = <(double, double)>[(mx, my)];
    for (var i = 0; i < xs.length; i++) {
      samples.add((mx + (xs[i] - mx) * 0.72, my + (ys[i] - my) * 0.72));
    }
    return _Poly(
      xs,
      ys,
      n,
      d,
      f.surface.name,
      samples,
      x0,
      y0,
      x1,
      y1,
      'piece=${f.piece} n=${f.n} ${f.v.map((q) => '(${q.x.toStringAsFixed(2)},${q.y.toStringAsFixed(2)},${q.z.toStringAsFixed(2)})').join(' ')}',
    );
  }

  final List<double> xs, ys;
  final V3 n;
  final double d;
  final String what;
  final List<(double, double)> samples;
  final double x0, y0, x1, y1;
  final String world;

  bool touches(_Poly o) => x0 < o.x1 && o.x0 < x1 && y0 < o.y1 && o.y0 < y1;

  bool holds((double, double) s) {
    var inside = false;
    final n = xs.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = ys[i], yj = ys[j];
      if ((yi > s.$2) != (yj > s.$2)) {
        final x = xs[i] + (s.$2 - yi) / (yj - yi) * (xs[j] - xs[i]);
        if (s.$1 < x) inside = !inside;
      }
    }
    return inside;
  }

  /// How far away this face's plane is along the ray through a screen point.
  double? depthAt((double, double) s, double focal) {
    final dir = V3(s.$1 / focal, -s.$2 / focal, 1);
    final den = n.dot(dir);
    if (den.abs() < 1e-9) return null;
    final t = d / den;
    return t <= 0 ? null : t;
  }
}
