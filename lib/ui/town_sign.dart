import 'dart:math' as math;

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
    this.life = const Duration(milliseconds: 1150),
    this.leaving = false,
    this.onGone,
  });

  final String name;
  final String symbol;
  final UiTheme theme;

  /// Lo que dura de punta a punta: entrada, espera y salida.
  final Duration life;

  /// Que alguien movió la cámara y el cartel sobra. Se va en un suspiro, pero
  /// yéndose: no se quita de golpe.
  final bool leaving;

  /// Cuando ya no queda nada que ver y se puede sacar del árbol.
  final VoidCallback? onGone;

  @override
  State<TownSignOverlay> createState() => _TownSignOverlayState();
}

class _TownSignOverlayState extends State<TownSignOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.life,
  )..forward();

  /// La salida a destiempo, la de cuando alguien mueve la cámara.
  ///
  /// Va aparte del reloj de la vida del cartel y no adelantándolo, porque no
  /// es lo mismo: el final normal se va en el último tercio largo, y éste
  /// tiene que quitarse de en medio ya, sin llegar a parecer un parpadeo.
  late final AnimationController _fuera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.leaving) _irse();
  }

  @override
  void didUpdateWidget(TownSignOverlay old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _irse();
  }

  void _irse() {
    _fuera.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onGone?.call();
    });
  }

  @override
  void dispose() {
    _fuera.dispose();
    _c.dispose();
    super.dispose();
  }

  /// Un solo reloj de cero a uno para toda la vida del cartel, y de él salen
  /// la entrada y la salida. Con dos controladores habría que coordinarlos, y
  /// lo que se quiere comparar aquí es el diseño, no la mecánica.
  (double, double) _tramos(double t) {
    // Entra rápido y se va rápido: es un rótulo, no una animación. Poco más de
    // un segundo de punta a punta, y el desvanecido ocupa el último tercio
    // largo — lo justo para leer un nombre y que se quite de en medio.
    const entra = 0.13, sale = 0.34;
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
        animation: Listenable.merge([_c, _fuera]),
        builder: (context, _) {
          final (entra, sale) = _tramos(_c.value);
          // La salida a destiempo se multiplica con la normal en vez de
          // sustituirla: si llegan juntas, la que esté más avanzada manda y el
          // cartel no vuelve a aclararse para volver a irse.
          final corte = Curves.easeInCubic.transform(_fuera.value);
          final visible = (entra * (1 - sale) * (1 - corte)).clamp(0.0, 1.0);
          if (visible <= 0) return const SizedBox.shrink();
          return Opacity(
            opacity: visible,
            child: _sello(entra, math.max(sale, corte)),
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
