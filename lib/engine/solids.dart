import 'dart:math' as math;

import '../core/rng.dart';
import '../core/math3.dart';
import '../data/character.dart';
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
List<Solid> solidsOf(
  TownPiece piece, {
  TownCharacter? place,
  double lift = 0,
  double squash = 1.0,
}) {
  final y0 = piece.y0 + lift;
  final y1 = y0 + (piece.y1 - piece.y0) * squash;
  final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
  final i = piece.index;
  final s = piece.seed;

  switch (piece.kind) {
    case PieceKind.floor:
      final faces = boxFaces(x0, y0, z0, x1, y1, z1, Surface.wall);
      _hangWindows(faces, y0, y1, place);
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

    case PieceKind.thatch:
      return [Solid(i, thatchFaces(x0, y0, z0, x1, y1, z1, piece.alongX))];

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
/// What a plot has on it that nobody earned.
///
/// A kitchen garden and a tree. Neither is a piece: see `TownCharacter.gardens`
/// for why. Both are built as closed solids rather than as ground sheets,
/// because a sheet on the ground is only ever drawn along the wind's own path
/// and this is furniture, not weather.
///
/// Everything here names its own colour. Town furniture is painted by a
/// simpler road through the renderer than a piece is — one that asks the facet
/// what colour it is instead of asking the house it belongs to — so a facet
/// that does not say comes out the grey of nothing in particular, which is
/// what a vegetable bed and an oak both were until they were looked at.
class Yard {
  const Yard._();

  static const int _bark = 0xFF6B573F;
  static const List<int> _greens = [
    0xFF5E7040,
    0xFF6B7A42,
    0xFF54663C,
    0xFF77854C,
  ];

  /// Three raised beds and a pair of stakes. Read from above — which is how
  /// this town is nearly always read — that is a kitchen garden, and a
  /// ploughed field is not: a field is a shape in the distance, a garden is
  /// beds you could walk between.
  static List<Solid> gardenAt(double cx, double cz, double size, int seed) {
    final out = <Solid>[];
    const rows = 3;
    final wide = size * 0.84, deep = size * 0.84;
    final gap = deep / rows;
    for (var r = 0; r < rows; r++) {
      final z = cz - deep / 2 + gap * (r + 0.5);
      final h = size * (0.16 + hash01(seed, 60 + r) * 0.12);
      final w = wide * (0.74 + hash01(seed, 70 + r) * 0.24);
      out.add(
        Solid(
          -1,
          boxFaces(
            cx - w / 2,
            0,
            z - gap * 0.32,
            cx + w / 2,
            h,
            z + gap * 0.32,
            // Hoja y no «color propio»: así la huerta sigue el calendario
            // del año como cualquier otra hoja del valle, en vez de quedarse
            // verde primavera bajo la nieve.
            Surface.leaf,
            ao: 0.94,
            tint: _greens[(seed + r) & 3],
          ),
        ),
      );
    }
    // Two stakes on the corners: what says somebody keeps this, rather than
    // that the weeds happen to have come up in rows.
    for (var k = 0; k < 2; k++) {
      final x = cx + (k == 0 ? -1 : 1) * wide * 0.5;
      out.add(
        Solid(
          -1,
          boxFaces(
            x - 0.035,
            0,
            cz - deep * 0.5 - 0.035,
            x + 0.035,
            size * (0.38 + hash01(seed, 80 + k) * 0.16),
            cz - deep * 0.5 + 0.035,
            Surface.own,
            ao: 0.88,
            tint: _bark,
          ),
        ),
      );
    }
    return out;
  }

  /// One tree over the plot: a trunk and two boxes of leaves, the same tree a
  /// churchyard yew is, because a tree is a tree.
  static List<Solid> treeAt(double cx, double cz, double size, int seed) {
    final ht = size * (1.6 + hash01(seed, 90) * 0.8);
    final w = size * (0.80 + hash01(seed, 91) * 0.34);
    final trunk = w * 0.16;
    final leaf = _greens[seed & 3];
    return [
      Solid(
        -1,
        boxFaces(
          cx - trunk / 2,
          0,
          cz - trunk / 2,
          cx + trunk / 2,
          ht * 0.44,
          cz + trunk / 2,
          Surface.own,
          ao: 0.85,
          tint: _bark,
        ),
      ),
      Solid(
        -1,
        boxFaces(
          cx - w * 0.41,
          ht * 0.38,
          cz - w * 0.41,
          cx + w * 0.41,
          ht * 0.76,
          cz + w * 0.41,
          Surface.leaf,
          ao: 0.96,
          tint: leaf,
        ),
      ),
      Solid(
        -1,
        boxFaces(
          cx - w * 0.27,
          ht * 0.72,
          cz - w * 0.27,
          cx + w * 0.27,
          ht,
          cz + w * 0.27,
          Surface.leaf,
          ao: 1.0,
          tint: _greens[(seed + 1) & 3],
        ),
      ),
    ];
  }
}

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
/// A roof in straw.
///
/// Thatch is not tile the colour of straw. Two things say so from across a
/// street, and both are shape: the eaves are a **fat lip** — half a metre of
/// packed straw with a blunt edge, not a tile's thin line — and the ridge is
/// **rounded over** rather than folded to an arris, because straw will not
/// hold an edge and the ridge is where a thatcher lays his thickest bundle.
///
/// So the cross-section is a hexagon, not a triangle: up the outside of the
/// lip, up the slope, across the flat of the ridge, and back down. Extruded
/// along the ridge with a cap at each end, it is a closed solid like
/// everything else here, which is the whole reason the renderer can be sure
/// which of its faces are seen.
List<Facet> thatchFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  bool alongX,
) {
  final rise = y1 - y0;
  // Across the slope, the two numbers that make it straw: how deep the eaves
  // hang and how wide the ridge is rolled over.
  final across = alongX ? (z1 - z0) : (x1 - x0);
  final lip = math.min(rise * 0.30, across * 0.11);
  final roll = across * 0.06;
  final m = alongX ? (z0 + z1) / 2 : (x0 + x1) / 2;
  final r0 = m - roll, r1 = m + roll;
  final slope = (across / 2 - roll);
  final up = rise - lip;

  final out = <Facet>[];
  Facet face(List<V3> v, V3 n, Surface k, {double ao = 1.0, int data = 0}) =>
      Facet(v, n, k, ao: ao)..data = data;

  out.add(
    face(
      [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
      const V3(0, -1, 0),
      Surface.thatch,
      ao: 0.55,
    ),
  );

  if (alongX) {
    // the fat edge of the eaves, both sides
    out.add(
      face(
        [
          V3(x0, y0, z1),
          V3(x1, y0, z1),
          V3(x1, y0 + lip, z1),
          V3(x0, y0 + lip, z1),
        ],
        const V3(0, 0, 1),
        Surface.thatch,
        ao: 0.78,
        data: 1,
      ),
    );
    out.add(
      face(
        [
          V3(x1, y0, z0),
          V3(x0, y0, z0),
          V3(x0, y0 + lip, z0),
          V3(x1, y0 + lip, z0),
        ],
        const V3(0, 0, -1),
        Surface.thatch,
        ao: 0.72,
        data: 2,
      ),
    );
    // the two slopes
    out.add(
      face(
        [
          V3(x0, y0 + lip, z1),
          V3(x1, y0 + lip, z1),
          V3(x1, y1, r1),
          V3(x0, y1, r1),
        ],
        V3(0, slope, up).normalized,
        Surface.thatch,
        data: 3,
      ),
    );
    out.add(
      face(
        [
          V3(x1, y0 + lip, z0),
          V3(x0, y0 + lip, z0),
          V3(x0, y1, r0),
          V3(x1, y1, r0),
        ],
        V3(0, slope, -up).normalized,
        Surface.thatch,
        ao: 0.92,
        data: 4,
      ),
    );
    // the roll of the ridge
    out.add(
      face(
        [V3(x0, y1, r0), V3(x1, y1, r0), V3(x1, y1, r1), V3(x0, y1, r1)],
        const V3(0, 1, 0),
        Surface.thatch,
        data: 5,
      ),
    );
    // and a cap at each end
    for (final (x, n, ao) in [
      (x1, const V3(1, 0, 0), 0.86),
      (x0, const V3(-1, 0, 0), 0.80),
    ]) {
      out.add(
        face(
          [
            V3(x, y0, z0),
            V3(x, y0, z1),
            V3(x, y0 + lip, z1),
            V3(x, y1, r1),
            V3(x, y1, r0),
            V3(x, y0 + lip, z0),
          ],
          n,
          Surface.thatch,
          ao: ao,
          data: 6,
        ),
      );
    }
    return out;
  }

  out.add(
    face(
      [
        V3(x1, y0, z0),
        V3(x1, y0, z1),
        V3(x1, y0 + lip, z1),
        V3(x1, y0 + lip, z0),
      ],
      const V3(1, 0, 0),
      Surface.thatch,
      ao: 0.78,
      data: 1,
    ),
  );
  out.add(
    face(
      [
        V3(x0, y0, z1),
        V3(x0, y0, z0),
        V3(x0, y0 + lip, z0),
        V3(x0, y0 + lip, z1),
      ],
      const V3(-1, 0, 0),
      Surface.thatch,
      ao: 0.72,
      data: 2,
    ),
  );
  out.add(
    face(
      [
        V3(x1, y0 + lip, z0),
        V3(x1, y0 + lip, z1),
        V3(r1, y1, z1),
        V3(r1, y1, z0),
      ],
      V3(up, slope, 0).normalized,
      Surface.thatch,
      data: 3,
    ),
  );
  out.add(
    face(
      [
        V3(x0, y0 + lip, z1),
        V3(x0, y0 + lip, z0),
        V3(r0, y1, z0),
        V3(r0, y1, z1),
      ],
      V3(-up, slope, 0).normalized,
      Surface.thatch,
      ao: 0.92,
      data: 4,
    ),
  );
  out.add(
    face(
      [V3(r0, y1, z0), V3(r0, y1, z1), V3(r1, y1, z1), V3(r1, y1, z0)],
      const V3(0, 1, 0),
      Surface.thatch,
      data: 5,
    ),
  );
  for (final (z, n, ao) in [
    (z1, const V3(0, 0, 1), 0.86),
    (z0, const V3(0, 0, -1), 0.80),
  ]) {
    out.add(
      face(
        [
          V3(x0, y0, z),
          V3(x1, y0, z),
          V3(x1, y0 + lip, z),
          V3(r1, y1, z),
          V3(r0, y1, z),
          V3(x0, y0 + lip, z),
        ],
        n,
        Surface.thatch,
        ao: ao,
        data: 6,
      ),
    );
  }
  return out;
}

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
/// The windows of one storey.
///
/// How many and how big is where a wall says how thick it is. There is no
/// thickness to a wall in this world — a house is a closed box — so a thick
/// one is read the way a real one is: the opening is narrower, and it is set
/// back far enough to be ringed by its own shadow. A frontier town on the
/// Marca would rather have wall than window and gets both; on the Costa the
/// glass is almost flush and there is twice as much of it.
void _hangWindows(
  List<Facet> faces,
  double y0,
  double y1,
  TownCharacter? place,
) {
  final h = y1 - y0;
  if (h < 0.5) return;
  final thick = place?.wallThick ?? 0.0;
  final gap = place?.windowGap ?? 1.0;

  // Cuántas filas de ventanas lleva este cuerpo.
  //
  // Una por cuerpo mientras el cuerpo mida lo que mide una planta, que es como
  // está construido todo lo que hay hoy. Pero un cuerpo de cinco metros con
  // una sola fila de ventanas tiene ventanas de dos metros de alto, y entonces
  // deja de leerse como alto y pasa a leerse como un muro normal visto de
  // cerca. Un edificio se ve grande porque tiene muchas filas de ventanas
  // chicas, no una grande.
  //
  // El umbral está donde está para no tocar nada de lo que ya estaba: una
  // planta corriente mide entre uno y uno y medio, así que ninguna de las seis
  // regiones llega a dos filas. Está de antemano, para lo que venga.
  final filas = math.max(1, (h / 2.6).floor());
  final alto = h / filas;
  final hw = 0.15 * (1 - 0.28 * thick);
  // How far the opening is set back into the wall, as the width of the shadow
  // it throws around itself.
  final jamb = 0.062 * thick;
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
    final n = math.max(1, (span / (0.62 * gap)).floor());
    final decals = <Facet>[];
    for (var fila = 0; fila < filas; fila++) {
      final base = y0 + alto * fila;
      final wy0 = base + alto * 0.34, wy1 = base + alto * 0.74;
      for (var i = 0; i < n; i++) {
        final c = lo + span * (i + 0.5) / n;
        List<V3> rect(double a, double b, double p0, double p1) => onZ
            ? [V3(a, p0, out), V3(b, p0, out), V3(b, p1, out), V3(a, p1, out)]
            : [V3(out, p0, a), V3(out, p0, b), V3(out, p1, b), V3(out, p1, a)];
        // The reveal first, so the opening is painted inside it: unlit, because
        // the inside of a hole in a thick wall is a shadow and not a surface.
        if (jamb > 0.002) {
          decals.add(
            Facet(
              rect(c - hw - jamb, c + hw + jamb, wy0 - jamb, wy1 + jamb),
              f.n,
              Surface.hollow,
            )..data = i,
          );
        }
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

/// The notice board in the plaza.
///
/// Not a piece and never earned: the plots are laid out around a crossing at
/// the middle of the town and this stands in it, from the first achievement
/// on. A town that made you pay an achievement for the place where it tells
/// you things would be charging you to read your own handwriting.
class NoticeBoard {
  /// Half the width of the plank people read.
  /// Two thirds of a metre across and shoulder high, near enough — smaller
  /// than a house wall and bigger than the thumb that has to find it.
  static const double reach = 0.37;
  static const double low = 0.52, high = 1.02;
  static const double _post = 0.065, _top = 1.08;

  /// The four corners of the plank, front face, counter-clockwise from the
  /// bottom left. The town's mark goes on it and a finger lands on it, and
  /// both want the same rectangle.
  static List<V3> faceAt(double cx, double cz) => [
    V3(cx - reach, low, cz + 0.05),
    V3(cx + reach, low, cz + 0.05),
    V3(cx + reach, high, cz + 0.05),
    V3(cx - reach, high, cz + 0.05),
  ];

  /// Cuántas hojas caben en la plancha: dos filas de cinco, las mismas que
  /// tiene el tablón de cerca, para que la silueta se corresponda con lo que
  /// hay clavado de verdad.
  static const int rows = 2, cols = 5;
  static const int capacity = rows * cols;

  /// The plank, with the sheets that are actually pinned to it.
  ///
  /// The sheets are geometry and not a picture painted over the town, so a
  /// house standing between you and the board hides them the way it hides
  /// everything else. From across the plaza that is all a notice board is:
  /// pale paper on dark wood.
  ///
  /// [sheets] son los huecos ocupados del tablón de cerca, los mismos y en el
  /// mismo sitio. Así la plaza dice de lejos lo que se ve al acercarse —medio
  /// lleno se ve medio lleno, y con los papeles donde están— en vez de tener
  /// tres papeles de adorno que no querían decir nada.
  static List<Facet> _plank(double cx, double cz, int tint, List<int> sheets) {
    final faces = boxFaces(
      cx - reach,
      low,
      cz - 0.05,
      cx + reach,
      high,
      cz + 0.05,
      Surface.own,
      ao: 1.0,
      tint: tint,
    );
    const paper = 0xFFE9DCBC;
    // El hueco útil de la plancha, y una rejilla de dos por cinco dentro.
    const aire = 0.035;
    final usableW = (reach - aire) * 2, usableH = high - low - aire * 2;
    final colW = usableW / cols, rowH = usableH / rows;
    final w = colW * 0.36, h = w / 1.3;
    final papeles = <Facet>[];
    for (final hueco in sheets) {
      if (hueco < 0 || hueco >= capacity) continue;
      final row = hueco % rows, col = hueco ~/ rows;
      final mx = cx - reach + aire + (col + 0.5) * colW;
      final my = low + aire + (rows - 1 - row + 0.5) * rowH;
      papeles.add(
        Facet(
          [
            V3(mx - w, my - h, cz + 0.05),
            V3(mx + w, my - h, cz + 0.05),
            V3(mx + w, my + h, cz + 0.05),
            V3(mx - w, my + h, cz + 0.05),
          ],
          const V3(0, 0, 1),
          Surface.own,
          ao: 1.06,
          tint: paper,
        ),
      );
    }
    for (var i = 0; i < faces.length; i++) {
      if (faces[i].n.z < 0.9) continue;
      faces[i] = Facet(
        faces[i].v,
        faces[i].n,
        faces[i].surface,
        ao: faces[i].ao,
        tint: faces[i].tint,
        decals: papeles,
      );
    }
    return faces;
  }

  static List<Solid> solidsAt(
    double cx,
    double cz, {
    List<int> sheets = const [0, 3, 6],
  }) {
    const wood = 0xFF6B573F;
    const plank = 0xFFC9B896;
    const shingle = 0xFF8A7355;
    Solid post(double at) => Solid(
      -1,
      boxFaces(
        cx + at - _post / 2,
        0,
        cz - _post / 2,
        cx + at + _post / 2,
        _top,
        cz + _post / 2,
        Surface.own,
        ao: 0.88,
        tint: wood,
      ),
    );

    return [
      post(-reach + _post),
      post(reach - _post),
      Solid(-1, _plank(cx, cz, plank, sheets)),
      // A little roof, because paper left out in the rain is not a notice.
      Solid(
        -1,
        gableFaces(
              cx - reach - 0.09,
              high,
              cz - 0.17,
              cx + reach + 0.09,
              high + 0.17,
              cz + 0.17,
              true,
            )
            .map((f) => Facet(f.v, f.n, Surface.own, ao: f.ao, tint: shingle))
            .toList(),
      ),
    ];
  }
}
