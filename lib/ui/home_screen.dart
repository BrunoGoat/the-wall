import '../data/constellations.dart';
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
import 'placed_note.dart';
import 'journey_sheet.dart';
import 'notice_board.dart';
import 'overlays.dart';
import 'settings_sheet.dart';
import 'sky_sheet.dart';
import 'style.dart';
import 'town_sign.dart';
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

  /// The piece just laid, while its card is still up.
  Piece? _justPlaced;
  String? _whisper;
  Timer? _whisperTimer;

  /// El cartel del pueblo al que acabás de entrar: qué dice, con qué diseño de
  /// los cinco, y un número que cambia en cada anuncio para que la animación
  /// vuelva a empezar aunque el pueblo sea el mismo.
  (String, String, TownSign, int)? _sign;
  Timer? _signTimer;
  int _signNonce = 0;

  /// Cuál de las cinco maneras de anunciar la pieza le tocó a ésta. Se sortea
  /// al caer y no al pintar: si se sorteara al pintar, cambiaría de diseño en
  /// cada cuadro.
  NoteStyle _noteStyle = NoteStyle.tarjeta;

  static const Duration _signLife = Duration(milliseconds: 2600);
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
    _signTimer?.cancel();
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
      _showWhisper(
        'Mantené el botón para poner tu primera piedra',
        duration: const Duration(seconds: 6),
      );
    } else if (s.integrityAtLaunch < 0.92) {
      final days = s.daysIdle.floor();
      _showWhisper(
        '$days días sin piezas. El pueblo se está quedando a oscuras.',
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Anunciar el pueblo. Sale uno de los cinco diseños al azar, para poder
  /// verlos todos usando la app y quedarse con uno.
  void _announceTown() {
    final h = widget.store.habit;
    _signTimer?.cancel();
    setState(() => _sign = (h.name, h.symbol, TownSign.alAzar(), ++_signNonce));
    _signTimer = Timer(_signLife, () {
      if (mounted) setState(() => _sign = null);
    });
  }

  void _showWhisper(
    String msg, {
    Duration duration = const Duration(seconds: 3),
  }) {
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

  /// Alguien reconoció la constelación de esta noche y la tocó.
  ///
  /// Se anota una sola vez, y sólo entonces se abre el cuaderno: volver a
  /// tocarla no vuelve a celebrarlo. Lo que sí sigue pasando es que se ve, con
  /// su nombre debajo — el cielo no se apaga porque ya lo hayas mirado.
  void _logConstellation(String id) {
    final c = constellationOf(id);
    if (c == null) return;
    if (!widget.store.logConstellation(id)) return;
    Sensory.instance.milestone();
    _openSky(justFound: c);
  }

  void _openSky({Constellation? justFound}) {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          SkySheet(store: widget.store, theme: _theme, justFound: justFound),
    );
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
              onPlaced: (piece) {
                // In the testing mode the pieces come far too fast for a card
                // to be anything but in the way.
                if (Appearance.instance.rapid) return;
                setState(() {
                  _justPlaced = piece;
                  _noteStyle = NoteStyle.alAzar();
                });
              },
              onStoneTapped: (brick) => setState(() {
                _selected = brick;
                // Y fuera la tarjeta de la pieza recién puesta: quien se puso
                // a mirar otra ya pasó de página, y las dos juntas se pisan.
                _justPlaced = null;
              }),
              onNothingTapped: () {
                if (_selected != null) setState(() => _selected = null);
              },
              onSkyTapped: _logConstellation,
              onDomeTapped: _openSky,
              onTownTapped: (i) {
                store.select(i);
                _announceTown();
              },
              onBoardTapped: _readBoard,
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
            child: _TopBar(
              theme: t,
              store: store,
              onJourney: _openJourney,
              onSettings: _openSettings,
            ),
          ),

          // --- right: two ways of looking, and no more than that
          //
          // There were four. The other two —volver a la última pieza, enderezar
          // la vista— hacían lo mismo que un dedo sobre el pueblo, y una
          // columna de cuatro iconos sobre un valle es una barra de
          // herramientas encima de un paisaje. Quedan los dos que llevan a un
          // sitio donde no estabas: este pueblo entero, y el valle entero.
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
                ),
              ),
            ),

          if (_sign != null)
            Positioned.fill(
              child: TownSignOverlay(
                key: ValueKey(_sign!.$4),
                name: _sign!.$1,
                symbol: _sign!.$2,
                sign: _sign!.$3,
                theme: t,
                life: _signLife,
              ),
            ),

          if (_whisper != null && _selected == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 222,
              child: Center(
                child: Whisper(message: _whisper!, theme: t),
              ),
            ),

          // --- bottom: travel, then the one button
          // The card for the piece just laid, riding above the deck and out of
          // the way of the keyboard when it comes up.
          if (_justPlaced != null)
            Positioned.fill(
              child: PlacedNote(
                key: ValueKey(_justPlaced!.index),
                habit: store.habit,
                ordinal: _justPlaced!.index + 1,
                theme: t,
                style: _noteStyle,
                onWrite: (text) => store.setLabel(_justPlaced!.index, text),
                onDismiss: () => setState(() => _justPlaced = null),
              ),
            ),

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
                _announceTown();
              },
              onManage: _openHabits,
              onAdd: () => _openHabits(startNew: true),
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
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) =>
          HabitsSheet(store: widget.store, theme: _theme, startNew: startNew),
    );
  }

  /// The notice board of one town. Reading another town's board does not move
  /// you there: you can stand in your own plaza and read what the next valley
  /// over has worked out about itself.
  void _readBoard(int town) {
    final store = widget.store;
    if (town < 0 || town >= store.habits.length) return;
    Navigator.of(context).push(
      NoticeBoardScreen.route(
        store: store,
        habit: store.habits[town],
        theme: _theme,
      ),
    );
  }

  void _openSettings() {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) => SettingsSheet(store: widget.store, theme: _theme),
    );
  }

  void _openJourney() {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
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
    required this.onSettings,
  });

  final UiTheme theme;
  final Store store;
  final VoidCallback onJourney;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final decaying = store.isDecaying;
    final days = store.streak;
    // Two doors, because there are two different things behind them: the
    // numbers open what you have done, and the gear opens what you can set.
    // One chevron meaning both was one of them hiding.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onJourney,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${store.total}',
                      style: t.number.copyWith(shadows: t.halo),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'PIEZAS',
                        style: t.label.copyWith(shadows: t.halo),
                      ),
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
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSettings,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, bottom: 8),
            child: Icon(
              Icons.settings_outlined,
              size: 21,
              color: t.fg.withValues(alpha: 0.44),
              shadows: t.halo,
            ),
          ),
        ),
      ],
    );
  }
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
    required this.onAdd,
  });

  final UiTheme theme;
  final TownViewController wall;
  final VoidCallback onPlace;
  final int placed;
  final TownPlan plan;
  final Store store;
  final void Function(int index) onSelect;
  final VoidCallback onManage;
  final VoidCallback onAdd;

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
            onAdd: onAdd,
          ),
          const SizedBox(height: 6),
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
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => store.setPreview(null),
      child: SheetSurface(
        theme: t,
        all: true,
        top: 20,
        padding: const EdgeInsets.fromLTRB(15, 8, 11, 8),
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
