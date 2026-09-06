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
  Mason(this.cx, this.cz, this.seed, this.alongX);

  final double cx, cz;
  final int seed;

  /// Which way the roofs of this building run.
  final bool alongX;

  final List<Spec> out = [];

  /// Every roof laid so far, so anything that comes up through one knows where
  /// its tiles are.
  final List<_Roof> _roofs = [];

  /// The top of what has been laid so far.
  double y = 0;

  int get count => out.length;

  double h01(int salt) => hash01(seed, salt);
  double rand(double a, double b, int salt) => hashRange(a, b, seed, salt);

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
    out.add(Spec(
      kind: kind,
      cx: cx + dx,
      cz: cz + dz,
      w: w,
      d: d,
      y0: y0,
      y1: y1,
      alongX: along ?? alongX,
    ));
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
    final base = at ?? y;
    _add(k, dx, dz, w, d, base, base + ht, along: along);
    if (k == PieceKind.roof) {
      _roofs.add(_Roof(dx, dz, w, d, base, ht, along ?? alongX));
    }
    if (!ridge && at == null) y += ht;
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

  /// A storey with windows in it.
  void floor(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.floor, w, d, ht, dx: dx, dz: dz);

  /// A stone base, wider than what stands on it.
  void plinth(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.plinth, w, d, ht, dx: dx, dz: dz);

  /// A pitched roof. Sits on the course line without raising it, so a chimney
  /// laid afterwards comes up through it.
  void roof(double w, double d, double rise,
          {double dx = 0, double dz = 0, bool? along, double? at}) =>
      box(PieceKind.roof, w, d, rise,
          dx: dx, dz: dz, ridge: true, at: at, along: along);

  /// A roof that also raises the course line, for a mass built on top of one.
  void roofUnder(double w, double d, double rise,
      {double dx = 0, double dz = 0, bool? along}) {
    box(PieceKind.roof, w, d, rise, dx: dx, dz: dz, along: along);
  }

  void spire(double w, double d, double rise,
          {double dx = 0, double dz = 0, double? at}) =>
      box(PieceKind.spire, w, d, rise, dx: dx, dz: dz, at: at);

  void dome(double w, double d, double rise,
          {double dx = 0, double dz = 0, double? at}) =>
      box(PieceKind.dome, w, d, rise, dx: dx, dz: dz, at: at);

  void parapet(double w, double d, double ht,
          {double dx = 0, double dz = 0}) =>
      box(PieceKind.parapet, w, d, ht, dx: dx, dz: dz);

  /// A chimney comes out *through* a roof, so it is laid from the tiles up.
  ///
  /// Started at the wall head it would be a tall box with most of its length
  /// buried in the roof, and no renderer that sorts whole faces can decide
  /// which half of a buried box to draw: from one side the roof swallows the
  /// chimney whole, from the other the chimney shows all the way down to the
  /// eaves. Standing it on the tiles there is nothing buried to argue about.
  void chimney(double side, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.chimney, side, side, ht,
          dx: dx, dz: dz, ridge: true, at: _tilesAt(dx, dz) - 0.08);

  /// A door, which belongs on the ground whatever has been built above it.
  void door(double w, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.porch, w, 0.44, ht, dx: dx, dz: dz, at: 0);

  /// A dormer straddles the tiles: half in the roof, half out of it. Laid from
  /// the wall head it was buried nearly whole, which is the same argument the
  /// chimney was having.
  void dormer(double w, double ht, {double dx = 0, double dz = 0, double? at}) =>
      box(PieceKind.dormer, w, w * 0.85, ht,
          dx: dx, dz: dz, ridge: true, at: at ?? _tilesAt(dx, dz) - ht * 0.45);

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
  void palisade(double len, double ht,
          {double dx = 0, double dz = 0, bool along = true}) =>
      _add(PieceKind.palisade, dx, dz, along ? len : 0.22,
          along ? 0.22 : len, 0, ht, along: along);

  /// A pole with a banner on it.
  void banner(double ht, {double dx = 0, double dz = 0, double? at}) =>
      _add(PieceKind.banner, dx, dz, 0.5, 0.5, at ?? 0, (at ?? 0) + ht);

  /// A run of arches carrying whatever is above them.
  void arcade(double len, double ht, double depth,
      {double dx = 0, double dz = 0, bool? along, double? at, bool rise = false}) {
    final base = at ?? y;
    final a = along ?? alongX;
    _add(PieceKind.arcade, dx, dz, a ? len : depth, a ? depth : len, base,
        base + ht,
        along: a);
    if (rise && at == null) y += ht;
  }

  /// A flight of steps climbing towards the centre of the building.
  void stair(double w, double rise, double run,
          {double dx = 0, double dz = 0, bool? along, double? at}) =>
      _add(PieceKind.stair, dx, dz, w, run, at ?? 0, (at ?? 0) + rise,
          along: along);

  /// A water wheel, turning in the plane across its short side.
  void wheel(double diameter, {double dx = 0, double dz = 0, bool? along}) =>
      _add(PieceKind.wheel, dx, dz, diameter, diameter, 0.0, diameter,
          along: along);

  /// The sails of a windmill, on the face of whatever they are pinned to.
  void sails(double diameter, {double dx = 0, double dz = 0, required double at}) =>
      _add(PieceKind.sail, dx, dz, diameter, diameter, at - diameter / 2,
          at + diameter / 2);

  /// A single upright: the leg of a well roof, a gallows, the end of a
  /// trellis.
  void post(double side, double ht,
          {double dx = 0, double dz = 0, double at = 0}) =>
      box(PieceKind.parapet, side, side, ht,
          dx: dx, dz: dz, ridge: true, at: at);

  /// A horizontal member resting on posts. Without [at] it rests on the course
  /// line, which is where the thing it was laid after left off.
  void beam(double w, double d, double ht,
          {double dx = 0, double dz = 0, double? at}) =>
      box(PieceKind.parapet, w, d, ht,
          dx: dx, dz: dz, ridge: true, at: at ?? y);

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
  void outbuilding(double w, double d, double ht, double rise,
      {double dx = 0, double dz = 0, bool? along}) {
    box(PieceKind.floor, w, d, ht, dx: dx, dz: dz, ridge: true, at: 0);
    box(PieceKind.roof, w + 0.25, d + 0.25, rise,
        dx: dx, dz: dz, ridge: true, at: ht, along: along);
  }

  /// A long low body: the nave of a church, the hall of a market.
  void hall(double w, double d, double ht, double rise,
      {double dx = 0, double dz = 0, bool? along}) {
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
  const _Roof(this.dx, this.dz, this.w, this.d, this.base, this.rise,
      this.alongX);
  final double dx, dz, w, d, base, rise;
  final bool alongX;

  /// The height of the tiles above a point, or null when the point is not
  /// under this roof at all.
  double? surfaceAt(double x, double z) {
    final hw = w / 2, hd = d / 2;
    if (hw <= 0 || hd <= 0) return null;
    if ((x - dx).abs() > hw || (z - dz).abs() > hd) return null;
    // Flat at the ridge, down to the eaves across the slope.
    final across =
        alongX ? (z - dz).abs() / hd : (x - dx).abs() / hw;
    return base + rise * (1 - across);
  }
}
