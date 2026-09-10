import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'style.dart';

/// The row of habits, right above the button.
///
/// Every habit is a symbol you chose and a town of your own. Tapping one takes
/// you there. It sits where the thumb already is, because switching between
/// habits is the second most common thing anybody does here — the first being
/// laying a piece.
///
/// It used to be a row of bordered pills with a count in each, and it ate a
/// whole band across the bottom of a screen whose entire job is to show you a
/// town. Now it is what it always was underneath: a line of marks, one lit.
/// No frames, no plates, no numbers competing with the one already at the top
/// of the screen — the current town is the one in the accent colour with a dot
/// under it, and that is the whole of what this has to say. Each mark is small
/// and the thing you tap is not: the hit area stays a full thumb wide.
class HabitBar extends StatelessWidget {
  const HabitBar({
    super.key,
    required this.store,
    required this.theme,
    required this.onSelect,
    required this.onManage,
    required this.onAdd,
  });

  final Store store;
  final UiTheme theme;
  final void Function(int index) onSelect;

  /// Tapping the habit you are already on: edit this one.
  final VoidCallback onManage;

  /// Tapping the plus: found a new one. Not the same thing at all.
  final VoidCallback onAdd;

  /// What the whole row costs in height. A quarter of what the pills did.
  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (store.habits.length <= 1 && !store.canAddHabit) {
      return const SizedBox.shrink();
    }

    final crown = store.leader;

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (var i = 0; i < store.habits.length; i++)
            _Mark(
              habit: store.habits[i],
              lit: Store.integrityOf(store.habits[i]),
              on: i == store.active,
              crowned: i == crown,
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
          _AddMark(theme: t, onTap: onAdd, enabled: store.canAddHabit),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.habit,
    required this.lit,
    required this.on,
    required this.crowned,
    required this.theme,
    required this.onTap,
  });

  final Habit habit;
  final double lit;
  final bool on;

  /// The most pieces in the valley. A whole competition in one small mark.
  final bool crowned;
  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Dimmed when the habit has been left: the row of symbols is itself a
    // small readout of how every habit is going.
    final ink = (on ? t.accent : t.fg).withValues(
      alpha: on ? 1.0 : 0.30 + 0.34 * lit,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: on ? 1.0 : 0.88,
                    child: HabitSigil(
                      symbol: habit.symbol,
                      color: ink,
                      size: 21,
                    ),
                  ),
                  if (crowned)
                    Positioned(
                      top: -6,
                      right: -1,
                      child: CustomPaint(
                        size: const Size(11, 9),
                        painter: _CrownMark(
                          const Color(0xFFE8B84B).withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // The one dot that says which town you are standing in.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: on ? 14 : 3,
              height: 3,
              decoration: BoxDecoration(
                color: on
                    ? t.accent.withValues(alpha: 0.9)
                    : t.fg.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMark extends StatelessWidget {
  const _AddMark({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 46,
        child: Center(
          child: Icon(
            Icons.add,
            size: 18,
            color: t.fg.withValues(alpha: enabled ? 0.42 : 0.16),
            shadows: t.halo,
          ),
        ),
      ),
    );
  }
}

/// The valley's crown, small enough to sit over a mark.
class _CrownMark extends CustomPainter {
  const _CrownMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      HabitSigils.crown(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(_CrownMark old) => old.color != color;
}
