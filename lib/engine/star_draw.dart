import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'shooting_star.dart';

/// Dónde cae en pantalla un punto del cielo. Lo pone quien llama, porque la
/// cuenta del cielo es del pintor de la escena y el valle y el tablón arman su
/// proyector cada uno por su cuenta.
typedef SkyAim = Offset? Function(double az, double el);

/// Cómo se pinta una fugaz.
///
/// Aparte del pintor del valle porque el tablón de la plaza dibuja su propio
/// cielo y quiere exactamente esto mismo. Cuando eran dos copias, mejorar la
/// del valle dejaba la del tablón como estaba.
///
/// Son dos cosas, y en dos sitios distintos del orden de pintado: [sky] va con
/// el cielo, detrás del pueblo; [land] va al final del todo, porque es luz que
/// cae sobre lo que ya está pintado.
class StarDraw {
  const StarDraw._();

  /// El color de la luz. Frío y con algo de verde, como el de una fugaz de
  /// verdad: el blanco puro sobre un cielo azul de noche no se lee como luz,
  /// se lee como un agujero en la imagen.
  static const Color core = Color(0xFFF2F8FF);
  static const Color halo = Color(0xFFA9CBFF);
  static const Color far = Color(0xFF6E93E8);

  /// La estrella: su estela, su cabeza y el destello de la cabeza.
  static void sky(
    Canvas canvas,
    Size size,
    SkyAim aim,
    double horizonY,
    ShootingStar star,
    double nightAlpha,
  ) {
    final glow = star.glow * nightAlpha;
    if (glow <= 0.012) return;

    Offset? en(double k) {
      final a = star.aim(k);
      return a == null ? null : aim(a.$1, a.$2);
    }

    // La estela arrastra casi un tercio del vuelo: sobre cinco segundos son
    // más de un segundo de cola, y eso es lo que la hace grande. Con la cola
    // corta de antes, lo que cruzaba era un punto.
    const cola = 0.30;
    final chispa = size.shortestSide;

    // Tres pasadas sobre la misma estela: el resplandor ancho y desenfocado,
    // el cuerpo, y el filo blanco de dentro. Una sola línea no brilla; brillar
    // es tener un borde encendido dentro de algo difuso.
    //
    // La desenfocada va en seis tramos y las otras en veintiséis. No es un
    // descuido: desenfocar cuesta, y hacerlo veintiséis veces por fotograma se
    // nota en un teléfono. Difuminada, seis tramos y veintiséis se ven igual.
    for (final (tramos, ancho, alfa, desenfoque) in [
      (6, 0.055 * chispa, 0.20, 7.0),
      (26, 0.016 * chispa, 0.42, 0.0),
      (26, 0.006 * chispa, 0.95, 0.0),
    ]) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      if (desenfoque > 0) {
        paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, desenfoque);
      }
      for (var i = 0; i < tramos; i++) {
        final a = en(star.u - cola * (i + 1) / tramos);
        final b = en(star.u - cola * i / tramos);
        if (a == null || b == null) continue;
        if (a.dy > horizonY && b.dy > horizonY) continue;
        // Se afina y se apaga hacia atrás, que es lo que la hace cola.
        final k = 1 - i / tramos;
        final f = k * k;
        paint
          ..color = (desenfoque > 0 ? halo : core).withValues(
            alpha: (glow * alfa * f).clamp(0.0, 1.0),
          )
          ..strokeWidth = math.max(0.6, ancho * math.pow(k, 1.3).toDouble());
        canvas.drawLine(a, b, paint);
      }
    }

    // Las chispas que se van soltando por el camino. Son lo que separa una
    // raya de luz de algo que se está deshaciendo mientras cae.
    for (var i = 1; i <= 7; i++) {
      final k = i / 8;
      final at = en(star.u - cola * k * 0.92);
      if (at == null || at.dy > horizonY) continue;
      final j = (star.id * 31 + i) % 7;
      final lado = Offset(
        math.sin(j * 1.7 + star.u * 2.2) * chispa * 0.010 * k,
        math.cos(j * 2.3 + star.u * 1.7) * chispa * 0.010 * k,
      );
      canvas.drawCircle(
        at + lado,
        chispa * 0.0035 * (1 - k) + 0.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = core.withValues(
            alpha: (glow * 0.75 * (1 - k) * (1 - k)).clamp(0.0, 1.0),
          ),
      );
    }

    final head = en(star.u);
    if (head == null || head.dy > horizonY) return;

    // El resplandor de la cabeza: grande, para que sea imposible no verla.
    final r = chispa * 0.15;
    canvas.drawCircle(
      head,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          head,
          r,
          [
            core.withValues(alpha: 0.55 * glow),
            halo.withValues(alpha: 0.22 * glow),
            far.withValues(alpha: 0.0),
          ],
          const [0.0, 0.30, 1.0],
        ),
    );

    // Y el destello de cuatro puntas, que es lo que la hace una estrella y no
    // una bola. Gira despacio mientras cae.
    _sparkle(canvas, head, chispa * 0.085, star.spin, glow);
    _sparkle(canvas, head, chispa * 0.048, star.spin + math.pi / 4, glow * 0.6);

    canvas.drawCircle(
      head,
      chispa * 0.008,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: glow.clamp(0.0, 1.0)),
    );
  }

  /// Una cruz de cuatro puntas afiladas, del largo [len].
  static void _sparkle(
    Canvas canvas,
    Offset at,
    double len,
    double spin,
    double glow,
  ) {
    if (glow <= 0.01) return;
    final ancho = len * 0.085;
    final p = Path();
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final lado = Offset(-dir.dy, dir.dx) * ancho;
      p
        ..moveTo(at.dx, at.dy)
        ..lineTo(
          at.dx + dir.dx * len * 0.34 + lado.dx,
          at.dy + dir.dy * len * 0.34 + lado.dy,
        )
        ..lineTo(at.dx + dir.dx * len, at.dy + dir.dy * len)
        ..lineTo(
          at.dx + dir.dx * len * 0.34 - lado.dx,
          at.dy + dir.dy * len * 0.34 - lado.dy,
        )
        ..close();
    }
    canvas.drawPath(
      p,
      Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.6)
        ..color = core.withValues(alpha: (0.85 * glow).clamp(0.0, 1.0)),
    );
  }

  /// La luz que echa sobre el pueblo y las montañas.
  ///
  /// No es realista y no pretende serlo: una fugaz de verdad no ilumina nada.
  /// Es luz que barre, que viene de donde viene ella y se mueve con ella, y
  /// está para que uno levante la vista. Sin esto, lo que pasa en el cielo
  /// pasa sólo en el cielo, y mirando al pueblo no te enterás nunca.
  ///
  /// Va después que ella y dura más: cuando la estrella ya se apagó, esto
  /// sigue medio segundo abriéndose y perdiéndose, que es lo que deja la
  /// sensación de que algo pasó.
  static void land(
    Canvas canvas,
    Size size,
    SkyAim aim,
    ShootingStar star,
    double nightAlpha,
  ) {
    final k = star.light * nightAlpha;
    if (k < 0.015) return;
    // Cuando la cabeza ya se apagó, la luz se queda donde estaba y se abre:
    // seguirla hasta el final la sacaría de la pantalla justo mientras se
    // desvanece, y lo que tiene que hacer es deshacerse donde uno la vio.
    final donde = star.aim(math.min(star.u, 0.90));
    if (donde == null) return;
    final at = aim(donde.$1, donde.$2);
    if (at == null) return;

    // Un levantón parejo de toda la escena, flojo: es lo que alcanza a las
    // cordilleras del fondo, que están demasiado lejos del foco para que las
    // toque el degradado.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = far.withValues(alpha: (0.085 * k).clamp(0.0, 1.0)),
    );

    // Y el barrido, desde donde está ella. El pueblo se enciende por el lado
    // que le toca y no entero y por igual, que sería un flash.
    final abre = 0.88 + 0.80 * (1 - star.light);
    final r = size.longestSide * abre;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        // Cae deprisa y luego despacio. Con la caída suave de antes, el prado
        // entero subía por igual y lo que se veía era niebla, no luz: la luz
        // se lee porque hay diferencia entre lo que alcanza y lo que no.
        ..shader = ui.Gradient.radial(
          at,
          r,
          [
            core.withValues(alpha: (0.46 * k).clamp(0.0, 1.0)),
            halo.withValues(alpha: (0.17 * k).clamp(0.0, 1.0)),
            far.withValues(alpha: (0.045 * k).clamp(0.0, 1.0)),
            const Color(0x00000000),
          ],
          const [0.0, 0.12, 0.38, 1.0],
        ),
    );
  }
}
