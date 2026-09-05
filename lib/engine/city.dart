import 'dart:math' as math;

import '../core/rng.dart';
import '../data/landmarks.dart';
import 'mason.dart';

export 'mason.dart' show PieceKind;

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

/// The ordinary houses: the week-by-week fabric of the town. Everything
/// grander is a [Landmark], and lives in its own catalogue.
enum BuildingKind {
  shed,
  cottage,
  workshop,
  house,
  granary,
  townhouse,
  inn,
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
};

const Map<BuildingKind, String> buildingName = {
  BuildingKind.shed: 'Cobertizo',
  BuildingKind.cottage: 'Casa',
  BuildingKind.workshop: 'Taller',
  BuildingKind.house: 'Casona',
  BuildingKind.granary: 'Granero',
  BuildingKind.townhouse: 'Casa de vecinos',
  BuildingKind.inn: 'Posada',
};

class CityBuilding {
  CityBuilding({
    required this.index,
    required this.kind,
    required this.landmark,
    required this.firstPiece,
    required this.cx,
    required this.cz,
    required this.seed,
  });

  final int index;

  /// The house this is, when it is an ordinary house.
  final BuildingKind? kind;

  /// The landmark this is, when it is one. Exactly one of the two is set.
  final Landmark? landmark;

  /// The achievement that started it.
  final int firstPiece;
  final double cx, cz;
  final int seed;

  int get cost => landmark?.cost ?? buildingCost[kind]!;
  String get name => landmark?.name ?? buildingName[kind]!;
  bool get isLandmark => landmark != null;

  /// How much room it needs around its own middle, for keeping neighbours off.
  /// A house wants its plot; a landmark wants as much as its recipe reaches,
  /// and a little more so it is not wearing somebody's washing line.
  double get reach => landmark == null ? 1.3 : landmark!.reach + 0.5;

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
  /// to be worth waiting for and the twentieth does not arrive every fortnight.
  static bool isLandmarkSlot(int b) {
    var at = _firstLandmark, gap = _firstGap, step = 0;
    while (at < b) {
      at += gap + step;
      step++;
    }
    return at == b;
  }

  static const int _firstLandmark = 4;
  static const int _firstGap = 6;

  /// Which landmark this is, counting from the first one the town builds.
  static int landmarkNumber(int b) {
    var n = 0, at = _firstLandmark, gap = _firstGap, step = 0;
    while (at < b) {
      at += gap + step;
      step++;
      n++;
    }
    return n;
  }

  /// The tier a town of this many buildings is ready to attempt.
  ///
  /// Small works first, then the works of a town, then the ones it only tries
  /// once it is sure of itself — but never so strictly that the catalogue runs
  /// dry, which is why the band widens as the town grows.
  static int tierFor(int landmarkNo) {
    if (landmarkNo < 3) return 0;
    if (landmarkNo < 6) return 1;
    if (landmarkNo < 8) return 0;
    if (landmarkNo % 5 == 4) return 0;
    if (landmarkNo % 5 == 2 || landmarkNo < 12) return 1;
    return 2;
  }

  /// The nth landmark the town builds.
  ///
  /// Taken from a single sequence that runs through the whole catalogue before
  /// anything comes round again, so a lifetime of use meets a hundred different
  /// things rather than the same four. The sequence is front-loaded with the
  /// small works and back-loaded with the grand ones, which is the order a real
  /// town builds in: the well before the cathedral.
  static Landmark landmarkFor(int b) {
    final seq = _sequence;
    return seq[landmarkNumber(b) % seq.length];
  }

  static List<Landmark>? _seq;

  /// The pattern of tiers the sequence follows, repeated until the catalogue is
  /// spent. Roughly a third small, half middling and a fifth grand, which is
  /// about the shape of the catalogue itself, so all three run out together and
  /// the fallback below almost never fires.
  static const List<int> _cadence = [0, 1, 0, 1, 2, 1, 0, 1, 2, 1];

  /// The first landmarks a town builds, chosen rather than drawn.
  ///
  /// The catalogue is shuffled so that no two towns walk the same road, but the
  /// opening is not: the first two years should show what the town is capable
  /// of — a mill with its crops, a wheel turning in a river, a bridge, a
  /// castle — and not a pigsty and a charnel house, which is what an honest
  /// shuffle keeps handing out.
  static const List<String> _opening = [
    'pozo',
    'horno',
    'molinoViento',
    'cruz',
    'capilla',
    'molinoAgua',
    'palomar',
    'puente',
    'reloj',
    'fuente',
    'mercado',
    'castillo',
    'ermita',
    'faro',
    'iglesia',
    'lagar',
    'atalaya',
    'claustro',
    'acueducto',
    'concejo',
  ];

  static List<Landmark> get _sequence {
    final cached = _seq;
    if (cached != null) return cached;

    final out = <Landmark>[];
    final taken = <String>{};
    for (final id in _opening) {
      for (final l in landmarks) {
        if (l.id == id && taken.add(id)) out.add(l);
      }
    }

    // Everything else, in the widening cadence: mostly small works while the
    // town is small, mostly grand ones once it is not.
    final pools = [
      for (var t = 0; t < 3; t++)
        _pool(t).where((l) => !taken.contains(l.id)).toList(),
    ];
    final at = [0, 0, 0];
    var total = 0;
    for (final pool in pools) {
      total += pool.length;
    }
    for (var k = 0; k < total; k++) {
      var want = _cadence[k % _cadence.length];
      // A tier that has been spent hands over to the next one that has not, so
      // nothing comes round twice while something else is still unbuilt.
      for (var tries = 0; tries < 3 && at[want] >= pools[want].length; tries++) {
        want = (want + 1) % 3;
      }
      out.add(pools[want][at[want]]);
      at[want]++;
    }
    return _seq = out;
  }

  static final Map<int, List<Landmark>> _pools = {};

  /// One tier's catalogue, shuffled once and then kept.
  ///
  /// A fixed permutation, so appending a new landmark to the catalogue only
  /// ever changes what comes after everything already standing.
  static List<Landmark> _pool(int tier) => _pools.putIfAbsent(tier, () {
        final of = landmarks.where((l) => l.tier == tier).toList();
        final keyed = <(double, Landmark)>[
          for (var i = 0; i < of.length; i++) (hash01(0x5EED, tier, i), of[i]),
        ];
        keyed.sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.id.compareTo(b.$2.id);
        });
        return [for (final k in keyed) k.$2];
      });

  /// The ordinary house on an ordinary plot.
  static BuildingKind kindFor(int b) {
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
        BuildingKind.shed,
      ];
    } else {
      pool = const [
        BuildingKind.house,
        BuildingKind.townhouse,
        BuildingKind.cottage,
        BuildingKind.townhouse,
        BuildingKind.inn,
        BuildingKind.granary,
        BuildingKind.workshop,
        BuildingKind.house,
      ];
    }
    return pool[hash32(b, 0x71c3, 5) % pool.length];
  }

  /// What it costs to build the bth building, whatever it turns out to be.
  static int costOf(int b) =>
      isLandmarkSlot(b) ? landmarkFor(b).cost : buildingCost[kindFor(b)]!;
}

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
      total += CityPlan.costOf(count);
      count++;
    }
    count = math.max(count, 1);

    final isMark = [for (var b = 0; b < count; b++) CityPlan.isLandmarkSlot(b)];
    final plots = _plots(count, isMark);
    var index = 0;
    for (var b = 0; b < count; b++) {
      final mark = isMark[b] ? CityPlan.landmarkFor(b) : null;
      final seed = hash32(b, 0x9e37, 17);
      final building = CityBuilding(
        index: b,
        kind: mark == null ? CityPlan.kindFor(b) : null,
        landmark: mark,
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
      final out =
          math.sqrt(building.cx * building.cx + building.cz * building.cz);
      if (out + building.reach > radius) radius = out + building.reach;
      if (index >= want) break;
    }
  }

  /// The plots, nearest the centre first.
  ///
  /// A square grid of blocks with streets between them, taken in order of
  /// distance from the middle with a little jitter so the edge of the town is
  /// ragged rather than a circle drawn with a compass. Buildings claim them in
  /// order and a landmark keeps its neighbours at arm's length, so a castle is
  /// never wearing somebody's cottage. Because a plot is chosen looking only at
  /// what is already standing, nothing built earlier ever has to move.
  List<(double, double)> _plots(int want, List<bool> isMark) {
    final rings = math.max(3, (math.sqrt(want) / 2).ceil() + 3);
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

    final used = List<bool>.filled(all.length, false);
    final out = <(double, double)>[];
    final reaches = <double>[];
    var from = 0;
    for (var b = 0; b < want; b++) {
      final r = isMark[b] ? CityPlan.landmarkFor(b).reach + 0.5 : 1.3;
      var placedIt = false;
      for (var i = from; i < all.length; i++) {
        if (used[i]) continue;
        final x = all[i].$1, z = all[i].$2;
        var ok = true;
        for (var k = 0; k < out.length; k++) {
          final dx = x - out[k].$1, dz = z - out[k].$2;
          if (dx.abs() > 14 || dz.abs() > 14) continue;
          final need = (r + reaches[k]) * 0.72;
          if (dx * dx + dz * dz < need * need) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        used[i] = true;
        out.add((x, z));
        reaches.add(r);
        placedIt = true;
        while (from < all.length && used[from]) {
          from++;
        }
        break;
      }
      // The grid ran out, which only happens for a town far larger than any
      // that will ever be built. Better a crowded corner than no plot at all.
      if (!placedIt) {
        out.add(all[out.length % all.length].$1 == 0
            ? (0.0, 0.0)
            : (all[out.length % all.length].$1, all[out.length % all.length].$2));
        reaches.add(r);
      }
    }
    return out;
  }

  List<Spec> _piecesOf(CityBuilding b) {
    final s = b.seed;
    // Every building sits a little differently on its plot, so a grid of them
    // never lines up into a barracks. A landmark sits square: it is the thing
    // the street is arranged around, not one more house on it.
    final jitter = b.isLandmark ? 0.0 : 0.22;
    final m = Mason(
      b.cx + hashRange(-jitter, jitter, s, 3),
      b.cz + hashRange(-jitter, jitter, s, 4),
      s,
      hash01(s, 5) < 0.5,
    );

    final mark = b.landmark;
    if (mark != null) {
      mark.build(m);
      return m.finish(mark.cost);
    }

    final wide = hashRange(1.45, 1.85, s, 6);
    final deep = hashRange(1.35, 1.75, s, 7);
    final storey = hashRange(0.92, 1.14, s, 8);

    switch (b.kind!) {
      case BuildingKind.shed:
        m.floor(wide * 0.8, deep * 0.8, storey * 0.78);
        m.roof(wide * 0.86, deep * 0.86, 0.42);
      case BuildingKind.cottage:
        m.floor(wide, deep, storey);
        m.roof(wide + 0.16, deep + 0.16, 0.62);
        m.chimney(0.26, 0.75, dx: wide * 0.28, dz: deep * 0.18);
      case BuildingKind.workshop:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.85);
        m.roof(wide + 0.16, deep + 0.16, 0.58);
        m.door(wide * 0.5, 0.66, dz: deep * 0.5 + 0.22);
      case BuildingKind.house:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.92);
        m.roof(wide + 0.18, deep + 0.18, 0.7);
        m.chimney(0.28, 0.9, dx: -wide * 0.3, dz: deep * 0.2);
        m.dormer(0.5, 0.42, dz: deep * 0.28);
      case BuildingKind.granary:
        m.plinth(wide + 0.3, deep + 0.3, 0.34);
        m.floor(wide, deep, storey * 1.15);
        m.floor(wide, deep, storey);
        m.roof(wide + 0.22, deep + 0.22, 0.78);
        m.door(wide * 0.42, 0.5, dz: deep * 0.5 + 0.2);
        m.dormer(0.42, 0.4, dz: -deep * 0.28);
      case BuildingKind.townhouse:
        m.plinth(wide + 0.22, deep + 0.22, 0.28);
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.95);
        m.floor(wide, deep, storey * 0.9);
        m.roof(wide + 0.2, deep + 0.2, 0.72);
        m.dormer(0.46, 0.4, dz: deep * 0.26);
        m.door(wide * 0.44, 0.62, dz: deep * 0.5 + 0.2);
      case BuildingKind.inn:
        m.floor(wide * 1.15, deep, storey * 1.1);
        m.floor(wide * 1.15, deep, storey);
        m.roof(wide * 1.25, deep + 0.2, 0.72);
        // The side wing stands on the ground beside the inn, not on its roof.
        m.box(PieceKind.floor, wide * 0.6, deep * 0.7, storey * 0.9,
            dx: wide * 0.8, ridge: true, at: 0);
        m.roof(wide * 0.66, deep * 0.76, 0.44,
            dx: wide * 0.8, at: storey * 0.9, along: !m.alongX);
        m.chimney(0.3, 1.0, dx: -wide * 0.4);
        m.chimney(0.26, 0.8, dx: wide * 0.2);
        m.door(wide * 0.7, 0.7, dz: deep * 0.5 + 0.24);
    }

    return m.finish(b.cost);
  }
}
