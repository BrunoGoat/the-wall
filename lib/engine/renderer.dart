import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../fx/effects.dart';
import 'camera.dart';
import 'town.dart';
import 'landscape.dart';
import 'palette.dart';

int _ch(double v) {
  final i = (v * 255.0).round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

/// One town in the valley, and what the habit behind it is called.
class TownEntry {
  const TownEntry({
    required this.layout,
    required this.name,
    required this.symbol,
    required this.integrity,
    required this.placed,
  });

  final TownLayout layout;
  final String name;
  final String symbol;

  /// How lit this town is. A habit left alone goes dark, and from across the
  /// valley that is the whole comparison: this one is alive, that one is not.
  final double integrity;
  final int placed;
}

/// One stone as it appears on screen this frame, kept so taps can be resolved
/// back to the brick that was drawn there.
class PickTarget {
  PickTarget(this.brickIndex, this.cx, this.cy, this.radius, this.labelled);
  final int brickIndex;
  final double cx, cy, radius;

  /// True when this stone carries a note, so it can be marked on the wall.
  final bool labelled;
}

class TownScene {
  TownScene({
    required this.placed,
    required this.palette,
    required this.camera,
    required this.integrity,
    required this.time,
    required this.effects,
    required this.labelledBricks,
    this.fx,
    this.budget = 2900,
    required this.towns,
    required this.active,
    this.finished,
    this.finishedAge = 99,
    this.selectedBrick,
    this.charge = 0,
  });

  /// How many achievements have been laid.
  final int placed;
  final Palette palette;
  final OrbitCamera camera;
  final double integrity;
  final double time;
  final EffectSystem effects;

  /// How many pieces are worth drawing this frame, trimmed to hold the frame
  /// rate on whatever phone this is.
  final int budget;

  /// Bricks the person wrote a note on.
  final Set<int> labelledBricks;

  final PlacementFx? fx;





  /// Every town in the valley, one per habit, and which of them is the one
  /// being built right now. They are all drawn: the whole point of a valley
  /// with several towns in it is being able to look at them together.
  final List<TownEntry> towns;
  final int active;

  TownLayout get town => towns[active].layout;

  /// The building that has just been finished, and how long ago in seconds.
  /// A house takes days to build and a second to celebrate.
  final int? finished;
  final double finishedAge;

  /// The stone the person just tapped, ringed so it is obvious which one the
  /// note belongs to.
  final int? selectedBrick;

  /// 0..1 while the place button is held down.
  final double charge;
}

class _Face {
  final Float32List pts = Float32List(56);
  int n = 0;
  double depth = 0;
  int color = 0;
  bool outline = false;
}

/// Draws the whole world: sky, ground, the wall in full detail nearby, and its
/// own silhouette receding into the haze when it gets long.
class TownPainter extends CustomPainter {
  TownPainter(this.scene, this.picks);

  final TownScene scene;
  final List<PickTarget> picks;

  static final List<_Face> _facePool = List.generate(16000, (_) => _Face());
  static final Float64List _clipA = Float64List(96);
  static final Float64List _clipB = Float64List(96);
  static final Path _scratch = Path();

  int _faceCount = 0;

  /// Where the lit windows landed on screen this frame, so their light can be
  /// laid over the town after the masonry is down. x, y, radius, strength.
  final List<double> _lamps = [];

  _Face? _nextFace() {
    if (_faceCount >= _facePool.length) return null;
    return _facePool[_faceCount++];
  }

  @override
  void paint(Canvas canvas, Size size) {
    picks.clear();
    _faceCount = 0;
    _lamps.clear();

    final p = scene.camera.projector(size.width, size.height, scene.time);
    final horizonY = _horizonY(p, size);
    final town = scene.town;

    _drawSky(canvas, size, p, horizonY);
    _drawGround(canvas, size, horizonY);
    _drawRanges(canvas, p, size, horizonY);
    for (final e in scene.towns) {
      _drawTownGround(canvas, p, e.layout);
    }
    _drawMeadow(p, size, town);
    _drawRings(canvas, p, town, overlay: false);
    _collectTown(p, size);
    _flush(canvas);
    _drawLamps(canvas, size);
    _drawBirds(canvas, p, size, town);
    _drawRings(canvas, p, town, overlay: true);
    _drawTownGhost(canvas, p, size, town);
    _drawTownLabels(canvas, p, size, town);
    _drawTownSigns(canvas, p, size);
    _drawParticles(canvas, p);
    _drawAtmosphere(canvas, size, horizonY);
  }

  // ------------------------------------------------------------------- sky

  double _horizonY(Projector p, Size size) {
    final f = p.forward;
    var hx = f.x, hz = f.z;
    final l = math.sqrt(hx * hx + hz * hz);
    if (l < 1e-5) return -size.height; // looking straight down
    hx /= l;
    hz /= l;
    final d = V3(hx, 0, hz);
    final den = d.dot(p.forward);
    if (den.abs() < 1e-5) return -size.height;
    return p.cy - p.focal * (d.dot(p.up) / den);
  }

  void _drawSky(Canvas canvas, Size size, Projector p, double horizonY) {
    final pal = scene.palette;
    final h = size.height;
    final top = 0.0;
    final hy = clampD(horizonY, -h * 3, h * 4);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final span = math.max(1.0, hy - top);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, hy - span),
        Offset(0, hy),
        [pal.skyTop, pal.skyHorizon],
      );
    canvas.drawRect(rect, paint);

    if (pal.starAlpha > 0.02) _drawStars(canvas, size, p, horizonY);
    _drawSun(canvas, size, p);

    // A soft band of haze sitting on the horizon.
    if (hy > -h && hy < h * 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, hy - h * 0.22, size.width, h * 0.22),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, hy - h * 0.22),
            Offset(0, hy),
            [pal.skyHorizon.withValues(alpha: 0), pal.haze.withValues(alpha: 0.85)],
          ),
      );
    }
  }

  void _drawStars(Canvas canvas, Size size, Projector p, double horizonY) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 130; i++) {
      final az = hash01(i, 3) * math.pi * 2;
      final el = 0.06 + hash01(i, 5) * 1.4;
      final d = V3(math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el));
      final den = d.dot(p.forward);
      if (den <= 0.05) continue;
      final sx = p.cx + p.focal * d.dot(p.right) / den;
      final sy = p.cy - p.focal * d.dot(p.up) / den;
      if (sx < 0 || sx > size.width || sy < 0 || sy > horizonY) continue;
      final tw = 0.55 + 0.45 * math.sin(scene.time * 1.7 + i * 2.1);
      paint.color = Colors.white.withValues(
          alpha: (0.25 + 0.55 * hash01(i, 9)) * tw * scene.palette.starAlpha);
      canvas.drawCircle(Offset(sx, sy), 0.6 + hash01(i, 11) * 1.1, paint);
    }
  }

  /// The sun through the day, the moon through the night. Both ride the same
  /// arc, which is what makes the shadows swing round as the hours pass.
  void _drawSun(Canvas canvas, Size size, Projector p) {
    final pal = scene.palette;
    final day = pal.isDaylight;
    final d = day ? pal.sunDir : pal.moonDir;
    final den = d.dot(p.forward);
    if (den <= 0.08) return;
    final sx = p.cx + p.focal * d.dot(p.right) / den;
    final sy = p.cy - p.focal * d.dot(p.up) / den;
    if (sx < -400 || sx > size.width + 400) return;

    final r = size.shortestSide * (day ? 0.052 : 0.040);
    final glow = day ? 5.5 : 3.4;
    // Low sun reddens and swells, the way it does near the horizon.
    final low = 1 - clampD(d.y * 2.4, 0, 1);
    final disc = day
        ? Color.lerp(pal.sun, const Color(0xFFFF9A4D), low * 0.55)!
        : const Color(0xFFEFF3FF);

    canvas.drawCircle(
      Offset(sx, sy),
      r * glow * (1 + low * 0.5),
      Paint()
        ..shader = ui.Gradient.radial(Offset(sx, sy), r * glow * (1 + low * 0.5), [
          disc.withValues(alpha: day ? 0.32 : 0.20),
          disc.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(
        Offset(sx, sy), r, Paint()..color = disc.withValues(alpha: 0.94));
    if (!day) {
      // A bite out of the disc, so it reads as a moon and not a pale sun.
      canvas.drawCircle(
        Offset(sx + r * 0.42, sy - r * 0.30),
        r * 0.88,
        Paint()..color = pal.skyTop.withValues(alpha: 0.92),
      );
    }
  }

  void _drawGround(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    final hy = clampD(horizonY, -size.height, size.height * 2);
    if (hy > size.height) return;
    final rect = Rect.fromLTWH(0, hy, size.width, size.height - hy);
    if (rect.height <= 0) return;
    // The wall stands on a dry plain; the town stands in a meadow. The same
    // ground, read to suit what is built on it.
    final meadow = true && pal.isDaylight;
    final near = meadow
        ? Color.lerp(pal.ground, const Color(0xFF6B8F3E), 0.45)!
        : pal.ground;
    final far = meadow
        ? Color.lerp(pal.groundFar, const Color(0xFF7E9A4C), 0.38)!
        : pal.groundFar;
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(
          Offset(0, hy), Offset(0, size.height), [far, near]),
    );
  }

  /// Three ranges of hills standing all the way round the horizon.
  ///
  /// They are drawn as a ring centred on wherever the camera is looking, but
  /// their shape is sampled from world position, so walking along the wall
  /// reveals new country instead of dragging the same skyline along.
  /// The three mountain ranges on the skyline.
  ///
  /// Three things had to be true at once, and the old version got none of them
  /// right once the camera left its usual place:
  ///
  ///  * The ring has to be centred on the *camera*, not on the point it is
  ///    looking at. Zoomed all the way out the eye sits a hundred units from
  ///    that point, which put it almost on top of the nearest range — half the
  ///    country ended up behind the viewer, and the half in front reared up
  ///    across the whole screen.
  ///  * The shape has to be sampled somewhere that does not move when you
  ///    merely orbit, or the skyline swims as you turn. So the geometry follows
  ///    the eye and the height follows the stretch of wall being looked at:
  ///    walking the wall still reveals new country, turning on the spot does
  ///    not.
  ///  * Every strip has to be a closed shape. Whenever a point fell behind the
  ///    near plane the old loop handed Skia an open path, which closes itself
  ///    with a straight line back to the start — that is where the huge wedges
  ///    across the view came from. Now only the arc actually in front of the
  ///    camera is walked at all, and each strip is closed by construction.
  void _drawRanges(Canvas canvas, Projector p, Size size, double horizonY) {
    final pal = scene.palette;
    final light = pal.lightDir;

    // Below the horizon is the ground plane, and a range hundreds of units away
    // is behind it. Clipping there is what stops the mountains from floating in
    // the middle of the field when the camera looks down at the wall, and what
    // makes their feet meet the ground instead of hanging over it.
    final cut = clampD(horizonY, -1.0, size.height + 1.0);
    if (cut <= 0) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, -size.height, size.width, cut + size.height + 1),
    );

    // Only the arc in front of the camera: everything else is behind the eye,
    // where projection is meaningless. Sampled just wide enough for the lens.
    final az = math.atan2(p.forward.x, p.forward.z);
    final span = math.atan(size.width * 0.5 / p.focal) + 0.30;
    const steps = 210;
    final floor = size.height + 40;
    final look = scene.camera.travel;

    for (var li = Landscape.ridges.length - 1; li >= 0; li--) {
      final layer = Landscape.ridges[li];
      final fade = 0.30 + li * 0.28;
      // The nearest range keeps some of the ground's own colour; the far ones
      // dissolve almost entirely into the haze.
      final base = Color.lerp(pal.ground, pal.groundFar, 0.35 + li * 0.3)!;
      final body = Color.lerp(base, pal.haze, fade)!;
      final lit = Color.lerp(body, pal.sun, 0.20 * (1 - fade))!;

      var path = Path();
      var open = false;
      var litSide = false;
      var startX = 0.0, lastX = 0.0, crest = size.height;

      // Each range fades into the haze where it meets the horizon, the way
      // distance actually works. Into the haze and not into the ground: fading
      // to the ground's own colour made the two indistinguishable exactly where
      // they meet, and the skyline dissolved instead of standing against the
      // field.
      Paint fill(bool isLit) {
        final c = isLit ? lit : body;
        final top = math.min(crest, cut - 1);
        return Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, top),
            Offset(0, cut),
            [c, Color.lerp(c, pal.haze, 0.42 + 0.12 * (2 - li) / 2)!],
          );
      }

      void close() {
        if (!open) return;
        path
          ..lineTo(lastX, floor)
          ..lineTo(startX, floor)
          ..close();
        canvas.drawPath(path, fill(litSide));
        path = Path();
        open = false;
        crest = size.height;
      }

      for (var i = 0; i <= steps; i++) {
        final th = az - span + (i / steps) * (span * 2);
        final dx = math.sin(th), dz = math.cos(th);
        final h = Landscape.ridgeHeight(
          layer,
          look + dx * layer.radius,
          dz * layer.radius,
        );
        final top = p.project(V3(
          p.eye.x + dx * layer.radius,
          math.max(h, layer.base),
          p.eye.z + dz * layer.radius,
        ));
        if (top == null) {
          close();
          continue;
        }
        // Slopes facing the light catch a little more of it.
        final facing = (dx * light.x + dz * light.z) < 0;
        if (open && facing != litSide) {
          // Carry the seam through so the two strips meet along one edge
          // instead of leaving a hairline of sky between them.
          if (top.y < crest) crest = top.y;
          path
            ..lineTo(top.x, top.y)
            ..lineTo(top.x, floor)
            ..lineTo(startX, floor)
            ..close();
          canvas.drawPath(path, fill(litSide));
          path = Path()..moveTo(top.x, floor);
          path.lineTo(top.x, top.y);
          startX = top.x;
          litSide = facing;
          lastX = top.x;
          crest = top.y;
          continue;
        }
        if (!open) {
          path.moveTo(top.x, floor);
          path.lineTo(top.x, top.y);
          startX = top.x;
          litSide = facing;
          crest = top.y;
          open = true;
        } else {
          path.lineTo(top.x, top.y);
          if (top.y < crest) crest = top.y;
        }
        lastX = top.x;
      }
      close();
    }

    canvas.restore();
  }

  // ------------------------------------------------------------- far wall

  void _quad(Projector p, V3 a, V3 b, V3 c, V3 d, int color,
      {double? depthOverride}) {
    final pts = [a, b, c, d];
    for (var i = 0; i < 4; i++) {
      final cp = p.cameraOf(pts[i]);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    _emit(p, _clipA, 4, color, depthOverride: depthOverride);
  }

  /// Clips a camera-space polygon, projects it and stores it for sorting.
  void _emit(Projector p, Float64List cam, int count, int color,
      {bool outline = false, double? depthOverride}) {
    final m = clipNear(cam, count, _clipB, p.near);
    if (m < 3) return;
    final f = _nextFace();
    if (f == null) return;
    var depth = 0.0;
    for (var i = 0; i < m; i++) {
      final z = _clipB[i * 3 + 2];
      f.pts[i * 2] = p.screenX(_clipB[i * 3], z);
      f.pts[i * 2 + 1] = p.screenY(_clipB[i * 3 + 1], z);
      depth += z;
    }
    f.n = m;
    f.depth = depthOverride ?? depth / m;
    f.color = color;
    f.outline = outline;
  }

  // --------------------------------------------------------------- stones

  void _registerPick(_Face f, int brickIndex, Size size) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < f.n; i++) {
      final x = f.pts[i * 2], y = f.pts[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (maxX < 0 || minX > size.width || maxY < 0 || minY > size.height) return;
    picks.add(PickTarget(
      brickIndex,
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      math.max(6.0, math.max(maxX - minX, maxY - minY) * 0.55),
      scene.labelledBricks.contains(brickIndex),
    ));
  }

  // ------------------------------------------------------------------ town

  /// Haze by real distance rather than by distance along one axis.
  ///
  /// The wall runs east to west, so fading it by how far it is along x is
  /// close enough. A town spreads in both directions, and fading it by x alone
  /// leaves the north end of a street crisp and the west end of it lost.
  Color _hazeAt(Color c, Projector p, double x, double z, Palette pal) {
    final dx = x - p.eye.x, dz = z - p.eye.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    // The town is meant to be looked at, not squinted through: it keeps most
    // of its colour all the way to the far side of the valley.
    // Capped: from across the valley a town must still be a town and not a
    // smudge the colour of the grass. Distance says "further away", never
    // "gone".
    final t = 1 - math.exp(-dist * 0.0040);
    if (t < 0.004) return c;
    return Color.lerp(c, pal.haze, math.min(t * 0.5, 0.30))!;
  }

  /// The lanes between the blocks, and the shadow each building sits in.
  void _drawTownGround(Canvas canvas, Projector p, TownLayout town) {
    final pal = scene.palette;
    // A yard of packed earth around each house: the ground people walk on,
    // worn bare by the door and ragged at the edges where the grass wins.
    // A tidy square of grey reads as a concrete slab, which is the one thing a
    // medieval town must never look like.
    final pad = Color.lerp(
        Color.lerp(pal.ground, const Color(0xFFB0946C), 0.72)!,
        pal.skyLight,
        0.10)!;
    final half = town.plotPitch * 0.46;
    for (final b in town.buildings) {
      if (b.placedPieces <= 0) continue;
      final s = b.seed;
      // Eight points round the edge, each pulled in or out a little, so no two
      // yards are the same shape and none of them has a drawn corner.
      final path = Path();
      var started = false;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final r = half * hashRange(0.78, 1.12, s, 40, i);
        final at = p.project(
            V3(b.cx + math.cos(a) * r * 1.32, 0.004, b.cz + math.sin(a) * r * 1.32));
        if (at == null) {
          started = false;
          break;
        }
        if (!started) {
          path.moveTo(at.x, at.y);
          started = true;
        } else {
          path.lineTo(at.x, at.y);
        }
      }
      if (!started) continue;
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = _hazeAt(pad, p, b.cx, b.cz, pal)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // A soft pool of shade under each building. The wall gets a real projected
    // shadow; a hundred and fifty houses would cost far too much for that, and
    // at this size a contact shadow is what stops them floating anyway.
    final light = pal.lightDir;
    final drop = clampD(1.0 / math.max(0.25, light.y), 0.8, 2.4);
    for (final b in town.buildings) {
      if (b.placedPieces <= 0 || b.peakY <= 0.05) continue;
      final h = b.peakY;
      final at = p.project(V3(
        b.cx - light.x * drop * h * 0.35,
        0.006,
        b.cz - light.z * drop * h * 0.35,
      ));
      if (at == null) continue;
      final r = p.focal / at.depth * (1.3 + h * 0.18);
      if (r < 2) continue;
      canvas.drawCircle(
        Offset(at.x, at.y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
            pal.ink.withValues(alpha: 0.20 * scene.integrity.clamp(0.5, 1.0)),
            pal.ink.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// A ghost of the piece that is about to be laid.
  ///
  /// The town always shows you the next thing it is waiting for: an outline
  /// standing where the piece will go, breathing on its own and firming up as
  /// the button is held. It is the difference between pressing a button and
  /// finishing something you can already see.
  void _drawTownGhost(Canvas canvas, Projector p, Size size, TownLayout town) {
    if (scene.fx != null) return; // one is already in flight
    final piece = town.pieceFor(scene.placed);
    if (piece == null) return;
    final pal = scene.palette;
    final charge = scene.charge;

    // A slow breath when idle, and a firm hold while the button is down.
    final breath = 0.5 + 0.5 * math.sin(scene.time * 2.1);
    final alpha = 0.16 + breath * 0.10 + charge * 0.55;

    final y0 = piece.y0, y1 = piece.y1;
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    if (p.cameraOf(V3(piece.cx, (y0 + y1) / 2, piece.cz)).z <= p.near) return;

    Offset? at(double x, double y, double z) {
      final q = p.project(V3(x, y, z));
      return q == null ? null : Offset(q.x, q.y);
    }

    final lo = [
      at(x0, y0, z0), at(x1, y0, z0), at(x1, y0, z1), at(x0, y0, z1),
    ];
    final hi = [
      at(x0, y1, z0), at(x1, y1, z0), at(x1, y1, z1), at(x0, y1, z1),
    ];
    if (lo.contains(null) || hi.contains(null)) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 + charge * 1.6
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(pal.accent, Colors.white, 0.35 + charge * 0.4)!
          .withValues(alpha: alpha);

    // Only the uprights and the top: a full cage reads as a bug report.
    final path = Path();
    for (var i = 0; i < 4; i++) {
      path
        ..moveTo(hi[i]!.dx, hi[i]!.dy)
        ..lineTo(hi[(i + 1) % 4]!.dx, hi[(i + 1) % 4]!.dy);
      // The corner posts, drawn as short ticks up from the ground.
      final a = lo[i]!, b = hi[i]!;
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(a.dx + (b.dx - a.dx) * 0.28, a.dy + (b.dy - a.dy) * 0.28)
        ..moveTo(b.dx - (b.dx - a.dx) * 0.28, b.dy - (b.dy - a.dy) * 0.28)
        ..lineTo(b.dx, b.dy);
    }
    canvas.drawPath(path, line);

    // A patch of light on the ground where it will land, so the eye knows
    // where to look even when the piece itself is a chimney on a far roof.
    final foot = at(piece.cx, math.max(0.02, y0), piece.cz);
    if (foot != null) {
      final q = p.cameraOf(V3(piece.cx, y0, piece.cz));
      final r = p.focal / q.z * math.max(piece.w, piece.d) * (0.7 + charge * 0.3);
      if (r > 2) {
        canvas.drawCircle(
          foot,
          r,
          Paint()
            ..shader = ui.Gradient.radial(foot, r, [
              Color.lerp(pal.accent, Colors.white, 0.5)!
                  .withValues(alpha: 0.10 + charge * 0.30),
              const Color(0x00000000),
            ]),
        );
      }
    }
  }

  /// The ring that runs out across the ground when something lands or is
  /// finished. Two lines and it is the thing the eye actually follows.
  void _drawRings(Canvas canvas, Projector p, TownLayout town,
      {required bool overlay}) {
    final pal = scene.palette;

    void ring(double cx, double cz, double r, double alpha, Color c,
        double width) {
      if (alpha <= 0.01 || r <= 0.02) return;
      const steps = 28;
      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final a = i * 2 * math.pi / steps;
        final at = p.project(V3(cx + math.cos(a) * r, 0.02, cz + math.sin(a) * r));
        if (at == null) return;
        if (i == 0) {
          path.moveTo(at.x, at.y);
        } else {
          path.lineTo(at.x, at.y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = c.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }

    final fx = scene.fx;

    // The shadow of the piece still in the air, closing under it as it comes
    // down. This is the whole of the anticipation: you can see exactly where it
    // is going and exactly how long it has left.
    if (!overlay && fx != null && !fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final up = fx.yOffset;
        final t = clampD(1 - up / 2.3, 0, 1);
        final at = p.project(V3(piece.cx, math.max(piece.y0, 0.02), piece.cz));
        if (at != null) {
          final base = math.max(piece.w, piece.d) * 0.55;
          final r = p.focal / at.depth * base * (1.7 - t * 0.85);
          if (r > 1.5) {
            canvas.drawCircle(
              Offset(at.x, at.y),
              r,
              Paint()
                ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
                  pal.ink.withValues(alpha: 0.10 + t * 0.30),
                  pal.ink.withValues(alpha: 0),
                ]),
            );
          }
        }
      }
    }

    // The dust ring under a piece that has just landed. Drawn before the
    // masonry, because dust goes behind a wall; the gold below is light, and
    // light goes in front.
    if (!overlay && fx != null && fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final t = clampD(fx.sinceImpact / 0.55, 0, 1);
        ring(piece.cx, piece.cz, 0.25 + t * 2.1, (1 - t) * (1 - t) * 0.55,
            Color.lerp(pal.stoneWarm, Colors.white, 0.4)!, 2.4);
      }
    }

    if (!overlay) return;

    // Two rings out from a building that has just been finished.
    final justDone = scene.finished;
    if (justDone != null && justDone < town.buildings.length) {
      final b = town.buildings[justDone];
      for (var i = 0; i < 2; i++) {
        final t = clampD((scene.finishedAge - i * 0.22) / 1.5, 0, 1);
        if (t <= 0) continue;
        final ease = 1 - math.pow(1 - t, 3).toDouble();
        ring(b.cx, b.cz, 0.4 + ease * (b.isLandmark ? 7.5 : 4.4),
            (1 - t) * (1 - t) * (b.isLandmark ? 0.85 : 0.6),
            const Color(0xFFF2C25B), b.isLandmark ? 3.0 : 2.2);
      }
    }
  }

  /// The light the lit windows throw, laid over the town once its walls are
  /// down. Half of what a town at night is, is the glow around the windows
  /// rather than the windows themselves.
  void _drawLamps(Canvas canvas, Size size) {
    if (_lamps.isEmpty) return;
    const warm = Color(0xFFFFC978);
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < _lamps.length; i += 4) {
      final x = _lamps[i], y = _lamps[i + 1];
      final r = _lamps[i + 2] * 3.0, k = _lamps[i + 3];
      if (x < -r || x > size.width + r || y < -r || y > size.height + r) {
        continue;
      }
      paint.shader = ui.Gradient.radial(Offset(x, y), r, [
        warm.withValues(alpha: 0.16 * k),
        warm.withValues(alpha: 0.055 * k),
        const Color(0x00000000),
      ], [
        0.0,
        0.38,
        1.0,
      ]);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// The sign over each town: its symbol, its name and how much of it is
  /// standing.
  ///
  /// This is the whole reason several towns share a valley. From far enough
  /// back you cannot read a house, but you can read four signs and see under
  /// each one how big and how lit its town is — which is the answer to "me
  /// está yendo bien con esto y mal con lo otro", said in one look.
  void _drawTownSigns(Canvas canvas, Projector p, Size size) {
    if (scene.towns.length < 2) return;
    final pal = scene.palette;
    final dark = _isDarkSky();

    // Nearest first, so a sign never covers one in front of it.
    final rows = <(double, int)>[];
    for (var i = 0; i < scene.towns.length; i++) {
      final l = scene.towns[i].layout;
      final dx = l.cx - p.eye.x, dz = l.cz - p.eye.z;
      rows.add((dx * dx + dz * dz, i));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    final taken = <Rect>[];
    for (final (_, i) in rows) {
      final e = scene.towns[i];
      final l = e.layout;
      // High enough to clear the roofs, wherever the camera is.
      final at = p.project(V3(l.cx, math.max(6.0, l.radius * 0.55), l.cz));
      if (at == null) continue;
      if (at.x < -140 || at.x > size.width + 140) continue;
      if (at.y < -80 || at.y > size.height + 80) continue;

      // Signs matter most from far away; up close the town speaks for itself.
      final d = at.depth;
      final near = clampD((d - 26) / 30, 0, 1);
      if (near <= 0.02) continue;
      final alive = e.integrity;
      final on = i == scene.active;

      final ink = dark ? Colors.white : pal.ink;
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '${e.symbol}  ',
            style: const TextStyle(fontSize: 15),
          ),
          TextSpan(
            text: e.name.toUpperCase(),
            style: TextStyle(
              color: ink.withValues(alpha: (on ? 0.95 : 0.66) * near),
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        textDirection: TextDirection.ltr,
      )..layout();

      final w = math.max(tp.width, 76.0);
      final cx = clampD(at.x, w / 2 + 14, size.width - w / 2 - 14);
      final box = Rect.fromLTWH(cx - w / 2 - 10, at.y - 14, w + 20, 46);
      if (taken.any(box.overlaps)) continue;
      taken.add(box);

      // A plate behind it, so a name is legible over a roof of any colour.
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(13)),
        Paint()
          ..color = (dark ? Colors.black : Colors.white)
              .withValues(alpha: (on ? 0.30 : 0.20) * near),
      );
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(13)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = pal.accent.withValues(alpha: 0.75 * near),
        );
      }
      tp.paint(canvas, Offset(cx - tp.width / 2, at.y - 9));

      // Under the name: how much town there is, and how much of it is lit.
      // Two towns side by side become two bars of different length, which is
      // the comparison without a single number being read.
      const bw = 62.0;
      final bar = Rect.fromLTWH(cx - bw / 2, at.y + 16, bw, 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = ink.withValues(alpha: 0.16 * near),
      );
      // Length is the size of the town, on a curve that keeps a young town
      // visible and stops an old one running off the end.
      final size01 = clampD(math.sqrt(e.placed / 900.0), 0.06, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bar.left, bar.top, bw * size01, 4),
          const Radius.circular(2),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF8E7A63),
            const Color(0xFFF2C25B),
            alive,
          )!
              .withValues(alpha: (0.35 + 0.6 * alive) * near),
      );
    }
  }

  /// A few birds turning over the town.
  ///
  /// They cost almost nothing and they do something no amount of masonry can:
  /// they make the sky part of the place. A town with birds over it is somewhere
  /// you are looking at; a town without them is a model on a table.
  void _drawBirds(Canvas canvas, Projector p, Size size, TownLayout town) {
    final pal = scene.palette;
    if (!pal.isDaylight) return;
    final t = scene.time;
    final ink = pal.ink.withValues(alpha: 0.42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // Two loose flocks on wide circles at different heights and speeds.
    for (var flock = 0; flock < 2; flock++) {
      final n = flock == 0 ? 5 : 3;
      final radius = town.radius * (flock == 0 ? 0.55 : 0.85) + 4;
      final height = 7.0 + flock * 4.5;
      final speed = (flock == 0 ? 0.085 : -0.062);
      final drift = hash01(flock, 7) * 6.28;
      for (var i = 0; i < n; i++) {
        final a = t * speed + drift + i * 0.34 + hash01(flock, i, 3) * 0.5;
        final wobble = math.sin(t * 0.7 + i * 1.3) * 0.9;
        final x = math.cos(a) * (radius + wobble);
        final z = math.sin(a) * (radius + wobble) * 0.8;
        final y = height + math.sin(t * 0.55 + i * 0.9) * 0.7;
        final at = p.project(V3(x, y, z));
        if (at == null) continue;
        if (at.x < -40 || at.x > size.width + 40) continue;
        if (at.y < -40 || at.y > size.height + 40) continue;
        final s = clampD(p.focal / at.depth * 0.16, 1.4, 9.0);
        // The beat of the wings, which is the whole animation.
        final beat = math.sin(t * 7.5 + i * 2.1);
        final lift = s * 0.55 * beat;
        paint
          ..strokeWidth = math.max(0.9, s * 0.20)
          ..color = ink.withValues(alpha: clampD(s / 6, 0.12, 0.42));
        final path = Path()
          ..moveTo(at.x - s, at.y - lift * 0.4)
          ..quadraticBezierTo(at.x - s * 0.4, at.y - lift, at.x, at.y)
          ..quadraticBezierTo(
              at.x + s * 0.4, at.y - lift, at.x + s, at.y - lift * 0.4);
        canvas.drawPath(path, paint);
      }
    }
  }

  /// The meadow the town stands in: tufts of grass leaning with the wind.
  ///
  /// Not a texture — a few hundred real blades, sized and coloured apart, near
  /// the camera only, and never where a building already stands. It is what
  /// turns a flat green field into ground.
  void _drawMeadow(Projector p, Size size, TownLayout town) {
    final pal = scene.palette;
    if (!pal.isDaylight && pal.starAlpha > 0.6) return;

    // Where the buildings are, at a coarse grid, so a tuft can be skipped
    // without asking a hundred and fifty houses one at a time.
    final reachEarly = clampD(scene.camera.distance * 2.0, 12, 62);
    final step = clampD(reachEarly / 52, 0.34, 1.0);
    final built = <int>{};
    for (final b in town.buildings) {
      final gx = (b.cx / step).round(), gz = (b.cz / step).round();
      // Only the plot itself is bare: the lanes between the houses are grass,
      // which is most of what the eye actually sees at street level.
      final pad = (1.2 / step).floor();
      for (var dx = -pad; dx <= pad; dx++) {
        for (var dz = -pad; dz <= pad; dz++) {
          built.add((gx + dx) * 8192 + (gz + dz));
        }
      }
    }

    final e = p.eye;
    final reach = reachEarly;
    final n = (reach / step).ceil();
    final ox = (e.x / step).round(), oz = (e.z / step).round();
    final base = Color.lerp(pal.ground, const Color(0xFF6B8F3E), 0.45)!;
    final green = Color.lerp(base, const Color(0xFF5E8F35), 0.7)!;
    final pale = Color.lerp(base, const Color(0xFF8FB44A), 0.7)!;
    var drawn = 0;

    for (var ix = -n; ix <= n; ix++) {
      for (var iz = -n; iz <= n; iz++) {
        if (drawn > 2600) return;
        final gx = ox + ix, gz = oz + iz;
        if (built.contains(gx * 8192 + gz)) continue;
        final x = gx * step + hashJitter(step * 0.42, gx, gz, 3);
        final z = gz * step + hashJitter(step * 0.42, gx, gz, 4);
        final dx = x - e.x, dz = z - e.z;
        final dist = math.sqrt(dx * dx + dz * dz);
        if (dist > reach || dist < 0.6) continue;

        // Different sizes, so it never reads as a stamped pattern.
        final h = hashRange(0.055, 0.155, gx, gz, 5);
        final lean = _gust(x, z) * _windForce;
        final tone = Color.lerp(green, pale, hash01(gx, gz, 6))!;
        // Fades out at the far edge instead of ending in a hard ring.
        final fade = clampD((reach - dist) / (reach * 0.28), 0, 1);
        if (fade < 0.05) continue;
        final c = _hazeAt(Color.lerp(base, tone, 0.45 + 0.55 * fade)!, p, x, z,
                pal)
            .toARGB32();

        // Only the near tufts are worth three blades.
        final blades = dist < reach * 0.4 ? 2 : 1;
        for (var k = 0; k < blades; k++) {
          final bx = x + hashJitter(0.09, gx, gz, 7 + k);
          final bz = z + hashJitter(0.09, gx, gz, 11 + k);
          final bh = h * hashRange(0.62, 1.0, gx, gz, 15 + k);
          final tipX = bx + lean * bh * 0.75;
          final tipZ = bz + lean * bh * 0.30;
          final wide = bh * 0.085;
          _quad(
            p,
            V3(bx - wide, 0.004, bz),
            V3(bx + wide, 0.004, bz),
            V3(tipX + wide * 0.18, bh, tipZ),
            V3(tipX - wide * 0.18, bh, tipZ),
            c,
          );
        }
        drawn++;
      }
    }
  }

  /// Every town in the valley, nearest piece first so the budget is spent
  /// where the eye is. One ordering across all of them, so a far town cannot
  /// eat the near one's detail.
  void _collectTown(Projector p, Size size) {
    final pal = scene.palette;
    final light = pal.lightDir;
    final fx = scene.fx;
    final night = !pal.isDaylight;

    // How high the finishing wave has climbed, and how bright it still is.
    var sweep = -1.0;
    var sweepFade = 0.0;
    final justDone = scene.finished;
    final active = scene.town;
    if (justDone != null && justDone < active.buildings.length) {
      final b = active.buildings[justDone];
      const rise = 0.85; // seconds from footings to ridge
      final t = scene.finishedAge / rise;
      if (t < 1.7) {
        sweep = (b.peakY + 0.6) * t;
        sweepFade = t <= 1 ? 1.0 : clampD(1 - (t - 1) / 0.7, 0, 1);
      }
    }

    // (town, piece) pairs, sorted together.
    final order = <int>[];
    final owners = <int>[];
    for (var w = 0; w < scene.towns.length; w++) {
      final e = scene.towns[w];
      final take = math.min(e.placed, e.layout.pieces.length);
      for (var i = 0; i < take; i++) {
        order.add(i);
        owners.add(w);
      }
    }
    final idx = List<int>.generate(order.length, (i) => i);
    double far(int k) {
      final q = scene.towns[owners[k]].layout.pieces[order[k]];
      final dx = q.cx - p.eye.x, dz = q.cz - p.eye.z;
      return dx * dx + dz * dz;
    }
    idx.sort((a, b) => far(a).compareTo(far(b)));

    for (var k = 0; k < idx.length && k < scene.budget; k++) {
      final w = owners[idx[k]];
      final e = scene.towns[w];
      final piece = e.layout.pieces[order[idx[k]]];
      final decay = 1.0 - e.integrity;
      var lift = 0.0;
      var flash = 0.0;
      var squash = 1.0;
      // A finished building lights up from its footings to its ridge, one
      // course at a time. Not a flat flash: a wave you can watch climb, which
      // is the difference between being told it is done and seeing it finish.
      if (w == scene.active && sweep >= 0 && piece.building == scene.finished) {
        final d = (piece.y0 - sweep).abs();
        if (d < 0.9) {
          flash = (1 - d / 0.9) * (1 - d / 0.9) * sweepFade;
        }
      }
      if (w == scene.active && fx != null && fx.brickIndex == piece.index) {
        lift = fx.yOffset;
        flash = fx.flash;
        // Squash on landing: the piece spreads as it takes the weight and then
        // springs back. It is a tenth of a second long and it is most of what
        // makes putting one down feel like anything at all.
        squash = fx.squash.$2;
      }
      _emitPiece(p, e.layout, piece, pal, light, decay, night, lift, flash,
          size, squash: squash);
    }
  }

  void _emitPiece(
    Projector p,
    TownLayout home,
    TownPiece piece,
    Palette pal,
    V3 light,
    double decay,
    bool night,
    double lift,
    double flash,
    Size size, {
    double squash = 1.0,
  }) {
    final s = piece.seed;
    // Colour belongs to the house, not to the piece: a wall that changes tone
    // halfway up, or a dormer that does not match its own roof, is the fastest
    // way to make a town look like a pile of blocks.
    final h = hash32(piece.building, 0x51ed, 3);
    final y0 = piece.y0 + lift;
    final y1 = y0 + (piece.y1 - piece.y0) * squash;
    // A house is plaster over stone: pale walls, a stone base, a warm roof.
    // Plaster takes a limewash, and every town has one it favours: Ribera is
    // white, Marca ochre, Costa indigo. Most houses take the local colour and
    // the rest go their own way, which is what stops a town reading as one
    // material repeated — and what makes two towns two places.
    final ch = home.character;
    Color wall() {
      final warm = hash01(h, 1);
      var c = Color.lerp(pal.stoneCool, pal.stoneWarm, 0.35 + warm * 0.55)!;
      final wash = hash01(h, 2);
      if (wash < ch.washShare) {
        c = Color.lerp(c, ch.wash, 0.30 + hash01(h, 21) * 0.22)!;
      } else if (wash < ch.washShare + 0.12) {
        c = Color.lerp(c, const Color(0xFFC9836E), 0.34)!;
      } else if (wash < ch.washShare + 0.20) {
        c = Color.lerp(c, const Color(0xFFA8B47A), 0.28)!;
      }
      return _weather(c, decay, s);
    }

    Color stone() => _weather(
        Color.lerp(pal.stoneCool, pal.stone, 0.55)!, decay, s);

    /// Tile, slate or thatch, in whatever mix this town roofs with.
    Color roofColour() {
      final t = hash01(h, 3);
      final (tile, slate, _) = ch.roofMix;
      final base = t < tile
          ? const Color(0xFFC05C38)
          : (t < tile + slate
              ? const Color(0xFF5B6B72)
              : const Color(0xFFA8853A));
      return _weather(Color.lerp(base, pal.stone, 0.08)!, decay, s);
    }

    switch (piece.kind) {
      case PieceKind.roof:
        _emitGable(p, piece, y0, y1, roofColour(), light, pal, 1.0, flash);
      case PieceKind.spire:
        _emitPyramid(p, piece, y0, y1, roofColour(), light, pal, flash);
      case PieceKind.plinth:
        _emitBox(p, piece, y0, y1,
            _weather(Color.lerp(pal.stoneCool, pal.stone, 0.5)!, decay, s),
            light, pal, 0.86, flash, size);
      case PieceKind.chimney:
        _emitBox(p, piece, y0, y1,
            _weather(const Color(0xFF8C6A52), decay, s), light, pal, 0.92,
            flash, size);
      case PieceKind.parapet:
        _emitBox(p, piece, y0, y1,
            _weather(Color.lerp(pal.stoneCool, pal.stone, 0.62)!, decay, s),
            light, pal, 0.95, flash, size);
      case PieceKind.dormer:
        _emitBox(p, piece, y0, y1, roofColour(), light, pal, 1.0, flash, size);
      case PieceKind.porch:
        _emitBox(p, piece, y0, y1, wall(), light, pal, 0.9, flash, size);
      case PieceKind.floor:
        _emitBox(p, piece, y0, y1, wall(), light, pal, 1.0, flash, size,
            windows: true, night: night, decay: decay);
      case PieceKind.dome:
        _emitDome(p, piece, y0, y1, roofColour(), light, pal, flash);
      case PieceKind.arcade:
        _emitArcade(p, piece, y0, y1, stone(), light, pal, flash, size);
      case PieceKind.stair:
        _emitStair(p, piece, y0, y1, stone(), light, pal, flash, size);
      case PieceKind.field:
        _emitField(p, piece, y0, pal, decay);
      case PieceKind.water:
        _emitWater(p, piece, y0, pal, night);
      case PieceKind.tree:
        _emitTree(p, piece, y0, y1, light, pal, decay, flash);
      case PieceKind.palisade:
        _emitPalisade(p, piece, y0, y1, light, pal, decay, flash);
      case PieceKind.banner:
        _emitBanner(p, piece, y0, y1, light, pal, flash);
      case PieceKind.wheel:
        _emitWheel(p, piece, y0, y1, light, pal, decay, flash);
      case PieceKind.sail:
        _emitSails(p, piece, y0, y1, light, pal, flash);
    }
  }

  // ------------------------------------------------------------------ wind

  /// One travelling gust, in -1..1.
  ///
  /// Everything that moves in the town moves to this same field, so the grass,
  /// the crops, the trees and the banners all lean the same way at the same
  /// moment. A dozen things each fidgeting to their own clock reads as noise;
  /// a dozen things leaning together reads as weather.
  double _gust(double x, double z, [double phase = 0]) {
    final t = scene.time;
    final a = math.sin(x * 0.36 + z * 0.23 - t * 1.25 + phase);
    final b = math.sin(x * 0.11 - z * 0.17 - t * 0.51 + phase * 0.6);
    return a * 0.62 + b * 0.38;
  }

  /// How hard it is blowing just now, so there are calm spells and gusty ones
  /// instead of one endless breeze.
  double get _windForce => 0.42 + 0.58 * (0.5 + 0.5 * math.sin(scene.time * 0.31));

  // ------------------------------------------------- the landmark vocabulary

  /// A dome: rings of quads narrowing to a cap. Cheap, and from any distance
  /// the town is seen at it reads as a dome rather than as eight facets.
  void _emitDome(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final cx = piece.cx, cz = piece.cz;
    if (p.cameraOf(V3(cx, (y0 + y1) / 2, cz)).z <= p.near) return;
    final rx = piece.w / 2, rz = piece.d / 2, rise = y1 - y0;
    const rings = 3, sides = 8;

    V3 at(int ring, int i) {
      final t = ring / rings;
      final k = math.cos(t * math.pi / 2);
      final a = i * 2 * math.pi / sides;
      return V3(cx + math.cos(a) * rx * k, y0 + math.sin(t * math.pi / 2) * rise,
          cz + math.sin(a) * rz * k);
    }

    for (var ring = 0; ring < rings; ring++) {
      for (var i = 0; i < sides; i++) {
        final a = at(ring, i), b = at(ring, i + 1);
        final c = at(ring + 1, i + 1), d = at(ring + 1, i);
        final ang = (i + 0.5) * 2 * math.pi / sides;
        final up = (ring + 0.5) / rings;
        final n = V3(math.cos(ang) * (1 - up * 0.75), 0.35 + up * 0.9,
                math.sin(ang) * (1 - up * 0.75))
            .normalized;
        _quad(p, a, b, c, d,
            _hazeAt(_shade(n, albedo, light, pal, 1.0, flash, 0), p, cx, cz, pal)
                .toARGB32());
      }
    }
  }

  /// A run of arches: the piers, and the wall above them with the openings
  /// left dark. Drawn as solid masonry with the voids painted in, which from
  /// outside is exactly what an arcade looks like.
  void _emitArcade(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double flash,
    Size size,
  ) {
    final along = piece.alongX;
    final len = along ? piece.w : piece.d;
    final n = clampD(len / 0.95, 1, 8).round();
    final e = p.eye;
    final ht = y1 - y0;
    final pierW = len / n * 0.34;
    final step = len / n;
    final start = (along ? piece.x0 : piece.z0) + step / 2;

    // The band over the arches.
    final headY = y0 + ht * 0.72;
    _emitSlab(p, piece.cx, piece.cz, piece.w, piece.d, headY, y1, albedo, light,
        pal, 1.0, flash);

    final dark = Color.lerp(pal.ink, albedo, 0.22)!;
    for (var i = 0; i <= n; i++) {
      final c = start - step / 2 + i * step;
      final px = along ? c : piece.cx;
      final pz = along ? piece.cz : c;
      _emitSlab(p, px, pz, along ? pierW : piece.w, along ? piece.d : pierW, y0,
          headY, albedo, light, pal, 0.92, flash);
    }
    // The shadow inside each opening, on whichever face the camera can see.
    for (var i = 0; i < n; i++) {
      final c = start + i * step;
      final w = step - pierW;
      if (along) {
        final z = e.z > piece.cz ? piece.z1 + 0.004 : piece.z0 - 0.004;
        _quad(p, V3(c - w / 2, y0, z), V3(c + w / 2, y0, z),
            V3(c + w / 2, headY, z), V3(c - w / 2, headY, z),
            _hazeAt(dark, p, piece.cx, piece.cz, pal).toARGB32());
      } else {
        final x = e.x > piece.cx ? piece.x1 + 0.004 : piece.x0 - 0.004;
        _quad(p, V3(x, y0, c - w / 2), V3(x, y0, c + w / 2),
            V3(x, headY, c + w / 2), V3(x, headY, c - w / 2),
            _hazeAt(dark, p, piece.cx, piece.cz, pal).toARGB32());
      }
    }
    _registerPickAt(p, piece, size, (y0 + y1) / 2);
  }

  /// A flight of steps, drawn as three shallow treads.
  void _emitStair(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double flash,
    Size size,
  ) {
    const steps = 3;
    final rise = (y1 - y0) / steps;
    final along = piece.alongX;
    final run = along ? piece.d : piece.w;
    for (var i = 0; i < steps; i++) {
      final shrink = run * (i / steps) * 0.5;
      _emitSlab(
        p,
        piece.cx,
        piece.cz,
        along ? piece.w : piece.w - shrink,
        along ? piece.d - shrink : piece.d,
        y0 + i * rise,
        y0 + (i + 1) * rise,
        albedo,
        light,
        pal,
        0.9 + i * 0.04,
        flash,
      );
    }
    _registerPickAt(p, piece, size, y1);
  }

  /// Ploughed rows, and the crop standing in them rippling with the wind.
  void _emitField(
      Projector p, TownPiece piece, double y0, Palette pal, double decay) {
    final s = piece.seed;
    // Real crop colours rather than a wash of the ground tone: young green,
    // ripe barley, the deep green of a kitchen garden.
    final t = hash01(s, 9);
    final crop = t < 0.36
        ? const Color(0xFF6FA341)
        : (t < 0.72 ? const Color(0xFFC9A94A) : const Color(0xFF4E8C46));
    final soil = const Color(0xFF6B563E);
    final along = piece.alongX;
    final across = along ? piece.d : piece.w;
    final rows = clampD(across / 0.26, 3, 14).round();
    final y = y0 + 0.012;
    final sway = 0.055 * _windForce;

    for (var i = 0; i < rows; i++) {
      final lean = _gust(piece.cx, piece.cz, i * 0.5) * sway;
      final a = (i + 0.10) / rows, b = (i + 0.86) / rows;
      final ripe = Color.lerp(crop, const Color(0xFFE0C86A),
          0.18 * (0.5 + 0.5 * _gust(piece.cx, piece.cz, i * 0.9)))!;
      final c = _hazeAt(
          Color.lerp(i.isEven ? ripe : soil, pal.ground, decay * 0.45)!,
          p,
          piece.cx,
          piece.cz,
          pal);
      // The crop stands a little proud of the soil, and leans.
      final h = i.isEven ? y + 0.10 : y;
      final push = i.isEven ? lean : 0.0;
      final V3 q0, q1, q2, q3;
      if (along) {
        final z0 = piece.z0 + across * a, z1 = piece.z0 + across * b;
        q0 = V3(piece.x0 + push, h, z0);
        q1 = V3(piece.x1 + push, h, z0);
        q2 = V3(piece.x1, y, z1);
        q3 = V3(piece.x0, y, z1);
      } else {
        final x0 = piece.x0 + across * a, x1 = piece.x0 + across * b;
        q0 = V3(x0, h, piece.z0 + push);
        q1 = V3(x0, h, piece.z1 + push);
        q2 = V3(x1, y, piece.z1);
        q3 = V3(x1, y, piece.z0);
      }
      var far = p.cameraOf(q0).z;
      for (final v in [q1, q2, q3]) {
        final z = p.cameraOf(v).z;
        if (z > far) far = z;
      }
      _quad(p, q0, q1, q2, q3, c.toARGB32(), depthOverride: far);
    }
  }

  /// Standing water: a colour of its own, bands of light running across it,
  /// and foam where it meets the bank.
  void _emitWater(
      Projector p, TownPiece piece, double y0, Palette pal, bool night) {
    final y = y0 + 0.05;
    final deep = night ? const Color(0xFF1E3A52) : const Color(0xFF35707B);
    final lit = night ? const Color(0xFF33556F) : const Color(0xFF5C9AA0);
    // Foam is water with air in it, not paint: it keeps the water's own colour
    // underneath, which is what stops it reading as a white sticker.
    final foam = Color.lerp(
        night ? const Color(0xFF8FA4B8) : const Color(0xFFE8F4F2), deep, 0.32)!;
    final cx = piece.cx, cz = piece.cz;

    int tint(Color c) => _hazeAt(c, p, cx, cz, pal).toARGB32();

    // A flat sheet lying on the ground is sorted by its farthest corner, not
    // its middle: a long ribbon of water running past a house has its centre
    // nearer than the house's, and would otherwise be painted over the wall.
    void plate(double x0, double x1, double z0, double z1, double h, Color c) {
      final a = V3(x0, h, z1), b = V3(x1, h, z1);
      final d = V3(x1, h, z0), e = V3(x0, h, z0);
      var far = p.cameraOf(a).z;
      for (final v in [b, d, e]) {
        final z = p.cameraOf(v).z;
        if (z > far) far = z;
      }
      _quad(p, a, b, d, e, tint(c), depthOverride: far);
    }

    plate(piece.x0, piece.x1, piece.z0, piece.z1, y, deep);

    // Bands of reflected light travelling across it. Each sits a hair higher
    // than the last so they never fight each other for the same depth.
    final w = piece.w, d = piece.d;
    const bands = 3;
    for (var i = 0; i < bands; i++) {
      final phase = scene.time * 0.33 + i * 0.41 + hash01(piece.seed, 21, i);
      final t = phase - phase.floorToDouble();
      final z = piece.z0 + d * t;
      final thick = d * (0.05 + 0.03 * math.sin(scene.time * 1.1 + i));
      if (z + thick > piece.z1) continue;
      final inset = w * 0.06;
      plate(piece.x0 + inset, piece.x1 - inset, z, z + thick,
          y + 0.004 + i * 0.002, Color.lerp(deep, lit, 0.55)!);
    }

    // Foam: a frill round the edge that breathes with the wind, so still water
    // still looks alive.
    final swell = 0.014 + 0.012 * _windForce;
    final rim = math.min(
        math.min(w, d) * (0.05 + 0.025 * _windForce), 0.13);
    if (rim < 0.02) return;
    final fy = y + 0.012;
    for (var side = 0; side < 4; side++) {
      final wob = rim * (0.7 + 0.5 * _gust(cx, cz, side * 1.7).abs());
      switch (side) {
        case 0:
          plate(piece.x0, piece.x1, piece.z0, piece.z0 + wob, fy, foam);
        case 1:
          plate(piece.x0, piece.x1, piece.z1 - wob, piece.z1, fy, foam);
        case 2:
          plate(piece.x0, piece.x0 + wob, piece.z0, piece.z1, fy, foam);
        case 3:
          plate(piece.x1 - wob, piece.x1, piece.z0, piece.z1, fy, foam);
      }
    }
    // And a lick of white further in on the windward side.
    final lick = rim * 0.6 * (0.5 + 0.5 * math.sin(scene.time * 1.7));
    if (lick > 0.01) {
      plate(piece.x0 + rim, piece.x1 - rim, piece.z0 + rim,
          piece.z0 + rim + lick, y + swell, foam);
    }
  }

  /// A tree: a trunk and a canopy of two stacked blocks, which at this scale
  /// reads as a tree and costs eight faces.
  void _emitTree(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double decay,
    double flash,
  ) {
    final ht = y1 - y0;
    final s = piece.seed;
    final leaf = Color.lerp(
      const Color(0xFF4E5C3C),
      const Color(0xFF6E7448),
      hash01(s, 11),
    )!;
    // Pulled towards the ground's own tone so a tree reads as part of the
    // landscape rather than as a green block dropped onto it.
    final settled = Color.lerp(leaf, pal.ground, 0.28)!;
    final autumn = Color.lerp(settled, const Color(0xFF8A6E42), decay * 0.6)!;
    final bark = const Color(0xFF6B573F);
    final trunk = piece.w * 0.16;
    _emitSlab(p, piece.cx, piece.cz, trunk, trunk, y0, y0 + ht * 0.42, bark,
        light, pal, 0.85, flash);
    _emitSlab(p, piece.cx, piece.cz, piece.w * 0.82, piece.d * 0.82,
        y0 + ht * 0.36, y0 + ht * 0.74, autumn, light, pal, 0.98, flash);
    _emitSlab(p, piece.cx, piece.cz, piece.w * 0.52, piece.d * 0.52,
        y0 + ht * 0.70, y1, autumn, light, pal, 1.08, flash);
  }

  /// A run of stakes.
  void _emitPalisade(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double decay,
    double flash,
  ) {
    final along = piece.alongX;
    final len = along ? piece.w : piece.d;
    final n = clampD(len / 0.34, 2, 16).round();
    final wood = _weather(const Color(0xFF7A6549), decay, piece.seed);
    final step = len / n;
    final start = (along ? piece.x0 : piece.z0) + step / 2;
    for (var i = 0; i < n; i++) {
      final c = start + i * step;
      final top = y1 - hash01(piece.seed, 12, i) * (y1 - y0) * 0.18;
      _emitSlab(
        p,
        along ? c : piece.cx,
        along ? piece.cz : c,
        along ? step * 0.6 : piece.w,
        along ? piece.d : step * 0.6,
        y0,
        top,
        wood,
        light,
        pal,
        0.9,
        flash,
      );
    }
  }

  /// A pole with a banner hanging from it. The one piece of the town allowed a
  /// colour that is not stone, plaster or tile.
  void _emitBanner(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final ht = y1 - y0;
    _emitSlab(p, piece.cx, piece.cz, 0.09, 0.09, y0, y1,
        const Color(0xFF6B573F), light, pal, 0.9, flash);
    // The one thing in the town allowed a colour that is not stone, plaster
    // or tile, and the one thing that flies.
    final pick = hash01(piece.seed, 13);
    final cloth = pick < 0.34
        ? const Color(0xFFC0392B)
        : (pick < 0.67 ? const Color(0xFFE0A32E) : const Color(0xFF2E6FA8));
    final e = p.eye;
    final gust = _gust(piece.cx, piece.cz, piece.seed * 0.0007);
    final fly = ht * (0.30 + 0.18 * _windForce * (0.5 + 0.5 * gust));
    final top = y1 - ht * 0.08, bot = top - ht * 0.34;
    // The free corner lifts and falls; the hoist stays on the pole.
    final wave = ht * 0.11 * gust * _windForce;
    final c = _hazeAt(cloth, p, piece.cx, piece.cz, pal).toARGB32();
    final shade =
        _hazeAt(Color.lerp(cloth, Colors.black, 0.22)!, p, piece.cx, piece.cz,
                pal)
            .toARGB32();
    if ((e.x - piece.cx).abs() > (e.z - piece.cz).abs()) {
      final z0 = piece.cz + 0.04, z1 = piece.cz + 0.04 + fly;
      _quad(p, V3(piece.cx, bot, z0), V3(piece.cx, bot + wave, z1),
          V3(piece.cx, top + wave, z1), V3(piece.cx, top, z0), c);
      _quad(p, V3(piece.cx, bot, z0), V3(piece.cx, bot + wave, z1),
          V3(piece.cx, bot + wave - ht * 0.06, z1),
          V3(piece.cx, bot - ht * 0.02, z0), shade);
    } else {
      final x0 = piece.cx + 0.04, x1 = piece.cx + 0.04 + fly;
      _quad(p, V3(x0, bot, piece.cz), V3(x1, bot + wave, piece.cz),
          V3(x1, top + wave, piece.cz), V3(x0, top, piece.cz), c);
      _quad(p, V3(x0, bot, piece.cz), V3(x1, bot + wave, piece.cz),
          V3(x1, bot + wave - ht * 0.06, piece.cz),
          V3(x0, bot - ht * 0.02, piece.cz), shade);
    }
  }

  /// A water wheel: a rim of paddles turning in a vertical plane.
  void _emitWheel(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double decay,
    double flash,
  ) {
    final r = (y1 - y0) / 2;
    final cy = y0 + r;
    final cx = piece.cx, cz = piece.cz;
    final wood = _weather(const Color(0xFF6E5A42), decay, piece.seed);
    final rim = _weather(const Color(0xFF8A7355), decay, piece.seed);
    // The wheel turns across its short side: along a wall running east-west it
    // stands in the east-west plane.
    final flat = piece.alongX;
    const spokes = 12;
    final thick = r * 0.16;
    // The rim first, as a closed ring of short chords, so it reads as a wheel
    // and not as a scatter of blocks floating in a circle.
    for (var i = 0; i < spokes; i++) {
      final a = (i + 0.5) * 2 * math.pi / spokes;
      final px = math.cos(a) * r * 0.88, py = math.sin(a) * r * 0.88;
      final tangential = math.max(r * 2 * math.pi / spokes * 0.62, 0.08);
      final horiz = math.sin(a).abs() * tangential + math.cos(a).abs() * r * 0.16;
      final vert = math.cos(a).abs() * tangential + math.sin(a).abs() * r * 0.16;
      _emitSlab(
        p,
        flat ? cx + px : cx,
        flat ? cz : cz + px,
        flat ? horiz : thick,
        flat ? thick : horiz,
        cy + py - vert / 2,
        cy + py + vert / 2,
        rim,
        light,
        pal,
        0.98,
        flash,
      );
    }
    // The paddles, standing out from the rim.
    for (var i = 0; i < spokes ~/ 2; i++) {
      final a = i * 4 * math.pi / spokes;
      final px = math.cos(a) * r * 0.62, py = math.sin(a) * r * 0.62;
      _emitSlab(
        p,
        flat ? cx + px : cx,
        flat ? cz : cz + px,
        flat ? r * 0.5 : thick * 1.5,
        flat ? thick * 1.5 : r * 0.5,
        cy + py - r * 0.09,
        cy + py + r * 0.09,
        wood,
        light,
        pal,
        0.9,
        flash,
      );
    }
    _emitSlab(p, cx, cz, flat ? r * 0.3 : thick * 1.4,
        flat ? thick * 1.4 : r * 0.3, cy - r * 0.15, cy + r * 0.15, wood, light,
        pal, 0.88, flash);
  }

  /// Four sails on a windmill's cap, turning.
  ///
  /// Drawn as flat quads in the plane of the cap rather than as boxes, which is
  /// what lets them sit at any angle — and a windmill whose sails go round is
  /// the single most alive thing in the town.
  void _emitSails(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final r = (y1 - y0) / 2;
    final cy = y0 + r;
    final cx = piece.cx, cz = piece.cz - 0.16;
    const wood = Color(0xFF5A4835);
    final cloth = Color.lerp(const Color(0xFFF6EBD2), pal.stoneWarm, 0.18)!;
    final shade = Color.lerp(cloth, const Color(0xFF8A6E4A), 0.30)!;

    // The wheel turns at the wind's own pace, and freewheels a little when the
    // gust drops, so it never looks like a clock hand.
    final turn = scene.time * (0.55 + 0.75 * _windForce) +
        hash01(piece.seed, 17) * 6.28;

    void blade(double ang, double from, double to, double halfW, Color c,
        double ao) {
      final dx = math.cos(ang), dy = math.sin(ang);
      final nx = -dy * halfW, ny = dx * halfW;
      _quad(
        p,
        V3(cx + dx * from + nx, cy + dy * from + ny, cz),
        V3(cx + dx * to + nx, cy + dy * to + ny, cz),
        V3(cx + dx * to - nx, cy + dy * to - ny, cz),
        V3(cx + dx * from - nx, cy + dy * from - ny, cz),
        _hazeAt(_shade(const V3(0, 0, -1), c, light, pal, ao, flash, 0), p, cx,
                cz, pal)
            .toARGB32(),
      );
    }

    for (var i = 0; i < 4; i++) {
      final a = turn + i * math.pi / 2;
      // The cloth first, then the stock over it, so the frame reads on top.
      blade(a, r * 0.30, r * 0.98, r * 0.20, i.isEven ? cloth : shade, 1.06);
      blade(a, r * 0.06, r * 1.0, r * 0.055, wood, 0.95);
    }
    _emitSlab(p, cx, cz + 0.06, r * 0.28, 0.22, cy - r * 0.14, cy + r * 0.14,
        wood, light, pal, 0.88, flash);
  }

  /// A box given by its middle and size rather than by a piece, for the parts
  /// a landmark is assembled from.
  void _emitSlab(
    Projector p,
    double cx,
    double cz,
    double w,
    double d,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double ao,
    double flash,
  ) {
    final x0 = cx - w / 2, x1 = cx + w / 2;
    final z0 = cz - d / 2, z1 = cz + d / 2;
    final e = p.eye;
    if (p.cameraOf(V3(cx, (y0 + y1) / 2, cz)).z <= p.near) return;

    Color face(V3 n, double k) =>
        _hazeAt(_shade(n, albedo, light, pal, ao * k, flash, 0), p, cx, cz, pal);

    if (e.z > z1) {
      _quad(p, V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1),
          face(const V3(0, 0, 1), 1.0).toARGB32());
    } else if (e.z < z0) {
      _quad(p, V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0),
          face(const V3(0, 0, -1), 1.0).toARGB32());
    }
    if (e.x > x1) {
      _quad(p, V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1),
          face(const V3(1, 0, 0), 0.94).toARGB32());
    } else if (e.x < x0) {
      _quad(p, V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0),
          face(const V3(-1, 0, 0), 0.94).toARGB32());
    }
    if (e.y > y1) {
      _quad(p, V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0), V3(x0, y1, z0),
          face(const V3(0, 1, 0), 1.04).toARGB32());
    }
  }

  /// Makes a piece tappable without it having drawn a box of its own.
  void _registerPickAt(Projector p, TownPiece piece, Size size, double y) {
    final at = p.project(V3(piece.cx, y, piece.cz));
    if (at == null) return;
    if (at.x < 0 || at.x > size.width || at.y < 0 || at.y > size.height) return;
    picks.add(PickTarget(
      piece.index,
      at.x,
      at.y,
      math.max(8.0, p.focal / at.depth * piece.w * 0.4),
      scene.labelledBricks.contains(piece.index),
    ));
  }

  Color _weather(Color c, double decay, int seed) {
    if (decay < 0.02) return c;
    final moss = hash01(seed, 61) < decay * 0.55;
    final t = decay * (moss ? 0.42 : 0.22);
    return Color.lerp(c, const Color(0xFF5C6B4A), t)!;
  }

  /// A box, with only the faces turned towards the camera drawn.
  void _emitBox(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double ao,
    double flash,
    Size size, {
    bool windows = false,
    bool night = false,
    double decay = 0,
  }) {
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    final e = p.eye;
    final mid = V3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
    if (p.cameraOf(mid).z <= p.near) return;

    Color face(V3 n, double k) => _hazeAt(
          _shade(n, albedo, light, pal, ao * k, flash, 0),
          p,
          mid.x,
          mid.z,
          pal,
        );

    final before = _faceCount;
    if (e.z > z1) {
      _quad(p, V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1),
          face(const V3(0, 0, 1), 1.0).toARGB32());
    } else if (e.z < z0) {
      _quad(p, V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0),
          face(const V3(0, 0, -1), 1.0).toARGB32());
    }
    if (e.x > x1) {
      _quad(p, V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1),
          face(const V3(1, 0, 0), 0.94).toARGB32());
    } else if (e.x < x0) {
      _quad(p, V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0),
          face(const V3(-1, 0, 0), 0.94).toARGB32());
    }
    if (e.y > y1) {
      _quad(p, V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0), V3(x0, y1, z0),
          face(const V3(0, 1, 0), 1.04).toARGB32());
    }
    if (_faceCount > before) {
      _registerPick(_facePool[before], piece.index, size);
    }
    if (windows) _emitWindows(p, piece, y0, y1, pal, night, decay);
  }

  /// The windows of one storey, and whether anybody is home.
  ///
  /// This is where the town says how you are doing. A lit window is one
  /// achievement showing from the outside; a whole town of them read in a
  /// single glance is the thing the wall could never do. And when the days
  /// start going by without a piece, they go out one by one — which says
  /// "nobody has been here" far better than moss on a wall ever did.
  void _emitWindows(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Palette pal,
    bool night,
    double decay,
  ) {
    final h = y1 - y0;
    if (h < 0.5) return;
    final wy0 = y0 + h * 0.34, wy1 = y0 + h * 0.74;
    final e = p.eye;
    final s = piece.seed;

    // How much of the town is still lived in. Falls away fast at the end so
    // the last stretch of neglect is the one you actually notice.
    final life = clampD(1 - decay, 0, 1);
    final lifeCurve = life * life * (3 - 2 * life);
    // A window is boarded once the place has been empty a good while, and
    // which ones go first never changes.
    final boarded = decay > 0.30 && hash01(s, 72) < (decay - 0.30) * 1.5;

    void row(bool onZ, double at, double from, double to, double outward) {
      final span = to - from;
      final n = math.max(1, (span / 0.62).floor());
      for (var i = 0; i < n; i++) {
        final c = from + span * (i + 0.5) / n;
        // Each window has its own place in the queue: the same ones go dark
        // first every time, so the town empties from the edges of a habit
        // rather than flickering at random.
        final rank = hash01(s, 70, i);
        final lit = night && rank < 0.72 * lifeCurve;
        final shut = !lit && (boarded || hash01(s, 73, i) < decay * 0.8);
        final colour = lit
            ? Color.lerp(const Color(0xFF7A5C2E), const Color(0xFFFFD79A),
                0.35 + 0.65 * lifeCurve)!
            : Color.lerp(pal.ink, pal.stoneCool, night ? 0.12 : 0.30)!;
        const hw = 0.15;
        final wc = lit
            ? colour
            : _hazeAt(colour, p, piece.cx, piece.cz, pal);

        // A lit window is a light, not a yellow rectangle. Remember where it
        // fell so a glow can be laid over the town once the walls are down.
        if (lit && _lamps.length < 4 * 220) {
          final at = p.project(V3(
            onZ ? c : outward,
            (wy0 + wy1) / 2,
            onZ ? outward : c,
          ));
          if (at != null) {
            final r = p.focal / at.depth * 0.34;
            if (r > 1.2) {
              _lamps
                ..add(at.x)
                ..add(at.y)
                ..add(math.min(r, 34))
                ..add(clampD(1 - decay * 0.7, 0.2, 1.0));
            }
          }
        }

        if (onZ) {
          _quad(
            p,
            V3(c - hw, wy0, outward),
            V3(c + hw, wy0, outward),
            V3(c + hw, wy1, outward),
            V3(c - hw, wy1, outward),
            wc.toARGB32(),
          );
        } else {
          _quad(
            p,
            V3(outward, wy0, c - hw),
            V3(outward, wy0, c + hw),
            V3(outward, wy1, c + hw),
            V3(outward, wy1, c - hw),
            wc.toARGB32(),
          );
        }
        if (!shut) continue;

        // Two planks nailed across an empty window.
        final plank = _hazeAt(
                _weather(const Color(0xFF7A6549), decay, s), p, piece.cx,
                piece.cz, pal)
            .toARGB32();
        for (var k = 0; k < 2; k++) {
          final my = wy0 + (wy1 - wy0) * (k == 0 ? 0.28 : 0.66);
          final th = (wy1 - wy0) * 0.13;
          final out2 = outward + (outward > 0 ? 0.004 : -0.004);
          if (onZ) {
            _quad(p, V3(c - hw * 1.25, my - th, out2),
                V3(c + hw * 1.25, my - th, out2),
                V3(c + hw * 1.25, my + th, out2),
                V3(c - hw * 1.25, my + th, out2), plank);
          } else {
            _quad(p, V3(out2, my - th, c - hw * 1.25),
                V3(out2, my - th, c + hw * 1.25),
                V3(out2, my + th, c + hw * 1.25),
                V3(out2, my + th, c - hw * 1.25), plank);
          }
        }
      }
    }

    if (e.z > piece.z1) {
      row(true, 0, piece.x0 + 0.2, piece.x1 - 0.2, piece.z1 + 0.012);
    } else if (e.z < piece.z0) {
      row(true, 0, piece.x0 + 0.2, piece.x1 - 0.2, piece.z0 - 0.012);
    }
    if (e.x > piece.x1) {
      row(false, 0, piece.z0 + 0.2, piece.z1 - 0.2, piece.x1 + 0.012);
    } else if (e.x < piece.x0) {
      row(false, 0, piece.z0 + 0.2, piece.z1 - 0.2, piece.x0 - 0.012);
    }
  }

  /// A pitched roof: two slopes and two gable ends.
  void _emitGable(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double ao,
    double flash,
  ) {
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
    if (p.cameraOf(V3(mx, (y0 + y1) / 2, mz)).z <= p.near) return;

    Color face(V3 n, double k) => _hazeAt(
          _shade(n, albedo, light, pal, ao * k, flash, 0),
          p,
          mx,
          mz,
          pal,
        );

    final rise = y1 - y0;
    if (piece.alongX) {
      // Ridge runs east to west; the slopes face north and south.
      final run = (z1 - z0) / 2;
      final nA = V3(0, run, rise).normalized;
      final nB = V3(0, run, -rise).normalized;
      _quad(p, V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, mz), V3(x0, y1, mz),
          face(nA, 1.0).toARGB32());
      _quad(p, V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, mz), V3(x1, y1, mz),
          face(nB, 0.92).toARGB32());
      _tri(p, V3(x1, y0, z0), V3(x1, y0, z1), V3(x1, y1, mz),
          face(const V3(1, 0, 0), 0.88).toARGB32());
      _tri(p, V3(x0, y0, z1), V3(x0, y0, z0), V3(x0, y1, mz),
          face(const V3(-1, 0, 0), 0.88).toARGB32());
    } else {
      final run = (x1 - x0) / 2;
      final nA = V3(run, rise, 0).normalized;
      final nB = V3(-run, rise, 0).normalized;
      _quad(p, V3(x1, y0, z0), V3(x1, y0, z1), V3(mx, y1, z1), V3(mx, y1, z0),
          face(nA, 1.0).toARGB32());
      _quad(p, V3(x0, y0, z1), V3(x0, y0, z0), V3(mx, y1, z0), V3(mx, y1, z1),
          face(nB, 0.92).toARGB32());
      _tri(p, V3(x0, y0, z1), V3(x1, y0, z1), V3(mx, y1, z1),
          face(const V3(0, 0, 1), 0.88).toARGB32());
      _tri(p, V3(x1, y0, z0), V3(x0, y0, z0), V3(mx, y1, z0),
          face(const V3(0, 0, -1), 0.88).toARGB32());
    }
  }

  /// A spire: four faces to a point.
  void _emitPyramid(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Color albedo,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
    final apex = V3(mx, y1, mz);
    if (p.cameraOf(V3(mx, (y0 + y1) / 2, mz)).z <= p.near) return;
    final rise = y1 - y0;

    void side(V3 a, V3 b, V3 n, double k) {
      _tri(
        p,
        a,
        b,
        apex,
        _hazeAt(_shade(n.normalized, albedo, light, pal, k, flash, 0), p, mx, mz,
                pal)
            .toARGB32(),
      );
    }

    side(V3(x0, y0, z1), V3(x1, y0, z1), V3(0, (z1 - z0) / 2, rise), 1.0);
    side(V3(x1, y0, z0), V3(x0, y0, z0), V3(0, (z1 - z0) / 2, -rise), 0.9);
    side(V3(x1, y0, z1), V3(x1, y0, z0), V3(rise, (x1 - x0) / 2, 0), 0.95);
    side(V3(x0, y0, z0), V3(x0, y0, z1), V3(-rise, (x1 - x0) / 2, 0), 0.95);
  }

  void _tri(Projector p, V3 a, V3 b, V3 c, int color) {
    final pts = [a, b, c];
    for (var i = 0; i < 3; i++) {
      final cp = p.cameraOf(pts[i]);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    _emit(p, _clipA, 3, color);
  }

  /// The name of each landmark the town has finished.
  void _drawTownLabels(
    Canvas canvas,
    Projector p,
    Size size,
    TownLayout town,
  ) {
    // From far enough back the valley is about which town is which, not which
    // building is which. The landmark names stand down for the town signs.
    if (scene.towns.length > 1 && scene.camera.distance > 95) return;
    // Nearest first, so when two names collide it is the one further away that
    // gives up its place.
    final show = <(double, Offset2, String, double)>[];
    for (final b in town.buildings) {
      if (!b.isLandmark || !b.finished) continue;
      if (scene.placed < b.firstPiece + b.cost) continue;
      final at = p.project(V3(b.cx, b.peakY + 0.5, b.cz));
      if (at == null) continue;
      if (at.x < -120 || at.x > size.width + 120) continue;
      // The one just finished comes in last so nothing can push it aside, and
      // rises into place rather than blinking on.
      final pop = b.index == scene.finished
          ? clampD(scene.finishedAge / 0.55, 0, 1)
          : 1.0;
      show.add((b.index == scene.finished ? -1.0 : at.depth, at,
          b.name.toUpperCase(), pop));
    }
    show.sort((a, b) => a.$1.compareTo(b.$1));
    final taken = <Rect>[];
    for (final row in show) {
      _drawLabel(canvas, row.$2, row.$3, size, taken: taken, pop: row.$4);
    }
  }

  Color _shade(V3 n, Color albedo, V3 light, Palette pal, double ao,
      double flash, double repairGlow) {
    final ndl = math.max(0.0, n.dot(light));
    final skyTerm = 0.5 + 0.5 * n.y;
    // Stone in shadow is still stone: the sky term is modulated by the albedo
    // so unlit faces stay pale limestone instead of collapsing to black.
    final k = (0.44 + 0.58 * ndl + 0.26 * skyTerm) * ao * pal.contrast;
    var r = albedo.r * k + pal.sun.r * ndl * 0.06 + pal.skyLight.r * skyTerm * 0.045;
    var g = albedo.g * k + pal.sun.g * ndl * 0.06 + pal.skyLight.g * skyTerm * 0.045;
    var b = albedo.b * k + pal.sun.b * ndl * 0.06 + pal.skyLight.b * skyTerm * 0.045;
    if (flash > 0) {
      r = lerpD(r, 1.0, flash * 0.85);
      g = lerpD(g, 0.97, flash * 0.85);
      b = lerpD(b, 0.82, flash * 0.85);
    }
    if (repairGlow > 0) {
      r = lerpD(r, 1.0, repairGlow * 0.55);
      g = lerpD(g, 0.92, repairGlow * 0.5);
      b = lerpD(b, 0.68, repairGlow * 0.45);
    }
    return Color.fromARGB(255, _ch(r), _ch(g), _ch(b));
  }

  // ---------------------------------------------------------------- flush

  void _flush(Canvas canvas) {
    if (_faceCount == 0) return;
    final faces = _facePool.sublist(0, _faceCount);
    faces.sort((a, b) => b.depth.compareTo(a.depth));
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final f in faces) {
      _scratch.reset();
      _scratch.moveTo(f.pts[0], f.pts[1]);
      for (var i = 1; i < f.n; i++) {
        _scratch.lineTo(f.pts[i * 2], f.pts[i * 2 + 1]);
      }
      _scratch.close();
      paint.color = Color(f.color);
      canvas.drawPath(_scratch, paint);
    }
  }

  // ------------------------------------------------------------- extras

  /// A name set straight on the sky with a halo, and a hairline under it to tie
  /// it to the thing it names. No filled pill: that was the last of the heavy
  /// white chrome.
  void _drawLabel(
    Canvas canvas,
    Offset2 top,
    String name,
    Size size, {
    double? at,
    List<Rect>? taken,
    double pop = 1,
  }) {
    final depth = at ?? top.depth;
    // How far a name carries depends on how far back the camera has gone: from
    // across the valley the town should still say what its landmarks are.
    final far = math.max(24.0, scene.camera.distance * 1.15);
    final fade = clampD(1 - (depth - far) / (far * 0.75), 0, 1) * pop;
    if (fade <= 0.02) return;
    final dark = _isDarkSky();
    final glow = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: (dark ? Colors.white : scene.palette.ink)
              .withValues(alpha: 0.88 * fade),
          fontSize: 9.5,
          letterSpacing: 2.6,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: (dark ? Colors.black : const Color(0xFF3A3426))
                  .withValues(alpha: (dark ? 0.6 : 0.34) * fade),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The camera buttons live down the right-hand edge; a name that lands
    // under them is unreadable, so it slides left far enough to clear them.
    var cx = top.x;
    final inButtons = top.y > 80 && top.y < 250;
    final right = size.width - (inButtons ? 74 : 6) - glow.width / 2;
    final left = 6 + glow.width / 2;
    if (right > left) cx = clampD(cx, left, right);

    // A name that has just been earned rises into place instead of appearing.
    final lift = (1 - pop) * 16;
    final origin = Offset(cx - glow.width / 2, top.y - glow.height / 2 + lift);

    // A town has a lot of names in it. Two of them written across each other
    // are worth less than one of them alone, so a name that would land on one
    // already written simply is not written.
    if (taken != null) {
      final box = Rect.fromLTWH(
          origin.dx - 6, origin.dy - 3, glow.width + 12, glow.height + 14);
      for (final other in taken) {
        if (box.overlaps(other)) return;
      }
      taken.add(box);
    }

    glow.paint(canvas, origin);

    // A hairline under it, to tie the name to the thing it names.
    final w = glow.width * 0.5;
    canvas.drawLine(
      Offset(cx - w / 2, origin.dy + glow.height + 5),
      Offset(cx + w / 2, origin.dy + glow.height + 5),
      Paint()
        ..strokeWidth = 1
        ..color = (dark ? Colors.white : scene.palette.ink)
            .withValues(alpha: 0.30 * fade),
    );
  }

  bool _isDarkSky() {
    final c = scene.palette.skyHorizon;
    return (c.r * 0.3 + c.g * 0.55 + c.b * 0.15) < 0.45;
  }

  // ---------------------------------------------------------- stone marks

  // ------------------------------------------------------------- particles

  void _drawParticles(Canvas canvas, Projector p) {
    final pal = scene.palette;
    final paint = Paint();
    for (final part in scene.effects.live) {
      final pt = p.project(V3(part.x, part.y, part.z));
      if (pt == null) continue;
      final life = (part.life / part.maxLife).clamp(0.0, 1.0);
      final r = part.size * p.focal / pt.depth;
      if (r < 0.3) continue;
      switch (part.kind) {
        case ParticleKind.dust:
          paint
            ..color = Color.lerp(pal.stoneWarm, pal.haze, 0.4)!
                .withValues(alpha: life * 0.42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (2.2 - life), paint);
          paint.maskFilter = null;
        case ParticleKind.chip:
          paint.color = pal.stoneCool.withValues(alpha: life);
          canvas.save();
          canvas.translate(pt.x, pt.y);
          canvas.rotate(part.angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.4), paint);
          canvas.restore();
        case ParticleKind.spark:
          paint.color = Color.lerp(pal.accent, Colors.white, 0.4)!
              .withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 1.3, paint);
        case ParticleKind.gold:
          paint.color = const Color(0xFFF2C25B)
              .withValues(alpha: life * life * 0.85);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 0.9, paint);
        case ParticleKind.ember:
          paint.color = Color.lerp(const Color(0xFFFF8A3D), const Color(0xFFFFD79A), life)!
              .withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.moteRepair:
          paint.color = const Color(0xFFBFE8D0).withValues(alpha: life * 0.8);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.smoke:
          // Thickest just after it leaves the flue, then thinning as it spreads
          // and takes the colour of the air it is drifting through.
          final age = 1 - life;
          final puff = Color.lerp(
              Color.lerp(pal.stoneCool, pal.ink, 0.22)!, pal.haze, age * 0.8)!;
          paint
            ..color = puff.withValues(alpha: life * life * 0.30)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + age * 6);
          canvas.drawCircle(
              Offset(pt.x, pt.y), r * (1.0 + age * 3.2), paint);
          paint.maskFilter = null;
        case ParticleKind.glint:
          final k = math.sin(life * math.pi);
          paint
            ..color = Color.lerp(pal.sun, Colors.white, 0.5)!
                .withValues(alpha: k * 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (0.8 + k), paint);
          paint.maskFilter = null;
      }
    }
  }

  // ----------------------------------------------------------------- ghost

  void _drawAtmosphere(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    final decay = 1 - scene.integrity;
    if (decay > 0.05) {
      // A town left alone does not fog over, it goes cold and quiet. Grey mist
      // reads as bad visibility; a cold, dim town reads as nobody home.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.lerp(pal.ink, const Color(0xFF3E4758), 0.55)!
              .withValues(alpha: 0.06 + decay * 0.20),
      );
    }
    // A soft vignette to hold the eye on the town.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.52),
          size.longestSide * 0.72,
          [Colors.transparent, pal.ink.withValues(alpha: 0.26)],
          [0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant TownPainter old) => true;
}
