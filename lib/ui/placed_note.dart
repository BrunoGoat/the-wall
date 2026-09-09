import 'dart:async';

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import 'habit_sigil.dart';
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
class PlacedNote extends StatefulWidget {
  const PlacedNote({
    super.key,
    required this.habit,
    required this.ordinal,
    required this.theme,
    required this.onWrite,
    required this.onDismiss,
  });

  final Habit habit;

  /// Which piece of this town it is, counting from one.
  final int ordinal;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        child: _writing
            ? _Slip(
                key: const ValueKey('slip'),
                theme: t,
                habit: h,
                ordinal: widget.ordinal,
                text: _text,
                focus: _focus,
                onDone: _submit,
              )
            : _Line(
                key: const ValueKey('line'),
                theme: t,
                habit: h,
                ordinal: widget.ordinal,
                onWrite: _open,
              ),
      ),
    );
  }
}

/// The quiet state: no panel, no field, no buttons. Just which town got it.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.theme,
    required this.habit,
    required this.ordinal,
    required this.onWrite,
  });

  final UiTheme theme;
  final Habit habit;
  final int ordinal;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HabitSigil(symbol: habit.symbol, color: t.accent, size: 18),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            habit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              shadows: t.halo,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '· $ordinal',
          style: t.bodySoft.copyWith(fontSize: 13, shadows: t.halo),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onWrite,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(
              'anotar',
              style: t.body.copyWith(
                fontSize: 13.5,
                color: t.accent,
                shadows: t.halo,
                decoration: TextDecoration.underline,
                decorationColor: t.accent.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// And if there is something to say: a slip of paper, and nothing else on it.
class _Slip extends StatelessWidget {
  const _Slip({
    super.key,
    required this.theme,
    required this.habit,
    required this.ordinal,
    required this.text,
    required this.focus,
    required this.onDone,
  });

  final UiTheme theme;
  final Habit habit;
  final int ordinal;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // La misma tarjeta que sale al leer una leyenda ya escrita.
    //
    // Era un papelito blanco torcido, del tablón de anuncios, y quedaba como
    // un cuerpo extraño: escribir la leyenda y leerla son la misma cosa vista
    // dos veces, y se veían distintas. Ahora las dos son la tarjeta esmerilada
    // que ya se había afinado, con el mismo ancho, la misma cabecera chica y
    // el mismo tamaño de texto.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Frosted(
        theme: t,
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${habit.name.toUpperCase()} · PIEZA $ordinal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(fontSize: 8.5, letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: text,
              focusNode: focus,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onDone(),
              onTapOutside: (_) => onDone(),
              textCapitalization: TextCapitalization.sentences,
              cursorColor: t.accent,
              style: t.body.copyWith(
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
          ],
        ),
      ),
    );
  }
}
