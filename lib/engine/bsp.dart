import '../core/math3.dart';
import 'solid.dart';

/// A binary space partition of one cluster of built things.
///
/// This is what replaced sorting. The old renderer gave every face a single
/// number — how far away its middle was — dropped them all in a heap and
/// painted them in that order. That is only ever right when no two faces
/// overlap in depth, and the moment they do there is no correct order of the
/// two: half of a chimney is nearer than the middle of the slope it stands on
/// and half is further, so whichever way round you paint them, one half is
/// wrong, and which half changes as the camera swings.
///
/// A BSP asks a different question. Every face is filed against a plane, and
/// anything straddling that plane is *cut* at it, once, when the building is
/// built. After that, from any camera position anywhere, walking the tree
/// far-side-first gives an order that is exactly right, with no sorting, no
/// bias and nothing forced in front of anything. The chimney comes out of the
/// roof from every angle because the roof was cut along the chimney's own
/// planes and each piece of it is wholly in front of the brick or wholly
/// behind it.
///
/// The town is append-only and never moves, so all of this is paid once, when
/// an achievement lays a piece — not sixty times a second.
class BspTree {
  BspTree._(this._root, this.facets);

  final _Node? _root;

  /// How many faces the tree ended up holding — cuts and hung decals included,
  /// because what the frame pays for is every polygon it fills. Watched by the
  /// exhibition hall: a build that suddenly costs twice the faces means a
  /// splitting plane was chosen badly.
  final int facets;

  static BspTree build(List<Facet> faces) {
    var count = 0;
    final root = _build(faces, 0, (n) => count += n);
    return BspTree._(root, count);
  }

  /// Walks the tree far to near from [eye], handing every face to [emit] in
  /// the order it must be painted.
  void paint(V3 eye, void Function(Facet) emit) {
    final n = _root;
    if (n != null) _walk(n, eye, emit);
  }

  static void _walk(_Node node, V3 eye, void Function(Facet) emit) {
    final side = node.n.dot(eye) - node.d;
    final near = side >= 0 ? node.front : node.back;
    final far = side >= 0 ? node.back : node.front;
    if (far != null) _walk(far, eye, emit);
    for (final f in node.on) {
      emit(f);
    }
    if (near != null) _walk(near, eye, emit);
  }
}

class _Node {
  _Node(this.n, this.d);
  final V3 n;
  final double d;
  final List<Facet> on = [];
  _Node? front, back;
}

const double _eps = 1e-4;

_Node? _build(List<Facet> faces, int depth, void Function(int) tally) {
  if (faces.isEmpty) return null;
  final pick = _choose(faces, depth);
  final node = _Node(pick.n, pick.planeD);
  final front = <Facet>[];
  final back = <Facet>[];
  for (final f in faces) {
    switch (_classify(f, node.n, node.d)) {
      case _Side.on:
        node.on.add(f);
      case _Side.front:
        front.add(f);
      case _Side.back:
        back.add(f);
      case _Side.spanning:
        // A last resort, and one nothing in the town reaches: every face is
        // flat and every plane comes from a face, so the recursion always gets
        // somewhere. This is here so a bad recipe cannot take the stack with
        // it, not because it is expected to fire — and it is set well past
        // where two domes running through each other need to go, because
        // stopping early there is exactly how one of them came out in front of
        // the other.
        if (depth > 300) {
          front.add(f);
          break;
        }
        final cut = _split(f, node.n, node.d);
        if (cut.$1 != null) front.add(cut.$1!);
        if (cut.$2 != null) back.add(cut.$2!);
    }
  }
  if (node.on.isEmpty &&
      (front.length >= faces.length || back.length >= faces.length)) {
    // No plane in this batch separates anything — which can only happen if a
    // face is not flat. Stop rather than recur for ever; the geometry test is
    // what stops it happening at all.
    node.on.addAll(faces);
    var loose = faces.length;
    for (final f in faces) {
      loose += f.decals?.length ?? 0;
    }
    tally(loose);
    return node;
  }
  var cost = node.on.length;
  for (final f in node.on) {
    cost += f.decals?.length ?? 0;
  }
  tally(cost);
  node.front = _build(front, depth + 1, tally);
  node.back = _build(back, depth + 1, tally);
  return node;
}

/// Picks the plane to file this batch against.
///
/// Cheapest first: the fewer faces a plane cuts in two the smaller the tree
/// and the fewer faces the frame has to paint. A balanced tree matters much
/// less than an uncut one here, because a building is thirty faces and not
/// thirty thousand. Axis-aligned planes win ties, because nearly everything in
/// the town is a box and a box's own planes cut nothing.
Facet _choose(List<Facet> faces, int depth) {
  if (faces.length == 1) return faces.first;
  // Try every face's plane when there are few enough of them, which there
  // nearly always are: a cut that could have been avoided is a face the frame
  // pays for from now on, and a building is thirty faces, not thirty thousand.
  final step = faces.length <= 96 ? 1 : faces.length ~/ 96;
  Facet? best;
  var bestScore = double.infinity;
  for (var i = 0; i < faces.length; i += step) {
    final c = faces[i];
    final n = c.n;
    final d = c.planeD;
    var splits = 0, f = 0, b = 0, on = 0;
    for (final o in faces) {
      switch (_classify(o, n, d)) {
        case _Side.on:
          on++;
        case _Side.front:
          f++;
        case _Side.back:
          b++;
        case _Side.spanning:
          splits++;
      }
    }
    if (f == 0 && b == 0 && splits == 0 && on == faces.length && depth > 0) {
      // Everything is on this plane; it separates nothing.
      continue;
    }
    final axis = (n.x.abs() > 0.999 || n.y.abs() > 0.999 || n.z.abs() > 0.999);
    final score = splits * 9.0 + (f - b).abs() * 0.5 + (axis ? 0.0 : 1.5);
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best ?? faces.first;
}

enum _Side { on, front, back, spanning }

_Side _classify(Facet f, V3 n, double d) {
  var front = false, back = false;
  for (final p in f.v) {
    final s = n.dot(p) - d;
    if (s > _eps) front = true;
    if (s < -_eps) back = true;
  }
  if (front && back) return _Side.spanning;
  if (front) return _Side.front;
  if (back) return _Side.back;
  return _Side.on;
}

/// Cuts a facet in two at a plane. This is the one place geometry is created,
/// and it happens when the piece is laid, never while drawing.
(Facet?, Facet?) _split(Facet f, V3 n, double d) => _cut(f, n, d, true);

(Facet?, Facet?) _split2(Facet f, V3 n, double d) => _cut(f, n, d, false);

(Facet?, Facet?) _cut(Facet f, V3 n, double d, bool withDecals) {
  final front = <V3>[];
  final back = <V3>[];
  final v = f.v;
  for (var i = 0; i < v.length; i++) {
    final a = v[i], b = v[(i + 1) % v.length];
    final sa = n.dot(a) - d, sb = n.dot(b) - d;
    if (sa >= -_eps) front.add(a);
    if (sa <= _eps) back.add(a);
    if ((sa > _eps && sb < -_eps) || (sa < -_eps && sb > _eps)) {
      final t = sa / (sa - sb);
      final p = V3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );
      front.add(p);
      back.add(p);
    }
  }
  // What is hung on the face is cut with it. Handing the whole row of windows
  // to both halves paints each of them twice, and the second copy takes its
  // turn wherever its half of the wall ended up in the tree — which is a
  // window drawn on the wrong side of the house.
  List<Facet>? frontDecals, backDecals;
  final hung = withDecals ? f.decals : null;
  if (hung != null) {
    for (final g in hung) {
      final cut = _split2(g, n, d);
      if (cut.$1 != null) (frontDecals ??= <Facet>[]).add(cut.$1!);
      if (cut.$2 != null) (backDecals ??= <Facet>[]).add(cut.$2!);
    }
  }
  return (
    front.length >= 3 ? f.withVerts(front, carrying: frontDecals) : null,
    back.length >= 3 ? f.withVerts(back, carrying: backDecals) : null,
  );
}
