import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/store.dart';
import 'style.dart';

/// The row of habits, right above the button.
///
/// Every habit is a symbol you chose and a town of your own. Tapping one takes
/// you there. It sits where the thumb already is, because switching between
/// habits is the second most common thing anybody does here — the first being
/// laying a piece.
class HabitBar extends StatelessWidget {
  const HabitBar({
    super.key,
    required this.store,
    required this.theme,
    required this.onSelect,
    required this.onManage,
  });

  final Store store;
  final UiTheme theme;
  final void Function(int index) onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (store.habits.length <= 1 && !store.canAddHabit) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (var i = 0; i < store.habits.length; i++)
            _Chip(
              habit: store.habits[i],
              lit: Store.integrityOf(store.habits[i]),
              on: i == store.active,
              theme: t,
              onTap: () {
                if (i == store.active) {
                  onManage();
                } else {
                  Sensory.instance.tick();
                  onSelect(i);
                }
              },
            ),
          _AddChip(theme: t, onTap: onManage, enabled: store.canAddHabit),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.habit,
    required this.lit,
    required this.on,
    required this.theme,
    required this.onTap,
  });

  final Habit habit;
  final double lit;
  final bool on;
  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: t.fg.withValues(alpha: on ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: on ? t.accent.withValues(alpha: 0.75) : t.stroke,
              width: on ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dimmed when the habit has been left: the row of symbols is
              // itself a small readout of how every habit is going.
              Opacity(
                opacity: 0.35 + 0.65 * lit,
                child: Text(habit.symbol, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 8),
              Text(
                '${habit.total}',
                style: TextStyle(
                  color: t.fg.withValues(alpha: on ? 0.92 : 0.55),
                  fontSize: 13,
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
}

class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.theme,
    required this.onTap,
    required this.enabled,
  });
  final UiTheme theme;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.stroke),
          ),
          child: Icon(Icons.add, size: 17, color: t.fgSoft),
        ),
      ),
    );
  }
}
