import 'dart:async';

import 'package:flutter/material.dart';

import '../data/epics.dart';
import '../data/milestones.dart';
import '../engine/palette.dart';
import '../fx/sensory.dart';
import '../model/models.dart';
import '../model/wall_store.dart';
import 'habits_sheet.dart';
import 'journey_sheet.dart';
import 'overlays.dart';
import 'style.dart';
import 'wall_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final WallStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WallViewController _wall = WallViewController();
  late UiTheme _theme = UiTheme(Palette.forMoment(12, 1));

  Epic? _revealEpic;
  MilestoneReveal? _revealMilestone;
  String? _whisper;
  Timer? _whisperTimer;
  _StoneInfo? _stone;
  Timer? _stoneTimer;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _whisperTimer?.cancel();
    _stoneTimer?.cancel();
    super.dispose();
  }

  void _onStore() => setState(() {});

  /// One line on opening, so the wall's condition is the first thing you learn.
  void _greet() {
    final s = widget.store;
    if (s.total == 0) {
      _showWhisper('Tocá un hábito para colocar tu primer ladrillo',
          duration: const Duration(seconds: 5));
    } else if (s.integrityAtLaunch < 0.92) {
      final days = s.daysIdle.floor();
      _showWhisper('$days días sin ladrillos. La muralla se está resintiendo.',
          duration: const Duration(seconds: 5));
    }
  }

  void _showWhisper(String msg,
      {Duration duration = const Duration(seconds: 3)}) {
    _whisperTimer?.cancel();
    setState(() => _whisper = msg);
    _whisperTimer = Timer(duration, () {
      if (mounted) setState(() => _whisper = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final store = widget.store;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: t.palette.skyTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: WallView(
              store: store,
              controller: _wall,
              onEpicFound: (e) => setState(() => _revealEpic = e),
              onMilestoneComplete: (seg) => setState(() {
                _revealMilestone =
                    MilestoneReveal(seg.type!, seg.milestoneNo + 1);
              }),
              onStoneTapped: (brick, habit, epicNumber) {
                _stoneTimer?.cancel();
                setState(() {
                  _stone = _StoneInfo(brick, habit, epicNumber);
                });
                _stoneTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _stone = null);
                });
              },
              onWhisper: _showWhisper,
              onPaletteChanged: (p) {
                final next = UiTheme(p);
                if (next.dark != _theme.dark ||
                    next.accent != _theme.accent ||
                    next.palette.skyTop != _theme.palette.skyTop) {
                  setState(() => _theme = next);
                }
              },
            ),
          ),

          // --- top: the numbers that matter
          Positioned(
            top: media.padding.top + 10,
            left: 14,
            right: 14,
            child: _TopBar(theme: t, store: store, onJourney: _openJourney),
          ),

          // --- right: camera controls
          Positioned(
            right: 14,
            top: media.padding.top + 96,
            child: Column(
              children: [
                RoundButton(
                  icon: Icons.zoom_out_map,
                  theme: t,
                  tooltip: 'Ver toda la muralla',
                  onTap: _wall.frameAll,
                ),
                const SizedBox(height: 10),
                RoundButton(
                  icon: Icons.center_focus_strong,
                  theme: t,
                  tooltip: 'Ir al último ladrillo',
                  onTap: _wall.goToLatest,
                ),
                const SizedBox(height: 10),
                RoundButton(
                  icon: Icons.threesixty,
                  theme: t,
                  tooltip: 'Reiniciar la vista',
                  onTap: _wall.resetView,
                ),
              ],
            ),
          ),

          // --- floating info
          if (_stone != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 190,
              child: Center(
                child: StoneCard(
                  theme: t,
                  habitName: _stone!.habit?.name ?? 'Un logro',
                  glyph: _stone!.habit?.glyph ?? '◆',
                  when: _stone!.brick.placedAt,
                  number: _stone!.brick.index + 1,
                  epicTitle: _stone!.epicNumber == null
                      ? null
                      : kEpics[_stone!.epicNumber! - 1].title,
                ),
              ),
            ),

          if (_whisper != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 246,
              child: Center(child: Whisper(message: _whisper!, theme: t)),
            ),

          // --- bottom: travel + habits
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomDeck(
              theme: t,
              store: store,
              wall: _wall,
              onOpenHabits: _openHabits,
            ),
          ),

          if (_revealMilestone != null)
            Positioned.fill(
              child: MilestoneOverlay(
                type: _revealMilestone!.type,
                ordinal: _revealMilestone!.ordinal,
                theme: t,
                onDismiss: () => setState(() => _revealMilestone = null),
              ),
            ),

          if (_revealEpic != null)
            Positioned.fill(
              child: EpicRevealOverlay(
                epic: _revealEpic!,
                found: store.discoveries.length,
                theme: t,
                onDismiss: () => setState(() => _revealEpic = null),
              ),
            ),
        ],
      ),
    );
  }

  void _openJourney() {
    Sensory.instance.tick();
    final structureX = <int, double>{
      for (final s in _wall.structures) s.firstBrick: (s.x0 + s.x1) / 2,
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JourneySheet(
        store: widget.store,
        theme: _theme,
        structureX: structureX,
        onGoTo: _wall.goToX,
      ),
    );
  }

  void _openHabits() {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitsSheet(store: widget.store, theme: _theme),
    );
  }
}

class MilestoneReveal {
  MilestoneReveal(this.type, this.ordinal);
  final MilestoneType type;
  final int ordinal;
}

class _StoneInfo {
  _StoneInfo(this.brick, this.habit, this.epicNumber);
  final Brick brick;
  final Habit? habit;
  final int? epicNumber;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.theme,
    required this.store,
    required this.onJourney,
  });

  final UiTheme theme;
  final WallStore store;
  final VoidCallback onJourney;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final decaying = store.isDecaying;
    return Frosted(
      theme: t,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
      onTap: onJourney,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${store.total}', style: t.number),
                  const SizedBox(width: 7),
                  Text('LADRILLOS',
                      style: t.label.copyWith(fontSize: 9, letterSpacing: 1.6)),
                  if (store.streak > 0) ...[
                    const SizedBox(width: 12),
                    Text('${store.streak}',
                        style: t.number.copyWith(fontSize: 18)),
                    const SizedBox(width: 5),
                    Text('DÍAS',
                        style:
                            t.label.copyWith(fontSize: 9, letterSpacing: 1.6)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                decaying
                    ? 'La muralla se deteriora · un ladrillo la repara'
                    : store.nextEventLabel,
                style: TextStyle(
                  color: decaying
                      ? const Color(0xFFD98E3B)
                      : t.fg.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  size: 17, color: t.fg.withValues(alpha: 0.55)),
              const SizedBox(height: 3),
              Text('${store.discoveries.length}/100',
                  style: TextStyle(
                      color: t.fg.withValues(alpha: 0.55),
                      fontSize: 10,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _BottomDeck extends StatelessWidget {
  const _BottomDeck({
    required this.theme,
    required this.store,
    required this.wall,
    required this.onOpenHabits,
  });

  final UiTheme theme;
  final WallStore store;
  final WallViewController wall;
  final VoidCallback onOpenHabits;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final habits = store.activeHabits;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.palette.ink.withValues(alpha: 0),
            t.palette.ink.withValues(alpha: t.dark ? 0.42 : 0.20),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TravelScrubber(
              theme: t,
              length: wall.wallLength,
              travel: wall.travel,
              marks: [
                for (final s in wall.structures) (s.x0 + s.x1) / 2,
              ],
              onSeek: wall.goToX,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: habits.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (i == habits.length) {
                  return _ManageChip(theme: t, onTap: onOpenHabits);
                }
                final h = habits[i];
                return _HabitChip(
                  theme: t,
                  habit: h,
                  todayCount: store.todayCount(h.id),
                  onPlace: () {
                    Sensory.instance.press();
                    wall.place(h.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The single most important control in the app: one tap, one stone.
class _HabitChip extends StatefulWidget {
  const _HabitChip({
    required this.theme,
    required this.habit,
    required this.todayCount,
    required this.onPlace,
  });

  final UiTheme theme;
  final Habit habit;
  final int todayCount;
  final VoidCallback onPlace;

  @override
  State<_HabitChip> createState() => _HabitChipState();
}

class _HabitChipState extends State<_HabitChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  bool _down = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final h = widget.habit;
    final color = kHabitColors[h.colorIndex % kHabitColors.length];
    final done = widget.todayCount >= h.perDayTarget;
    final progress = (widget.todayCount / h.perDayTarget).clamp(0.0, 1.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        _c.forward(from: 0);
        widget.onPlace();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // A quick punch outwards as the stone leaves the chip.
          final k = Curves.easeOutBack.transform(
              (_c.value * 2.2).clamp(0.0, 1.0));
          final fade = 1 - Curves.easeIn.transform(_c.value);
          final scale = (_down ? 0.94 : 1.0) * (1 + 0.06 * (1 - (k - 1).abs()));
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_c.isAnimating)
                Container(
                  width: 96 + 40 * k,
                  height: 84 + 30 * k,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: color.withValues(alpha: 0.6 * fade),
                      width: 2,
                    ),
                  ),
                ),
              Transform.scale(scale: scale, child: child),
            ],
          );
        },
        child: Frosted(
          theme: t,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ProgressRing(
                    progress: progress,
                    color: color,
                    track: t.fg.withValues(alpha: 0.12),
                    size: 42,
                  ),
                  Text(h.glyph, style: const TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(width: 11),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: done ? t.fg : t.fg.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    h.perDayTarget > 1
                        ? '${widget.todayCount}/${h.perDayTarget} hoy'
                        : (done ? 'hecho hoy' : 'colocar ladrillo'),
                    style: TextStyle(
                      color: done ? color : t.fg.withValues(alpha: 0.5),
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageChip extends StatelessWidget {
  const _ManageChip({required this.theme, required this.onTap});
  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Frosted(
        theme: t,
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 20, color: t.fg.withValues(alpha: 0.75)),
            const SizedBox(height: 6),
            Text('Hábitos',
                style: TextStyle(
                    color: t.fg.withValues(alpha: 0.6), fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
