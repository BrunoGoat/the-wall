import 'dart:math' as math;

import '../core/rng.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import 'mason.dart';

export 'mason.dart' show PieceKind;

/// One achievement, as a piece of a building.
///
/// The whole point of the city over the wall: a brick in a wall only ever means
/// "the wall is one brick longer", but a piece of a house means "the house is
/// nearly finished", and three days later the house *is* finished. There is a
/// completion to look forward to that is closer than the next landmark.
class TownPiece {
  TownPiece({
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
enum BuildingKind { shed, cottage, workshop, house, granary, townhouse, inn }

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

/// What a building roofs with. Chosen once, when the town is laid out, from
/// the character's own mix — and then it is both the shape the mason lays and
/// the colour the renderer paints, instead of two hashes in two files that
/// have to agree with each other and one day will not.
enum RoofStuff { tile, slate, thatch }

class TownBuilding {
  TownBuilding({
    required this.index,
    required this.kind,
    required this.landmark,
    required this.firstPiece,
    required this.cx,
    required this.cz,
    required this.seed,
    this.spread = 1.0,
    this.roof = RoofStuff.tile,
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

  /// How wide this town builds on the ground, so the room a building keeps
  /// clear stretches with it.
  final double spread;

  /// Tile, slate or straw.
  final RoofStuff roof;

  /// The plot's own yard: where it is, how big, and what is on it.
  ///
  /// None of it is a piece and none of it is earned. A kitchen garden is not
  /// an achievement — it is what a plot looks like in a place where people
  /// grow things — and charging somebody an achievement for the scenery would
  /// be charging them for the weather. It is filed like the notice board:
  /// furniture the town owns, which a house in front of it still hides.
  double yardX = 0, yardZ = 0, yardSize = 0;
  double treeX = 0, treeZ = 0, treeSize = 0;

  int get cost => landmark?.cost ?? buildingCost[kind]!;
  String get name => landmark?.name ?? buildingName[kind]!;
  bool get isLandmark => landmark != null;

  /// How much room it keeps clear around its own middle. A house wants its
  /// plot; a landmark wants the room its tier is given.
  double get reach => (landmark?.room ?? 1.3) * spread;

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
class TownPlan {
  TownPlan._(this.character);

  /// One plan per kind of place, built once and kept.
  static final Map<int, TownPlan> _plans = {};
  factory TownPlan.of(TownCharacter c) =>
      _plans.putIfAbsent(c.order, () => TownPlan._(c));

  final TownCharacter character;

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
  Landmark landmarkFor(int b) {
    final seq = _sequence;
    return seq[landmarkNumber(b) % seq.length];
  }

  List<Landmark>? _seq;

  /// The pattern of tiers the sequence follows, repeated until the catalogue is
  /// spent. Roughly a third small, half middling and a fifth grand, which is
  /// about the shape of the catalogue itself, so all three run out together and
  /// the fallback below almost never fires.
  static const List<int> _cadence = [0, 1, 0, 1, 2, 1, 0, 1, 2, 1];

  /// The landmarks worth opening a town with.
  ///
  /// A town's first two years should show what the place is capable of — a mill
  /// with its crops, a wheel turning in a river, a bridge, a castle — and not a
  /// pigsty and a charnel house, which is what an honest shuffle keeps handing
  /// out. So the openers are chosen; but *which* of them a given town gets, and
  /// in what order, is its own, so two habits never walk the same road.
  static const List<String> _openers = [
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

  List<Landmark> get _sequence {
    final cached = _seq;
    if (cached != null) return cached;

    final out = <Landmark>[];
    final taken = <String>{};
    // This town's own order through the openers.
    final opening =
        <(double, String)>[
          for (var i = 0; i < _openers.length; i++)
            (hash01(character.order, 0x09E4, i), _openers[i]),
        ]..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });
    for (final (_, id) in opening) {
      for (final l in landmarks) {
        if (l.id == id && taken.add(id)) out.add(l);
      }
    }

    // El observatorio no se sortea, y va en el mismo sitio en los seis.
    //
    // Es la puerta de una cosa entera —el cielo, y las ocho constelaciones que
    // hay que salir a reconocer— y dejarlo al azar del catálogo significaba
    // que a un pueblo le tocase el séptimo y a otro no le tocase en veinte mil
    // piezas. Una función que se abre por suerte no es una función. Va después
    // de las primeras obras: cuando el pueblo ya es un pueblo, alguien levanta
    // la vista.
    const looksUp = 3;
    for (final l in landmarks) {
      if (l.id == 'observatorio' && taken.add(l.id)) {
        out.insert(math.min(looksUp, out.length), l);
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
      for (
        var tries = 0;
        tries < 3 && at[want] >= pools[want].length;
        tries++
      ) {
        want = (want + 1) % 3;
      }
      out.add(pools[want][at[want]]);
      at[want]++;
    }
    return _seq = out;
  }

  final Map<int, List<Landmark>> _pools = {};

  /// One tier's catalogue, shuffled once and then kept.
  ///
  /// A fixed permutation, so appending a new landmark to the catalogue only
  /// ever changes what comes after everything already standing.
  List<Landmark> _pool(int tier) => _pools.putIfAbsent(tier, () {
    final of = landmarks.where((l) => l.tier == tier).toList();
    final keyed = <(double, Landmark)>[
      for (var i = 0; i < of.length; i++)
        (hash01(character.order, tier, i), of[i]),
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

  /// What the town is putting up right now, how much of it is left, and
  /// whether it is one of the hundred and twelve landmarks.
  ///
  /// A pure walk over the plan, so the label at the top of the screen never
  /// needs a laid-out town to say what is being built.
  (String, int, bool)? underway(int placed) {
    var cursor = 0;
    for (var b = 0; b < 20000; b++) {
      final mark = isLandmarkSlot(b) ? landmarkFor(b) : null;
      final cost = mark?.cost ?? buildingCost[kindFor(b)]!;
      if (placed < cursor + cost) {
        final name = mark?.name ?? buildingName[kindFor(b)]!;
        return (name, cursor + cost - placed, mark != null);
      }
      cursor += cost;
    }
    return null;
  }

  /// Every landmark the town has built or is about to, with the achievement
  /// it starts at and what it costs. Enough to show the road ahead without
  /// laying out a town to do it.
  List<(Landmark, int)> landmarksAround(int placed, {int ahead = 500}) {
    final out = <(Landmark, int)>[];
    var cursor = 0;
    for (var b = 0; b < 20000; b++) {
      final mark = isLandmarkSlot(b) ? landmarkFor(b) : null;
      final cost = mark?.cost ?? buildingCost[kindFor(b)]!;
      if (mark != null) out.add((mark, cursor));
      cursor += cost;
      if (cursor > placed + ahead) break;
    }
    return out;
  }

  /// Si el pueblo ya terminó este hito.
  ///
  /// Un paseo por el plan, sin construir nada: qué hitos tiene un pueblo es
  /// una pregunta que se contesta con el plan y el número de piezas, y armar
  /// seis pueblos enteros en memoria para saber si alguno tiene una cúpula
  /// sería pagar un mundo por un sí o un no.
  bool built(String landmarkId, int placed) {
    var cursor = 0;
    for (var b = 0; b < 20000; b++) {
      final mark = isLandmarkSlot(b) ? landmarkFor(b) : null;
      final cost = mark?.cost ?? buildingCost[kindFor(b)]!;
      // En cuanto uno no está terminado, no lo está ninguno de los de después.
      if (cursor + cost > placed) return false;
      if (mark?.id == landmarkId) return true;
      cursor += cost;
    }
    return false;
  }

  /// How many buildings the town has finished.
  int finishedBuildings(int placed) {
    var cursor = 0, n = 0;
    for (var b = 0; b < 20000; b++) {
      cursor += costOf(b);
      if (cursor > placed) break;
      n++;
    }
    return n;
  }

  /// What it costs to build the bth building, whatever it turns out to be.
  int costOf(int b) =>
      isLandmarkSlot(b) ? landmarkFor(b).cost : buildingCost[kindFor(b)]!;
}

class TownLayout {
  TownLayout(this.placed, this.character, {this.cx = 0, this.cz = 0})
    : plan = TownPlan.of(character),
      plotPitch = character.plotPitch,
      solo = false {
    _build();
  }

  /// One structure on its own, in an empty world.
  ///
  /// Nothing about the catalogue is visible from inside a town: a landmark
  /// turns up once every few hundred achievements, and half of them nobody
  /// will reach for a year. This builds exactly one of them, at the origin, so
  /// every recipe can be looked at, walked around, and watched going up piece
  /// by piece — which is the only way to catch a chimney standing on thin air
  /// before somebody earns it.
  TownLayout.showcase(
    this.character, {
    Landmark? landmark,
    BuildingKind? kind,
    required this.placed,
    int seed = 0,
  }) : plan = TownPlan.of(character),
       plotPitch = character.plotPitch,
       cx = 0,
       cz = 0,
       solo = true {
    final building = TownBuilding(
      index: 0,
      kind: landmark == null ? (kind ?? BuildingKind.house) : null,
      landmark: landmark,
      firstPiece: 0,
      cx: 0,
      cz: 0,
      seed: hash32(seed, 0x5A11, 7),
      spread: character.spread,
      roof: _roofOf(hash32(seed, 0x5A11, 7)),
    );
    for (final p in _piecesOf(building)) {
      if (pieces.length > placed) break;
      pieces.add(
        TownPiece(
          index: pieces.length,
          building: 0,
          kind: p.kind,
          cx: p.cx,
          cz: p.cz,
          w: p.w,
          d: p.d,
          y0: p.y0,
          y1: p.y1,
          seed: hash32(building.seed, pieces.length, 31),
          alongX: p.alongX,
        ),
      );
      if (p.y1 > building.peakY) building.peakY = p.y1;
    }
    final built = math.min(pieces.length, placed);
    building.placedPieces = built;
    buildings.add(building);
    radius = building.reach + 1.5;
  }

  /// True for one structure standing on its own in an empty world. A town has
  /// a plaza with a notice board in it; a thing on a plinth in an exhibition
  /// hall does not.
  final bool solo;

  /// Where in the valley this town stands. Every habit has its own plot, so
  /// several towns can be looked at side by side without any of them moving.
  final double cx, cz;

  /// What kind of place this is: how tall its houses stand, how tight its
  /// streets run, and the order it meets the hundred and twelve.
  final TownCharacter character;
  final TownPlan plan;

  /// One extra piece is always laid out so the app can show a ghost of where
  /// the next one goes.
  final int placed;

  final List<TownPiece> pieces = [];
  final List<TownBuilding> buildings = [];

  /// El edificio de este hito, si está en pie. Para las cosas que un pueblo
  /// desbloquea al terminar algo, y para poder señalarlas en pantalla.
  TownBuilding? standing(String landmarkId) {
    for (final b in buildings) {
      if (b.landmark?.id == landmarkId && b.finished) return b;
    }
    return null;
  }

  /// How far the town reaches from its centre, for framing the camera.
  double radius = 4;

  /// How high this town reaches, counting only what is actually standing.
  ///
  /// A sign hung over a town has to clear it, and «a bit above the middle» is
  /// not the same height for a hamlet as for a place with a cathedral in it.
  double get tallest {
    var top = 0.0;
    for (final b in buildings) {
      if (b.placedPieces > 0 && b.peakY > top) top = b.peakY;
    }
    return top;
  }

  TownPiece? pieceFor(int index) =>
      index >= 0 && index < pieces.length ? pieces[index] : null;

  TownBuilding? buildingOf(int index) {
    final p = pieceFor(index);
    return p == null ? null : buildings[p.building];
  }

  /// How close together the plots are laid here.
  final double plotPitch;

  double get blockPitch => plotPitch * 3.6;

  void _build() {
    final want = placed + 1;

    // How many buildings the town needs to hold that many pieces.
    var count = 0, total = 0;
    while (total < want) {
      total += plan.costOf(count);
      count++;
    }
    count = math.max(count, 1);

    final isMark = [for (var b = 0; b < count; b++) TownPlan.isLandmarkSlot(b)];
    final plots = _plots(count, isMark);
    var index = 0;
    for (var b = 0; b < count; b++) {
      final mark = isMark[b] ? plan.landmarkFor(b) : null;
      final seed = hash32(b, 0x9e37, 17);
      final building = TownBuilding(
        index: b,
        kind: mark == null ? TownPlan.kindFor(b) : null,
        landmark: mark,
        firstPiece: index,
        cx: cx + plots[b].$1,
        cz: cz + plots[b].$2,
        seed: seed,
        spread: character.spread,
        roof: _roofOf(seed),
      );
      final made = _piecesOf(building);
      for (final p in made) {
        if (index >= want) break;
        pieces.add(
          TownPiece(
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
          ),
        );
        if (p.y1 > building.peakY) building.peakY = p.y1;
        index++;
      }
      // The last piece of the town is the ghost of the next one: it is drawn
      // as an outline standing where the piece will go, and it is not built
      // yet. Counting it would give a plot its yard, and a wall the roof that
      // covers it, a whole achievement early.
      _layYard(building, made);
      final built = math.min(index, placed);
      building.placedPieces = math.max(0, built - building.firstPiece);
      buildings.add(building);
      final out = math.sqrt(
        (building.cx - cx) * (building.cx - cx) +
            (building.cz - cz) * (building.cz - cz),
      );
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
            final key =
                math.sqrt(x * x + z * z) +
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
      // Stretched wider on the ground, a building needs more ground. The
      // plot has to know what the mason is going to do to it.
      final r = (isMark[b] ? plan.landmarkFor(b).room : 1.3) * character.spread;
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
        out.add(
          all[out.length % all.length].$1 == 0
              ? (0.0, 0.0)
              : (
                  all[out.length % all.length].$1,
                  all[out.length % all.length].$2,
                ),
        );
        reaches.add(r);
      }
    }
    return out;
  }

  /// Which of the three this building roofs with, from the character's mix.
  /// Deterministic in the building's own seed, so it never changes under a
  /// town that is already standing.
  RoofStuff _roofOf(int seed) {
    final t = hash01(seed, 3);
    final (tile, slate, _) = character.roofMix;
    if (t < tile) return RoofStuff.tile;
    return t < tile + slate ? RoofStuff.slate : RoofStuff.thatch;
  }

  /// Turns this building's roofs to straw where straw is what it roofs with.
  ///
  /// Done here rather than in every recipe: a mason lays a roof, and what
  /// region he is standing in decides what it is made of. Which is also how
  /// it worked.
  List<Spec> _straw(TownBuilding b, List<Spec> specs) {
    if (b.roof != RoofStuff.thatch) return specs;
    return [
      for (final p in specs)
        if (p.kind != PieceKind.roof)
          p
        else
          Spec(
            kind: PieceKind.thatch,
            cx: p.cx,
            cz: p.cz,
            w: p.w,
            d: p.d,
            y0: p.y0,
            y1: p.y1,
            alongX: p.alongX,
          ),
    ];
  }

  /// Gives a house its yard, if this is a place that has them.
  ///
  /// It goes beside the house, clear of it, and clear of the neighbour: the
  /// far edge is kept inside half a plot so no garden ever ends up in
  /// somebody else's kitchen. Where the house is too big for its plot to have
  /// any room left, it simply has no yard, which is also what happens in a
  /// town where the houses got bigger.
  void _layYard(TownBuilding b, List<Spec> made) {
    if (solo || b.isLandmark || made.isEmpty) return;
    final wantGarden = hash01(b.seed, 42) < character.gardens;
    final wantTree = hash01(b.seed, 43) < character.trees;
    if (!wantGarden && !wantTree) return;

    var half = 0.0;
    for (final p in made) {
      final x = (p.cx - b.cx).abs() + p.w / 2;
      final z = (p.cz - b.cz).abs() + p.d / 2;
      if (x > half) half = x;
      if (z > half) half = z;
    }
    final dir = (hash01(b.seed, 41) * 4).floor() % 4;
    const step = [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)];

    // A garden wants clear ground: whatever is left over between this house
    // and the next one, minus a path to walk down. It is the size of the room
    // there is for one, and where the houses grew until there is none the plot
    // simply has no garden — which is what happens to a street that fills in.
    if (wantGarden) {
      final room = plotPitch - 2 * half - 0.24;
      final size = math.min(plotPitch * 0.34, room);
      if (size >= 0.38) {
        final off = half + size / 2 + 0.10;
        b.yardX = b.cx + step[dir].$1 * off;
        b.yardZ = b.cz + step[dir].$2 * off;
        b.yardSize = size;
      }
    }

    // A tree wants far less than a garden: somewhere to stand its trunk. It
    // goes on the corner of the plot, which is both where the room is and
    // where anybody would put one, and its crown is allowed out over the roof
    // — that is what a tree beside a house does, and since geometry that runs
    // through other geometry is cut where the two cross, it is drawn right
    // when it does.
    if (wantTree) {
      const corner = [(0.7, 0.7), (-0.7, 0.7), (-0.7, -0.7), (0.7, -0.7)];
      final c = corner[(dir + (wantGarden ? 2 : 1)) % 4];
      final off = half * 0.98 + 0.34;
      b.treeX = b.cx + c.$1 * off;
      b.treeZ = b.cz + c.$2 * off;
      b.treeSize = math.min(plotPitch * 0.34, 1.05);
    }
  }

  List<Spec> _piecesOf(TownBuilding b) {
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
      spread: character.spread,
      storey: character.storey,
      pitch: character.pitch,
    );

    final mark = b.landmark;
    if (mark != null) {
      mark.build(m);
      return _straw(b, m.finish(mark.cost));
    }

    // An ordinary house, in the units every recipe is written in. What makes
    // it a Sierra house or a Ribera house is the mason, not this.
    //
    // The spread here is deliberately narrow — a house differs from its
    // neighbour by a twentieth, not by a fifth. It used to be ±11%, which is
    // the same size as the difference between two whole regions, so standing
    // in a street you could not tell which region you were in: the noise was
    // as loud as the signal. A town is houses that agree with each other.
    final wide = hashRange(1.52, 1.74, s, 6);
    final deep = hashRange(1.44, 1.64, s, 7);
    final storey = hashRange(0.96, 1.06, s, 8);
    const pitch = 1.0;

    switch (b.kind!) {
      case BuildingKind.shed:
        m.floor(wide * 0.8, deep * 0.8, storey * 0.78);
        m.roof(wide * 0.86, deep * 0.86, 0.42 * pitch);
      case BuildingKind.cottage:
        m.floor(wide, deep, storey);
        m.roof(wide + 0.16, deep + 0.16, 0.62 * pitch);
        m.chimney(0.26, 0.75, dx: wide * 0.28, dz: deep * 0.18);
      case BuildingKind.workshop:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.85);
        m.roof(wide + 0.16, deep + 0.16, 0.58 * pitch);
        m.door(wide * 0.5, 0.66, dz: deep * 0.5 + 0.22);
      case BuildingKind.house:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.92);
        m.roof(wide + 0.18, deep + 0.18, 0.7 * pitch);
        m.chimney(0.28, 0.9, dx: -wide * 0.3, dz: deep * 0.2);
        m.dormer(0.5, 0.42, dz: deep * 0.28);
      case BuildingKind.granary:
        m.plinth(wide + 0.3, deep + 0.3, 0.34);
        m.floor(wide, deep, storey * 1.15);
        m.floor(wide, deep, storey);
        m.roof(wide + 0.22, deep + 0.22, 0.78 * pitch);
        m.door(wide * 0.42, 0.5, dz: deep * 0.5 + 0.2);
        m.dormer(0.42, 0.4, dz: -deep * 0.28);
      case BuildingKind.townhouse:
        m.plinth(wide + 0.22, deep + 0.22, 0.28);
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.95);
        m.floor(wide, deep, storey * 0.9);
        m.roof(wide + 0.2, deep + 0.2, 0.72 * pitch);
        m.dormer(0.46, 0.4, dz: deep * 0.26);
        m.door(wide * 0.44, 0.62, dz: deep * 0.5 + 0.2);
      case BuildingKind.inn:
        m.floor(wide * 1.15, deep, storey * 1.1);
        m.floor(wide * 1.15, deep, storey);
        m.roof(wide * 1.25, deep + 0.2, 0.72 * pitch);
        // The side wing stands on the ground beside the inn, not on its roof.
        m.box(
          PieceKind.floor,
          wide * 0.6,
          deep * 0.7,
          storey * 0.9,
          dx: wide * 0.8,
          ridge: true,
          at: 0,
        );
        m.roof(
          wide * 0.66,
          deep * 0.76,
          0.44,
          dx: wide * 0.8,
          at: storey * 0.9,
          along: !m.alongX,
        );
        m.chimney(0.3, 1.0, dx: -wide * 0.4);
        m.chimney(0.26, 0.8, dx: wide * 0.2);
        m.door(wide * 0.7, 0.7, dz: deep * 0.5 + 0.24);
    }

    return _straw(b, m.finish(b.cost));
  }
}
