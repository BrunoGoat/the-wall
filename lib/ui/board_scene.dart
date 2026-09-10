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

/// El tablón de la plaza, de cerca y en tres dimensiones.
///
/// No es una pantalla con el tablón dibujado: es el mismo tablón que está
/// clavado en la plaza, con la misma cámara de órbita que el pueblo, y las
/// notas son hojas de papel con sitio en el mundo. Se recorre —un dedo lo
/// arrastra a lo largo, dos lo giran, pellizcar acerca— y se toca una hoja
/// para descolgarla.
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
  });

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

  /// Qué hoja está descolgada, y cuánto lo está.
  int? _open;
  double _openK = 0;

  /// Cuánta ayuda se está enseñando. Se apaga sola en cuanto alguien toca.
  double _hint = 1;

  Size _size = const Size(400, 800);
  late final List<PaperInk> _ink = [
    for (final p in widget.plan.papers) PaperInk(p.notice),
  ];

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
      ..yaw = 0.78
      ..pitch = 0.34
      ..distance = 9.0
      ..yawTarget = 0.42
      ..pitchTarget = 0.2;
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
    final quiere = _open == null ? 0.0 : 1.0;
    _openK += (quiere - _openK) * (1 - math.exp(-dt * 7.0));
    if (_hint > 0) _hint = math.max(0, _hint - dt * 0.32);
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
        ((_open == null ? 0.0 : 1.0) - _openK).abs() < 1e-3 &&
        _hint <= 0;
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Lo lejos que se puede estar: lo justo para verlo entero, y un poco más
  /// para que se vea de pie en el prado.
  double get _far => widget.plan.fitDistance(_size) * 1.35;

  void _clampCam() {
    final plan = widget.plan;
    _cam.yawTarget = clampD(_cam.yawTarget, -1.05, 1.05);
    _cam.pitchTarget = clampD(_cam.pitchTarget, -0.3, 0.8);
    _cam.distanceTarget = clampD(_cam.distanceTarget, 0.62, _far);
    _cam.travelTarget = clampD(
      _cam.travelTarget,
      -plan.halfWidth,
      plan.halfWidth,
    );
    _cam.focusYTarget = clampD(_cam.focusYTarget, plan.low, plan.top);
  }

  /// De frente al tablón, con todo a la vista.
  void _front() {
    setState(() => _open = null);
    _cam
      ..yawTarget = 0
      ..pitchTarget = 0.04
      ..travelTarget = 0
      ..focusYTarget = widget.plan.midY
      ..distanceTarget = widget.plan.fitDistance(_size);
    _clampCam();
  }

  /// Descolgar una hoja: la cámara se va a ella y la hoja crece.
  void _take(int i) {
    final p = widget.plan.papers[i];
    setState(() => _open = i);
    _cam
      ..yawTarget = 0
      ..pitchTarget = 0
      ..travelTarget = p.openCx
      ..focusYTarget = p.openCy
      // Lo justo para que la hoja llene el alto de la pantalla con aire.
      ..distanceTarget = p.h * BoardPaper.grown / BoardPlan.tanHalfFovY * 1.18;
    _clampCam();
  }

  Projector _projector() => _cam.projector(_size.width, _size.height, 0);

  void _tap(Offset at) {
    _hint = 0;
    final p = _projector();
    final plan = widget.plan;
    // De delante hacia atrás: la hoja descolgada primero, que es la que está
    // encima de todas.
    final orden = [for (var i = 0; i < plan.papers.length; i++) i]
      ..sort((a, b) {
        if (a == _open) return 1;
        if (b == _open) return -1;
        return 0;
      });
    for (final i in orden.reversed) {
      final q = projectQuad(
        p,
        plan.papers[i].cornersAt(i == _open ? _openK : 0),
      );
      if (q != null && insideQuad(q, at)) {
        if (i == _open) {
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
    if (plank != null && insideQuad(plank, at)) {
      if (_open != null) {
        _front();
      } else {
        setState(() {});
        _cam
          ..yawTarget = 0
          ..pitchTarget = 0.04
          ..distanceTarget = math.min(
            _cam.distanceTarget * 0.55,
            widget.plan.fitDistance(_size),
          );
        _clampCam();
      }
      return;
    }
    // El cielo o el prado: si hay una hoja descolgada se cuelga, y si no se
    // sale del tablón.
    if (_open != null) {
      _front();
    } else {
      widget.onLeave();
    }
  }

  void _drag(ScaleUpdateDetails d) {
    _hint = 0;
    _wake();
    if (d.pointerCount >= 2) {
      // Dos dedos: girar y acercar, que es mirar el tablón como objeto.
      if (d.scale != 1) _cam.distanceTarget /= d.scale.clamp(0.5, 2.0);
      _cam.yawTarget -= d.focalPointDelta.dx * 0.004;
      _cam.pitchTarget += d.focalPointDelta.dy * 0.003;
    } else {
      // Un dedo: recorrerlo. Cuánto mundo se anda por píxel sale de la lente y
      // de lo lejos que se esté, así que el tablón sigue al dedo igual de
      // cerca que de lejos en vez de dispararse al acercarse.
      final p = _projector();
      final k = _cam.distance / p.focal;
      _cam.travelTarget -= d.focalPointDelta.dx * k;
      _cam.focusYTarget += d.focalPointDelta.dy * k;
      if (_open != null) setState(() => _open = null);
    }
    _clampCam();
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
            _cam.distanceTarget = widget.plan.fitDistance(size);
            _cam.distance = _cam.distanceTarget * 1.55;
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: _drag,
          onTapUp: (d) => _tap(d.localPosition),
          child: CustomPaint(
            size: Size.infinite,
            painter: BoardPainter(
              plan: widget.plan,
              ink: _ink,
              cam: _cam,
              palette: widget.palette,
              habit: widget.habit,
              open: _open,
              openK: _openK,
              hint: _hint,
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
    required this.open,
    required this.openK,
    required this.hint,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final BoardPlan plan;
  final List<PaperInk> ink;
  final OrbitCamera cam;
  final Palette palette;
  final Habit habit;
  final int? open;
  final double openK;
  final double hint;

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
    _grain(canvas, p);
    _name(canvas, p);
  }

  /// Las juntas entre tablas, dibujadas en el plano de la plancha para que se
  /// tuerzan con ella.
  void _grain(Canvas canvas, Projector p) {
    final tablas = math.max(3, (plan.halfWidth * 2 / 0.42).round());
    final linea = Paint()
      ..color = _lit(BoardPlan.shingle, 1).withValues(alpha: 0.42)
      ..strokeWidth = 1.4;
    for (var i = 1; i < tablas; i++) {
      final x = -plan.halfWidth + 2 * plan.halfWidth * i / tablas;
      final a = p.project(V3(x, plan.low, BoardPlan.plankDepth + 0.001));
      final b = p.project(V3(x, plan.high, BoardPlan.plankDepth + 0.001));
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), linea);
    }
  }

  /// El nombre del hábito, quemado en el filo de arriba de la plancha.
  void _name(Canvas canvas, Projector p) {
    final texto =
        '${habit.name.toUpperCase()}   ·   '
        '${habit.place.region.toUpperCase()}';
    const alto = 0.115;
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
    const src = Size(600, 40);
    final m = paperTransform(src, quad);
    if (m == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: _lit(BoardPlan.post, 1).withValues(alpha: 0.85),
          fontSize: 21,
          letterSpacing: 5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: src.width);
    canvas.save();
    canvas.transform(m);
    tp.paint(canvas, Offset((src.width - tp.width) / 2, 8));
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
      final abierta = i == open ? openK : 0.0;
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
      if (a.$2 == open) return 1;
      if (b.$2 == open) return -1;
      return b.$1.compareTo(a.$1);
    });

    for (final (_, i, quad) in orden) {
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
      final ancho = (quad[1] - quad[0]).distance;
      final detail = ((ancho - 54) / 90).clamp(0.0, 1.0);
      if (detail <= 0.02) continue;
      final m = paperTransform(PaperInk.box, quad);
      if (m == null) continue;
      canvas.save();
      canvas.clipPath(path);
      canvas.transform(m);
      ink[i].paint(canvas, i == open ? openK : 0.0, detail);
      canvas.restore();
    }
  }

  void _hint(Canvas canvas, Size size) {
    if (hint <= 0.02) return;
    final tp = TextPainter(
      text: TextSpan(
        text: 'Arrastrá para recorrerlo · dos dedos lo giran · tocá una nota',
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
