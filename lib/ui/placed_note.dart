import 'dart:async';

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import 'style.dart';

/// The card that comes up the moment a piece lands.
///
/// Two jobs, and the first one matters more: it says out loud which habit this
/// piece went to. With several towns in the valley the button is the same
/// button, and "which one did I just add to" is a question the app should never
/// make anybody ask.
///
/// The second is the note. Optional, always — the piece counts either way — but
/// offered right here, while you still remember that it was one kilometre and
/// not two. A year later that is the difference between a count and a story.
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

  @override
  void initState() {
    super.initState();
    _arm();
    // Typing keeps it up: nobody should lose a half-written note to a timer.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _fade?.cancel();
      } else {
        _arm();
      }
    });
  }

  void _arm() {
    _fade?.cancel();
    // Long enough to actually think of something to write. Seven seconds was
    // not: it was gone before the thumb reached the field.
    _fade = Timer(const Duration(seconds: 12), () {
      if (mounted && _text.text.trim().isEmpty) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Frosted(
        theme: t,
        strong: true,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Text(h.symbol, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text('· pieza ${widget.ordinal}',
                          style: t.bodySoft.copyWith(fontSize: 11.5)),
                    ],
                  ),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    maxLength: 60,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    textCapitalization: TextCapitalization.sentences,
                    style: t.body.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
                      hintText: 'anotá algo (opcional)',
                      hintStyle: t.bodySoft.copyWith(fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _submit,
              icon: Icon(
                _text.text.trim().isEmpty ? Icons.close : Icons.check,
                size: 19,
                color: t.fgSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
