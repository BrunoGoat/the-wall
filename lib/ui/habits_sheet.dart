import 'package:flutter/material.dart';

import '../engine/palette.dart';
import '../fx/sensory.dart';
import '../model/models.dart';
import '../model/wall_store.dart';
import 'style.dart';

/// Managing what counts as a brick.
class HabitsSheet extends StatefulWidget {
  const HabitsSheet({super.key, required this.store, required this.theme});

  final WallStore store;
  final UiTheme theme;

  @override
  State<HabitsSheet> createState() => _HabitsSheetState();
}

class _HabitsSheetState extends State<HabitsSheet> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final active = store.habits.where((h) => !h.archived).toList();
    final archived = store.habits.where((h) => h.archived).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: t.panelStrong,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: t.stroke),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fgFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('HÁBITOS', style: t.label),
            const SizedBox(height: 4),
            Text(
              'Cada vez que cumplís uno, colocás un ladrillo. Uno solo.',
              style: t.bodySoft,
            ),
            const SizedBox(height: 18),
            ...active.map((h) => _row(h, t, false)),
            const SizedBox(height: 10),
            _addButton(t),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('GUARDADOS', style: t.label),
              const SizedBox(height: 4),
              Text(
                'Sus ladrillos siguen en la muralla. Nada de lo construido se borra.',
                style: t.bodySoft.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              ...archived.map((h) => _row(h, t, true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Habit h, UiTheme t, bool archived) {
    final color = kHabitColors[h.colorIndex % kHabitColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.fg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Text(h.glyph, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: t.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  h.perDayTarget > 1
                      ? '${h.perDayTarget} por día'
                      : 'una vez por día',
                  style: t.bodySoft.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(archived ? Icons.unarchive_outlined : Icons.edit_outlined,
                size: 18, color: t.fgSoft),
            onPressed: () {
              Sensory.instance.tick();
              if (archived) {
                widget.store.restoreHabit(h);
                setState(() {});
              } else {
                _edit(h);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _addButton(UiTheme t) => GestureDetector(
        onTap: () {
          Sensory.instance.tick();
          _edit(null);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.stroke),
          ),
          child: Text('+  Nuevo hábito',
              style: t.body.copyWith(fontWeight: FontWeight.w600)),
        ),
      );

  Future<void> _edit(Habit? existing) async {
    final t = widget.theme;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    var glyph = existing?.glyph ?? kHabitGlyphs.first;
    var colorIndex = existing?.colorIndex ?? widget.store.habits.length;
    var target = existing?.perDayTarget ?? 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            decoration: BoxDecoration(
              color: t.panelStrong,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: t.stroke),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'NUEVO HÁBITO' : 'EDITAR', style: t.label),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtl,
                  style: t.body,
                  autofocus: existing == null,
                  decoration: InputDecoration(
                    hintText: 'Nombre',
                    hintStyle: TextStyle(color: t.fgFaint),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: t.stroke)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: t.accent)),
                  ),
                ),
                const SizedBox(height: 22),
                Text('ÍCONO', style: t.label),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kHabitGlyphs
                      .map((g) => GestureDetector(
                            onTap: () => setLocal(() => glyph = g),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: glyph == g
                                    ? t.accent.withValues(alpha: 0.25)
                                    : t.fg.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: glyph == g ? t.accent : Colors.transparent,
                                ),
                              ),
                              child: Text(g, style: const TextStyle(fontSize: 19)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 22),
                Text('COLOR', style: t.label),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(kHabitColors.length, (i) {
                    final on = i == colorIndex % kHabitColors.length;
                    return GestureDetector(
                      onTap: () => setLocal(() => colorIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 9),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kHabitColors[i],
                          border: Border.all(
                            color: on ? t.fg : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('VECES POR DÍA', style: t.label),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.remove, color: t.fgSoft, size: 18),
                      onPressed: () =>
                          setLocal(() => target = target > 1 ? target - 1 : 1),
                    ),
                    Text('$target', style: t.body),
                    IconButton(
                      icon: Icon(Icons.add, color: t.fgSoft, size: 18),
                      onPressed: () =>
                          setLocal(() => target = target < 12 ? target + 1 : 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () {
                          widget.store.archiveHabit(existing);
                          Navigator.of(context).pop();
                        },
                        child: Text('Guardar y ocultar',
                            style: TextStyle(color: t.fgSoft)),
                      ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.accent),
                      onPressed: () {
                        final name = nameCtl.text.trim();
                        if (name.isEmpty) return;
                        if (existing == null) {
                          widget.store
                              .addHabit(name, glyph, colorIndex, target: target);
                        } else {
                          existing
                            ..name = name
                            ..glyph = glyph
                            ..colorIndex = colorIndex
                            ..perDayTarget = target;
                          widget.store.updateHabit(existing);
                        }
                        Sensory.instance.tick();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
