import 'dart:math' as math;

import '../core/math3.dart';
import '../data/milestones.dart';
import 'layout.dart';

/// One solid mass of the landmark. The filler turns it into stones.
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

class StructureSpec {
  StructureSpec(this.slabs, this.length, this.featureX, this.featureY);
  final List<Slab> slabs;
  final double length;
  final double featureX, featureY;
}

double _flat(double x) => 0;

/// Thirty genuinely different silhouettes, each assembled from solid masses
/// that the filler turns into real stones.
///
/// Everything is authored against the tier's own [wallTop], so the same
/// landmark reads correctly on a two-course starter wall and on a wall that
/// has levelled up five times: the body grows with the wall, while the parts
/// that crown it keep their proportions.
class StructureShapes {
  StructureShapes(this.wallTop);

  /// Height of the walkway this landmark is built on.
  final double wallTop;

  double get _wallHalf => WallDims.halfDepthAtY(wallTop * 0.5);

  /// How far the rampart's own crenellations stand above the walkway. A
  /// landmark that stops short of this reads as a notch in the wall.
  static const double crown = 0.44;

  /// Build order inside a landmark, and with it the order in which the bricks
  /// go on. It is also the order things are given up in when a landmark is
  /// still short of bricks, so it runs from what the landmark *is* to what it
  /// is merely wearing: mass, then the brackets and parapet that finish it,
  /// then its cap, then mouldings, then the fine detail cut into its faces.
  /// A landmark that ran out of bricks halfway up its trim still reads as a
  /// landmark; one that never got its parapet reads as unfinished wall.
  static const int corbelOrder = 15;
  static const int crownOrder = 20;
  static const int capOrder = 30;
  static const int trimOrder = 84;
  static const int detailOrder = 95;

  StructureSpec build(MilestoneKind kind, double x0) {
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
      case MilestoneKind.roundTower:
        return _roundTower(x0);
      case MilestoneKind.albarrana:
        return _albarrana(x0);
      case MilestoneKind.cistern:
        return _cistern(x0);
      case MilestoneKind.bentGate:
        return _bentGate(x0);
      case MilestoneKind.outworks:
        return _outworks(x0);
      case MilestoneKind.postern:
        return _postern(x0);
      case MilestoneKind.machicolation:
        return _machicolation(x0);
      case MilestoneKind.belfry:
        return _belfry(x0);
      case MilestoneKind.clockTower:
        return _clockTower(x0);
      case MilestoneKind.windmill:
        return _windmill(x0);
      case MilestoneKind.doubleArcade:
        return _doubleArcade(x0);
      case MilestoneKind.twinStair:
        return _twinStair(x0);
      case MilestoneKind.moatBridge:
        return _moatBridge(x0);
      case MilestoneKind.spurTower:
        return _spurTower(x0);
      case MilestoneKind.triumphalArch:
        return _triumphalArch(x0);
      case MilestoneKind.casemate:
        return _casemate(x0);
      case MilestoneKind.buttresses:
        return _buttresses(x0);
      case MilestoneKind.octagonTower:
        return _octagonTower(x0);
      case MilestoneKind.dovecote:
        return _dovecote(x0);
      case MilestoneKind.lighthouse:
        return _lighthouse(x0);
    }
  }

  // ------------------------------------------------------- shared vocabulary

  /// The stretch of ordinary curtain wall the landmark stands in.
  Slab _curtain(
    double a,
    double b, {
    bool Function(double u, double y)? cut,
    double? top,
    int order = 0,
  }) {
    return Slab(
      x0: a,
      x1: b,
      y0: 0,
      y1: top ?? wallTop,
      solid: cut == null ? (x, y) => true : (x, y) => !cut(x - a, y),
      zCenter: _flat,
      halfDepth: (x) => _wallHalf,
      kind: SlotKind.body,
      order: order,
    );
  }

  /// A crenellated cap: merlons with gaps, the final flourish on any parapet.
  Slab _crenellation(
    double x0,
    double x1,
    double yBase,
    double height,
    double depth, {
    double period = 0.62,
    double duty = 0.58,
    double z = 0,
    int order = crownOrder,
  }) {
    return Slab(
      x0: x0,
      x1: x1,
      y0: yBase,
      y1: yBase + height,
      solid: (x, y) => (x - x0) % period < period * duty,
      zCenter: (x) => z,
      halfDepth: (x) => depth,
      kind: SlotKind.merlon,
      courseScale: 0.72,
      ornament: true,
      order: order,
    );
  }

  /// A projecting horizontal band — the moulding that divides a tall face into
  /// storeys. Small stones, so it reads as a line of trim rather than masonry.
  Slab _stringCourse(
    double x0,
    double x1,
    double y, {
    double height = 0.12,
    double depth = 0.40,
    double z = 0,
    int order = 84,
  }) {
    return Slab(
      x0: x0,
      x1: x1,
      y0: y,
      y1: y + height,
      solid: (x, y) => true,
      zCenter: (x) => z,
      halfDepth: (x) => depth,
      kind: SlotKind.ornament,
      courseScale: 0.46,
      ornament: true,
      order: order,
    );
  }

  /// The row of brackets that carries an overhanging gallery.
  Slab _corbels(
    double x0,
    double x1,
    double y, {
    double height = 0.17,
    double depth = 0.42,
    double period = 0.24,
    double duty = 0.52,
    double z = 0,
    int order = corbelOrder,
  }) {
    return Slab(
      x0: x0,
      x1: x1,
      y0: y,
      y1: y + height,
      solid: (x, y) => (x - x0) % period < period * duty,
      zCenter: (x) => z,
      halfDepth: (x) => depth,
      kind: SlotKind.ornament,
      courseScale: 0.42,
      ornament: true,
      order: order,
    );
  }

  /// A wider plinth at the foot of a mass: the batter that makes a tower look
  /// planted instead of dropped.
  Slab _plinth(
    double x0,
    double x1,
    double height,
    double depth, {
    double z = 0,
    int order = 0,
  }) {
    return Slab(
      x0: x0,
      x1: x1,
      y0: 0,
      y1: height,
      solid: (x, y) => true,
      zCenter: (x) => z,
      halfDepth: (x) => depth,
      kind: SlotKind.tower,
      courseScale: 0.86,
      order: order,
    );
  }

  /// A drum: circular in plan, so it is round from every orbit angle.
  Slab _drum(
    double cx,
    double r,
    double y0,
    double y1, {
    double z = 0,
    SlotKind kind = SlotKind.tower,
    double courseScale = 1.0,
    int order = 1,
  }) {
    return Slab(
      x0: cx - r,
      x1: cx + r,
      y0: y0,
      y1: y1,
      solid: (x, y) => true,
      zCenter: (x) => z,
      halfDepth: (x) {
        final d = (x - cx) / r;
        return r * math.sqrt(math.max(0.06, 1 - d * d));
      },
      kind: kind,
      courseScale: courseScale,
      order: order,
    );
  }

  /// Same idea, but faceted: a regular octagon seen from above.
  Slab _octagon(
    double cx,
    double r,
    double y0,
    double y1, {
    double z = 0,
    SlotKind kind = SlotKind.tower,
    int order = 1,
  }) {
    const flat = 0.4142;
    return Slab(
      x0: cx - r,
      x1: cx + r,
      y0: y0,
      y1: y1,
      solid: (x, y) => true,
      zCenter: (x) => z,
      halfDepth: (x) {
        final t = ((x - cx) / r).abs();
        if (t <= flat) return r;
        return math.max(0.08, r * (1 - t) / (1 - flat));
      },
      kind: kind,
      order: order,
    );
  }

  /// A round-headed opening.
  static bool _archHole(double x, double y, double cx, double r, double spring) {
    if (y < 0) return false;
    if (y <= spring) return (x - cx).abs() <= r;
    final dy = y - spring;
    if (dy > r) return false;
    final half = math.sqrt(math.max(0.0, r * r - dy * dy));
    return (x - cx).abs() <= half;
  }

  /// A pointed opening — the gothic sibling of the one above.
  static bool _pointedHole(
    double x,
    double y,
    double cx,
    double r,
    double spring,
  ) {
    if (y < 0) return false;
    if (y <= spring) return (x - cx).abs() <= r;
    final rise = r * 1.45;
    final t = (y - spring) / rise;
    if (t > 1) return false;
    final half = r * (1 - t * t * (3 - 2 * t));
    return (x - cx).abs() <= half;
  }

  /// A slot that splays outward: an embrasure for a gun or a bow.
  static bool _embrasure(
    double x,
    double y,
    double cx,
    double y0,
    double y1,
    double throatHalf,
    double mouthHalf,
  ) {
    if (y < y0 || y > y1) return false;
    final t = (y - y0) / math.max(0.001, y1 - y0);
    final half = lerpD(throatHalf, mouthHalf, t < 0.5 ? t * 2 : 1);
    return (x - cx).abs() <= half;
  }

  // ------------------------------------------------------------- 1. tower

  StructureSpec _watchtower(double x0) {
    const len = 2.35;
    const ta = 0.5, tb = 1.85;
    final top = wallTop + 1.63;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= ta && u <= tb),
      _plinth(x0 + ta - 0.09, x0 + tb + 0.09, 0.42, 0.62),
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0.42, y1: top,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => 0.56,
        kind: SlotKind.tower,
        order: crownOrder + 2,
      ),
      _stringCourse(x0 + ta - 0.05, x0 + tb + 0.05, wallTop + 0.42, depth: 0.60),
      _corbels(x0 + ta - 0.1, x0 + tb + 0.1, top, depth: 0.64, period: 0.22),
      _crenellation(x0 + ta - 0.1, x0 + tb + 0.1, top + 0.17, 0.42, 0.60,
          period: 0.52),
      _crenellation(x0, x0 + ta, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + tb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 21),
    ], len, (ta + tb) / 2, top + 0.6);
  }

  // -------------------------------------------------------------- 2. gate

  StructureSpec _gate(double x0) {
    const len = 2.9;
    const cx = 1.45, r = 0.46, spring = 1.05;
    final bandTop = wallTop + 0.33;
    bool jamb(double u) => (u > 0.72 && u < 0.99) || (u > 1.91 && u < 2.18);
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: bandTop,
        solid: (x, y) =>
            !jamb(x - x0) && !_archHole(x - x0, y, cx, r, spring),
        zCenter: _flat,
        halfDepth: (x) => _wallHalf,
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0 + 0.72, x1: x0 + 2.18, y0: 0, y1: bandTop,
        solid: (x, y) => jamb(x - x0),
        zCenter: _flat,
        halfDepth: (x) => 0.48,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The voussoir ring around the arch head.
      Slab(
        x0: x0 + cx - r - 0.16, x1: x0 + cx + r + 0.16,
        y0: spring - 0.1, y1: spring + r + 0.16,
        solid: (x, y) {
          final u = x - x0;
          return _archHole(u, y, cx, r + 0.16, spring) &&
              !_archHole(u, y, cx, r, spring);
        },
        zCenter: (x) => 0.06,
        halfDepth: (x) => 0.42,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: 84,
      ),
      _stringCourse(x0, x0 + len, bandTop - 0.16, depth: 0.40),
      _crenellation(x0, x0 + len, bandTop, 0.42, 0.32, period: 0.56),
    ], len, cx, spring + r);
  }

  // -------------------------------------------------------- 3. great tower

  StructureSpec _greatTower(double x0) {
    const len = 3.05;
    const ta = 0.42, tb = 2.63;
    final top = wallTop + 2.53;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= ta && u <= tb),
      _plinth(x0 + ta - 0.14, x0 + tb + 0.14, 0.55, 0.90),
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0.55, y1: top,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => 0.784,
        kind: SlotKind.tower,
        order: 1,
      ),
      // Clasping pilasters up the corners.
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0.55, y1: top,
        solid: (x, y) {
          final u = x - x0 - ta;
          final w = tb - ta;
          return u < 0.2 || u > w - 0.2;
        },
        zCenter: _flat,
        halfDepth: (x) => 0.86,
        kind: SlotKind.tower,
        courseScale: 0.8,
        order: 2,
      ),
      _stringCourse(x0 + ta - 0.05, x0 + tb + 0.05, wallTop + 0.55, depth: 0.82),
      _stringCourse(x0 + ta - 0.05, x0 + tb + 0.05, wallTop + 1.62, depth: 0.82),
      _corbels(x0 + ta - 0.14, x0 + tb + 0.14, top, depth: 0.90, period: 0.23),
      _crenellation(x0 + ta - 0.14, x0 + tb + 0.14, top + 0.17, 0.5, 0.88,
          period: 0.58),
      _crenellation(x0, x0 + ta, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + tb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, (ta + tb) / 2, top + 0.67);
  }

  // ------------------------------------------------------------- 4. stair

  StructureSpec _stair(double x0) {
    const len = 2.65;
    const runStart = 0.25, runEnd = 2.35;
    final steps = math.max(6, (wallTop / 0.30).round());
    double stepTop(double u) {
      final t = clampD((u - runStart) / (runEnd - runStart), 0, 1);
      return wallTop * ((t * steps).floor() + 1) / steps;
    }
    return StructureSpec([
      _curtain(x0, x0 + len),
      Slab(
        x0: x0 + runStart, x1: x0 + runEnd, y0: 0, y1: wallTop,
        solid: (x, y) => y <= stepTop(x - x0),
        zCenter: (x) => 0.66,
        halfDepth: (x) => 0.208,
        kind: SlotKind.tower,
        courseScale: 0.8,
        order: 1,
      ),
      // The rail: a low parapet following the flight.
      Slab(
        x0: x0 + runStart, x1: x0 + runEnd, y0: 0, y1: wallTop + 0.34,
        solid: (x, y) {
          final s = stepTop(x - x0);
          return y > s && y <= s + 0.30;
        },
        zCenter: (x) => 0.80,
        halfDepth: (x) => 0.10,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: 86,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.54),
    ], len, (runStart + runEnd) / 2, wallTop);
  }

  // -------------------------------------------------------- 5. drawbridge

  StructureSpec _drawbridge(double x0) {
    const len = 3.5;
    const la = 0.72, lb = 1.34, ra = 2.16, rb = 2.78;
    final ttop = wallTop + 0.90;
    final deck = math.min(wallTop - 0.5, 1.06);
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= la && u <= rb),
      Slab(
        x0: x0 + la, x1: x0 + rb, y0: 0, y1: ttop,
        solid: (x, y) {
          final u = x - x0;
          return (u >= la && u <= lb) || (u >= ra && u <= rb);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.512,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The lintel bridging the two towers above the passage.
      Slab(
        x0: x0 + lb, x1: x0 + ra, y0: deck + 0.38, y1: wallTop,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => 0.32,
        kind: SlotKind.body,
        order: 2,
      ),
      // The chain slots cut into the tower faces.
      Slab(
        x0: x0 + lb - 0.02, x1: x0 + ra + 0.02,
        y0: wallTop - 0.02, y1: wallTop + 0.16,
        solid: (x, y) => true,
        zCenter: (x) => 0.44,
        halfDepth: (x) => 0.10,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: 84,
      ),
      // The deck itself, laid down last.
      Slab(
        x0: x0 + lb - 0.04, x1: x0 + ra + 0.04, y0: deck, y1: deck + 0.2,
        solid: (x, y) => true,
        zCenter: (x) => 0.70,
        halfDepth: (x) => 0.088,
        kind: SlotKind.deck,
        courseScale: 0.6,
        ornament: true,
        order: 88,
      ),
      _corbels(x0 + la, x0 + lb, ttop, depth: 0.55, period: 0.2),
      _corbels(x0 + ra, x0 + rb, ttop, depth: 0.55, period: 0.2, order: 16),
      _crenellation(x0 + la, x0 + lb, ttop + 0.17, 0.4, 0.53, period: 0.5),
      _crenellation(x0 + ra, x0 + rb, ttop + 0.17, 0.4, 0.53, period: 0.5, order: 21),
    ], len, (lb + ra) / 2, deck + 0.2);
  }

  // ------------------------------------------------------------ 6. beacon

  StructureSpec _beacon(double x0) {
    const len = 2.05;
    const sa = 0.62, sb = 1.42;
    final top = wallTop + 1.23;
    final cx = x0 + (sa + sb) / 2;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= sa && u <= sb),
      _plinth(x0 + sa - 0.08, x0 + sb + 0.08, 0.34, 0.47),
      Slab(
        x0: x0 + sa, x1: x0 + sb, y0: 0.34, y1: top,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => 0.416,
        kind: SlotKind.tower,
        order: 1,
      ),
      _stringCourse(x0 + sa - 0.05, x0 + sb + 0.05, wallTop + 0.30, depth: 0.45),
      // The flared bowl that holds the fire.
      Slab(
        x0: x0 + sa - 0.22, x1: x0 + sb + 0.22, y0: top, y1: top + 0.34,
        solid: (x, y) {
          final t = (y - top) / 0.34;
          return (x - cx).abs() <= lerpD(0.40, 0.62, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.464,
        kind: SlotKind.ornament,
        courseScale: 0.6,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + sa, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + sb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, (sa + sb) / 2, top + 0.4);
  }

  // ----------------------------------------------------------- 7. bastion

  StructureSpec _bastion(double x0) {
    const len = 3.65;
    const ba = 0.48, bb = 3.15;
    final btop = wallTop + 0.36;
    double bump(double u) {
      final t = clampD((u - ba) / (bb - ba), 0, 1);
      if (t < 0.28) return t / 0.28;
      if (t > 0.72) return (1 - t) / 0.28;
      return 1;
    }
    double front(double x) => 0.34 + 0.74 * bump(x - x0);
    double zc(double x) => (front(x) - 0.34) / 2;
    double hd(double x) => (front(x) + 0.34) / 2;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= ba && u <= bb),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: 0, y1: 0.5,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.1,
        kind: SlotKind.tower,
        courseScale: 0.86,
        order: 0,
      ),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: 0.5, y1: btop,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: hd,
        kind: SlotKind.tower,
        order: 1,
      ),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: btop, y1: btop + 0.12,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.06,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: 84,
      ),
      Slab(
        x0: x0 + ba, x1: x0 + bb, y0: btop + 0.12, y1: btop + 0.58,
        solid: (x, y) {
          final t = (x - x0 - ba) / (bb - ba);
          return (t * 7.2) % 1.0 < 0.6;
        },
        zCenter: zc,
        halfDepth: (x) => hd(x) * 0.92,
        kind: SlotKind.merlon,
        courseScale: 0.7,
        ornament: true,
        order: crownOrder + 2,
      ),
      _crenellation(x0, x0 + ba, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + bb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, (ba + bb) / 2, btop + 0.58);
  }

  // ----------------------------------------------------------- 8. arcade

  StructureSpec _aqueduct(double x0) {
    const len = 4.05;
    const centers = [0.88, 2.02, 3.16];
    const r = 0.42, spring = 0.92;
    final top = math.max(wallTop, spring + r + 0.34);
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
        zCenter: _flat,
        halfDepth: (x) => _wallHalf,
        kind: SlotKind.body,
        order: 0,
      ),
      // Impost blocks where each arch springs.
      for (final c in centers)
        Slab(
          x0: x0 + c - r - 0.12, x1: x0 + c + r + 0.12,
          y0: spring - 0.13, y1: spring,
          solid: (x, y) => (x - x0 - c).abs() > r,
          zCenter: (x) => 0.05,
          halfDepth: (x) => _wallHalf + 0.06,
          kind: SlotKind.ornament,
          courseScale: 0.4,
          ornament: true,
          order: 84,
        ),
      _stringCourse(x0, x0 + len, top - 0.14, depth: _wallHalf + 0.06),
      _crenellation(x0, x0 + len, top, 0.4, 0.32, period: 0.58),
    ], len, centers[1], spring + r);
  }

  // ----------------------------------------------------------- 9. shrine

  StructureSpec _shrine(double x0) {
    const len = 2.1;
    const nx0 = 0.78, nx1 = 1.32, ny0 = 0.42, ny1 = 1.18;
    const ncx = (nx0 + nx1) / 2, nr = 0.27;
    bool niche(double u, double y) {
      if (y < ny0 || u < nx0 || u > nx1) return false;
      if (y <= ny1) return true;
      final dy = y - ny1;
      if (dy > nr) return false;
      return (u - ncx).abs() <= math.sqrt(math.max(0.0, nr * nr - dy * dy));
    }
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => niche(u, y)),
      // The recessed back of the niche.
      Slab(
        x0: x0 + nx0, x1: x0 + nx1, y0: ny0, y1: ny1 + nr,
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
      // A gabled hood over the opening.
      Slab(
        x0: x0 + nx0 - 0.2, x1: x0 + nx1 + 0.2,
        y0: ny1 + nr, y1: ny1 + nr + 0.34,
        solid: (x, y) {
          final t = (y - ny1 - nr) / 0.34;
          return (x - x0 - ncx).abs() <= lerpD(nr + 0.2, 0.04, t);
        },
        zCenter: (x) => 0.10,
        halfDepth: (x) => 0.36,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.52),
    ], len, ncx, ny1);
  }

  // --------------------------------------------------------- 10. barbican

  StructureSpec _barbican(double x0) {
    const len = 4.3;
    const la = 0.5, lb = 1.42, ra = 2.88, rb = 3.8;
    const cx = 2.15, r = 0.5, spring = 1.12;
    final ttop = wallTop + 1.33;
    final curtainTop = wallTop + 0.43;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= la && u <= rb),
      _plinth(x0 + la - 0.08, x0 + rb + 0.08, 0.46, 0.62),
      Slab(
        x0: x0 + la, x1: x0 + rb, y0: 0.46, y1: ttop,
        solid: (x, y) {
          final u = x - x0;
          return (u >= la && u <= lb) || (u >= ra && u <= rb);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.544,
        kind: SlotKind.tower,
        order: 1,
      ),
      Slab(
        x0: x0 + lb, x1: x0 + ra, y0: 0, y1: curtainTop,
        solid: (x, y) => !_archHole(x - x0, y, cx, r, spring),
        zCenter: _flat,
        halfDepth: (x) => 0.368,
        kind: SlotKind.body,
        order: 2,
      ),
      // The portcullis groove above the arch.
      Slab(
        x0: x0 + cx - r, x1: x0 + cx + r,
        y0: spring + r, y1: spring + r + 0.14,
        solid: (x, y) => true,
        zCenter: (x) => 0.32,
        halfDepth: (x) => 0.09,
        kind: SlotKind.ornament,
        courseScale: 0.38,
        ornament: true,
        order: 84,
      ),
      _corbels(x0 + lb, x0 + ra, curtainTop - 0.14, depth: 0.42, period: 0.22),
      _crenellation(x0 + lb, x0 + ra, curtainTop, 0.4, 0.352, period: 0.54, order: 19),
      _crenellation(x0 + la, x0 + lb, ttop, 0.44, 0.56, period: 0.5, order: 20),
      _crenellation(x0 + ra, x0 + rb, ttop, 0.44, 0.56, period: 0.5, order: 21),
    ], len, cx, spring + r);
  }

  // ------------------------------------------------------ 11. round tower

  StructureSpec _roundTower(double x0) {
    const len = 2.8;
    const cx = 1.4, r = 0.62;
    final top = wallTop + 2.05;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => (u - cx).abs() <= r + 0.14),
      _drum(x0 + cx, r + 0.14, 0, 0.55, courseScale: 0.86, order: 0),
      _drum(x0 + cx, r, 0.55, wallTop + 0.30, order: 1),
      _drum(x0 + cx, r - 0.05, wallTop + 0.42, top, order: 2),
      Slab(
        x0: x0 + cx - r - 0.03, x1: x0 + cx + r + 0.03,
        y0: wallTop + 0.30, y1: wallTop + 0.42,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) {
          final d = (x - x0 - cx) / (r + 0.03);
          return (r + 0.03) * math.sqrt(math.max(0.06, 1 - d * d));
        },
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: 84,
      ),
      _corbels(x0 + cx - r - 0.06, x0 + cx + r + 0.06, top, depth: 0.70, period: 0.2),
      Slab(
        x0: x0 + cx - r - 0.06, x1: x0 + cx + r + 0.06,
        y0: top + 0.17, y1: top + 0.6,
        solid: (x, y) => (x - x0 - cx + r) % 0.5 < 0.29,
        zCenter: _flat,
        halfDepth: (x) {
          final d = (x - x0 - cx) / (r + 0.06);
          return (r + 0.06) * math.sqrt(math.max(0.06, 1 - d * d));
        },
        kind: SlotKind.merlon,
        courseScale: 0.7,
        ornament: true,
        order: crownOrder + 2,
      ),
      _crenellation(x0, x0 + cx - r, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + cx + r, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, top + 0.6);
  }

  // -------------------------------------------------------- 12. albarrana

  /// A tower standing clear of the wall, tied back by a slender arched bridge.
  StructureSpec _albarrana(double x0) {
    const len = 3.0;
    const cx = 1.5, half = 0.46;
    final top = wallTop + 1.55;
    const zOut = 1.35;
    final deck = math.min(wallTop - 0.24, 1.30);
    return StructureSpec([
      _curtain(x0, x0 + len),
      // The detached tower, well forward of the wall line.
      Slab(
        x0: x0 + cx - half - 0.1, x1: x0 + cx + half + 0.1, y0: 0, y1: 0.44,
        solid: (x, y) => true,
        zCenter: (x) => zOut,
        halfDepth: (x) => half + 0.1,
        kind: SlotKind.tower,
        courseScale: 0.86,
        order: 1,
      ),
      Slab(
        x0: x0 + cx - half, x1: x0 + cx + half, y0: 0.44, y1: top,
        solid: (x, y) => true,
        zCenter: (x) => zOut,
        halfDepth: (x) => half,
        kind: SlotKind.tower,
        order: 2,
      ),
      // The bridge: a single span from the walkway out to the tower.
      Slab(
        x0: x0 + cx - 0.16, x1: x0 + cx + 0.16, y0: deck, y1: deck + 0.20,
        solid: (x, y) => true,
        zCenter: (x) => zOut / 2 + 0.1,
        halfDepth: (x) => zOut / 2 - 0.1,
        kind: SlotKind.deck,
        courseScale: 0.5,
        ornament: true,
        order: 88,
      ),
      // Its arch, springing under the deck.
      Slab(
        x0: x0 + cx - 0.11, x1: x0 + cx + 0.11, y0: deck - 0.4, y1: deck,
        solid: (x, y) {
          final t = (deck - y) / 0.4;
          return t < 0.55;
        },
        zCenter: (x) => zOut / 2 + 0.1,
        halfDepth: (x) => (zOut / 2 - 0.1) * 0.7,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: 87,
      ),
      _stringCourse(x0 + cx - half - 0.04, x0 + cx + half + 0.04, wallTop + 0.2,
          depth: half + 0.04, z: zOut),
      _corbels(x0 + cx - half - 0.08, x0 + cx + half + 0.08, top,
          depth: half + 0.12, period: 0.2, z: zOut),
      _crenellation(x0 + cx - half - 0.08, x0 + cx + half + 0.08, top + 0.17,
          0.4, half + 0.12, period: 0.44, z: zOut),
      _crenellation(x0, x0 + cx - 0.2, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + cx + 0.2, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, top + 0.57);
  }

  // ---------------------------------------------------------- 13. cistern

  /// A vaulted tank under the walkway, with a wellhead standing on it.
  StructureSpec _cistern(double x0) {
    const len = 2.9;
    const cx = 1.45, vr = 0.78, spring = 0.62;
    return StructureSpec([
      _curtain(x0, x0 + len,
          cut: (u, y) => _archHole(u, y, cx, vr, spring)),
      // The vault's back wall, set deep so you read a chamber, not a hole.
      Slab(
        x0: x0 + cx - vr, x1: x0 + cx + vr, y0: 0, y1: spring + vr,
        solid: (x, y) => _archHole(x - x0, y, cx, vr, spring),
        zCenter: (x) => -0.26,
        halfDepth: (x) => 0.10,
        kind: SlotKind.recess,
        courseScale: 0.55,
        order: 1,
      ),
      // Water: a flat, dark deck at the bottom of the tank.
      Slab(
        x0: x0 + cx - vr + 0.08, x1: x0 + cx + vr - 0.08, y0: 0.10, y1: 0.20,
        solid: (x, y) => true,
        zCenter: (x) => -0.06,
        halfDepth: (x) => 0.20,
        kind: SlotKind.deck,
        courseScale: 0.42,
        ornament: true,
        order: 86,
      ),
      // The wellhead on the walkway above.
      Slab(
        x0: x0 + cx - 0.30, x1: x0 + cx + 0.30, y0: wallTop, y1: wallTop + 0.42,
        solid: (x, y) => (x - x0 - cx).abs() > 0.14 || y > wallTop + 0.30,
        zCenter: _flat,
        halfDepth: (x) => 0.30,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: 88,
      ),
      _stringCourse(x0 + cx - vr - 0.1, x0 + cx + vr + 0.1, spring + vr,
          depth: _wallHalf + 0.05),
      _crenellation(x0, x0 + cx - 0.34, wallTop, crown, 0.288, period: 0.52),
      _crenellation(x0 + cx + 0.34, x0 + len, wallTop, crown, 0.288,
          period: 0.52, order: 21),
    ], len, cx, spring + vr);
  }

  // -------------------------------------------------------- 14. bent gate

  /// A gate you cannot charge through: the passage turns inside the mass.
  StructureSpec _bentGate(double x0) {
    const len = 3.7;
    const outer = 1.05, inner = 2.55, r = 0.40, spring = 0.98;
    final bandTop = wallTop + 0.40;
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: bandTop,
        solid: (x, y) {
          final u = x - x0;
          if (_archHole(u, y, outer, r, spring) && y < spring + r) {
            return false;
          }
          return true;
        },
        zCenter: (x) => 0.10,
        halfDepth: (x) => _wallHalf + 0.10,
        kind: SlotKind.body,
        order: 0,
      ),
      // The second arch, offset along the wall and set back in depth.
      Slab(
        x0: x0 + inner - r - 0.3, x1: x0 + inner + r + 0.3, y0: 0, y1: spring + r + 0.3,
        solid: (x, y) => !_archHole(x - x0, y, inner, r, spring),
        zCenter: (x) => -0.30,
        halfDepth: (x) => 0.18,
        kind: SlotKind.recess,
        courseScale: 0.6,
        order: 1,
      ),
      // The screen wall that forces the turn.
      Slab(
        x0: x0 + outer + r, x1: x0 + inner - r, y0: 0, y1: wallTop * 0.8,
        solid: (x, y) => true,
        zCenter: (x) => -0.05,
        halfDepth: (x) => 0.12,
        kind: SlotKind.body,
        courseScale: 0.7,
        order: 2,
      ),
      _stringCourse(x0, x0 + len, bandTop - 0.15, depth: _wallHalf + 0.16),
      _corbels(x0 + outer - r - 0.2, x0 + outer + r + 0.2, bandTop - 0.32,
          depth: _wallHalf + 0.22, period: 0.2),
      _crenellation(x0, x0 + len, bandTop, 0.42, _wallHalf + 0.06, period: 0.56),
    ], len, outer, spring + r);
  }

  // --------------------------------------------------------- 15. outworks

  /// A ravelin: a low angular apron thrown out in front of the wall.
  StructureSpec _outworks(double x0) {
    const len = 4.2;
    const a = 0.55, b = 3.65;
    double prow(double u) {
      final t = clampD((u - a) / (b - a), 0, 1);
      return 0.35 + 1.55 * (t < 0.5 ? t * 2 : (1 - t) * 2);
    }
    const deckTop = 1.05;
    return StructureSpec([
      _curtain(x0, x0 + len),
      // The apron itself: a squat glacis in front, its own parapet on top.
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0, y1: deckTop,
        solid: (x, y) => true,
        zCenter: (x) => 0.45 + prow(x - x0) / 2,
        halfDepth: (x) => prow(x - x0) / 2 + 0.12,
        kind: SlotKind.tower,
        courseScale: 0.9,
        order: 1,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: deckTop, y1: deckTop + 0.12,
        solid: (x, y) => true,
        zCenter: (x) => 0.45 + prow(x - x0) / 2,
        halfDepth: (x) => prow(x - x0) / 2 + 0.18,
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: 84,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: deckTop + 0.12, y1: deckTop + 0.48,
        solid: (x, y) => (x - x0 - a) % 0.46 < 0.28,
        zCenter: (x) => 0.45 + prow(x - x0) / 2,
        halfDepth: (x) => prow(x - x0) / 2 + 0.14,
        kind: SlotKind.merlon,
        courseScale: 0.66,
        ornament: true,
        order: crownOrder + 2,
      ),
      // A short causeway linking apron and wall.
      Slab(
        x0: x0 + (a + b) / 2 - 0.22, x1: x0 + (a + b) / 2 + 0.22,
        y0: deckTop - 0.2, y1: deckTop,
        solid: (x, y) => true,
        zCenter: (x) => 0.30,
        halfDepth: (x) => 0.30,
        kind: SlotKind.deck,
        courseScale: 0.45,
        ornament: true,
        order: 88,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.54, order: 21),
    ], len, (a + b) / 2, deckTop + 0.48);
  }

  // ---------------------------------------------------------- 16. postern

  /// The small door nobody is supposed to know about.
  StructureSpec _postern(double x0) {
    const len = 2.3;
    const cx = 1.15, r = 0.22, spring = 0.52;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => _archHole(u, y, cx, r, spring)),
      // A relieving arch above the door, discharging the load sideways.
      Slab(
        x0: x0 + cx - 0.46, x1: x0 + cx + 0.46,
        y0: spring + r + 0.06, y1: spring + r + 0.34,
        solid: (x, y) {
          final t = (y - spring - r - 0.06) / 0.28;
          return (x - x0 - cx).abs() <= lerpD(0.46, 0.12, t);
        },
        zCenter: (x) => 0.06,
        halfDepth: (x) => _wallHalf + 0.04,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: 84,
      ),
      // The recessed door head.
      Slab(
        x0: x0 + cx - r, x1: x0 + cx + r, y0: 0, y1: spring + r,
        solid: (x, y) => _archHole(x - x0, y, cx, r, spring),
        zCenter: (x) => -0.18,
        halfDepth: (x) => 0.10,
        kind: SlotKind.recess,
        courseScale: 0.45,
        order: 1,
      ),
      // Two steps down to it, narrowing as they go out.
      Slab(
        x0: x0 + cx - 0.34, x1: x0 + cx + 0.34, y0: 0, y1: 0.20,
        solid: (x, y) => y < 0.10 || (x - x0 - cx).abs() < 0.24,
        zCenter: (x) => 0.40,
        halfDepth: (x) => 0.16,
        kind: SlotKind.deck,
        courseScale: 0.4,
        ornament: true,
        order: 88,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.52),
    ], len, cx, spring + r);
  }

  // ---------------------------------------------------- 17. machicolation

  /// A long overhanging gallery, all corbels and shadow.
  StructureSpec _machicolation(double x0) {
    const len = 3.4;
    final gal = wallTop;
    return StructureSpec([
      _curtain(x0, x0 + len),
      _stringCourse(x0, x0 + len, gal - 0.42, depth: _wallHalf + 0.04),
      // Two receding rows of brackets, then the floor they carry.
      _corbels(x0, x0 + len, gal - 0.30, height: 0.14, depth: _wallHalf + 0.14,
          period: 0.44, duty: 0.5),
      _corbels(x0, x0 + len, gal - 0.16, height: 0.16, depth: _wallHalf + 0.26,
          period: 0.44, duty: 0.62, order: 16),
      Slab(
        x0: x0, x1: x0 + len, y0: gal, y1: gal + 0.14,
        solid: (x, y) => true,
        zCenter: (x) => 0.06,
        halfDepth: (x) => _wallHalf + 0.30,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: 87,
      ),
      // The parapet standing on the gallery, with its dropping slots.
      Slab(
        x0: x0, x1: x0 + len, y0: gal + 0.14, y1: gal + 0.62,
        solid: (x, y) => (x - x0) % 0.46 < 0.28,
        zCenter: (x) => 0.06,
        halfDepth: (x) => _wallHalf + 0.28,
        kind: SlotKind.merlon,
        courseScale: 0.68,
        ornament: true,
        order: crownOrder + 2,
      ),
    ], len, len / 2, gal + 0.62);
  }

  // ----------------------------------------------------------- 18. belfry

  /// An open stage with a bell hanging in it.
  StructureSpec _belfry(double x0) {
    const len = 2.6;
    const pa = 0.55, pb = 2.05, cx = 1.3;
    final stage = wallTop + 1.35;
    final r = (pb - pa) / 2 - 0.16;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= pa && u <= pb),
      _plinth(x0 + pa - 0.08, x0 + pb + 0.08, 0.4, 0.5),
      // Two piers carrying a pointed arch: the bell stage.
      Slab(
        x0: x0 + pa, x1: x0 + pb, y0: 0.4, y1: stage,
        solid: (x, y) =>
            !_pointedHole(x - x0, y - wallTop, cx, r, 0.22),
        zCenter: _flat,
        halfDepth: (x) => 0.44,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The bell.
      Slab(
        x0: x0 + cx - 0.19, x1: x0 + cx + 0.19,
        y0: wallTop + 0.44, y1: wallTop + 0.86,
        solid: (x, y) {
          final t = (y - wallTop - 0.44) / 0.42;
          return (x - x0 - cx).abs() <= lerpD(0.06, 0.19, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.17,
        kind: SlotKind.ornament,
        courseScale: 0.34,
        ornament: true,
        order: 88,
      ),
      _stringCourse(x0 + pa - 0.06, x0 + pb + 0.06, stage, depth: 0.50),
      // A gabled cap over the stage.
      Slab(
        x0: x0 + pa - 0.06, x1: x0 + pb + 0.06, y0: stage + 0.12, y1: stage + 0.72,
        solid: (x, y) {
          final t = (y - stage - 0.12) / 0.60;
          return (x - x0 - cx).abs() <= lerpD((pb - pa) / 2 + 0.06, 0.05, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.46,
        kind: SlotKind.ornament,
        courseScale: 0.5,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + pa, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + pb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, stage + 0.72);
  }

  // ------------------------------------------------------ 19. clock tower

  StructureSpec _clockTower(double x0) {
    const len = 2.5;
    const ta = 0.42, tb = 2.08, cx = 1.25;
    final top = wallTop + 2.15;
    final dialY = wallTop + 1.30;
    const dialR = 0.40;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= ta && u <= tb),
      _plinth(x0 + ta - 0.1, x0 + tb + 0.1, 0.48, 0.66),
      Slab(
        x0: x0 + ta, x1: x0 + tb, y0: 0.48, y1: top,
        solid: (x, y) {
          final dx = x - x0 - cx, dy = y - dialY;
          return dx * dx + dy * dy > dialR * dialR;
        },
        zCenter: _flat,
        halfDepth: (x) => 0.58,
        kind: SlotKind.tower,
        order: 1,
      ),
      // The dial itself, sunk into the face.
      Slab(
        x0: x0 + cx - dialR, x1: x0 + cx + dialR,
        y0: dialY - dialR, y1: dialY + dialR,
        solid: (x, y) {
          final dx = x - x0 - cx, dy = y - dialY;
          return dx * dx + dy * dy <= dialR * dialR;
        },
        zCenter: (x) => -0.14,
        halfDepth: (x) => 0.44,
        kind: SlotKind.recess,
        courseScale: 0.36,
        order: 2,
      ),
      _stringCourse(x0 + ta - 0.06, x0 + tb + 0.06, wallTop + 0.36, depth: 0.62),
      _stringCourse(x0 + ta - 0.06, x0 + tb + 0.06, dialY + dialR + 0.12, depth: 0.62),
      _corbels(x0 + ta - 0.12, x0 + tb + 0.12, top, depth: 0.68, period: 0.22),
      // A short spire.
      Slab(
        x0: x0 + ta - 0.06, x1: x0 + tb + 0.06, y0: top + 0.17, y1: top + 0.95,
        solid: (x, y) {
          final t = (y - top - 0.17) / 0.78;
          return (x - x0 - cx).abs() <= lerpD((tb - ta) / 2 + 0.06, 0.05, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.60,
        kind: SlotKind.ornament,
        courseScale: 0.52,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + ta, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + tb, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, dialY);
  }

  // --------------------------------------------------------- 20. windmill

  /// A stone tower mill, sails and all.
  StructureSpec _windmill(double x0) {
    const len = 2.7;
    const cx = 1.35;
    final capY = wallTop + 1.70;
    final hub = capY + 0.30;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => (u - cx).abs() <= 0.70),
      _drum(x0 + cx, 0.68, 0, 0.5, courseScale: 0.86, order: 0),
      _drum(x0 + cx, 0.60, 0.5, wallTop + 0.7, order: 1),
      _drum(x0 + cx, 0.48, wallTop + 0.7, capY, order: 2),
      _stringCourse(x0 + cx - 0.62, x0 + cx + 0.62, wallTop + 0.62, depth: 0.62),
      // The cap.
      Slab(
        x0: x0 + cx - 0.52, x1: x0 + cx + 0.52, y0: capY, y1: capY + 0.46,
        solid: (x, y) {
          final t = (y - capY) / 0.46;
          return (x - x0 - cx).abs() <= lerpD(0.52, 0.10, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.50,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: capOrder,
      ),
      // Four sails on a cross, out in front of the cap. Built as real timber
      // and not as hairlines: anything thinner than this rendered as a stray
      // scratch across the wall rather than as a sail.
      Slab(
        x0: x0 + cx - 1.05, x1: x0 + cx + 1.05, y0: hub - 0.17, y1: hub + 0.17,
        solid: (x, y) => true,
        zCenter: (x) => 0.78,
        halfDepth: (x) => 0.17,
        kind: SlotKind.ornament,
        courseScale: 0.7,
        ornament: true,
        order: capOrder + 2,
      ),
      Slab(
        x0: x0 + cx - 0.17, x1: x0 + cx + 0.17, y0: hub - 1.05, y1: hub + 1.05,
        solid: (x, y) => true,
        zCenter: (x) => 0.78,
        halfDepth: (x) => 0.17,
        kind: SlotKind.ornament,
        courseScale: 0.7,
        ornament: true,
        order: capOrder + 3,
      ),
      _crenellation(x0, x0 + cx - 0.6, wallTop, crown, 0.272, period: 0.5, order: 24),
      _crenellation(x0 + cx + 0.6, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 25),
    ], len, cx, hub);
  }

  // --------------------------------------------------- 21. double arcade

  /// Two storeys of arches. The Roman answer to a valley.
  StructureSpec _doubleArcade(double x0) {
    const len = 4.6;
    const lower = [1.15, 2.30, 3.45];
    const lr = 0.46, lspring = 0.98;
    final upperBase = lspring + lr + 0.30;
    const ur = 0.26;
    final top = math.max(wallTop, upperBase + ur * 2.2 + 0.30);
    final uspring = upperBase + 0.34;
    final upper = <double>[
      for (var i = 0; i < 7; i++) 0.60 + i * 0.58,
    ];
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: upperBase,
        solid: (x, y) {
          final u = x - x0;
          for (final c in lower) {
            if (_archHole(u, y, c, lr, lspring)) return false;
          }
          return true;
        },
        zCenter: _flat,
        halfDepth: (x) => _wallHalf + 0.08,
        kind: SlotKind.body,
        order: 0,
      ),
      Slab(
        x0: x0, x1: x0 + len, y0: upperBase, y1: top,
        solid: (x, y) {
          final u = x - x0;
          for (final c in upper) {
            if (_archHole(u, y, c, ur, uspring)) return false;
          }
          return true;
        },
        zCenter: _flat,
        halfDepth: (x) => _wallHalf,
        kind: SlotKind.body,
        courseScale: 0.8,
        order: 1,
      ),
      _stringCourse(x0, x0 + len, upperBase - 0.13, depth: _wallHalf + 0.14),
      _stringCourse(x0, x0 + len, top - 0.13, depth: _wallHalf + 0.08),
      _crenellation(x0, x0 + len, top, 0.38, 0.30, period: 0.56),
    ], len, lower[1], lspring + lr);
  }

  // ------------------------------------------------------- 22. twin stair

  /// Two flights meeting on a landing: the ceremonial way up.
  StructureSpec _twinStair(double x0) {
    const len = 3.3;
    const a = 0.22, b = 3.08, mid = 1.65;
    final steps = math.max(6, (wallTop / 0.30).round());
    double stepTop(double u) {
      final t = u < mid
          ? clampD((u - a) / (mid - 0.22 - a), 0, 1)
          : clampD((b - u) / (b - mid - 0.22), 0, 1);
      return wallTop * ((t * steps).floor() + 1) / steps;
    }
    return StructureSpec([
      _curtain(x0, x0 + len),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0, y1: wallTop,
        solid: (x, y) => y <= stepTop(x - x0),
        zCenter: (x) => 0.68,
        halfDepth: (x) => 0.22,
        kind: SlotKind.tower,
        courseScale: 0.78,
        order: 1,
      ),
      // The landing the two flights share.
      Slab(
        x0: x0 + mid - 0.30, x1: x0 + mid + 0.30,
        y0: wallTop, y1: wallTop + 0.14,
        solid: (x, y) => true,
        zCenter: (x) => 0.68,
        halfDepth: (x) => 0.28,
        kind: SlotKind.deck,
        courseScale: 0.44,
        ornament: true,
        order: 88,
      ),
      // Newel posts at the foot of each flight.
      Slab(
        x0: x0 + a - 0.02, x1: x0 + b + 0.02, y0: 0, y1: 0.62,
        solid: (x, y) {
          final u = x - x0;
          return u < a + 0.16 || u > b - 0.16;
        },
        zCenter: (x) => 0.84,
        halfDepth: (x) => 0.13,
        kind: SlotKind.ornament,
        courseScale: 0.4,
        ornament: true,
        order: 87,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.54, order: 21),
    ], len, mid, wallTop);
  }

  // ------------------------------------------------------ 23. moat bridge

  /// A bridge on piers, stepping out from a gate towards the far bank.
  StructureSpec _moatBridge(double x0) {
    const len = 3.2;
    const gx = 1.6, gr = 0.42, gspring = 1.0;
    const deckY = 0.92;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => _archHole(u, y, gx, gr, gspring)),
      // Three piers marching out into the moat.
      for (var i = 0; i < 3; i++)
        Slab(
          x0: x0 + gx - 0.22, x1: x0 + gx + 0.22, y0: 0, y1: deckY,
          solid: (x, y) => true,
          zCenter: (x) => 0.75 + i * 0.62,
          halfDepth: (x) => 0.15,
          kind: SlotKind.tower,
          courseScale: 0.7,
          order: 1 + i,
        ),
      // The deck they carry.
      Slab(
        x0: x0 + gx - 0.30, x1: x0 + gx + 0.30, y0: deckY, y1: deckY + 0.16,
        solid: (x, y) => true,
        zCenter: (x) => 1.32,
        halfDepth: (x) => 1.30,
        kind: SlotKind.deck,
        courseScale: 0.5,
        ornament: true,
        order: 88,
      ),
      // Low parapets down both sides of the deck.
      Slab(
        x0: x0 + gx - 0.30, x1: x0 + gx + 0.30,
        y0: deckY + 0.16, y1: deckY + 0.44,
        solid: (x, y) => (x - x0 - gx).abs() > 0.20,
        zCenter: (x) => 1.32,
        halfDepth: (x) => 1.30,
        kind: SlotKind.ornament,
        courseScale: 0.36,
        ornament: true,
        order: 89,
      ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.52, order: 22),
    ], len, gx, gspring + gr);
  }

  // ------------------------------------------------------- 24. spur tower

  /// A tower with a beaked prow: shot glances off it instead of biting.
  StructureSpec _spurTower(double x0) {
    const len = 3.1;
    const a = 0.55, b = 2.55, cx = 1.55;
    final top = wallTop + 1.75;
    double prow(double u) {
      final t = ((u - cx).abs()) / ((b - a) / 2);
      return lerpD(1.55, 0.42, clampD(t, 0, 1));
    }
    double zc(double x) => (prow(x - x0) - 0.42) / 2;
    double hd(double x) => (prow(x - x0) + 0.42) / 2;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= a && u <= b),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0, y1: 0.6,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.1,
        kind: SlotKind.tower,
        courseScale: 0.86,
        order: 0,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0.6, y1: top,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: hd,
        kind: SlotKind.tower,
        order: 1,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: wallTop + 0.2, y1: wallTop + 0.32,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.05,
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: 84,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: top, y1: top + 0.14,
        solid: (x, y) => true,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.09,
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: 85,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: top + 0.14, y1: top + 0.56,
        solid: (x, y) => (x - x0 - a) % 0.44 < 0.26,
        zCenter: zc,
        halfDepth: (x) => hd(x) + 0.05,
        kind: SlotKind.merlon,
        courseScale: 0.68,
        ornament: true,
        order: crownOrder + 2,
      ),
      _crenellation(x0, x0 + a, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + b, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, top + 0.56);
  }

  // -------------------------------------------------- 25. triumphal arch

  /// One monumental span, pilasters, entablature and an attic storey.
  StructureSpec _triumphalArch(double x0) {
    const len = 3.6;
    const cx = 1.8, r = 0.66, spring = 1.28;
    final cornice = math.max(wallTop, spring + r + 0.42);
    return StructureSpec([
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: cornice,
        solid: (x, y) => !_archHole(x - x0, y, cx, r, spring),
        zCenter: _flat,
        halfDepth: (x) => _wallHalf + 0.06,
        kind: SlotKind.body,
        order: 0,
      ),
      // Four pilasters standing proud of the face.
      Slab(
        x0: x0, x1: x0 + len, y0: 0, y1: cornice,
        solid: (x, y) {
          final u = x - x0;
          for (final p in const [0.42, 1.02, 2.58, 3.18]) {
            if ((u - p).abs() < 0.13) return true;
          }
          return false;
        },
        zCenter: (x) => 0.12,
        halfDepth: (x) => _wallHalf + 0.16,
        kind: SlotKind.tower,
        courseScale: 0.8,
        order: 1,
      ),
      // Capitals.
      Slab(
        x0: x0, x1: x0 + len, y0: cornice - 0.20, y1: cornice - 0.04,
        solid: (x, y) {
          final u = x - x0;
          for (final p in const [0.42, 1.02, 2.58, 3.18]) {
            if ((u - p).abs() < 0.19) return true;
          }
          return false;
        },
        zCenter: (x) => 0.12,
        halfDepth: (x) => _wallHalf + 0.22,
        kind: SlotKind.ornament,
        courseScale: 0.34,
        ornament: true,
        order: 84,
      ),
      _stringCourse(x0, x0 + len, cornice, height: 0.18,
          depth: _wallHalf + 0.24, z: 0.06, order: 85),
      // The attic: a plain block carrying the inscription.
      Slab(
        x0: x0 + 0.3, x1: x0 + len - 0.3, y0: cornice + 0.18, y1: cornice + 0.86,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => _wallHalf + 0.06,
        kind: SlotKind.body,
        courseScale: 0.7,
        order: 86,
      ),
      _stringCourse(x0 + 0.24, x0 + len - 0.24, cornice + 0.86,
          height: 0.14, depth: _wallHalf + 0.14, order: 87),
    ], len, cx, spring + r);
  }

  // --------------------------------------------------------- 26. casemate

  /// A thick gun deck, all batter and embrasures.
  StructureSpec _casemate(double x0) {
    const len = 3.9;
    const a = 0.35, b = 3.55;
    const guns = [1.05, 1.95, 2.85];
    const gy0 = 0.86, gy1 = 1.34;
    final top = math.max(wallTop, gy1 + 0.46);
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => u >= a && u <= b),
      // Battered base: three receding masses instead of one box.
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0, y1: 0.42,
        solid: (x, y) => true,
        zCenter: (x) => 0.34,
        halfDepth: (x) => 0.74,
        kind: SlotKind.tower,
        courseScale: 0.9,
        order: 0,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0.42, y1: 0.86,
        solid: (x, y) => true,
        zCenter: (x) => 0.30,
        halfDepth: (x) => 0.66,
        kind: SlotKind.tower,
        courseScale: 0.9,
        order: 1,
      ),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: 0.86, y1: top,
        solid: (x, y) {
          final u = x - x0;
          for (final g in guns) {
            if (_embrasure(u, y, g, gy0, gy1, 0.09, 0.30)) return false;
          }
          return true;
        },
        zCenter: (x) => 0.26,
        halfDepth: (x) => 0.58,
        kind: SlotKind.tower,
        order: 2,
      ),
      // The dark throats behind the embrasures.
      for (var i = 0; i < guns.length; i++)
        Slab(
          x0: x0 + guns[i] - 0.31, x1: x0 + guns[i] + 0.31, y0: gy0, y1: gy1,
          solid: (x, y) => _embrasure(x - x0, y, guns[i], gy0, gy1, 0.09, 0.30),
          zCenter: (x) => -0.18,
          halfDepth: (x) => 0.14,
          kind: SlotKind.recess,
          courseScale: 0.5,
          order: 95 + i,
        ),
      _stringCourse(x0 + a, x0 + b, top - 0.14, depth: 0.66, z: 0.26),
      Slab(
        x0: x0 + a, x1: x0 + b, y0: top, y1: top + 0.34,
        solid: (x, y) => true,
        zCenter: (x) => 0.26,
        halfDepth: (x) => 0.60,
        kind: SlotKind.merlon,
        courseScale: 0.6,
        ornament: true,
        order: crownOrder + 2,
      ),
      _crenellation(x0, x0 + a, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + b, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, guns[1], gy1);
  }

  // ------------------------------------------------------- 27. buttresses

  /// A weak stretch braced by stepped buttresses with weathering set-offs.
  StructureSpec _buttresses(double x0) {
    const len = 3.6;
    const at = [0.55, 1.75, 2.95];
    final h1 = wallTop * 0.42, h2 = wallTop * 0.72, h3 = wallTop * 0.94;
    Slab stage(double y0, double y1, double halfW, double proj, int order) {
      return Slab(
        x0: x0, x1: x0 + len, y0: y0, y1: y1,
        solid: (x, y) {
          final u = x - x0;
          for (final c in at) {
            if ((u - c).abs() <= halfW) return true;
          }
          return false;
        },
        zCenter: (x) => (proj - _wallHalf) / 2,
        halfDepth: (x) => (proj + _wallHalf) / 2,
        kind: SlotKind.tower,
        courseScale: 0.84,
        order: order,
      );
    }
    return StructureSpec([
      _curtain(x0, x0 + len),
      stage(0, h1, 0.30, 0.86, 1),
      stage(h1, h2, 0.25, 0.66, 2),
      stage(h2, h3, 0.20, 0.48, 3),
      // The sloping weatherings that shed rain off each set-off.
      for (final y in [h1, h2, h3])
        Slab(
          x0: x0, x1: x0 + len, y0: y, y1: y + 0.11,
          solid: (x, y) {
            final u = x - x0;
            for (final c in at) {
              if ((u - c).abs() <= 0.32) return true;
            }
            return false;
          },
          zCenter: (x) => _wallHalf + 0.20,
          halfDepth: (x) => 0.42,
          kind: SlotKind.ornament,
          courseScale: 0.36,
          ornament: true,
          order: 84,
        ),
      _crenellation(x0, x0 + len, wallTop, crown, 0.288, period: 0.54, order: 21),
    ], len, at[1], h3);
  }

  // --------------------------------------------------- 28. octagon tower

  StructureSpec _octagonTower(double x0) {
    const len = 2.9;
    const cx = 1.45, r = 0.66;
    final top = wallTop + 2.25;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => (u - cx).abs() <= r + 0.12),
      _octagon(x0 + cx, r + 0.12, 0, 0.52, order: 0),
      _octagon(x0 + cx, r, 0.52, wallTop + 0.9, order: 1),
      _octagon(x0 + cx, r - 0.07, wallTop + 1.02, top, order: 2),
      Slab(
        x0: x0 + cx - r - 0.04, x1: x0 + cx + r + 0.04,
        y0: wallTop + 0.9, y1: wallTop + 1.02,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) {
          final t = ((x - x0 - cx) / (r + 0.04)).abs();
          return t <= 0.4142
              ? r + 0.04
              : math.max(0.08, (r + 0.04) * (1 - t) / 0.5858);
        },
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: 84,
      ),
      // Narrow lancets on the faces.
      Slab(
        x0: x0 + cx - 0.5, x1: x0 + cx + 0.5,
        y0: wallTop + 0.2, y1: wallTop + 0.75,
        solid: (x, y) => ((x - x0 - cx + 0.5) % 0.5) < 0.09,
        zCenter: (x) => -0.20,
        halfDepth: (x) => 0.32,
        kind: SlotKind.recess,
        courseScale: 0.5,
        order: 95,
      ),
      _corbels(x0 + cx - r - 0.06, x0 + cx + r + 0.06, top,
          depth: r + 0.12, period: 0.2),
      _crenellation(x0 + cx - r - 0.06, x0 + cx + r + 0.06, top + 0.17,
          0.44, r + 0.10, period: 0.46),
      _crenellation(x0, x0 + cx - r, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + cx + r, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, top + 0.61);
  }

  // --------------------------------------------------------- 29. dovecote

  /// A squat drum honeycombed with nesting holes.
  StructureSpec _dovecote(double x0) {
    const len = 2.4;
    const cx = 1.2, r = 0.72;
    final top = wallTop + 0.95;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => (u - cx).abs() <= r + 0.10),
      _drum(x0 + cx, r + 0.1, 0, 0.4, courseScale: 0.86, order: 0),
      _drum(x0 + cx, r, 0.4, top, order: 1),
      // Rows of nesting holes punched into the face.
      Slab(
        x0: x0 + cx - r + 0.12, x1: x0 + cx + r - 0.12,
        y0: 0.62, y1: top - 0.18,
        solid: (x, y) {
          final u = (x - x0 - cx + r) % 0.44;
          final v = (y - 0.62) % 0.52;
          return u < 0.17 && v < 0.22;
        },
        zCenter: (x) => -0.12,
        halfDepth: (x) => r * 0.55,
        kind: SlotKind.recess,
        courseScale: 0.5,
        // Last of all: fine detail must never be built before the crown it
        // decorates, or a landmark short of bricks ends up headless.
        order: 95,
      ),
      _stringCourse(x0 + cx - r - 0.04, x0 + cx + r + 0.04, 0.48, depth: r + 0.04),
      _corbels(x0 + cx - r - 0.06, x0 + cx + r + 0.06, top,
          depth: r + 0.14, period: 0.19),
      // A shallow conical cap.
      Slab(
        x0: x0 + cx - r - 0.06, x1: x0 + cx + r + 0.06,
        y0: top + 0.17, y1: top + 0.62,
        solid: (x, y) {
          final t = (y - top - 0.17) / 0.45;
          return (x - x0 - cx).abs() <= lerpD(r + 0.06, 0.06, t);
        },
        zCenter: _flat,
        halfDepth: (x) => r * 0.9,
        kind: SlotKind.ornament,
        courseScale: 0.44,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + cx - r, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + cx + r, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, top + 0.62);
  }

  // ------------------------------------------------------- 30. lighthouse

  /// Three receding drums and a lantern: the tallest thing on the wall.
  StructureSpec _lighthouse(double x0) {
    const len = 3.0;
    const cx = 1.5;
    final s1 = wallTop + 0.9;
    final s2 = s1 + 1.45;
    final s3 = s2 + 1.20;
    return StructureSpec([
      _curtain(x0, x0 + len, cut: (u, y) => (u - cx).abs() <= 0.92),
      _drum(x0 + cx, 0.90, 0, 0.55, courseScale: 0.86, order: 0),
      _drum(x0 + cx, 0.82, 0.55, s1, order: 1),
      _stringCourse(x0 + cx - 0.86, x0 + cx + 0.86, s1, depth: 0.86),
      _drum(x0 + cx, 0.62, s1 + 0.12, s2, order: 2),
      _stringCourse(x0 + cx - 0.66, x0 + cx + 0.66, s2, depth: 0.66, order: 85),
      _drum(x0 + cx, 0.44, s2 + 0.12, s3, order: 3),
      _corbels(x0 + cx - 0.5, x0 + cx + 0.5, s3, depth: 0.56, period: 0.18),
      // The lantern: an open cage of piers with a fire inside.
      Slab(
        x0: x0 + cx - 0.42, x1: x0 + cx + 0.42, y0: s3 + 0.17, y1: s3 + 0.78,
        solid: (x, y) => ((x - x0 - cx + 0.42) % 0.28) < 0.13,
        zCenter: _flat,
        halfDepth: (x) => 0.42,
        kind: SlotKind.tower,
        courseScale: 0.44,
        order: 4,
      ),
      Slab(
        x0: x0 + cx - 0.20, x1: x0 + cx + 0.20, y0: s3 + 0.24, y1: s3 + 0.56,
        solid: (x, y) => true,
        zCenter: _flat,
        halfDepth: (x) => 0.20,
        kind: SlotKind.ornament,
        courseScale: 0.3,
        ornament: true,
        order: 88,
      ),
      // Its roof.
      Slab(
        x0: x0 + cx - 0.5, x1: x0 + cx + 0.5, y0: s3 + 0.78, y1: s3 + 1.22,
        solid: (x, y) {
          final t = (y - s3 - 0.78) / 0.44;
          return (x - x0 - cx).abs() <= lerpD(0.50, 0.05, t);
        },
        zCenter: _flat,
        halfDepth: (x) => 0.48,
        kind: SlotKind.ornament,
        courseScale: 0.42,
        ornament: true,
        order: capOrder,
      ),
      _crenellation(x0, x0 + cx - 0.82, wallTop, crown, 0.272, period: 0.5, order: 21),
      _crenellation(x0 + cx + 0.82, x0 + len, wallTop, crown, 0.272, period: 0.5, order: 22),
    ], len, cx, s3 + 0.78);
  }
}
