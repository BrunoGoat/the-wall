import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/findings.dart';
import '../model/appearance.dart';
import 'board_plan.dart';
import 'note_font.dart';

/// Lo que lleva escrito una hoja.
///
/// Se maqueta en un rectángulo plano de [box] píxeles y de ahí lo recoge la
/// homografía, que lo planta sobre las cuatro esquinas de la hoja en la
/// pantalla. Por eso aquí no hay ni cámara ni perspectiva: esto es la hoja
/// vista de frente, y torcerla es asunto de quien la clava.
///
/// **Una sola maquetación.** Antes había dos —la de la hoja clavada y la de
/// la descolgada— y se cruzaban al abrirla. Eso hacía que durante el cruce se
/// vieran las dos frases, una encima de la otra y las dos a medias, que es
/// exactamente lo que parece papel transparente. Ahora el texto es el mismo
/// clavada que descolgada, y lo único que cambia al descolgarla es lo que se
/// añade debajo: las barras y el párrafo de más, que aparecen porque hay sitio
/// y porque ahora se puede leer.
///
/// El aire es de cartel de bando y no de nota adhesiva: un filete alrededor,
/// el titular espaciado con su raya debajo, y tinta parda.
class PaperInk {
  PaperInk(this.notice, {NoteFont? font, double? scale})
    : font = _resolve(
        notice,
        font ??
            NoteFont.porNombre(
              notice.kind == NoticeKind.pueblo
                  ? Appearance.instance.villageFont
                  : Appearance.instance.noteFont,
            ) ??
            NoteFont.sistema,
      ),
      scale =
          scale ??
          (notice.kind == NoticeKind.pueblo
              ? Appearance.instance.villageScale
              : Appearance.instance.noteScale) {
    _lay();
  }

  /// «Varias manos» no es una letra: es que a cada papel le toque la suya.
  ///
  /// Un tablón de plaza lo escriben veinte vecinos, y con una sola letra para
  /// todo se lee como veinte copias de la misma nota. La mano sale del nombre
  /// del papel, igual que su hueco y su inclinación, así que la de la cabra
  /// está siempre escrita por la misma persona.
  static NoteFont _resolve(Notice n, NoteFont pedida) =>
      pedida == NoteFont.varias ? NoteFont.handFor(n) : pedida;

  final Notice notice;

  /// Con qué letra, y de qué cuerpo. Se leen de los ajustes al maquetar, así
  /// que cambiar de letra pide rehacer las hojas — no hay nada que actualizar
  /// en caliente aquí dentro.
  final NoteFont font;
  final double scale;

  /// Un bando del pueblo se lee de corrido y no como un titular con su
  /// remate.
  ///
  /// «Se perdió una cabra» y «atiende por Nube» no son una afirmación y su
  /// prueba: son una sola frase que alguien escribió en un papel y partió en
  /// dos porque cabía mejor. Las notas del tablón sí son lo otro —lo que el
  /// pueblo dice de vos, y debajo las cuentas de las que lo sacó— y ahí la
  /// raya separa dos cosas que de verdad son distintas.
  bool get corrido => notice.kind == NoticeKind.pueblo;

  /// El rectángulo en el que se maqueta. Su proporción es la de la hoja
  /// ([BoardPlan.paperW] contra [BoardPlan.paperH]), o el texto saldría
  /// estirado.
  static const Size box = Size(300, 230);
  static const double pad = 18;

  /// Cómo se maqueta, en un solo sitio.
  ///
  /// Público porque hay un test que mide si a los cientos de bandos escritos a
  /// mano les cabe lo que dicen, y para que esa medida signifique algo tiene
  /// que hacerse con estos números y no con unos parecidos. Un bando que no
  /// cabe sale recortado con puntos suspensivos, y con un catálogo que crece a
  /// mano no hay manera de verlo a ojo.
  static const double saidSize = 15.5, becauseSize = 10.5;
  static const int saidLines = 4, becauseLines = 4;

  /// Y el de corrido, que es todo el papel para una sola frase.
  static const double plainSize = 13, plainLines = 8;
  static const double lineHeight = 1.26;
  static double get textWidth => box.width - pad * 2;

  /// No son `final`: si el texto no entra se vuelve a maquetar más chico, y
  /// eso es reasignarlas.
  late TextPainter _said, _because;

  /// El alto del que dispone el texto dentro del papel.
  static double get textHeight => box.height - pad * 2 - 4;

  void _lay() {
    // Se maqueta, y si no entra se busca el tamaño más grande que sí entre.
    //
    // Hace falta desde que la letra y el cuerpo los elige quien usa la app:
    // una manuscrita de caja alta al máximo del deslizador puede pedir el
    // triple de sitio que la de fábrica, y sin esto la mitad de los bandos
    // saldrían cortados con puntos suspensivos. Un papel de un tablón se
    // escribe más chico cuando hay mucho que decir, que es exactamente esto.
    //
    // Se busca por mitades y no bajando a ojo. Bajar a ojo se pasa de largo
    // —al encoger cambian los cortes de línea y se gana una línea entera de
    // golpe—, y pasarse de largo tiene una consecuencia fea: que pedir más
    // tamaño dé menos. Con «Otra mano» en el tope, el deslizador escribía más
    // chico que a media altura. Buscando por mitades, el tamaño que sale es
    // siempre el mayor que cabe, así que subir el deslizador nunca puede
    // escribir más chico.
    _layAt(1);
    shrunk = 1;
    if (_alto <= textHeight) return;

    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 8; i++) {
      final k = (lo + hi) / 2;
      _layAt(k);
      if (_alto <= textHeight) {
        lo = k;
      } else {
        hi = k;
      }
    }
    // La última prueba pudo ser una que no entraba: se deja puesta la mayor
    // que sí.
    _layAt(lo);
    shrunk = lo;
  }

  /// Cuánto hubo que encoger el texto para que entrara: 1 es que entró tal
  /// cual. Sirve para saber si el deslizador del tamaño todavía hace algo o si
  /// el papel ya está pidiendo lo contrario.
  double shrunk = 1;

  double get _alto => _said.height + (corrido ? 0 : 13 + _because.height);

  void _layAt(double k) {
    final ancho = textWidth;
    if (corrido) {
      _said = _paint(
        '${notice.said} ${notice.because}',
        plainSize * k,
        FontWeight.w500,
        0.92,
        plainLines.round(),
        ancho,
        0,
      );
      _because = _paint('', becauseSize, FontWeight.w400, 0, 1, ancho, 0);
      return;
    }
    _said = _paint(
      notice.said,
      saidSize * k,
      FontWeight.w700,
      1.0,
      saidLines,
      ancho,
      0.15,
    );
    _because = _paint(
      notice.because,
      becauseSize * k,
      FontWeight.w400,
      0.74,
      becauseLines,
      ancho,
      0,
    );
  }

  TextPainter _paint(
    String text,
    double size,
    FontWeight weight,
    double alpha,
    int lines,
    double width,
    double spacing,
  ) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: font.family,
        color: BoardPlan.ink.withValues(alpha: alpha),
        fontSize: size * font.scale * scale,
        height: lineHeight,
        letterSpacing: spacing,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: width);

  /// Si al papel no le cabe lo que lleva escrito, ni encogiéndolo.
  bool get overflows =>
      _said.didExceedMaxLines ||
      _because.didExceedMaxLines ||
      _alto > textHeight;

  /// Pinta la hoja. [detail] dice cuánto texto se gana a la distancia a la que
  /// está: de lejos una hoja es una mancha clara sobre madera, que es lo que es
  /// de verdad.
  ///
  /// Ya no hay dos estados. La nota enseña todo lo que tiene esté clavada o
  /// descolgada, y descolgarla sirve para poder leerla, no para que aparezca
  /// nada. El párrafo que había debajo del gráfico se fue entero: contaba cómo
  /// leer el gráfico, y un gráfico que necesita que le expliquen cómo leerlo
  /// está mal hecho.
  void paint(Canvas canvas, double detail) {
    if (detail <= 0.02) return;
    final capa = detail < 0.99;
    if (capa) {
      canvas.saveLayer(
        Offset.zero & box,
        Paint()..color = Colors.white.withValues(alpha: detail.clamp(0.0, 1.0)),
      );
    }

    // El filete del bando, por dentro del filo.
    canvas.drawRect(
      Rect.fromLTWH(9, 9, box.width - 18, box.height - 18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = BoardPlan.ink.withValues(alpha: 0.2),
    );

    var y = pad + 4;
    _said.paint(canvas, Offset(pad, y));
    y += _said.height;

    if (!corrido) {
      y += 6;
      // La raya bajo el titular, que es lo que separa un bando de una notita.
      canvas.drawLine(
        Offset(pad, y),
        Offset(box.width - pad, y),
        Paint()..color = BoardPlan.ink.withValues(alpha: 0.28),
      );
      y += 7;
      _because.paint(canvas, Offset(pad, y));
      y += _because.height;
    }

    if (!corrido) {
      // El gráfico se ve desde el principio, clavada y todo. Antes salía sólo
      // al descolgar la nota, y era lo único que de verdad hacía falta ver: la
      // frase de arriba dice qué pasa y el gráfico dice de dónde sale, y las
      // dos juntas caben en el papel sin tener que tocarlo.
      final hueco = box.height - pad - y;
      if (notice.bars.isNotEmpty && hueco > 34) {
        y += 8;
        final alto = math.min(hueco - 6, notice.ticks.isEmpty ? 46.0 : 58.0);
        canvas.save();
        canvas.translate(pad, y);
        _bars(canvas, Size(box.width - pad * 2, alto));
        canvas.restore();
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
