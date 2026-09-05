import 'package:flutter/material.dart';

import '../data/character.dart';
import '../fx/sensory.dart';
import '../model/store.dart';
import 'style.dart';

/// The symbols a habit can wear.
///
/// A grid rather than a keyboard: picking is one tap, it always renders, and
/// nobody has to know how to type an emoji on their phone.
const List<String> habitSymbols = [
  '📖', '🏃', '💪', '🧘', '🚭', '💧', '🥗', '😴',
  '✍️', '🎸', '🎨', '🧹', '💊', '🦷', '☎️', '🌱',
  '🧠', '💻', '🪙', '🚲', '🏊', '🐕', '🍳', '🎯',
];

/// Making a habit, and everything you can change about one afterwards.
class HabitsSheet extends StatefulWidget {
  const HabitsSheet({
    super.key,
    required this.store,
    required this.theme,
    this.startNew = false,
  });

  final Store store;
  final UiTheme theme;
  final bool startNew;

  @override
  State<HabitsSheet> createState() => _HabitsSheetState();
}

class _HabitsSheetState extends State<HabitsSheet> {
  late final TextEditingController _name;
  late String _symbol;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _creating = widget.startNew && widget.store.canAddHabit;
    final h = widget.store.habit;
    _name = TextEditingController(text: _creating ? '' : h.name);
    _symbol = _creating ? habitSymbols.first : h.symbol;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startNew() {
    setState(() {
      _creating = true;
      _name.text = '';
      _symbol = habitSymbols[
          widget.store.habits.length % habitSymbols.length];
    });
  }

  void _commit() {
    final store = widget.store;
    Sensory.instance.tick();
    if (_creating) {
      store.addHabit(_name.text, _symbol);
    } else {
      store.renameHabit(store.active, name: _name.text, symbol: _symbol);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final slot = _creating ? store.habits.length : store.habit.slot;
    final ch = TownCharacter.forSlot(slot);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Frosted(
        theme: t,
        strong: true,
        radius: 30,
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.fg.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_creating ? 'UN HÁBITO NUEVO' : 'ESTE HÁBITO',
                  style: t.label),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.fg.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.stroke),
                    ),
                    child: Text(_symbol, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: t.body.copyWith(fontSize: 17),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 24,
                      decoration: InputDecoration(
                        hintText: 'Leer, correr, no fumar…',
                        hintStyle: t.bodySoft,
                        counterText: '',
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: t.stroke),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in habitSymbols)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _symbol = s),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: s == _symbol
                              ? t.accent.withValues(alpha: 0.20)
                              : Colors.transparent,
                          border: Border.all(
                            color: s == _symbol ? t.accent : t.stroke,
                          ),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              // The valley decides what kind of place each habit builds, and it
              // is worth knowing before you start which one you are getting.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.fg.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SU PUEBLO SERÁ DE ${ch.region.toUpperCase()}',
                        style: t.label.copyWith(fontSize: 9.5)),
                    const SizedBox(height: 6),
                    Text(ch.blurb, style: t.bodySoft),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _commit,
                      style: FilledButton.styleFrom(
                        backgroundColor: t.accent.withValues(alpha: 0.85),
                        foregroundColor: t.dark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_creating ? 'Fundar el pueblo' : 'Guardar'),
                    ),
                  ),
                  if (!_creating && store.canAddHabit) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _startNew,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.fgSoft,
                        side: BorderSide(color: t.stroke),
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.add, size: 19),
                    ),
                  ],
                ],
              ),

              if (!_creating && store.habits.length > 1) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _confirmRemove(context),
                    style: TextButton.styleFrom(foregroundColor: t.fgFaint),
                    child: Text('Abandonar este hábito',
                        style: t.bodySoft.copyWith(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final t = widget.theme;
    final h = widget.store.habit;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        title: Text('¿Abandonar ${h.name}?', style: t.body),
        content: Text(
          'Se borra su pueblo entero: ${h.total} piezas. No hay vuelta atrás.',
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              widget.store.removeHabit(widget.store.active);
              Navigator.of(dialog).pop();
              Navigator.of(context).pop();
            },
            child: Text('Abandonar',
                style: TextStyle(color: t.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
