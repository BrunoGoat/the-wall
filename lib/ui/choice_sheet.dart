import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import 'style.dart';

/// La única vez que esta app te pregunta algo.
///
/// Todo lo demás pasa solo: las casas salen del hash del pueblo, los hitos del
/// orden que le tocó al fundarlo, y no hay nada que decidir en ninguna
/// pantalla. Está bien que sea así — un botón y ninguna elección es la mitad
/// de lo que la hace descansada, y una app de hábitos llena de menús es una
/// app que se abandona.
///
/// Pero cada varias semanas, cuando toca empezar una obra grande, el pueblo
/// levanta la vista y pregunta. Dos obras que le tocaban igual de pronto; la
/// que no salga no se pierde, encabeza la lista de la próxima vez. Así que no
/// hay manera de elegir mal, que es lo que permite que la pregunta no dé
/// pereza: no estás optimizando nada, estás decidiendo en qué orden quieres
/// ver crecer tu propio valle.
///
/// Y se puede cerrar sin contestar. Entonces deciden ellos, que es lo que
/// hacían antes de que se pudiera elegir.
class ChoiceSheet extends StatefulWidget {
  const ChoiceSheet({
    super.key,
    required this.options,
    required this.place,
    required this.theme,
    required this.onPick,
    required this.onLeave,
  });

  final List<Landmark> options;
  final TownCharacter place;
  final UiTheme theme;
  final void Function(Landmark) onPick;

  /// Cerrar sin contestar. No es «luego lo pregunto otra vez»: es que deciden
  /// ellos, ahora, lo que habrían decidido solos.
  final VoidCallback onLeave;

  @override
  State<ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<ChoiceSheet> {
  /// Cuál está señalada. Ninguna hasta que se toca una: la hoja no llega con
  /// una respuesta ya puesta, porque entonces la de al lado tendría que
  /// ganarle a algo y no es lo que pasa — las dos empiezan iguales.
  int? _at;

  void _tap(int i) {
    Sensory.instance.tick();
    setState(() => _at = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Frosted(
      theme: t,
      strong: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fg.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('EL PUEBLO PREGUNTA', style: t.label),
            const SizedBox(height: 10),
            Text('¿Qué levantamos ahora?', style: t.title),
            const SizedBox(height: 6),
            Text(
              'Las dos están listas para empezar. La que no elijas será la '
              'primera la próxima vez.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.options.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _Option(
                mark: widget.options[i],
                place: widget.place,
                theme: t,
                chosen: _at == i,
                onTap: () => _tap(i),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _at == null
                    ? null
                    : () {
                        widget.onPick(widget.options[_at!]);
                        Navigator.of(context).pop();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent.withValues(alpha: 0.85),
                  foregroundColor: t.dark ? Colors.black : Colors.white,
                  disabledBackgroundColor: t.fg.withValues(alpha: 0.10),
                  disabledForegroundColor: t.fgFaint,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _at == null
                      ? 'Elegí una'
                      : 'Que empiecen: ${widget.options[_at!].name}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  widget.onLeave();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Que decidan ellos',
                  style: t.bodySoft.copyWith(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una de las dos, con la obra dibujada.
///
/// Dibujada y no descrita: son ciento y pico obras y sus nombres no siempre
/// dicen mucho —«atarazana», «lonja»— y lo que se está decidiendo es qué
/// quiere uno ver en su valle, que es una cosa que se decide mirando. Sale del
/// mismo render que el pueblo, con el mismo sol de ahora mismo.
class _Option extends StatelessWidget {
  const _Option({
    required this.mark,
    required this.place,
    required this.theme,
    required this.chosen,
    required this.onTap,
  });

  final Landmark mark;
  final TownCharacter place;
  final UiTheme theme;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: chosen ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: chosen ? t.accent.withValues(alpha: 0.85) : t.stroke,
            width: chosen ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: WorkPortrait(
                    mark: mark,
                    place: place,
                    palette: t.palette,
                  ),
                  size: const Size(82, 82),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mark.name,
                          style: t.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '${mark.cost}',
                        style: t.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: chosen ? t.accent : t.fgSoft,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        mark.cost == 1 ? 'pieza' : 'piezas',
                        style: t.bodySoft.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mark.blurb,
                    style: t.bodySoft.copyWith(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El retrato de una obra terminada, en la región de este pueblo.
///
/// El mismo motor que pinta el valle, encuadrado a ojo de pájaro sobre un
/// trozo de prado. Sin cielo y sin sierra: a ochenta píxeles, un cielo entero
/// es una banda de color que no dice nada y le roba sitio a lo que sí.
class WorkPortrait extends CustomPainter {
  WorkPortrait({
    required this.mark,
    required this.place,
    required this.palette,
  });

  final Landmark mark;
  final TownCharacter place;
  final Palette palette;

  /// Desde dónde se mira una obra para que entre entera en un cuadrado de
  /// [size].
  ///
  /// Aparte y pública para poder exigirle en un test que la obra entre de
  /// verdad. Lo tenía calculado a ojo con el radio y lo estaba fijando sobre
  /// los valores de la cámara en vez de sobre sus objetivos —que `snap()`
  /// copia por encima—, así que ni el encuadre ni el giro eran los que yo
  /// creía y el castillo salía cortado por la mitad. Ninguna de las dos cosas
  /// se ve leyendo el código: se ven mirando el retrato, o midiéndolo.
  static OrbitCamera frame(TownLayout layout, Size size) {
    var top = 1.0;
    final esquinas = <V3>[];
    for (final p in layout.pieces) {
      if (p.y1 > top) top = p.y1;
      esquinas
        ..add(V3(p.x0, p.y0, p.z0))
        ..add(V3(p.x1, p.y1, p.z1))
        ..add(V3(p.x0, p.y1, p.z1))
        ..add(V3(p.x1, p.y0, p.z0));
    }
    final cam = OrbitCamera()
      ..yawTarget = 0.62
      ..pitchTarget = 0.42
      ..focusYTarget = top * 0.44;
    cam.snap();
    // Medido sobre la proyección de verdad y no a ojo con el radio: un
    // castillo mide cuatro veces lo que una fuente, y con una regla al tanteo
    // se cortaban justo las obras que más ganas dan de ver. El margen deja un
    // dedo de aire alrededor.
    cam.distanceTarget = clampD(
      cam.distanceToFit(esquinas, size.width, size.height, margin: 0.80),
      4,
      120,
    );
    cam.snap();
    return cam;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TownLayout.showcase(
      place,
      landmark: mark,
      placed: mark.cost,
    );
    final cam = frame(layout, size);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = TownPainter.meadowTone(palette),
    );
    TownPainter(
      TownScene(
        placed: mark.cost,
        palette: palette,
        camera: cam,
        integrity: 1,
        time: 0,
        hourOfDay: palette.hour,
        effects: EffectSystem(),
        labelledBricks: const {},
        budget: 4000,
        towns: [
          TownEntry(
            layout: layout,
            name: mark.name,
            symbol: place.symbol,
            integrity: 1,
            placed: mark.cost,
          ),
        ],
        active: 0,
        labels: false,
      ),
      [],
      [],
      [],
      [],
      [],
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(WorkPortrait old) =>
      old.mark.id != mark.id ||
      old.place.order != place.order ||
      old.palette.hour != palette.hour;
}
