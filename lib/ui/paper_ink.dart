import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/findings.dart';
import 'board_plan.dart';

/// Lo que lleva escrito una hoja.
///
/// Se maqueta en un rectángulo plano de [box] píxeles y de ahí lo recoge la
/// homografía, que lo planta sobre las cuatro esquinas de la hoja en la
/// pantalla. Por eso aquí no hay ni cámara ni perspectiva: esto es la hoja
/// vista de frente, y torcerla es asunto de quien la clava.
///
/// Hay dos maquetaciones, la de la hoja clavada y la de la hoja descolgada, y
/// se cruzan al abrirla. Las dos caben en el mismo rectángulo a propósito: la
/// hoja crece por igual de ancho y de alto, así que lo que cambia no es el
/// sitio sino cuánto se cuenta.
class PaperInk {
  PaperInk(this.notice) {
    _lay();
  }

  final Notice notice;

  /// El rectángulo en el que se maqueta. Su proporción es la de la hoja
  /// ([BoardPlan.paperW] contra [BoardPlan.paperH]), o el texto saldría
  /// estirado.
  static const Size box = Size(300, 230);
  static const double pad = 20;

  late final TextPainter _saidShut, _saidOpen, _becauseShut, _becauseOpen;
  TextPainter? _more;

  void _lay() {
    final ancho = box.width - pad * 2;
    _saidShut = _paint(notice.said, 17, FontWeight.w700, 1.0, 3, ancho);
    _saidOpen = _paint(notice.said, 15.5, FontWeight.w700, 1.0, 3, ancho);
    _becauseShut = _paint(
      notice.because,
      11.5,
      FontWeight.w400,
      0.72,
      3,
      ancho,
    );
    _becauseOpen = _paint(
      notice.because,
      10.5,
      FontWeight.w400,
      0.74,
      3,
      ancho,
    );
    final more = notice.more;
    if (more != null) {
      _more = _paint(more, 8.6, FontWeight.w400, 0.6, 4, ancho);
    }
  }

  static TextPainter _paint(
    String text,
    double size,
    FontWeight weight,
    double alpha,
    int lines,
    double width,
  ) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: BoardPlan.ink.withValues(alpha: alpha),
        fontSize: size,
        height: 1.28,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: width);

  /// Pinta la hoja. [open] va de 0 (clavada) a 1 (descolgada), y [detail] dice
  /// cuánto texto se gana a la distancia a la que está: de lejos una hoja es
  /// una mancha clara sobre madera, que es lo que es de verdad.
  void paint(Canvas canvas, double open, double detail) {
    if (detail <= 0.02) return;
    final abierta = Curves.easeOutCubic.transform(open.clamp(0.0, 1.0));
    if (abierta < 0.999) {
      _cara(canvas, _saidShut, _becauseShut, (1 - abierta) * detail, 0);
    }
    if (abierta > 0.001) {
      _cara(canvas, _saidOpen, _becauseOpen, abierta * detail, abierta);
    }
  }

  void _cara(
    Canvas canvas,
    TextPainter said,
    TextPainter because,
    double alpha,
    double abierta,
  ) {
    if (alpha <= 0.02) return;
    final capa = alpha < 0.99;
    if (capa) {
      canvas.saveLayer(
        Offset.zero & box,
        Paint()..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
    var y = pad;
    // La chincheta, en el mismo sitio en las dos maquetaciones para que no
    // salte al abrir.
    canvas.drawCircle(
      const Offset(pad + 4.5, pad + 4.5),
      4.5,
      Paint()..color = const Color(0xFF9C4A3C),
    );
    canvas.drawCircle(
      const Offset(pad + 3, pad + 3),
      1.6,
      Paint()..color = const Color(0x55FFFFFF),
    );
    y += 17;

    said.paint(canvas, Offset(pad, y));
    y += said.height + 7;
    because.paint(canvas, Offset(pad, y));
    y += because.height;

    if (abierta > 0.02) {
      final hueco = box.height - pad - y;
      if (notice.bars.isNotEmpty && hueco > 34) {
        y += 8;
        final alto = math.min(hueco - 10, notice.ticks.isEmpty ? 44.0 : 56.0);
        canvas.save();
        canvas.translate(pad, y);
        _bars(canvas, Size(box.width - pad * 2, alto));
        canvas.restore();
        y += alto + 6;
      }
      final more = _more;
      if (more != null && box.height - pad - y > more.height) {
        canvas.drawLine(
          Offset(pad, y),
          Offset(box.width - pad, y),
          Paint()..color = BoardPlan.ink.withValues(alpha: 0.14),
        );
        more.paint(canvas, Offset(pad, y + 6));
      }
    }
    if (capa) canvas.restore();
  }

  /// Las barras: cada una es un número del que salió la frase de arriba, y las
  /// oscuras son las que la frase señala.
  void _bars(Canvas canvas, Size size) {
    final bars = notice.bars;
    if (bars.isEmpty) return;
    final rotula = notice.ticks.length == bars.length;
    final pie = rotula ? 13.0 : 0.0;
    final h = size.height - pie - 2;
    final hueco = bars.length > 14 ? 1.2 : 3.0;
    final w = (size.width - hueco * (bars.length - 1)) / bars.length;
    final flojo = Paint()..color = BoardPlan.ink.withValues(alpha: 0.22);
    final fuerte = Paint()..color = BoardPlan.ink.withValues(alpha: 0.82);
    for (var i = 0; i < bars.length; i++) {
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      final alto = math.max(1.6, h * bars[i].clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + hueco), 2 + h - alto, w, alto),
          Radius.circular(math.min(2.0, w / 2)),
        ),
        on ? fuerte : flojo,
      );
    }
    canvas.drawLine(
      Offset(0, h + 2.5),
      Offset(size.width, h + 2.5),
      Paint()..color = BoardPlan.ink.withValues(alpha: 0.2),
    );
    if (!rotula) return;
    for (var i = 0; i < bars.length; i++) {
      final text = notice.ticks[i];
      if (text.isEmpty) continue;
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: BoardPlan.ink.withValues(alpha: on ? 0.8 : 0.45),
            fontSize: bars.length > 8 ? 6.4 : 7.6,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w * (bars.length > 8 ? 1.0 : 1.6));
      tp.paint(canvas, Offset(i * (w + hueco) + (w - tp.width) / 2, h + 5));
    }
  }
}
