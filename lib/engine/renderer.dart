import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/milestones.dart';
import '../fx/effects.dart';
import '../model/appearance.dart';
import 'camera.dart';
import 'city.dart';
import 'layout.dart';
import 'landscape.dart';
import 'palette.dart';
import 'stone.dart';

int _ch(double v) {
  final i = (v * 255.0).round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
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

class WallScene {
  WallScene({
    required this.layout,
    required this.placed,
    required this.palette,
    required this.camera,
    required this.integrity,
    required this.time,
    required this.effects,
    required this.labelledBricks,
    required this.structureNames,
    this.fx,
    this.repairSweep,
    this.detailBudget = 300,
    this.coarseBudget = 2600,
    this.mortar = MortarLook.seca,
    this.city,
    this.selectedBrick,
    this.charge = 0,
  });

  final WallLayout layout;
  final int placed;
  final Palette palette;
  final OrbitCamera camera;
  final double integrity;
  final double time;
  final EffectSystem effects;

  /// Bricks the person wrote a note on.
  final Set<int> labelledBricks;
  final Map<int, String> structureNames;

  final PlacementFx? fx;

  /// x position of the travelling repair wave, sweeping from the newest stone
  /// back down the wall. Null when nothing is being repaired.
  final double? repairSweep;

  final int detailBudget;

  /// How many further stones are drawn as plain blocks beyond the detailed
  /// band. They keep their size, colour and joints, only not their chipped
  /// corners — which at that distance are under a pixel anyway.
  final int coarseBudget;

  /// How the masonry is pointed.
  final MortarLook mortar;

  /// When set, the achievements are drawn as a town rather than as a wall.
  final CityLayout? city;

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
class WallPainter extends CustomPainter {
  WallPainter(this.scene, this.picks);

  final WallScene scene;
  final List<PickTarget> picks;

  static final List<_Face> _facePool = List.generate(16000, (_) => _Face());
  static final StoneMesh _mesh = StoneMesh(24);
  static final Float64List _clipA = Float64List(96);
  static final Float64List _clipB = Float64List(96);
  static final Path _scratch = Path();

  int _faceCount = 0;

  _Face? _nextFace() {
    if (_faceCount >= _facePool.length) return null;
    return _facePool[_faceCount++];
  }

  @override
  void paint(Canvas canvas, Size size) {
    picks.clear();
    _faceCount = 0;

    final cam = scene.camera;
    // Cover a continuous stretch of wall with the stones the budget allows,
    // and let the distant silhouette take over beyond it.
    final l0 = scene.layout;
    final density = l0.length > 0.5 ? scene.placed / l0.length : 4.0;
    final perSide = 2 * math.max(1.0, density);
    cam.detailRadius = clampD(scene.detailBudget / perSide, 6, 260);
    // Beyond the detailed band the stones keep going as plain blocks. Only
    // past *this* does the wall become its own silhouette — which on any wall
    // anyone will actually build is off the end of it.
    cam.coarseRadius = clampD(
      (scene.detailBudget + scene.coarseBudget) / perSide,
      cam.detailRadius,
      900,
    );
    final p = cam.projector(size.width, size.height, scene.time);
    final horizonY = _horizonY(p, size);

    final city = scene.city;
    if (city != null) {
      _drawSky(canvas, size, p, horizonY);
      _drawGround(canvas, size, horizonY);
      _drawRanges(canvas, p, size, horizonY);
      _drawCityGround(canvas, p, city);
      _collectCity(p, size, city);
      _flush(canvas);
      _drawCityLabels(canvas, p, size, city);
      _drawParticles(canvas, p);
      _drawAtmosphere(canvas, size, horizonY);
      return;
    }

    _drawSky(canvas, size, p, horizonY);
    _drawGround(canvas, size, horizonY);
    _drawRanges(canvas, p, size, horizonY);
    _drawTerrain(canvas, p, size);
    _drawShadow(canvas, p);

    _collectFarWall(p);
    _collectStones(p, size);

    _flush(canvas);

    _drawStructureExtras(canvas, p, size);
    _drawStoneMarks(canvas, p, size);
    _drawParticles(canvas, p);
    _drawGhost(canvas, p);
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
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, hy),
          Offset(0, size.height),
          [pal.groundFar, pal.ground],
        ),
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

  void _drawTerrain(Canvas canvas, Projector p, Size size) {
    final pal = scene.palette;
    final base = scene.camera.travel;
    final paint = Paint();
    for (var i = 0; i < 22; i++) {
      // Anchored to a coarse grid along the wall so patches hold still as the
      // camera travels, instead of swimming with it.
      final cell = (base / 9).floor() + i - 11;
      final x = cell * 9.0 + hashRange(-3.5, 3.5, cell, 5);
      final side = hash01(cell, 6) < 0.5 ? -1.0 : 1.0;
      final z = side * hashRange(2.4, 26.0, cell, 7);
      final r = hashRange(1.6, 5.4, cell, 8);

      final c = p.project(V3(x, 0.002, z));
      if (c == null) continue;
      final ex = p.project(V3(x + r, 0.002, z));
      final ez = p.project(V3(x, 0.002, z + r));
      if (ex == null || ez == null) continue;
      final rx = (ex.x - c.x).abs().clamp(2.0, size.width);
      final ry = ((ez.y - c.y).abs() + (ex.y - c.y).abs() * 0.5)
          .clamp(1.0, size.height);
      if (rx < 3 || c.x < -rx * 2 || c.x > size.width + rx * 2) continue;

      final warm = hash01(cell, 9) < 0.45;
      final tint = warm
          ? Color.lerp(pal.ground, pal.groundFar, 0.55)!
          : Color.lerp(pal.ground, pal.ink, 0.30)!;
      final fade = 1 - math.exp(-c.depth * 0.02);
      paint.shader = ui.Gradient.radial(
        Offset(c.x, c.y),
        math.max(rx, ry),
        [
          tint.withValues(alpha: 0.30 * (1 - fade)),
          tint.withValues(alpha: 0.0),
        ],
      );
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.scale(1, ry / math.max(rx, ry));
      canvas.translate(-c.x, -c.y);
      canvas.drawCircle(Offset(c.x, c.y), math.max(rx, ry), paint);
      canvas.restore();
      paint.shader = null;
    }
  }

  /// The wall's shadow, laid on the ground away from the light.
  void _drawShadow(Canvas canvas, Projector p) {
    final l = scene.layout;
    if (l.profileCore.isEmpty) return;
    final pal = scene.palette;
    final light = pal.lightDir;
    if (light.y < 0.05) return;
    final stretch = clampD(1.0 / light.y, 0.6, 2.2);
    final ox = -light.x * stretch;
    final oz = -light.z * stretch;

    final path = Path();
    var started = false;
    final n = l.profileCore.length;
    final lo = _bucketLo(), hi = _bucketHi();
    // Far edge of the shadow.
    for (var i = lo; i <= hi && i < n; i++) {
      final top = l.profileCore[i];
      if (top <= 0) continue;
      final d = l.profileDepth[i];
      final x = i * l.profileStep;
      final pt = p.project(V3(x + ox * top, 0.004, -d + oz * top));
      if (pt == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(pt.x, pt.y);
        started = true;
      } else {
        path.lineTo(pt.x, pt.y);
      }
    }
    // Near edge, coming back.
    for (var i = math.min(hi, n - 1); i >= lo; i--) {
      final top = l.profileCore[i];
      if (top <= 0) continue;
      final d = l.profileDepth[i];
      final x = i * l.profileStep;
      final pt = p.project(V3(x, 0.004, d));
      if (pt == null) continue;
      path.lineTo(pt.x, pt.y);
    }
    if (!started) return;
    path.close();
    final strength = scene.integrity.clamp(0.55, 1.0);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromARGB(_ch(0.24 * strength), 38, 33, 22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // An ambient contact shadow hugging both sides of the footing. The
    // directional shadow can fall entirely behind the wall depending on where
    // the sun is; without this the wall reads as floating.
    final contact = Path();
    var open = false;
    for (var i = lo; i <= hi && i < n; i++) {
      if (l.profileCore[i] <= 0) {
        open = false;
        continue;
      }
      final d = l.profileDepth[i] + 0.20;
      final pt = p.project(V3(i * l.profileStep, 0.003, d));
      if (pt == null) {
        open = false;
        continue;
      }
      if (!open) {
        contact.moveTo(pt.x, pt.y);
        open = true;
      } else {
        contact.lineTo(pt.x, pt.y);
      }
    }
    for (var i = math.min(hi, n - 1); i >= lo; i--) {
      if (l.profileCore[i] <= 0) continue;
      final d = l.profileDepth[i] + 0.20;
      final pt = p.project(V3(i * l.profileStep, 0.003, -d));
      if (pt == null) continue;
      contact.lineTo(pt.x, pt.y);
    }
    if (open) {
      contact.close();
      canvas.drawPath(
        contact,
        Paint()
          ..color = Color.fromARGB(_ch(0.30 * strength), 30, 26, 17)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  int _bucketLo() {
    final l = scene.layout;
    final r = scene.camera.coarseRadius * 1.3;
    return ((scene.camera.travel - r) / l.profileStep)
        .floor()
        .clamp(0, math.max(0, l.profileCore.length - 1));
  }

  int _bucketHi() {
    final l = scene.layout;
    final r = scene.camera.coarseRadius * 1.3;
    return ((scene.camera.travel + r) / l.profileStep)
        .ceil()
        .clamp(0, math.max(0, l.profileCore.length - 1));
  }

  // ------------------------------------------------------------- far wall

  /// Beyond the detail radius the wall becomes its own silhouette, thinning
  /// into the haze. On a wall that has grown long this is most of what you see,
  /// so it is lit with the same model as the stones and keeps its battlements —
  /// it has to read as the same wall carrying on, not as a bank of earth.
  void _collectFarWall(Projector p) {
    final l = scene.layout;
    if (l.profileTop.isEmpty) return;
    final pal = scene.palette;
    final cam = scene.camera;
    final light = pal.lightDir;
    final near = math.max(2.0, cam.coarseRadius - l.profileStep * 3);
    final step = l.profileStep;
    final n = l.profileTop.length;
    final decay = 1.0 - scene.integrity;

    for (var i = 0; i < n - 1; i++) {
      final x0 = i * step;
      final x1 = x0 + step;
      // Start just inside the detailed range: the silhouette sits a little
      // thinner than the stones, so the overlap hides the seam behind them.
      if ((x0 - cam.travel).abs() < near && (x1 - cam.travel).abs() < near) {
        continue;
      }
      final core = l.profileCore[i];
      final tip = l.profileTop[i];
      if (core <= 0.01) continue;
      final d = math.max(0.10, l.profileDepth[i] * 0.93);

      final dx = (x0 + x1) / 2 - p.eye.x;
      final dz = p.eye.z;
      final dist = math.max(0.001, math.sqrt(dx * dx + dz * dz));
      final haze = 1 - math.exp(-dist * 0.011);

      // Enough albedo variation from bucket to bucket to suggest coursing.
      var albedo = Color.lerp(
        pal.stoneCool,
        pal.stoneWarm,
        0.30 + 0.46 * hash01(i, 61),
      )!;
      if (decay > 0.02 && hash01(i, 62) < decay * 0.6) {
        albedo = Color.lerp(albedo, const Color(0xFF5C6B4A), 0.22 + decay * 0.3)!;
      }

      Color band(V3 normal, double ao) {
        final c = _shade(normal, albedo, light, pal, ao, 0, 0);
        return Color.lerp(c, pal.haze, haze * 0.92)!;
      }

      final front = p.eye.z >= 0 ? d : -d;
      final frontN = V3(0, 0, p.eye.z >= 0 ? 1 : -1);

      // The solid mass.
      _quad(p, V3(x0, 0, front), V3(x1, 0, front), V3(x1, core, front),
          V3(x0, core, front), band(frontN, 0.80).toARGB32());
      _quad(p, V3(x0, core, d), V3(x1, core, d), V3(x1, core, -d),
          V3(x0, core, -d), band(const V3(0, 1, 0), 0.95).toARGB32());

      // The battlements on top, only where there actually is a merlon.
      if (tip > core + 0.06 && dist < 65) {
        final md = d * 0.82;
        final mf = p.eye.z >= 0 ? md : -md;
        _quad(p, V3(x0, core, mf), V3(x1, core, mf), V3(x1, tip, mf),
            V3(x0, tip, mf), band(frontN, 0.88).toARGB32());
        _quad(p, V3(x0, tip, md), V3(x1, tip, md), V3(x1, tip, -md),
            V3(x0, tip, -md), band(const V3(0, 1, 0), 1.0).toARGB32());
      }
    }
  }

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

  void _collectStones(Projector p, Size size) {
    final l = scene.layout;
    final cam = scene.camera;
    final pal = scene.palette;
    final light = pal.lightDir;
    final decay = 1.0 - scene.integrity;
    final radius = cam.detailRadius;
    final profiles = StoneProfiles.instance;
    final look = scene.mortar;
    final mortarBase = Color.lerp(pal.mortar, pal.stone, look.tint)!;
    final fx = scene.fx;

    // Nearest-first so the detail budget is spent where the eye is.
    final order = <int>[];
    for (var i = 0; i < scene.placed && i < l.slots.length; i++) {
      final s = l.slots[i];
      if ((s.x - cam.travel).abs() > cam.coarseRadius) continue;
      order.add(i);
    }
    order.sort((a, b) {
      final da = (l.slots[a].x - cam.travel).abs();
      final db = (l.slots[b].x - cam.travel).abs();
      return da.compareTo(db);
    });
    final take = math.min(order.length, scene.detailBudget);
    final coarse =
        math.min(order.length, scene.detailBudget + scene.coarseBudget);

    for (var k = 0; k < take; k++) {
      final idx = order[k];
      final slot = l.slots[idx];
      final isFalling = fx != null && fx.brickIndex == idx;

      var yOff = 0.0, rot = 0.0, sx = 1.0, sy = 1.0, flash = 0.0;
      if (isFalling) {
        yOff = fx.yOffset;
        rot = fx.rotation;
        final sq = fx.squash;
        sx = sq.$1;
        sy = sq.$2;
        flash = fx.flash;
      }

      // Weathering: erosion nibbles at the stones, worst on the exposed top.
      final exposure = clampD(slot.y / 2.2, 0.25, 1.0);
      var erosion = decay * exposure;
      // The repair wave runs from the stone just laid back along the wall,
      // healing everything it has already passed.
      final sweep = scene.repairSweep;
      var repairGlow = 0.0;
      if (sweep != null) {
        final d = (slot.x - sweep).abs();
        if (slot.x > sweep) {
          erosion = 0;
        } else if (d < 1.6) {
          erosion *= d / 1.6;
        }
        repairGlow = math.max(0.0, 1 - d / 1.3);
      }

      // Cheap ambient occlusion: deep courses and recesses sit in shade.
      var ao = 0.58 + 0.42 * smoothstep(-0.2, 1.7, slot.y);
      if (slot.kind == SlotKind.recess) ao *= 0.62;
      final capped = _hasWallAbove(l, slot);

      final profile = profiles.forSeed(slot.seed);
      _mesh.build(
        slot,
        profile,
        yOffset: yOff,
        rotation: rot,
        scaleX: sx,
        scaleY: sy,
        erosion: erosion,
        mirror: (slot.seed & 0x1000) != 0,
        joint: look.joint,
        relief: look.relief,
      );
      _mesh.toCamera(p);

      final albedo = _albedoFor(slot, pal, erosion);
      final n = _mesh.n;

      // The mortar core this stone is set into: a solid box, very slightly
      // larger than the slot so it fills the joints, and slightly thinner so
      // the stone's own irregular face still stands proud of it.
      //
      // It has to be a solid and not a pair of flat plates. Plates leave the
      // wall hollow the moment you look at it from above or from behind, and
      // no amount of sorting fixes that — you are simply looking through a
      // joint at nothing. Its faces are all pinned behind the *furthest*
      // corner of its own stone so the core can never paint over the stone,
      // whichever side of the wall the camera has orbited to.
      var farDepth = 0.0;
      for (var i = 0; i < n; i++) {
        final f = _mesh.camFront[i * 3 + 2];
        final b = _mesh.camBack[i * 3 + 2];
        if (f > farDepth) farDepth = f;
        if (b > farDepth) farDepth = b;
      }
      farDepth += 0.02;
      // Sized to the slot exactly. Slots tile, so the joints are still backed;
      // growing it even slightly made the core stand proud of the stone along
      // every exposed edge, and that dark rim is what made each stone read as
      // an open crate rather than a block set into a wall.
      _emitCore(
        p,
        x0: slot.x - slot.w / 2,
        x1: slot.x + slot.w / 2,
        y0: slot.y - slot.h / 2,
        y1: slot.y + slot.h / 2,
        z0: slot.zCenter - slot.halfDepth + look.recess,
        z1: slot.zCenter + slot.halfDepth - look.recess,
        albedo: mortarBase,
        light: light,
        pal: pal,
        ao: ao * 0.92,
        repairGlow: repairGlow * 0.4,
        depth: farDepth,
        capped: capped,
      );

      _emitPrism(p, slot, albedo, light, pal, ao,
          flash: flash,
          repairGlow: repairGlow,
          capped: capped,
          pickInto: size,
          pickIndex: idx);
    }

    // Past the detailed band every stone is still a stone: the same block, in
    // the same place, its own colour, with its own joints around it — just
    // without the chipped corners, which out there are under a pixel wide. It
    // used to become a smooth ribbon at this distance, and the seam where the
    // masonry stopped was the most conspicuous thing on the wall.
    for (var k = take; k < coarse; k++) {
      final idx = order[k];
      final slot = l.slots[idx];
      final exposure = clampD(slot.y / 2.2, 0.25, 1.0);
      final erosion = decay * exposure;
      final ao = 0.58 + 0.42 * smoothstep(-0.2, 1.7, slot.y);
      _emitBlock(
        p,
        slot,
        _albedoFor(slot, pal, erosion),
        mortarBase,
        light,
        pal,
        ao,
        look,
        size,
        idx,
        _hasWallAbove(l, slot),
      );
    }

    _emitBuried(p, l, cam, radius, mortarBase, light, pal);
  }

  /// Blocks the crenellation gaps of every course the wall has grown past.
  ///
  /// Emitted in short chunks rather than as one long box: the painter's
  /// algorithm sorts by a single depth per face, and a face running the whole
  /// length of the wall has no single sensible depth.
  void _emitBuried(
    Projector p,
    WallLayout l,
    OrbitCamera cam,
    double radius,
    Color mortar,
    V3 light,
    Palette pal,
  ) {
    if (l.buried.isEmpty) return;
    const chunk = 0.62;
    for (final band in l.buried) {
      if (band.x1 < cam.travel - radius || band.x0 > cam.travel + radius) {
        continue;
      }
      var x = math.max(band.x0, cam.travel - radius);
      final xTo = math.min(band.x1, cam.travel + radius);
      final ao = 0.58 + 0.42 * smoothstep(-0.2, 1.7, band.y0);
      while (x < xTo) {
        final x1 = math.min(x + chunk, xTo);
        final mid = V3((x + x1) / 2, (band.y0 + band.y1) / 2, 0);
        _emitCore(
          p,
          x0: x,
          x1: x1,
          y0: band.y0,
          y1: band.y1,
          z0: -band.halfDepth,
          z1: band.halfDepth,
          albedo: mortar,
          light: light,
          pal: pal,
          ao: ao * 0.88,
          repairGlow: 0,
          depth: p.cameraOf(mid).z + band.halfDepth,
        );
        x = x1;
      }
    }
  }

  /// Emits every visible face of the prism currently in [_mesh].
  ///
  /// Shared by the wall's stones and by the boulders lying around it, so both
  /// are lit and sorted by exactly the same rules.
  void _emitPrism(
    Projector p,
    StoneSlot slot,
    Color albedo,
    V3 light,
    Palette pal,
    double ao, {
    double flash = 0,
    double repairGlow = 0,
    bool capped = false,
    Size? pickInto,
    int pickIndex = -1,
  }) {
    // Anything straddling the near plane clips into a sliver whose average
    // depth reads as "extremely close", which sorts it in front of the entire
    // scene. Nothing that near is worth drawing anyway.
    final centre = p.cameraOf(V3(slot.x, slot.y, slot.zCenter));
    if (centre.z < slot.halfDepth + slot.w * 0.5 + p.near) return;

    final n = _mesh.n;
    // --- front and back faces
    for (var side = 0; side < 2; side++) {
      final cam3 = side == 0 ? _mesh.camFront : _mesh.camBack;
      final normal = V3(0, 0, side == 0 ? 1 : -1);
      final toEye = V3(
        p.eye.x - slot.x,
        p.eye.y - slot.y,
        p.eye.z - (slot.zCenter + (side == 0 ? slot.halfDepth : -slot.halfDepth)),
      );
      if (normal.dot(toEye) <= 0) continue;
      for (var i = 0; i < n; i++) {
        final j = side == 0 ? i : (n - 1 - i);
        _clipA[i * 3] = cam3[j * 3];
        _clipA[i * 3 + 1] = cam3[j * 3 + 1];
        _clipA[i * 3 + 2] = cam3[j * 3 + 2];
      }
      final c = _shade(normal, albedo, light, pal, ao, flash, repairGlow);
      final before = _faceCount;
      _emit(p, _clipA, n, _haze(c, p, slot.x, pal).toARGB32());
      if (side == 0 && pickInto != null && _faceCount > before) {
        _registerPick(_facePool[before], pickIndex, pickInto);
      }
    }

    // --- side faces, which are also the tops the light catches
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final ax = _mesh.front[i * 3], ay = _mesh.front[i * 3 + 1], az = _mesh.front[i * 3 + 2];
      final bx = _mesh.front[j * 3], by = _mesh.front[j * 3 + 1], bz = _mesh.front[j * 3 + 2];
      final cx = _mesh.back[j * 3], cy2 = _mesh.back[j * 3 + 1], cz = _mesh.back[j * 3 + 2];
      final dx = _mesh.back[i * 3], dy = _mesh.back[i * 3 + 1], dz = _mesh.back[i * 3 + 2];

      // The profile winds counter-clockwise seen from the front, so the
      // outward normal of each side face is (into-the-wall) x (along-edge).
      final e1 = V3(bx - ax, by - ay, bz - az);
      final e2 = V3(dx - ax, dy - ay, dz - az);
      final nrm = e2.cross(e1).normalized;
      final mx = (ax + bx + cx + dx) * 0.25;
      final my = (ay + by + cy2 + dy) * 0.25;
      final mz = (az + bz + cz + dz) * 0.25;
      if (nrm.dot(V3(p.eye.x - mx, p.eye.y - my, p.eye.z - mz)) <= 0) continue;

      _clipA[0] = _mesh.camFront[i * 3];
      _clipA[1] = _mesh.camFront[i * 3 + 1];
      _clipA[2] = _mesh.camFront[i * 3 + 2];
      _clipA[3] = _mesh.camFront[j * 3];
      _clipA[4] = _mesh.camFront[j * 3 + 1];
      _clipA[5] = _mesh.camFront[j * 3 + 2];
      _clipA[6] = _mesh.camBack[j * 3];
      _clipA[7] = _mesh.camBack[j * 3 + 1];
      _clipA[8] = _mesh.camBack[j * 3 + 2];
      _clipA[9] = _mesh.camBack[i * 3];
      _clipA[10] = _mesh.camBack[i * 3 + 1];
      _clipA[11] = _mesh.camBack[i * 3 + 2];

      // A stone with wall on top of it is looking up into a crevice, not at
      // the sky. Left lit, every course showed a bright white ledge along its
      // top edge and the wall read as a stack of loose slabs instead of a
      // face — which is most of what made the mortar look bad.
      final shade = capped && nrm.y > 0.30
          ? lerpD(1.0, 0.34, smoothstep(0.30, 0.85, nrm.y))
          : 1.0;
      final c = _shade(nrm, albedo, light, pal, ao * shade, flash, repairGlow);
      _emit(p, _clipA, 4, _haze(c, p, slot.x, pal).toARGB32());
    }
  }

  /// The solid mortar box behind one stone. Only the faces actually turned
  /// towards the camera are emitted.
  void _emitCore(
    Projector p, {
    required double x0,
    required double x1,
    required double y0,
    required double y1,
    required double z0,
    required double z1,
    required Color albedo,
    required V3 light,
    required Palette pal,
    required double ao,
    required double repairGlow,
    required double depth,
    bool capped = false,
  }) {
    if (z1 <= z0) {
      final mid = (z0 + z1) / 2;
      z0 = mid - 0.01;
      z1 = mid + 0.01;
    }
    final e = p.eye;
    const debugCore = bool.fromEnvironment('DEBUG_CORE');
    int col(V3 normal, double k) => debugCore
        ? const Color(0xFFFF00AA).toARGB32()
        : _haze(
            _shade(normal, albedo, light, pal, ao * k, 0, repairGlow),
            p,
            (x0 + x1) / 2,
            pal,
          ).toARGB32();

    if (e.z > z1) {
      _quad(p, V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1),
          col(const V3(0, 0, 1), 1.0), depthOverride: depth);
    } else if (e.z < z0) {
      _quad(p, V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0),
          col(const V3(0, 0, -1), 1.0), depthOverride: depth);
    }
    if (e.y > y1) {
      _quad(p, V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0), V3(x0, y1, z0),
          col(const V3(0, 1, 0), capped ? 0.36 : 1.05), depthOverride: depth);
    } else if (e.y < y0) {
      _quad(p, V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1),
          col(const V3(0, -1, 0), 0.75), depthOverride: depth);
    }
    if (e.x > x1) {
      _quad(p, V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1),
          col(const V3(1, 0, 0), 0.92), depthOverride: depth);
    } else if (e.x < x0) {
      _quad(p, V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0),
          col(const V3(-1, 0, 0), 0.92), depthOverride: depth);
    }
  }

  /// Whether the wall carries on above this stone.
  ///
  /// Read off the coarse top profile rather than the layout's own courses,
  /// because a landmark's stones do not sit on courses at all. It takes the
  /// *lowest* reading across the stone's span, so a walkway stone with sky
  /// showing between two merlons still catches the light, while a stone with
  /// wall over the whole of it does not.
  bool _hasWallAbove(WallLayout l, StoneSlot slot) {
    if (l.profileTop.isEmpty) return false;
    final last = l.profileTop.length - 1;
    final i0 = (slot.left / l.profileStep).floor().clamp(0, last);
    final i1 = (slot.right / l.profileStep).ceil().clamp(0, last);
    var above = double.infinity;
    for (var i = i0; i <= i1; i++) {
      if (l.profileTop[i] < above) above = l.profileTop[i];
    }
    return above > slot.top + 0.06;
  }

  /// One stone, far enough away that its chipped corners are under a pixel.
  ///
  /// Drawn at the full size of its slot rather than cut back for a joint: out
  /// here the joint is a fraction of a pixel too, and letting the block fill it
  /// means the coarse band butts up against the detailed one with no seam.
  void _emitBlock(
    Projector p,
    StoneSlot slot,
    Color albedo,
    Color mortar,
    V3 light,
    Palette pal,
    double ao,
    MortarLook look,
    Size size,
    int idx,
    bool capped,
  ) {
    final centre = p.cameraOf(V3(slot.x, slot.y, slot.zCenter));
    if (centre.z <= p.near) return;
    // Under about a pixel and a half wide it is not worth a draw call; the
    // silhouette behind covers that ground.
    if (slot.w * p.focal / centre.z < 1.4) return;

    final before = _faceCount;
    _emitCore(
      p,
      x0: slot.x - slot.w / 2,
      x1: slot.x + slot.w / 2,
      y0: slot.y - slot.h / 2,
      y1: slot.y + slot.h / 2,
      z0: slot.zCenter - slot.halfDepth,
      z1: slot.zCenter + slot.halfDepth,
      albedo: albedo,
      light: light,
      pal: pal,
      ao: ao,
      repairGlow: 0,
      depth: centre.z,
      capped: capped,
    );
    if (_faceCount > before) {
      _registerPick(_facePool[before], idx, size);
    }
  }

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

  Color _albedoFor(StoneSlot slot, Palette pal, double erosion) {
    final s = slot.seed;
    // Natural limestone is never one colour: warm and cool stones alternate,
    // with a little brightness variation on top.
    final warm = hash01(s, 1);
    var c = Color.lerp(pal.stoneCool, pal.stoneWarm, 0.28 + warm * 0.52)!;
    final b = 1.0 + hashJitter(0.055, s, 2);
    c = Color.from(
      alpha: 1,
      red: clampD(c.r * b, 0, 1),
      green: clampD(c.g * b, 0, 1),
      blue: clampD(c.b * b, 0, 1),
    );
    if (slot.kind == SlotKind.deck) {
      c = Color.lerp(c, const Color(0xFF6B4F32), 0.55)!;
    } else if (slot.kind == SlotKind.ornament) {
      c = Color.lerp(c, pal.stoneWarm, 0.25)!;
    }
    // Lichen creeps in as the wall is neglected.
    if (erosion > 0.02) {
      final moss = hash01(s, 3);
      if (moss < erosion * 0.72) {
        c = Color.lerp(c, const Color(0xFF5C6B4A), 0.20 + erosion * 0.42)!;
      }
      c = Color.lerp(c, const Color(0xFF7E7C6E), erosion * 0.28)!;
    }
    return c;
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
    final t = 1 - math.exp(-dist * 0.0125);
    if (t < 0.004) return c;
    return Color.lerp(c, pal.haze, t * 0.85)!;
  }

  /// The lanes between the blocks, and the shadow each building sits in.
  void _drawCityGround(Canvas canvas, Projector p, CityLayout city) {
    final pal = scene.palette;
    // A packed-earth pad under each plot that has been built on. Neighbouring
    // plots touch, so a block reads as one yard with streets around it, and the
    // edge of the town stays as ragged as the houses themselves.
    final pad = Color.lerp(pal.ground, pal.stoneWarm, 0.20)!;
    const half = CityLayout.plotPitch * 0.5;
    for (final b in city.buildings) {
      if (b.placedPieces <= 0) continue;
      final a = p.project(V3(b.cx - half, 0.004, b.cz - half));
      final c = p.project(V3(b.cx + half, 0.004, b.cz - half));
      final d = p.project(V3(b.cx + half, 0.004, b.cz + half));
      final e = p.project(V3(b.cx - half, 0.004, b.cz + half));
      if (a == null || c == null || d == null || e == null) continue;
      final path = Path()
        ..moveTo(a.x, a.y)
        ..lineTo(c.x, c.y)
        ..lineTo(d.x, d.y)
        ..lineTo(e.x, e.y)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = _hazeAt(pad, p, b.cx, b.cz, pal),
      );
    }

    // A soft pool of shade under each building. The wall gets a real projected
    // shadow; a hundred and fifty houses would cost far too much for that, and
    // at this size a contact shadow is what stops them floating anyway.
    final light = pal.lightDir;
    final drop = clampD(1.0 / math.max(0.25, light.y), 0.8, 2.4);
    for (final b in city.buildings) {
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
            pal.ink.withValues(alpha: 0.26 * scene.integrity.clamp(0.5, 1.0)),
            pal.ink.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// The town itself.
  void _collectCity(Projector p, Size size, CityLayout city) {
    final pal = scene.palette;
    final light = pal.lightDir;
    final decay = 1.0 - scene.integrity;
    final fx = scene.fx;
    final night = !pal.isDaylight;

    final take = math.min(scene.placed, city.pieces.length);
    // Nearest first, so the detail budget is spent where the eye is.
    final order = <int>[];
    for (var i = 0; i < take; i++) {
      order.add(i);
    }
    order.sort((a, b) {
      double d(CityPiece q) {
        final dx = q.cx - p.eye.x, dz = q.cz - p.eye.z;
        return dx * dx + dz * dz;
      }

      return d(city.pieces[a]).compareTo(d(city.pieces[b]));
    });

    final budget = scene.detailBudget + scene.coarseBudget;
    for (var k = 0; k < order.length && k < budget; k++) {
      final piece = city.pieces[order[k]];
      var lift = 0.0;
      var flash = 0.0;
      if (fx != null && fx.brickIndex == piece.index) {
        lift = fx.yOffset;
        flash = fx.flash;
      }
      _emitPiece(p, piece, pal, light, decay, night, lift, flash, size);
    }
  }

  void _emitPiece(
    Projector p,
    CityPiece piece,
    Palette pal,
    V3 light,
    double decay,
    bool night,
    double lift,
    double flash,
    Size size,
  ) {
    final s = piece.seed;
    // Colour belongs to the house, not to the piece: a wall that changes tone
    // halfway up, or a dormer that does not match its own roof, is the fastest
    // way to make a town look like a pile of blocks.
    final h = hash32(piece.building, 0x51ed, 3);
    final y0 = piece.y0 + lift, y1 = piece.y1 + lift;
    // A house is plaster over stone: pale walls, a stone base, a warm roof.
    Color wall() {
      final warm = hash01(h, 1);
      var c = Color.lerp(pal.stoneCool, pal.stoneWarm, 0.35 + warm * 0.55)!;
      if (hash01(h, 2) < 0.22) {
        c = Color.lerp(c, const Color(0xFF9A7C55), 0.35)!;
      }
      return _weather(c, decay, s);
    }

    Color stone() => _weather(
        Color.lerp(pal.stoneCool, pal.stone, 0.55)!, decay, s);

    Color roofColour() {
      final t = hash01(h, 3);
      final base = t < 0.45
          ? const Color(0xFF9A5B44)
          : (t < 0.78 ? const Color(0xFF6E6A63) : const Color(0xFF8A7448));
      return _weather(Color.lerp(base, pal.stone, 0.18)!, decay, s);
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

  // ------------------------------------------------- the landmark vocabulary

  /// A dome: rings of quads narrowing to a cap. Cheap, and from any distance
  /// the town is seen at it reads as a dome rather than as eight facets.
  void _emitDome(
    Projector p,
    CityPiece piece,
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
    CityPiece piece,
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
    CityPiece piece,
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

  /// Ploughed rows, flat on the ground.
  void _emitField(
      Projector p, CityPiece piece, double y0, Palette pal, double decay) {
    final green = Color.lerp(
        const Color(0xFF7E8A52), const Color(0xFFB09B58), hash01(piece.seed, 9))!;
    final soil = Color.lerp(green, const Color(0xFF6B5A42), 0.55)!;
    final along = piece.alongX;
    final across = along ? piece.d : piece.w;
    final rows = clampD(across / 0.28, 3, 12).round();
    final y = y0 + 0.012;
    for (var i = 0; i < rows; i++) {
      final a = (i + 0.12) / rows, b = (i + 0.88) / rows;
      final c = _hazeAt(
          Color.lerp(i.isEven ? green : soil, pal.ground, decay * 0.4)!,
          p,
          piece.cx,
          piece.cz,
          pal);
      if (along) {
        final z0 = piece.z0 + across * a, z1 = piece.z0 + across * b;
        _quad(p, V3(piece.x0, y, z0), V3(piece.x1, y, z0), V3(piece.x1, y, z1),
            V3(piece.x0, y, z1), c.toARGB32());
      } else {
        final x0 = piece.x0 + across * a, x1 = piece.x0 + across * b;
        _quad(p, V3(x0, y, piece.z0), V3(x0, y, piece.z1), V3(x1, y, piece.z1),
            V3(x1, y, piece.z0), c.toARGB32());
      }
    }
  }

  /// Standing water. Takes the sky's colour, which is what makes it read as
  /// water rather than as a blue rectangle.
  void _emitWater(
      Projector p, CityPiece piece, double y0, Palette pal, bool night) {
    final sky = Color.lerp(pal.skyHorizon, pal.skyTop, 0.45)!;
    final c = Color.lerp(sky, night ? pal.ink : pal.haze, 0.28)!;
    final y = y0 + 0.05;
    _quad(
      p,
      V3(piece.x0, y, piece.z1),
      V3(piece.x1, y, piece.z1),
      V3(piece.x1, y, piece.z0),
      V3(piece.x0, y, piece.z0),
      _hazeAt(c, p, piece.cx, piece.cz, pal).toARGB32(),
    );
  }

  /// A tree: a trunk and a canopy of two stacked blocks, which at this scale
  /// reads as a tree and costs eight faces.
  void _emitTree(
    Projector p,
    CityPiece piece,
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
      const Color(0xFF5A6E42),
      const Color(0xFF87904E),
      hash01(s, 11),
    )!;
    final autumn = Color.lerp(leaf, const Color(0xFF9A7A44), decay * 0.6)!;
    final bark = const Color(0xFF6B573F);
    final trunk = piece.w * 0.16;
    _emitSlab(p, piece.cx, piece.cz, trunk, trunk, y0, y0 + ht * 0.42, bark,
        light, pal, 0.85, flash);
    _emitSlab(p, piece.cx, piece.cz, piece.w * 0.92, piece.d * 0.92,
        y0 + ht * 0.34, y0 + ht * 0.78, autumn, light, pal, 1.0, flash);
    _emitSlab(p, piece.cx, piece.cz, piece.w * 0.6, piece.d * 0.6,
        y0 + ht * 0.74, y1, autumn, light, pal, 1.06, flash);
  }

  /// A run of stakes.
  void _emitPalisade(
    Projector p,
    CityPiece piece,
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
    CityPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final ht = y1 - y0;
    _emitSlab(p, piece.cx, piece.cz, 0.09, 0.09, y0, y1,
        const Color(0xFF6B573F), light, pal, 0.9, flash);
    final cloth = Color.lerp(pal.accent, const Color(0xFFB4462F),
        hash01(piece.seed, 13) * 0.7)!;
    final e = p.eye;
    final w = ht * 0.42;
    final top = y1 - ht * 0.08, bot = top - ht * 0.38;
    final c = _hazeAt(cloth, p, piece.cx, piece.cz, pal).toARGB32();
    if ((e.x - piece.cx).abs() > (e.z - piece.cz).abs()) {
      final z0 = piece.cz + 0.04, z1 = piece.cz + 0.04 + w;
      _quad(p, V3(piece.cx, bot, z0), V3(piece.cx, bot, z1),
          V3(piece.cx, top, z1), V3(piece.cx, top, z0), c);
    } else {
      final x0 = piece.cx + 0.04, x1 = piece.cx + 0.04 + w;
      _quad(p, V3(x0, bot, piece.cz), V3(x1, bot, piece.cz),
          V3(x1, top, piece.cz), V3(x0, top, piece.cz), c);
    }
  }

  /// A water wheel: a rim of paddles turning in a vertical plane.
  void _emitWheel(
    Projector p,
    CityPiece piece,
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
    const spokes = 10;
    final thick = r * 0.18;
    for (var i = 0; i < spokes; i++) {
      final a = i * 2 * math.pi / spokes;
      final px = math.cos(a) * r * 0.86, py = math.sin(a) * r * 0.86;
      _emitSlab(
        p,
        flat ? cx + px : cx,
        flat ? cz : cz + px,
        flat ? r * 0.2 : thick,
        flat ? thick : r * 0.2,
        cy + py - r * 0.12,
        cy + py + r * 0.12,
        i.isEven ? rim : wood,
        light,
        pal,
        0.95,
        flash,
      );
    }
    _emitSlab(p, cx, cz, flat ? r * 0.3 : thick * 1.2,
        flat ? thick * 1.2 : r * 0.3, cy - r * 0.16, cy + r * 0.16, wood, light,
        pal, 0.88, flash);
  }

  /// Four sails on a windmill's cap.
  void _emitSails(
    Projector p,
    CityPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
    double flash,
  ) {
    final r = (y1 - y0) / 2;
    final cy = y0 + r;
    final cx = piece.cx, cz = piece.cz;
    final wood = const Color(0xFF6E5A42);
    final cloth = Color.lerp(pal.stoneWarm, Colors.white, 0.45)!;
    // Set at a slight angle so the four arms never line up with the roof.
    final tilt = 0.38 + hash01(piece.seed, 14) * 0.5;
    for (var i = 0; i < 4; i++) {
      final a = tilt + i * math.pi / 2;
      final dx = math.cos(a), dy = math.sin(a);
      for (var k = 1; k <= 3; k++) {
        final t = k / 3.2 * r;
        _emitSlab(
          p,
          cx + dx * t,
          cz,
          r * 0.26,
          0.1,
          cy + dy * t - r * 0.12,
          cy + dy * t + r * 0.12,
          k == 3 ? wood : cloth,
          light,
          pal,
          1.0,
          flash,
        );
      }
    }
    _emitSlab(p, cx, cz, r * 0.22, 0.2, cy - r * 0.11, cy + r * 0.11, wood,
        light, pal, 0.9, flash);
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
  void _registerPickAt(Projector p, CityPiece piece, Size size, double y) {
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
    CityPiece piece,
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

  /// The windows of one storey.
  ///
  /// At night a lit window is one achievement showing from the outside, which
  /// is the whole town's worth of them read in a single glance — the thing the
  /// wall could never do.
  void _emitWindows(
    Projector p,
    CityPiece piece,
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

    void row(bool onZ, double at, double from, double to, double outward) {
      final span = to - from;
      final n = math.max(1, (span / 0.62).floor());
      for (var i = 0; i < n; i++) {
        final c = from + span * (i + 0.5) / n;
        final lit = night && hash01(s, 70, i) > 0.30 + decay * 0.45;
        final colour = lit
            ? const Color(0xFFFFD79A)
            : Color.lerp(pal.ink, pal.stoneCool, 0.30)!;
        const hw = 0.15;
        if (onZ) {
          _quad(
            p,
            V3(c - hw, wy0, outward),
            V3(c + hw, wy0, outward),
            V3(c + hw, wy1, outward),
            V3(c - hw, wy1, outward),
            (lit ? colour : _hazeAt(colour, p, piece.cx, piece.cz, pal))
                .toARGB32(),
          );
        } else {
          _quad(
            p,
            V3(outward, wy0, c - hw),
            V3(outward, wy0, c + hw),
            V3(outward, wy1, c + hw),
            V3(outward, wy1, c - hw),
            (lit ? colour : _hazeAt(colour, p, piece.cx, piece.cz, pal))
                .toARGB32(),
          );
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
    CityPiece piece,
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
    CityPiece piece,
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
  void _drawCityLabels(
    Canvas canvas,
    Projector p,
    Size size,
    CityLayout city,
  ) {
    for (final b in city.buildings) {
      if (!b.isLandmark || !b.finished) continue;
      if (scene.placed < b.firstPiece + b.cost) continue;
      final at = p.project(V3(b.cx, b.peakY + 0.5, b.cz));
      if (at == null) continue;
      if (at.x < -120 || at.x > size.width + 120) continue;
      _drawLabel(canvas, at, b.name.toUpperCase(), size);
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

  Color _haze(Color c, Projector p, double x, Palette pal) {
    final dist = (x - p.eye.x).abs() + (p.eye.y).abs() * 0.2;
    final t = 1 - math.exp(-dist * 0.0085);
    if (t < 0.004) return c;
    return Color.lerp(c, pal.haze, t * 0.85)!;
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

  /// The small living details that hang off the landmarks: fire in a brazier,
  /// a lantern in a shrine, chains on a drawbridge, a banner on a great tower.
  void _drawStructureExtras(Canvas canvas, Projector p, Size size) {
    final l = scene.layout;
    final pal = scene.palette;
    for (final st in l.structures) {
      final built = scene.placed >= st.firstBrick + st.brickCount;
      final progress =
          ((scene.placed - st.firstBrick) / st.brickCount).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final anchor = p.project(V3(st.featureX, st.featureY, 0));
      if (anchor == null) continue;
      if (anchor.x < -200 || anchor.x > size.width + 200) continue;
      final scale = p.focal / anchor.depth;

      switch (st.type.kind) {
        case MilestoneKind.beacon:
          if (built) _drawFire(canvas, anchor, scale, pal);
          break;
        case MilestoneKind.shrine:
          if (built) _drawLantern(canvas, anchor, scale, pal);
          break;
        case MilestoneKind.drawbridge:
          if (built) _drawChains(canvas, p, st, pal);
          break;
        case MilestoneKind.greatTower:
        case MilestoneKind.barbican:
          if (built) _drawBanner(canvas, p, st, pal);
          break;
        default:
          break;
      }
      if (built) _drawStructureLabel(canvas, p, st, anchor, size);
    }
  }

  void _drawFire(Canvas canvas, Offset2 at, double scale, Palette pal) {
    final flick = 0.82 + 0.18 * math.sin(scene.time * 9.1);
    final r = 0.26 * scale * flick;
    final c = Offset(at.x, at.y - r * 0.5);
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 2.6, [
          const Color(0xFFFFB347).withValues(alpha: 0.42),
          const Color(0xFFFF7A18).withValues(alpha: 0.0),
        ]),
    );
    final path = Path()..moveTo(c.dx - r * 0.5, c.dy + r * 0.5);
    path.quadraticBezierTo(c.dx - r * 0.7, c.dy - r * 0.4, c.dx, c.dy - r * 1.5 * flick);
    path.quadraticBezierTo(c.dx + r * 0.7, c.dy - r * 0.4, c.dx + r * 0.5, c.dy + r * 0.5);
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC46B).withValues(alpha: 0.92));
  }

  void _drawLantern(Canvas canvas, Offset2 at, double scale, Palette pal) {
    final pulse = 0.85 + 0.15 * math.sin(scene.time * 2.2);
    final r = 0.24 * scale * pulse;
    final c = Offset(at.x, at.y);
    canvas.drawCircle(
      c,
      r * 3.4,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 3.4, [
          const Color(0xFFFFD9A0).withValues(alpha: 0.38),
          const Color(0xFFFFB25E).withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(c, r * 0.5, Paint()..color = const Color(0xFFFFE9C4));
  }

  /// The two chains that lift the drawbridge deck.
  ///
  /// Their length is capped rather than run all the way to the top of the gate
  /// towers: those towers now grow with the wall, and a chain drawn from the
  /// deck to the top of a wall three storeys high stopped reading as a chain
  /// and started reading as a scratch across the screen. They also sag, and
  /// they are drawn thick enough at any distance to be a chain and not a
  /// hairline.
  void _drawChains(Canvas canvas, Projector p, StructureInstance st, Palette pal) {
    final topY = math.min(st.peakY - 0.25, st.featureY + 1.85);
    if (topY <= st.featureY + 0.2) return;
    for (final side in [-1.0, 1.0]) {
      final a = p.project(V3(st.featureX + side * 0.44, st.featureY + 0.06, 0.72));
      final b = p.project(V3(st.featureX + side * 0.86, topY, 0.52));
      if (a == null || b == null) continue;
      // A little slack, hanging from the winch end.
      final mid = Offset(
        (a.x + b.x) / 2 - side * 0.06 * (b.y - a.y).abs(),
        (a.y + b.y) / 2 + 0.10 * (b.y - a.y).abs(),
      );
      final path = Path()
        ..moveTo(a.x, a.y)
        ..quadraticBezierTo(mid.dx, mid.dy, b.x, b.y);
      final width = clampD(p.focal / math.max(1.0, a.depth) * 0.055, 1.4, 6.0);
      canvas.drawPath(
        path,
        Paint()
          ..color = pal.ink.withValues(alpha: 0.42)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawBanner(Canvas canvas, Projector p, StructureInstance st, Palette pal) {
    final base = p.project(V3(st.featureX, st.peakY, 0.1));
    final tip = p.project(V3(st.featureX, st.peakY + 1.1, 0.1));
    if (base == null || tip == null) return;
    canvas.drawLine(
      Offset(base.x, base.y),
      Offset(tip.x, tip.y),
      Paint()
        ..color = pal.ink.withValues(alpha: 0.7)
        ..strokeWidth = 1.8,
    );
    final w = (base.y - tip.y).abs() * 0.55;
    if (w < 2) return;
    final wave = math.sin(scene.time * 2.4) * w * 0.12;
    final path = Path()
      ..moveTo(tip.x, tip.y + w * 0.08)
      ..lineTo(tip.x + w, tip.y + w * 0.18 + wave)
      ..lineTo(tip.x + w * 0.78, tip.y + w * 0.52)
      ..lineTo(tip.x + w, tip.y + w * 0.86 + wave)
      ..lineTo(tip.x, tip.y + w * 0.76)
      ..close();
    canvas.drawPath(path, Paint()..color = pal.accent.withValues(alpha: 0.88));
  }

  void _drawStructureLabel(
      Canvas canvas, Projector p, StructureInstance st, Offset2 anchor, Size size) {
    if (anchor.depth > 42) return;
    final name = scene.structureNames[st.index] ?? st.type.name;
    final top = p.project(V3(st.featureX, st.peakY + 0.5, 0));
    if (top == null) return;
    _drawLabel(canvas, top, name.toUpperCase(), size, at: anchor.depth);
  }

  /// A name set straight on the sky with a halo, and a hairline under it to tie
  /// it to the thing it names. No filled pill: that was the last of the heavy
  /// white chrome.
  void _drawLabel(
    Canvas canvas,
    Offset2 top,
    String name,
    Size size, {
    double? at,
  }) {
    final depth = at ?? top.depth;
    final fade = clampD(1 - (depth - 24) / 18, 0, 1);
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

    final origin = Offset(cx - glow.width / 2, top.y - glow.height / 2);
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

  /// A quiet mark on the stones that carry a note, and a ring around the one
  /// currently selected.
  void _drawStoneMarks(Canvas canvas, Projector p, Size size) {
    final pal = scene.palette;
    for (final pick in picks) {
      final selected = pick.brickIndex == scene.selectedBrick;
      if (!pick.labelled && !selected) continue;
      final c = Offset(pick.cx, pick.cy);
      final r = clampD(pick.radius * 0.38, 3, 26);

      if (pick.labelled) {
        final breathe = 0.72 + 0.28 * math.sin(scene.time * 1.4 + pick.brickIndex);
        canvas.drawCircle(
          c,
          r * 1.7,
          Paint()
            ..shader = ui.Gradient.radial(c, r * 1.7, [
              pal.accent.withValues(alpha: 0.30 * breathe),
              pal.accent.withValues(alpha: 0.0),
            ]),
        );
        canvas.drawCircle(
          c,
          math.max(1.6, r * 0.22),
          Paint()..color = pal.accent.withValues(alpha: 0.85),
        );
      }

      if (selected) {
        canvas.drawCircle(
          c,
          r * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
    }
  }

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
          paint.color = const Color(0xFFF2C25B).withValues(alpha: life * 0.95);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 1.2, paint);
        case ParticleKind.ember:
          paint.color = Color.lerp(const Color(0xFFFF8A3D), const Color(0xFFFFD79A), life)!
              .withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.moteRepair:
          paint.color = const Color(0xFFBFE8D0).withValues(alpha: life * 0.8);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
      }
    }
  }

  // ----------------------------------------------------------------- ghost

  /// Where the next stone will land. Anticipation is part of the reward.
  void _drawGhost(Canvas canvas, Projector p) {
    final l = scene.layout;
    if (scene.placed >= l.slots.length) return;
    if (scene.fx != null && !scene.fx!.landed) return;
    final slot = l.slots[scene.placed];
    final profile = StoneProfiles.instance.forSeed(slot.seed);
    _mesh.build(slot, profile, mirror: (slot.seed & 0x1000) != 0);
    final path = Path();
    var ok = false;
    for (var i = 0; i < _mesh.n; i++) {
      final pt = p.project(V3(_mesh.front[i * 3], _mesh.front[i * 3 + 1],
          _mesh.front[i * 3 + 2]));
      if (pt == null) return;
      if (i == 0) {
        path.moveTo(pt.x, pt.y);
        ok = true;
      } else {
        path.lineTo(pt.x, pt.y);
      }
    }
    if (!ok) return;
    path.close();
    // Idle it is a faint outline; as the button is held it fills and brightens,
    // so you can see exactly where the stone is about to go.
    final ch = scene.charge.clamp(0.0, 1.0);
    final beat = ch > 0.02 ? 6.0 + ch * 14 : 2.6;
    final pulse = 0.35 + 0.25 * math.sin(scene.time * beat);
    final accent = scene.palette.accent;

    if (ch > 0.02) {
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.28 * ch)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 14 * ch),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(Colors.white, accent, ch)!
            .withValues(alpha: 0.03 * pulse + 0.45 * ch)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(Colors.white, accent, ch * 0.7)!
            .withValues(alpha: 0.10 + 0.06 * pulse + 0.55 * ch)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + 2.6 * ch,
    );
  }

  void _drawAtmosphere(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    final decay = 1 - scene.integrity;
    if (decay > 0.05) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = pal.haze.withValues(alpha: 0.10 + decay * 0.16),
      );
    }
    // A soft vignette to hold the eye on the wall.
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
  bool shouldRepaint(covariant WallPainter old) => true;
}
