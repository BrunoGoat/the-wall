import 'package:flutter/material.dart';

import 'habit_sigil.dart';
import 'style.dart';

/// El nombre del pueblo al que acabás de entrar, puesto encima de la escena y
/// quitado solo.
///
/// Se probaron cinco maneras y quedó ésta: grande, en el medio y sin caja
/// ninguna, como el rótulo de un capítulo. Se dibuja sobre toda la pantalla y
/// no atrapa ningún toque.
class TownSignOverlay extends StatefulWidget {
  const TownSignOverlay({
    super.key,
    required this.name,
    required this.symbol,
    required this.theme,
    this.life = const Duration(milliseconds: 1700),
  });

  final String name;
  final String symbol;
  final UiTheme theme;

  /// Lo que dura de punta a punta: entrada, espera y salida.
  final Duration life;

  @override
  State<TownSignOverlay> createState() => _TownSignOverlayState();
}

class _TownSignOverlayState extends State<TownSignOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.life,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Un solo reloj de cero a uno para toda la vida del cartel, y de él salen
  /// la entrada y la salida. Con dos controladores habría que coordinarlos, y
  /// lo que se quiere comparar aquí es el diseño, no la mecánica.
  (double, double) _tramos(double t) {
    // Entra rápido y se va rápido: es un rótulo, no una animación. Un segundo
    // y pico de punta a punta, y el desvanecido ocupa el último tercio.
    const entra = 0.14, sale = 0.30;
    final a = Curves.easeOutCubic.transform((t / entra).clamp(0.0, 1.0));
    final b = Curves.easeInCubic.transform(
      ((t - (1 - sale)) / sale).clamp(0.0, 1.0),
    );
    return (a, b);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final (entra, sale) = _tramos(_c.value);
          return Opacity(
            opacity: (entra * (1 - sale)).clamp(0.0, 1.0),
            child: _sello(entra, sale),
          );
        },
      ),
    );
  }

  // El rótulo: grande, en el medio y sin caja ninguna.-----------------
  Widget _sello(double entra, double sale) {
    final t = widget.theme;
    return Align(
      alignment: const Alignment(0, -0.16),
      child: Transform.scale(
        scale: 1.10 - 0.10 * entra + 0.04 * sale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HabitSigil(symbol: widget.symbol, color: t.accent, size: 26),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: t.fg,
                  fontSize: 31,
                  height: 1.1,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 0.6,
                  shadows: t.halo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
