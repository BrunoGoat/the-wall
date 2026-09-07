import 'dart:math' as math;

import '../core/math3.dart';
import 'bsp.dart';
import 'solid.dart';
import 'solids.dart';
import 'town.dart';

/// One cluster of built things that has to be ordered from the inside.
///
/// Almost always this is a single solid — a wall, a roof, one stake of a
/// fence. Things only share a cluster when their boxes overlap on all three
/// axes at once, which is the one case where no plane separates them: a
/// chimney and the roof it comes out of, a dormer astride its slope. Those get
/// cut apart in a tree of their own; everything else stays whole.
class BuiltCluster {
  BuiltCluster(this.key, this.bounds, this.tree, this.members, this.source)
    : faces = tree.facets;

  /// The achievements it is made of, which is also what says a cluster has not
  /// changed since the last piece was laid and can be kept as it is.
  final String key;

  final Aabb bounds;
  final BspTree tree;

  /// Which achievements stand in here, so the detail budget can be spent on
  /// whole buildings instead of half-drawn ones.
  final Set<int> members;

  /// The faces as they were before the tree cut any of them, kept so that a
  /// cluster which later has to join another one is built from whole faces
  /// rather than from somebody else's offcuts.
  final List<Facet> source;

  /// How many faces it costs to paint, cuts included.
  final int faces;

  int get pieces => members.length;
}

/// A place in the order: either something to paint, or a plane with more
/// order on each side of it.
sealed class Order {
  Aabb get bounds;
}

class OrderLeaf extends Order {
  OrderLeaf(this.bounds, {this.cluster, this.weather = -1});
  @override
  final Aabb bounds;

  /// Masonry, or -1 and a piece index for the things that move with the wind.
  final BuiltCluster? cluster;
  final int weather;
}

/// A plane, and everything on each side of it.
///
/// Nothing straddles it, so which side is nearer is decided by which side the
/// camera is on and by nothing else. That is what makes the order exact rather
/// than sorted, and it is also what makes it impossible for three things to
/// hide each other in a ring — which is a real thing that happens with boxes,
/// and which the old distance sort had no answer to at all.
class OrderSplit extends Order {
  OrderSplit(this.axis, this.at, this.low, this.high, this.bounds);
  final int axis;
  final double at;
  final Order low, high;
  @override
  final Aabb bounds;
}

/// Two things with no plane to put between them, painted one after the other.
///
/// The one place left where the order is settled by a rule rather than by
/// geometry, and it is reached only when no plane separates anything in a
/// batch at all. Masonry never ends up here — anything that interleaves is cut
/// apart into a single tree instead — so what this holds is the crops, the
/// water and the flags, which lie flat on the ground or fly over the roofs and
/// do not hide one another.
class OrderBoth extends Order {
  OrderBoth(this.first, this.then, this.bounds);
  final Order first, then;
  @override
  final Aabb bounds;
}

/// A town's masonry, cut and filed once for the count of pieces it holds.
class BuiltTown {
  BuiltTown(
    this.root,
    this.clusters,
    this.weather,
    this.weatherBox,
    this.bounds,
    this.placed,
    this.sign,
  );
  final Order? root;
  final List<BuiltCluster> clusters;

  /// The pieces that only blow in the wind, which carry no masonry and are
  /// painted by hand every frame.
  final List<int> weather;
  final List<Aabb> weatherBox;

  final Aabb? bounds;
  final int placed;

  /// What town, and how far along, this was built for.
  final int sign;
}

/// Kept from one achievement to the next, so laying a piece re-files that
/// piece's own corner of the town and leaves the rest of it alone. Layouts are
/// thrown away and rebuilt whenever their count moves, which is why the cache
/// is keyed by where the town stands rather than by the object.
final Map<String, BuiltTown> _cache = {};

BuiltTown builtTown(TownLayout layout, int placed) {
  final key = '${layout.cx},${layout.cz},${layout.character.order}';
  final had = _cache[key];
  if (had != null &&
      had.placed == placed &&
      had.sign == _sign(layout, placed)) {
    return had;
  }
  // Carried forward only when the town really is the same town one piece
  // longer. Two different structures can stand in the same spot — the
  // exhibition hall puts a hundred and nineteen of them at the origin, one
  // after another — and building the second one on top of the first's masonry
  // would be a very quiet way of going very wrong.
  final seed =
      had != null &&
          had.placed <= math.min(placed, layout.pieces.length) &&
          had.sign == _sign(layout, had.placed)
      ? had
      : null;
  final made = _build(layout, placed, seed);
  if (_cache.length > 24) _cache.clear();
  _cache[key] = made;
  return made;
}

/// A cheap fingerprint of the first [upto] pieces, so a town carried over from
/// the last frame can be shown to be the same town.
int _sign(TownLayout layout, int upto) {
  var h = 0x811c9dc5;
  void feed(int v) {
    h = ((h ^ v) * 0x01000193) & 0x3fffffff;
  }

  final n = math.min(upto, layout.pieces.length);
  feed(n);
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    feed(p.kind.index);
    feed(p.alongX ? 1 : 2);
    feed(p.building);
    for (final v in [p.cx, p.cz, p.w, p.d, p.y0, p.y1]) {
      feed((v * 8192).round());
    }
  }
  return h;
}

BuiltTown _build(TownLayout layout, int placed, BuiltTown? before) {
  final take = math.min(placed, layout.pieces.length);

  // What is to be filed: every closed solid, and every cluster already filed
  // last time that can simply be carried over. A town is append-only, so
  // laying a piece changes one corner of one building and nothing else — and
  // re-cutting the other two hundred houses to find that out would be the most
  // expensive way imaginable of learning nothing.
  final faces = <List<Facet>>[];
  final bounds = <Aabb>[];
  final held = <Set<int>>[];
  final kept = <BuiltCluster?>[];
  final weather = <int>[];
  final weatherBox = <Aabb>[];
  var from = 0;
  if (before != null && before.placed <= take && before.clusters.isNotEmpty) {
    from = before.placed;
    for (final c in before.clusters) {
      faces.add(c.source);
      bounds.add(c.bounds);
      held.add(c.members);
      kept.add(c);
    }
    weather.addAll(before.weather);
    weatherBox.addAll(before.weatherBox);
  }

  for (var i = from; i < take; i++) {
    final piece = layout.pieces[i];
    if (hasWeather(piece.kind)) {
      final reach =
          piece.kind == PieceKind.banner || piece.kind == PieceKind.sail
          ? math.max(piece.w, piece.y1 - piece.y0)
          : 0.0;
      weather.add(i);
      weatherBox.add(
        Aabb(
          piece.x0 - reach,
          piece.y0,
          piece.z0 - reach,
          piece.x1 + reach,
          piece.y1,
          piece.z1 + reach,
        ),
      );
    }
    for (final solid in solidsOf(piece)) {
      final b = Aabb.of(solid.faces);
      if (b == null) continue;
      for (final f in solid.faces) {
        f.piece = solid.piece;
        final d = f.decals;
        if (d != null) {
          for (final g in d) {
            g.piece = solid.piece;
          }
        }
      }
      faces.add(solid.faces);
      bounds.add(b);
      held.add({solid.piece});
      kept.add(null);
    }
  }
  if (faces.isEmpty && weather.isEmpty) {
    return BuiltTown(
      null,
      const [],
      weather,
      weatherBox,
      null,
      placed,
      _sign(layout, take),
    );
  }

  // Grow the groups until no two of them overlap on all three axes. A box
  // sitting inside another box has no separating plane either, so it is not
  // enough to ask whether the pieces themselves run through one another: a
  // post standing clear of everything is still swallowed by the box round the
  // forge beside it, and that is a chance to get the order wrong.
  final n = faces.length;
  final owner = List<int>.generate(n, (i) => i);
  final box = List<Aabb>.of(bounds);
  int root(int k) {
    var r = k;
    while (owner[r] != r) {
      r = owner[r] = owner[owner[r]];
    }
    return r;
  }

  // Swept along x over the groups themselves, so two things at opposite ends
  // of the valley are never compared at all, and a group that has grown to
  // reach further left is still compared against what is now beside it.
  var moved = true;
  while (moved) {
    moved = false;
    final roots = <int>[];
    for (var i = 0; i < n; i++) {
      if (root(i) == i) roots.add(i);
    }
    roots.sort((a, b) => box[a].x0.compareTo(box[b].x0));
    for (var a = 0; a < roots.length; a++) {
      final i = roots[a];
      if (root(i) != i) continue;
      for (var b = a + 1; b < roots.length; b++) {
        final j = roots[b];
        if (box[j].x0 > box[i].x1) break;
        if (root(j) != j || root(i) != i) continue;
        if (!box[i].overlaps(box[j])) continue;
        owner[j] = i;
        box[i] = box[i].union(box[j]);
        moved = true;
      }
    }
  }

  final grouped = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    grouped.putIfAbsent(root(i), () => <int>[]).add(i);
  }

  final clusters = <BuiltCluster>[];
  for (final entry in grouped.entries) {
    final mine = entry.value;
    // A group that is one cluster and nothing else is the same cluster it was
    // before: it keeps its tree, cuts and all.
    if (mine.length == 1 && kept[mine.first] != null) {
      clusters.add(kept[mine.first]!);
      continue;
    }
    final source = <Facet>[];
    final members = <int>{};
    for (final i in mine) {
      source.addAll(faces[i]);
      members.addAll(held[i]);
    }
    final list = members.toList()..sort();
    clusters.add(
      BuiltCluster(
        list.join(','),
        box[entry.key],
        BspTree.build(source),
        members,
        source,
      ),
    );
  }

  final leaves = <OrderLeaf>[
    for (final c in clusters) OrderLeaf(c.bounds, cluster: c),
    for (var i = 0; i < weather.length; i++)
      OrderLeaf(weatherBox[i], weather: weather[i]),
  ];
  var whole = leaves.first.bounds;
  for (final l in leaves) {
    whole = whole.union(l.bounds);
  }
  return BuiltTown(
    _order(leaves),
    clusters,
    weather,
    weatherBox,
    whole,
    placed,
    _sign(layout, take),
  );
}

/// Files everything that stands in a town behind a series of planes.
///
/// Every plane has nothing straddling it, so at any node the near side and the
/// far side are decided by where the camera is and by nothing else. Between
/// separate buildings such a plane is simply the street between them and costs
/// nothing at all — no geometry is cut to make it. Only when no plane can be
/// found does anything get cut, and then it is cut once, here, and never
/// thought about again.
Order _order(List<OrderLeaf> leaves) {
  if (leaves.length == 1) return leaves.first;
  final cut = _separator(leaves);
  var b = leaves.first.bounds;
  for (final l in leaves) {
    b = b.union(l.bounds);
  }
  if (cut == null) {
    // No plane separates them: they interleave, so they are filed into one
    // tree, which settles it exactly at the cost of some cutting. Built from
    // whole faces rather than from anybody's offcuts.
    final source = <Facet>[];
    final members = <int>{};
    final under = <OrderLeaf>[];
    final over = <OrderLeaf>[];
    for (final l in leaves) {
      final c = l.cluster;
      if (c == null) {
        // Crops and water lie on the ground and go under everything; a flag
        // flies over the roofs and goes on top.
        (l.bounds.y1 <= 0.35 ? under : over).add(l);
        continue;
      }
      source.addAll(c.source);
      members.addAll(c.members);
    }
    Order? out;
    void after(Order o) => out = out == null ? o : OrderBoth(out!, o, b);
    for (final l in under) {
      after(l);
    }
    if (source.isNotEmpty) {
      final list = members.toList()..sort();
      after(
        OrderLeaf(
          b,
          cluster: BuiltCluster(
            list.join(','),
            b,
            BspTree.build(source),
            members,
            source,
          ),
        ),
      );
    }
    for (final l in over) {
      after(l);
    }
    return out ?? leaves.first;
  }
  final (axis, at, low, high) = cut;
  return OrderSplit(axis, at, _order(low), _order(high), b);
}

/// The most even plane that nothing straddles, or null when there is none.
(int, double, List<OrderLeaf>, List<OrderLeaf>)? _separator(
  List<OrderLeaf> leaves,
) {
  (int, double, List<OrderLeaf>, List<OrderLeaf>)? best;
  var bestScore = 1 << 30;
  for (var axis = 0; axis < 3; axis++) {
    double lo(OrderLeaf l) => switch (axis) {
      0 => l.bounds.x0,
      1 => l.bounds.y0,
      _ => l.bounds.z0,
    };
    double hi(OrderLeaf l) => switch (axis) {
      0 => l.bounds.x1,
      1 => l.bounds.y1,
      _ => l.bounds.z1,
    };
    final byHi = List<OrderLeaf>.of(leaves)
      ..sort((a, b) => hi(a).compareTo(hi(b)));
    // The smallest `lo` still to come, from each point in the sweep onward.
    final ahead = List<double>.filled(byHi.length, double.infinity);
    for (var i = byHi.length - 2; i >= 0; i--) {
      ahead[i] = math.min(ahead[i + 1], lo(byHi[i + 1]));
    }
    for (var k = 0; k < byHi.length - 1; k++) {
      final at = hi(byHi[k]);
      if (ahead[k] < at) continue;
      final score = ((k + 1) - (byHi.length - k - 1)).abs();
      if (score < bestScore) {
        bestScore = score;
        best = (axis, at, byHi.sublist(0, k + 1), byHi.sublist(k + 1));
      }
    }
  }
  return best;
}

/// Walks the order from where the camera stands, farthest first.
void walkOrder(Order node, V3 eye, void Function(OrderLeaf) visit) {
  if (node is OrderLeaf) {
    visit(node);
    return;
  }
  if (node is OrderBoth) {
    walkOrder(node.first, eye, visit);
    walkOrder(node.then, eye, visit);
    return;
  }
  final split = node as OrderSplit;
  final e = switch (split.axis) {
    0 => eye.x,
    1 => eye.y,
    _ => eye.z,
  };
  final near = e >= split.at ? split.high : split.low;
  final far = e >= split.at ? split.low : split.high;
  walkOrder(far, eye, visit);
  walkOrder(near, eye, visit);
}

/// Every face of a town in the exact order it will be painted, culled the way
/// the renderer culls it.
///
/// The renderer walks this same path inline while it shades and projects;
/// pulled out here it is what the angle test drives, so "does anything come
/// out in front of something it is behind?" is a question a machine answers on
/// every build instead of an eye catching it three releases later.
List<Facet> paintSequence(TownLayout layout, int placed, V3 eye) {
  final built = builtTown(layout, placed);
  final out = <Facet>[];
  final root = built.root;
  if (root == null) return out;
  walkOrder(root, eye, (leaf) {
    final c = leaf.cluster;
    if (c == null) return;
    c.tree.paint(eye, (f) {
      final a = f.v[0];
      if ((eye.x - a.x) * f.n.x +
              (eye.y - a.y) * f.n.y +
              (eye.z - a.z) * f.n.z <=
          0) {
        return;
      }
      out.add(f);
      final d = f.decals;
      if (d != null) out.addAll(d);
    });
  });
  return out;
}
