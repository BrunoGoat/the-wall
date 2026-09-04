import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/milestones.dart';
import '../engine/structures.dart';

/// The mark that stands for a landmark: its own elevation, drawn.
///
/// Not an icon from a set and certainly not an emoji — the sigil is sampled
/// from the very geometry the wall is built out of, so the mark beside "Puerta
/// de Piedra" is the outline of the gate you actually built, arch and all. Two
/// landmarks can no more share a mark than they can share a silhouette.
class LandmarkSigil extends StatelessWidget {
  const LandmarkSigil({
    super.key,
    required this.kind,
    required this.color,
    this.size = 30,
    this.locked = false,
  });

  final MilestoneKind kind;
  final Color color;
  final double size;

  /// A landmark not yet begun is drawn as a faint ruled outline: you can see
  /// its shape coming without being shown the thing itself.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SigilPainter(kind: kind, color: color, locked: locked),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  const _SigilPainter({
    required this.kind,
    required this.color,
    required this.locked,
  });

  final MilestoneKind kind;
  final Color color;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = SigilShapes.of(kind);
    if (shape.bounds.isEmpty) return;

    final b = shape.bounds;
    final k = math.min(size.width / b.width, size.height / b.height) * 0.94;
    canvas.save();
    canvas.translate(
      (size.width - b.width * k) / 2 - b.left * k,
      (size.height + b.height * k) / 2 + b.top * k,
    );
    // The shape is authored in wall coordinates, where y climbs.
    canvas.scale(k, -k);
    if (locked) {
      canvas.drawPath(
        shape.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 / k
          ..color = color,
      );
      canvas.restore();
      return;
    }
    // The parts of the landmark that stand out in front of the wall are drawn
    // a shade lighter, so a stair reads as a stair rather than as one more
    // crenellated block.
    canvas.saveLayer(shape.bounds.inflate(1), Paint());
    canvas.drawPath(shape.path, Paint()..color = color);
    canvas.drawPath(
      shape.relief,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.42)
        ..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.kind != kind || old.color != color || old.locked != locked;
}

/// One elevation per landmark, sampled once and kept.
class SigilShapes {
  const SigilShapes._();

  static final Map<MilestoneKind, SigilShape> _cache = {};

  static SigilShape of(MilestoneKind kind) =>
      _cache.putIfAbsent(kind, () => _build(kind));

  /// Rasterises the landmark's front elevation on a coarse grid.
  ///
  /// A grid rather than an outline trace: the shapes are unions of masses with
  /// holes cut through them, and squaring them off at this size is what makes
  /// the mark read as masonry instead of as a blob.
  static SigilShape _build(MilestoneKind kind) {
    const wallTop = 1.72;
    final spec = StructureShapes(wallTop).build(kind, 0);
    final path = Path();
    final relief = Path();
    var lo = double.infinity, hi = -double.infinity;
    var left = double.infinity, right = -double.infinity;

    const step = 0.085;
    for (final slab in spec.slabs) {
      final nx = ((slab.x1 - slab.x0) / step).ceil();
      final ny = ((slab.y1 - slab.y0) / step).ceil();
      if (nx <= 0 || ny <= 0) continue;
      final w = (slab.x1 - slab.x0) / nx;
      final h = (slab.y1 - slab.y0) / ny;
      final mid = (slab.x0 + slab.x1) / 2;
      final proud = slab.zCenter(mid) > 0.26;
      for (var i = 0; i < nx; i++) {
        final x = slab.x0 + (i + 0.5) * w;
        for (var j = 0; j < ny; j++) {
          final y = slab.y0 + (j + 0.5) * h;
          if (!slab.solid(x, y)) continue;
          final cell = Rect.fromLTWH(
            slab.x0 + i * w,
            slab.y0 + j * h,
            w * 1.02,
            h * 1.02,
          );
          path.addRect(cell);
          if (proud) relief.addRect(cell);
          if (y < lo) lo = y;
          if (y > hi) hi = y;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }
    if (lo > hi) return SigilShape(null, Rect.zero);
    return SigilShape(
      path,
      Rect.fromLTRB(left - step, lo - step, right + step, hi + step),
      relief: relief,
    );
  }
}

class SigilShape {
  const SigilShape(this._path, this.bounds, {Path? relief}) : _relief = relief;
  final Path? _path;
  final Path? _relief;
  final Rect bounds;
  Path get path => _path ?? Path();

  /// The masses that stand clear of the wall's face.
  Path get relief => _relief ?? Path();
}

/// A hairline rule with a diamond in the middle: the divider used wherever the
/// app needs to separate two things without shouting about it.
class Sigil {
  const Sigil._();

  /// Draws a small lozenge, the app's only decorative mark.
  static Widget lozenge(Color color, {double size = 5}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LozengePainter(color)),
      );
}

class _LozengePainter extends CustomPainter {
  const _LozengePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LozengePainter old) => old.color != color;
}
