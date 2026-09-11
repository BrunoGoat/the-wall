import 'package:flutter/material.dart';

import 'style.dart';

/// La tarjeta de una leyenda.
///
/// Recibe la cabecera ya escrita y el cuerpo ya montado —un texto si se está
/// leyendo, un campo si se está escribiendo— porque leer una leyenda y
/// escribirla son la misma cosa vista dos veces, y tienen que verse igual.
///
/// Se probaron cinco materiales y quedó éste: un bloque teñido con el color de
/// la hora, esquinas apenas redondeadas, y la cabecera arriba a la izquierda
/// diciendo qué pieza es y cuándo se puso.
class LegendCard extends StatelessWidget {
  const LegendCard({
    super.key,
    required this.theme,
    required this.header,
    required this.child,
    this.onTap,
  });

  final UiTheme theme;
  final String header;
  final Widget child;
  final VoidCallback? onTap;

  /// Lo ancho que puede ponerse. De canto a canto tapaba el pueblo del que
  /// estaba hablando.
  static const double ancho = 300;

  /// De qué color va lo que todavía no se escribió.
  ///
  /// Pardo y no del color de la hora: en naranja parecía un aviso, y no lo es
  /// — es una frase que falta, y una frase que falta se escribe en tinta
  /// floja. De noche el mismo pardo pero aclarado, o sobre el bloque oscuro no
  /// se lee.
  /// El color de la leyenda que todavía no escribiste.
  ///
  /// Sale de la paleta de la hora, como todo lo demás: era un marrón fijo, y a
  /// las tres de la mañana un marrón de mediodía es una mancha que no es de
  /// aquí. Un paso hacia el acento y nada más — el naranja de antes cantaba
  /// demasiado para lo que es: un hueco esperando, no un aviso.
  static Color pending(UiTheme t) =>
      Color.lerp(t.fgSoft, t.accent, 0.28)!.withValues(alpha: 0.85);

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final cuerpo = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ancho),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          color: Color.lerp(t.panelStrong, t.accent, t.dark ? 0.16 : 0.13),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                header,
                style: t.label.copyWith(fontSize: 8.5, letterSpacing: 1.2),
              ),
              const SizedBox(height: 5),
              // El cuerpo llega sin color y lo pone la tarjeta: quien lo monta
              // no sabe sobre qué va a caer.
              DefaultTextStyle.merge(
                style: TextStyle(color: t.fg),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return cuerpo;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cuerpo,
    );
  }
}
