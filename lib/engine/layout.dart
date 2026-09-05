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

  /// The stones that are actually part of the wall.
  ///
  /// One extra slot is always laid out beyond them, so the app can show a
  /// ghost of where the next stone will land — but the ghost is not a stone:
  /// it must not lengthen the wall, appear in the distant silhouette, or cast
  /// a shadow on the ground before anyone has earned it.
  Iterable<StoneSlot> get _laid =>
      slots.length > brickCount ? slots.take(brickCount) : slots;

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
        _spans.add(_Span.of(built.instance.x0, endX, built.slots));
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
    // frontier bookkeeping has advanced past a half-finished landmark — and
    // not counting the ghost, which is not a stone yet.
    length = 0;
    for (var i = 0; i < slots.length && i < brickCount; i++) {
      if (slots[i].right > length) length = slots[i].right;
    }
    _buildBuried();
    _buildProfile();
  }

  /// The stretches of wall the landmarks stand on, each with the coarse
  /// profile of its own top.
  ///
  /// A landmark is built to the wall of its own day, so once the wall has been
  /// heightened it is shorter than its neighbours. What closes that gap is the
  /// wall itself: courses opened by a later tier run straight over the top of
  /// an old landmark, and only the parts that still stand higher — its towers,
  /// its turret — keep pushing through. That is what happens to a real wall
  /// that gets raised, and it means the skyline stays whole without anyone
  /// having to pay for an old landmark twice.
  final List<_Span> _spans = [];
  double _spanEnd = 0;

  /// Makes room for the landmarks in the way of a stone of width [w] at [xs],
  /// at the height [yBottom] the stone would sit at.
  ///
  /// A stone that would run into a landmark is first narrowed to close the gap
  /// up against it, and only steps over it when what is left is too small to
  /// be a stone at all. Stepping over without narrowing left a slot beside
  /// every landmark, and once tiers stacked those slots became a chimney
  /// running the whole height of the wall.
  (double, double) _fitSpans(double xs, double w, double yBottom) {
    if (_spans.isEmpty || xs >= _spanEnd) return (xs, w);
    for (var pass = 0; pass < 6; pass++) {
      var moved = false;
      for (final sp in _spans) {
        if (sp.x1 <= xs || sp.x0 >= xs + w) continue;
        final block = sp.blockedAt(yBottom, xs, xs + w);
        if (block == null) continue;
        if (xs >= block.$1) {
          xs = block.$2;
          moved = true;
          continue;
        }
        final room = block.$1 - xs;
        if (room >= WallDims.minStoneW) return (xs, room);
        xs = block.$2;
        moved = true;
      }
      if (!moved) break;
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
    final fitted = _fitSpans(fill[c], w, WallDims.courseBottom(c));
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
    // Built to the wall of its own day, and paid for at that day's rate.
    //
    // Rebuilding old landmarks to the wall's current height kept the skyline
    // even, but it did so by handing a twenty-two brick watchtower a tower
    // three times as tall to pay for, and the only way to pay was with blocks a
    // metre across. A landmark built out of six boulders is not a landmark. So
    // each one is built to the wall as it stood when it was begun, out of
    // stones the size of that wall's stones — and where the wall has since been
    // heightened, the oldest landmarks sit a little below its top, which is
    // what happens to real ones.
    final spec = StructureShapes(
      WallDims.walkTopOf(WallTiers.tierAt(seg.firstBrick)),
    ).build(type.kind, startX);
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
  /// One stone size for the whole landmark. It was tempting to give each part
  /// of it its own budget and its own size — that is how the parapet stopped
  /// being the first thing given up when the bricks ran short — but a landmark
  /// whose body is a stack of slabs a metre across and whose cornice is a
  /// handful of gravel is not a landmark, it is a pile. Sizing every part
  /// together is what keeps it reading as one piece of masonry. The parapet is
  /// kept instead by building it *before* the mouldings (see the order
  /// constants in StructureShapes), and the body is stopped from swallowing the
  /// budget in giant blocks by the size bounds in [_generate].
  List<_RawStone> _fillSlabs(
    List<Slab> slabs,
    int target,
    int seedA,
    int seedB,
  ) =>
      _capped(_searchFill(slabs, target, seedA, seedB), target);

  /// Trims a landmark to the bricks it is allowed, giving up whatever is
  /// furthest from being the landmark itself.
  ///
  /// Sorted rather than trusted to arrive in order, and sorted stably, because
  /// what the sort decides is both the order the bricks go on in and the order
  /// things are given up in: within one part of a landmark the stones must
  /// still be laid from the ground up.
  List<_RawStone> _capped(List<_RawStone> stones, int target) {
    if (stones.length <= target) return stones;
    final order = List<int>.generate(stones.length, (i) => i);
    order.sort((a, b) {
      final c = stones[a].slabOrder.compareTo(stones[b].slabOrder);
      return c != 0 ? c : a.compareTo(b);
    });
    return [for (var i = 0; i < target; i++) stones[order[i]]];
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

  /// How big a landmark's stones are allowed to get, and how small its chips
  /// are allowed to get. Both are expressed against the rampart's own stones,
  /// because looking like the wall it stands in is the whole job.
  static const double _maxCourse = 0.74;
  static const double _maxStoneW = 1.06;
  static const double _minStoneW = 0.40;

  List<_RawStone> _generate(List<Slab> slabs, double scale, int seedA, int seedB) {
    final out = <_RawStone>[];
    final ordered = [...slabs]..sort((a, b) => a.order.compareTo(b.order));
    var salt = 0;
    for (final slab in ordered) {
      final want = scale * slab.courseScale;
      if (want < 0.04) continue;
      // Divide the mass into a whole number of courses so it finishes exactly
      // at its own top: a leftover sliver leaves the crenellation floating.
      //
      // Bounded, though. A landmark on a wall that has levelled up has enough
      // mass to pay for that the search would happily build its tower out of
      // four blocks a metre tall, and no arrangement of four blocks a metre
      // tall reads as a tower. Nothing here may be more than a couple of the
      // rampart's own courses high.
      final tall = slab.y1 - slab.y0;
      final courses = math.max(
        math.max(1, (tall / want).round()),
        (tall / _maxCourse).ceil(),
      );
      final ch = tall / courses;
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
    // A feature narrower than this is not worth a stone: cut into pieces it
    // reads as gravel caught in the wall rather than as the moulding it is
    // meant to be, so it is left out altogether.
    if (span < ch * 0.55 || span < 0.21) return;
    // The same bounds sideways: never a block wider than the widest stone in
    // the rampart, and never a chip narrower than the narrowest — a moulding
    // made of gravel reads as rubble caught in the wall, not as a moulding.
    final targetW = clampD(ch * 1.75, _minStoneW, _maxStoneW);
    var n = (span / targetW).round();
    if (n < 1) n = 1;
    // Rounding can leave one block spanning the lot: a run of 1.35 over a
    // target of 1.06 rounds to a single stone. The cap is a cap.
    if (span / n > _maxStoneW) n = (span / _maxStoneW).ceil();
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

    // And the same for a landmark the wall has been built over: its own
    // crenellations are now inside the mass, and their gaps would be daylight
    // through the middle of a solid wall.
    for (final sp in _spans) {
      final peak = sp.peak;
      if (peak <= 0.1) continue;
      var covered = false;
      for (final s in _laid) {
        if (s.structureIndex >= 0) continue;
        if (s.right <= sp.x0 || s.left >= sp.x1) continue;
        if (s.y - s.h / 2 >= peak - 0.06) {
          covered = true;
          break;
        }
      }
      if (!covered) continue;
      buried.add(BuriedBand(
        math.max(0, peak - 0.55),
        peak,
        sp.x0,
        sp.x1,
        WallDims.halfDepthAtY(peak) - 0.06,
      ));
    }
  }

  /// The continuous stretches course [c] actually covers.
  List<(double, double)> _runsOfCourse(int c) {
    final out = <(double, double)>[];
    for (final s in _laid) {
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
    for (final s in _laid) {
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

/// One landmark's footprint, with the coarse profile of its own top.
class _Span {
  _Span(this.x0, this.x1, this.step, this.tops);

  factory _Span.of(double x0, double x1, List<StoneSlot> stones) {
    const step = 0.22;
    final n = math.max(1, ((x1 - x0) / step).ceil());
    final tops = List<double>.filled(n, 0.0);
    for (final s in stones) {
      final i0 = ((s.left - x0) / step).floor().clamp(0, n - 1);
      final i1 = ((s.right - x0) / step).ceil().clamp(0, n - 1);
      for (var i = i0; i <= i1; i++) {
        if (s.top > tops[i]) tops[i] = s.top;
      }
    }
    return _Span(x0, x1, step, tops);
  }

  final double x0, x1, step;

  /// Highest stone of the landmark in each slice of its footprint.
  final List<double> tops;

  double get peak {
    var m = 0.0;
    for (final t in tops) {
      if (t > m) m = t;
    }
    return m;
  }

  /// The first stretch of this footprint that a course sitting at [yBottom]
  /// cannot pass through, searched between [from] and [to].
  ///
  /// Null when the course clears the landmark everywhere it would touch it —
  /// which is how a heightened wall runs over the top of an old one.
  (double, double)? blockedAt(double yBottom, double from, double to) {
    final n = tops.length;
    final i0 = ((from - x0) / step).floor().clamp(0, n - 1);
    final i1 = ((to - x0) / step).ceil().clamp(0, n - 1);
    var start = -1;
    for (var i = i0; i <= i1; i++) {
      final blocked = tops[i] > yBottom + 0.02;
      if (blocked && start < 0) start = i;
      if (!blocked && start >= 0) {
        return (x0 + start * step, x0 + i * step);
      }
    }
    if (start < 0) return null;
    // Blocked to the end of the searched stretch: extend to the far side of
    // whatever is actually in the way, so the course steps clear of it.
    var end = i1;
    while (end + 1 < n && tops[end + 1] > yBottom + 0.02) {
      end++;
    }
    return (x0 + start * step, math.min(x1, x0 + (end + 1) * step));
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
