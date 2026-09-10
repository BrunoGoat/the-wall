import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'habit_sigil.dart';
import 'style.dart';

/// Cómo se anuncia el pueblo al que acabás de entrar.
///
/// Cinco maneras, y sale una al azar cada vez. Están para elegir: cambian de
/// sitio en la pantalla, de tamaño, de color y de cómo entran, que es todo lo
/// que hay que comparar para decidir cuál de ellas se queda.
enum TownSign {
  /// Grande y en el medio, como el rótulo de un capítulo.
  sello,

  /// Una placa a la izquierda, debajo de la cuenta, que entra desde el borde.
  cartel,

  /// Una cinta angosta que se abre desde el centro hacia los dos lados.
  cinta,

  /// Abajo, chiquito y en versalitas, subiendo desde el botón.
  brote,

  /// Letra por letra, con una raya que se dibuja debajo.
  letras;

  static final math.Random _dado = math.Random();

  static TownSign alAzar() => values[_dado.nextInt(values.length)];

  /// El que se llame así, o nada. Un nombre que esta versión ya no conoce
  /// —porque el diseño se retiró— devuelve nulo a propósito: quien lo tuviera
  /// elegido pasa a ver uno al azar, que es raro pero se entiende, en vez de
  /// una pantalla vacía.
  static TownSign? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// Cómo se llama en los ajustes.
  String get label => const {
    TownSign.sello: 'Sello',
    TownSign.cartel: 'Cartel',
    TownSign.cinta: 'Cinta',
    TownSign.brote: 'Brote',
    TownSign.letras: 'Letras',
  }[this]!;
}

/// El nombre del pueblo, puesto encima de la escena y quitado solo.
///
/// Se dibuja sobre toda la pantalla porque cada variante elige dónde ponerse;
/// no atrapa ningún toque.
class TownSignOverlay extends StatefulWidget {
  const TownSignOverlay({
    super.key,
    required this.name,
    required this.symbol,
    required this.theme,
    required this.sign,
    this.life = const Duration(milliseconds: 2600),
  });

  final String name;
  final String symbol;
  final UiTheme theme;
  final TownSign sign;

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
    const entra = 0.16, sale = 0.20;
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
            child: switch (widget.sign) {
              TownSign.sello => _sello(entra, sale),
              TownSign.cartel => _cartel(entra, sale),
              TownSign.cinta => _cinta(entra, sale),
              TownSign.brote => _brote(entra, sale),
              TownSign.letras => _letras(entra, sale),
            },
          );
        },
      ),
    );
  }

  // --- 1. Un rótulo grande en el medio, sin caja ninguna --------------------
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

  // --- 2. Una placa que entra por el borde izquierdo ------------------------
  Widget _cartel(double entra, double sale) {
    final t = widget.theme;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 152, left: 16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: Offset(-52 + 52 * entra - 26 * sale, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Frosted(
              theme: t,
              radius: 9,
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 3, color: t.accent),
                    const SizedBox(width: 11),
                    HabitSigil(
                      symbol: widget.symbol,
                      color: t.accent,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 9, 14, 9),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: 14,
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  // --- 3. Una cinta que se abre desde el centro -----------------------------
  Widget _cinta(double entra, double sale) {
    final t = widget.theme;
    final tinta = t.accent;
    return Align(
      alignment: const Alignment(0, -0.30),
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          widthFactor: entra.clamp(0.001, 1.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  t.panelStrong.withValues(alpha: 0),
                  t.panelStrong,
                  t.panelStrong,
                  t.panelStrong.withValues(alpha: 0),
                ],
                stops: const [0, 0.22, 0.78, 1],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HabitSigil(symbol: widget.symbol, color: tinta, size: 14),
                const SizedBox(width: 11),
                Flexible(
                  child: Text(
                    widget.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tinta,
                      fontSize: 12.5,
                      letterSpacing: 4.2,
                      fontWeight: FontWeight.w600,
                      shadows: t.halo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. Abajo, casi nada -------------------------------------------------
  Widget _brote(double entra, double sale) {
    final t = widget.theme;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 236),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: Offset(0, 16 - 16 * entra - 8 * sale),
          child: Padding(
            // Un hábito puede llamarse «Despertarse temprano sin excusas», y
            // esto es una línea sola: se corta antes de tocar los bordes.
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.fg,
                      fontSize: 12.5,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w600,
                      shadows: t.halo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. Letra por letra, con su raya -------------------------------------
  Widget _letras(double entra, double sale) {
    final t = widget.theme;
    // Por grafemas y no por unidades de código: partir una «ñ» o una tilde
    // por la mitad deja un carácter roto en pantalla.
    final letras = widget.name.characters.toList();
    // La entrada de cada letra empieza un poco después que la anterior, y
    // todas terminan antes de que se acabe el tramo de entrada.
    final paso = letras.isEmpty ? 1.0 : 0.55 / letras.length;
    // Encoge con el largo y envuelve. Una fila de letras sueltas no se corta
    // sola con puntos suspensivos como un texto normal: o cabe, o se sale.
    final cuerpo = 26.0 - ((letras.length - 12) * 0.5).clamp(0.0, 9.0);
    return Align(
      alignment: const Alignment(0, -0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < letras.length; i++)
                  Builder(
                    builder: (_) {
                      final u = Curves.easeOutCubic.transform(
                        ((entra - i * paso) / (1 - 0.55)).clamp(0.0, 1.0),
                      );
                      return Opacity(
                        opacity: u,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - u)),
                          child: Text(
                            letras[i],
                            style: TextStyle(
                              color: t.fg,
                              fontSize: cuerpo,
                              height: 1.15,
                              fontWeight: FontWeight.w300,
                              shadows: t.halo,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: entra.clamp(0.001, 1.0),
                child: Container(width: 120, height: 1.5, color: t.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
