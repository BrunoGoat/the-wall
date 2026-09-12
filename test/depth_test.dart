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

/// The same structure as each of the six regions would build it.
///
/// It used to be built once, in Ribera, and that was a hole: the region is no
/// longer only a coat of paint. It stretches every recipe on the ground and in
/// height, it steepens every roof, and where it roofs in straw the roof is a
/// different solid altogether. A structure checked in one region is a
/// structure checked in one sixth of the cases.
TownLayout _show(
  Landmark? mark,
  BuildingKind? kind,
  int pieces, [
  TownCharacter? place,
]) => TownLayout.showcase(
  place ?? TownCharacter.all.first,
  landmark: mark,
  kind: kind,
  placed: pieces,
  // Six different seeds as well as six regions, so the roll that decides tile
  // from slate from straw lands every way round somewhere in the sweep.
  seed: place == null ? 0 : place.order,
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
      for (final place in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          final layout = _show(mark, kind, cost, place);
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
                  open.add('${place.region} $name ${piece.kind.name}');
                  break;
                }
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
      for (final place in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final piece in _show(mark, kind, cost, place).pieces) {
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
      }
      expect(bent.toSet().toList(), isEmpty);
    });
  });

  group('a whole town, plaza and all', () {
    // The exhibits stand on their own; a town has streets, neighbours and a
    // notice board in the middle of it, and the order between all of that is
    // the same question asked of a much messier scene.
    test('nothing in a real town is painted over what is in front of it', () {
      // Dos regiones y no una: la más ancha y la más apretada no plantean el
      // mismo problema. Donde esto se rompe es entre dos cajas que se solapan
      // en profundidad, y eso depende de lo juntas que estén las casas.
      final bad = <String>[];
      for (final c in [TownCharacter.all.first, TownCharacter.all.last]) {
        for (final n in [1, 12, 90, 300]) {
          final layout = TownLayout(n, c);
          for (var yi = 0; yi < 6 && bad.isEmpty; yi++) {
            for (var pi = 0; pi < 2 && bad.isEmpty; pi++) {
              final where = _fault(
                layout,
                n,
                yi * math.pi / 3 + 0.21,
                0.18 + pi * 0.5,
                math.max(9.0, layout.radius * 1.4),
                1.2,
              );
              if (where != null) {
                bad.add('${c.region}, $n piezas: $where');
              }
            }
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
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

    test('y ningún pueblo es un solo nudo', () {
      // Lo que se rompió una vez, dicho directamente y barato.
      //
      // Dos edificios se ordenan solos cuando un plano los separa. Cuando se
      // atraviesan no lo hay, y hay que meterlos en el mismo árbol y cortarlos
      // entre sí — y ese árbol se vuelve a cortar entero cada vez que el
      // pueblo crece. Al probar una región de casas mucho más anchas sin
      // ensancharle el solar, todos los edificios se tocaban: el pueblo entero
      // era un nudo de cinco grupos, y poner una pieza pasó de once a
      // quinientos doce milisegundos con cuatrocientas piezas, y a casi cinco
      // segundos con mil ochocientas.
      //
      // Eso lo cazó el cronómetro de aquí abajo, pero sólo con mil ochocientas
      // piezas y por el peor de los seis, que es tarde y es vago. Esto lo dice
      // en la forma en que pasa: si un pueblo tiene ciento y pico edificios y
      // el filtrado saca cinco grupos, están todos metidos unos dentro de
      // otros.
      //
      // El umbral es un suelo contra el desastre, no una medida de lo apretado
      // que está el pueblo: un pueblo sano saca del orden de un grupo por
      // edificio o más, y el nudo que hubo sacaba trece para ciento trece.
      // Cualquier cosa por debajo de la mitad es que se están atravesando.
      for (final c in TownCharacter.all) {
        final layout = TownLayout(400, c);
        final casas = layout.buildings.length;
        final grupos = builtTown(layout, 400).clusters.length;
        expect(
          grupos,
          greaterThan(casas ~/ 2),
          reason:
              '${c.region}: $casas edificios en $grupos grupos — se están '
              'atravesando, y cada pieza nueva vuelve a cortarlos a todos',
        );
      }
    });

    // And laying a piece re-files that piece's own corner of the town, not the
    // town. The world is append-only: the two hundred houses that did not
    // change did not need looking at.
    test('one more achievement costs one more achievement', () {
      // Los seis y no uno, y por la mediana.
      //
      // Esto medía un solo pueblo contra un número de milisegundos, y ese
      // número estaba afinado a los edificios que a ese pueblo le tocaban.
      // Cambiar el orden de las obras —que es algo que va a pasar cada vez que
      // se añada una estructura— le cambiaba los edificios, y el test se caía
      // sin que nada estuviera roto. Peor: tapaba lo contrario, que un pueblo
      // se pusiera lento por un reparto desafortunado.
      //
      // Hay además un precipicio conocido debajo de todo esto. Cuando ningún
      // plano separa a un grupo de edificios hay que cortarlos en un solo
      // árbol, y en un pueblo denso de casas anchas las cajas se tocan todas
      // por el suelo: el pueblo entero es un nudo, y ese nudo se vuelve a
      // cortar cada vez que crece. Por eso la mediana manda y el peor caso
      // sólo tiene un techo: la mediana es lo que se arregló, y el peor caso
      // es lo que queda por arreglar.
      final took = <int>[];
      for (final c in TownCharacter.all) {
        builtTown(TownLayout(1800, c), 1800);
        final clock = Stopwatch()..start();
        final after = builtTown(TownLayout(1801, c), 1801);
        clock.stop();
        expect(after.clusters, isNotEmpty, reason: c.region);
        took.add(clock.elapsedMilliseconds);
      }
      took.sort();
      final middle = took[took.length ~/ 2];
      expect(
        middle,
        lessThan(90),
        reason: 'la mediana de los seis fue de ${middle}ms: $took',
      );
      expect(
        took.last,
        lessThan(1400),
        reason: 'el peor de los seis fue de ${took.last}ms: $took',
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
