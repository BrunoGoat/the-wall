import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/milestones.dart';
import '../data/pacing.dart';
import 'structures.dart';

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

/// How the wall is stacked, and how it grows taller over a lifetime.
///
/// The wall does not only run: every so often it gains a whole storey. When a
/// tier opens, the next bricks go back to the beginning and raise the entire
/// length that already exists — a levelling course over the old parapet, then
/// new body courses, then a new walkway and new crenellations on top.
///
/// Crucially this never moves a stone that is already laid. Which courses are
/// available is a function of the brick's own index, so the first N bricks lay
/// out exactly as they always did; the tier only ever opens *more* room above.
class WallTiers {
  const WallTiers._();

  /// Brick counts at which the wall gains a storey.
  static const List<int> thresholds = [100, 350, 900];

  static const int maxTier = 3;

  /// The courses each tier opens, bottom to top.
  ///
  /// Every tier reads the same way: a levelling course over the crenellations
  /// below (the ground tier has none to level), then body courses, then a
  /// walkway capstone, then two courses of merlons. Each tier adds fewer body
  /// courses than the one before, so the wall keeps climbing without running
  /// away from the landmarks standing in it — the first level-up is the big
  /// one, and the ones after are the wall thickening its parapet.
  static const List<List<double>> _tierCourses = [
    [0.40, 0.38, 0.38, 0.36, 0.20, 0.22, 0.22],
    [0.20, 0.38, 0.38, 0.20, 0.22, 0.22],
    [0.20, 0.38, 0.20, 0.22, 0.22],
    [0.20, 0.20, 0.22, 0.22],
  ];

  static int tierAt(int brickIndex) {
    var k = 0;
    for (final t in thresholds) {
      if (brickIndex >= t) k++;
    }
    return k > maxTier ? maxTier : k;
  }

  static final List<int> _first = _buildFirst();

  static List<int> _buildFirst() {
    final out = <int>[];
    var at = 0;
    for (final t in _tierCourses) {
      out.add(at);
      at += t.length;
    }
    return out;
  }

  static int firstCourseOf(int tier) => _first[tier];

  static int courseCountOf(int tier) => _tierCourses[tier].length;

  static int topCourseOf(int tier) =>
      firstCourseOf(tier) + courseCountOf(tier) - 1;

  static int tierOfCourse(int c) {
    for (var t = maxTier; t >= 0; t--) {
      if (c >= _first[t]) return t;
    }
    return 0;
  }

  /// Position of a course inside its own tier.
  static int roleIndex(int c) => c - firstCourseOf(tierOfCourse(c));

  static bool isLevelling(int c) =>
      tierOfCourse(c) > 0 && roleIndex(c) == 0;

  static bool isCapstone(int c) =>
      roleIndex(c) == courseCountOf(tierOfCourse(c)) - 3;

  static bool isMerlon(int c) =>
      roleIndex(c) >= courseCountOf(tierOfCourse(c)) - 2;

  static int capstoneOf(int tier) => topCourseOf(tier) - 2;

  static List<int> merlonsOf(int tier) =>
      [topCourseOf(tier) - 1, topCourseOf(tier)];

  static int levellingOf(int tier) => tier == 0 ? -1 : firstCourseOf(tier);

  /// Which course has to be solid underneath this one.
  ///
  /// A levelling course bridges the old crenellations, so it rests on the
  /// walkway below them rather than on the merlons themselves.
  static int supportOf(int c) {
    if (c == 0) return -1;
    if (isLevelling(c)) return capstoneOf(tierOfCourse(c) - 1);
    return c - 1;
  }

  static final List<double> heights = [
    for (final t in _tierCourses) ...t,
  ];

  static const List<String> tierNames = ['I', 'II', 'III', 'IV'];
}

class WallDims {
  const WallDims._();

  static List<double> get courseHeights => WallTiers.heights;
  static int get totalCourses => WallTiers.heights.length;

  static const double minStoneW = 0.36;
  static const double maxStoneW = 1.04;

  /// Minimum horizontal offset between a stone and the joint below it, which is
  /// what stops the courses lining up into an obviously fake grid.
  static const double stagger = 0.20;

  static const double merlonPeriod = 1.52;
  static const double merlonWidth = 0.88;

  static double courseBottom(int c) {
    var y = 0.0;
    final h = WallTiers.heights;
    for (var i = 0; i < c && i < h.length; i++) {
      y += h[i];
    }
    return y;
  }

  static double courseCenter(int c) =>
      courseBottom(c) + WallTiers.heights[c] / 2;

  /// Walkway height of a given tier: the top of that tier's capstone.
  static double walkTopOf(int tier) => courseBottom(WallTiers.capstoneOf(tier) + 1);

  /// Full height of a tier, crenellations included.
  static double crownOf(int tier) => courseBottom(WallTiers.topCourseOf(tier) + 1);

  /// The ground tier's walkway. Structures in tier 0 are built to this.
  static double get walkTop => walkTopOf(0);

  /// The wall tapers as it rises, but only gently once it is tall — a tower
  /// that kept thinning at the ground-tier rate would end up a needle.
  static double halfDepthAtY(double y) {
    if (y <= walkTop) return lerpD(0.36, 0.315, clampD(y / walkTop, 0, 1));
    return lerpD(0.315, 0.275, clampD((y - walkTop) / 8.5, 0, 1));
  }

  static double halfDepthForCourse(int c) {
    final d = halfDepthAtY(courseCenter(c));
    return WallTiers.isMerlon(c) ? d - 0.045 : d;
  }
}

// ---------------------------------------------------------------- slab model

/// One solid mass of a structure, described by a 2D silhouette test plus how
/// thick the wall is at each x. Stones always run right through the thickness,
/// so a single stone reads correctly from both sides of the wall.
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

  /// Old crenellation courses the wall has since grown past.
  final List<BuriedBand> buried = [];
  double profileStep = 0.34;

  StoneSlot? slotFor(int brickIndex) =>
      brickIndex >= 0 && brickIndex < slots.length ? slots[brickIndex] : null;

  /// The tier the wall has reached, which is what the landmarks are built to.
  late final int currentTier = WallTiers.tierAt(math.max(0, brickCount - 1));

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
        // No course is shoved past the landmark here. Every course finds its
        // own way around it (see _fitSpans) as and when it gets there, so the
        // stretch of wall behind can still be finished — and, once a tier
        // opens, raised — instead of being abandoned at whatever height it had
        // reached the day the landmark was begun.
        _spans.add((built.instance.x0, endX));
        if (endX > _spanEnd) _spanEnd = endX;
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
    _buildBuried();
    _buildProfile();
  }

  /// The stretches of wall a landmark is standing on. A course opened by a
  /// later tier has to climb past them rather than through them.
  final List<(double, double)> _spans = [];
  double _spanEnd = 0;

  /// Makes room for the landmarks in the way of a stone of width [w] at [xs].
  ///
  /// A stone that would run into a landmark is first narrowed to close the gap
  /// up against it, and only steps over it when what is left is too small to
  /// be a stone at all. Stepping over without narrowing left a slot beside
  /// every landmark, and once tiers stacked those slots became a chimney
  /// running the whole height of the wall.
  (double, double) _fitSpans(double xs, double w) {
    if (_spans.isEmpty || xs >= _spanEnd) return (xs, w);
    for (final sp in _spans) {
      if (sp.$2 <= xs) continue;
      if (sp.$1 >= xs + w) break;
      if (xs >= sp.$1) {
        xs = sp.$2;
        continue;
      }
      final room = sp.$1 - xs;
      if (room >= WallDims.minStoneW) return (xs, room);
      xs = sp.$2;
    }
    return (xs, w);
  }

  /// Where the next landmark starts: past everything laid, and past every
  /// landmark already standing.
  double _frontier(List<double> fill) {
    var m = _spanEnd;
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

    // Only the courses this brick's own tier has opened. Because it depends on
    // the index and not on anything mutable, the first N bricks always lay out
    // the same way — a tier can add room above, never move what is below.
    final top = WallTiers.topCourseOf(WallTiers.tierAt(index));
    for (var c = top; c >= 0; c--) {
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
          kind: WallTiers.isMerlon(c)
              ? SlotKind.merlon
              : (WallTiers.isCapstone(c) ? SlotKind.capstone : SlotKind.body),
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
    final fitted = _fitSpans(fill[c], w);
    var xs = fitted.$1;
    w = fitted.$2;
    final support = WallTiers.supportOf(c);

    if (WallTiers.isMerlon(c)) {
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
      if (xs + ww > fill[support] - WallDims.stagger) return null;
      return (xs, ww);
    }

    if (support < 0) return (xs, w);
    if (xs + w > fill[support] - WallDims.stagger) return null;
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
    // Built to the tier the wall is at *now*, not the tier it was at the day
    // the landmark was begun. A wall that levelled up twice would otherwise
    // leave every old landmark as a notch in its own skyline. A landmark keeps
    // its stretch of wall and its stone count either way — it grows upward
    // with the wall, and its stones grow with it.
    final spec = StructureShapes(WallDims.walkTopOf(currentTier))
        .build(type.kind, startX);
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
  /// The budget is shared out by what each part of a landmark is *for*, not
  /// simply spent from the ground up. A landmark on a wall that has levelled up
  /// three times has a great deal of mass to pay for, and filling it in one
  /// pass meant the mass swallowed every brick and the thing was left headless:
  /// a stump of curtain with no parapet, reading as a gap in the wall rather
  /// than a landmark standing in it. So the crown is paid for first, the mass
  /// takes what is left, and the mouldings get the remainder — and it is the
  /// mouldings that are given up when a landmark cannot afford everything.
  List<_RawStone> _fillSlabs(List<Slab> slabs, int target, int seedA, int seedB) {
    final mass = <Slab>[], crown = <Slab>[], trim = <Slab>[];
    for (final s in slabs) {
      (s.order < 15 ? mass : (s.order < 80 ? crown : trim)).add(s);
    }
    if (crown.isEmpty && trim.isEmpty) {
      return _searchFill(mass, target, seedA, seedB);
    }

    final c = _searchFill(crown, (target * 0.22).ceil(), seedA, seedB);
    final t = _searchFill(trim, (target * 0.12).ceil(), seedA, seedB ^ 0x5bd1);
    final cq = math.min(c.length, (target * 0.22).ceil());
    final tq = math.min(t.length, (target * 0.12).ceil());
    final m = _searchFill(mass, math.max(1, target - cq - tq), seedA, seedB);
    final mq = math.min(m.length, math.max(0, target - cq - tq));

    // Each part takes its share and no more: the stone-size search only
    // guarantees *at least* what it was asked for, and left uncapped the mass
    // would quietly eat the crown's share as well as its own.
    final out = <_RawStone>[
      ...m.take(mq),
      ...c.take(cq),
      ...t.take(tq),
    ];
    // Whatever a part could not use goes back into the pot, so the landmark
    // still costs exactly the bricks the pacing promised.
    for (final spare in [m.skip(mq), c.skip(cq), t.skip(tq)]) {
      for (final stone in spare) {
        if (out.length >= target) break;
        out.add(stone);
      }
    }
    out.sort((a, b) => a.slabOrder.compareTo(b.slabOrder));
    return out;
  }

  /// The largest stone size that still yields at least [target] stones.
  List<_RawStone> _searchFill(
    List<Slab> slabs,
    int target,
    int seedA,
    int seedB,
  ) {
    if (slabs.isEmpty || target <= 0) return const [];
    var lo = 0.06, hi = 1.40;
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


  // ------------------------------------------------------ buried courses

  /// Works out how far each superseded crenellation has been built over.
  ///
  /// A band is only blocked as far as the levelling course above it has
  /// actually reached, so the wall visibly thickens behind the new tier as it
  /// creeps along instead of healing everywhere at once.
  void _buildBuried() {
    // Measured from the stones actually laid, not from the layout's frontier
    // bookkeeping. A course does not run continuously: it steps over every
    // landmark in its way, so what has to be blocked is each stretch it really
    // covers — blocking from the origin to its far end would hang masonry in
    // the air over everything it skipped.
    for (var t = 0; t < WallTiers.maxTier; t++) {
      final lev = WallTiers.levellingOf(t + 1);
      if (lev < 0) continue;
      final runs = _runsOfCourse(lev);
      if (runs.isEmpty) continue;
      for (final c in WallTiers.merlonsOf(t)) {
        final half = WallDims.halfDepthForCourse(c) - 0.035;
        for (final r in runs) {
          buried.add(BuriedBand(
            WallDims.courseBottom(c),
            WallDims.courseBottom(c + 1),
            r.$1,
            r.$2,
            half,
          ));
        }
      }
    }
  }

  /// The continuous stretches course [c] actually covers.
  List<(double, double)> _runsOfCourse(int c) {
    final out = <(double, double)>[];
    for (final s in slots) {
      if (s.structureIndex >= 0 || s.course != c) continue;
      if (out.isNotEmpty && s.left <= out.last.$2 + 0.06) {
        out[out.length - 1] = (out.last.$1, math.max(out.last.$2, s.right));
      } else {
        out.add((s.left, s.right));
      }
    }
    return out;
  }

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

/// A course a later tier has built over.
///
/// Crenellations are gaps by design. The moment the wall levels up, those gaps
/// are in the *middle* of a solid mass, and you would see daylight straight
/// through it. Every buried band gets blocked with blind masonry, set a little
/// shallower than the merlons so the old crenellation still reads as relief on
/// the face instead of vanishing.
class BuriedBand {
  BuriedBand(this.y0, this.y1, this.x0, this.x1, this.halfDepth);
  final double y0, y1, x0, x1, halfDepth;
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
