import 'package:flutter/material.dart';

import '../data/character.dart';
import '../engine/town.dart';
import '../model/findings.dart';
import '../model/habit.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'style.dart';

/// The plaza's notice board.
///
/// Everything the town has worked out about the person building it, in one
/// place, written as sentences rather than laid out as a dashboard. Every
/// notice carries the counts it came from, and none of them exists until
/// there is enough behind it to be true — so an empty board is not a bug, it
/// is the town saying it does not know you yet.
class NoticeBoardSheet extends StatelessWidget {
  const NoticeBoardSheet({
    super.key,
    required this.store,
    required this.habit,
    required this.theme,
  });

  final Store store;
  final Habit habit;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // This habit's own plan, not the one you happen to be standing in: a
    // board can be read from the next town over.
    final work = TownPlan.of(
      TownCharacter.forSlot(habit.slot),
    ).underway(habit.total);
    final said = noticesFor(
      habit,
      others: store.habits,
      underway: work?.$1,
      left: work?.$2 ?? 0,
    );
    final days = daysOf(habit).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: t.panelStrong,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.fgFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Head(theme: t, habit: habit),
            const SizedBox(height: 4),
            Expanded(
              child: said.isEmpty
                  ? _Empty(theme: t, days: days)
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      itemCount: said.length + 1,
                      itemBuilder: (context, i) => i == said.length
                          ? _Foot(theme: t)
                          : _Pinned(theme: t, notice: said[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.theme, required this.habit});
  final UiTheme theme;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          HabitSigil(symbol: habit.symbol, size: 22, color: t.fg),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EL TABLÓN',
                  style: t.label.copyWith(fontSize: 9.5, letterSpacing: 2.2),
                ),
                const SizedBox(height: 3),
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One notice, pinned up: what the town says, and under it the counts it is
/// saying it from. The second line is not decoration — a claim you cannot
/// check is a claim you should not believe.
class _Pinned extends StatelessWidget {
  const _Pinned({required this.theme, required this.notice});
  final UiTheme theme;
  final Notice notice;

  static const _marks = {
    NoticeKind.ahead: Icons.trending_flat,
    NoticeKind.hour: Icons.schedule,
    NoticeKind.week: Icons.calendar_today_outlined,
    NoticeKind.relapse: Icons.remove_circle_outline,
    NoticeKind.comeback: Icons.replay,
    NoticeKind.pair: Icons.link,
    NoticeKind.life: Icons.landscape_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: t.fg.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              _marks[notice.kind] ?? Icons.push_pin_outlined,
              size: 17,
              color: t.fg.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.said,
                  style: t.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notice.because,
                  style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A board with nothing on it yet, which is the honest state of a young town.
class _Empty extends StatelessWidget {
  const _Empty({required this.theme, required this.days});
  final UiTheme theme;
  final int days;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 0, 34, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 30,
              color: t.fg.withValues(alpha: 0.30),
            ),
            const SizedBox(height: 16),
            Text(
              'El tablón está vacío.',
              textAlign: TextAlign.center,
              style: t.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              days == 0
                  ? 'Todavía no hay nada que contar. Poné la primera pieza.'
                  : 'Llevás $days ${days == 1 ? 'día' : 'días'}. El pueblo '
                        'prefiere callarse a inventar: cuando tenga bastante '
                        'para estar seguro de algo, lo escribe acá.',
              textAlign: TextAlign.center,
              style: t.bodySoft.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.theme});
  final UiTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      'Todo esto sale de cuándo pusiste cada pieza. Nada más se guarda, y '
      'nada de esto sale de tu teléfono.',
      style: theme.bodySoft.copyWith(
        fontSize: 11.5,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
    ),
  );
}
