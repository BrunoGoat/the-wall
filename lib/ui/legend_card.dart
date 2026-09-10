import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'style.dart';

/// De qué está hecha la tarjeta de una leyenda.
///
/// Cinco materiales, y sale uno al azar. Es la misma tarjeta al escribir la
/// leyenda que al volver a leerla —eso ya estaba decidido y no se toca—, así
/// que el material se elige una vez y vale para las dos caras del mismo
/// momento.
enum CardStyle {
  /// La de siempre: un panel esmerilado con la cabecera en versalitas.
  esmerilada,

  /// Un papel: cálido, sin difuminado, con serifas y una pizca torcido.
  papel,

  /// Una etiqueta de las que se atan: filo de color, ojal y esquina cortada.
  etiqueta,

  /// Sin caja ninguna. El texto sobre la escena, con una raya y nada más.
  placa,

  /// Un bloque teñido con el número de la pieza grande y flojo detrás.
  nota;

  static final math.Random _dado = math.Random();

  static CardStyle alAzar() => values[_dado.nextInt(values.length)];

  /// El que se llame así, o nada. Un nombre que esta versión ya no conoce
  /// —porque el diseño se retiró— devuelve nulo a propósito: quien lo tuviera
  /// elegido pasa a ver uno al azar, que es raro pero se entiende, en vez de
  /// una pantalla vacía.
  static CardStyle? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// Cómo se llama en los ajustes.
  String get label => const {
    CardStyle.esmerilada: 'Esmerilada',
    CardStyle.papel: 'Papel',
    CardStyle.etiqueta: 'Etiqueta',
    CardStyle.placa: 'Placa',
    CardStyle.nota: 'Nota',
  }[this]!;
}

/// La tarjeta de una leyenda, en cualquiera de sus cinco materiales.
///
/// Recibe la cabecera ya escrita y el cuerpo ya montado —un texto si se está
/// leyendo, un campo si se está escribiendo— porque lo que cambia entre las
/// cinco es de qué está hecha, no qué dice.
class LegendCard extends StatelessWidget {
  const LegendCard({
    super.key,
    required this.theme,
    required this.style,
    required this.header,
    required this.child,
    this.onTap,
  });

  final UiTheme theme;
  final CardStyle style;
  final String header;
  final Widget child;
  final VoidCallback? onTap;

  /// Lo ancho que puede ponerse. De canto a canto tapaba el pueblo del que
  /// estaba hablando, así que ninguna de las cinco pasa de aquí.
  static const double ancho = 300;

  /// Con qué tinta escribe cada material. El papel escribe en tinta parda
  /// aunque el resto de la interfaz vaya en claro sobre oscuro: es papel.
  Color get _tinta => switch (style) {
    CardStyle.papel =>
      theme.dark ? const Color(0xFFE7DFCC) : const Color(0xFF3B3327),
    _ => theme.fg,
  };

  /// El papel. De noche no se queda gris con la tinta clara encima —eso deja
  /// una nota que no se lee—: se oscurece de verdad y escribe en claro. Y un
  /// papel muy blanco a las tres de la mañana tampoco vale.
  Color get _papelTono =>
      theme.dark ? const Color(0xFF2E2A22) : const Color(0xFFF4EAD4);

  /// El cuerpo lo tiñe la tarjeta y no quien la llama, que no sabe de qué va
  /// a estar hecha.
  Widget _conTinta(Widget kid) => DefaultTextStyle.merge(
    style: TextStyle(color: _tinta),
    child: kid,
  );

  @override
  Widget build(BuildContext context) {
    final cuerpo = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ancho),
      child: switch (style) {
        CardStyle.esmerilada => _esmerilada(),
        CardStyle.papel => _papel(),
        CardStyle.etiqueta => _etiqueta(),
        CardStyle.placa => _placa(),
        CardStyle.nota => _nota(),
      },
    );
    if (onTap == null) return cuerpo;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cuerpo,
    );
  }

  TextStyle get _cabecera =>
      theme.label.copyWith(fontSize: 8.5, letterSpacing: 1.2);

  // --- 1. La de siempre ----------------------------------------------------
  Widget _esmerilada() => Frosted(
    theme: theme,
    radius: 16,
    padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(header, style: _cabecera),
        const SizedBox(height: 4),
        _conTinta(child),
      ],
    ),
  );

  // --- 2. Un papel ---------------------------------------------------------
  Widget _papel() {
    // El papel es papel también de noche: se apaga, no se vuelve azul. Y algo
    // torcido, porque una nota escrita a mano no queda recta.
    final tono = _papelTono;
    final tinta = _tinta;
    return Transform.rotate(
      angle: -0.012,
      child: Container(
        decoration: BoxDecoration(
          color: tono,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.dark ? 0.34 : 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              header,
              style: TextStyle(
                fontFamily: 'Chronicle',
                color: tinta.withValues(alpha: 0.55),
                fontSize: 8.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: tinta.withValues(alpha: 0.16)),
            const SizedBox(height: 7),
            DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Chronicle'),
              child: _conTinta(child),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Una etiqueta -----------------------------------------------------
  Widget _etiqueta() {
    return ClipPath(
      // La esquina de arriba a la derecha cortada, que es lo que hace que una
      // etiqueta parezca una etiqueta y no una tarjeta redondeada más.
      clipper: _Recorte(),
      child: Frosted(
        theme: theme,
        radius: 0,
        strong: true,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: theme.accent),
              const SizedBox(width: 12),
              // El ojal.
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.fg.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 11, 26, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(header, style: _cabecera),
                      const SizedBox(height: 4),
                      _conTinta(child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. Sin caja ---------------------------------------------------------
  Widget _placa() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            header,
            style: _cabecera.copyWith(color: theme.accent, shadows: theme.halo),
          ),
          const SizedBox(height: 6),
          Container(width: 46, height: 1.5, color: theme.accent),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: TextStyle(shadows: theme.halo),
            child: _conTinta(child),
          ),
        ],
      ),
    );
  }

  // --- 5. Un bloque con el número detrás -----------------------------------
  Widget _nota() {
    // El número que va detrás es el primer trozo de la cabecera, que siempre
    // empieza por la pieza. Si algún día no lo hace, no se dibuja: mejor sin
    // marca de agua que con una que mienta.
    final marca = RegExp(r'\d+').firstMatch(header)?.group(0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: Color.lerp(
          theme.panelStrong,
          theme.accent,
          theme.dark ? 0.16 : 0.13,
        ),
        child: Stack(
          children: [
            if (marca != null)
              Positioned(
                right: 8,
                top: -10,
                child: Text(
                  marca,
                  style: TextStyle(
                    color: theme.fg.withValues(alpha: 0.13),
                    fontSize: 58,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(header, style: _cabecera),
                  const SizedBox(height: 5),
                  _conTinta(child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La esquina cortada de la etiqueta.
class _Recorte extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const corte = 16.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - corte, 0)
      ..lineTo(size.width, corte)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}
