import 'dart:async';

import 'package:flutter/material.dart';

import '../data/milestones.dart';
import '../engine/palette.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/models.dart';
import '../data/lexicon.dart';
import '../model/wall_store.dart';
import 'hold_button.dart';
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

  MilestoneReveal? _revealMilestone;
  String? _whisper;
  Timer? _whisperTimer;
  Brick? _selected;

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
      _selected = widget.store.brickAt(_selected!.index);
    }
    setState(() {});
  }

  /// One line on opening, so the wall's condition is the first thing you learn.
  void _greet() {
    final s = widget.store;
    if (s.total == 0) {
      _showWhisper(Lexicon.of.firstPrompt,
          duration: const Duration(seconds: 6));
    } else if (s.integrityAtLaunch < 0.92) {
      final days = s.daysIdle.floor();
      final w = Lexicon.of;
      _showWhisper('$days días sin ${w.units}. ${w.decayWhisper}',
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

  Future<void> _editLabel(Brick brick) async {
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
      setState(() => _selected = widget.store.brickAt(brick.index));
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
            child: WallView(
              store: store,
              controller: _wall,
              onMilestoneComplete: (seg) {
                // In the testing mode the stones come far too fast for a
                // full-screen announcement to be anything but in the way.
                if (Appearance.instance.rapid) return;
                setState(() {
                  _revealMilestone =
                      MilestoneReveal(seg.type!, seg.milestoneNo + 1);
                });
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
                  tooltip: Lexicon.of.seeAll,
                  onTap: _wall.frameAll,
                ),
                GhostButton(
                  icon: Icons.center_focus_strong,
                  theme: t,
                  tooltip: Lexicon.of.goLatest,
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
              wall: _wall,
              onPlace: () {
                _wall.clearSelection();
                setState(() => _selected = null);
                _wall.place();
              },
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
        onEditLabel: _editLabel,
      ),
    );
  }
}

class MilestoneReveal {
  MilestoneReveal(this.type, this.ordinal);
  final MilestoneType type;
  final int ordinal;
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
                      child: Text(Lexicon.of.unitsCaps,
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
                      ? Lexicon.of.decayLine
                      : (Lexicon.isTown
                          ? Lexicon.nextEvent(store.total)
                          : store.nextEventLabel),
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

class _BottomDeck extends StatelessWidget {
  const _BottomDeck({
    required this.theme,
    required this.wall,
    required this.onPlace,
  });

  final UiTheme theme;
  final WallViewController wall;
  final VoidCallback onPlace;

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
          HoldToPlace(
            theme: t,
            onPlace: onPlace,
            onCharge: wall.setCharge,
            rapid: Appearance.instance.rapid,
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
  final WallStore store;

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
              'VISTA DE ${store.shownTotal} ${Lexicon.of.unitsCaps}',
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
