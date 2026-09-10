import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/landmarks.dart';
import 'papyrus.dart';
import '../fx/sensory.dart';
import 'legend_card.dart';
import 'style.dart';

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
                    Icon(
                      _icons[mark.tier],
                      size: 40,
                      color: t.fg.withValues(alpha: 0.88),
                    ),
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

/// Para qué fue una pieza, al tocarla.
///
/// La leyenda se escribe aquí mismo. Antes esto abría una hoja por debajo con
/// su título, su explicación y sus botones de guardar y cancelar: una pantalla
/// entera para una frase de sesenta letras que ya estaba en pantalla. Ahora el
/// texto se convierte en el campo y se escribe donde se lee.
///
/// Y no hay botón de guardar. Tocar fuera guarda, que es lo que iba a pasar de
/// todas formas.
class StoneCard extends StatefulWidget {
  const StoneCard({
    super.key,
    required this.theme,
    required this.when,
    required this.number,
    required this.label,
    required this.onWrite,
  });

  final UiTheme theme;
  final DateTime when;
  final int number;
  final String? label;

  /// La leyenda nueva. Vacía quiere decir que se borró.
  final void Function(String text) onWrite;

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String formatDate(DateTime w) =>
      '${w.day} ${_months[w.month - 1]} ${w.year} · '
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';

  @override
  State<StoneCard> createState() => _StoneCardState();
}

class _StoneCardState extends State<StoneCard> {
  late final TextEditingController _text = TextEditingController(
    text: widget.label ?? '',
  );
  final FocusNode _focus = FocusNode();
  bool _writing = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    if (_writing) return;
    Sensory.instance.tick();
    setState(() => _writing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _close() {
    if (!_writing) return;
    final t = _text.text.trim();
    if (t != (widget.label ?? '')) {
      Sensory.instance.tick();
      widget.onWrite(t);
    }
    setState(() => _writing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final has = widget.label != null && widget.label!.trim().isNotEmpty;
    return LegendCard(
      theme: t,
      onTap: _writing ? null : _open,
      header: 'PIEZA ${widget.number} · ${StoneCard.formatDate(widget.when)}',
      child: _writing
          ? TextField(
              controller: _text,
              focusNode: _focus,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _close(),
              onTapOutside: (_) => _close(),
              textCapitalization: TextCapitalization.sentences,
              cursorColor: t.accent,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
                hintText: 'qué fue',
                hintStyle: t.bodySoft.copyWith(fontSize: 13.5, height: 1.25),
                border: InputBorder.none,
              ),
            )
          : Text(
              has ? widget.label! : 'escribir una leyenda',
              // Sin color cuando hay leyenda: lo pone la tarjeta. Cuando no la
              // hay, pardo flojo — es una frase que falta, no un aviso.
              style: TextStyle(
                fontSize: 13.5,
                height: 1.25,
                fontWeight: has ? FontWeight.w500 : FontWeight.w400,
                color: has ? null : LegendCard.pending(t),
              ),
            ),
    );
  }
}

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
    return LayoutBuilder(
      builder: (context, cons) {
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
      },
    );
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
      old.travel != travel ||
      old.length != length ||
      old.marks.length != marks.length;
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
