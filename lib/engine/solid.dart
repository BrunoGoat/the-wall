import 'dart:math' as math;

import '../core/math3.dart';

/// What a facet is made of.
///
/// Deliberately not a colour. The town is repainted every frame by the palette
/// of the hour, and a piece left alone weathers, so a colour baked into the
/// geometry would be a colour that is wrong by the afternoon. A facet says what
/// it is; the renderer says what that looks like right now.
enum Surface {
  /// Limewashed plaster: the walls of an ordinary house.
  wall,

  /// Masonry: plinths, piers, parapets, steps.
  stone,

  /// Straw: a roof with no line in it, thick at the eaves and blunt at the
  /// ridge. Its own surface because it is its own shape — thatch painted onto
  /// a tiled roof is a tiled roof the colour of straw.
  thatch,

  /// Whatever this town roofs with — tile or slate.
  tile,

  /// Chimney brick.
  brick,

  /// The dark of an opening you cannot see into.
  hollow,

  /// A window, which is lit or dark or boarded depending on how the habit is
  /// going. [Facet.data] is which window in its row, so the same ones go out
  /// first every time.
  window,

  /// Planks nailed over an abandoned window.
  plank,

  /// Foliage, which turns as the habit is neglected.
  leaf,

  /// A colour of its own, carried in [Facet.tint]: timber, bark, leaves, crop,
  /// water, cloth. Things whose colour is not the town's to decide.
  own,
}

/// One flat face of something built.
///
/// Vertices run counter-clockwise seen from outside, and [n] points out. The
/// winding is not used for painting — a filled polygon does not care which way
/// round it was written — but it is what makes "this solid is closed" a thing
/// that can be checked rather than hoped for, and a closed solid is the whole
/// reason a face can never go missing.
class Facet {
  Facet(
    List<V3> verts,
    this.n,
    this.surface, {
    this.ao = 1.0,
    this.tint,
    this.decals,
  }) : v = _facing(verts, n);

  /// Wound counter-clockwise seen from outside, whichever way round it was
  /// written.
  ///
  /// Every shape in the town has a mirror-image twin — a roof whose ridge runs
  /// the other way, a stair climbing the other direction — and writing both
  /// out by hand is writing one of them backwards. The normal is what was
  /// meant; the order follows it. Nothing paints differently for it, but
  /// "every edge is walked twice, once each way" is how a test knows a solid
  /// is shut, and a solid that is shut is one that cannot lose a face.
  /// The face's own normal, worked out from the face.
  ///
  /// Use this rather than writing one out by hand wherever the shape is not a
  /// plain box: a normal that is not square to its own face is not a shading
  /// nicety gone slightly wrong, it is a lie about where the face's plane is,
  /// and everything downstream — what is culled, how the tree is cut, what
  /// order things come out in — is built on that plane being the truth.
  static V3 normalOf(List<V3> verts, {V3 away = V3.zero}) {
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (var i = 0; i < verts.length; i++) {
      final a = verts[i], b = verts[(i + 1) % verts.length];
      nx += (a.y - b.y) * (a.z + b.z);
      ny += (a.z - b.z) * (a.x + b.x);
      nz += (a.x - b.x) * (a.y + b.y);
    }
    final n = V3(nx, ny, nz).normalized;
    var cx = 0.0, cy = 0.0, cz = 0.0;
    for (final p in verts) {
      cx += p.x;
      cy += p.y;
      cz += p.z;
    }
    final k = verts.length.toDouble();
    final out = V3(cx / k - away.x, cy / k - away.y, cz / k - away.z);
    return n.dot(out) >= 0 ? n : n * -1;
  }

  static List<V3> _facing(List<V3> verts, V3 n) {
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (var i = 0; i < verts.length; i++) {
      final a = verts[i], b = verts[(i + 1) % verts.length];
      nx += (a.y - b.y) * (a.z + b.z);
      ny += (a.z - b.z) * (a.x + b.x);
      nz += (a.x - b.x) * (a.y + b.y);
    }
    if (nx * nx + ny * ny + nz * nz < 1e-18) return verts;
    return nx * n.x + ny * n.y + nz * n.z >= 0
        ? verts
        : verts.reversed.toList();
  }

  final List<V3> v;
  final V3 n;
  final Surface surface;

  /// How shut in this face is: a wall top catches the whole sky, the underside
  /// of an arch catches very little.
  final double ao;

  /// ARGB, for [Surface.own].
  final int? tint;

  /// Faces lying exactly on this one, painted straight after it and never
  /// sorted against it. A window cannot fight its own wall for depth if the
  /// question is never asked.
  final List<Facet>? decals;

  /// Which window, which plank. Only the surfaces that need it read it.
  int data = 0;

  /// The achievement that laid the piece this face belongs to. Carried on the
  /// face itself because once the faces are filed into a tree they no longer
  /// arrive piece by piece, and the colour of a wall belongs to its house.
  int piece = 0;

  V3 get centroid {
    var x = 0.0, y = 0.0, z = 0.0;
    for (final p in v) {
      x += p.x;
      y += p.y;
      z += p.z;
    }
    final k = v.length.toDouble();
    return V3(x / k, y / k, z / k);
  }

  /// Signed distance of the facet's plane from the origin, so the plane is
  /// `n · p = d`.
  double get planeD => n.dot(v[0]);

  Facet withVerts(List<V3> nv, {List<Facet>? carrying}) =>
      Facet(nv, n, surface, ao: ao, tint: tint, decals: carrying)
        ..data = data
        ..piece = piece;
}

/// A closed thing that has been built. One piece of a building is one or more
/// of these.
class Solid {
  Solid(this.piece, this.faces);

  /// The achievement that laid it, so a tap can be resolved back to a day.
  final int piece;
  final List<Facet> faces;
}

/// An axis-aligned bounding box, which is how two things that do not touch are
/// ordered exactly rather than approximately.
class Aabb {
  Aabb(this.x0, this.y0, this.z0, this.x1, this.y1, this.z1);

  static Aabb? of(Iterable<Facet> faces) {
    var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
    var any = false;
    for (final f in faces) {
      for (final p in f.v) {
        any = true;
        if (p.x < x0) x0 = p.x;
        if (p.y < y0) y0 = p.y;
        if (p.z < z0) z0 = p.z;
        if (p.x > x1) x1 = p.x;
        if (p.y > y1) y1 = p.y;
        if (p.z > z1) z1 = p.z;
      }
    }
    return any ? Aabb(x0, y0, z0, x1, y1, z1) : null;
  }

  final double x0, y0, z0, x1, y1, z1;

  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;
  double get cz => (z0 + z1) / 2;

  Aabb union(Aabb o) => Aabb(
    math.min(x0, o.x0),
    math.min(y0, o.y0),
    math.min(z0, o.z0),
    math.max(x1, o.x1),
    math.max(y1, o.y1),
    math.max(z1, o.z1),
  );

  Aabb grown(double m) => Aabb(x0 - m, y0 - m, z0 - m, x1 + m, y1 + m, z1 + m);

  /// True when the two boxes overlap on all three axes, which is the one case
  /// where no separating plane exists and the two things have to be ordered
  /// together rather than against each other.
  bool overlaps(Aabb o) =>
      x0 < o.x1 &&
      o.x0 < x1 &&
      y0 < o.y1 &&
      o.y0 < y1 &&
      z0 < o.z1 &&
      o.z0 < z1;

  double get radius {
    final dx = x1 - x0, dy = y1 - y0, dz = z1 - z0;
    return math.sqrt(dx * dx + dy * dy + dz * dz) / 2;
  }
}
