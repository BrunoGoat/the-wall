import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../model/habit.dart';
import 'board_plan.dart';
import 'paper_ink.dart';

/// Lo que cambia entre un fotograma y el siguiente.
///
/// Vive en un objeto y no en campos sueltos por un motivo concreto: el pintor
/// se construye una vez por `build` y se vuelve a pintar sesenta veces por
/// segundo sin volver a construirse. Con los números copiados dentro, el
/// pintor se quedaba con los de aquel `build` y repintaba lo mismo una y otra
/// vez, así que descolgar una nota se congelaba a medias: medio crecida, medio
/// torcida y con el texto a media tinta, y hasta dónde llegaba dependía de
/// cuándo hubiera ocurrido el último `build` por cualquier otro motivo. De ahí
/// que pareciera que a veces se acercaba y a veces no.
class BoardMotion {
  /// Qué hoja está descolgada, y cuánto lo está.
  int? open;
  double openK = 0;

  /// Cuánta ayuda se está enseñando. Se apaga sola en cuanto alguien toca.
  double hint = 1;

  /// Cuánto se ha tirado hacia atrás más allá del tope, de 0 a 1.
  double leaving = 0;
}

/// El tablón de la plaza, de cerca y en tres dimensiones.
///
/// No es una pantalla con el tablón dibujado: es el mismo tablón que está
/// clavado en la plaza, y las notas son hojas de papel con sitio en el mundo.
///
/// **Se ve en tres dimensiones pero se anda en dos.** La cámara llega, se
/// pone de frente y ahí se queda: no gira nunca. Lo único que se puede hacer
/// con los dedos es correrlo a izquierda y derecha, y eso está topado en el
/// filo de la madera, así que no hay manera de arrastrarse fuera del tablón y
/// quedarse mirando el prado. El zoom es una franja estrecha, para ajustar y
/// no para explorar; alejarse más allá de ella es la puerta de salida, y es la
/// única cosa que saca de aquí aparte de la flecha.
///
/// Lo que sí se mueve en tres dimensiones es la propia escena: descolgar una
/// nota lleva la cámara hasta ella. Eso lo decide la app, no el dedo, y por
/// eso puede permitirse lo que el dedo no.
///
/// Que las hojas sean geometría y no una lista es lo que hace que esto valga
/// la pena: una nota tapa a otra porque está delante, se tuerce porque está
/// clavada torcida, y se lee de lado si uno mira de lado.
class BoardScene extends StatefulWidget {
  const BoardScene({
    super.key,
    required this.plan,
    required this.habit,
    required this.palette,
    required this.onLeave,
    this.letra = 0,
    this.motion,
  });

  /// Para los tests: el objeto que se mueve, para poder mirarlo desde fuera.
  final BoardMotion? motion;

  /// Cambia cuando cambia la letra o el cuerpo elegidos en los ajustes. La
  /// escena no lee las preferencias: le basta con saber que algo cambió para
  /// volver a maquetar.
  final int letra;

  final BoardPlan plan;
  final Habit habit;
  final Palette palette;
  final VoidCallback onLeave;

  @override
  State<BoardScene> createState() => _BoardSceneState();
}

class _BoardSceneState extends State<BoardScene>
    with SingleTickerProviderStateMixin {
  final OrbitCamera _cam = OrbitCamera();
  late final Ticker _ticker = Ticker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// Cuánto ha girado el mundo desde que se abrió, en segundos.
  Duration _last = Duration.zero;

  /// Lo que se mueve. Lo lee el pintor en cada fotograma, no al construirse.
  late final BoardMotion _m = widget.motion ?? BoardMotion();
  static const double _umbralSalida = 0.5;

  Size _size = const Size(400, 800);

  /// La tinta de cada hoja, maquetada. Se rehace cuando cambia el plano o la
  /// letra elegida: maquetar es caro y la cámara se mueve sesenta veces por
  /// segundo, así que no puede hacerse al pintar.
  late List<PaperInk> _ink = _entintar();

  List<PaperInk> _entintar() => [
    for (final p in widget.plan.papers) PaperInk(p.notice),
  ];

  @override
  void didUpdateWidget(BoardScene old) {
    super.didUpdateWidget(old);
    if (!identical(old.plan, widget.plan) || old.letra != widget.letra) {
      _ink = _entintar();
      _m.open = null;
      _m.openK = 0;
      _cam.distanceTarget = widget.plan.readDistance(_size);
      _clampCam();
      _wake();
    }
  }

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _cam
      ..focusY = plan.midY
      ..focusYTarget = _cam.focusY
      ..focusZ = 0
      ..focusZTarget = 0
      ..travel = 0
      ..travelTarget = 0
      // Se llega andando: desde un lado y desde lejos, y la cámara se endereza
      // sola. Es la misma entrada que tenía la pantalla de antes —venía hacia
      // vos— sólo que ahora la hace la cámara y no una escala.
      // Se llega de lado y la cámara se endereza sola: es lo único que hace
      // en tres dimensiones por su cuenta, y es lo que dice de una vez que
      // esto es un sitio y no una lámina. A partir de ahí no vuelve a girar.
      ..yaw = 0.62
      ..pitch = 0.26
      ..distance = 9.0
      ..yawTarget = 0
      ..pitchTarget = 0;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (dt <= 0) return;
    _cam.step(dt);
    final quiere = _m.open == null ? 0.0 : 1.0;
    _m.openK += (quiere - _m.openK) * (1 - math.exp(-dt * 7.0));
    if (_m.hint > 0) _m.hint = math.max(0, _m.hint - dt * 0.32);
    _frame.value++;
    // Un tablón quieto no tiene por qué pintarse sesenta veces por segundo.
    // Se para solo cuando la cámara llega a donde iba, y lo despierta el
    // primer dedo que lo toque.
    if (_quieto) _ticker.stop();
  }

  bool get _quieto {
    final c = _cam;
    return (c.travel - c.travelTarget).abs() < 1e-4 &&
        (c.focusY - c.focusYTarget).abs() < 1e-4 &&
        (c.yaw - c.yawTarget).abs() < 1e-4 &&
        (c.pitch - c.pitchTarget).abs() < 1e-4 &&
        (c.distance - c.distanceTarget).abs() < 1e-4 &&
        ((_m.open == null ? 0.0 : 1.0) - _m.openK).abs() < 1e-3 &&
        _m.hint <= 0;
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  double get _near => widget.plan.nearLimit(_size);
  double get _far => widget.plan.farLimit(_size);

  /// Lo que puede hacer el dedo, y nada más.
  ///
  /// La cámara no gira: de frente y de frente se queda. Sólo se corre a lo
  /// largo del tablón, y hasta el filo de la madera: el tope sale de lo que la
  /// lente abarca desde donde está, así que al acercarse hay más que recorrer
  /// y al alejarse menos, hasta que el tablón cabe entero y no hay nada que
  /// correr.
  void _clampCam() {
    final plan = widget.plan;
    _cam.yawTarget = 0;
    _cam.pitchTarget = 0;
    // Con una nota descolgada, nada de topes: los coloca la app y están fuera
    // del alcance del dedo a propósito. Ver [_take].
    if (_m.open != null) return;
    _cam.distanceTarget = clampD(_cam.distanceTarget, _near, _far);
    _cam.focusYTarget = plan.midY;
    final tope = plan.panLimit(_size, _cam.distanceTarget);
    _cam.travelTarget = clampD(_cam.travelTarget, -tope, tope);
  }

  /// De vuelta al tablón, de frente y a la distancia de leer. No mueve el
  /// tablón a los lados: uno vuelve de una nota al sitio del tablón en el que
  /// estaba, no al principio.
  void _front() {
    setState(() => _m.open = null);
    _cam.distanceTarget = widget.plan.readDistance(_size);
    _clampCam();
    _wake();
  }

  /// Descolgar una hoja: la cámara se va a ella y la hoja crece.
  ///
  /// Esto se salta los topes del dedo a propósito, y por eso no llama a
  /// [_clampCam]: los topes existen para que nadie se pierda arrastrando, y
  /// una nota descolgada la coloca la app, más cerca de lo que el dedo puede
  /// llegar y centrada en ella y no en el tablón. Aplicarlos aquí —o al
  /// terminar el gesto que la abrió, que es lo que pasaba— deshacía el
  /// acercamiento entero, a veces sí y a veces no según qué llegara antes.
  void _take(int i) {
    final p = widget.plan.papers[i];
    setState(() => _m.open = i);
    _cam
      ..yawTarget = 0
      ..pitchTarget = 0
      ..travelTarget = p.openCx
      ..focusYTarget = p.openCy
      // Lo justo para que la hoja entre entera, por el lado que peor entre.
      ..distanceTarget = p.closeUpDistance(_size);
    _wake();
  }

  Projector _projector() => _cam.projector(_size.width, _size.height, 0);

  void _tap(Offset at) {
    _m.hint = 0;
    final p = _projector();
    final plan = widget.plan;
    // De delante hacia atrás: la hoja descolgada primero, que es la que está
    // encima de todas.
    final orden = [for (var i = 0; i < plan.papers.length; i++) i]
      ..sort((a, b) {
        if (a == _m.open) return 1;
        if (b == _m.open) return -1;
        return 0;
      });
    for (final i in orden.reversed) {
      final q = projectQuad(
        p,
        plan.papers[i].cornersAt(i == _m.open ? _m.openK : 0),
      );
      if (q != null && insideQuad(q, at)) {
        if (i == _m.open) {
          _front();
        } else {
          _take(i);
        }
        return;
      }
    }
    // La plancha: acercarse de frente.
    final plank = projectQuad(p, [
      V3(-plan.halfWidth, plan.high, BoardPlan.plankDepth),
      V3(plan.halfWidth, plan.high, BoardPlan.plankDepth),
      V3(plan.halfWidth, plan.low, BoardPlan.plankDepth),
      V3(-plan.halfWidth, plan.low, BoardPlan.plankDepth),
    ]);
    // La madera, el cielo o el prado: lo único que hace un toque fuera de una
    // nota es volver a colgar la que estuviera descolgada. De aquí no se sale
    // tocando —un dedo suelto en el prado no puede ser la puerta— sino
    // alejándose o con la flecha.
    if (plank != null && insideQuad(plank, at)) {
      if (_m.open != null) _front();
      return;
    }
    if (_m.open != null) _front();
  }

  void _drag(ScaleUpdateDetails d) {
    _m.hint = 0;
    _wake();
    if (d.pointerCount >= 2 && d.scale != 1) {
      // Pellizcar es lo único que cambia la distancia, y sólo dentro de la
      // franja. Pasado el tope de atrás no se para en seco: sigue yendo con
      // resistencia, que es lo que avisa de que ahí detrás está la salida.
      final quiere = _cam.distanceTarget / d.scale.clamp(0.5, 2.0);
      if (quiere > _far) {
        final sobra = (quiere - _far) / (_far * 0.55);
        _m.leaving = sobra.clamp(0.0, 1.0);
        _cam.distanceTarget = _far + (quiere - _far) * 0.45;
      } else {
        _m.leaving = 0;
        _cam.distanceTarget = clampD(quiere, _near, _far);
      }
    } else if (d.pointerCount == 1) {
      // Un dedo lo corre a lo largo y nada más. Lo de arriba y abajo se tira:
      // el tablón no tiene arriba y abajo a los que ir.
      final p = _projector();
      _cam.travelTarget -= d.focalPointDelta.dx * (_cam.distance / p.focal);
      // Un roce no cuelga la nota. El dedo que se apoya al tocar produce
      // arrastres de una décima de píxel, y con ellos la nota se cerraba en el
      // mismo gesto que la abría.
      if (_m.open != null && d.focalPointDelta.dx.abs() > 1.5) {
        setState(() => _m.open = null);
      }
    }
    final tope = widget.plan.panLimit(_size, _cam.distanceTarget);
    _cam.travelTarget = clampD(_cam.travelTarget, -tope, tope);
  }

  /// Al soltar: si se tiró bastante hacia atrás, se sale al valle; si no, el
  /// tablón vuelve a su sitio.
  void _release(ScaleEndDetails d) {
    if (_m.leaving > _umbralSalida) {
      widget.onLeave();
      return;
    }
    _m.leaving = 0;
    // Un toque también termina en un gesto de escala, así que si esto no
    // respetara la nota descolgada, abrirla y cerrarla serían la misma cosa.
    if (_m.open != null) {
      _wake();
      return;
    }
    _cam.distanceTarget = clampD(_cam.distanceTarget, _near, _far);
    _clampCam();
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        if (size != _size) {
          _size = size;
          // La distancia de entrada depende del tamaño real de la pantalla, y
          // eso no se sabe hasta aquí.
          if (_cam.distanceTarget == 9.0) {
            _cam.distanceTarget = widget.plan.readDistance(size);
            _cam.distance = _cam.distanceTarget * 2.4;
            // Se entra por el filo izquierdo y no por el medio. El tablón es
            // siempre igual de grande y se llena de izquierda a derecha, así
            // que un pueblo con dos notas las tiene todas a la izquierda: caer
            // en el medio sería caer mirando madera vacía.
            _cam.travelTarget = -widget.plan.panLimit(
              size,
              _cam.distanceTarget,
            );
            _cam.travel = _cam.travelTarget;
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: _drag,
          onScaleEnd: _release,
          onTapUp: (d) => _tap(d.localPosition),
          child: CustomPaint(
            size: Size.infinite,
            painter: BoardPainter(
              plan: widget.plan,
              ink: _ink,
              cam: _cam,
              palette: widget.palette,
              habit: widget.habit,
              motion: _m,
              repaint: _frame,
            ),
          ),
        );
      },
    );
  }
}

/// Proyecta las cuatro esquinas. Devuelve null si alguna se ha ido detrás del
/// ojo, que es cuando ya no hay cuadrilátero que valga.
List<Offset>? projectQuad(Projector p, List<V3> world) {
  final out = <Offset>[];
  for (final v in world) {
    final at = p.project(v);
    if (at == null) return null;
    out.add(Offset(at.x, at.y));
  }
  return out;
}

/// Dibuja el tablón.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.plan,
    required this.ink,
    required this.cam,
    required this.palette,
    required this.habit,
    required this.motion,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final BoardPlan plan;
  final List<PaperInk> ink;
  final OrbitCamera cam;
  final Palette palette;
  final Habit habit;

  /// Lo que se mueve. Se lee al pintar y no al construirse: el pintor se
  /// construye una vez por `build` y se pinta en cada fotograma, así que un
  /// número copiado aquí dentro se queda congelado.
  final BoardMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    final p = cam.projector(size.width, size.height, 0);
    final horizon = TownPainter.horizonOf(p, size);
    _sky(canvas, size, horizon);
    _ground(canvas, size, horizon);
    _shadow(canvas, p);
    _posts(canvas, p);
    _plank(canvas, p);
    _roof(canvas, p);
    _papers(canvas, p, size);
    _hint(canvas, size);
    if (motion.leaving > 0.01) {
      // Se va apagando conforme se tira hacia atrás, para que soltar y salir
      // no sea una sorpresa: cuando la pantalla ya está medio ida, soltar es
      // lo que uno espera que pase.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.55 * motion.leaving),
      );
    }
  }

  // ------------------------------------------------------------ el escenario

  void _sky(Canvas canvas, Size size, double horizon) {
    final hy = clampD(horizon, -size.height * 2, size.height * 3);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, math.max(hy, 0)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyHorizon],
        ).createShader(Rect.fromLTWH(0, 0, size.width, math.max(hy, 1))),
    );
  }

  void _ground(Canvas canvas, Size size, double horizon) {
    final hy = clampD(horizon, -size.height, size.height * 2);
    if (hy > size.height) return;
    canvas.drawRect(
      Rect.fromLTWH(0, hy, size.width, size.height - hy),
      Paint()..color = TownPainter.meadowTone(palette),
    );
  }

  /// La sombra que echa el tablón en la hierba. Sin ella el tablón flota.
  void _shadow(Canvas canvas, Projector p) {
    final quad = projectQuad(p, [
      V3(-plan.halfWidth - 0.2, 0.001, 0.5),
      V3(plan.halfWidth + 0.2, 0.001, 0.5),
      V3(plan.halfWidth + 0.1, 0.001, -0.22),
      V3(-plan.halfWidth - 0.1, 0.001, -0.22),
    ]);
    if (quad == null) return;
    canvas.drawPath(
      _path(quad),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * palette.daylight + 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  // -------------------------------------------------------------- la madera

  /// Un tono de la paleta: lo que dice el color por la luz que hay.
  Color _lit(Color base, double k) {
    final day = palette.daylight;
    final noche = Color.lerp(base, palette.skyHorizon, 0.55)!;
    final c = Color.lerp(noche, base, 0.35 + 0.65 * day)!;
    return Color.fromARGB(
      255,
      (c.r * 255 * k).clamp(0, 255).round(),
      (c.g * 255 * k).clamp(0, 255).round(),
      (c.b * 255 * k).clamp(0, 255).round(),
    );
  }

  /// Las caras de una caja que se ven desde donde está el ojo, de atrás a
  /// delante. En una caja convexa esto es exacto: una cara se ve exactamente
  /// cuando el ojo está del lado al que mira.
  void _box(
    Canvas canvas,
    Projector p,
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
    Color color,
  ) {
    // cara, normal, y cuánta luz le toca
    const caras = [
      ([0, 1, 2, 3], V3(0, 0, 1), 1.0),
      ([4, 5, 6, 7], V3(0, 0, -1), 0.62),
      ([1, 5, 6, 2], V3(1, 0, 0), 0.76),
      ([4, 0, 3, 7], V3(-1, 0, 0), 0.7),
      ([3, 2, 6, 7], V3(0, 1, 0), 1.16),
      ([4, 5, 1, 0], V3(0, -1, 0), 0.5),
    ];
    final v = [
      V3(x0, y0, z1),
      V3(x1, y0, z1),
      V3(x1, y1, z1),
      V3(x0, y1, z1),
      V3(x1, y0, z0),
      V3(x0, y0, z0),
      V3(x0, y1, z0),
      V3(x1, y1, z0),
    ];
    final visto = <(double, Path, Color)>[];
    for (final (idx, n, k) in caras) {
      final centro = V3(
        (v[idx[0]].x + v[idx[2]].x) / 2,
        (v[idx[0]].y + v[idx[2]].y) / 2,
        (v[idx[0]].z + v[idx[2]].z) / 2,
      );
      if ((centro - p.eye).dot(n) > 0) continue;
      final quad = projectQuad(p, [for (final i in idx) v[i]]);
      if (quad == null) continue;
      visto.add(((centro - p.eye).length, _path(quad), _lit(color, k)));
    }
    visto.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, path, c) in visto) {
      canvas.drawPath(path, Paint()..color = c);
      // El pelo de un píxel cierra la costura entre dos caras vecinas, que el
      // suavizado deja abierta.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = c,
      );
    }
  }

  void _posts(Canvas canvas, Projector p) {
    const t = BoardPlan.postThick;
    for (final s in [-1.0, 1.0]) {
      final x = s * (plan.halfWidth - t);
      _box(
        canvas,
        p,
        x - t / 2,
        0,
        -t / 2,
        x + t / 2,
        plan.postTop,
        t / 2,
        BoardPlan.post,
      );
    }
  }

  void _plank(Canvas canvas, Projector p) {
    _box(
      canvas,
      p,
      -plan.halfWidth,
      plan.low,
      -BoardPlan.plankDepth,
      plan.halfWidth,
      plan.high,
      BoardPlan.plankDepth,
      BoardPlan.wood,
    );
    // Sin juntas ni veta: la madera va lisa. Las líneas verticales partían el
    // tablón en columnas y el ojo las leía como si separaran algo.
    _name(canvas, p);
  }

  /// El nombre del hábito, quemado en el filo de arriba de la plancha.
  void _name(Canvas canvas, Projector p) {
    final texto =
        '${habit.name.toUpperCase()}   ·   '
        '${habit.place.region.toUpperCase()}';
    const alto = BoardPlan.headHeight;
    final quad = projectQuad(p, [
      V3(
        -plan.halfWidth + 0.1,
        plan.headY + alto,
        BoardPlan.plankDepth + 0.002,
      ),
      V3(plan.halfWidth - 0.1, plan.headY + alto, BoardPlan.plankDepth + 0.002),
      V3(plan.halfWidth - 0.1, plan.headY, BoardPlan.plankDepth + 0.002),
      V3(-plan.halfWidth + 0.1, plan.headY, BoardPlan.plankDepth + 0.002),
    ]);
    if (quad == null) return;
    final ancho = (quad[1] - quad[0]).distance;
    if (ancho < 60) return;
    // La caja de maquetar tiene que tener la proporción del hueco al que va,
    // porque la homografía estira lo que le den hasta las cuatro esquinas. Con
    // una caja fija, un tablón ancho estiraba las letras a lo largo y el
    // nombre salía deformado: cuanto más ancho el tablón, más deformado. Sale
    // de las medidas del mundo, así que vale para cualquier ancho.
    final src = plan.headBox;
    final m = paperTransform(src, quad);
    if (m == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: _lit(BoardPlan.post, 1).withValues(alpha: 0.8),
          fontSize: 26,
          letterSpacing: 6,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: src.width);
    canvas.save();
    canvas.transform(m);
    tp.paint(
      canvas,
      Offset((src.width - tp.width) / 2, (src.height - tp.height) / 2),
    );
    canvas.restore();
  }

  /// El tejadito a dos aguas: dos faldones y los dos hastiales.
  void _roof(Canvas canvas, Projector p) {
    final w = plan.halfWidth + BoardPlan.eave;
    const d = BoardPlan.roofDepth;
    final y0 = plan.high, y1 = plan.top;
    final caras = <(List<V3>, double)>[
      // el faldón de delante
      ([V3(-w, y0, d), V3(w, y0, d), V3(w, y1, 0), V3(-w, y1, 0)], 1.18),
      // el de detrás
      ([V3(w, y0, -d), V3(-w, y0, -d), V3(-w, y1, 0), V3(w, y1, 0)], 0.66),
      // los dos hastiales
      ([V3(w, y0, d), V3(w, y0, -d), V3(w, y1, 0)], 0.8),
      ([V3(-w, y0, -d), V3(-w, y0, d), V3(-w, y1, 0)], 0.74),
      // y el alero visto desde abajo
      ([V3(-w, y0, -d), V3(w, y0, -d), V3(w, y0, d), V3(-w, y0, d)], 0.46),
    ];
    final visto = <(double, Path, Color)>[];
    for (final (vs, k) in caras) {
      final quad = projectQuad(p, vs);
      if (quad == null) continue;
      final n = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized;
      final centro = V3(
        vs.map((v) => v.x).reduce((a, b) => a + b) / vs.length,
        vs.map((v) => v.y).reduce((a, b) => a + b) / vs.length,
        vs.map((v) => v.z).reduce((a, b) => a + b) / vs.length,
      );
      if ((centro - p.eye).dot(n) > 0) continue;
      visto.add((
        (centro - p.eye).length,
        _path(quad),
        _lit(BoardPlan.shingle, k),
      ));
    }
    visto.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, path, c) in visto) {
      canvas.drawPath(path, Paint()..color = c);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = c,
      );
    }
  }

  // --------------------------------------------------------------- el papel

  void _papers(Canvas canvas, Projector p, Size size) {
    final orden = <(double, int, List<Offset>)>[];
    for (var i = 0; i < plan.papers.length; i++) {
      final abierta = i == motion.open ? motion.openK : 0.0;
      final esquinas = plan.papers[i].cornersAt(abierta);
      final quad = projectQuad(p, esquinas);
      if (quad == null) continue;
      final centro = V3(
        (esquinas[0].x + esquinas[2].x) / 2,
        (esquinas[0].y + esquinas[2].y) / 2,
        (esquinas[0].z + esquinas[2].z) / 2,
      );
      orden.add(((centro - p.eye).length, i, quad));
    }
    // De lejos a cerca, y la descolgada siempre la última: se ha despegado del
    // tablón y tiene que tapar a las demás aunque su centro caiga detrás.
    orden.sort((a, b) {
      if (a.$2 == motion.open) return 1;
      if (b.$2 == motion.open) return -1;
      return b.$1.compareTo(a.$1);
    });

    for (final (_, i, quad) in orden) {
      // Justo antes de la descolgada se echa un velo sobre todo lo demás. Sin
      // él la nota crecía delante de un tablón igual de nítido que ella y no
      // había manera de saber cuál se estaba leyendo.
      if (i == motion.open && motion.openK > 0.01) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = Colors.black.withValues(
              alpha: 0.5 * motion.openK.clamp(0, 1),
            ),
        );
      }
      final path = _path(quad);
      // La sombra que echa la hoja sobre la madera.
      canvas.drawPath(
        path.shift(const Offset(2, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(path, Paint()..color = _lit(plan.papers[i].paper, 1.0));

      // El texto entra cuando la hoja es bastante grande en pantalla para que
      // signifique algo. De lejos una hoja es papel claro sobre madera, que es
      // exactamente lo que es en la plaza.
      // La descolgada se lee entera desde el primer fotograma. Se ganaba el
      // desvanecido por ser pequeña en pantalla, y durante el vuelo hacia ella
      // eso se veía como un papel translúcido.
      final ancho = (quad[1] - quad[0]).distance;
      final detail = i == motion.open
          ? 1.0
          : ((ancho - 54) / 90).clamp(0.0, 1.0);
      if (detail <= 0.02) continue;
      final m = paperTransform(PaperInk.box, quad);
      if (m == null) continue;
      canvas.save();
      canvas.clipPath(path);
      canvas.transform(m);
      ink[i].paint(canvas, i == motion.open ? motion.openK : 0.0, detail);
      canvas.restore();
    }
  }

  void _hint(Canvas canvas, Size size) {
    final hint = motion.hint;
    if (hint <= 0.02) return;
    final tp = TextPainter(
      text: TextSpan(
        text: 'Arrastrá a los lados · tocá una nota · alejá para salir',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85 * hint),
          fontSize: 11.5,
          letterSpacing: 0.4,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 46));
  }

  static Path _path(List<Offset> q) {
    final path = Path()..moveTo(q[0].dx, q[0].dy);
    for (var i = 1; i < q.length; i++) {
      path.lineTo(q[i].dx, q[i].dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
