import 'dart:math' as math;

import '../core/rng.dart';
import '../core/math3.dart';
import 'solid.dart';
import 'town.dart';

/// Turns a piece of a building into closed geometry.
///
/// This file knows nothing about cameras, palettes or canvases. It says where
/// the stone is; the renderer says what it looks like at six in the evening in
/// November. Keeping the two apart is what makes "is this solid closed?" a
/// question a test can answer, and a closed solid is the reason a face can
/// never go missing at some angle: there is no such thing as the inside of a
/// house here, so every face has a twin looking the other way, and exactly one
/// of the two is turned towards you.
List<Solid> solidsOf(TownPiece piece, {double lift = 0, double squash = 1.0}) {
  final y0 = piece.y0 + lift;
  final y1 = y0 + (piece.y1 - piece.y0) * squash;
  final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
  final i = piece.index;
  final s = piece.seed;

  switch (piece.kind) {
    case PieceKind.floor:
      final faces = boxFaces(x0, y0, z0, x1, y1, z1, Surface.wall);
      _hangWindows(faces, y0, y1);
      return [Solid(i, faces)];

    case PieceKind.porch:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.wall, ao: 0.9)),
      ];

    case PieceKind.plinth:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.stone, ao: 0.86)),
      ];

    case PieceKind.parapet:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.stone, ao: 0.95)),
      ];

    case PieceKind.chimney:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.brick, ao: 0.92)),
      ];

    case PieceKind.roof:
      return [Solid(i, gableFaces(x0, y0, z0, x1, y1, z1, piece.alongX))];

    case PieceKind.spire:
      return [Solid(i, spireFaces(x0, y0, z0, x1, y1, z1))];

    case PieceKind.dome:
      return [
        Solid(i, domeFaces(piece.cx, piece.cz, piece.w, piece.d, y0, y1)),
      ];

    case PieceKind.dormer:
      // A window in the roof, not a crate on it: a low limewashed front with a
      // small roof of its own turned across the slope it comes out of.
      final eaves = y0 + (y1 - y0) * 0.58;
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, eaves, z1, Surface.wall, ao: 0.95)),
        Solid(i, gableFaces(x0, eaves, z0, x1, y1, z1, !piece.alongX)),
      ];

    case PieceKind.stair:
      final out = <Solid>[];
      const steps = 3;
      final rise = (y1 - y0) / steps;
      final run = piece.alongX ? piece.d : piece.w;
      for (var k = 0; k < steps; k++) {
        final shrink = run * (k / steps) * 0.5;
        final w = piece.alongX ? piece.w : piece.w - shrink;
        final d = piece.alongX ? piece.d - shrink : piece.d;
        out.add(
          Solid(
            i,
            boxFaces(
              piece.cx - w / 2,
              y0 + k * rise,
              piece.cz - d / 2,
              piece.cx + w / 2,
              y0 + (k + 1) * rise,
              piece.cz + d / 2,
              Surface.stone,
              ao: 0.9 + k * 0.04,
            ),
          ),
        );
      }
      return out;

    case PieceKind.arcade:
      return _arcade(piece, y0, y1);

    case PieceKind.tree:
      final ht = y1 - y0;
      final trunk = piece.w * 0.16;
      final cx = piece.cx, cz = piece.cz;
      return [
        Solid(
          i,
          boxFaces(
            cx - trunk / 2,
            y0,
            cz - trunk / 2,
            cx + trunk / 2,
            y0 + ht * 0.42,
            cz + trunk / 2,
            Surface.own,
            ao: 0.85,
            tint: 0xFF6B573F,
          ),
        ),
        Solid(
          i,
          boxFaces(
            cx - piece.w * 0.41,
            y0 + ht * 0.36,
            cz - piece.d * 0.41,
            cx + piece.w * 0.41,
            y0 + ht * 0.74,
            cz + piece.d * 0.41,
            Surface.leaf,
            ao: 0.98,
          ),
        ),
        Solid(
          i,
          boxFaces(
            cx - piece.w * 0.26,
            y0 + ht * 0.70,
            cz - piece.d * 0.26,
            cx + piece.w * 0.26,
            y1,
            cz + piece.d * 0.26,
            Surface.leaf,
            ao: 1.08,
          ),
        ),
      ];

    case PieceKind.palisade:
      final along = piece.alongX;
      final len = along ? piece.w : piece.d;
      final n = clampD(len / 0.34, 2, 16).round();
      final step = len / n;
      final start = (along ? x0 : z0) + step / 2;
      final out = <Solid>[];
      for (var k = 0; k < n; k++) {
        final c = start + k * step;
        final top = y1 - hash01(s, 12, k) * (y1 - y0) * 0.18;
        final w = along ? step * 0.6 : piece.w;
        final d = along ? piece.d : step * 0.6;
        final ccx = along ? c : piece.cx;
        final ccz = along ? piece.cz : c;
        out.add(
          Solid(
            i,
            boxFaces(
              ccx - w / 2,
              y0,
              ccz - d / 2,
              ccx + w / 2,
              top,
              ccz + d / 2,
              Surface.own,
              ao: 0.9,
              tint: 0xFF7A6549,
            ),
          ),
        );
      }
      return out;

    case PieceKind.wheel:
      return _wheel(piece, y0, y1);

    case PieceKind.banner:
      // The pole is masonry's business; the cloth flies, and flying things are
      // drawn after the town is standing.
      return [
        Solid(
          i,
          boxFaces(
            piece.cx - 0.045,
            y0,
            piece.cz - 0.045,
            piece.cx + 0.045,
            y1,
            piece.cz + 0.045,
            Surface.own,
            ao: 0.9,
            tint: 0xFF6B573F,
          ),
        ),
      ];

    case PieceKind.sail:
      final r = (y1 - y0) / 2;
      final cy = y0 + r;
      final cz = piece.cz - 0.16 + 0.06;
      return [
        Solid(
          i,
          boxFaces(
            piece.cx - r * 0.14,
            cy - r * 0.14,
            cz - 0.11,
            piece.cx + r * 0.14,
            cy + r * 0.14,
            cz + 0.11,
            Surface.own,
            ao: 0.88,
            tint: 0xFF5A4835,
          ),
        ),
      ];

    case PieceKind.field:
    case PieceKind.water:
      // Ploughed rows and standing water are sheets lying on the ground that
      // move with the wind. They carry no volume and nothing stands on them.
      return const [];
  }
}

/// True when a piece has something that moves, drawn after the masonry.
bool hasWeather(PieceKind k) =>
    k == PieceKind.field ||
    k == PieceKind.water ||
    k == PieceKind.sail ||
    k == PieceKind.banner;

// --------------------------------------------------------------- the shapes

/// The six faces of a box, wound counter-clockwise seen from outside.
List<Facet> boxFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  Surface s, {
  double ao = 1.0,
  int? tint,
  double top = 1.0,
}) => [
  Facet(
    [V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1)],
    const V3(0, 0, 1),
    s,
    ao: ao,
    tint: tint,
  ),
  Facet(
    [V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0)],
    const V3(0, 0, -1),
    s,
    ao: ao,
    tint: tint,
  ),
  Facet(
    [V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1)],
    const V3(1, 0, 0),
    s,
    ao: ao * 0.94,
    tint: tint,
  ),
  Facet(
    [V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0)],
    const V3(-1, 0, 0),
    s,
    ao: ao * 0.94,
    tint: tint,
  ),
  Facet(
    [V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0), V3(x0, y1, z0)],
    const V3(0, 1, 0),
    s,
    ao: ao * top,
    tint: tint,
  ),
  Facet(
    [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
    const V3(0, -1, 0),
    s,
    ao: ao * 0.55,
    tint: tint,
  ),
];

/// A pitched roof: two slopes, two ends and the floor that closes it.
///
/// The floor is not decoration. Without it a roof is a shell, and a shell
/// cannot be back-face culled — which is exactly how half a roof used to
/// disappear depending on where you stood.
List<Facet> gableFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  bool alongX,
) {
  final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
  final rise = y1 - y0;
  final floor = Facet(
    [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
    const V3(0, -1, 0),
    Surface.tile,
    ao: 0.55,
  );
  if (alongX) {
    final run = (z1 - z0) / 2;
    return [
      Facet(
        [V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, mz), V3(x0, y1, mz)],
        V3(0, run, rise).normalized,
        Surface.tile,
      ),
      Facet(
        [V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, mz), V3(x1, y1, mz)],
        V3(0, run, -rise).normalized,
        Surface.tile,
        ao: 0.92,
      ),
      Facet(
        [V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, mz)],
        const V3(1, 0, 0),
        Surface.tile,
        ao: 0.86,
      ),
      Facet(
        [V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, mz)],
        const V3(-1, 0, 0),
        Surface.tile,
        ao: 0.86,
      ),
      floor,
    ];
  }
  final run = (x1 - x0) / 2;
  // The slope climbs `run` across and `rise` up, so its normal leans the other
  // way round: `rise` across and `run` up. Written the obvious way — the same
  // two numbers in the same order as the slope that carried them — every roof
  // whose ridge runs north to south has been lit as though it were shallow
  // when it is steep and steep when it is shallow, ever since there were
  // roofs. Only a test that checks a normal is square to its own face was ever
  // going to catch that; the eye never did.
  return [
    Facet(
      [V3(x1, y0, z0), V3(x1, y0, z1), V3(mx, y1, z1), V3(mx, y1, z0)],
      V3(rise, run, 0).normalized,
      Surface.tile,
    ),
    Facet(
      [V3(x0, y0, z1), V3(x0, y0, z0), V3(mx, y1, z0), V3(mx, y1, z1)],
      V3(-rise, run, 0).normalized,
      Surface.tile,
      ao: 0.92,
    ),
    Facet(
      [V3(x0, y0, z1), V3(x1, y0, z1), V3(mx, y1, z1)],
      const V3(0, 0, 1),
      Surface.tile,
      ao: 0.86,
    ),
    Facet(
      [V3(x1, y0, z0), V3(x0, y0, z0), V3(mx, y1, z0)],
      const V3(0, 0, -1),
      Surface.tile,
      ao: 0.86,
    ),
    floor,
  ];
}

/// A spire: four faces to a point, and the base that closes it.
List<Facet> spireFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
) {
  final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
  final apex = V3(mx, y1, mz);
  final rise = y1 - y0;
  final rx = (x1 - x0) / 2, rz = (z1 - z0) / 2;
  return [
    Facet(
      [V3(x0, y0, z1), V3(x1, y0, z1), apex],
      V3(0, rz, rise).normalized,
      Surface.tile,
    ),
    Facet(
      [V3(x1, y0, z0), V3(x0, y0, z0), apex],
      V3(0, rz, -rise).normalized,
      Surface.tile,
      ao: 0.9,
    ),
    Facet(
      [V3(x1, y0, z1), V3(x1, y0, z0), apex],
      V3(rise, rx, 0).normalized,
      Surface.tile,
      ao: 0.95,
    ),
    Facet(
      [V3(x0, y0, z0), V3(x0, y0, z1), apex],
      V3(-rise, rx, 0).normalized,
      Surface.tile,
      ao: 0.95,
    ),
    Facet(
      [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
      const V3(0, -1, 0),
      Surface.tile,
      ao: 0.55,
    ),
  ];
}

/// A rounded cap: rings of quads narrowing to a point, on a closed base.
List<Facet> domeFaces(
  double cx,
  double cz,
  double w,
  double d,
  double y0,
  double y1,
) {
  const rings = 3, sides = 8;
  final rx = w / 2, rz = d / 2, rise = y1 - y0;
  V3 at(int ring, int i) {
    final t = ring / rings;
    final k = math.cos(t * math.pi / 2);
    // Wrapped, not run past the end: the eighth face has to close onto the
    // very same corner the first one started from, or the dome is a shell with
    // a hairline crack down it and nothing downstream can be sure it is shut.
    final a = (i % sides) * 2 * math.pi / sides;
    return V3(
      cx + math.cos(a) * rx * k,
      y0 + math.sin(t * math.pi / 2) * rise,
      cz + math.sin(a) * rz * k,
    );
  }

  final out = <Facet>[];
  final apex = V3(cx, y1, cz);
  // The middle of the dome's own base, so every face can be turned to look
  // away from it.
  final core = V3(cx, y0, cz);
  Facet shell(List<V3> v) =>
      Facet(v, Facet.normalOf(v, away: core), Surface.tile);
  for (var ring = 0; ring < rings; ring++) {
    for (var i = 0; i < sides; i++) {
      final a = at(ring, i), b = at(ring, i + 1);
      if (ring == rings - 1) {
        out.add(shell([a, b, apex]));
      } else {
        // Two triangles, not one quad. Four points on a curved surface are not
        // flat, and a face that is not flat has no plane — which is the one
        // thing everything after this needs it to have.
        final c = at(ring + 1, i + 1), d = at(ring + 1, i);
        out.add(shell([a, b, c]));
        out.add(shell([a, c, d]));
      }
    }
  }
  final base = <V3>[];
  for (var i = sides - 1; i >= 0; i--) {
    base.add(at(0, i));
  }
  out.add(Facet(base, const V3(0, -1, 0), Surface.tile, ao: 0.55));
  return out;
}

// ------------------------------------------------------------- the fiddly bits

/// A run of arches: the piers, the band they carry, and the shadow standing in
/// each opening, set back so the arch reads as a hole rather than a stripe.
List<Solid> _arcade(TownPiece piece, double y0, double y1) {
  final along = piece.alongX;
  final len = along ? piece.w : piece.d;
  final n = clampD(len / 0.95, 1, 8).round();
  final ht = y1 - y0;
  final pierW = len / n * 0.34;
  final step = len / n;
  final start = (along ? piece.x0 : piece.z0) + step / 2;
  final headY = y0 + ht * 0.72;
  final out = <Solid>[
    Solid(
      piece.index,
      boxFaces(
        piece.x0,
        headY,
        piece.z0,
        piece.x1,
        y1,
        piece.z1,
        Surface.stone,
      ),
    ),
  ];
  for (var i = 0; i <= n; i++) {
    final c = start - step / 2 + i * step;
    final w = along ? pierW : piece.w;
    final d = along ? piece.d : pierW;
    final ccx = along ? c : piece.cx;
    final ccz = along ? piece.cz : c;
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          y0,
          ccz - d / 2,
          ccx + w / 2,
          headY,
          ccz + d / 2,
          Surface.stone,
          ao: 0.92,
        ),
      ),
    );
  }
  const set = 0.035;
  for (var i = 0; i < n; i++) {
    final c = start + i * step;
    final gap = step - pierW;
    final w = along ? gap : piece.w - set * 2;
    final d = along ? piece.d - set * 2 : gap;
    final ccx = along ? c : piece.cx;
    final ccz = along ? piece.cz : c;
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          y0,
          ccz - d / 2,
          ccx + w / 2,
          headY,
          ccz + d / 2,
          Surface.hollow,
          ao: 0.7,
        ),
      ),
    );
  }
  return out;
}

/// A water wheel: a closed ring of chords, the paddles standing out of it, and
/// the hub.
List<Solid> _wheel(TownPiece piece, double y0, double y1) {
  final r = (y1 - y0) / 2;
  final cy = y0 + r;
  final cx = piece.cx, cz = piece.cz;
  final flat = piece.alongX;
  const spokes = 12;
  final thick = r * 0.16;
  final out = <Solid>[];

  void slab(
    double ccx,
    double ccz,
    double w,
    double d,
    double a,
    double b,
    int tint,
    double ao,
  ) {
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          a,
          ccz - d / 2,
          ccx + w / 2,
          b,
          ccz + d / 2,
          Surface.own,
          ao: ao,
          tint: tint,
        ),
      ),
    );
  }

  for (var i = 0; i < spokes; i++) {
    final a = (i + 0.5) * 2 * math.pi / spokes;
    final px = math.cos(a) * r * 0.88, py = math.sin(a) * r * 0.88;
    final tangential = math.max(r * 2 * math.pi / spokes * 0.62, 0.08);
    final horiz = math.sin(a).abs() * tangential + math.cos(a).abs() * r * 0.16;
    final vert = math.cos(a).abs() * tangential + math.sin(a).abs() * r * 0.16;
    slab(
      flat ? cx + px : cx,
      flat ? cz : cz + px,
      flat ? horiz : thick,
      flat ? thick : horiz,
      cy + py - vert / 2,
      cy + py + vert / 2,
      0xFF8A7355,
      0.98,
    );
  }
  for (var i = 0; i < spokes ~/ 2; i++) {
    final a = i * 4 * math.pi / spokes;
    final px = math.cos(a) * r * 0.62, py = math.sin(a) * r * 0.62;
    slab(
      flat ? cx + px : cx,
      flat ? cz : cz + px,
      flat ? r * 0.5 : thick * 1.5,
      flat ? thick * 1.5 : r * 0.5,
      cy + py - r * 0.09,
      cy + py + r * 0.09,
      0xFF6E5A42,
      0.9,
    );
  }
  slab(
    cx,
    cz,
    flat ? r * 0.3 : thick * 1.4,
    flat ? thick * 1.4 : r * 0.3,
    cy - r * 0.15,
    cy + r * 0.15,
    0xFF6E5A42,
    0.88,
  );
  return out;
}

/// Windows, hung on the walls they belong to.
///
/// They are not faces of their own with a depth to be argued over: they are
/// carried by the wall's own face and painted the instant after it. A window
/// cannot fight its wall for depth when the question is never asked, which is
/// the end of the flicker that used to come and go as the camera swung round.
void _hangWindows(List<Facet> faces, double y0, double y1) {
  final h = y1 - y0;
  if (h < 0.5) return;
  final wy0 = y0 + h * 0.34, wy1 = y0 + h * 0.74;
  const hw = 0.15;
  for (final f in faces) {
    if (f.n.y.abs() > 0.01) continue;
    final onZ = f.n.z.abs() > 0.5;
    // The wall's own span, pulled in from its corners.
    var lo = double.infinity, hi = -double.infinity, out = 0.0;
    for (final p in f.v) {
      final t = onZ ? p.x : p.z;
      if (t < lo) lo = t;
      if (t > hi) hi = t;
      out = onZ ? p.z : p.x;
    }
    lo += 0.2;
    hi -= 0.2;
    final span = hi - lo;
    if (span < 0.5) continue;
    final n = math.max(1, (span / 0.62).floor());
    final decals = <Facet>[];
    for (var i = 0; i < n; i++) {
      final c = lo + span * (i + 0.5) / n;
      List<V3> rect(double a, double b, double p0, double p1) => onZ
          ? [V3(a, p0, out), V3(b, p0, out), V3(b, p1, out), V3(a, p1, out)]
          : [V3(out, p0, a), V3(out, p0, b), V3(out, p1, b), V3(out, p1, a)];
      decals.add(
        Facet(rect(c - hw, c + hw, wy0, wy1), f.n, Surface.window)..data = i,
      );
      // Two planks nailed across it, drawn only once the place has been empty
      // a while. The geometry is always here; whether it is painted is the
      // renderer's business, because neglect changes by the day and stone
      // does not.
      for (var k = 0; k < 2; k++) {
        final py = wy0 + (wy1 - wy0) * (k == 0 ? 0.28 : 0.66);
        final th = (wy1 - wy0) * 0.13;
        decals.add(
          Facet(
            rect(c - hw * 1.25, c + hw * 1.25, py - th, py + th),
            f.n,
            Surface.plank,
          )..data = i,
        );
      }
    }
    if (decals.isEmpty) continue;
    final at = faces.indexOf(f);
    faces[at] = Facet(
      f.v,
      f.n,
      f.surface,
      ao: f.ao,
      tint: f.tint,
      decals: decals,
    );
  }
}
