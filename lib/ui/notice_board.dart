import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/town.dart';
import '../fx/sensory.dart';
import '../model/findings.dart';
import '../model/habit.dart';
import 'board_look.dart';
import 'habit_sigil.dart';
import 'style.dart';

/// The plaza's notice board, walked up to.
///
/// Everything the town has worked out about the person building it, pinned to
/// the same board that stands in the plaza — not a screen of statistics with
/// the town somewhere behind it. Every notice carries the counts it came from,
/// and none of them exists until there is enough behind it to be true, so an
/// empty board is not a bug: it is the town saying it does not know you yet.
///
/// Taking a notice off the board — tapping it — brings it up close, with the
/// same evidence drawn out.
class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({
    super.key,
    required this.valley,
    required this.habit,
    required this.theme,
    this.look = BoardLook.tablon,
  });

  /// Los pueblos que hay en el valle, [habit] incluido. Es todo lo que el
  /// tablón necesita saber de fuera: las notas que comparan dos hábitos y la
  /// corona salen de aquí. Pide la lista y no el almacén a propósito, para
  /// que se le pueda enseñar un valle de mentira sin tocar el de verdad.
  final List<Habit> valley;
  final Habit habit;
  final UiTheme theme;

  /// De qué está hecho el tablón por detrás.
  final BoardLook look;

  /// The route that walks you up to it: the board comes towards you rather
  /// than a panel sliding over the town.
  static Route<void> route({
    required List<Habit> valley,
    required Habit habit,
    required UiTheme theme,
    BoardLook look = BoardLook.tablon,
  }) => PageRouteBuilder<void>(
    opaque: false,
    barrierColor: sheetScrim(theme.dark),
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => NoticeBoardScreen(
      valley: valley,
      habit: habit,
      theme: theme,
      look: look,
    ),
    transitionsBuilder: (_, a, _, child) {
      final eased = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween(begin: 0.82, end: 1.0).animate(eased),
          child: child,
        ),
      );
    },
  );

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

/// La tinta. Es la única que no cambia con la superficie del tablón: siempre
/// se escribe sobre un papel, y el papel siempre es claro.
const Color _ink = Color(0xFF3B3730);

class _NoticeBoardScreenState extends State<NoticeBoardScreen>
    with SingleTickerProviderStateMixin {
  /// Se crea en [initState] y no al usarse. Perezoso parecía gratis, pero
  /// quien entra al tablón y se va sin tocar ninguna nota nunca lo llega a
  /// leer, y entonces el que lo creaba era [dispose] — un reloj nuevo mientras
  /// la pantalla se desmonta, buscando un ancestro que ya no está.
  late final AnimationController _zoom;

  final Map<int, GlobalKey> _pins = {};
  int? _open;
  Rect _from = Rect.zero;

  late final List<Notice> _said;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );
    final work = TownPlan.of(
      widget.habit.place,
    ).underway(widget.habit.total, widget.habit.chronicle);
    _said = noticesFor(
      widget.habit,
      others: widget.valley,
      underway: work?.$1,
      left: work?.$2 ?? 0,
    );
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _take(int i) {
    final box = _pins[i]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    setState(() {
      _from = origin & box.size;
      _open = i;
    });
    Sensory.instance.tick();
    _zoom.forward(from: 0);
  }

  Future<void> _putBack() async {
    await _zoom.reverse();
    if (mounted) setState(() => _open = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final skin = widget.look.skin;
    final media = MediaQuery.of(context);
    final open = _open;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tapping the sky walks away from the board.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 34, 12, 12),
              child: _Board(
                theme: t,
                skin: skin,
                habit: widget.habit,
                said: _said,
                pins: _pins,
                onTake: _take,
                onLeave: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (open != null)
            AnimatedBuilder(
              animation: _zoom,
              builder: (context, _) {
                final k = Curves.easeOutCubic.transform(_zoom.value);
                final wide = math.min(media.size.width - 34, 420.0);
                final middle = Offset(
                  media.size.width / 2,
                  media.size.height / 2,
                );
                // Scaled about its own middle and walked over from where it
                // was pinned, so the paper only ever takes up the room its
                // words need — a card stretched to a fixed height with a foot
                // of nothing under the text is not a piece of paper.
                final grow = _from.width / wide;
                final scale = grow + (1 - grow) * k;
                final at = Offset.lerp(_from.center, middle, k)! - middle;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _putBack,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5 * k),
                        ),
                      ),
                    ),
                    Center(
                      child: Transform.translate(
                        offset: at,
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: wide,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: media.size.height * 0.82,
                              ),
                              child: _Close(
                                notice: _said[open],
                                paper: skin.papers[open % skin.papers.length],
                                detail: k,
                                onBack: _putBack,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The board itself: planks, a roof over them, and what is pinned up.
class _Board extends StatelessWidget {
  const _Board({
    required this.theme,
    required this.skin,
    required this.habit,
    required this.said,
    required this.pins,
    required this.onTake,
    required this.onLeave,
  });

  final UiTheme theme;
  final BoardSkin skin;
  final Habit habit;
  final List<Notice> said;
  final Map<int, GlobalKey> pins;
  final void Function(int) onTake;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Roof(onLeave: onLeave),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: skin.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              border: Border.all(color: skin.frame, width: skin.frameWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              child: CustomPaint(
                painter: skin.texture,
                child: said.isEmpty
                    ? _Empty(habit: habit, skin: skin)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 26),
                        children: [
                          _Burnt(habit: habit, skin: skin),
                          const SizedBox(height: 10),
                          for (var i = 0; i < said.length; i++)
                            _Pinned(
                              key: pins.putIfAbsent(i, GlobalKey.new),
                              notice: said[i],
                              paper: skin.papers[i % skin.papers.length],
                              shadow: skin.shadow,
                              lean: (i.isEven ? 1 : -1) * (0.6 + i % 3 * 0.35),
                              onTap: () => onTake(i),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The little roof the 3D board has, so the thing you walked up to is the
/// thing you are looking at.
class _Roof extends StatelessWidget {
  const _Roof({required this.onLeave});
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: const _Shingles())),
        Positioned(
          left: 0,
          top: -30,
          child: IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: Colors.white.withValues(alpha: 0.92),
            tooltip: 'Volver al pueblo',
          ),
        ),
      ],
    ),
  );
}

class _Shingles extends CustomPainter {
  const _Shingles();

  @override
  void paint(Canvas canvas, Size size) {
    // Eaves that overhang the board a little, and a shallow pitch over them:
    // the same little roof the board has out in the plaza, seen from in front.
    final tile = Paint()..color = const Color(0xFF8A7355);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF6E5A42);
    final pitch = Path()
      ..moveTo(14, size.height - 9)
      ..lineTo(size.width * 0.5, 3)
      ..lineTo(size.width - 14, size.height - 9)
      ..close();
    canvas.drawPath(pitch, tile);
    canvas.drawPath(pitch, edge);
    final eaves = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height - 11, size.width, 11),
      const Radius.circular(3),
    );
    canvas.drawRRect(eaves, tile);
    canvas.drawRRect(eaves, edge);
  }

  @override
  bool shouldRepaint(_Shingles old) => false;
}

/// The habit's name, burnt into the top plank.
class _Burnt extends StatelessWidget {
  const _Burnt({required this.habit, required this.skin});
  final Habit habit;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HabitSigil(
        symbol: habit.symbol,
        color: skin.heading.withValues(alpha: 0.9),
        size: 19,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          habit.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: skin.heading.withValues(alpha: 0.95),
            fontSize: 12.5,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        habit.place.region.toUpperCase(),
        style: TextStyle(
          color: skin.heading.withValues(alpha: 0.7),
          fontSize: 9.5,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// One notice, pinned up.
class _Pinned extends StatelessWidget {
  const _Pinned({
    super.key,
    required this.notice,
    required this.paper,
    required this.shadow,
    required this.lean,
    required this.onTap,
  });

  final Notice notice;
  final Color paper;

  /// Cuánta sombra echa sobre el fondo. Sobre una pared clara hace falta más,
  /// porque ahí el papel ya no se separa por el color.
  final double shadow;
  final double lean;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Transform.rotate(
      angle: lean * math.pi / 180,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadow),
                blurRadius: 7,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Pin(),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      notice.said,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                notice.because,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.72),
                  fontSize: 12.5,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: const Color(0xFF9C4A3C),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
  );
}

/// A notice taken off the board and held up close: the same sentence, the
/// counts, and the shape they were read off.
class _Close extends StatelessWidget {
  const _Close({
    required this.notice,
    required this.paper,
    required this.detail,
    required this.onBack,
  });

  final Notice notice;
  final Color paper;

  /// How far into the zoom we are. The extra detail fades in at the end, so
  /// the paper reads as one thing that got closer rather than two things.
  final double detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final late = ((detail - 0.45) / 0.55).clamp(0.0, 1.0);
    return Material(
      color: paper,
      elevation: 16,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _Pin(),
                  const Spacer(),
                  GestureDetector(
                    onTap: onBack,
                    child: Opacity(
                      opacity: late,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: _ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notice.said,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notice.because,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (notice.bars.isNotEmpty) ...[
                const SizedBox(height: 20),
                Opacity(
                  opacity: late,
                  child: SizedBox(
                    height: notice.ticks.isEmpty ? 78 : 96,
                    child: CustomPaint(
                      painter: _Evidence(notice),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ],
              if (notice.more != null) ...[
                const SizedBox(height: 18),
                Opacity(
                  opacity: late,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: _ink.withValues(alpha: 0.12)),
                      const SizedBox(height: 12),
                      Text(
                        notice.more!,
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.66),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The evidence, drawn. Every bar is a number the sentence above was read off,
/// and the ones the sentence is about are the dark ones.
class _Evidence extends CustomPainter {
  const _Evidence(this.notice);
  final Notice notice;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = notice.bars;
    if (bars.isEmpty) return;
    final labels = notice.ticks.length == bars.length;
    final foot = labels ? 18.0 : 0.0;
    final h = size.height - foot - 2;
    final gap = bars.length > 14 ? 1.5 : 4.0;
    final w = (size.width - gap * (bars.length - 1)) / bars.length;

    final base = Paint()..color = _ink.withValues(alpha: 0.22);
    final picked = Paint()..color = _ink.withValues(alpha: 0.82);
    for (var i = 0; i < bars.length; i++) {
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      // Even an empty bar leaves a mark, so a gap reads as nothing rather
      // than as missing.
      final tall = math.max(2.0, h * bars[i].clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + gap), 2 + h - tall, w, tall),
          Radius.circular(math.min(2.5, w / 2)),
        ),
        on ? picked : base,
      );
    }
    canvas.drawLine(
      Offset(0, h + 2.5),
      Offset(size.width, h + 2.5),
      Paint()
        ..color = _ink.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );
    if (!labels) return;
    for (var i = 0; i < bars.length; i++) {
      final text = notice.ticks[i];
      if (text.isEmpty) continue;
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: _ink.withValues(alpha: on ? 0.8 : 0.45),
            fontSize: bars.length > 8 ? 8.5 : 10,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w * (bars.length > 8 ? 1.0 : 1.6));
      tp.paint(canvas, Offset(i * (w + gap) + (w - tp.width) / 2, h + 7));
    }
  }

  @override
  bool shouldRepaint(_Evidence old) => old.notice != notice;
}

/// A board with nothing on it yet, which is the honest state of a young town.
class _Empty extends StatelessWidget {
  const _Empty({required this.habit, required this.skin});
  final Habit habit;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) {
    final days = daysOf(habit).length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Transform.rotate(
          angle: -1.1 * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: skin.papers.first,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: skin.shadow),
                  blurRadius: 7,
                  offset: const Offset(1, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Pin(),
                const SizedBox(height: 12),
                const Text(
                  'El tablón está vacío.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  days == 0
                      ? 'Todavía no hay nada que contar. Poné la primera pieza.'
                      : 'Llevás $days ${days == 1 ? 'día' : 'días'}. El pueblo '
                            'prefiere callarse a inventar: cuando tenga '
                            'bastante para estar seguro de algo, lo escribe '
                            'acá.',
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
