import 'dart:async';

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import 'legend_card.dart';
import 'overlays.dart';
import 'style.dart';

/// Por dónde se entra a escribir la leyenda. Está aquí para que el test pueda
/// tocarlo sin saber cómo está dibujado.
@visibleForTesting
const Key anotar = Key('anotar');

/// Lo que aparece en cuanto una pieza aterriza.
///
/// Dice **qué** se acaba de construir —un tejado, una chimenea, un pretil— y
/// nada más. No dice a qué pueblo fue, porque estás mirándolo, ni cuántas
/// piezas llevás, porque eso está arriba a la izquierda: las dos cosas que
/// decía antes ya estaban en la pantalla.
///
/// Y la nota se queda fuera del camino hasta que se la pide. Una tarjeta con
/// el campo de texto ya abierto le dice «escribí algo» a quien acaba de hacer
/// la cosa y quiere mirar su pueblo, y nueve de cada diez veces la respuesta
/// es que no. Así que: el nombre de la pieza, un lápiz al lado, y sólo si se
/// toca aparece el papel — el mismo papel que sale al releer una leyenda vieja.
class PlacedNote extends StatefulWidget {
  const PlacedNote({
    super.key,
    required this.kind,
    required this.ordinal,
    required this.when,
    required this.theme,
    required this.onWrite,
    required this.onDismiss,
  });

  /// Cómo se llama lo que se acaba de poner. Nulo sólo si el trazado no sabe
  /// de esa pieza, que no debería pasar.
  final String? kind;

  /// Qué pieza de este pueblo es, contando desde uno.
  final int ordinal;

  /// Cuándo se puso, para la cabecera del papel.
  final DateTime when;

  final UiTheme theme;
  final void Function(String text) onWrite;
  final VoidCallback onDismiss;

  @override
  State<PlacedNote> createState() => _PlacedNoteState();
}

class _PlacedNoteState extends State<PlacedNote> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _fade;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _fade?.cancel();
    // Lo que se tarda en leer una palabra y decidir que no hay nada que
    // añadir, que es casi siempre. Eran nueve segundos y se quedaba ahí
    // colgado mucho después de haber dicho lo suyo.
    _fade = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && !_writing) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    _fade?.cancel();
    Sensory.instance.tick();
    setState(() => _writing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _submit() {
    final t = _text.text.trim();
    if (t.isNotEmpty) {
      Sensory.instance.tick();
      widget.onWrite(t);
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final media = MediaQuery.of(context);
    final teclado = media.viewInsets.bottom;

    if (_writing) {
      return Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: teclado > 0 ? teclado + 10 : 208 + media.padding.bottom,
            child: Center(
              child: LegendCard(
                theme: t,
                header:
                    'PIEZA ${widget.ordinal} · '
                    '${StoneCard.formatDate(widget.when)}',
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  maxLength: 60,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onTapOutside: (_) => _submit(),
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: t.accent,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    hintText: 'qué fue',
                    hintStyle: t.bodySoft.copyWith(
                      fontSize: 13.5,
                      height: 1.25,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Arriba del centro, no encima del botón: lo que se acaba de construir
    // está en el pueblo, y el anuncio tiene que dejarlo ver.
    return Align(
      alignment: const Alignment(0, -0.34),
      child: _Entrada(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.kind ?? 'Pieza',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.number.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                        shadows: t.halo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    key: anotar,
                    onTap: _open,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.accent.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: t.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(width: 92, height: 1.5, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cómo entra: subiendo un poco y apareciendo.
class _Entrada extends StatelessWidget {
  const _Entrada({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, v, kid) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: kid),
      ),
      child: child,
    );
  }
}
