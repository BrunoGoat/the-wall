import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/palette.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/piece.dart';
import '../data/landmarks.dart';
import '../model/store.dart';
import 'habit_bar.dart';
import 'habits_sheet.dart';
import 'hold_button.dart';
import 'journey_sheet.dart';
import 'overlays.dart';
import 'style.dart';
import '../engine/town.dart';
import 'town_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final Store store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TownViewController _wall = TownViewController();
  late UiTheme _theme = UiTheme(Palette.forMoment(12, 1));

  /// A landmark of the town, and which number it is, waiting to be shown.
  (Landmark, int)? _revealTown;
  String? _whisper;
  Timer? _whisperTimer;
  Piece? _selected;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    Appearance.instance.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    Appearance.instance.removeListener(_onStore);
    _whisperTimer?.cancel();
    super.dispose();
  }

  void _onStore() {
    // Keep the open card in step with the store, so a note written now shows
    // up on the card straight away.
    if (_selected != null) {
      _selected = widget.store.pieceAt(_selected!.index);
    }
    setState(() {});
  }

  /// One line on opening, so the wall's condition is the first thing you learn.
  void _greet() {
    final s = widget.store;
    if (s.total == 0) {
      _showWhisper('Mantené el botón para poner tu primera piedra',
          duration: const Duration(seconds: 6));
    } else if (s.integrityAtLaunch < 0.92) {
      final days = s.daysIdle.floor();
      _showWhisper('$days días sin piezas. El pueblo se está quedando a oscuras.',
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

  Future<void> _editLabel(Piece brick) async {
    final result = await LabelSheet.show(
      context,
      theme: _theme,
      number: brick.index + 1,
      initial: brick.label,
    );
    if (result == null) return;
    widget.store.setLabel(brick.index, result);
    if (mounted) {
      Sensory.instance.tick();
      setState(() => _selected = widget.store.pieceAt(brick.index));
    }
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
            child: TownView(
              store: store,
              controller: _wall,
              onTownLandmark: (mark, ordinal) {
                if (Appearance.instance.rapid) return;
                setState(() => _revealTown = (mark, ordinal));
              },
              onStoneTapped: (brick) => setState(() => _selected = brick),
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

          // --- top: the numbers, set straight on the scene
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: media.padding.top + 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      t.palette.ink.withValues(alpha: t.dark ? 0.34 : 0.14),
                      t.palette.ink.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + 12,
            left: 22,
            right: 14,
            child: _TopBar(theme: t, store: store, onJourney: _openJourney),
          ),

          // --- right: camera controls
          Positioned(
            right: 10,
            top: media.padding.top + 92,
            child: Column(
              children: [
                GhostButton(
                  icon: Icons.zoom_out_map,
                  theme: t,
                  tooltip: 'Ver todo el pueblo',
                  onTap: _wall.frameAll,
                ),
                if (store.habits.length > 1)
                  GhostButton(
                    icon: Icons.travel_explore,
                    theme: t,
                    tooltip: 'Ver todo el valle',
                    onTap: _wall.frameValley,
                  ),
                GhostButton(
                  icon: Icons.center_focus_strong,
                  theme: t,
                  tooltip: 'Ir a lo último que pusiste',
                  onTap: _wall.goToLatest,
                ),
                GhostButton(
                  icon: Icons.threesixty,
                  theme: t,
                  tooltip: 'Reiniciar la vista',
                  onTap: _wall.resetView,
                ),
              ],
            ),
          ),

          // --- preview mode: impossible to forget you are in it
          if (store.isPreviewing)
            Positioned(
              top: media.padding.top + 78,
              left: 0,
              right: 0,
              child: Center(
                child: _PreviewBanner(theme: t, store: store),
              ),
            ),

          // --- the tapped stone, and its optional note
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: media.padding.bottom + 214,
              child: Center(
                child: StoneCard(
                  theme: t,
                  when: _selected!.placedAt,
                  number: _selected!.index + 1,
                  label: _selected!.label,
                  onEdit: () => _editLabel(_selected!),
                  onClose: () {
                    _wall.clearSelection();
                    setState(() => _selected = null);
                  },
                ),
              ),
            ),

          if (_whisper != null && _selected == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 222,
              child: Center(child: Whisper(message: _whisper!, theme: t)),
            ),

          // --- bottom: travel, then the one button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomDeck(
              theme: t,
              placed: store.total,
              plan: store.plan,
              store: store,
              onSelect: (i) {
                widget.store.select(i);
                _showWhisper(widget.store.habit.name);
              },
              onManage: _openHabits,
              wall: _wall,
              onPlace: () {
                _wall.clearSelection();
                setState(() => _selected = null);
                _wall.place();
              },
            ),
          ),

          if (_revealTown != null)
            Positioned.fill(
              child: TownLandmarkOverlay(
                mark: _revealTown!.$1,
                ordinal: _revealTown!.$2,
                theme: t,
                onDismiss: () => setState(() => _revealTown = null),
              ),
            ),

        ],
      ),
    );
  }

  void _openHabits({bool startNew = false}) {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitsSheet(
        store: widget.store,
        theme: _theme,
        startNew: startNew,
      ),
    );
  }

  void _openJourney() {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JourneySheet(
        store: widget.store,
        theme: _theme,
        onGoTo: _wall.goTo,
        onEditLabel: _editLabel,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.theme,
    required this.store,
    required this.onJourney,
  });

  final UiTheme theme;
  final Store store;
  final VoidCallback onJourney;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final decaying = store.isDecaying;
    final days = store.streak;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onJourney,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${store.total}',
                        style: t.number.copyWith(shadows: t.halo)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('PIEZAS',
                          style: t.label.copyWith(shadows: t.halo)),
                    ),
                    if (days > 0) ...[
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          '$days ${days == 1 ? 'DÍA' : 'DÍAS'}',
                          style: t.label.copyWith(
                            shadows: t.halo,
                            color: t.fg.withValues(alpha: 0.44),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  decaying
                      ? 'Se están apagando las ventanas · una pieza las enciende'
                      : store.nextEventLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: decaying
                        ? const Color(0xFFE0A055)
                        : t.fg.withValues(alpha: 0.50),
                    fontSize: 12,
                    letterSpacing: 0.1,
                    shadows: t.halo,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Icon(Icons.chevron_right,
                size: 20,
                color: t.fg.withValues(alpha: 0.40),
                shadows: t.halo),
          ),
        ],
      ),
    );
  }
}

/// What this piece finishes, said above the button.
///
/// The pull to put one more down is strongest when you can see exactly what it
/// completes. "faltan 2 para el Granero" is a different feeling from a button
/// that only says "mantener".
String? buttonHint(int placed, TownPlan plan) {
  final work = plan.underway(placed);
  if (work == null) return null;
  final left = work.$2;
  if (left == 1) return 'esta termina ${work.$1}';
  if (left <= 4) return 'faltan $left para ${work.$1}';
  return null;
}

class _BottomDeck extends StatelessWidget {
  const _BottomDeck({
    required this.theme,
    required this.wall,
    required this.onPlace,
    required this.placed,
    required this.plan,
    required this.store,
    required this.onSelect,
    required this.onManage,
  });

  final UiTheme theme;
  final TownViewController wall;
  final VoidCallback onPlace;
  final int placed;
  final TownPlan plan;
  final Store store;
  final void Function(int index) onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.palette.ink.withValues(alpha: 0),
            t.palette.ink.withValues(alpha: t.dark ? 0.30 : 0.13),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HabitBar(
            store: store,
            theme: t,
            onSelect: onSelect,
            onManage: onManage,
          ),
          const SizedBox(height: 6),
          HoldToPlace(
            theme: t,
            onPlace: onPlace,
            onCharge: wall.setCharge,
            rapid: Appearance.instance.rapid,
            hint: buttonHint(placed, plan),
          ),
        ],
      ),
    );
  }
}

/// Says, unmissably, that what you are looking at is not your wall.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.theme, required this.store});
  final UiTheme theme;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => store.setPreview(null),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 8, 11, 8),
        decoration: BoxDecoration(
          color: t.panelStrong,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VISTA DE ${store.shownTotal} PIEZAS',
              style: TextStyle(
                color: t.accent,
                fontSize: 10.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.close, size: 15, color: t.fgSoft),
          ],
        ),
      ),
    );
  }
}
