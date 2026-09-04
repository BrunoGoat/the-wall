import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/epics.dart';

/// The mark that identifies each family of epics.
///
/// The same drawing is used for the tiny anomaly hidden in a stone and for the
/// full-size emblem on the reveal card, so finding one and recognising it later
/// are the same gesture.
class EpicSigil {
  const EpicSigil._();

  static Color colorFor(EpicKind k) => switch (k) {
        EpicKind.rune => const Color(0xFFE8B44A),
        EpicKind.gem => const Color(0xFF7FC4E8),
        EpicKind.fossil => const Color(0xFFCFA98A),
        EpicKind.carving => const Color(0xFFE6D6B4),
        EpicKind.relic => const Color(0xFFC9A227),
        EpicKind.creature => const Color(0xFF97C48A),
        EpicKind.celestial => const Color(0xFFAFB8F0),
        EpicKind.specter => const Color(0xFFC9E8E4),
        EpicKind.mechanism => const Color(0xFFD08A5A),
        EpicKind.flora => const Color(0xFF8FC06A),
      };

  static String nameFor(EpicKind k) => switch (k) {
        EpicKind.rune => 'Runa',
        EpicKind.gem => 'Gema',
        EpicKind.fossil => 'Fósil',
        EpicKind.carving => 'Talla',
        EpicKind.relic => 'Reliquia',
        EpicKind.creature => 'Criatura',
        EpicKind.celestial => 'Celeste',
        EpicKind.specter => 'Aparición',
        EpicKind.mechanism => 'Mecanismo',
        EpicKind.flora => 'Flora',
      };

  static void paint(Canvas canvas, Offset c, double r, EpicKind kind, Color tint,
      double alpha) {
    final paint = Paint()
      ..color = tint.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.16)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = tint.withValues(alpha: alpha * 0.9);

    switch (kind) {
      case EpicKind.rune:
        final path = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx, c.dy + r)
          ..moveTo(c.dx - r * 0.7, c.dy - r * 0.35)
          ..lineTo(c.dx + r * 0.7, c.dy - r * 0.75)
          ..moveTo(c.dx - r * 0.7, c.dy + r * 0.6)
          ..lineTo(c.dx + r * 0.7, c.dy + r * 0.2);
        canvas.drawPath(path, paint);
      case EpicKind.gem:
        final path = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.8, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.8, c.dy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawLine(Offset(c.dx - r * 0.8, c.dy), Offset(c.dx + r * 0.8, c.dy),
            paint..color = Colors.white.withValues(alpha: alpha * 0.7));
      case EpicKind.fossil:
        final path = Path();
        for (var i = 0; i <= 42; i++) {
          final t = i / 42;
          final ang = t * math.pi * 3.4;
          final rad = r * t;
          final x = c.dx + math.cos(ang) * rad;
          final y = c.dy + math.sin(ang) * rad;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, paint);
      case EpicKind.carving:
        for (var i = 1; i <= 3; i++) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: r * i / 3), -2.2, 2.6,
              false, paint);
        }
      case EpicKind.relic:
        canvas.drawCircle(Offset(c.dx, c.dy - r * 0.55), r * 0.36, paint);
        canvas.drawLine(Offset(c.dx, c.dy - r * 0.2), Offset(c.dx, c.dy + r), paint);
        canvas.drawLine(Offset(c.dx, c.dy + r * 0.6),
            Offset(c.dx + r * 0.55, c.dy + r * 0.6), paint);
      case EpicKind.creature:
        canvas.drawOval(
            Rect.fromCenter(center: Offset(c.dx - r * 0.42, c.dy), width: r * 0.7, height: r * 0.9),
            fill);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(c.dx + r * 0.42, c.dy), width: r * 0.7, height: r * 0.9),
            fill);
      case EpicKind.celestial:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final ang = -math.pi / 2 + i * math.pi / 5;
          final rad = i.isEven ? r : r * 0.42;
          final x = c.dx + math.cos(ang) * rad;
          final y = c.dy + math.sin(ang) * rad;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, fill);
      case EpicKind.specter:
        final path = Path()..moveTo(c.dx - r * 0.7, c.dy + r);
        path.cubicTo(c.dx - r, c.dy - r * 0.6, c.dx + r, c.dy - r * 0.9, c.dx + r * 0.6,
            c.dy + r);
        canvas.drawPath(path, paint);
      case EpicKind.mechanism:
        canvas.drawCircle(c, r * 0.5, paint);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * r * 0.62, c.dy + math.sin(a) * r * 0.62),
            Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
            paint,
          );
        }
      case EpicKind.flora:
        canvas.drawLine(Offset(c.dx, c.dy + r), Offset(c.dx, c.dy - r * 0.3), paint);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(c.dx - r * 0.4, c.dy - r * 0.2), radius: r * 0.5),
            0, math.pi, false, paint);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(c.dx + r * 0.4, c.dy - r * 0.45), radius: r * 0.5),
            math.pi, math.pi, false, paint);
    }
  }
}
