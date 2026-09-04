import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/milestones.dart';
import '../data/pacing.dart';

/// What a stone is doing in the wall. Only used for shading and for the small
/// touches (a brazier on an ornament, a lantern in a niche).
enum SlotKind { body, capstone, merlon, tower, ornament, deck, recess }

/// A reserved position for exactly one stone.
class StoneSlot {
  StoneSlot({
    required this.brickIndex,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.zCenter,
    required this.halfDepth,
    required this.course,
    required this.kind,
    required this.structureIndex,
  }) : seed = hash32(brickIndex, 0x51ed, course);

  final int brickIndex;
  /// Centre of the stone's face.
  final double x, y;
  final double w, h;
  final double zCenter, halfDepth;
  final int course;
  final SlotKind kind;
  final int structureIndex;
  final int seed;

  double get top => y + h / 2;
  double get left => x - w / 2;
  double get right => x + w / 2;
}

/// A landmark placed in the wall, with the x-range it occupies.
class StructureInstance {
  StructureInstance({
    required this.index,
    required this.type,
    required this.x0,
    required this.x1,
    required this.firstBrick,
    required this.brickCount,
  });

  final int index;
  final MilestoneType type;
  final double x0, x1;
  final int firstBrick;
  final int brickCount;
  double peakY = 0;

  /// Points of interest that the little extras hang off: brazier bowls,
  /// lantern niches, bridge chains.
  double featureX = 0;
  double featureY = 0;
}

// ---------------------------------------------------------------- dimensions

class WallDims {
  const WallDims._();

  /// Four body courses, then the walkway capstone, then two merlon courses.
  static const List<double> courseHeights = [0.40, 0.38, 0.38, 0.36, 0.20, 0.22, 0.22];
  static const int bodyCourses = 4;
  static const int capstoneCourse = 4;
  static const int merlonLowCourse = 5;
  static const int totalCourses = 7;

  static const double minStoneW = 0.36;
  static const double maxStoneW = 1.04;

  /// Minimum horizontal offset between a stone and the joint below it, which is
  /// what stops the courses lining up into an obviously fake grid.
  static const double stagger = 0.20;

  static const double merlonPeriod = 1.52;
  static const double merlonWidth = 0.88;

  static double courseBottom(int c) {
    var y = 0.0;
    for (var i = 0; i < c && i < courseHeights.length; i++) {
      y += courseHeights[i];
    }
    return y;
  }

  static double courseCenter(int c) => courseBottom(c) + courseHeights[c] / 2;

  /// Walkway height: the top of the capstone course.
  static double get walkTop => courseBottom(capstoneCourse + 1);

  static double get merlonTop => courseBottom(totalCourses);

  /// The wall tapers as it rises. Half-thickness at a given height.
  static double halfDepthAtY(double y) {
    final t = clampD(y / walkTop, 0, 1);
    return lerpD(0.36, 0.315, t);
  }

  static double halfDepthForCourse(int c) {
    if (c >= merlonLowCourse) return 0.27;
    return halfDepthAtY(courseCenter(c));
  }
}

// ---------------------------------------------------------------- slab model

/// One solid mass of a structure, described by a 2D silhouette test plus how
/// thick the wall is at each x. Stones always run right through the thickness,
/// so a single stone reads correctly from both sides of the wall.
class Slab {
  Slab({
    required this.x0,
    required this.x1,
    required this.y0,
    required this.y1,
    required this.solid,
    required this.zCenter,
    required this.halfDepth,
    required this.kind,
    this.courseScale = 1.0,
    this.ornament = false,
    this.order = 0,
  });

  final double x0, x1, y0, y1;
  final bool Function(double x, double y) solid;
  final double Function(double x) zCenter;
  final double Function(double x) halfDepth;
  final SlotKind kind;
  final double courseScale;
  final bool ornament;
  final int order;
}

double _wallZ(double x) => 0;

// ---------------------------------------------------------------- the layout

/// Turns a brick count into concrete stone positions.
///
/// Deterministic and append-only: the first N slots for any N are always the
/// same, so a stone laid months ago never moves or changes shape.
class WallLayout {
  WallLayout(this.brickCount) {
    _build();
  }

  /// One extra slot is always produced so the app can show a ghost of where the
  /// next stone will land and fly the camera to it before it exists.
  final int brickCount;

  final List<StoneSlot> slots = [];
  final List<StructureInstance> structures = [];

  double length = 0;

  /// Sampled top profile of the whole wall, used for the distant silhouette.
  final List<double> profileTop = [];
  /// Top of the *solid* mass, ignoring merlons and ornaments, so the mortar
  /// core never fills in the gaps between the crenellations.
  final List<double> profileCore = [];
  /// Half-thickness and centre of the topmost solid stone in each bucket. The
  /// wall batters as it rises, so sizing the mortar core to the *thinnest*
  /// point keeps it hidden behind the stones at every height.
  final List<double> profileCoreHalf = [];
  final List<double> profileCoreZ = [];
  final List<double> profileDepth = [];
  double profileStep = 0.34;

  StoneSlot? slotFor(int brickIndex) =>
      brickIndex >= 0 && brickIndex < slots.length ? slots[brickIndex] : null;

  void _build() {
    final want = brickCount + 1;
    final plan = WallPlan(want + 8);
    final fill = List<double>.filled(WallDims.totalCourses, 0.0);
    var index = 0;

    for (final seg in plan.segments) {
      if (index >= want) break;
      if (seg.isMilestone) {
        final startX = _frontier(fill);
        final built = _buildStructure(
          seg,
          startX,
          index,
          want - index,
        );
        slots.addAll(built.slots);
        structures.add(built.instance);
        index += built.slots.length;
        final endX = built.instance.x1;
        for (var c = 0; c < fill.length; c++) {
          fill[c] = endX;
        }
        if (built.truncated) break;
      } else {
        for (var i = 0; i < seg.length && index < want; i++) {
          final slot = _placeRunStone(fill, index);
          slots.add(slot);
          index++;
        }
      }
    }

    // The visible length is what has actually been built, not how far the
    // frontier bookkeeping has advanced past a half-finished landmark.
    length = 0;
    for (final s in slots) {
      if (s.right > length) length = s.right;
    }
    _buildProfile();
  }

  double _frontier(List<double> fill) {
    var m = 0.0;
    for (final f in fill) {
      if (f > m) m = f;
    }
    return m;
  }

  // ------------------------------------------------------------- plain run

  /// Places one stone on the running rampart.
  ///
  /// The stone always goes to the *highest* course that can legally take it,
  /// which produces the stepped leading edge of a wall actually under
  /// construction rather than a flat row creeping along the ground.
  StoneSlot _placeRunStone(List<double> fill, int index) {
    // Real rubble courses mix the odd big block and the odd small one in
    // among the ordinary ones, which is most of what stops a wall reading as
    // a grid.
    final pick = hash01(index, 3);
    final double wBase;
    if (pick < 0.16) {
      wBase = hashRange(0.86, WallDims.maxStoneW, index, 11);
    } else if (pick > 0.86) {
      wBase = hashRange(WallDims.minStoneW, 0.50, index, 11);
    } else {
      wBase = lerpD(0.50, 0.86, hashBell(index, 11));
    }

    for (var c = WallDims.totalCourses - 1; c >= 0; c--) {
      final r = _tryCourse(fill, c, wBase, index);
      if (r != null) {
        fill[c] = r.$1 + r.$2;
        return StoneSlot(
          brickIndex: index,
          x: r.$1 + r.$2 / 2,
          y: WallDims.courseCenter(c),
          w: r.$2,
          h: WallDims.courseHeights[c] * (1 - 0.06 * hash01(index, 23)),
          zCenter: 0,
          halfDepth: WallDims.halfDepthForCourse(c),
          course: c,
          kind: c >= WallDims.merlonLowCourse
              ? SlotKind.merlon
              : (c == WallDims.capstoneCourse ? SlotKind.capstone : SlotKind.body),
          structureIndex: -1,
        );
      }
    }

    // Unreachable in practice: course 0 always accepts a stone.
    fill[0] += wBase;
    return StoneSlot(
      brickIndex: index,
      x: fill[0] - wBase / 2,
      y: WallDims.courseCenter(0),
      w: wBase,
      h: WallDims.courseHeights[0],
      zCenter: 0,
      halfDepth: WallDims.halfDepthForCourse(0),
      course: 0,
      kind: SlotKind.body,
      structureIndex: -1,
    );
  }

  /// Returns (startX, width) if course [c] can take a stone, else null.
  (double, double)? _tryCourse(List<double> fill, int c, double w, int index) {
    var xs = fill[c];

    if (c >= WallDims.merlonLowCourse) {
      // Merlon courses only exist inside the crenellation bands.
      final snapped = _snapToMerlonBand(xs);
      if (snapped == null) return null;
      xs = snapped;
      final bandEnd = _merlonBandEnd(xs);
      var ww = math.min(w, bandEnd - xs);
      if (ww < 0.16) {
        final next = _snapToMerlonBand(bandEnd + 0.001);
        if (next == null) return null;
        xs = next;
        ww = math.min(w, _merlonBandEnd(xs) - xs);
        if (ww < 0.16) return null;
      }
      if (xs + ww > fill[c - 1] - WallDims.stagger) return null;
      return (xs, ww);
    }

    if (c == 0) return (xs, w);
    if (xs + w > fill[c - 1] - WallDims.stagger) return null;
    return (xs, w);
  }

  static double? _snapToMerlonBand(double x) {
    final band = (x / WallDims.merlonPeriod).floor();
    final start = band * WallDims.merlonPeriod;
    if (x < start + WallDims.merlonWidth) return x;
    return (band + 1) * WallDims.merlonPeriod;
  }

  static double _merlonBandEnd(double x) {
    final band = (x / WallDims.merlonPeriod).floor();
    return band * WallDims.merlonPeriod + WallDims.merlonWidth;
  }

  // ------------------------------------------------------------ structures

  _BuiltStructure _buildStructure(
    PlanSegment seg,
    double startX,
    int firstIndex,
    int remaining,
  ) {
    final type = seg.type!;
    final spec = StructureShapes.build(type.kind, startX);
    final want = seg.length;
    final generated = _fillSlabs(spec.slabs, want, firstIndex, seg.milestoneNo);

    final inst = StructureInstance(
      index: structures.length,
      type: type,
      x0: startX,
      x1: startX + spec.length,
      firstBrick: seg.firstBrick,
      brickCount: want,
    );
    inst.featureX = startX + spec.featureX;
    inst.featureY = spec.featureY;
    for (final s in generated) {
      if (s.top > inst.peakY) inst.peakY = s.top;
    }

    final take = math.min(generated.length, remaining);
    final out = <StoneSlot>[];
    for (var i = 0; i < take; i++) {
      final g = generated[i];
      out.add(StoneSlot(
        brickIndex: firstIndex + i,
        x: g.x,
        y: g.y,
        w: g.w,
        h: g.h,
        zCenter: g.zCenter,
        halfDepth: g.halfDepth,
        course: (g.y / 0.38).floor(),
        kind: g.kind,
        structureIndex: inst.index,
      ));
    }
    return _BuiltStructure(out, inst, take < generated.length);
  }

  /// Fills a set of slabs with exactly [target] stones.
  ///
  /// Stone size is searched for rather than fixed, so a landmark always costs
  /// precisely the number of bricks the pacing promised, no matter its shape.
  List<_RawStone> _fillSlabs(List<Slab> slabs, int target, int seedA, int seedB) {
    // Stone count falls as the stones get bigger, so this searches for the
    // largest stone size that still yields at least [target] of them.
    var lo = 0.06, hi = 0.80;
    var best = _generate(slabs, lo, seedA, seedB);
    if (best.length < target) return best;
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      final g = _generate(slabs, mid, seedA, seedB);
      if (g.length >= target) {
        lo = mid;
        best = g;
      } else {
        hi = mid;
      }
    }
    if (best.length > target) best = best.sublist(0, target);
    return best;
  }

  List<_RawStone> _generate(List<Slab> slabs, double scale, int seedA, int seedB) {
    final out = <_RawStone>[];
    final ordered = [...slabs]..sort((a, b) => a.order.compareTo(b.order));
    var salt = 0;
    for (final slab in ordered) {
      final want = scale * slab.courseScale;
      if (want < 0.04) continue;
      // Divide the mass into a whole number of courses so it finishes exactly
      // at its own top: a leftover sliver leaves the crenellation floating.
      final courses = math.max(1, ((slab.y1 - slab.y0) / want).round());
      final ch = (slab.y1 - slab.y0) / courses;
      if (ch < 0.04) continue;
      for (var ci = 0; ci < courses; ci++) {
        final yb = slab.y0 + ci * ch;
        final yc = yb + ch / 2;
        // Find the solid intervals of this course.
        const step = 0.02;
        var x = slab.x0;
        double? runStart;
        while (x <= slab.x1 + step) {
          final inside = x <= slab.x1 && slab.solid(x, yc);
          if (inside && runStart == null) {
            runStart = x;
          } else if (!inside && runStart != null) {
            _fillRun(out, slab, runStart, x, yc, ch, scale, seedA, seedB, salt++);
            runStart = null;
          }
          x += step;
        }
        if (runStart != null) {
          _fillRun(out, slab, runStart, slab.x1, yc, ch, scale, seedA, seedB, salt++);
        }
      }
    }
    // Build the whole landmark bottom-up rather than mass by mass, so the
    // footprint rises together. Ornaments are always the final flourish.
    out.sort((a, b) {
      if (a.ornament != b.ornament) return a.ornament ? 1 : -1;
      final ba = (a.y / 0.16).floor();
      final bb = (b.y / 0.16).floor();
      if (ba != bb) return ba.compareTo(bb);
      if (a.slabOrder != b.slabOrder) return a.slabOrder.compareTo(b.slabOrder);
      return a.x.compareTo(b.x);
    });
    return out;
  }

  void _fillRun(
    List<_RawStone> out,
    Slab slab,
    double a,
    double b,
    double yc,
    double ch,
    double scale,
    int seedA,
    int seedB,
    int salt,
  ) {
    final span = b - a;
    if (span < ch * 0.55) return;
    final targetW = ch * 1.75;
    var n = (span / targetW).round();
    if (n < 1) n = 1;
    final base = span / n;
    var cursor = a;
    for (var i = 0; i < n; i++) {
      var w = base;
      if (n > 1) {
        w = base * (1 + hashJitter(0.16, seedA, seedB, salt, i));
        if (i == n - 1) w = b - cursor;
      }
      if (w <= 0.02) continue;
      final xc = cursor + w / 2;
      out.add(_RawStone(
        x: xc,
        y: yc,
        w: w,
        h: ch * (1 - 0.05 * hash01(seedA, seedB, salt, i + 91)),
        zCenter: slab.zCenter(xc),
        halfDepth: slab.halfDepth(xc),
        kind: slab.kind,
        ornament: slab.ornament,
        slabOrder: slab.order,
      ));
      cursor += w;
    }
  }

  // -------------------------------------------------------------- profile

  /// Coarse top profile of the entire wall, so the far distance can be drawn as
  /// a receding silhouette instead of thousands of invisible stones.
  void _buildProfile() {
    profileStep = 0.34;
    final n = (length / profileStep).ceil() + 2;
    profileTop
      ..clear()
      ..addAll(List<double>.filled(n, 0));
    profileCore
      ..clear()
      ..addAll(List<double>.filled(n, 0));
    profileCoreHalf
      ..clear()
      ..addAll(List<double>.filled(n, 0.4));
    profileCoreZ
      ..clear()
      ..addAll(List<double>.filled(n, 0));
    profileDepth
      ..clear()
      ..addAll(List<double>.filled(n, 0));
    for (final s in slots) {
      final i0 = (s.left / profileStep).floor().clamp(0, n - 1);
      final i1 = (s.right / profileStep).ceil().clamp(0, n - 1);
      final solid = s.kind != SlotKind.merlon &&
          s.kind != SlotKind.ornament &&
          s.kind != SlotKind.deck;
      for (var i = i0; i <= i1; i++) {
        if (s.top > profileTop[i]) profileTop[i] = s.top;
        if (solid && s.top > profileCore[i]) {
          profileCore[i] = s.top;
          profileCoreHalf[i] = s.halfDepth;
          profileCoreZ[i] = s.zCenter;
        }
        final d = s.zCenter.abs() + s.halfDepth;
        if (d > profileDepth[i]) profileDepth[i] = d;
      }
    }
  }
}

class _BuiltStructure {
  _BuiltStructure(this.slots, this.instance, this.truncated);
  final List<StoneSlot> slots;
  final StructureInstance instance;
  final bool truncated;
}

class _RawStone {
  _RawStone({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.zCenter,
    required this.halfDepth,
    required this.kind,
    required this.ornament,
    required this.slabOrder,
  });
  final double x, y, w, h, zCenter, halfDepth;
  final SlotKind kind;
  final bool ornament;
  final int slabOrder;

  double get top => y + h / 2;
}

// ------------------------------------------------------------ the landmarks

class StructureSpec {
  StructureSpec(this.slabs, this.length, this.featureX, this.featureY);
  final List<Slab> slabs;
  final double length;
  final double featureX, featureY;
}

/// Ten genuinely different silhouettes. Each one is a set of solid masses that
/// the filler turns into stones; none of them is the same box at another scale.
class StructureShapes {
  const StructureShapes._();

  static StructureSpec build(MilestoneKind kind, double x0) {
    switch (kind) {
      case MilestoneKind.watchtower:
        return _watchtower(x0);
      case MilestoneKind.gate:
        return _gate(x0);
      case MilestoneKind.greatTower:
        return _greatTower(x0);
      case MilestoneKind.stair:
        return _stair(x0);
      case MilestoneKind.drawbridge:
        return _drawbridge(x0);
      case MilestoneKind.beacon:
        return _beacon(x0);
      case MilestoneKind.bastion:
        return _bastion(x0);
      case MilestoneKind.aqueduct:
        return _aqueduct(x0);
      case MilestoneKind.shrine:
        return _shrine(x0);
      case MilestoneKind.barbican:
        return _barbican(x0);
    }
  }

  static double get _wallTop => WallDims.walkTop;

  /// A crenellated cap: merlons with gaps, used as the final flourish.
  static Slab _crenellation(
    double x0,
    double x1,
    double yBase,
    double height,
    double depth, {
    double period = 0.62,
    double duty = 0.58,
    int order = 90,
  }) {
    return Slab(
      x0: x0,
      x1: x1,
      y0: yBase,
      y1: yBase + height,
      solid: (x, y) {
        final t = (x - x0) % period;
        return t < period * duty;
      },
      zCenter: (x) => 0,
      halfDepth: (x) => depth,
      kind: SlotKind.merlon,
      courseScale: 0.72,
      ornament: true,
      order: order,
    );
  }

  static bool _archHole(double x, double y, double cx, double r, double spring) {
    if (y < 0) return false;
    if (y <= spring) return (x - cx).abs() <= r;
    final dy = y - spring;
    if (dy > r) return false;
    final half = math.sqrt(math.max(0.0, r * r - dy * dy));
    return (x - cx).abs() <= half;
  }

  // ---- 1. Watchtower: a compact turret straddling the rampart.
  static StructureSpec _watchtower(double x0) {
    const len = 2.35;
    const ta = 0.5, tb = 1.85, top = 3.35;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => (x - x0 < ta || x - x0 > tb),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0, y1: top,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => 0.56,
        kind: SlotKind.tower,
        order: 1,
      ),
      _crenellation(x0 + ta - 0.06, x0 + tb + 0.06, top, 0.44, 0.496, period: 0.52),
      _crenellation(x0, x0 + ta, _wallTop, 0.34, 0.272, period: 0.5, order: 91),
      _crenellation(x0 + tb, x0 + len, _wallTop, 0.34, 0.272, period: 0.5, order: 91),
    ], len, (ta + tb) / 2, top + 0.44);
  }

  // ---- 2. Gate: an arched way through, with heavy jambs.
  static StructureSpec _gate(double x0) {
    const len = 2.9;
    const bandTop = 2.05;
    const cx = 1.45, r = 0.46, spring = 1.05;
    bool jamb(double x) {
      final u = x - x0;
      return (u > 0.72 && u < 0.99) || (u > 1.91 && u < 2.18);
    }
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: bandTop,
        solid: (x, y) => !jamb(x) && !_archHole(x - x0, y, cx, r, spring),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + 0.72, x1: x0 + 2.18, y0: 0, y1: bandTop,
        solid: (x, y) => jamb(x),
        zCenter: _wallZ,
        halfDepth: (x) => 0.48,
        kind: SlotKind.tower,
        order: 1,
      ),
      _crenellation(x0, x0 + len, bandTop, 0.42, 0.32, period: 0.56),
    ], len, cx, spring + r);
  }

  // ---- 3. Great tower: the thing you can see from the far end of the wall.
  static StructureSpec _greatTower(double x0) {
    const len = 3.05;
    const ta = 0.42, tb = 2.63, top = 4.25;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => (x - x0 < ta || x - x0 > tb),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0, y1: top,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => 0.784,
        kind: SlotKind.tower,
        order: 1,
      ),
      // A machicolation: the overhang just under the parapet.
      Slab(
        x0: x0 + ta - 0.12, x1: x0 + tb + 0.12, y0: top, y1: top + 0.24,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => 0.88,
        kind: SlotKind.ornament,
        courseScale: 0.7,
        ornament: true,
        order: 89,
      ),
      _crenellation(x0 + ta - 0.12, x0 + tb + 0.12, top + 0.24, 0.5, 0.82, period: 0.58),
    ], len, (ta + tb) / 2, top + 0.74);
  }

  // ---- 4. Stair: a flight climbing the front face up to the walkway.
  static StructureSpec _stair(double x0) {
    const len = 2.65;
    const runStart = 0.25, runEnd = 2.35;
    double stepTop(double u) {
      final t = clampD((u - runStart) / (runEnd - runStart), 0, 1);
      const steps = 6;
      return _wallTop * ((t * steps).floor() + 1) / steps;
    }
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + runStart, x1: x0 + runEnd, y0: 0, y1: _wallTop,
        solid: (x, y) => y <= stepTop(x - x0),
        zCenter: (x) => 0.66,
        halfDepth: (x) => 0.208,
        kind: SlotKind.tower,
        courseScale: 0.8,
        order: 1,
      ),
      _crenellation(x0, x0 + len, _wallTop, 0.36, 0.288, period: 0.54),
    ], len, (runStart + runEnd) / 2, _wallTop);
  }

  // ---- 5. Drawbridge: two gate towers, a void, and a deck lowered across it.
  static StructureSpec _drawbridge(double x0) {
    const len = 3.5;
    const la = 0.72, lb = 1.34, ra = 2.16, rb = 2.78, ttop = 2.62;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) {
          final u = x - x0;
          return u < la || u > rb;
        },
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + la, x1: x0 + rb, y0: 0, y1: ttop,
        solid: (x, y) {
          final u = x - x0;
          return (u >= la && u <= lb) || (u >= ra && u <= rb);
        },
        zCenter: _wallZ,
        halfDepth: (x) => 0.512,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The lintel bridging the two towers above the passage.
      Slab(
        x0: x0 + lb, x1: x0 + ra, y0: 1.44, y1: _wallTop,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => 0.32,
        kind: SlotKind.body,
        order: 2,
      ),
      // The deck itself, laid down last.
      Slab(
        x0: x0 + lb - 0.04, x1: x0 + ra + 0.04, y0: 0.96, y1: 1.16,
        solid: (x, y) => true,
        zCenter: (x) => 0.70,
        halfDepth: (x) => 0.088,
        kind: SlotKind.deck,
        courseScale: 0.6,
        ornament: true,
        order: 88,
      ),
      _crenellation(x0 + la, x0 + lb, ttop, 0.4, 0.448, period: 0.5),
      _crenellation(x0 + ra, x0 + rb, ttop, 0.4, 0.448, period: 0.5, order: 91),
    ], len, (lb + ra) / 2, 1.16);
  }

  // ---- 6. Beacon: a slim shaft with a fire bowl on top.
  static StructureSpec _beacon(double x0) {
    const len = 2.05;
    const sa = 0.62, sb = 1.42, top = 2.95;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => (x - x0 < sa || x - x0 > sb),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + sa, x1: x0 + sb, y0: 0, y1: top,
        solid: (x, y) => true,
        zCenter: _wallZ,
        halfDepth: (x) => 0.416,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The flared bowl that holds the fire.
      Slab(
        x0: x0 + sa - 0.22, x1: x0 + sb + 0.22, y0: top, y1: top + 0.34,
        solid: (x, y) {
          final t = (y - top) / 0.34;
          final half = lerpD(0.40, 0.62, t);
          return (x - (x0 + (sa + sb) / 2)).abs() <= half;
        },
        zCenter: _wallZ,
        halfDepth: (x) => 0.464,
        kind: SlotKind.ornament,
        courseScale: 0.6,
        ornament: true,
        order: 88,
      ),
      _crenellation(x0, x0 + sa, _wallTop, 0.34, 0.272, period: 0.5, order: 91),
      _crenellation(x0 + sb, x0 + len, _wallTop, 0.34, 0.272, period: 0.5, order: 92),
    ], len, (sa + sb) / 2, top + 0.4);
  }

  // ---- 7. Bastion: an angular mass shouldering out of the wall line.
  static StructureSpec _bastion(double x0) {
    const len = 3.65;
    const ba = 0.48, bb = 3.15, btop = 2.08;
    double bump(double u) {
      final t = clampD((u - ba) / (bb - ba), 0, 1);
      if (t < 0.28) return t / 0.28;
      if (t > 0.72) return (1 - t) / 0.28;
      return 1;
    }
    double front(double x) => 0.34 + 0.74 * bump(x - x0);
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => (x - x0 < ba || x - x0 > bb),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: 0, y1: btop,
        solid: (x, y) => true,
        zCenter: (x) => (front(x) - 0.34) / 2,
        halfDepth: (x) => (front(x) + 0.34) / 2,
        kind: SlotKind.tower,
        order: 1,
      ),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: btop, y1: btop + 0.46,
        solid: (x, y) {
          final t = (x - x0 - ba) / (bb - ba);
          final u = (t * 7.2) % 1.0;
          return u < 0.6;
        },
        zCenter: (x) => (front(x) - 0.34) / 2,
        halfDepth: (x) => (front(x) + 0.34) / 2 * 0.92,
        kind: SlotKind.merlon,
        courseScale: 0.7,
        ornament: true,
        order: 90,
      ),
      _crenellation(x0, x0 + ba, _wallTop, 0.34, 0.272, period: 0.5, order: 91),
      _crenellation(x0 + bb, x0 + len, _wallTop, 0.34, 0.272, period: 0.5, order: 92),
    ], len, (ba + bb) / 2, btop + 0.46);
  }

  // ---- 8. Arcade: three spans of arches carrying the wall over a low place.
  static StructureSpec _aqueduct(double x0) {
    const len = 4.05;
    const top = 2.15;
    const centers = [0.88, 2.02, 3.16];
    const r = 0.42, spring = 0.92;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: top,
        solid: (x, y) {
          final u = x - x0;
          for (final c in centers) {
            if (_archHole(u, y, c, r, spring)) return false;
          }
          return true;
        },
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      _crenellation(x0, x0 + len, top, 0.4, 0.32, period: 0.58),
    ], len, centers[1], spring + r);
  }

  // ---- 9. Shrine: a niche cut into the wall, with its back set deep.
  static StructureSpec _shrine(double x0) {
    const len = 2.1;
    const nx0 = 0.78, nx1 = 1.32, ny0 = 0.42, ny1 = 1.18;
    bool niche(double u, double y) {
      if (y < ny0) return false;
      if (u < nx0 || u > nx1) return false;
      if (y <= ny1) return true;
      final dy = y - ny1;
      const r = 0.27;
      if (dy > r) return false;
      final half = math.sqrt(math.max(0.0, r * r - dy * dy));
      return (u - (nx0 + nx1) / 2).abs() <= half;
    }
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) => !niche(x - x0, y),
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      // The recessed back of the niche.
      Slab(
        x0: x0 + nx0, x1: x0 + nx1, y0: ny0, y1: ny1 + 0.27,
        solid: (x, y) => niche(x - x0, y),
        zCenter: (x) => -0.20,
        halfDepth: (x) => 0.16,
        kind: SlotKind.recess,
        courseScale: 0.62,
        order: 1,
      ),
      // A small pedestal standing in the niche.
      Slab(
        x0: x0 + nx0 + 0.14, x1: x0 + nx1 - 0.14, y0: ny0, y1: ny0 + 0.2,
        solid: (x, y) => true,
        zCenter: (x) => 0.06,
        halfDepth: (x) => 0.112,
        kind: SlotKind.ornament,
        courseScale: 0.5,
        ornament: true,
        order: 88,
      ),
      _crenellation(x0, x0 + len, _wallTop, 0.36, 0.288, period: 0.52),
    ], len, (nx0 + nx1) / 2, ny1);
  }

  // ---- 10. Barbican: two towers guarding one arch. A proper piece of work.
  static StructureSpec _barbican(double x0) {
    const len = 4.3;
    const la = 0.5, lb = 1.42, ra = 2.88, rb = 3.8, ttop = 3.05;
    const curtainTop = 2.15, cx = 2.15, r = 0.5, spring = 1.12;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: _wallTop,
        solid: (x, y) {
          final u = x - x0;
          return u < la || u > rb;
        },
        zCenter: _wallZ,
        halfDepth: (x) => WallDims.halfDepthAtY(_wallTop * 0.5),
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + la, x1: x0 + rb, y0: 0, y1: ttop,
        solid: (x, y) {
          final u = x - x0;
          return (u >= la && u <= lb) || (u >= ra && u <= rb);
        },
        zCenter: _wallZ,
        halfDepth: (x) => 0.544,
        kind: SlotKind.tower,
        order: 1,
      ),
      Slab(
        x0: x0 + lb, x1: x0 + ra, y0: 0, y1: curtainTop,
        solid: (x, y) => !_archHole(x - x0, y, cx, r, spring),
        zCenter: _wallZ,
        halfDepth: (x) => 0.368,
        kind: SlotKind.body,
        order: 2,
      ),
      _crenellation(x0 + lb, x0 + ra, curtainTop, 0.4, 0.352, period: 0.54, order: 89),
      _crenellation(x0 + la, x0 + lb, ttop, 0.44, 0.48, period: 0.5, order: 90),
      _crenellation(x0 + ra, x0 + rb, ttop, 0.44, 0.48, period: 0.5, order: 91),
    ], len, cx, spring + r);
  }
}
