import 'dart:math' as math;

import '../core/rng.dart';

/// What a piece of a building is doing, which is all the renderer needs to know
/// to draw it.
enum PieceKind { plinth, floor, roof, chimney, dormer, porch, parapet, spire }

/// One achievement, as a piece of a building.
///
/// The whole point of the city over the wall: a brick in a wall only ever means
/// "the wall is one brick longer", but a piece of a house means "the house is
/// nearly finished", and three days later the house *is* finished. There is a
/// completion to look forward to that is closer than the next landmark.
class CityPiece {
  CityPiece({
    required this.index,
    required this.building,
    required this.kind,
    required this.cx,
    required this.cz,
    required this.w,
    required this.d,
    required this.y0,
    required this.y1,
    required this.seed,
    this.alongX = true,
  });

  /// Which achievement laid this piece.
  final int index;
  final int building;
  final PieceKind kind;

  /// Centre and footprint on the ground.
  final double cx, cz, w, d;

  /// Bottom and top. For a roof, [y1] is the ridge.
  final double y0, y1;

  final int seed;

  /// Ridge direction of a roof.
  final bool alongX;

  double get x0 => cx - w / 2;
  double get x1 => cx + w / 2;
  double get z0 => cz - d / 2;
  double get z1 => cz + d / 2;
}

enum BuildingKind {
  shed,
  cottage,
  workshop,
  house,
  granary,
  townhouse,
  inn,
  hall,
  market,
  tower,
  church,
}

/// How many achievements each kind of building costs.
const Map<BuildingKind, int> buildingCost = {
  BuildingKind.shed: 2,
  BuildingKind.cottage: 3,
  BuildingKind.workshop: 4,
  BuildingKind.house: 5,
  BuildingKind.granary: 6,
  BuildingKind.townhouse: 7,
  BuildingKind.inn: 8,
  BuildingKind.hall: 10,
  BuildingKind.market: 9,
  BuildingKind.tower: 13,
  BuildingKind.church: 20,
};

const Map<BuildingKind, String> buildingName = {
  BuildingKind.shed: 'Cobertizo',
  BuildingKind.cottage: 'Casa',
  BuildingKind.workshop: 'Taller',
  BuildingKind.house: 'Casona',
  BuildingKind.granary: 'Granero',
  BuildingKind.townhouse: 'Casa de vecinos',
  BuildingKind.inn: 'Posada',
  BuildingKind.hall: 'Concejo',
  BuildingKind.market: 'Mercado',
  BuildingKind.tower: 'Torre del reloj',
  BuildingKind.church: 'Iglesia',
};

/// The landmarks: the buildings that mark an era of the town rather than a
/// week of it.
const Set<BuildingKind> landmarkKinds = {
  BuildingKind.hall,
  BuildingKind.market,
  BuildingKind.tower,
  BuildingKind.church,
};

class CityBuilding {
  CityBuilding({
    required this.index,
    required this.kind,
    required this.firstPiece,
    required this.cx,
    required this.cz,
    required this.seed,
  });

  final int index;
  final BuildingKind kind;

  /// The achievement that started it.
  final int firstPiece;
  final double cx, cz;
  final int seed;

  int get cost => buildingCost[kind]!;
  String get name => buildingName[kind]!;
  bool get isLandmark => landmarkKinds.contains(kind);

  /// Filled in as the pieces are generated.
  double peakY = 0;
  int placedPieces = 0;
  bool get finished => placedPieces >= cost;
}

/// The order the town is built in.
///
/// A pure function of the building's number, exactly like the wall's plan, so
/// the hundredth achievement lands on the same piece of the same house whether
/// it is placed today or replayed on a fresh install.
class CityPlan {
  const CityPlan._();

  /// Landmarks arrive at a widening cadence, so the first one is close enough
  /// to be worth waiting for and the tenth does not arrive every other week.
  static bool isLandmarkSlot(int b) {
    var at = 5, gap = 8;
    while (at < b) {
      at += gap;
      gap += 3;
    }
    return at == b;
  }

  static BuildingKind kindFor(int b) {
    if (isLandmarkSlot(b)) {
      const rota = [
        BuildingKind.market,
        BuildingKind.hall,
        BuildingKind.church,
        BuildingKind.tower,
      ];
      var n = 0, at = 5, gap = 8;
      while (at < b) {
        at += gap;
        gap += 3;
        n++;
      }
      return rota[n % rota.length];
    }
    // Ordinary houses get grander as the town does, but never so much that a
    // small one stops appearing: a town of nothing but mansions is a suburb.
    final List<BuildingKind> pool;
    if (b < 7) {
      pool = const [
        BuildingKind.shed,
        BuildingKind.cottage,
        BuildingKind.cottage,
        BuildingKind.workshop,
      ];
    } else if (b < 22) {
      pool = const [
        BuildingKind.cottage,
        BuildingKind.house,
        BuildingKind.workshop,
        BuildingKind.house,
        BuildingKind.granary,
      ];
    } else {
      pool = const [
        BuildingKind.house,
        BuildingKind.townhouse,
        BuildingKind.granary,
        BuildingKind.inn,
        BuildingKind.townhouse,
        BuildingKind.cottage,
      ];
    }
    return pool[(hash01(b, 0x51ce) * pool.length).floor() % pool.length];
  }
}

/// The town, laid out from a number of achievements.
///
/// Deterministic and append-only in the same way the wall is: a house built
/// last spring is on the same plot, the same shape, for good.
class CityLayout {
  CityLayout(this.placed) {
    _build();
  }

  /// One extra piece is always laid out so the app can show a ghost of where
  /// the next one goes.
  final int placed;

  final List<CityPiece> pieces = [];
  final List<CityBuilding> buildings = [];

  /// How far the town reaches from its centre, for framing the camera.
  double radius = 4;

  CityPiece? pieceFor(int index) =>
      index >= 0 && index < pieces.length ? pieces[index] : null;

  CityBuilding? buildingOf(int index) {
    final p = pieceFor(index);
    return p == null ? null : buildings[p.building];
  }

  static const double plotPitch = 2.5;
  static const double blockPitch = 9.0;

  void _build() {
    final want = placed + 1;

    // How many buildings the town needs to hold that many pieces.
    var count = 0, total = 0;
    while (total < want) {
      total += buildingCost[CityPlan.kindFor(count)]!;
      count++;
    }
    count = math.max(count, 1);

    final plots = _plots(count);
    var index = 0;
    for (var b = 0; b < count; b++) {
      final kind = CityPlan.kindFor(b);
      final seed = hash32(b, 0x9e37, 17);
      final building = CityBuilding(
        index: b,
        kind: kind,
        firstPiece: index,
        cx: plots[b].$1,
        cz: plots[b].$2,
        seed: seed,
      );
      final made = _piecesOf(building);
      for (final p in made) {
        if (index >= want) break;
        pieces.add(CityPiece(
          index: index,
          building: b,
          kind: p.kind,
          cx: p.cx,
          cz: p.cz,
          w: p.w,
          d: p.d,
          y0: p.y0,
          y1: p.y1,
          seed: hash32(seed, index, 31),
          alongX: p.alongX,
        ));
        if (p.y1 > building.peakY) building.peakY = p.y1;
        building.placedPieces = index - building.firstPiece + 1;
        index++;
      }
      buildings.add(building);
      final reach =
          math.sqrt(building.cx * building.cx + building.cz * building.cz);
      if (reach + 2 > radius) radius = reach + 2;
      if (index >= want) break;
    }
  }

  /// The plots, nearest the centre first.
  ///
  /// A square grid of blocks with streets between them, taken in order of
  /// distance from the middle with a little jitter so the edge of the town is
  /// ragged rather than a circle drawn with a compass. The jitter is smaller
  /// than a plot, so the order of the first N plots never changes when the
  /// town needs more of them.
  List<(double, double)> _plots(int want) {
    final rings = math.max(2, (math.sqrt(want / 9) + 3).ceil());
    final all = <(double, double, double)>[];
    for (var bx = -rings; bx <= rings; bx++) {
      for (var bz = -rings; bz <= rings; bz++) {
        for (var px = 0; px < 3; px++) {
          for (var pz = 0; pz < 3; pz++) {
            final x = bx * blockPitch + px * plotPitch + plotPitch / 2;
            final z = bz * blockPitch + pz * plotPitch + plotPitch / 2;
            final key = math.sqrt(x * x + z * z) +
                hashRange(0, 2.2, bx + 991, bz + 991, px, pz);
            all.add((x, z, key));
          }
        }
      }
    }
    all.sort((a, b) {
      final c = a.$3.compareTo(b.$3);
      if (c != 0) return c;
      final d = a.$1.compareTo(b.$1);
      return d != 0 ? d : a.$2.compareTo(b.$2);
    });
    final out = <(double, double)>[];
    for (final e in all) {
      if (out.length >= want) break;
      out.add((e.$1, e.$2));
    }
    return out;
  }

  List<_Spec> _piecesOf(CityBuilding b) {
    final s = b.seed;
    final out = <_Spec>[];
    // Every building sits a little differently on its plot, so a grid of them
    // never lines up into a barracks.
    final ox = hashRange(-0.22, 0.22, s, 3);
    final oz = hashRange(-0.22, 0.22, s, 4);
    final cx = b.cx + ox, cz = b.cz + oz;
    final ridgeAlongX = hash01(s, 5) < 0.5;

    double y = 0;
    /// Adds a piece and, unless it is [ridge] work, raises the course line so
    /// the next piece sits on top of it. [at] pins the piece to a height of its
    /// own: a door belongs on the ground, whatever has been built above it.
    void box(PieceKind k, double w, double d, double h,
        {double dx = 0, double dz = 0, bool ridge = false, double? at}) {
      final base = at ?? y;
      out.add(_Spec(
        kind: k,
        cx: cx + dx,
        cz: cz + dz,
        w: w,
        d: d,
        y0: base,
        y1: base + h,
        alongX: ridgeAlongX,
      ));
      if (!ridge && at == null) y += h;
    }

    void roof(double w, double d, double rise, {double dx = 0, double dz = 0}) {
      out.add(_Spec(
        kind: PieceKind.roof,
        cx: cx + dx,
        cz: cz + dz,
        w: w,
        d: d,
        y0: y,
        y1: y + rise,
        alongX: ridgeAlongX,
      ));
    }

    final wide = hashRange(1.45, 1.85, s, 6);
    final deep = hashRange(1.35, 1.75, s, 7);
    final storey = hashRange(0.92, 1.14, s, 8);

    switch (b.kind) {
      case BuildingKind.shed:
        box(PieceKind.floor, wide * 0.8, deep * 0.8, storey * 0.78);
        roof(wide * 0.86, deep * 0.86, 0.42);
      case BuildingKind.cottage:
        box(PieceKind.floor, wide, deep, storey);
        roof(wide + 0.16, deep + 0.16, 0.62);
        box(PieceKind.chimney, 0.26, 0.26, 0.75,
            dx: wide * 0.28, dz: deep * 0.18, ridge: true);
      case BuildingKind.workshop:
        box(PieceKind.floor, wide, deep, storey);
        box(PieceKind.floor, wide, deep, storey * 0.85);
        roof(wide + 0.16, deep + 0.16, 0.58);
        box(PieceKind.porch, wide * 0.5, 0.5, 0.66,
            dz: deep * 0.5 + 0.22, ridge: true, at: 0);
      case BuildingKind.house:
        box(PieceKind.floor, wide, deep, storey);
        box(PieceKind.floor, wide, deep, storey * 0.92);
        roof(wide + 0.18, deep + 0.18, 0.7);
        box(PieceKind.chimney, 0.28, 0.28, 0.9,
            dx: -wide * 0.3, dz: deep * 0.2, ridge: true);
        box(PieceKind.dormer, 0.5, 0.42, 0.42,
            dz: deep * 0.28, ridge: true);
      case BuildingKind.granary:
        box(PieceKind.plinth, wide + 0.3, deep + 0.3, 0.34);
        box(PieceKind.floor, wide, deep, storey * 1.15);
        box(PieceKind.floor, wide, deep, storey);
        roof(wide + 0.22, deep + 0.22, 0.78);
        box(PieceKind.porch, wide * 0.42, 0.44, 0.5,
            dz: deep * 0.5 + 0.2, ridge: true, at: 0);
        box(PieceKind.dormer, 0.42, 0.36, 0.4, dz: -deep * 0.28, ridge: true);
      case BuildingKind.townhouse:
        box(PieceKind.floor, wide, deep, storey);
        box(PieceKind.floor, wide, deep, storey * 0.94);
        box(PieceKind.floor, wide, deep, storey * 0.88);
        roof(wide + 0.16, deep + 0.16, 0.66);
        box(PieceKind.chimney, 0.26, 0.26, 0.85,
            dx: wide * 0.3, ridge: true);
        box(PieceKind.dormer, 0.46, 0.4, 0.4, dz: deep * 0.26, ridge: true);
        box(PieceKind.porch, wide * 0.44, 0.42, 0.62,
            dz: deep * 0.5 + 0.2, ridge: true, at: 0);
      case BuildingKind.inn:
        box(PieceKind.floor, wide * 1.15, deep, storey * 1.1);
        box(PieceKind.floor, wide * 1.15, deep, storey);
        roof(wide * 1.25, deep + 0.2, 0.72);
        // The side wing stands on the ground beside the inn, not on its roof;
        // its own little roof below is pinned to the same height.
        box(PieceKind.floor, wide * 0.6, deep * 0.7, storey * 0.9,
            dx: wide * 0.8, ridge: true, at: 0);
        out.add(_Spec(
          kind: PieceKind.roof,
          cx: cx + wide * 0.8,
          cz: cz,
          w: wide * 0.66,
          d: deep * 0.76,
          y0: storey * 0.9,
          y1: storey * 0.9 + 0.44,
          alongX: !ridgeAlongX,
        ));
        box(PieceKind.chimney, 0.3, 0.3, 1.0, dx: -wide * 0.4, ridge: true);
        box(PieceKind.chimney, 0.26, 0.26, 0.8, dx: wide * 0.2, ridge: true);
        box(PieceKind.porch, wide * 0.7, 0.5, 0.7,
            dz: deep * 0.5 + 0.24, ridge: true, at: 0);
      case BuildingKind.hall:
        box(PieceKind.plinth, wide * 1.5, deep * 1.35, 0.4);
        box(PieceKind.floor, wide * 1.35, deep * 1.2, storey * 1.2);
        box(PieceKind.floor, wide * 1.35, deep * 1.2, storey * 1.05);
        box(PieceKind.floor, wide * 1.35, deep * 1.2, storey * 0.95);
        roof(wide * 1.5, deep * 1.32, 0.9);
        box(PieceKind.chimney, 0.3, 0.3, 1.0, dx: -wide * 0.55, ridge: true);
        box(PieceKind.chimney, 0.3, 0.3, 1.0, dx: wide * 0.55, ridge: true);
        box(PieceKind.dormer, 0.55, 0.45, 0.48, dz: deep * 0.4, ridge: true);
        box(PieceKind.dormer, 0.55, 0.45, 0.48, dz: -deep * 0.4, ridge: true);
        box(PieceKind.porch, wide * 0.8, 0.6, 0.9,
            dz: deep * 0.68 + 0.2, ridge: true, at: 0);
      case BuildingKind.market:
        box(PieceKind.plinth, wide * 1.7, deep * 1.5, 0.3);
        for (var i = 0; i < 4; i++) {
          box(PieceKind.floor, 0.26, 0.26, storey * 1.25,
              dx: (i < 2 ? -1 : 1) * wide * 0.62,
              dz: (i.isEven ? -1 : 1) * deep * 0.52,
              ridge: true);
        }
        y += storey * 1.25;
        box(PieceKind.floor, wide * 1.6, deep * 1.4, 0.22, ridge: true);
        y += 0.22;
        roof(wide * 1.8, deep * 1.6, 0.85);
        box(PieceKind.dormer, 0.5, 0.44, 0.46, ridge: true);
        box(PieceKind.chimney, 0.24, 0.24, 0.7, dx: wide * 0.5, ridge: true);
      case BuildingKind.tower:
        final t = math.min(wide, deep) * 0.72;
        box(PieceKind.plinth, t + 0.34, t + 0.34, 0.42);
        for (var i = 0; i < 8; i++) {
          box(PieceKind.floor, t, t, storey * 0.82);
        }
        // The clock, on the shaft under the gallery, not floating over the
        // spire: it is the last piece laid but the first one anybody looks at.
        final clockY = y - storey * 0.62;
        box(PieceKind.parapet, t + 0.3, t + 0.3, 0.42);
        out.add(_Spec(
          kind: PieceKind.spire,
          cx: cx,
          cz: cz,
          w: t + 0.1,
          d: t + 0.1,
          y0: y,
          y1: y + 1.5,
          alongX: ridgeAlongX,
        ));
        y += 1.5;
        box(PieceKind.dormer, 0.42, 0.14, 0.42,
            dz: -t * 0.5 - 0.05, ridge: true, at: clockY);
        box(PieceKind.porch, t * 0.7, 0.44, 0.66,
            dz: t * 0.5 + 0.2, ridge: true, at: 0);
      case BuildingKind.church:
        final navW = wide * 1.5, navD = deep * 2.1;
        box(PieceKind.plinth, navW + 0.4, navD + 0.4, 0.36);
        box(PieceKind.floor, navW, navD, storey * 1.35);
        box(PieceKind.floor, navW, navD, storey * 1.1);
        out.add(_Spec(
          kind: PieceKind.roof,
          cx: cx,
          cz: cz,
          w: navW + 0.3,
          d: navD + 0.3,
          y0: y,
          y1: y + 1.1,
          alongX: false,
        ));
        // The aisles, lower and to either side.
        for (final side in [-1.0, 1.0]) {
          out.add(_Spec(
            kind: PieceKind.floor,
            cx: cx + side * (navW * 0.5 + wide * 0.36),
            cz: cz,
            w: wide * 0.72,
            d: navD * 0.82,
            y0: 0.36,
            y1: 0.36 + storey * 1.15,
            alongX: false,
          ));
          out.add(_Spec(
            kind: PieceKind.roof,
            cx: cx + side * (navW * 0.5 + wide * 0.36),
            cz: cz,
            w: wide * 0.8,
            d: navD * 0.86,
            y0: 0.36 + storey * 1.15,
            y1: 0.36 + storey * 1.15 + 0.42,
            alongX: false,
          ));
        }
        // The tower at the west end.
        final tw = wide * 0.78;
        var ty = 0.36;
        for (var i = 0; i < 6; i++) {
          out.add(_Spec(
            kind: PieceKind.floor,
            cx: cx,
            cz: cz - navD * 0.5 - tw * 0.42,
            w: tw,
            d: tw,
            y0: ty,
            y1: ty + storey * 0.85,
            alongX: true,
          ));
          ty += storey * 0.85;
        }
        out.add(_Spec(
          kind: PieceKind.parapet,
          cx: cx,
          cz: cz - navD * 0.5 - tw * 0.42,
          w: tw + 0.26,
          d: tw + 0.26,
          y0: ty,
          y1: ty + 0.4,
          alongX: true,
        ));
        ty += 0.4;
        out.add(_Spec(
          kind: PieceKind.spire,
          cx: cx,
          cz: cz - navD * 0.5 - tw * 0.42,
          w: tw + 0.08,
          d: tw + 0.08,
          y0: ty,
          y1: ty + 2.2,
          alongX: true,
        ));
        // The apse, and the porch.
        out.add(_Spec(
          kind: PieceKind.floor,
          cx: cx,
          cz: cz + navD * 0.5 + wide * 0.3,
          w: navW * 0.72,
          d: wide * 0.62,
          y0: 0.36,
          y1: 0.36 + storey * 1.2,
          alongX: false,
        ));
        out.add(_Spec(
          kind: PieceKind.roof,
          cx: cx,
          cz: cz + navD * 0.5 + wide * 0.3,
          w: navW * 0.78,
          d: wide * 0.68,
          y0: 0.36 + storey * 1.2,
          y1: 0.36 + storey * 1.2 + 0.5,
          alongX: false,
        ));
        out.add(_Spec(
          kind: PieceKind.porch,
          cx: cx,
          cz: cz - navD * 0.5 - tw * 0.9,
          w: tw * 0.8,
          d: 0.5,
          y0: 0.36,
          y1: 0.36 + 0.85,
          alongX: true,
        ));
        out.add(_Spec(
          kind: PieceKind.dormer,
          cx: cx,
          cz: cz - navD * 0.24,
          w: 0.5,
          d: 0.44,
          y0: 0.36 + storey * 2.45,
          y1: 0.36 + storey * 2.45 + 0.46,
          alongX: false,
        ));
    }

    // Every kind must cost exactly what the plan says it costs.
    final want = buildingCost[b.kind]!;
    while (out.length < want) {
      out.add(out.last);
    }
    return out.length > want ? out.sublist(0, want) : out;
  }
}

class _Spec {
  _Spec({
    required this.kind,
    required this.cx,
    required this.cz,
    required this.w,
    required this.d,
    required this.y0,
    required this.y1,
    required this.alongX,
  });
  final PieceKind kind;
  final double cx, cz, w, d, y0, y1;
  final bool alongX;
}
