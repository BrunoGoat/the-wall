import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../data/bandos.dart';
import '../engine/solids.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/board.dart';
import '../model/board_slots.dart';
import '../model/findings.dart';
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
    this.dice = false,
  });

  /// Los pueblos del valle, [habit] incluido: de ahí salen las notas que
  /// comparan dos hábitos y la corona. Pide la lista y no el almacén para que
  /// se le pueda enseñar un valle inventado sin tocar el de verdad.
  final List<Habit> valley;
  final Habit habit;
  final UiTheme theme;

  /// Enseña un dado que vuelve a repartir el tablón con notas al azar.
  ///
  /// Sólo para el tablón de mentira de los ajustes. Es lo que hace falta para
  /// probar una letra y un cuerpo de verdad: con las notas de siempre uno mira
  /// diez papeles y se queda tranquilo, y el que se sale por el borde es el
  /// bando número trescientos doce, que no ha visto nunca.
  final bool dice;

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
    // La vuelta dura algo más que antes porque ya no es un corte al final del
    // tirón hacia atrás: se pide a mitad, y lo que se ve es el tablón
    // alejándose mientras se abre el pueblo debajo.
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) =>
        NoticeBoardScreen(valley: valley, habit: habit, theme: theme),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: a,
        curve: Curves.easeOutCubic,
        // Al irse, tarda en empezar a borrarse y luego se va de golpe: así el
        // tablón se lee todavía durante el primer trozo del tirón, que es
        // cuando la cámara aún no ha ganado velocidad.
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  /// La hora con la que se pinta el cielo del tablón. La misma que el valle,
  /// hora fingida incluida: si no, se entra al tablón y amanece de golpe.
  double get _hora {
    if (Appearance.instance.fakeHour) return Appearance.instance.fakeHourAt;
    final now = DateTime.now();
    return now.hour + now.minute / 60.0;
  }

  late BoardPlan _plan;

  /// Qué tirada del dado va. Cero es el tablón de verdad.
  int _roll = 0;

  @override
  void initState() {
    super.initState();
    _plan = _real();
  }

  BoardPlan _real() {
    final said = boardNotices(widget.habit, valley: widget.valley);
    return BoardPlan.of(
      said,
      // Dónde quedó clavado cada papel. La misma tabla que mira el pueblo para
      // dibujar la silueta de su tablón, así que lo que se ve desde el valle y
      // lo que se ve al entrar es lo mismo.
      slots: BoardSlots.instance.assign(
        widget.habit.id,
        said,
        slots: NoticeBoard.capacity,
      ),
    );
  }

  /// Un tablón lleno de lo que haya: las notas del pueblo mezcladas con bandos
  /// sacados al azar de los cuatrocientos treinta y seis.
  ///
  /// Los huecos también van al azar y no por la tabla de siempre: lo que se
  /// prueba con esto es si el texto cabe, y para eso hace falta que salgan los
  /// largos, los cortos y los raros, no los diez de siempre.
  void _tirar() {
    Sensory.instance.tick();
    final semilla = ++_roll * 7919 + DateTime.now().millisecondsSinceEpoch;
    final reales = boardNotices(
      widget.habit,
      valley: widget.valley,
    ).where((n) => n.kind != NoticeKind.pueblo).toList();
    final said = <Notice>[];
    final huecos = <int>[];
    final libres = [for (var i = 0; i < NoticeBoard.capacity; i++) i];
    for (var i = libres.length - 1; i > 0; i--) {
      final j = hashInt(i + 1, semilla, i, 5);
      final t = libres[i];
      libres[i] = libres[j];
      libres[j] = t;
    }
    for (var i = 0; i < NoticeBoard.capacity; i++) {
      // Una de cada tres de las de verdad, cuando las haya, y el resto bandos.
      final real = reales.isNotEmpty && hash01(semilla, i, 1) < 0.35;
      if (real) {
        said.add(reales[hashInt(reales.length, semilla, i, 2)]);
      } else {
        final (dice, y) = bandos[hashInt(bandos.length, semilla, i, 3)];
        said.add(Notice(NoticeKind.pueblo, dice, y));
      }
      huecos.add(libres[i]);
    }
    setState(() => _plan = BoardPlan.of(said, slots: huecos));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListenableBuilder(
      listenable: Appearance.instance,
      builder: (context, _) {
        // Sigue escuchando a Appearance porque el cielo del tablón lleva la
        // hora fingida de los ajustes.
        return Stack(
          children: [
            Positioned.fill(
              child: BoardScene(
                // La clave rehace las hojas en cada tirada del dado: maquetar
                // es caro y no puede hacerse al pintar.
                key: ValueKey(_roll),
                plan: _plan,
                habit: widget.habit,
                palette: widget.theme.palette,
                hourOfDay: _hora,
                onLeave: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (widget.dice)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: _tirar,
                    icon: const Icon(Icons.casino_outlined, size: 22),
                    color: Colors.white.withValues(alpha: 0.92),
                    tooltip: 'Volver a repartir el tablón',
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
