import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../model/piece.dart';

/// The colours of an old sheet. Deliberately fixed: a chronicle does not
/// change colour because the sun went down over the wall outside.
class Papyrus {
  const Papyrus._();

  static const Color sheetTop = Color(0xFFEFE0BE);
  static const Color sheetBottom = Color(0xFFDFC79A);
  static const Color fibre = Color(0xFF6B4E22);
  static const Color ink = Color(0xFF4A3A22);
  static const Color inkSoft = Color(0xFF6E5A3B);
  static const Color inkFaint = Color(0xFF8C7752);
  static const Color rubric = Color(0xFF8E3B2E);
  static const Color rule = Color(0x33795E33);

  static const String serif = 'Chronicle';

  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
      TextStyle(
        fontFamily: serif,
        color: c ?? ink,
        fontSize: size,
        height: 1.5,
        fontWeight: w,
      );

  /// Roman numerals, because a chronicle does not count in Arabic.
  static String roman(int n) {
    if (n <= 0) return '—';
    const table = <int, String>{
      1000: 'M', 900: 'CM', 500: 'D', 400: 'CD',
      100: 'C', 90: 'XC', 50: 'L', 40: 'XL',
      10: 'X', 9: 'IX', 5: 'V', 4: 'IV', 1: 'I',
    };
    final b = StringBuffer();
    var left = n;
    for (final e in table.entries) {
      while (left >= e.key) {
        b.write(e.value);
        left -= e.key;
      }
    }
    return b.toString();
  }

  static const List<String> months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// "el XII día de marzo, año MMXXVI"
  static String longDate(DateTime d) =>
      'el ${roman(d.day)} día de ${months[d.month - 1]}, año ${roman(d.year)}';

  static String monthHeading(DateTime d) =>
      'MES DE ${months[d.month - 1].toUpperCase()} · AÑO ${roman(d.year)}';
}

/// Paints the sheet itself: weave, stains, worn edges.
///
/// Everything is driven by [hash01] off a fixed seed, so the same sheet is the
/// same sheet every time it is drawn — a stain that wandered on every scroll
/// frame would read as a bug, not as age.
class PapyrusPainter extends CustomPainter {
  const PapyrusPainter({this.seed = 0x9e37});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
    canvas.save();
    canvas.clipRRect(rr);

    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width * 0.35, size.height),
          const [Papyrus.sheetTop, Papyrus.sheetBottom],
        ),
    );

    // The weave: papyrus is strips laid across strips. Kept very faint and
    // broken up — drawn any stronger it stops reading as fibre in the sheet
    // and starts reading as ruled lines on top of it.
    for (var i = 0; i < 150; i++) {
      final y = hash01(seed, 1, i) * size.height;
      final x0 = hash01(seed, 2, i) * size.width;
      final w = (0.08 + hash01(seed, 13, i) * 0.5) * size.width;
      canvas.drawLine(
        Offset(x0, y),
        Offset(math.min(size.width, x0 + w), y + hashJitter(0.6, seed, 14, i)),
        Paint()
          ..color = Papyrus.fibre.withValues(
              alpha: 0.035 + hash01(seed, 15, i) * 0.045)
          ..strokeWidth = 0.7 + hash01(seed, 16, i) * 0.8,
      );
    }
    for (var i = 0; i < 70; i++) {
      final x = hash01(seed, 4, i) * size.width;
      final y0 = hash01(seed, 5, i) * size.height;
      final h = (0.05 + hash01(seed, 17, i) * 0.28) * size.height;
      canvas.drawLine(
        Offset(x, y0),
        Offset(x + hashJitter(0.8, seed, 18, i), math.min(size.height, y0 + h)),
        Paint()
          ..color = Papyrus.fibre.withValues(alpha: 0.025 + hash01(seed, 19, i) * 0.03)
          ..strokeWidth = 0.7,
      );
    }

    // Stains: a few soft blooms, darker at the edges of the sheet.
    for (var i = 0; i < 16; i++) {
      final cx = hash01(seed, 7, i) * size.width;
      final cy = hash01(seed, 8, i) * size.height;
      final rad = 26 + hash01(seed, 9, i) * 130;
      final a = 0.03 + hash01(seed, 10, i) * 0.06;
      canvas.drawCircle(
        Offset(cx, cy),
        rad,
        Paint()
          ..shader = ui.Gradient.radial(Offset(cx, cy), rad, [
            const Color(0xFF7A5A2A).withValues(alpha: a),
            const Color(0x007A5A2A),
          ]),
      );
    }

    // Worn edges: the sheet is darker and rougher where it has been handled.
    final edge = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        math.max(size.width, size.height) * 0.72,
        const [Color(0x00000000), Color(0x33553A15)],
        const [0.55, 1.0],
      );
    canvas.drawRect(r, edge);

    // A ragged deckle down both sides.
    final tear = Paint()..color = const Color(0x22553A15);
    for (var i = 0; i < 120; i++) {
      final y = i / 120 * size.height;
      final w = 1.5 + hash01(seed, 11, i) * 4.5;
      canvas.drawRect(Rect.fromLTWH(0, y, w, size.height / 120 + 1), tear);
      final w2 = 1.5 + hash01(seed, 12, i) * 4.5;
      canvas.drawRect(
          Rect.fromLTWH(size.width - w2, y, w2, size.height / 120 + 1), tear);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PapyrusPainter old) => old.seed != seed;
}

/// A hairline rule with a drawn lozenge in the middle, the way a scribe closes
/// a section. Drawn rather than typed: a dingbat character is at the mercy of
/// whatever font the phone falls back to, and half of them come back as emoji.
class PapyrusRule extends StatelessWidget {
  const PapyrusRule({super.key, this.wide = false});

  /// The heavier mark, for the end of the whole chronicle.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Papyrus.rule, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: SizedBox(
            width: wide ? 34 : 9,
            height: 9,
            child: CustomPaint(painter: _RulePainter(wide: wide)),
          ),
        ),
        const Expanded(child: Divider(color: Papyrus.rule, height: 1)),
      ],
    );
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter({required this.wide});
  final bool wide;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Papyrus.inkFaint;
    void lozenge(double cx, double half) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, size.height / 2 - half)
          ..lineTo(cx + half, size.height / 2)
          ..lineTo(cx, size.height / 2 + half)
          ..lineTo(cx - half, size.height / 2)
          ..close(),
        paint,
      );
    }

    lozenge(size.width / 2, 4);
    if (wide) {
      lozenge(size.width / 2 - 13, 2.2);
      lozenge(size.width / 2 + 13, 2.2);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.wide != wide;
}

/// One entry in the chronicle.
class PapyrusEntry extends StatelessWidget {
  const PapyrusEntry({
    super.key,
    required this.brick,
    required this.ordinal,
    required this.onGo,
    required this.onEdit,
    this.dropCap = false,
  });

  final Piece brick;

  /// Which entry this is in the whole log, for the marginal number.
  final int ordinal;
  final VoidCallback onGo;
  final VoidCallback onEdit;
  final bool dropCap;

  @override
  Widget build(BuildContext context) {
    final text = brick.label ?? '';
    final first = text.isEmpty ? '' : text.characters.first;
    final rest = text.isEmpty ? '' : text.substring(first.length);

    return InkWell(
      onTap: onGo,
      onLongPress: onEdit,
      borderRadius: BorderRadius.circular(6),
      splashColor: Papyrus.rubric.withValues(alpha: 0.06),
      highlightColor: Papyrus.rubric.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The margin, where a scribe kept his count.
            SizedBox(
              width: 42,
              child: Text(
                Papyrus.roman(ordinal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: Papyrus.serif,
                  color: Papyrus.inkFaint,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: first,
                          style: TextStyle(
                            fontFamily: Papyrus.serif,
                            color: Papyrus.rubric,
                            fontSize: dropCap ? 30 : 17.5,
                            height: dropCap ? 1.0 : 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: rest,
                          style: const TextStyle(
                            fontFamily: Papyrus.serif,
                            color: Papyrus.ink,
                            fontSize: 17.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Puesta la pieza ${Papyrus.roman(brick.index + 1)}, '
                    '${Papyrus.longDate(brick.placedAt)}.',
                    style: Papyrus.body(12.5, c: Papyrus.inkSoft),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 5),
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'enmendar',
                    style: Papyrus.body(9.5, c: Papyrus.inkFaint).copyWith(
                      letterSpacing: 1.1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
