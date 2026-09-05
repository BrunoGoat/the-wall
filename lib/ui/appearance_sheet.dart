import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/appearance.dart';
import 'style.dart';

/// Choosing how the masonry is pointed, with the wall in plain sight behind.
///
/// Deliberately opened without a scrim: every one of these is a judgement about
/// how the stone looks, and you cannot make it against a dimmed wall.
class AppearanceSheet extends StatefulWidget {
  const AppearanceSheet({super.key, required this.theme});

  final UiTheme theme;

  @override
  State<AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<AppearanceSheet> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final current = Appearance.instance.mortar;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      decoration: BoxDecoration(
        color: t.panelStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.fgFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('MORTERO Y JUNTAS', style: t.label),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Se cambia sobre la muralla, en vivo. No toca ningún ladrillo. '
              'Sólo aplica al modo muralla.',
              style: t.bodySoft.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          for (final look in MortarLook.all)
            _Option(
              theme: t,
              look: look,
              selected: look.style == current,
              onTap: () async {
                Sensory.instance.tick();
                await Appearance.instance.setMortar(look.style);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.theme,
    required this.look,
    required this.selected,
    required this.onTap,
  });

  final UiTheme theme;
  final MortarLook look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? t.accent.withValues(alpha: 0.55)
                : t.fg.withValues(alpha: 0.13),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _JointSwatch(look: look, theme: t),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    look.name,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? t.accent : t.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(look.blurb, style: t.bodySoft.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A few courses of the wall at that pointing, drawn small.
class _JointSwatch extends StatelessWidget {
  const _JointSwatch({required this.look, required this.theme});
  final MortarLook look;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _SwatchPainter(look: look, theme: theme)),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.look, required this.theme});
  final MortarLook look;
  final UiTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final pal = theme.palette;
    final mortar = Color.lerp(pal.mortar, pal.stone, look.tint)!;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Offset.zero & size, Paint()..color = mortar);

    // The joint reads at this size as a fraction of the course, not as the
    // handful of millimetres it really is.
    final gap = 0.6 + look.joint * 150;
    const rows = 4;
    final h = size.height / rows;
    var seed = 0;
    for (var r = 0; r < rows; r++) {
      final offset = r.isEven ? 0.0 : -size.width * 0.28;
      var x = offset;
      while (x < size.width) {
        final w = size.width * (0.34 + ((seed * 37) % 5) * 0.07);
        final tone = 0.82 + ((seed * 53) % 7) * 0.035;
        final c = Color.lerp(pal.stoneCool, pal.stoneWarm, ((seed * 17) % 9) / 8)!;
        canvas.drawRect(
          Rect.fromLTWH(x + gap, r * h + gap, w - gap * 2, h - gap * 2),
          Paint()
            ..color = Color.from(
              alpha: 1,
              red: (c.r * tone).clamp(0.0, 1.0),
              green: (c.g * tone).clamp(0.0, 1.0),
              blue: (c.b * tone).clamp(0.0, 1.0),
            ),
        );
        x += w;
        seed++;
      }
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.fg.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.look.style != look.style || old.theme.dark != theme.dark;
}
