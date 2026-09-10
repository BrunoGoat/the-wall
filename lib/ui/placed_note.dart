import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import 'habit_sigil.dart';
import 'legend_card.dart';
import 'style.dart';

/// What comes up the moment a piece lands.
///
/// Two jobs, and the first one matters more: say out loud which habit this
/// piece went to. With several towns in the valley the button is the same
/// button, and "which one did I just add to" is a question the app should
/// never make anybody ask.
///
/// The second is the note, and it stays out of the way until it is asked for.
/// A card with a text field already open says "write something" to somebody
/// who has just done the thing and wants to watch their town, and nine times
/// out of ten the answer is no. So: one quiet line over the roofs, and a word
/// to tap if there is something worth remembering — and then it is a slip of
/// paper, the same paper the notice board is covered in, because that is what
/// a note is.
/// De cuántas maneras se dice.
///
/// Cinco, y sale una al azar cada vez que cae una pieza. Cambian de sitio en
/// la pantalla, de tamaño y de cómo ofrecen la nota, que es todo lo que hay
/// que comparar para quedarse con una. Lo que **no** cambia es el papel donde
/// se escribe: esa tarjeta ya está decidida y es la misma que sale al leer una
/// leyenda vieja.
enum NoteStyle {
  /// Una tarjeta compacta encima del botón.
  tarjeta,

  /// Sin caja: el nombre grande en el medio de la pantalla.
  sello,

  /// Una franja de lado a lado, apoyada en la botonera.
  franja,

  /// Una pastilla flotando sobre el pueblo, con su botón al lado.
  globo,

  /// El número de la pieza, grande, y el nombre al lado.
  cuenta;

  static final math.Random _dado = math.Random();

  static NoteStyle alAzar() => values[_dado.nextInt(values.length)];
}

class PlacedNote extends StatefulWidget {
  const PlacedNote({
    super.key,
    required this.habit,
    required this.ordinal,
    required this.theme,
    required this.style,
    required this.card,
    required this.onWrite,
    required this.onDismiss,
  });

  final NoteStyle style;

  /// De qué está hecho el papel donde se escribe. Se sortea al caer la pieza,
  /// igual que la manera de anunciarla.
  final CardStyle card;

  final Habit habit;

  /// Which piece of this town it is, counting from one.
  final int ordinal;

  final UiTheme theme;
  final void Function(String text) onWrite;
  final VoidCallback onDismiss;

  @override
  State<PlacedNote> createState() => _PlacedNoteState();
}

/// Por dónde se entra a escribir la leyenda, en las cinco. Está aquí para que
/// el test pueda tocarlo sin saber cómo está dibujada cada una.
@visibleForTesting
const Key anotar = Key('anotar');

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
    // Long enough to read which habit it went to and decide there is nothing
    // to add — which is most of the time — and long enough to reach for the
    // word if there is.
    _fade = Timer(const Duration(seconds: 9), () {
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
    final h = widget.habit;
    final media = MediaQuery.of(context);
    final teclado = media.viewInsets.bottom;

    if (_writing) {
      // El papel siempre en el mismo sitio, esquive el teclado o no: lo que se
      // está comparando son las cinco maneras de anunciar, no cinco maneras de
      // escribir.
      return Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: teclado > 0 ? teclado + 10 : 208 + media.padding.bottom,
            child: Center(
              child: _Slip(
                theme: t,
                card: widget.card,
                habit: h,
                ordinal: widget.ordinal,
                text: _text,
                focus: _focus,
                onDone: _submit,
              ),
            ),
          ),
        ],
      );
    }

    return _Entrada(
      // Cada variante entra desde donde está: la de abajo sube, la del medio
      // sólo se abre. Una que baje sobre la botonera se lee como que se cae.
      desde: switch (widget.style) {
        NoteStyle.tarjeta => 12,
        NoteStyle.sello => 0,
        NoteStyle.franja => 22,
        NoteStyle.globo => 8,
        NoteStyle.cuenta => -8,
      },
      crece: widget.style == NoteStyle.sello,
      child: switch (widget.style) {
        NoteStyle.tarjeta => _tarjeta(t, h, media),
        NoteStyle.sello => _sello(t, h),
        NoteStyle.franja => _franja(t, h, media),
        NoteStyle.globo => _globo(t, h),
        NoteStyle.cuenta => _cuenta(t, h),
      },
    );
  }

  // --- 1. Una tarjeta compacta encima del botón ----------------------------
  Widget _tarjeta(UiTheme t, Habit h, MediaQueryData media) {
    return Padding(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 204),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Frosted(
            theme: t,
            radius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      HabitSigil(symbol: h.symbol, color: t.accent, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: 14.5,
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.ordinal}',
                        style: t.label.copyWith(fontSize: 11, letterSpacing: 0),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: t.stroke),
                GestureDetector(
                  key: anotar,
                  onTap: _open,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'anotar algo',
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(fontSize: 13, color: t.accent),
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

  // --- 2. Sin caja: el nombre grande, en el medio --------------------------
  Widget _sello(UiTheme t, Habit h) {
    return Align(
      alignment: const Alignment(0, 0.06),
      child: GestureDetector(
        key: anotar,
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HabitSigil(symbol: h.symbol, color: t.accent, size: 30),
              const SizedBox(height: 13),
              Text(
                h.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: t.fg,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w300,
                  shadows: t.halo,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PIEZA ${widget.ordinal}  ·  ANOTAR',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 9.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                  shadows: t.halo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. Una franja de lado a lado, apoyada en la botonera ----------------
  Widget _franja(UiTheme t, Habit h, MediaQueryData media) {
    return Padding(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 196),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Frosted(
          theme: t,
          radius: 0,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Row(
              children: [
                Container(width: 3, height: 52, color: t.accent),
                const SizedBox(width: 16),
                HabitSigil(symbol: h.symbol, color: t.accent, size: 18),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'PIEZA ${widget.ordinal}',
                  style: t.label.copyWith(fontSize: 9),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  key: anotar,
                  onTap: _open,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.accent.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(Icons.add, size: 16, color: t.accent),
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

  // --- 4. Una pastilla flotando, con su botón al lado ----------------------
  Widget _globo(UiTheme t, Habit h) {
    return Align(
      alignment: const Alignment(0, 0.34),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Frosted(
              theme: t,
              radius: 26,
              padding: const EdgeInsets.fromLTRB(15, 10, 17, 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HabitSigil(symbol: h.symbol, color: t.accent, size: 16),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        fontSize: 14,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${widget.ordinal}',
                    style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: anotar,
            onTap: _open,
            behavior: HitTestBehavior.opaque,
            child: Frosted(
              theme: t,
              radius: 22,
              padding: const EdgeInsets.all(11),
              child: Icon(Icons.edit_outlined, size: 16, color: t.accent),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. El número, grande, y el nombre al lado ---------------------------
  Widget _cuenta(UiTheme t, Habit h) {
    return Align(
      alignment: const Alignment(0, -0.06),
      child: GestureDetector(
        key: anotar,
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${widget.ordinal}',
                    style: t.number.copyWith(fontSize: 42, shadows: t.halo),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.fg,
                            fontSize: 13,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w600,
                            shadows: t.halo,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'anotar',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 12.5,
                            shadows: t.halo,
                          ),
                        ),
                      ],
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

/// Cómo entra cualquiera de las cinco: subiendo un poco y apareciendo.
///
/// Está aparte porque lo que se compara son los diseños, y si cada uno trajera
/// además su propia curva no se sabría cuál de las dos cosas gustó.
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.child,
    required this.desde,
    required this.crece,
  });

  final Widget child;

  /// Píxeles desde los que sube. Negativo, baja.
  final double desde;

  /// Si además crece un pelo, para el que no tiene caja donde apoyarse.
  final bool crece;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, v, kid) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, desde * (1 - v)),
          child: crece
              ? Transform.scale(scale: 0.94 + 0.06 * v, child: kid)
              : kid,
        ),
      ),
      child: child,
    );
  }
}

/// And if there is something to say: a slip of paper, and nothing else on it.
class _Slip extends StatelessWidget {
  const _Slip({
    required this.theme,
    required this.card,
    required this.habit,
    required this.ordinal,
    required this.text,
    required this.focus,
    required this.onDone,
  });

  final UiTheme theme;
  final CardStyle card;
  final Habit habit;
  final int ordinal;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // La misma tarjeta que sale al leer una leyenda ya escrita, en el mismo
    // material. Escribir la leyenda y leerla son la misma cosa vista dos
    // veces, y se veían distintas.
    return LegendCard(
      theme: t,
      style: card,
      header: '${habit.name.toUpperCase()} · PIEZA $ordinal',
      child: TextField(
        controller: text,
        focusNode: focus,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        onTapOutside: (_) => onDone(),
        textCapitalization: TextCapitalization.sentences,
        cursorColor: t.accent,
        // Sin color: lo pone el material, que en el papel escribe en tinta
        // parda aunque el resto de la interfaz vaya en claro sobre oscuro.
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
          hintStyle: t.bodySoft.copyWith(fontSize: 13.5, height: 1.25),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
