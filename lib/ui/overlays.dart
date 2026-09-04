import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/epics.dart';
import '../data/milestones.dart';
import '../engine/sigil.dart';
import 'style.dart';

/// The full-screen moment when an epic is finally uncovered.
class EpicRevealOverlay extends StatefulWidget {
  const EpicRevealOverlay({
    super.key,
    required this.epic,
    required this.found,
    required this.theme,
    required this.onDismiss,
  });

  final Epic epic;
  final int found;
  final UiTheme theme;
  final VoidCallback onDismiss;

  @override
  State<EpicRevealOverlay> createState() => _EpicRevealOverlayState();
}

class _EpicRevealOverlayState extends State<EpicRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.epic;
    final tint = EpicSigil.colorFor(e.kind);
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
          final pop = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
          return Container(
            color: Colors.black.withValues(alpha: 0.62 * t),
            child: Center(
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 26),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 0.4 + 0.6 * pop,
                            child: SizedBox(
                              width: 132,
                              height: 132,
                              child: CustomPaint(
                                painter: _SigilPainter(e.kind, tint, _c.value),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            '${e.tierName.toUpperCase()} · ${EpicSigil.nameFor(e.kind).toUpperCase()}',
                            style: TextStyle(
                              color: tint,
                              fontSize: 10.5,
                              letterSpacing: 3.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            e.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF6F1E6),
                              fontSize: 27,
                              height: 1.18,
                              fontFamily: 'serif',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            e.lore,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 14.5,
                              height: 1.55,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              '${widget.found} de 100 encontrados',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11.5,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'tocá para seguir',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 11,
                              letterSpacing: 1.6,
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
        },
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter(this.kind, this.tint, this.t);
  final EpicKind kind;
  final Color tint;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 2.2, [
          tint.withValues(alpha: 0.34),
          tint.withValues(alpha: 0.0),
        ]),
    );
    // A ring of light that opens outwards on reveal.
    final ring = Curves.easeOutQuart.transform(t.clamp(0.0, 1.0));
    if (ring < 1) {
      canvas.drawCircle(
        c,
        r * (0.5 + ring * 2.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ring)
          ..color = tint.withValues(alpha: (1 - ring) * 0.8),
      );
    }
    canvas.drawCircle(
      c,
      r * 1.28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tint.withValues(alpha: 0.32),
    );
    EpicSigil.paint(canvas, c, r, kind, tint, 1.0);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter old) => old.t != t;
}

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
                    Text(type.glyph, style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 18),
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
                        fontFamily: 'serif',
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
                      'levantado con ${type.brickCost} ladrillos tuyos',
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
class StoneCard extends StatelessWidget {
  const StoneCard({
    super.key,
    required this.theme,
    required this.habitName,
    required this.glyph,
    required this.when,
    required this.number,
    required this.epicTitle,
  });

  final UiTheme theme;
  final String habitName;
  final String glyph;
  final DateTime when;
  final int number;
  final String? epicTitle;

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  @override
  Widget build(BuildContext context) {
    final d = '${when.day} ${_months[when.month - 1]} ${when.year} · '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Frosted(
      theme: theme,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(glyph, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ladrillo $number · $habitName',
                  style: theme.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(d, style: theme.bodySoft.copyWith(fontSize: 11.5)),
              if (epicTitle != null) ...[
                const SizedBox(height: 4),
                Text('◈ $epicTitle',
                    style: TextStyle(
                        color: theme.accent, fontSize: 11.5, letterSpacing: 0.4)),
              ],
            ],
          ),
        ],
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
