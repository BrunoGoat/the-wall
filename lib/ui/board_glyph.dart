import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El tablón de la plaza, dibujado como icono.
///
/// Estaba puesta una chincheta, que es lo que se clava en un tablón pero no es
/// el tablón: el botón prometía una cosa y al otro lado había otra. Esto es lo
/// mismo que hay en la plaza —dos postes hincados, la plancha y el tejadito a
/// dos aguas con su alero— reducido a lo que se distingue a veinte píxeles.
///
/// Las medidas salen de las del modelo y no de la nada: la plancha es más
/// ancha que alta, el tejado vuela por los lados y los postes asoman por
/// debajo, que es la silueta por la que se reconoce desde el valle.
class BoardGlyph extends StatelessWidget {
  const BoardGlyph({
    super.key,
    required this.color,
    this.size = 20,
    this.shadows,
  });

  final Color color;
  final double size;

  /// El mismo halo que llevan los iconos de al lado, para que un botón no se
  /// lea sobre el cielo y el de al lado no.
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BoardGlyphPainter(color, shadows),
  );
}

class _BoardGlyphPainter extends CustomPainter {
  _BoardGlyphPainter(this.color, this.shadows);

  final Color color;
  final List<Shadow>? shadows;

  @override
  void paint(Canvas canvas, Size size) {
    // Todo se dibuja en una caja de veinte y se escala: así las proporciones
    // no dependen del tamaño al que se pida el icono.
    final k = size.width / 20;
    canvas.save();
    canvas.scale(k);

    const trazo = 1.25;
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trazo
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    // El tejadito a dos aguas. El alero vuela bastante por los lados y la
    // pendiente es poca, como la del modelo: con el faldón acabando justo en
    // la esquina de la plancha, el triángulo se cerraba contra ella y lo que
    // se leía era una casa.
    final tejado = Path()
      ..moveTo(2.2, 7.2)
      ..lineTo(10, 4.7)
      ..lineTo(17.8, 7.2);

    // La plancha, más ancha que alta.
    final plancha = RRect.fromLTRBR(
      3.9,
      7.2,
      16.1,
      14.4,
      const Radius.circular(0.7),
    );

    // Las patas. Sólo el trozo que asoma por debajo: los postes siguen dentro
    // de la plancha, pero pintarlos ahí cruzaba dos rayas por encima de los
    // papeles y a veinte píxeles eso es suciedad, no un poste.
    final patas = Path()
      ..moveTo(6.6, 14.4)
      ..lineTo(6.6, 18.2)
      ..moveTo(13.4, 14.4)
      ..lineTo(13.4, 18.2);

    final armazon = Path()
      ..addPath(tejado, Offset.zero)
      ..addRRect(plancha)
      ..addPath(patas, Offset.zero);

    for (final s in shadows ?? const <Shadow>[]) {
      // El desenfoque va en unidades de la caja, y con tope: doce píxeles de
      // halo sobre un icono de veinte lo convierten en una mancha.
      final blur = math.min(s.blurRadius / k, 3.2);
      if (blur <= 0) continue;
      canvas.drawPath(
        armazon.shift(s.offset / k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trazo
          ..color = s.color
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
      );
    }

    canvas.drawPath(tejado, linea);
    canvas.drawRRect(plancha, linea);
    canvas.drawPath(patas, linea);

    // Las dos hojas clavadas, macizas y a media tinta: son el detalle que dice
    // de qué es el botón, no la forma por la que se reconoce. A trazo se
    // perdían contra el borde de la plancha.
    // Y van torcidas, cada una para su lado: es lo que separa un tablón de una
    // casa con dos ventanas.
    final tinta = Paint()..color = color.withValues(alpha: color.a * 0.55);
    for (final (r, giro) in [
      (const Rect.fromLTWH(5.9, 8.8, 3.7, 4.0), -0.10),
      (const Rect.fromLTWH(10.4, 8.6, 3.7, 4.0), 0.12),
    ]) {
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(giro);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height),
        tinta,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoardGlyphPainter old) =>
      old.color != color || old.shadows != shadows;
}
