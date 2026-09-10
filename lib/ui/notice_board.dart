import 'package:flutter/material.dart';

import '../model/board.dart';
import '../model/habit.dart';
import 'board_plan.dart';
import 'board_scene.dart';
import 'style.dart';

/// El tablón de la plaza, al que uno se acerca.
///
/// Ya no es una pantalla con el tablón dibujado encima: es el tablón, el mismo
/// que está clavado en la plaza, con su cámara, sus postes, su tejadito y sus
/// hojas de papel puestas en el mundo. Se recorre y se tocan las hojas.
///
/// Todo lo que hay que saber de fuera son las notas, y ésas salen de lo que el
/// pueblo tiene apuntado. Ninguna existe hasta que hay bastante detrás para
/// que sea verdad, así que un tablón vacío no es un fallo: es el pueblo
/// diciendo que todavía no te conoce.
class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({
    super.key,
    required this.valley,
    required this.habit,
    required this.theme,
  });

  /// Los pueblos del valle, [habit] incluido: de ahí salen las notas que
  /// comparan dos hábitos y la corona. Pide la lista y no el almacén para que
  /// se le pueda enseñar un valle inventado sin tocar el de verdad.
  final List<Habit> valley;
  final Habit habit;
  final UiTheme theme;

  /// La ruta que te lleva hasta él. El acercamiento lo hace la cámara dentro
  /// de la escena —se llega al tablón desde un lado y desde lejos—, así que
  /// aquí sólo se funde: dos acercamientos, uno encima del otro, se pisan.
  static Route<void> route({
    required List<Habit> valley,
    required Habit habit,
    required UiTheme theme,
  }) => PageRouteBuilder<void>(
    opaque: false,
    barrierColor: sheetScrim(theme.dark),
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) =>
        NoticeBoardScreen(valley: valley, habit: habit, theme: theme),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
      child: child,
    ),
  );

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  late final BoardPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = BoardPlan.of(boardNotices(widget.habit, valley: widget.valley));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        Positioned.fill(
          child: BoardScene(
            plan: _plan,
            habit: widget.habit,
            palette: widget.theme.palette,
            onLeave: () => Navigator.of(context).maybePop(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 20),
              color: Colors.white.withValues(alpha: 0.92),
              tooltip: 'Volver al pueblo',
            ),
          ),
        ),
      ],
    ),
  );
}
