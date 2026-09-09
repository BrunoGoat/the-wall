import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/constellations.dart';
import '../model/store.dart';
import 'style.dart';

/// El cuaderno del observatorio: qué se ha reconocido del cielo y qué no.
///
/// Es del valle entero y no de un pueblo, porque el cielo es el mismo desde
/// todos. Se abre tocando cualquier cúpula.
class SkySheet extends StatelessWidget {
  const SkySheet({
    super.key,
    required this.store,
    required this.theme,
    this.justFound,
  });

  final Store store;
  final UiTheme theme;

  /// La que se acaba de reconocer, si esta hoja se abrió por eso.
  final Constellation? justFound;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final found = store.sky.length;
    return SheetSurface(
      theme: t,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fg.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              justFound == null ? 'EL CIELO' : 'ANOTADA',
              style: t.label.copyWith(color: t.accent),
            ),
            const SizedBox(height: 6),
            Text(
              justFound != null
                  ? '${justFound!.name}. ${justFound!.blurb}'
                  : 'Se ve una por noche, y sólo de noche. $found de '
                        '${constellations.length}.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final c in constellations)
                    _Row(
                      theme: t,
                      what: c,
                      known: store.sawIt(c.id),
                      fresh: c.id == justFound?.id,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.what,
    required this.known,
    required this.fresh,
  });

  final UiTheme theme;
  final Constellation what;
  final bool known;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            height: 62,
            child: CustomPaint(
              painter: _Figure(
                what: what,
                color: known ? t.accent : t.fg.withValues(alpha: 0.20),
                known: known,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      known ? what.name : '· · ·',
                      style: t.body.copyWith(
                        fontSize: 14.5,
                        color: known ? t.fg : t.fgFaint,
                      ),
                    ),
                    if (fresh) ...[
                      const SizedBox(width: 8),
                      Text(
                        'NUEVA',
                        style: t.label.copyWith(fontSize: 8.5, color: t.accent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  known
                      ? '${what.latin} · ${what.blurb}'
                      : 'Todavía no la reconociste.',
                  style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La figura, dibujada de sus coordenadas reales.
///
/// Del plano tangente que ya tiene medido, que es la misma forma que se ve en
/// el cielo. Sin reconocer, sólo los puntos: la gracia es reconocerla arriba,
/// y una silueta completa aquí sería contestar la pregunta desde el cuaderno.
class _Figure extends CustomPainter {
  const _Figure({required this.what, required this.color, required this.known});

  final Constellation what;
  final Color color;
  final bool known;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = what.shape;
    var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (final (x, y) in shape) {
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
    final span = math.max(math.max(x1 - x0, y1 - y0), 1e-6);
    final k = math.min(size.width, size.height) * 0.86 / span;
    // El este a la derecha y el norte arriba, que es como se mira una carta.
    Offset at(int i) => Offset(
      size.width / 2 - (shape[i].$1 - (x0 + x1) / 2) * k,
      size.height / 2 - (shape[i].$2 - (y0 + y1) / 2) * k,
    );

    if (known) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.45);
      for (var i = 0; i + 1 < what.lines.length; i += 2) {
        canvas.drawLine(at(what.lines[i]), at(what.lines[i + 1]), line);
      }
    }
    final dot = Paint()..color = color;
    for (var i = 0; i < shape.length; i++) {
      final mag = what.stars[i].mag;
      final bright = ((3.2 - mag) / 4.6).clamp(0.22, 1.0);
      canvas.drawCircle(at(i), 0.9 + 1.6 * bright, dot);
    }
  }

  @override
  bool shouldRepaint(_Figure old) =>
      old.what.id != what.id || old.color != color || old.known != known;
}
