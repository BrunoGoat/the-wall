import 'dart:math' as math;
import 'dart:typed_data';

import '../core/math3.dart';
import '../core/rng.dart';
import 'layout.dart';

/// The silhouette of one stone, in normalised face coordinates.
///
/// Every stone is a genuinely different irregular polygon — not one rectangle
/// scaled up and down. Corners are pulled in by different amounts, extra
/// vertices appear along random edges, and corners get chipped, which is what
/// makes a run of them read as rubble masonry instead of brickwork.
class StoneProfile {
  StoneProfile(this.pts);

  /// x,y pairs in roughly [-0.5, 0.5].
  final Float32List pts;
  int get count => pts.length ~/ 2;
}

class StoneProfiles {
  StoneProfiles._();
  static final StoneProfiles instance = StoneProfiles._();

  /// A deep pool so repetition is not perceivable; combined with the mirror
  /// flip below this is effectively 8192 distinct silhouettes, on top of every
  /// stone having its own width and height.
  static const int poolSize = 4096;
  final List<StoneProfile?> _pool = List.filled(poolSize, null);

  StoneProfile forSeed(int seed) {
    final i = seed & (poolSize - 1);
    final cached = _pool[i];
    if (cached != null) return cached;
    final made = _make(i);
    _pool[i] = made;
    return made;
  }

  StoneProfile _make(int s) {
    // Walk the four sides of a unit rectangle. Courses in real masonry sit on
    // thin, level beds while the vertical joints wander, so the horizontal
    // edges are kept tight and nearly all the irregularity is spent sideways.
    final xs = <double>[];
    final ys = <double>[];

    const corners = [
      [-0.5, -0.5],
      [0.5, -0.5],
      [0.5, 0.5],
      [-0.5, 0.5],
    ];

    for (var c = 0; c < 4; c++) {
      final cur = corners[c];
      final nxt = corners[(c + 1) % 4];
      final inX = cur[0] > 0 ? -1.0 : 1.0;
      final inY = cur[1] > 0 ? -1.0 : 1.0;

      if (hash01(s, c, 7) < 0.30) {
        // A knocked-off corner: two vertices instead of one, one on the edge
        // arriving at this corner and one on the edge leaving it.
        //
        // The order matters and is not the same at every corner. Corners 1 and
        // 3 are arrived at along a bed joint and left up a side; corners 0 and
        // 2 are the other way round. Emitted in the wrong order the two points
        // double back on each other and the silhouette crosses itself — and a
        // polygon that crosses itself extrudes into a prism whose faces face
        // inwards along the crossing. That is what left the odd stone looking
        // like an open crate with no lid: it was not a shading fault or a
        // sorting fault, the top of the stone genuinely faced the wrong way.
        final alongEdge = cur[0] + inX * hashRange(0.04, 0.11, s, c, 11);
        final nearEdge = cur[1] + inY * hashRange(0.002, 0.010, s, c, 13);
        final alongSide = cur[1] + inY * hashRange(0.015, 0.045, s, c, 12);
        final nearSide = cur[0] + inX * hashRange(0.003, 0.015, s, c, 14);
        if (c == 1 || c == 3) {
          xs.add(alongEdge);
          ys.add(nearEdge);
          xs.add(nearSide);
          ys.add(alongSide);
        } else {
          xs.add(nearSide);
          ys.add(alongSide);
          xs.add(alongEdge);
          ys.add(nearEdge);
        }
      } else {
        xs.add(cur[0] + inX * hashRange(0.003, 0.040, s, c, 15));
        ys.add(cur[1] + inY * hashRange(0.002, 0.014, s, c, 16));
      }

      // Break the straight run between two corners. The next edge runs from
      // `cur` to `nxt`; edges 0 and 2 are the bed joints, 1 and 3 the sides.
      final horizontal = c == 0 || c == 2;
      final bumps = hash01(s, c, 21) < (horizontal ? 0.34 : 0.70) ? 1 : 0;
      for (var b = 0; b < bumps; b++) {
        final t = hashRange(0.32, 0.68, s, c, 30 + b);
        final mx = cur[0] + (nxt[0] - cur[0]) * t;
        final my = cur[1] + (nxt[1] - cur[1]) * t;
        // Always displaced inwards: a stone that bulged past its slot would
        // overlap its neighbour and fight with it for the same pixels.
        final amp = horizontal ? 0.010 : 0.038;
        final d = hashRange(-amp, 0.0, s, c, 40 + b);
        final ex = nxt[0] - cur[0];
        final ey = nxt[1] - cur[1];
        final el = math.sqrt(ex * ex + ey * ey);
        final nx = -ey / el;
        final ny = ex / el;
        // The outward normal of this edge points away from the centre.
        final sign = (mx * nx + my * ny) >= 0 ? 1.0 : -1.0;
        xs.add(mx + nx * sign * d);
        ys.add(my + ny * sign * d);
      }
    }

    final out = Float32List(xs.length * 2);
    for (var i = 0; i < xs.length; i++) {
      out[i * 2] = xs[i];
      out[i * 2 + 1] = ys[i];
    }
    return StoneProfile(out);
  }
}

class StoneMesh {
  StoneMesh(int maxVerts)
      : front = Float64List(maxVerts * 3),
        back = Float64List(maxVerts * 3),
        camFront = Float64List(maxVerts * 3),
        camBack = Float64List(maxVerts * 3);

  final Float64List front, back, camFront, camBack;
  int n = 0;

  /// Builds the world-space prism for [slot].
  ///
  /// Stones run right through the thickness of the wall, so a single stone
  /// reads correctly from the front, from behind and from above — one
  /// achievement is always exactly one visible stone.
  void build(
    StoneSlot slot,
    StoneProfile profile, {
    double yOffset = 0,
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
    double erosion = 0,
    bool mirror = false,
    double joint = 0.005,
    double relief = 1.0,
  }) {
    n = profile.count;
    final w = math.max(0.04, slot.w - joint * 2) * scaleX * (1 - erosion * 0.10);
    final h = math.max(0.04, slot.h - joint * 2) * scaleY * (1 - erosion * 0.10);
    final cr = math.cos(rotation), sr = math.sin(rotation);
    // Rubble masonry never sits flush: letting each stone stand a little
    // proud of its neighbours is what makes the face read as stone rather than
    // as tiles on a slab.
    final proud = hashRange(-0.005, 0.020, slot.seed, 71) * relief;
    final zf = slot.zCenter + slot.halfDepth + proud;
    final zb = slot.zCenter - slot.halfDepth - proud * 0.35;
    // The back face is fractionally smaller, so the side faces catch the light
    // at a slight angle instead of reading as a flat cut.
    const taper = 0.94;

    for (var i = 0; i < n; i++) {
      // Mirroring doubles the number of distinct silhouettes, but negating x
      // also reverses the polygon's winding — and the side faces derive their
      // outward normals from that winding. Walking the profile backwards puts
      // the winding back, so a mirrored stone is still solid instead of having
      // its top face culled and its underside lit.
      final src = mirror ? (n - 1 - i) : i;
      var px = profile.pts[src * 2].toDouble();
      final py = profile.pts[src * 2 + 1].toDouble();
      if (mirror) px = -px;
      final lx = px * w;
      final ly = py * h;
      final rx = lx * cr - ly * sr;
      final ry = lx * sr + ly * cr;

      front[i * 3] = slot.x + rx;
      front[i * 3 + 1] = slot.y + ry + yOffset;
      front[i * 3 + 2] = zf;

      back[i * 3] = slot.x + rx * taper;
      back[i * 3 + 1] = slot.y + ry * taper + yOffset;
      back[i * 3 + 2] = zb;
    }
  }

  void toCamera(Projector p) {
    for (var i = 0; i < n; i++) {
      p.toCamera(front[i * 3], front[i * 3 + 1], front[i * 3 + 2], camFront, i * 3);
      p.toCamera(back[i * 3], back[i * 3 + 1], back[i * 3 + 2], camBack, i * 3);
    }
  }
}
