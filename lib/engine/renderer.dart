import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/milestones.dart';
import '../fx/effects.dart';
import 'camera.dart';
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

  static final List<_Face> _facePool = List.generate(6000, (_) => _Face());
  static final StoneMesh _mesh = StoneMesh(24);
  static final Float64List _clipA = Float64List(96);
  static final Float64List _clipB = Float64List(96);
  static final Path _scratch = Path();
  static final Map<int, TextPainter> _labelCache = {};

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
    cam.detailRadius = clampD(
      scene.detailBudget / (2 * math.max(1.0, density)),
      6,
      260,
    );
    final p = cam.projector(size.width, size.height, scene.time);
    final horizonY = _horizonY(p, size);

    _drawSky(canvas, size, p, horizonY);
    _drawGround(canvas, size, horizonY);
    _drawRanges(canvas, p, size);
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
  void _drawRanges(Canvas canvas, Projector p, Size size) {
    final pal = scene.palette;
    final light = pal.lightDir;
    final cx = scene.camera.travel;

    for (var li = Landscape.ridges.length - 1; li >= 0; li--) {
      final layer = Landscape.ridges[li];
      final fade = 0.30 + li * 0.28;
      // The nearest range keeps some of the ground's own colour; the far ones
      // dissolve almost entirely into the haze.
      final base = Color.lerp(pal.ground, pal.groundFar, 0.35 + li * 0.3)!;
      final body = Color.lerp(base, pal.haze, fade)!;
      final lit = Color.lerp(body, pal.sun, 0.20 * (1 - fade))!;

      const steps = 168;
      Path? path;
      var lastLitSide = false;
      for (var i = 0; i <= steps; i++) {
        final th = i / steps * math.pi * 2;
        final wx = cx + math.sin(th) * layer.radius;
        final wz = math.cos(th) * layer.radius;
        final h = Landscape.ridgeHeight(layer, wx, wz);
        final top = p.project(V3(wx, math.max(h, layer.base), wz));
        final foot = p.project(V3(wx, layer.base, wz));
        if (top == null || foot == null) {
          if (path != null) {
            canvas.drawPath(path, Paint()..color = lastLitSide ? lit : body);
            path = null;
          }
          continue;
        }
        // Slopes facing the light catch a little more of it.
        final facing = (math.sin(th) * light.x + math.cos(th) * light.z) < 0;
        if (path == null || facing != lastLitSide) {
          if (path != null) {
            path.lineTo(foot.x, foot.y);
            canvas.drawPath(path, Paint()..color = lastLitSide ? lit : body);
          }
          path = Path()..moveTo(foot.x, foot.y);
          lastLitSide = facing;
        }
        path.lineTo(top.x, top.y);
        // Close each strip down to the foot so it never floats.
        if (i == steps) {
          path.lineTo(foot.x, foot.y);
          canvas.drawPath(path, Paint()..color = lastLitSide ? lit : body);
          path = null;
        }
      }
      if (path != null) {
        canvas.drawPath(path, Paint()..color = lastLitSide ? lit : body);
      }
    }
  }

  /// A handful of soft patches of scrub on the ground. They cost almost
  /// nothing and stop the plain the wall stands on reading as empty paper.
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
    final r = scene.camera.detailRadius * 2.2;
    return ((scene.camera.travel - r) / l.profileStep)
        .floor()
        .clamp(0, math.max(0, l.profileCore.length - 1));
  }

  int _bucketHi() {
    final l = scene.layout;
    final r = scene.camera.detailRadius * 2.2;
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
    final near = math.max(2.0, cam.detailRadius - l.profileStep * 3);
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
    final mortarBase = Color.lerp(pal.mortar, pal.stoneCool, 0.46)!;
    final fx = scene.fx;

    // Nearest-first so the detail budget is spent where the eye is.
    final order = <int>[];
    for (var i = 0; i < scene.placed && i < l.slots.length; i++) {
      final s = l.slots[i];
      if ((s.x - cam.travel).abs() > radius) continue;
      order.add(i);
    }
    order.sort((a, b) {
      final da = (l.slots[a].x - cam.travel).abs();
      final db = (l.slots[b].x - cam.travel).abs();
      return da.compareTo(db);
    });
    final take = math.min(order.length, scene.detailBudget);

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
      final grow = 0.016 + erosion * 0.02;
      _emitCore(
        p,
        x0: slot.x - slot.w / 2 - grow,
        x1: slot.x + slot.w / 2 + grow,
        y0: slot.y - slot.h / 2 - grow,
        y1: slot.y + slot.h / 2 + grow,
        z0: slot.zCenter - slot.halfDepth + 0.05,
        z1: slot.zCenter + slot.halfDepth - 0.05,
        albedo: mortarBase,
        light: light,
        pal: pal,
        ao: ao * 0.80,
        repairGlow: repairGlow * 0.4,
        depth: farDepth,
      );

      _emitPrism(p, slot, albedo, light, pal, ao,
          flash: flash,
          repairGlow: repairGlow,
          pickInto: size,
          pickIndex: idx);
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

      final c = _shade(nrm, albedo, light, pal, ao, flash, repairGlow);
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
  }) {
    if (z1 <= z0) {
      final mid = (z0 + z1) / 2;
      z0 = mid - 0.01;
      z1 = mid + 0.01;
    }
    final e = p.eye;
    int col(V3 normal, double k) => _haze(
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
          col(const V3(0, 1, 0), 1.05), depthOverride: depth);
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

  Color _shade(V3 n, Color albedo, V3 light, Palette pal, double ao,
      double flash, double repairGlow) {
    final ndl = math.max(0.0, n.dot(light));
    final skyTerm = 0.5 + 0.5 * n.y;
    // Stone in shadow is still stone: the sky term is modulated by the albedo
    // so unlit faces stay pale limestone instead of collapsing to black.
    final k = (0.32 + 0.68 * ndl + 0.28 * skyTerm) * ao * pal.contrast;
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

  void _drawChains(Canvas canvas, Projector p, StructureInstance st, Palette pal) {
    final paint = Paint()
      ..color = pal.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final side in [-1.0, 1.0]) {
      final a = p.project(V3(st.featureX + side * 0.44, st.featureY + 0.06, 0.72));
      final b = p.project(V3(st.featureX + side * 0.92, st.peakY - 0.25, 0.5));
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
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
    var tp = _labelCache[st.index];
    if (tp == null || tp.text?.toPlainText() != name) {
      tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: scene.palette.ink.withValues(alpha: 0.85),
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _labelCache[st.index] = tp;
    }
    final top = p.project(V3(st.featureX, st.peakY + 0.45, 0));
    if (top == null) return;
    final fade = clampD(1 - (anchor.depth - 24) / 18, 0, 1);
    if (fade <= 0.02) return;
    final rect = Rect.fromCenter(
      center: Offset(top.x, top.y),
      width: tp.width + 16,
      height: tp.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()..color = Colors.white.withValues(alpha: 0.42 * fade),
    );
    canvas.saveLayer(rect.inflate(4), Paint()..color = Colors.white.withValues(alpha: fade));
    tp.paint(canvas, Offset(top.x - tp.width / 2, top.y - tp.height / 2));
    canvas.restore();
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
