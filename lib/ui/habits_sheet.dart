import 'package:flutter/material.dart';

import '../data/character.dart';
import '../data/symbols.dart';
import '../fx/sensory.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'style.dart';

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

/// Borrar un pueblo entero no se deshace, así que se dice en el color con el
/// que se dicen esas cosas.
///
/// Dos rojos, y no uno: el mismo rojo oscuro que sobre el panel claro se lee
/// como un aviso, sobre el panel de noche se apaga hasta parecer un texto
/// desactivado. El de noche es el mismo rojo, un punto más vivo.
Color _danger(bool dark) =>
    dark ? const Color(0xFFCC5B48) : const Color(0xFF9E3124);

class _HabitsSheetState extends State<HabitsSheet> {
  late final TextEditingController _name;
  late String _symbol;
  late int _place;
  bool _creating = false;

  /// The marks are only worth the room when somebody is actually choosing
  /// one. Until then this sheet is a name and a mark.
  bool _picking = false;

  /// Sixty-six marks is four screenfuls of grid on a phone, and a sheet that
  /// tall pushes its own name field off the top. Three rows that slide
  /// sideways instead: the common ones are already in front of you, and the
  /// rest are a drag away rather than a scroll through everything.
  final ScrollController _reel = ScrollController();

  static const double _tile = 40;
  static const double _gap = 8;
  static const int _rows = 3;
  static const double _stride = _tile + _gap;

  @override
  void initState() {
    super.initState();
    _creating = widget.startNew && widget.store.canAddHabit;
    final h = widget.store.habit;
    _name = TextEditingController(text: _creating ? '' : h.name);
    _symbol = _creating ? habitSymbols.first : h.symbol;
    _place = _creating
        ? TownCharacter.forSlot(widget.store.habits.length).order
        : h.character;
    _picking = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _reel.dispose();
    super.dispose();
  }

  /// Opening the picker on a mark that lives in the twentieth column and
  /// showing the first three would look like the mark is not in the list.
  void _showTheChosenOne() {
    final at = habitSymbols.indexOf(_symbol);
    if (at < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_reel.hasClients) return;
      final want = (at ~/ _rows - 1) * _stride;
      _reel.jumpTo(want.clamp(0.0, _reel.position.maxScrollExtent));
    });
  }

  /// The whole catalogue, three rows tall, read down and then across.
  Widget _reelOfMarks(UiTheme t) {
    final columns = (habitSymbols.length + _rows - 1) ~/ _rows;
    return SizedBox(
      height: _rows * _tile + (_rows - 1) * _gap,
      child: ListView.builder(
        controller: _reel,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: columns,
        itemBuilder: (_, column) => Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _rows; row++)
                Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
                  child: _markTile(t, column * _rows + row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One square of the reel, or an empty square where the list runs out — so
  /// the last column is the same width as every other one.
  Widget _markTile(UiTheme t, int at) {
    if (at >= habitSymbols.length) {
      return const SizedBox(width: _tile, height: _tile);
    }
    final mark = habitSymbols[at];
    final chosen = mark == _symbol;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Sensory.instance.tick();
        setState(() {
          _symbol = mark;
          _picking = false;
        });
        _keep();
      },
      child: Container(
        width: _tile,
        height: _tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: chosen ? t.accent.withValues(alpha: 0.20) : Colors.transparent,
          border: Border.all(color: chosen ? t.accent : t.stroke),
        ),
        child: HabitSigil(
          symbol: mark,
          color: chosen ? t.accent : t.fg.withValues(alpha: 0.62),
          size: 21,
        ),
      ),
    );
  }

  /// Editing writes as you go, so there is no button to press and nothing to
  /// lose by closing the sheet. A save button on a screen with two fields is a
  /// button asking you to confirm that you meant the thing you just did.
  ///
  /// Founding is the other case and keeps its button: a town is a decision,
  /// and the region it is founded with can never be changed afterwards.
  void _keep() {
    if (_creating) return;
    final store = widget.store;
    store.renameHabit(store.active, name: _name.text, symbol: _symbol);
  }

  void _found() {
    Sensory.instance.tick();
    widget.store.addHabit(_name.text, _symbol, character: _place);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final ch = _creating ? TownCharacter.byOrder(_place) : store.habit.place;
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
              if (_creating) ...[
                Text('UN HÁBITO NUEVO', style: t.label),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  // The mark is the way in to the rest of them. Nothing else
                  // on this sheet needs a screenful of icons under it.
                  GestureDetector(
                    onTap: () {
                      Sensory.instance.tick();
                      setState(() => _picking = !_picking);
                      if (_picking) _showTheChosenOne();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.fg.withValues(alpha: _picking ? 0.12 : 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _picking ? t.accent : t.stroke,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          HabitSigil(
                            symbol: _symbol,
                            color: t.accent,
                            size: 30,
                          ),
                          // A pencil in the corner, because a mark that opens
                          // thirty-six other marks does not look like a thing
                          // you can press unless it says so.
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: t.dark
                                    ? const Color(0xFF1A1A22)
                                    : const Color(0xFFF3EEE3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 10,
                                color: t.accent.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      onChanged: (_) => _keep(),
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
              AnimatedSize(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _picking
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _reelOfMarks(t),
                      )
                    : const SizedBox(width: double.infinity),
              ),

              const SizedBox(height: 20),
              // What kind of place this habit builds. Chosen once, the day it
              // is founded, and then never again: the character decides how
              // wide the plots are and in what order the hundred and twelve
              // arrive, so changing it later would move pieces laid years ago.
              if (_creating) ...[
                Text('QUÉ CLASE DE PUEBLO', style: t.label),
                const SizedBox(height: 10),
              ],
              if (_creating)
                Row(
                  children: [
                    for (final c in TownCharacter.all)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Sensory.instance.tick();
                              setState(() => _place = c.order);
                            },
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: c.order == _place
                                    ? t.accent.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: c.order == _place
                                      ? t.accent
                                      : t.stroke,
                                ),
                              ),
                              child: HabitSigil(
                                symbol: c.symbol,
                                color: c.order == _place
                                    ? t.accent
                                    : t.fg.withValues(alpha: 0.55),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (_creating) const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Column(
                  key: ValueKey(ch.region),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Smaller than the habit's own mark on purpose: this
                        // one says what kind of place it is, not what the
                        // habit is, and the size says which of the two you
                        // are looking at.
                        HabitSigil(
                          symbol: ch.symbol,
                          color: t.accent.withValues(alpha: 0.85),
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ch.region.toUpperCase(),
                          style: t.label.copyWith(
                            fontSize: 11,
                            color: t.accent,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(ch.blurb, style: t.bodySoft),
                  ],
                ),
              ),
              if (_creating) ...[
                const SizedBox(height: 8),
                Text(
                  'Se elige una sola vez. Después no se puede cambiar sin '
                  'mover piezas ya puestas, y eso no se hace.',
                  style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
                ),
              ],

              // Only when founding. Editing writes as you type, so there is
              // nothing here to confirm and nothing to lose by closing.
              if (_creating) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _found,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent.withValues(alpha: 0.85),
                      foregroundColor: t.dark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Fundar el pueblo'),
                  ),
                ),
              ],

              if (!_creating) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _confirmRemove(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _danger(t.dark),
                    ),
                    child: Text(
                      'Eliminar este hábito',
                      style: t.bodySoft.copyWith(
                        fontSize: 12.5,
                        color: _danger(t.dark),
                      ),
                    ),
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
    // The last one can go too, and it is worth saying what that leaves: an
    // empty valley, not an app with nothing in it.
    final onlyOne = widget.store.habits.length <= 1;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        elevation: 0,
        title: Text('¿Eliminar ${h.name}?', style: t.body),
        content: Text(
          'Se borra su pueblo entero: ${h.total} piezas. No hay vuelta atrás.'
          '${onlyOne ? ' Como es el único, el valle vuelve a empezar en '
                    'blanco.' : ''}',
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
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: _danger(t.dark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
