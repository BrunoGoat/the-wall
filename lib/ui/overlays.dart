import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/lexicon.dart';

import '../data/landmarks.dart';
import '../data/milestones.dart';
import 'papyrus.dart';
import 'sigil.dart';
import 'style.dart';

/// The card that celebrates a finished landmark.
class MilestoneOverlay extends StatelessWidget {
  const MilestoneOverlay({
    super.key,
    required this.type,
    required this.theme,
    required this.onDismiss,
    required this.ordinal,
  });

  final MilestoneType type;
  final UiTheme theme;
  final VoidCallback onDismiss;
  final int ordinal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.42),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Frosted(
                theme: theme,
                strong: true,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LandmarkSigil(
                      kind: type.kind,
                      color: theme.fg.withValues(alpha: 0.88),
                      size: 74,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'HITO $ordinal COMPLETADO',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 10.5,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      type.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.fg,
                        fontSize: 26,
                        fontFamily: Papyrus.serif,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      type.blurb,
                      textAlign: TextAlign.center,
                      style: theme.bodySoft.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'levantado con ${type.brickCost} '
                      '${Lexicon.of.units} tuyas',
                      style: TextStyle(
                        color: theme.fgFaint,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card for a landmark the town has just finished.
///
/// It arrives every two or three weeks, which is the whole point: often enough
/// to be worth waiting for, rare enough that it is still an event. It says
/// what was built, what it means for the place, and what it cost you.
class TownLandmarkOverlay extends StatelessWidget {
  const TownLandmarkOverlay({
    super.key,
    required this.mark,
    required this.theme,
    required this.onDismiss,
    required this.ordinal,
  });

  final Landmark mark;
  final UiTheme theme;
  final VoidCallback onDismiss;
  final int ordinal;

  static const _icons = [
    Icons.water_drop_outlined,
    Icons.storefront_outlined,
    Icons.account_balance_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onDismiss,
      child: DecoratedBox(
        // Darkest at the bottom, clear at the top: the card sits low and the
        // thing it is about stays where you can see it turning.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.04),
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0.52),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: Align(
          alignment: const Alignment(0, 0.72),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 336),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Frosted(
                theme: t,
                strong: true,
                radius: 26,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icons[mark.tier],
                        size: 40, color: t.fg.withValues(alpha: 0.88)),
                    const SizedBox(height: 14),
                    Text(
                      'HITO $ordinal DEL PUEBLO',
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 10.5,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mark.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.fg,
                        fontSize: 24,
                        fontFamily: Papyrus.serif,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mark.blurb,
                      textAlign: TextAlign.center,
                      style: t.bodySoft.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'levantado con ${mark.cost} piezas tuyas',
                      style: TextStyle(
                        color: t.fgFaint,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet line that slides in and leaves on its own.
class Whisper extends StatelessWidget {
  const Whisper({super.key, required this.message, required this.theme});

  final String message;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Frosted(
        theme: theme,
        radius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Text(
          message,
          style: TextStyle(
            color: theme.fg.withValues(alpha: 0.9),
            fontSize: 12.5,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// What one stone was for, shown when you tap it.
///
/// The note is always optional: a stone with nothing written on it counts for
/// exactly as much as one with a paragraph.
class StoneCard extends StatelessWidget {
  const StoneCard({
    super.key,
    required this.theme,
    required this.when,
    required this.number,
    required this.label,
    required this.onEdit,
    required this.onClose,
  });

  final UiTheme theme;
  final DateTime when;
  final int number;
  final String? label;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  static String formatDate(DateTime w) =>
      '${w.day} ${_months[w.month - 1]} ${w.year} · '
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final has = label != null && label!.trim().isNotEmpty;
    return Frosted(
      theme: t,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${Lexicon.of.unit.toUpperCase()} $number · '
                  '${formatDate(when)}',
                  style: t.label.copyWith(fontSize: 9.5, letterSpacing: 1.4),
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: has
                      ? Text(
                          label!,
                          style: t.body.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 15, color: t.accent),
                            const SizedBox(width: 7),
                            Text(
                              'escribir una leyenda',
                              style: TextStyle(
                                color: t.accent,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (has)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_outlined, size: 17, color: t.fgSoft),
              onPressed: onEdit,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 17, color: t.fgSoft),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// The little editor for a stone's note.
class LabelSheet extends StatefulWidget {
  const LabelSheet({
    super.key,
    required this.theme,
    required this.number,
    required this.initial,
  });

  final UiTheme theme;
  final int number;
  final String? initial;

  /// Returns the new note, an empty string to clear it, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required UiTheme theme,
    required int number,
    String? initial,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LabelSheet(theme: theme, number: number, initial: initial),
    );
  }

  @override
  State<LabelSheet> createState() => _LabelSheetState();
}

class _LabelSheetState extends State<LabelSheet> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
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
            Text(
                'LEYENDA DE ${Lexicon.isTown ? 'LA PIEZA' : 'EL LADRILLO'} '
                '${widget.number}',
                style: t.label),
            const SizedBox(height: 4),
            Text(
              'Opcional. Para acordarte de qué fue este.',
              style: t.bodySoft.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctl,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(context).pop(v),
              style: t.body.copyWith(fontSize: 17),
              decoration: InputDecoration(
                hintText: 'Leí',
                hintStyle: TextStyle(color: t.fgFaint),
                counterStyle: TextStyle(color: t.fgFaint, fontSize: 10),
                enabledBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: t.stroke)),
                focusedBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if ((widget.initial ?? '').isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: Text('Borrar', style: TextStyle(color: t.fgSoft)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar', style: TextStyle(color: t.fgSoft)),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: t.accent),
                  onPressed: () => Navigator.of(context).pop(_ctl.text),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip along the bottom that shows the whole wall at a glance and lets
/// you jump anywhere along it.
class TravelScrubber extends StatelessWidget {
  const TravelScrubber({
    super.key,
    required this.theme,
    required this.length,
    required this.travel,
    required this.marks,
    required this.onSeek,
  });

  final UiTheme theme;
  final double length;
  final double travel;
  /// x positions of landmarks along the wall.
  final List<double> marks;
  final void Function(double x) onSeek;

  @override
  Widget build(BuildContext context) {
    if (length < 12) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      void seek(Offset local) {
        onSeek(((local.dx / w).clamp(0.0, 1.0)) * length);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => seek(d.localPosition),
        onHorizontalDragUpdate: (d) => seek(d.localPosition),
        child: SizedBox(
          height: 26,
          child: CustomPaint(
            painter: _ScrubberPainter(
              theme: theme,
              length: length,
              travel: travel,
              marks: marks,
            ),
          ),
        ),
      );
    });
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.theme,
    required this.length,
    required this.travel,
    required this.marks,
  });

  final UiTheme theme;
  final double length, travel;
  final List<double> marks;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = theme.fg.withValues(alpha: 0.20)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);

    final markPaint = Paint()..color = theme.fg.withValues(alpha: 0.44);
    for (final m in marks) {
      final x = (m / length).clamp(0.0, 1.0) * size.width;
      canvas.drawCircle(Offset(x, y), 2.6, markPaint);
    }

    final t = (travel / length).clamp(0.0, 1.0) * size.width;
    canvas.drawLine(
      Offset(0, y),
      Offset(t, y),
      Paint()
        ..color = theme.accent.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(t, y), 5.5, Paint()..color = theme.accent);
    canvas.drawCircle(
      Offset(t, y),
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter old) =>
      old.travel != travel || old.length != length || old.marks.length != marks.length;
}

/// A ring that fills as today's target for one habit is met.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    required this.track,
  });

  final double progress;
  final Color color, track;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(progress, color, track)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
