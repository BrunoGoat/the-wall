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
    this.look = BoardLook.poste,
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
    BoardLook look = BoardLook.poste,
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
            // Arriba ya no se reserva nada: el remate del tablón es lo primero
            // que hay, y el botón de volver flota sobre él.
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                skin.margin,
                2,
                skin.margin,
                skin.margin + 2,
              ),
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
                                skin: skin,
                                index: open,
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

/// El tablón: el remate de arriba, la madera, y lo que hay clavado en ella.
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
    final radius = BorderRadius.vertical(
      top: Radius.circular(skin.top == TopKind.nada ? skin.radius : 0),
      bottom: Radius.circular(skin.radius),
    );
    final madera = Container(
      decoration: BoxDecoration(
        color: skin.wood,
        borderRadius: radius,
        border: skin.frameWidth == 0
            ? null
            : Border.all(color: skin.frame, width: skin.frameWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: skin.grain,
          foregroundPainter: skin.bevel ? _Bevel(skin.frame) : null,
          child: said.isEmpty
              ? _Empty(habit: habit, skin: skin)
              // El relleno de los lados lo pone cada hijo y no la lista: la
              // banda del nombre tiene que llegar a los dos bordes de la
              // madera, y desde una lista con relleno eso sólo se consigue
              // con un margen negativo, que no existe.
              : ListView(
                  padding: EdgeInsets.only(
                    top: skin.head == HeadKind.banda ? 0 : 12,
                    bottom: 24,
                  ),
                  children: [
                    if (skin.head == HeadKind.banda)
                      _Name(habit: habit, skin: skin)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _Name(habit: habit, skin: skin),
                      ),
                    SizedBox(height: skin.head == HeadKind.banda ? 12 : 9),
                    for (var i = 0; i < said.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _Pinned(
                          key: pins.putIfAbsent(i, GlobalKey.new),
                          notice: said[i],
                          skin: skin,
                          index: i,
                          onTap: () => onTake(i),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    return Stack(
      children: [
        Column(
          children: [
            if (skin.topHeight > 0) _Top(skin: skin),
            Expanded(
              child: skin.posts
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Post(skin: skin),
                        Expanded(child: madera),
                        _Post(skin: skin),
                      ],
                    )
                  : madera,
            ),
          ],
        ),
        // El botón de volver flota sobre el remate en vez de reservarse su
        // propia franja: era eso, y no el tejado, lo que empujaba el tablón
        // treinta píxeles hacia abajo.
        Positioned(
          left: 0,
          top: 0,
          child: GestureDetector(
            onTap: onLeave,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back,
                size: 19,
                color: Colors.white.withValues(alpha: 0.9),
                shadows: const [Shadow(color: Colors.black54, blurRadius: 5)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Uno de los dos postes que clavan el tablón en la plaza.
class _Post extends StatelessWidget {
  const _Post({required this.skin});
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    decoration: BoxDecoration(
      color: skin.postColor,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 5),
        ),
      ],
    ),
  );
}

/// El remate de arriba, sea lo que sea en este tablón.
class _Top extends StatelessWidget {
  const _Top({required this.skin});
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: skin.topHeight,
    child: CustomPaint(painter: _TopPaint(skin), size: Size.infinite),
  );
}

class _TopPaint extends CustomPainter {
  const _TopPaint(this.skin);
  final BoardSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = skin.topColor;
    switch (skin.top) {
      case TopKind.tejado:
        // Las dos aguas del modelo, con su alero volando por los lados.
        final pitch = Path()
          ..moveTo(10, size.height - 6)
          ..lineTo(size.width * 0.5, 2)
          ..lineTo(size.width - 10, size.height - 6)
          ..close();
        canvas.drawPath(pitch, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, size.height - 7, size.width, 7),
            const Radius.circular(2),
          ),
          p,
        );
      case TopKind.alero:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.7),
            const Radius.circular(2),
          ),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.04,
            0,
            size.width * 0.92,
            size.height * 0.34,
          ),
          Paint()..color = skin.topColor.withValues(alpha: 0.72),
        );
      case TopKind.liston:
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.02,
            size.height * 0.34,
            size.width * 0.96,
            size.height * 0.66,
          ),
          p,
        );
      case TopKind.cordel:
        // Un cordel con sus dos nudos, que es de donde cuelga todo.
        final cuerda = Paint()
          ..color = skin.topColor
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke;
        final hilo = Path()
          ..moveTo(4, size.height * 0.34)
          ..quadraticBezierTo(
            size.width / 2,
            size.height * 0.86,
            size.width - 4,
            size.height * 0.34,
          );
        canvas.drawPath(hilo, cuerda);
        for (final x in [8.0, size.width - 8]) {
          canvas.drawCircle(Offset(x, size.height * 0.34), 3.4, p);
        }
      case TopKind.nada:
        break;
    }
  }

  @override
  bool shouldRepaint(_TopPaint old) => old.skin != skin;
}

/// La luz de una moldura biselada, por dentro del marco.
class _Bevel extends CustomPainter {
  const _Bevel(this.frame);
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 2),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(_Bevel old) => old.frame != frame;
}

/// El nombre del hábito, escrito como lo escriba este tablón.
class _Name extends StatelessWidget {
  const _Name({required this.habit, required this.skin});
  final Habit habit;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) {
    final texto = habit.name.toUpperCase();
    final region = habit.place.region.toUpperCase();
    switch (skin.head) {
      case HeadKind.banda:
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          color: skin.frameWidth == 0
              ? skin.topColor
              : skin.frame.withValues(alpha: 0.94),
          child: _fila(texto, region, skin.heading),
        );
      case HeadKind.tarjeta:
        return Align(
          alignment: Alignment.centerLeft,
          child: Transform.rotate(
            angle: -0.9 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
              decoration: BoxDecoration(
                color: skin.papers.first,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: skin.shadow),
                    blurRadius: 5,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: _fila(texto, region, skin.ink, corta: true),
            ),
          ),
        );
      case HeadKind.tallado:
        return Stack(
          children: [
            // La luz que queda por debajo del trazo hundido.
            Transform.translate(
              offset: const Offset(0, 1),
              child: _fila(texto, region, Colors.white.withValues(alpha: 0.45)),
            ),
            _fila(texto, region, skin.heading),
          ],
        );
      case HeadKind.quemado:
        return _fila(texto, region, skin.heading);
    }
  }

  Widget _fila(String texto, String region, Color color, {bool corta = false}) {
    return Row(
      mainAxisSize: corta ? MainAxisSize.min : MainAxisSize.max,
      children: [
        HabitSigil(symbol: habit.symbol, color: color, size: 17),
        const SizedBox(width: 8),
        corta
            ? Flexible(child: _titulo(texto, color))
            : Expanded(child: _titulo(texto, color)),
        const SizedBox(width: 8),
        Text(
          region,
          style: TextStyle(
            color: color.withValues(alpha: 0.68),
            fontSize: 9,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _titulo(String texto, Color color) => Text(
    texto,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontSize: 12,
      letterSpacing: 2.4,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Una nota, clavada.
class _Pinned extends StatelessWidget {
  const _Pinned({
    super.key,
    required this.notice,
    required this.skin,
    required this.index,
    required this.onTap,
  });

  final Notice notice;
  final BoardSkin skin;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paper = skin.papers[index % skin.papers.length];
    final lean = skin.lean == 0
        ? 0.0
        : (index.isEven ? 1 : -1) * (skin.lean * (0.6 + index % 3 * 0.28));
    // Los recortes estrechos además se corren a un lado y a otro, porque un
    // recorte centrado con márgenes iguales vuelve a ser una fila de lista.
    final corre = skin.inset < 0.9
        ? (index.isEven ? -1 : 1) * (1 - skin.inset) * 26
        : 0.0;

    Widget hoja = Container(
      padding: EdgeInsets.fromLTRB(
        14,
        skin.shape == PaperShape.tapado ? 17 : 14,
        14,
        skin.shape == PaperShape.rasgado ? 19 : 12,
      ),
      color: paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (skin.pin != PinKind.ninguno) ...[
                _Pin(skin: skin),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  notice.said,
                  style: TextStyle(
                    color: skin.ink,
                    fontSize: 15.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (skin.head == HeadKind.banda) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: skin.ink.withValues(alpha: 0.16)),
          ],
          const SizedBox(height: 7),
          Text(
            notice.because,
            style: TextStyle(
              color: skin.ink.withValues(alpha: 0.72),
              fontSize: 12.5,
              height: 1.42,
            ),
          ),
        ],
      ),
    );

    if (skin.shape == PaperShape.rasgado) {
      hoja = ClipPath(clipper: const _Torn(), child: hoja);
    } else {
      hoja = ClipRRect(borderRadius: BorderRadius.circular(3), child: hoja);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: skin.gap),
      child: Transform.translate(
        offset: Offset(corre, 0),
        child: Transform.rotate(
          angle: lean * math.pi / 180,
          child: FractionallySizedBox(
            widthFactor: skin.inset,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: skin.shadow),
                      blurRadius: skin.shape == PaperShape.tapado ? 4 : 7,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    hoja,
                    // El listón que le cruza la cabeza al papel metido por
                    // detrás. Va encima del papel a propósito: es lo que dice
                    // que el papel está detrás y no clavado delante.
                    if (skin.shape == PaperShape.tapado)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 4,
                        child: Container(
                          height: 5,
                          color: skin.grain.dark.withValues(alpha: 0.8),
                        ),
                      ),
                    if (skin.pin == PinKind.cinta)
                      Positioned(
                        left: -12,
                        top: 8,
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Container(
                            width: 42,
                            height: 13,
                            color: skin.pinColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un papel rasgado por abajo.
class _Torn extends CustomClipper<Path> {
  const _Torn();

  @override
  Path getClip(Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 7);
    // Ocho dientes, siempre los mismos: un papel no cambia de rotura al
    // volver a mirarlo.
    const dientes = [0.0, 5.5, 1.5, 7.0, 2.5, 6.0, 1.0, 5.0, 2.0];
    for (var i = dientes.length - 1; i >= 0; i--) {
      p.lineTo(size.width * i / (dientes.length - 1), size.height - dientes[i]);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_Torn old) => false;
}

/// Lo que sujeta el papel.
class _Pin extends StatelessWidget {
  const _Pin({required this.skin});
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) {
    const sombra = BoxShadow(
      color: Colors.black38,
      blurRadius: 3,
      offset: Offset(0, 1),
    );
    switch (skin.pin) {
      case PinKind.chincheta:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: skin.pinColor,
            shape: BoxShape.circle,
            boxShadow: const [sombra],
          ),
        );
      case PinKind.clavo:
        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: skin.pinColor,
              boxShadow: const [sombra],
            ),
          ),
        );
      case PinKind.tachuela:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: skin.pinColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
        );
      case PinKind.lacre:
        // Una gota de lacre no es un círculo: se aplasta al sellarla.
        return Container(
          width: 14,
          height: 11,
          decoration: BoxDecoration(
            color: skin.pinColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [sombra],
          ),
        );
      case PinKind.cinta:
      case PinKind.ninguno:
        return const SizedBox.shrink();
    }
  }
}

/// A notice taken off the board and held up close: the same sentence, the
/// counts, and the shape they were read off.
class _Close extends StatelessWidget {
  const _Close({
    required this.notice,
    required this.skin,
    required this.index,
    required this.detail,
    required this.onBack,
  });

  final Notice notice;
  final BoardSkin skin;
  final int index;

  /// How far into the zoom we are. The extra detail fades in at the end, so
  /// the paper reads as one thing that got closer rather than two things.
  final double detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final late = ((detail - 0.45) / 0.55).clamp(0.0, 1.0);
    final ink = skin.ink;
    return Material(
      color: skin.papers[index % skin.papers.length],
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
                  if (skin.pin != PinKind.ninguno) _Pin(skin: skin),
                  const Spacer(),
                  GestureDetector(
                    onTap: onBack,
                    child: Opacity(
                      opacity: late,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notice.said,
                style: TextStyle(
                  color: ink,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notice.because,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.78),
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
                      painter: _Evidence(notice, ink),
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
                      Container(height: 1, color: ink.withValues(alpha: 0.12)),
                      const SizedBox(height: 12),
                      Text(
                        notice.more!,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.66),
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
  const _Evidence(this.notice, this.ink);
  final Notice notice;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = notice.bars;
    if (bars.isEmpty) return;
    final labels = notice.ticks.length == bars.length;
    final foot = labels ? 18.0 : 0.0;
    final h = size.height - foot - 2;
    final gap = bars.length > 14 ? 1.5 : 4.0;
    final w = (size.width - gap * (bars.length - 1)) / bars.length;

    final base = Paint()..color = ink.withValues(alpha: 0.22);
    final picked = Paint()..color = ink.withValues(alpha: 0.82);
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
        ..color = ink.withValues(alpha: 0.2)
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
            color: ink.withValues(alpha: on ? 0.8 : 0.45),
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
  bool shouldRepaint(_Evidence old) => old.notice != notice || old.ink != ink;
}

/// A board with nothing on it yet, which is the honest state of a young town.
class _Empty extends StatelessWidget {
  const _Empty({required this.habit, required this.skin});
  final Habit habit;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) {
    final days = daysOf(habit).length;
    final ink = skin.ink;
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
                if (skin.pin != PinKind.ninguno) ...[
                  _Pin(skin: skin),
                  const SizedBox(height: 12),
                ],
                Text(
                  'El tablón está vacío.',
                  style: TextStyle(
                    color: ink,
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
                    color: ink.withValues(alpha: 0.72),
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
