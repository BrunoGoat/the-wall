import '../core/rng.dart';

/// What a piece of a building is doing, which is all the renderer needs to know
/// to draw it.
///
/// This is the whole vocabulary the town is built out of. A landmark is not a
/// hand-modelled object: it is a short recipe written in these words, so a
/// hundred different landmarks cost a hundred short recipes instead of a
/// hundred models.
enum PieceKind {
  plinth,
  floor,
  roof,

  /// The same roof, in straw. Not a colour: a thatched roof is fat at the
  /// eaves and rounded at the ridge, and no amount of paint makes a tiled one
  /// look like it. Which of the two a building gets is decided when the town
  /// is laid out, from the character's mix, and never rolled again.
  thatch,
  chimney,
  dormer,
  porch,
  parapet,
  spire,

  /// Ploughed rows: the crops around a mill, a vineyard, a monastery garden.
  field,

  /// Standing water: a millrace, a moat, a washing place, salt pans.
  water,

  /// A vertical wheel with paddles, turned by the water beside it.
  wheel,

  /// The four sails of a windmill.
  sail,

  /// A rounded cap: a bread oven, a kiln, a baptistery, a mausoleum.
  dome,

  /// One tree: an orchard, a churchyard yew, a palace garden.
  tree,

  /// A run of stakes: a stockade, a pen, a vine trellis.
  palisade,

  /// A pole with a banner on it.
  banner,

  /// A run of arches: a cloister, a bridge, an aqueduct, a market hall.
  arcade,

  /// A flight of steps.
  stair,
}

/// One piece of a building, before it is given to an achievement.
/// Cómo se llama cada pieza en castellano, para poder decirlo en pantalla.
///
/// Vive aquí, al lado del enumerado, y no en la interfaz: el vocabulario de la
/// obra es de la obra. Están las diecinueve; si mañana hay una más, el
/// analizador señala este mapa.
const Map<PieceKind, String> pieceName = {
  PieceKind.plinth: 'Zócalo',
  PieceKind.floor: 'Planta',
  PieceKind.roof: 'Tejado',
  PieceKind.thatch: 'Techo de paja',
  PieceKind.chimney: 'Chimenea',
  PieceKind.dormer: 'Buhardilla',
  PieceKind.porch: 'Porche',
  PieceKind.parapet: 'Pretil',
  PieceKind.spire: 'Aguja',
  PieceKind.field: 'Huerta',
  PieceKind.water: 'Agua',
  PieceKind.wheel: 'Rueda',
  PieceKind.sail: 'Aspas',
  PieceKind.dome: 'Cúpula',
  PieceKind.tree: 'Árbol',
  PieceKind.palisade: 'Empalizada',
  PieceKind.banner: 'Estandarte',
  PieceKind.arcade: 'Arcada',
  PieceKind.stair: 'Escalinata',
};

class Spec {
  Spec({
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

/// The hand that lays the pieces.
///
/// Every call adds exactly one piece, which is exactly one achievement, so the
/// cost of a landmark is simply how many times the mason is asked to do
/// something. Height accumulates as it goes, the way a real course of masonry
/// does; anything that belongs at a height of its own says so with `at`, and
/// anything that sits beside rather than on top says so with `ridge`.
class Mason {
  Mason(
    this.cx,
    this.cz,
    this.seed,
    this.alongX, {
    this.spread = 1.0,
    this.storey = 1.0,
    this.pitch = 1.0,
  });

  final double cx, cz;
  final int seed;

  /// Which way the roofs of this building run.
  final bool alongX;

  /// The place this is being built in, as three numbers.
  ///
  /// Every recipe is written in one town's proportions and then stretched into
  /// this one's: wider or narrower on the ground by [spread], taller or lower
  /// by [storey], steeper or flatter in the roof by [pitch]. It happens here,
  /// at the one door every piece goes through, rather than in each recipe —
  /// which is why it also reaches the hundred and twelve. A castle in the
  /// Sierra used to be the same castle as a castle on the Costa, down to the
  /// centimetre, and a town whose landmarks are somebody else's landmarks is
  /// not a place.
  ///
  /// The stretch is affine and uniform, so nothing it touches can come apart:
  /// a chimney that met its roof still meets it, and a stair that reached a
  /// door still reaches it.
  final double spread, storey, pitch;

  final List<Spec> out = [];

  /// Every roof laid so far, so a dormer knows where its tiles are.
  final List<_Roof> _roofs = [];

  /// The top of what has been laid so far.
  double y = 0;

  int get count => out.length;

  double h01(int salt) => hash01(seed, salt);
  double rand(double a, double b, int salt) => hashRange(a, b, seed, salt);

  /// The one door every piece goes through, and so the one place the town's
  /// proportions are applied. The mason works in a single set of units and
  /// this turns them into this town's.
  void _add(
    PieceKind kind,
    double dx,
    double dz,
    double w,
    double d,
    double y0,
    double y1, {
    bool? along,
  }) {
    out.add(
      Spec(
        kind: kind,
        cx: cx + dx * spread,
        cz: cz + dz * spread,
        w: w * spread,
        d: d * spread,
        y0: y0 * storey,
        y1: y1 * storey,
        alongX: along ?? alongX,
      ),
    );
  }

  /// A rectangular mass. Raises the course line unless it is [ridge] work or
  /// pinned to a height of its own with [at].
  void box(
    PieceKind k,
    double w,
    double d,
    double ht, {
    double dx = 0,
    double dz = 0,
    bool ridge = false,
    double? at,
    bool? along,
  }) {
    // A roof is the one thing whose height is not the town's height: how steep
    // this place builds is a fourth number, on top of the other three.
    if (k == PieceKind.roof || k == PieceKind.thatch) ht *= pitch;
    final base = at ?? y;
    _add(k, dx, dz, w, d, base, base + ht, along: along);
    if (k == PieceKind.roof || k == PieceKind.thatch) {
      _roofs.add(_Roof(dx, dz, w, d, base, ht, along ?? alongX));
    }
    if (!ridge && at == null) y += ht;
  }

  /// A storey with windows in it.
  void floor(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.floor, w, d, ht, dx: dx, dz: dz);

  /// A stone base, wider than what stands on it.
  void plinth(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.plinth, w, d, ht, dx: dx, dz: dz);

  /// A pitched roof. Sits on the course line without raising it, so a chimney
  /// laid afterwards comes up through it.
  void roof(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
  }) => box(
    PieceKind.roof,
    w,
    d,
    rise,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at,
    along: along,
  );

  /// A roof that also raises the course line, for a mass built on top of one.
  void roofUnder(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
  }) {
    box(PieceKind.roof, w, d, rise, dx: dx, dz: dz, along: along);
  }

  void spire(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(PieceKind.spire, w, d, rise, dx: dx, dz: dz, at: at);

  void dome(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(PieceKind.dome, w, d, rise, dx: dx, dz: dz, at: at);

  void parapet(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.parapet, w, d, ht, dx: dx, dz: dz);

  void chimney(double side, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.chimney, side, side, ht, dx: dx, dz: dz, ridge: true);

  /// A door, which belongs on the ground whatever has been built above it.
  void door(double w, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.porch, w, 0.44, ht, dx: dx, dz: dz, at: 0);

  /// A dormer: a little window standing out of the slope of a roof.
  ///
  /// [dz] is down the slope and [dx] along the ridge, whichever way round this
  /// building's roof happens to run — the mason knows which way that is, and a
  /// recipe should not have to. Written straight into world axes a dormer half
  /// the time lands on the ridge itself, standing clear of the roof like a box
  /// somebody left on top of it.
  ///
  /// It is set on the tiles under its *lower* edge, because that is where a
  /// dormer's front stands; the slope rises across the rest of its footprint
  /// and buries it. Set on the tiles under its middle instead, the downhill
  /// half of it climbs out of the roof and what you see is a crate half sunk
  /// in the tiles rather than a window in them.
  void dormer(double w, double ht, {double dx = 0, double dz = 0, double? at}) {
    final deep = w * 0.55;
    final ox = alongX ? dx : dz;
    final oz = alongX ? dz : dx;
    final away = dz < 0 ? -1.0 : 1.0;
    final low = alongX
        ? _tilesAt(ox, oz + away * deep / 2)
        : _tilesAt(ox + away * deep / 2, oz);
    box(
      PieceKind.dormer,
      alongX ? w : deep,
      alongX ? deep : w,
      ht,
      dx: ox,
      dz: oz,
      ridge: true,
      at: at ?? low - ht * 0.22,
    );
  }

  /// How high the tiles are over a spot, or the course line where no roof
  /// covers it.
  double _tilesAt(double dx, double dz) {
    var top = y;
    for (final r in _roofs) {
      final s = r.surfaceAt(dx, dz);
      if (s != null && s > top) top = s;
    }
    return top;
  }

  // ------------------------------------------------------------- the ground

  /// Ploughed rows. Always on the ground, always beside the building.
  void field(double w, double d, {double dx = 0, double dz = 0, bool? along}) =>
      _add(PieceKind.field, dx, dz, w, d, 0, 0.10, along: along);

  /// Standing water, sunk a little into the ground.
  void water(double w, double d, {double dx = 0, double dz = 0}) =>
      _add(PieceKind.water, dx, dz, w, d, -0.06, 0.02);

  /// One tree, or a close clump read as one.
  void tree(double spread, double ht, {double dx = 0, double dz = 0}) =>
      _add(PieceKind.tree, dx, dz, spread, spread, 0, ht);

  /// A run of stakes along its longer side.
  void palisade(
    double len,
    double ht, {
    double dx = 0,
    double dz = 0,
    bool along = true,
  }) => _add(
    PieceKind.palisade,
    dx,
    dz,
    along ? len : 0.22,
    along ? 0.22 : len,
    0,
    ht,
    along: along,
  );

  /// A pole with a banner on it.
  void banner(double ht, {double dx = 0, double dz = 0, double? at}) =>
      _add(PieceKind.banner, dx, dz, 0.5, 0.5, at ?? 0, (at ?? 0) + ht);

  /// A run of arches carrying whatever is above them.
  void arcade(
    double len,
    double ht,
    double depth, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
    bool rise = false,
  }) {
    final base = at ?? y;
    final a = along ?? alongX;
    _add(
      PieceKind.arcade,
      dx,
      dz,
      a ? len : depth,
      a ? depth : len,
      base,
      base + ht,
      along: a,
    );
    if (rise && at == null) y += ht;
  }

  /// A flight of steps climbing towards the centre of the building.
  void stair(
    double w,
    double rise,
    double run, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
  }) => _add(
    PieceKind.stair,
    dx,
    dz,
    w,
    run,
    at ?? 0,
    (at ?? 0) + rise,
    along: along,
  );

  /// A water wheel, turning in the plane across its short side.
  void wheel(double diameter, {double dx = 0, double dz = 0, bool? along}) =>
      _add(
        PieceKind.wheel,
        dx,
        dz,
        diameter,
        diameter,
        0.0,
        diameter,
        along: along,
      );

  /// The sails of a windmill, on the face of whatever they are pinned to.
  void sails(
    double diameter, {
    double dx = 0,
    double dz = 0,
    required double at,
  }) => _add(
    PieceKind.sail,
    dx,
    dz,
    diameter,
    diameter,
    at - diameter / 2,
    at + diameter / 2,
  );

  /// A single upright: the leg of a well roof, a gallows, the end of a
  /// trellis.
  void post(
    double side,
    double ht, {
    double dx = 0,
    double dz = 0,
    double at = 0,
  }) => box(
    PieceKind.parapet,
    side,
    side,
    ht,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at,
  );

  /// A horizontal member resting on posts. Without [at] it rests on the course
  /// line, which is where the thing it was laid after left off.
  void beam(
    double w,
    double d,
    double ht, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(
    PieceKind.parapet,
    w,
    d,
    ht,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at ?? y,
  );

  // --------------------------------------------------------------- shortcuts

  /// A shaft of [storeys] storeys. One piece each, so the cost is honest.
  void shaft(double side, int storeys, double storeyH, {double taper = 0}) {
    for (var i = 0; i < storeys; i++) {
      floor(side - taper * i, side - taper * i, storeyH);
    }
  }

  /// A small building standing on the ground beside the main one: the miller's
  /// cottage, the lodge at the gate, the bakehouse behind the inn.
  ///
  /// It never touches the course line, in either direction. Written as an
  /// ordinary [floor] and [roof] with an offset it would inherit whatever
  /// height the main mass had reached, which is how a cottage ends up perched
  /// on top of a bell tower.
  void outbuilding(
    double w,
    double d,
    double ht,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
  }) {
    box(PieceKind.floor, w, d, ht, dx: dx, dz: dz, ridge: true, at: 0);
    box(
      PieceKind.roof,
      w + 0.25,
      d + 0.25,
      rise,
      dx: dx,
      dz: dz,
      ridge: true,
      at: ht,
      along: along,
    );
  }

  /// A long low body: the nave of a church, the hall of a market.
  void hall(
    double w,
    double d,
    double ht,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
  }) {
    floor(w, d, ht, dx: dx, dz: dz);
    roof(w + 0.2, d + 0.2, rise, dx: dx, dz: dz, along: along);
  }

  /// Pads out or trims down to exactly [want] pieces.
  ///
  /// Padding repeats the last piece, which lands in the same place and so reads
  /// as the mason taking one more day over the same detail. Trimming is what
  /// happens while the landmark is still going up.
  List<Spec> finish(int want) {
    while (out.length < want) {
      out.add(out.last);
    }
    return out.length > want ? out.sublist(0, want) : out;
  }
}

/// A roof that has been laid, and how high its tiles are over any spot.
class _Roof {
  const _Roof(
    this.dx,
    this.dz,
    this.w,
    this.d,
    this.base,
    this.rise,
    this.alongX,
  );
  final double dx, dz, w, d, base, rise;
  final bool alongX;

  /// The height of the tiles above a point, or null where this roof does not
  /// reach.
  double? surfaceAt(double x, double z) {
    final hw = w / 2, hd = d / 2;
    if (hw <= 0 || hd <= 0) return null;
    if ((x - dx).abs() > hw || (z - dz).abs() > hd) return null;
    // Highest at the ridge, down to nothing at the eaves.
    final across = alongX ? (z - dz).abs() / hd : (x - dx).abs() / hw;
    return base + rise * (1 - across);
  }
}
