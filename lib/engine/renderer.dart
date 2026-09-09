import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/constellations.dart';
import '../core/math3.dart';
import '../core/rng.dart';
import '../fx/effects.dart';
import '../ui/habit_sigil.dart';
import 'bsp.dart';
import 'camera.dart';
import 'solid.dart';
import 'solids.dart';
import 'town.dart';
import 'world.dart';
import 'landscape.dart';
import 'palette.dart';

int _ch(double v) {
  final i = (v * 255.0).round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

/// One town in the valley, and what the habit behind it is called.
class TownEntry {
  const TownEntry({
    required this.layout,
    required this.name,
    required this.symbol,
    required this.integrity,
    required this.placed,
    this.crowned = false,
  });

  final TownLayout layout;
  final String name;
  final String symbol;

  /// How lit this town is. A habit left alone goes dark, and from across the
  /// valley that is the whole comparison: this one is alive, that one is not.
  final double integrity;
  final int placed;

  /// True for the town with the most pieces in the valley.
  final bool crowned;
}

/// One stone as it appears on screen this frame, kept so taps can be resolved
/// back to the brick that was drawn there.
/// El sitio que una pieza ocupa en la pantalla, para poder tocarla.
///
/// Antes era un círculo alrededor del centro de **una** cara: la primera que se
/// pintaba de esa pieza, que casi nunca es la que se está mirando. De ahí las
/// dos quejas — que el blanco es más chico que la pieza, y que a veces sale la
/// de debajo. Ahora es la caja de **todas** sus caras juntas, y lleva la
/// distancia de la más cercana, que es lo que decide quién gana cuando dos se
/// pisan: la de adelante. Una pieza no se toca a través de otra.
class PickTarget {
  PickTarget(
    this.brickIndex,
    this.x0,
    this.y0,
    this.x1,
    this.y1,
    this.near,
    this.labelled,
  );

  final int brickIndex;

  /// Lo que abarca en pantalla, creciendo con cada cara suya que se pinta.
  double x0, y0, x1, y1;

  /// A qué distancia del ojo está lo más cercano suyo.
  double near;

  /// True when this stone carries a note, so it can be marked on the wall.
  final bool labelled;

  bool holds(double x, double y, double slack) =>
      x >= x0 - slack && x <= x1 + slack && y >= y0 - slack && y <= y1 + slack;

  void grow(double ax, double ay, double bx, double by, double z) {
    if (ax < x0) x0 = ax;
    if (ay < y0) y0 = ay;
    if (bx > x1) x1 = bx;
    if (by > y1) y1 = by;
    if (z < near) near = z;
  }
}

/// Where a town's sign landed on screen, so it can be tapped.
///
/// The sign is the only thing you can read about a town from the far side of
/// the valley; tapping the thing you are reading and being taken there is what
/// anybody expects it to do.
class SignHit {
  const SignHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

/// Where a town's notice board landed on screen, so it can be read.
///
/// The board is a thing standing in the plaza and not a button floating over
/// the town, so this is worked out from the plank's own four corners.
/// La cúpula de un observatorio en pantalla, para que un dedo la encuentre.
///
/// Lo que se guarda es del valle y no de un pueblo, así que da igual cuál se
/// toque: todos abren el mismo cuaderno. Pero se toca el de un pueblo, que es
/// lo que hace que sea un sitio y no una pantalla de ajustes.
class DomeHit {
  const DomeHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

/// Dónde quedó la constelación de esta noche, para que un dedo la encuentre.
class SkyHit {
  const SkyHit(this.id, this.rect);
  final String id;
  final Rect rect;
}

class BoardHit {
  const BoardHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

class TownScene {
  TownScene({
    required this.placed,
    required this.palette,
    required this.camera,
    required this.integrity,
    required this.time,
    required this.effects,
    required this.labelledBricks,
    this.fx,
    this.budget = 16000,
    required this.towns,
    required this.active,
    this.finished,
    this.finishedAge = 99,
    this.selectedBrick,
    this.charge = 0,
    this.labels = true,
    this.tonight,
    this.tonightKnown = false,
    this.skyNight = 0,
    this.coat = true,
  });

  /// How many achievements have been laid.
  final int placed;
  final Palette palette;
  final OrbitCamera camera;
  final double integrity;
  final double time;
  final EffectSystem effects;

  /// How many faces are worth drawing this frame, trimmed to hold the frame
  /// rate on whatever phone this is.
  ///
  /// Faces and not pieces: a stake of a fence and a cathedral are both one
  /// achievement, and what the frame actually pays for is the face count.
  final int budget;

  /// Bricks the person wrote a note on.
  final Set<int> labelledBricks;

  final PlacementFx? fx;

  /// Every town in the valley, one per habit, and which of them is the one
  /// being built right now. They are all drawn: the whole point of a valley
  /// with several towns in it is being able to look at them together.
  final List<TownEntry> towns;
  final int active;

  TownLayout get town => towns[active].layout;

  /// The building that has just been finished, and how long ago in seconds.
  /// A house takes days to build and a second to celebrate.
  final int? finished;
  final double finishedAge;

  /// The stone the person just tapped, ringed so it is obvious which one the
  /// note belongs to.
  final int? selectedBrick;

  /// 0..1 while the place button is held down.
  final double charge;

  /// Qué noche es ésta. Decide dónde se cuelga la constelación, y se queda
  /// quieta hasta el mediodía siguiente.
  final int skyNight;

  /// La constelación que se puede ver esta noche, si hay noche y si en el
  /// valle hay un observatorio en pie. Nula el resto del tiempo.
  final Constellation? tonight;

  /// Si esa constelación ya está anotada. Una anotada se sigue viendo —el
  /// cielo no se apaga porque la hayas mirado— pero más floja y con su nombre.
  final bool tonightKnown;

  /// Si el prado lleva su paño de manchas. Siempre, salvo para el test que
  /// mide cuánto se raya el suelo sin él — una regla que sólo mira el
  /// resultado bueno no distingue «lo arreglé» de «mi regla no mide nada».
  final bool coat;

  /// Whether the landmark names are hung over the buildings. The exhibition
  /// hall says the name in its own header, and a second one floating in the
  /// sky over an empty world is only clutter.
  final bool labels;
}

class _Face {
  final Float32List pts = Float32List(56);
  int n = 0;
  int color = 0;
}

/// The three colours a house is painted in.
class _Tone {
  const _Tone(this.wall, this.stone, this.tile);
  final Color wall, stone, tile;
}

/// Draws the whole world: sky, ground, the wall in full detail nearby, and its
/// own silhouette receding into the haze when it gets long.
class TownPainter extends CustomPainter {
  TownPainter(
    this.scene,
    this.picks,
    this.signs,
    this.boards,
    this.skies,
    this.domes,
  );

  final TownScene scene;
  final List<PickTarget> picks;

  /// Filled every frame: where each town's sign is, for the gesture layer.
  final List<SignHit> signs;

  /// And where each town's notice board is.
  final List<BoardHit> boards;

  /// Se rellena al pintar: dónde cayó la constelación de esta noche.
  final List<SkyHit> skies;

  /// Y dónde cayó cada cúpula.
  final List<DomeHit> domes;

  /// Room for everything the budget can ask for, with slack. A face that does
  /// not fit here is silently not drawn, which is a hole in a house — so the
  /// pool has to stay ahead of the budget rather than the other way round.
  static final List<_Face> _facePool = List.generate(26000, (_) => _Face());
  static final Float64List _clipA = Float64List(96);
  static final Float64List _clipB = Float64List(96);
  static final Path _scratch = Path();

  int _faceCount = 0;

  /// Where the lit windows landed on screen this frame, so their light can be
  /// laid over the town after the masonry is down. x, y, radius, strength.
  final List<double> _lamps = [];

  /// True while the town being painted is the one being built, so a tap is
  /// only ever resolved against a piece of that town.
  bool _picking = false;

  /// The colours each house is painted in, worked out once per town.
  final Map<int, _Tone> _tone = {};

  /// Pieces already given a tap target this frame.

  /// How high the finishing wave has climbed, and how bright it still is.
  double _sweep = -1;
  double _sweepFade = 0;

  /// The piece in the air, built fresh every frame because it is the one thing
  /// in the town that moves.
  BspTree? _falling;
  int _fallingPiece = -1;

  /// Whether the piece in the air has gone down yet this frame, so it goes
  /// down exactly once — with its own building if that building was drawn, and
  /// at the end if it never was.
  bool _fallingPainted = false;

  _Face? _nextFace() {
    if (_faceCount >= _facePool.length) return null;
    return _facePool[_faceCount++];
  }

  @override
  void paint(Canvas canvas, Size size) {
    picks.clear();
    _pickAt.clear();
    signs.clear();
    boards.clear();
    skies.clear();
    domes.clear();
    _faceCount = 0;
    _lamps.clear();

    final p = scene.camera.projector(size.width, size.height, scene.time);
    final horizonY = _horizonY(p, size);
    final town = scene.town;

    _drawSky(canvas, size, p, horizonY);
    _drawGround(canvas, size, p, horizonY);
    _drawRanges(canvas, p, size, horizonY);
    for (final e in scene.towns) {
      _drawTownGround(canvas, p, e.layout);
    }
    _drawRings(canvas, p, town, overlay: false);
    _collectTown(p, size);
    _flush(canvas);
    _drawLamps(canvas, size);
    _drawBirds(canvas, p, size, town);
    _drawRings(canvas, p, town, overlay: true);
    _drawTownGhost(canvas, p, size, town);
    _drawTownLabels(canvas, p, size, town);
    _drawTownSigns(canvas, p, size);
    _findBoards(p, size);
    _findDomes(p, size);
    _drawParticles(canvas, p);
    _drawAtmosphere(canvas, size, horizonY);
  }

  // ------------------------------------------------------------------- sky

  double _horizonY(Projector p, Size size) {
    final f = p.forward;
    var hx = f.x, hz = f.z;
    final l = math.sqrt(hx * hx + hz * hz);
    if (l < 1e-5) return -size.height; // looking straight down
    hx /= l;
    hz /= l;
    final d = V3(hx, 0, hz);
    final den = d.dot(p.forward);
    if (den.abs() < 1e-5) return -size.height;
    return p.cy - p.focal * (d.dot(p.up) / den);
  }

  /// Dónde cae en pantalla algo que está infinitamente lejos, dado su azimut y
  /// su elevación.
  ///
  /// Las estrellas, las fugaces y las tres cordilleras usan esto mismo, y ése
  /// es el asunto: son las tres cosas de esta escena que están tan lejos que
  /// sólo giran con la cámara y no se mueven con ella. La cuenta no tiene un
  /// solo término con `eye` dentro, y por eso trasladar el ojo —caminar por el
  /// valle, alejarse, subir— no las mueve ni un píxel.
  ///
  /// De ahí sale además, gratis, la propiedad que hacía falta: la elevación
  /// cero cae exactamente en la línea del horizonte, que es donde el suelo
  /// empieza a dibujarse. Un pie de montaña no puede quedar por debajo del
  /// prado.
  @visibleForTesting
  static Offset? skyPoint(
    Projector p,
    double az,
    double el, {
    double minDen = 0.03,
  }) {
    final ce = math.cos(el);
    final d = V3(math.sin(az) * ce, math.sin(el), math.cos(az) * ce);
    final den = d.dot(p.forward);
    if (den <= minDen) return null;
    return Offset(
      p.cx + p.focal * d.dot(p.right) / den,
      p.cy - p.focal * d.dot(p.up) / den,
    );
  }

  void _drawSky(Canvas canvas, Size size, Projector p, double horizonY) {
    final pal = scene.palette;
    final h = size.height;
    final top = 0.0;
    final hy = clampD(horizonY, -h * 3, h * 4);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final span = math.max(1.0, hy - top);
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, hy - span), Offset(0, hy), [
        pal.skyTop,
        pal.skyHorizon,
      ]);
    canvas.drawRect(rect, paint);

    if (pal.starAlpha > 0.02) {
      _drawStars(canvas, size, p, horizonY);
      _drawConstellation(canvas, size, p, horizonY);
      _drawShootingStar(canvas, size, p, horizonY);
    }
    _drawSun(canvas, size, p);

    // A soft band of haze sitting on the horizon.
    if (hy > -h && hy < h * 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, hy - h * 0.22, size.width, h * 0.22),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, hy - h * 0.22),
            Offset(0, hy),
            [
              pal.skyHorizon.withValues(alpha: 0),
              pal.haze.withValues(alpha: 0.85),
            ],
          ),
      );
    }
  }

  void _drawStars(Canvas canvas, Size size, Projector p, double horizonY) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 130; i++) {
      final az = hash01(i, 3) * math.pi * 2;
      final el = 0.06 + hash01(i, 5) * 1.4;
      final at = skyPoint(p, az, el, minDen: 0.05);
      if (at == null) continue;
      final sx = at.dx, sy = at.dy;
      if (sx < 0 || sx > size.width || sy < 0 || sy > horizonY) continue;
      final tw = 0.55 + 0.45 * math.sin(scene.time * 1.7 + i * 2.1);
      paint.color = Colors.white.withValues(
        alpha: (0.25 + 0.55 * hash01(i, 9)) * tw * scene.palette.starAlpha,
      );
      canvas.drawCircle(Offset(sx, sy), 0.6 + hash01(i, 11) * 1.1, paint);
    }
  }

  /// La constelación de esta noche.
  ///
  /// Colgada del cielo por su forma real: las coordenadas de sus estrellas son
  /// las del catálogo, y `hang` rehace el plano tangente donde se la ponga, así
  /// que los ángulos entre ellas son los de verdad. Lo que se ve es la figura
  /// que se ve levantando la cabeza, no una parecida.
  ///
  /// Dónde se cuelga lo decide la noche y no el reloj: pasa la noche entera en
  /// el mismo sitio del cielo, que es lo que permite salir a buscarla. Girar
  /// la cámara la encuentra; esperar, no.
  void _drawConstellation(
    Canvas canvas,
    Size size,
    Projector p,
    double horizonY,
  ) {
    final c = scene.tonight;
    if (c == null) return;
    final night = scene.skyNight;
    final az = hash01(night, 77) * math.pi * 2;
    // Colgada por su borde de abajo y no por su centro. Lo que hay que
    // garantizar es que el pie de la figura quede unos grados por encima del
    // horizonte —si no, se la come una cordillera— y eso depende de lo ancha
    // que sea: Escorpio ocupa veinticinco grados de cielo y la Cruz del Sur
    // seis. Puesta por el centro, la grande quedaba fuera de la pantalla.
    final el = c.spread * 0.5 + 0.09 + hash01(night, 79) * 0.11;

    final known = scene.tonightKnown;
    // Una sin anotar respira, para que se note que hay algo que hacer con
    // ella. Una anotada se queda quieta: ya cumplió.
    final beat = known ? 1.0 : 0.78 + 0.22 * math.sin(scene.time * 1.15);
    final ink = scene.palette.starAlpha * (known ? 0.42 : 0.95) * beat;
    if (ink < 0.03) return;

    final at = <Offset?>[];
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    var seen = 0;
    for (final (sa, se) in hang(c, az, el)) {
      final o = skyPoint(p, sa, se, minDen: 0.10);
      at.add(o);
      if (o == null) continue;
      seen++;
      if (o.dx < x0) x0 = o.dx;
      if (o.dx > x1) x1 = o.dx;
      if (o.dy < y0) y0 = o.dy;
      if (o.dy > y1) y1 = o.dy;
    }
    // Media figura no es una figura: o se ve entera o no se ofrece.
    if (seen < c.stars.length) return;
    if (x1 < 0 || x0 > size.width || y1 < 0 || y0 > horizonY) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: ink * 0.34);
    for (var k = 0; k + 1 < c.lines.length; k += 2) {
      final a = at[c.lines[k]], b = at[c.lines[k + 1]];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, line);
    }
    final dot = Paint()..color = Colors.white;
    for (var i = 0; i < at.length; i++) {
      final o = at[i];
      if (o == null) continue;
      // Por magnitud, y al revés de lo que parece: cuanto más chica, más
      // brilla. Sirio en menos uno y media tiene que verse como Sirio.
      final mag = c.stars[i].mag;
      final size01 = clampD((3.2 - mag) / 4.6, 0.22, 1.0);
      dot.color = Colors.white.withValues(alpha: ink * (0.55 + 0.45 * size01));
      canvas.drawCircle(o, 1.0 + 1.9 * size01, dot);
    }

    final box = Rect.fromLTRB(x0, y0, x1, y1).inflate(16);
    if (!known) skies.add(SkyHit(c.id, box));

    // El nombre sólo cuando ya está anotada. Antes de anotarla, decirlo sería
    // contestar la pregunta: la gracia es reconocerla.
    if (known) {
      final tp = TextPainter(
        text: TextSpan(
          text: c.name.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: ink * 0.9),
            fontSize: 9.5,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(box.center.dx - tp.width / 2, box.bottom + 2));
    }
  }

  /// Una estrella fugaz, cada tanto, cuando hay noche.
  ///
  /// Sin nada que guardar: el tiempo se parte en ventanas, y de qué ventana es
  /// éste decide —siempre igual— si hay una, cuándo dentro de la ventana y por
  /// dónde. Un estado más en la escena para algo que dura segundo y pico sería
  /// un estado más que mantener sincronizado con la pausa, con el rebobinado
  /// del expositor y con la hora fingida de los ajustes.
  ///
  /// Y no en todas las ventanas. Una que se puede esperar deja de ser un
  /// hallazgo: la gracia de mirar al cielo es que casi nunca pasa nada.
  void _drawShootingStar(
    Canvas canvas,
    Size size,
    Projector p,
    double horizonY,
  ) {
    const window = 24.0;
    const flight = 1.15;
    final epoch = (scene.time / window).floor();
    if (hash01(epoch, 401) > 0.30) return;
    final began = epoch * window + hash01(epoch, 403) * (window - flight);
    final u = (scene.time - began) / flight;
    if (u < 0 || u > 1) return;

    // De donde sale y hacia dónde va. Bajas y en diagonal, que es como se ven:
    // una raya en mitad del cielo parece un avión.
    final az0 = hash01(epoch, 405) * math.pi * 2;
    final el0 = 0.22 + hash01(epoch, 407) * 0.55;
    final sweep =
        (hash01(epoch, 409) < 0.5 ? -1 : 1) *
        (0.20 + hash01(epoch, 411) * 0.22);
    final drop = 0.10 + hash01(epoch, 413) * 0.16;

    Offset? at(double k) {
      final el = el0 - drop * k;
      if (el <= 0.01) return null;
      return skyPoint(p, az0 + sweep * k, el, minDen: 0.08);
    }

    // Entra y se apaga: nunca aparece ni desaparece de golpe.
    final glow =
        math.pow(math.sin(math.pi * u), 0.65).toDouble() *
        scene.palette.starAlpha;
    if (glow < 0.02) return;

    const tail = 0.13;
    const bits = 7;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < bits; i++) {
      final a = at(u - tail * (i + 1) / bits);
      final b = at(u - tail * i / bits);
      if (a == null || b == null) continue;
      if (b.dy > horizonY || a.dy > horizonY) continue;
      // La cola se afina y se apaga hacia atrás, que es lo que la hace cola.
      final k = 1 - i / bits;
      paint
        ..color = Colors.white.withValues(alpha: glow * k * k * 0.85)
        ..strokeWidth = 0.5 + 1.3 * k;
      canvas.drawLine(a, b, paint);
    }
    final head = at(u);
    if (head != null && head.dy <= horizonY) {
      canvas.drawCircle(
        head,
        1.7,
        Paint()..color = Colors.white.withValues(alpha: glow),
      );
    }
  }

  /// The sun through the day, the moon through the night. Both ride the same
  /// arc, which is what makes the shadows swing round as the hours pass.
  void _drawSun(Canvas canvas, Size size, Projector p) {
    final pal = scene.palette;
    final day = pal.isDaylight;
    final d = day ? pal.sunDir : pal.moonDir;
    final den = d.dot(p.forward);
    if (den <= 0.08) return;
    final sx = p.cx + p.focal * d.dot(p.right) / den;
    final sy = p.cy - p.focal * d.dot(p.up) / den;
    if (sx < -400 || sx > size.width + 400) return;

    final r = size.shortestSide * (day ? 0.052 : 0.040);
    final glow = day ? 5.5 : 3.4;
    // Low sun reddens and swells, the way it does near the horizon.
    final low = 1 - clampD(d.y * 2.4, 0, 1);
    final disc = day
        ? Color.lerp(pal.sun, const Color(0xFFFF9A4D), low * 0.55)!
        : const Color(0xFFEFF3FF);

    canvas.drawCircle(
      Offset(sx, sy),
      r * glow * (1 + low * 0.5),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(sx, sy),
          r * glow * (1 + low * 0.5),
          [
            disc.withValues(alpha: day ? 0.32 : 0.20),
            disc.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      r,
      Paint()..color = disc.withValues(alpha: 0.94),
    );
    if (!day) {
      // A bite out of the disc, so it reads as a moon and not a pale sun.
      canvas.drawCircle(
        Offset(sx + r * 0.42, sy - r * 0.30),
        r * 0.88,
        Paint()..color = pal.skyTop.withValues(alpha: 0.92),
      );
    }
  }

  void _drawGround(Canvas canvas, Size size, Projector p, double horizonY) {
    final pal = scene.palette;
    final hy = clampD(horizonY, -size.height, size.height * 2);
    if (hy > size.height) return;
    final rect = Rect.fromLTWH(0, hy, size.width, size.height - hy);
    if (rect.height <= 0) return;
    // The town stands in a meadow, and a meadow is a meadow at midnight too.
    //
    // The green used to be applied only in daylight, so after dark the field
    // fell back to the bare ground colour — a neutral blue-black, and the same
    // blue-black the hills behind it are made of. Field and skyline became one
    // dark shape with a line through it. At night it takes a deep blue-green
    // instead: dark enough to be night, green enough to still be grass.
    //
    // Blended by how much of a day it is rather than by whether the sun is up,
    // because the second of those changes colour in a single frame.
    final (far, near) = meadowTone(pal);
    final lift = scene.coat ? meadowLift(pal) : const Color(0x00000000);
    // Se teje antes de descontar, porque lo que hay que descontar es
    // exactamente lo que el paño suma de media, y eso lo sabe el paño.
    if (scene.coat) _coatTile();
    // El paño no llega hasta el horizonte, y no por ahorrar. Una mancha
    // redonda del suelo vista casi de canto se proyecta como una cinta
    // larguísima y finísima: la perspectiva la estira a lo ancho hasta
    // convertirla en otra raya horizontal, que es justo lo que se venía a
    // quitar. Tampoco hace falta que llegue —la hierba a doscientos metros no
    // tiene manchas, tiene un verde—, así que entra poco a poco, y despacio al
    // principio porque el aplastamiento cerca del horizonte es brutal y se
    // suelta despacio.
    //
    // El descuento del degradado usa la misma rampa y los mismos tramos. Los
    // dos son rectos entre tramo y tramo, así que lo que uno suma y lo que el
    // otro resta se cancelan píxel a píxel y no sólo de media.
    final stops = <double>[];
    final ramp = <double>[];
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      stops.add(t);
      ramp.add(math.pow(clampD(t / 0.62, 0, 1), 2.2).toDouble());
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, hy), Offset(0, size.height), [
          for (var i = 0; i < stops.length; i++)
            _sink(Color.lerp(far, near, stops[i])!, lift, ramp[i]),
        ], stops),
    );
    _drawMeadowCoat(canvas, rect, p, lift, stops, ramp);
  }

  static Color _sink(Color c, Color lift, double by) => Color.from(
    alpha: 1,
    red: clampD(c.r - lift.r * _coatFill * by, 0, 1),
    green: clampD(c.g - lift.g * _coatFill * by, 0, 1),
    blue: clampD(c.b - lift.b * _coatFill * by, 0, 1),
  );

  /// Las manchas del prado, tendidas sobre el plano del suelo.
  ///
  /// Un degradado liso de mil píxeles entre dos verdes que se llevan treinta
  /// unidades no puede salir liso: a ocho bits no hay más que treinta valores
  /// entre uno y otro, así que el aparato lo trama, y el tramado del teléfono
  /// —una matriz ordenada de cuatro por cuatro con cuatro unidades de
  /// recorrido— se lee como una persiana de rayas horizontales. Las casas y
  /// las montañas no la tienen porque son rellenos planos: no hay nada entre
  /// lo que escalonar. El prado era lo único degradado del cuadro, y por eso
  /// era lo único rayado.
  ///
  /// La salida no es afinar el tramado —está por debajo de lo que se puede
  /// tocar desde aquí— sino quitarle el sitio: un prado tiene manchas. Encima
  /// del degradado va un paño de ruido suave con bastante más recorrido que el
  /// escalón que tapa, y el ojo deja de tener ninguna raya recta que seguir.
  ///
  /// Va anclado al mundo y en perspectiva de verdad, no pegado a la pantalla:
  /// un salpicado que se queda quieto mientras el pueblo gira se ve como
  /// suciedad en el cristal, no como hierba. Y como el suelo es un plano, la
  /// cámara entera cabe en una matriz —con su división por la profundidad en
  /// la fila de perspectiva—, así que todo el paño se tiende de una sola
  /// pasada en vez de a base de sembrar manchas sueltas una por una.
  void _drawMeadowCoat(
    Canvas canvas,
    Rect rect,
    Projector p,
    Color lift,
    List<double> stops,
    List<double> ramp,
  ) {
    if (!scene.coat) return;
    final ground = _groundPatch(p);
    if (ground == null) return;
    canvas.save();
    canvas.clipRect(rect);
    // El paño se pinta aparte y se suma entero al final: hay que rebajarlo con
    // la rampa del horizonte antes de sumarlo, y rebajar y sumar en el mismo
    // trazo no se puede.
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.plus);
    // Las manchas crecen con la altura del ojo. Desde el valle, a doscientas
    // unidades de altura, unas manchas de trece unidades serían treinta
    // repeticiones del paño en pantalla: se ve la baldosa y el prado parece
    // una moqueta. Creciendo con la altura, en pantalla miden siempre lo
    // mismo, que es lo único que importa aquí —romper el escalón del
    // degradado— y de la baldosa nunca se ven más de tres o cuatro.
    final span = _coatWorld * clampD(p.eye.y / 13, 0.6, 16) / _coatSize;
    canvas.save();
    canvas.transform(_groundToScreen(p));
    canvas.drawPath(
      ground,
      Paint()
        ..colorFilter = ColorFilter.mode(lift, BlendMode.srcIn)
        ..shader = ImageShader(
          _coatTile(),
          TileMode.repeated,
          TileMode.repeated,
          Float64List.fromList([
            span, 0, 0, 0, //
            0, span, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
          ]),
          filterQuality: FilterQuality.medium,
        ),
    );
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, rect.top),
          Offset(0, rect.bottom),
          [
            for (final v in ramp)
              Color.from(alpha: v, red: 0, green: 0, blue: 0),
          ],
          stops,
        ),
    );
    canvas.restore();
    canvas.restore();
  }

  /// Cuánto aclara la mancha más clara del prado sobre la más oscura.
  ///
  /// Ni una cantidad fija ni una proporción pura del verde que ya hay. Fija,
  /// a mediodía la hierba saldría plana y de madrugada moteada como un
  /// leopardo. Pura proporción, pasa lo contrario: de noche el prado es tan
  /// oscuro que las manchas se quedarían por debajo del escalón que vienen a
  /// tapar, y de noche es justo cuando se veían las rayas. Así que un poco de
  /// cada cosa.
  static Color meadowLift(Palette pal) {
    final (_, near) = meadowTone(pal);
    double ch(double v) => clampD(v * 0.14 + 0.030, 0.03, 0.13);
    return Color.from(
      alpha: 1,
      red: ch(near.r),
      green: ch(near.g),
      blue: ch(near.b),
    );
  }

  /// El trozo de plano del suelo que está delante de la cámara.
  ///
  /// Hay que recortarlo: el plano entero incluye lo que queda detrás del ojo,
  /// y eso al dividir por la profundidad cambia de signo y se dobla sobre la
  /// pantalla. La condición «delante» es media plano en el suelo, así que el
  /// recorte es un trapecio y sale de tres cuentas.
  Path? _groundPatch(Projector p) {
    const reach = 6000.0;
    final f = p.forward;
    final ef = p.eye.dot(f);
    final g = math.sqrt(f.x * f.x + f.z * f.z);
    final path = Path();
    if (g < 1e-4) {
      // Mirando a plomo: o se ve el plano entero, o no se ve nada de él.
      if (-f.y * p.eye.y <= p.near) return null;
      path.addRect(
        Rect.fromCenter(
          center: Offset(p.eye.x, p.eye.z),
          width: reach,
          height: reach,
        ),
      );
      return path;
    }
    final gx = f.x / g, gz = f.z / g;
    // Profundidad de un punto del suelo: g * (ĝ · punto) - eye·forward.
    final s0 = (p.near + ef) / g;
    void go(double s, double t, bool first) {
      final x = gx * s - gz * t, z = gz * s + gx * t;
      first ? path.moveTo(x, z) : path.lineTo(x, z);
    }

    go(s0, -reach, true);
    go(s0, reach, false);
    go(s0 + reach, reach, false);
    go(s0 + reach, -reach, false);
    path.close();
    return path;
  }

  /// La cámara, para el plano del suelo y sólo para él, como una matriz.
  ///
  /// Vale porque todo lo que se pinta con ella tiene y = 0: entran (x, z) y
  /// sale el píxel, con la división por la profundidad hecha por la fila de
  /// perspectiva en vez de a mano.
  static Float64List _groundToScreen(Projector p) {
    final er = p.eye.dot(p.right);
    final eu = p.eye.dot(p.up);
    final ef = p.eye.dot(p.forward);
    final f = p.focal;
    return Float64List.fromList([
      // Columna de x.
      f * p.right.x + p.cx * p.forward.x,
      p.cy * p.forward.x - f * p.up.x,
      0,
      p.forward.x,
      // Columna de z, que aquí hace de y.
      f * p.right.z + p.cx * p.forward.z,
      p.cy * p.forward.z - f * p.up.z,
      0,
      p.forward.z,
      // La tercera entrada no se usa: todo esto está a ras de suelo.
      0, 0, 1, 0,
      // Columna del término independiente.
      -f * er - p.cx * ef,
      f * eu - p.cy * ef,
      0,
      -ef,
    ]);
  }

  /// El paño de manchas, tejido una vez y guardado.
  ///
  /// Ruido de valor en tres tamaños, con la rejilla más gruesa llevando la
  /// mitad del peso: manchas grandes con grano fino encima, que es a lo que se
  /// parece la hierba. Los tres tamaños dividen al paño, así que repite sin
  /// costura, y ninguno es tan grueso como para que se note dónde empieza otra
  /// vez. Sale a sesenta y cuatro píxeles y lo suaviza el filtrado al
  /// estirarlo: no hace falta más resolución para algo que no tiene ni un
  /// borde.
  static const double _coatSize = 64;
  static const double _coatWorld = 14;
  static const double _coatMean = 0.4624;

  /// Lo que el paño suma de media, contado sobre el paño ya tejido en vez de
  /// supuesto: el estirón lo recorta por los dos extremos y no lo hace por
  /// igual, así que la media de verdad no es la mitad justa. Es el número que
  /// el degradado se descuenta de antemano.
  static double _coatFill = 0.5;
  static ui.Image? _coat;

  static ui.Image _coatTile() {
    final had = _coat;
    if (had != null) return had;
    const n = 64;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint();
    var fill = 0.0;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final v =
            0.50 * _weave(x, y, 8, 0x11) +
            0.32 * _weave(x, y, 16, 0x22) +
            0.18 * _weave(x, y, 32, 0x33);
        // Tres ruidos sumados se apiñan en el medio: sin estirarlos, el paño
        // usaría un tercio del recorrido que se le da y las manchas no se
        // verían. Se estira alrededor de su propia media, que es la que hay
        // que conservar para que el verde promedio no se mueva.
        final a = clampD(0.5 + (v - _coatMean) * 1.9, 0, 1);
        fill += a;
        paint.color = Color.from(alpha: a, red: 1, green: 1, blue: 1);
        c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    _coatFill = fill / (n * n);
    return _coat = rec.endRecording().toImageSync(n, n);
  }

  /// Una capa del ruido: valores por vértice de una rejilla de `cells` por
  /// `cells` que se cierra sobre sí misma, interpolados con una curva suave
  /// para que no se vean las aristas de la rejilla.
  static double _weave(int x, int y, int cells, int salt) {
    const n = 64;
    final fx = x * cells / n, fy = y * cells / n;
    final ix = fx.floor(), iy = fy.floor();
    final tx = _ease(fx - ix), ty = _ease(fy - iy);
    double at(int a, int b) =>
        hash01((a % cells + cells) % cells, (b % cells + cells) % cells, salt);
    final top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx;
    final bot = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx;
    return top + (bot - top) * ty;
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  /// Three ranges of hills standing all the way round the horizon.
  ///
  /// They are drawn as a ring centred on wherever the camera is looking, but
  /// their shape is sampled from world position, so walking along the wall
  /// reveals new country instead of dragging the same skyline along.
  /// The three mountain ranges on the skyline.
  ///
  /// Three things had to be true at once, and the old version got none of them
  /// right once the camera left its usual place:
  ///
  ///  * The ring has to be centred on the *camera*, not on the point it is
  ///    looking at. Zoomed all the way out the eye sits a hundred units from
  ///    that point, which put it almost on top of the nearest range — half the
  ///    country ended up behind the viewer, and the half in front reared up
  ///    across the whole screen.
  ///  * The shape has to be sampled somewhere that does not move when you
  ///    merely orbit, or the skyline swims as you turn. So the geometry follows
  ///    the eye and the height follows the stretch of wall being looked at:
  ///    walking the wall still reveals new country, turning on the spot does
  ///    not.
  ///  * Every strip has to be a closed shape. Whenever a point fell behind the
  ///    near plane the old loop handed Skia an open path, which closes itself
  ///    with a straight line back to the start — that is where the huge wedges
  ///    across the view came from. Now only the arc actually in front of the
  ///    camera is walked at all, and each strip is closed by construction.
  /// The two colours the meadow is painted between: at the horizon, and at
  /// your feet.
  static (Color far, Color near) meadowTone(Palette pal) {
    final day = pal.daylight;
    final nearGreen = Color.lerp(
      const Color(0xFF1B4A4E),
      const Color(0xFF6B8F3E),
      day,
    )!;
    final farGreen = Color.lerp(
      const Color(0xFF265158),
      const Color(0xFF7E9A4C),
      day,
    )!;
    return (
      Color.lerp(pal.groundFar, farGreen, 0.30 + 0.10 * day)!,
      Color.lerp(pal.ground, nearGreen, 0.34 + 0.13 * day)!,
    );
  }

  /// What one range is painted with: the colour of its body, and the colour
  /// its foot fades to where it meets the horizon.
  ///
  /// Near ranges are the pale ones and far ranges are dark. That is what makes
  /// three of them read as three: the eye takes the darkest band as the one
  /// furthest back, and stacks the rest in front of it. It used to be the
  /// other way round — the far range got the most haze and came out lightest,
  /// which put the back of the world in front of everything else.
  static (Color body, Color foot) rangeTone(Palette pal, int li, int of) {
    // One for the range at your feet, zero for the one at the edge of the
    // world. Every choice below hangs off this and nothing else, so «which way
    // round are they?» is one line rather than three index sums.
    final near01 = of <= 1 ? 1.0 : (of - 1 - li) / (of - 1);
    // What a hill is made of at this hour, before distance touches it.
    final hill = Color.lerp(pal.groundFar, pal.haze, 0.38)!;
    // And then distance simply darkens it — toward black, not toward another
    // colour out of the palette. Which of two palette colours is the lighter
    // one changes with the hour: at night the far ground is lighter than the
    // near ground and the haze sits between them, so a rule written as a blend
    // of those came out in a different order at four in the morning than at
    // noon. Toward black it holds at every hour by construction.
    final body = Color.lerp(
      hill,
      const Color(0xFF000000),
      0.54 * (1 - near01),
    )!;
    return (body, Color.lerp(body, pal.haze, 0.30 + 0.15 * near01)!);
  }

  void _drawRanges(Canvas canvas, Projector p, Size size, double horizonY) {
    final pal = scene.palette;
    final light = pal.lightDir;

    // Below the horizon is the ground plane, and a range hundreds of units away
    // is behind it. Clipping there is what stops the mountains from floating in
    // the middle of the field when the camera looks down at the wall, and what
    // makes their feet meet the ground instead of hanging over it.
    final cut = clampD(horizonY, -1.0, size.height + 1.0);
    if (cut <= 0) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, -size.height, size.width, cut + size.height + 1),
    );

    // Only the arc in front of the camera: everything else is behind the eye,
    // where projection is meaningless. Sampled just wide enough for the lens.
    final az = math.atan2(p.forward.x, p.forward.z);
    final span = math.atan(size.width * 0.5 / p.focal) + 0.30;
    const steps = 210;
    final floor = size.height + 40;
    final look = scene.camera.travel;

    // Where the sun is across the screen, for the light that grazes the tops.
    // A number, not a side: the old code asked «is this slope facing the
    // light?» and got a yes or a no, which put a hard vertical edge down the
    // middle of every range at the two points where the answer flipped.
    final sunTh = _wrap(math.atan2(light.x, light.z) - az);
    final sunX = size.width / 2 + p.focal * math.tan(clampD(sunTh, -1.3, 1.3));

    for (var li = Landscape.ridges.length - 1; li >= 0; li--) {
      final layer = Landscape.ridges[li];
      final (body, foot) = rangeTone(pal, li, Landscape.ridges.length);

      // Every sample first, then the paint, then the shapes. In one pass the
      // gradient of a strip could only start at that strip's own highest
      // point, so two strips of the same range began their fade at different
      // heights and met along a visible step. One range, one paint.
      // Proyectadas como direcciones y no como puntos: una cordillera está
      // infinitamente lejos, y lo que eso quiere decir es que gira con la
      // cámara y no se mueve con ella.
      //
      // Antes se muestreaba en `ojo + dirección × radio` con la altura en
      // coordenadas del mundo: la posición horizontal seguía a la cámara pero
      // la vertical no, así que al subir el ojo —que es lo que hace alejarse—
      // las montañas se hundían proporcionalmente a la altura partido el
      // radio. Con el radio de la primera en ciento cincuenta y el ojo subiendo
      // decenas de unidades, eso es media cordillera de salto: se movían como
      // si estuvieran a diez metros, y en el peor caso su pie se metía por
      // debajo del horizonte y el prado se las comía.
      //
      // Así, en cambio, la elevación cero cae exactamente en el horizonte por
      // construcción, que es el sitio donde el suelo empieza. No hay forma de
      // que el pasto tape una montaña.
      final xs = <double>[], ys = <double>[];
      var crest = size.height;
      for (var i = 0; i <= steps; i++) {
        final th = az - span + (i / steps) * (span * 2);
        final dx = math.sin(th), dz = math.cos(th);
        final h = Landscape.ridgeHeight(
          layer,
          look + dx * layer.radius,
          dz * layer.radius,
        );
        // El perfil sigue cambiando con el viaje, así que caminar por el valle
        // descubre otra sierra: eso es paralaje de verdad, y es la única que
        // una cosa tan lejos tiene derecho a tener.
        final at = skyPoint(
          p,
          th,
          math.atan2(math.max(h, layer.base), layer.radius),
          minDen: 0.02,
        );
        if (at == null) {
          xs.add(double.nan);
          ys.add(double.nan);
          continue;
        }
        xs.add(at.dx);
        ys.add(at.dy);
        if (at.dy < crest) crest = at.dy;
      }

      // Each range fades into the haze where it meets the horizon, the way
      // distance actually works. Into the haze and not into the ground: fading
      // to the ground's own colour made the two indistinguishable exactly where
      // they meet, and the skyline dissolved instead of standing against the
      // field.
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, math.min(crest, cut - 1)),
          Offset(0, cut),
          [body, foot],
        );

      final shapes = <Path>[];
      Path? path;
      var startX = 0.0, lastX = 0.0;
      for (var i = 0; i <= steps; i++) {
        if (ys[i].isNaN) {
          if (path != null) {
            shapes.add(
              path
                ..lineTo(lastX, floor)
                ..lineTo(startX, floor)
                ..close(),
            );
            path = null;
          }
          continue;
        }
        if (path == null) {
          path = Path()..moveTo(xs[i], floor);
          path.lineTo(xs[i], ys[i]);
          startX = xs[i];
        } else {
          path.lineTo(xs[i], ys[i]);
        }
        lastX = xs[i];
      }
      if (path != null) {
        shapes.add(
          path
            ..lineTo(lastX, floor)
            ..lineTo(startX, floor)
            ..close(),
        );
      }

      for (final shape in shapes) {
        canvas.drawPath(shape, paint);
      }

      // And the sun on the tops, as a wash that comes and goes across the
      // screen rather than a side that is either lit or not. Near ranges take
      // more of it: the far ones are too much air away to catch anything.
      final near01 =
          (Landscape.ridges.length - 1 - li) /
          math.max(1, Landscape.ridges.length - 1);
      // Por cuánto de día es, y no siempre. El barrido usaba el color del sol
      // a plena fuerza a cualquier hora: a las tres de la mañana pintaba una
      // mancha clara en la ladera, del lado donde estaría el sol si lo
      // hubiera. De noche no le da el sol a nada.
      final strength = (0.20 + 0.16 * near01) * pal.daylight;
      if (strength > 0.02 && sunX > -size.width && sunX < size.width * 2) {
        final reach = size.width * 0.85;
        final glow = Paint()
          ..shader = ui.Gradient.linear(
            Offset(sunX - reach, 0),
            Offset(sunX + reach, 0),
            [
              pal.sun.withValues(alpha: 0),
              pal.sun.withValues(alpha: strength),
              pal.sun.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          );
        for (final shape in shapes) {
          canvas.drawPath(shape, glow);
        }
      }
    }

    canvas.restore();
  }

  /// An angle brought back into -pi..pi, so «how far round is the sun from
  /// where we are looking» never comes out as most of a circle.
  static double _wrap(double a) {
    var x = a;
    while (x > math.pi) {
      x -= 2 * math.pi;
    }
    while (x < -math.pi) {
      x += 2 * math.pi;
    }
    return x;
  }

  // ------------------------------------------------------------- far wall

  void _quad(Projector p, V3 a, V3 b, V3 c, V3 d, int color) {
    final pts = [a, b, c, d];
    for (var i = 0; i < 4; i++) {
      final cp = p.cameraOf(pts[i]);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    _emit(p, _clipA, 4, color);
  }

  /// Clips a camera-space polygon, projects it and queues it.
  ///
  /// Queues, not sorts. Faces are painted in the order they arrive here, and
  /// the order they arrive in is already the right one: that is what the tree
  /// walk and the box ordering are for. A depth number per face was the old
  /// way, and a single number cannot say which of two faces that overlap in
  /// depth is in front — there is no such number, which is why every bug this
  /// renderer ever had came back at a different angle.
  void _emit(Projector p, Float64List cam, int count, int color) {
    final m = clipNear(cam, count, _clipB, p.near);
    if (m < 3) return;
    final f = _nextFace();
    if (f == null) return;
    for (var i = 0; i < m; i++) {
      final z = _clipB[i * 3 + 2];
      f.pts[i * 2] = p.screenX(_clipB[i * 3], z);
      f.pts[i * 2 + 1] = p.screenY(_clipB[i * 3 + 1], z);
    }
    f.n = m;
    f.color = color;
  }

  // --------------------------------------------------------------- stones

  /// Dónde en qué índice de `picks` está cada pieza de este fotograma.
  final Map<int, int> _pickAt = {};

  void _registerPick(_Face f, int brickIndex, Size size, double near) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < f.n; i++) {
      final x = f.pts[i * 2], y = f.pts[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (maxX < 0 || minX > size.width || maxY < 0 || minY > size.height) return;
    final had = _pickAt[brickIndex];
    if (had != null) {
      picks[had].grow(minX, minY, maxX, maxY, near);
      return;
    }
    _pickAt[brickIndex] = picks.length;
    picks.add(
      PickTarget(
        brickIndex,
        minX,
        minY,
        maxX,
        maxY,
        near,
        scene.labelledBricks.contains(brickIndex),
      ),
    );
  }

  // ------------------------------------------------------------------ town

  /// Haze by real distance rather than by distance along one axis.
  ///
  /// The wall runs east to west, so fading it by how far it is along x is
  /// close enough. A town spreads in both directions, and fading it by x alone
  /// leaves the north end of a street crisp and the west end of it lost.
  Color _hazeAt(Color c, Projector p, double x, double z, Palette pal) {
    final dx = x - p.eye.x, dz = z - p.eye.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    // The town is meant to be looked at, not squinted through: it keeps most
    // of its colour all the way to the far side of the valley.
    // Capped: from across the valley a town must still be a town and not a
    // smudge the colour of the grass. Distance says "further away", never
    // "gone".
    final t = 1 - math.exp(-dist * 0.0040);
    if (t < 0.004) return c;
    return Color.lerp(c, pal.haze, math.min(t * 0.5, 0.30))!;
  }

  /// The lanes between the blocks, and the shadow each building sits in.
  void _drawTownGround(Canvas canvas, Projector p, TownLayout town) {
    final pal = scene.palette;
    // A yard of packed earth around each house: the ground people walk on,
    // worn bare by the door and ragged at the edges where the grass wins.
    // A tidy square of grey reads as a concrete slab, which is the one thing a
    // medieval town must never look like.
    final pad = Color.lerp(
      Color.lerp(pal.ground, const Color(0xFFB0946C), 0.72)!,
      pal.skyLight,
      0.10,
    )!;
    final half = town.plotPitch * 0.46;
    for (final b in town.buildings) {
      if (b.placedPieces <= 0) continue;
      final s = b.seed;
      // Eight points round the edge, each pulled in or out a little, so no two
      // yards are the same shape and none of them has a drawn corner.
      final path = Path();
      var started = false;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final r = half * hashRange(0.78, 1.12, s, 40, i);
        final at = p.project(
          V3(
            b.cx + math.cos(a) * r * 1.32,
            0.004,
            b.cz + math.sin(a) * r * 1.32,
          ),
        );
        if (at == null) {
          started = false;
          break;
        }
        if (!started) {
          path.moveTo(at.x, at.y);
          started = true;
        } else {
          path.lineTo(at.x, at.y);
        }
      }
      if (!started) continue;
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = _hazeAt(pad, p, b.cx, b.cz, pal)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // A soft pool of shade under each building. The wall gets a real projected
    // shadow; a hundred and fifty houses would cost far too much for that, and
    // at this size a contact shadow is what stops them floating anyway.
    final light = pal.lightDir;
    final drop = clampD(1.0 / math.max(0.25, light.y), 0.8, 2.4);
    for (final b in town.buildings) {
      if (b.placedPieces <= 0 || b.peakY <= 0.05) continue;
      final h = b.peakY;
      final at = p.project(
        V3(
          b.cx - light.x * drop * h * 0.35,
          0.006,
          b.cz - light.z * drop * h * 0.35,
        ),
      );
      if (at == null) continue;
      final r = p.focal / at.depth * (1.3 + h * 0.18);
      if (r < 2) continue;
      canvas.drawCircle(
        Offset(at.x, at.y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
            pal.ink.withValues(alpha: 0.20 * scene.integrity.clamp(0.5, 1.0)),
            pal.ink.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// A ghost of the piece that is about to be laid.
  ///
  /// The town always shows you the next thing it is waiting for: an outline
  /// standing where the piece will go, breathing on its own and firming up as
  /// the button is held. It is the difference between pressing a button and
  /// finishing something you can already see.
  void _drawTownGhost(Canvas canvas, Projector p, Size size, TownLayout town) {
    if (scene.fx != null) return; // one is already in flight
    final piece = town.pieceFor(scene.placed);
    if (piece == null) return;
    final pal = scene.palette;
    final charge = scene.charge;

    // A slow breath when idle, and a firm hold while the button is down.
    final breath = 0.5 + 0.5 * math.sin(scene.time * 2.1);
    final alpha = 0.16 + breath * 0.10 + charge * 0.55;

    final y0 = piece.y0, y1 = piece.y1;
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    if (p.cameraOf(V3(piece.cx, (y0 + y1) / 2, piece.cz)).z <= p.near) return;

    Offset? at(double x, double y, double z) {
      final q = p.project(V3(x, y, z));
      return q == null ? null : Offset(q.x, q.y);
    }

    final lo = [at(x0, y0, z0), at(x1, y0, z0), at(x1, y0, z1), at(x0, y0, z1)];
    final hi = [at(x0, y1, z0), at(x1, y1, z0), at(x1, y1, z1), at(x0, y1, z1)];
    if (lo.contains(null) || hi.contains(null)) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 + charge * 1.6
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        pal.accent,
        Colors.white,
        0.35 + charge * 0.4,
      )!.withValues(alpha: alpha);

    // Only the uprights and the top: a full cage reads as a bug report.
    final path = Path();
    for (var i = 0; i < 4; i++) {
      path
        ..moveTo(hi[i]!.dx, hi[i]!.dy)
        ..lineTo(hi[(i + 1) % 4]!.dx, hi[(i + 1) % 4]!.dy);
      // The corner posts, drawn as short ticks up from the ground.
      final a = lo[i]!, b = hi[i]!;
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(a.dx + (b.dx - a.dx) * 0.28, a.dy + (b.dy - a.dy) * 0.28)
        ..moveTo(b.dx - (b.dx - a.dx) * 0.28, b.dy - (b.dy - a.dy) * 0.28)
        ..lineTo(b.dx, b.dy);
    }
    canvas.drawPath(path, line);

    // A patch of light on the ground where it will land, so the eye knows
    // where to look even when the piece itself is a chimney on a far roof.
    final foot = at(piece.cx, math.max(0.02, y0), piece.cz);
    if (foot != null) {
      final q = p.cameraOf(V3(piece.cx, y0, piece.cz));
      final r =
          p.focal / q.z * math.max(piece.w, piece.d) * (0.7 + charge * 0.3);
      if (r > 2) {
        canvas.drawCircle(
          foot,
          r,
          Paint()
            ..shader = ui.Gradient.radial(foot, r, [
              Color.lerp(
                pal.accent,
                Colors.white,
                0.5,
              )!.withValues(alpha: 0.10 + charge * 0.30),
              const Color(0x00000000),
            ]),
        );
      }
    }
  }

  /// The ring that runs out across the ground when something lands or is
  /// finished. Two lines and it is the thing the eye actually follows.
  void _drawRings(
    Canvas canvas,
    Projector p,
    TownLayout town, {
    required bool overlay,
  }) {
    final pal = scene.palette;

    void ring(
      double cx,
      double cz,
      double r,
      double alpha,
      Color c,
      double width,
    ) {
      if (alpha <= 0.01 || r <= 0.02) return;
      const steps = 28;
      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final a = i * 2 * math.pi / steps;
        final at = p.project(
          V3(cx + math.cos(a) * r, 0.02, cz + math.sin(a) * r),
        );
        if (at == null) return;
        if (i == 0) {
          path.moveTo(at.x, at.y);
        } else {
          path.lineTo(at.x, at.y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = c.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }

    final fx = scene.fx;

    // The shadow of the piece still in the air, closing under it as it comes
    // down. This is the whole of the anticipation: you can see exactly where it
    // is going and exactly how long it has left.
    if (!overlay && fx != null && !fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final up = fx.yOffset;
        final t = clampD(1 - up / 2.3, 0, 1);
        final at = p.project(V3(piece.cx, math.max(piece.y0, 0.02), piece.cz));
        if (at != null) {
          final base = math.max(piece.w, piece.d) * 0.55;
          final r = p.focal / at.depth * base * (1.7 - t * 0.85);
          if (r > 1.5) {
            canvas.drawCircle(
              Offset(at.x, at.y),
              r,
              Paint()
                ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
                  pal.ink.withValues(alpha: 0.10 + t * 0.30),
                  pal.ink.withValues(alpha: 0),
                ]),
            );
          }
        }
      }
    }

    // The dust ring under a piece that has just landed. Drawn before the
    // masonry, because dust goes behind a wall; the gold below is light, and
    // light goes in front.
    if (!overlay && fx != null && fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final t = clampD(fx.sinceImpact / 0.55, 0, 1);
        ring(
          piece.cx,
          piece.cz,
          0.25 + t * 2.1,
          (1 - t) * (1 - t) * 0.55,
          Color.lerp(pal.stoneWarm, Colors.white, 0.4)!,
          2.4,
        );
      }
    }

    if (!overlay) return;

    // Two rings out from a building that has just been finished.
    final justDone = scene.finished;
    if (justDone != null && justDone < town.buildings.length) {
      final b = town.buildings[justDone];
      for (var i = 0; i < 2; i++) {
        final t = clampD((scene.finishedAge - i * 0.22) / 1.5, 0, 1);
        if (t <= 0) continue;
        final ease = 1 - math.pow(1 - t, 3).toDouble();
        ring(
          b.cx,
          b.cz,
          0.4 + ease * (b.isLandmark ? 7.5 : 4.4),
          (1 - t) * (1 - t) * (b.isLandmark ? 0.85 : 0.6),
          const Color(0xFFF2C25B),
          b.isLandmark ? 3.0 : 2.2,
        );
      }
    }
  }

  /// The light the lit windows throw, laid over the town once its walls are
  /// down. Half of what a town at night is, is the glow around the windows
  /// rather than the windows themselves.
  void _drawLamps(Canvas canvas, Size size) {
    if (_lamps.isEmpty) return;
    const warm = Color(0xFFFFC978);
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < _lamps.length; i += 4) {
      final x = _lamps[i], y = _lamps[i + 1];
      final r = _lamps[i + 2] * 3.0, k = _lamps[i + 3];
      if (x < -r || x > size.width + r || y < -r || y > size.height + r) {
        continue;
      }
      paint.shader = ui.Gradient.radial(
        Offset(x, y),
        r,
        [
          warm.withValues(alpha: 0.16 * k),
          warm.withValues(alpha: 0.055 * k),
          const Color(0x00000000),
        ],
        [0.0, 0.38, 1.0],
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// The sign over each town: its symbol, its name and how much of it is
  /// standing.
  ///
  /// This is the whole reason several towns share a valley. From far enough
  /// back you cannot read a house, but you can read four signs and see under
  /// each one how big and how lit its town is — which is the answer to "me
  /// está yendo bien con esto y mal con lo otro", said in one look.
  ///
  /// (See [_drawTownSigns] below; this doc belongs to it.)

  /// Where each town's notice board landed, so a finger can find it.
  ///
  /// Worked out from the plank's own four corners rather than from a marker
  /// hung over the town: the thing you tap is the thing you can see, and from
  /// behind it or from far enough away that it is a smudge, there is nothing
  /// to tap at all.
  void _findBoards(Projector p, Size size) {
    for (var i = 0; i < scene.towns.length; i++) {
      final e = scene.towns[i];
      if (e.placed <= 0) continue;
      final l = e.layout;
      // The plank faces one way. From behind it, it is a plank.
      if (p.eye.z <= l.cz + 0.3) continue;
      var x0 = double.infinity, y0 = double.infinity;
      var x1 = -double.infinity, y1 = -double.infinity;
      var whole = true;
      for (final v in NoticeBoard.faceAt(l.cx, l.cz)) {
        final at = p.project(v);
        if (at == null) {
          whole = false;
          break;
        }
        if (at.x < x0) x0 = at.x;
        if (at.x > x1) x1 = at.x;
        if (at.y < y0) y0 = at.y;
        if (at.y > y1) y1 = at.y;
      }
      if (!whole) continue;
      // Smaller than a fingertip is not something anybody was aiming at.
      if (x1 - x0 < 12 && y1 - y0 < 12) continue;
      if (x1 < 0 || x0 > size.width || y1 < 0 || y0 > size.height) continue;
      boards.add(BoardHit(i, Rect.fromLTRB(x0, y0, x1, y1).inflate(9)));
    }
  }

  /// Dónde está cada cúpula, para poder tocarla.
  ///
  /// Se mide del propio edificio y no de un punto colgado encima: lo que se
  /// toca es lo que se ve, y desde lejos, cuando la cúpula es una mancha de
  /// cuatro píxeles, no hay nada que tocar — que es lo correcto.
  void _findDomes(Projector p, Size size) {
    for (var i = 0; i < scene.towns.length; i++) {
      final b = scene.towns[i].layout.standing('observatorio');
      if (b == null) continue;
      var x0 = double.infinity, y0 = double.infinity;
      var x1 = -double.infinity, y1 = -double.infinity;
      var whole = true;
      // Las cuatro esquinas de la cúpula y su cima: con el centro solo, una
      // cúpula cerca ocuparía media pantalla y su blanco sería un punto.
      const r = 1.5;
      for (final v in [
        V3(b.cx - r, b.peakY - 1.6, b.cz - r),
        V3(b.cx + r, b.peakY - 1.6, b.cz - r),
        V3(b.cx - r, b.peakY - 1.6, b.cz + r),
        V3(b.cx + r, b.peakY - 1.6, b.cz + r),
        V3(b.cx, b.peakY, b.cz),
      ]) {
        final at = p.project(v);
        if (at == null) {
          whole = false;
          break;
        }
        if (at.x < x0) x0 = at.x;
        if (at.x > x1) x1 = at.x;
        if (at.y < y0) y0 = at.y;
        if (at.y > y1) y1 = at.y;
      }
      if (!whole) continue;
      if (x1 - x0 < 14 && y1 - y0 < 14) continue;
      if (x1 < 0 || x0 > size.width || y1 < 0 || y0 > size.height) continue;
      domes.add(DomeHit(i, Rect.fromLTRB(x0, y0, x1, y1).inflate(8)));
    }
  }

  void _drawTownSigns(Canvas canvas, Projector p, Size size) {
    if (scene.towns.length < 2) return;
    final pal = scene.palette;
    final dark = _isDarkSky();

    // Nearest first, so a sign never covers one in front of it.
    final rows = <(double, int)>[];
    for (var i = 0; i < scene.towns.length; i++) {
      final l = scene.towns[i].layout;
      final dx = l.cx - p.eye.x, dz = l.cz - p.eye.z;
      rows.add((dx * dx + dz * dz, i));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    final taken = <Rect>[];
    for (final (_, i) in rows) {
      final e = scene.towns[i];
      final l = e.layout;
      // Over the top of the town, not over the middle of it.
      //
      // It used to hang at a height guessed from how wide the town is, which
      // for a small one is barely off the ground — so a plate wider than the
      // hamlet under it covered the hamlet completely. Now it clears whatever
      // the tallest thing standing is, and then lifts a fixed distance further
      // up the screen, which holds at any angle and any distance: the valley
      // view is for looking at the towns, so nothing in it may sit on one.
      final top = math.max(l.tallest, 2.0) + 0.8;
      final at = p.project(V3(l.cx, top, l.cz));
      if (at == null) continue;
      final y = at.y - 30;
      if (at.x < -140 || at.x > size.width + 140) continue;
      if (y < -60 || y > size.height + 60) continue;

      // Signs matter most from far away; up close the town speaks for itself.
      final d = at.depth;
      final near = clampD((d - 26) / 30, 0, 1);
      if (near <= 0.02) continue;
      final on = i == scene.active;

      final ink = on ? pal.accent : (dark ? Colors.white : pal.ink);
      final fade = (on ? 0.95 : 0.62) * near;
      // No plate and no frame any more: a soft halo, the same one every other
      // piece of type in this app sits on when it stands straight on the
      // scene. A card behind a name is a card in front of a town.
      final shadow = Shadow(
        color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
          alpha: (dark ? 0.62 : 0.34) * near,
        ),
        blurRadius: 10,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: e.name.toUpperCase(),
          style: TextStyle(
            color: ink.withValues(alpha: fade),
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            shadows: [shadow],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // The habit's own drawn mark, painted rather than typed: it is the same
      // hand that drew the landmarks, and it looks the same on every phone.
      const glyph = 15.0;
      const crown = 12.0;
      final wears = e.crowned;
      final content = glyph + 8 + tp.width + (wears ? crown + 5 : 0);
      // Donde cae, y no donde quepa. Estaba recortado contra los dos bordes de
      // la pantalla, así que un pueblo que se iba de cuadro dejaba su nombre
      // pegado al canto: girar la cámara se sentía como que el cartel te
      // seguía. Un cartel está clavado en su pueblo; si el pueblo se sale, el
      // cartel se sale con él y se corta como se cortaría un cartel de verdad.
      final cx = at.x;
      final box = Rect.fromLTWH(cx - content / 2 - 8, y - 10, content + 16, 32);
      if (taken.any(box.overlaps)) continue;
      taken.add(box);
      // Generous: a sign is small and a thumb is not.
      signs.add(SignHit(i, box.inflate(10)));

      final left = cx - content / 2;
      HabitSigils.draw(
        canvas,
        Rect.fromLTWH(left, y - 4 + (tp.height - glyph) / 2, glyph, glyph),
        e.symbol,
        ink.withValues(alpha: fade),
      );
      final after = left + glyph + 8;
      tp.paint(canvas, Offset(after, y - 4));
      // The valley's crown, on whichever town has laid the most.
      if (wears) {
        HabitSigils.crown(
          canvas,
          Rect.fromLTWH(
            after + tp.width + 5,
            y - 4 + (tp.height - crown) / 2 + 1,
            crown,
            crown * 0.82,
          ),
          const Color(0xFFF2C25B).withValues(alpha: fade),
        );
      }

      // Y nada debajo del nombre. Había una regla que se llenaba según lo que
      // el pueblo llevara puesto, y es la clase de cosa que parece informativa
      // y miente: una barra de progreso dibuja un final, y un hábito no tiene
      // final. Lo que hay es cuánto pueblo hay, que se ve mirando el pueblo.
    }
  }

  /// A few birds turning over the town.
  ///
  /// They cost almost nothing and they do something no amount of masonry can:
  /// they make the sky part of the place. A town with birds over it is somewhere
  /// you are looking at; a town without them is a model on a table.
  void _drawBirds(Canvas canvas, Projector p, Size size, TownLayout town) {
    final pal = scene.palette;
    if (!pal.isDaylight) return;
    final t = scene.time;
    final ink = pal.ink.withValues(alpha: 0.42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // Two loose flocks on wide circles at different heights and speeds.
    for (var flock = 0; flock < 2; flock++) {
      final n = flock == 0 ? 5 : 3;
      final radius = town.radius * (flock == 0 ? 0.55 : 0.85) + 4;
      final height = 7.0 + flock * 4.5;
      final speed = (flock == 0 ? 0.085 : -0.062);
      final drift = hash01(flock, 7) * 6.28;
      for (var i = 0; i < n; i++) {
        final a = t * speed + drift + i * 0.34 + hash01(flock, i, 3) * 0.5;
        final wobble = math.sin(t * 0.7 + i * 1.3) * 0.9;
        final x = math.cos(a) * (radius + wobble);
        final z = math.sin(a) * (radius + wobble) * 0.8;
        final y = height + math.sin(t * 0.55 + i * 0.9) * 0.7;
        final at = p.project(V3(x, y, z));
        if (at == null) continue;
        if (at.x < -40 || at.x > size.width + 40) continue;
        if (at.y < -40 || at.y > size.height + 40) continue;
        final s = clampD(p.focal / at.depth * 0.16, 1.4, 9.0);
        // The beat of the wings, which is the whole animation.
        final beat = math.sin(t * 7.5 + i * 2.1);
        final lift = s * 0.55 * beat;
        paint
          ..strokeWidth = math.max(0.9, s * 0.20)
          ..color = ink.withValues(alpha: clampD(s / 6, 0.12, 0.42));
        final path = Path()
          ..moveTo(at.x - s, at.y - lift * 0.4)
          ..quadraticBezierTo(at.x - s * 0.4, at.y - lift, at.x, at.y)
          ..quadraticBezierTo(
            at.x + s * 0.4,
            at.y - lift,
            at.x + s,
            at.y - lift * 0.4,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  /// The whole valley's masonry, in the one order that is right.
  ///
  /// Nothing here sorts faces. Each building is a tree that was cut and filed
  /// when its pieces were laid, and walking that tree from wherever the camera
  /// happens to stand gives its own faces in exactly the right order — no
  /// heuristics, no bias, nothing forced in front of anything. The buildings
  /// are then filed behind planes with nothing straddling them, so which side
  /// of each plane is nearer is decided by where the camera stands and by
  /// nothing else. The renderer never guesses which of two things is in front,
  /// because it is never in a position where it has to.
  void _collectTown(Projector p, Size size) {
    final pal = scene.palette;
    final light = pal.lightDir;
    final fx = scene.fx;
    final night = !pal.isDaylight;

    // How high the finishing wave has climbed, and how bright it still is.
    _sweep = -1.0;
    _sweepFade = 0.0;
    final justDone = scene.finished;
    final active = scene.town;
    if (justDone != null && justDone < active.buildings.length) {
      final b = active.buildings[justDone];
      const rise = 0.85; // seconds from footings to ridge
      final t = scene.finishedAge / rise;
      if (t < 1.7) {
        _sweep = (b.peakY + 0.6) * t;
        _sweepFade = t <= 1 ? 1.0 : clampD(1 - (t - 1) / 0.7, 0, 1);
      }
    }

    // The piece in the air. It is the one thing in the town that moves, so it
    // is the one thing built fresh every frame.
    //
    // It used to be painted last, over the whole valley, on the grounds that
    // it is above the building it is coming down into. It is — but it is not
    // above the houses standing between it and the eye, and painting it last
    // put a chimney straight through the roof in front of it every time one
    // was laid. So it goes in at the place its own building goes in: the
    // clusters are already in a correct far-to-near order, so anything nearer
    // than its building is painted after it and covers it, which is what
    // being behind something means.
    _falling = null;
    _fallingPiece = -1;
    _fallingPainted = false;
    if (fx != null &&
        fx.brickIndex >= 0 &&
        fx.brickIndex < active.pieces.length &&
        fx.brickIndex < scene.towns[scene.active].placed) {
      final q = active.pieces[fx.brickIndex];
      final flying = <Facet>[];
      for (final solid in solidsOf(
        q,
        place: active.character,
        lift: fx.yOffset,
        squash: fx.squash.$2,
      )) {
        for (final f in solid.faces) {
          f.piece = solid.piece;
          flying.add(f);
        }
      }
      if (flying.isNotEmpty) {
        _falling = BspTree.build(flying);
        _fallingPiece = fx.brickIndex;
      }
    }

    // What the frame can afford. It is spent nearest first and on whole
    // buildings, so what it cannot pay for is a house on the far side of the
    // valley and never half of the one standing in front of you.
    final cost = <(double, int)>[];
    for (final e in scene.towns) {
      final take = math.min(e.placed, e.layout.pieces.length);
      if (take <= 0) continue;
      for (final c in builtTown(e.layout, take).clusters) {
        cost.add((_away(p, c.bounds), c.faces));
      }
    }
    cost.sort((a, b) => a.$1.compareTo(b.$1));
    var spend = 0;
    var cut = double.infinity;
    for (final c in cost) {
      spend += c.$2;
      if (spend > scene.budget) {
        cut = c.$1;
        break;
      }
    }

    // The towns themselves, farthest first. Each has its own plot with the
    // valley between them, so no two of them interleave and how far away they
    // are is the whole of their order.
    final towns = List<int>.generate(scene.towns.length, (i) => i);
    Aabb? boundsOf(TownEntry e) =>
        builtTown(e.layout, math.min(e.placed, e.layout.pieces.length)).bounds;
    towns.sort(
      (a, b) => _away(
        p,
        boundsOf(scene.towns[b]),
      ).compareTo(_away(p, boundsOf(scene.towns[a]))),
    );

    for (final w in towns) {
      final e = scene.towns[w];
      final take = math.min(e.placed, e.layout.pieces.length);
      if (take <= 0) continue;
      final root = builtTown(e.layout, take).root;
      if (root == null) continue;
      final decay = 1.0 - e.integrity;
      // Every town limewashes its houses its own way, so the colours are
      // worked out per town and not once for the valley.
      _tone.clear();
      _picking = w == scene.active;
      walkOrder(root, p.eye, (leaf) {
        final box = leaf.bounds;
        if (p.cameraOf(V3(box.cx, box.cy, box.cz)).z + box.radius < p.near) {
          return;
        }
        final c = leaf.cluster;
        if (c == null) {
          _emitWeather(p, e, e.layout.pieces[leaf.weather], pal, night, decay);
          return;
        }
        if (_away(p, box) > cut) return;
        final mine = w == scene.active && c.members.contains(_fallingPiece);
        c.tree.paint(p.eye, (f) {
          // `f.piece >= 0` matters: the town's own furniture is filed under
          // no achievement at all, and "no achievement" must not collide with
          // "the achievement that is in the air right now".
          if (w == scene.active && f.piece >= 0 && f.piece == _fallingPiece) {
            return;
          }
          _paint(p, e, f, pal, light, night, decay, size);
        });
        // Straight after the building it belongs to, and before any building
        // nearer than that one.
        if (mine) _paintFalling(p, e, pal, light, night, size);
      });
    }

    // If its own building never came up — filed away by the budget, or off
    // the side of the screen — the piece still has to be seen: it is the one
    // thing the person is looking at right now.
    if (_falling != null && !_fallingPainted) {
      final e = scene.towns[scene.active];
      _tone.clear();
      _picking = true;
      _paintFalling(p, e, pal, light, night, size);
    }
  }

  void _paintFalling(
    Projector p,
    TownEntry e,
    Palette pal,
    V3 light,
    bool night,
    Size size,
  ) {
    final falling = _falling;
    if (falling == null || _fallingPainted) return;
    _fallingPainted = true;
    falling.paint(
      p.eye,
      (f) => _paint(p, e, f, pal, light, night, 1.0 - e.integrity, size),
    );
  }

  /// How far a box is from the eye, squared, which is all a sort needs.
  static double _away(Projector p, Aabb? b) {
    if (b == null) return double.infinity;
    final dx = b.cx - p.eye.x, dy = b.cy - p.eye.y, dz = b.cz - p.eye.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// The wind-blown half of a piece: what a tree filed once cannot hold.
  void _emitWeather(
    Projector p,
    TownEntry e,
    TownPiece piece,
    Palette pal,
    bool night,
    double decay,
  ) {
    switch (piece.kind) {
      case PieceKind.field:
        _emitField(p, piece, piece.y0, pal, decay);
      case PieceKind.water:
        _emitWater(p, piece, piece.y0, pal, night);
      case PieceKind.sail:
        _emitSails(p, piece, piece.y0, piece.y1, pal.lightDir, pal);
      case PieceKind.banner:
        _emitBanner(p, piece, piece.y0, piece.y1, pal);
      default:
        break;
    }
  }

  /// Paints one face of something built.
  ///
  /// The only visibility decision left in the renderer, and it is the one that
  /// is always right: a face of a closed solid is seen exactly when the eye is
  /// on its outward side. There is no inside of a house here, so every face
  /// has a twin looking the other way and exactly one of the two is turned
  /// towards you — which is why a roof can no longer lose half of itself by
  /// being looked at from the wrong place.
  void _paint(
    Projector p,
    TownEntry e,
    Facet f,
    Palette pal,
    V3 light,
    bool night,
    double decay,
    Size size,
  ) {
    final v = f.v;
    final a = v[0];
    final eye = p.eye;
    if ((eye.x - a.x) * f.n.x + (eye.y - a.y) * f.n.y + (eye.z - a.z) * f.n.z <=
        0) {
      return;
    }
    // The notice board belongs to the town rather than to any achievement, so
    // it has no piece to take its colour or its weathering from. It takes them
    // from the town instead: a place nobody has been to in a month has a
    // weathered board like everything else in it.
    if (f.piece < 0) {
      _plain(p, f, pal, light, decay);
      return;
    }
    if (f.piece >= e.layout.pieces.length) return;
    final piece = e.layout.pieces[f.piece];
    final tone = _toneOf(e, piece, pal, decay);
    final colour = _colourOf(p, f, piece, tone, pal, light, decay, night);
    if (colour == null) return;
    _push(p, v, colour, piece, size);
    final decals = f.decals;
    if (decals == null) return;
    for (final g in decals) {
      final c = _colourOf(p, g, piece, tone, pal, light, decay, night);
      if (c != null) _push(p, g.v, c, piece, size);
    }
  }

  /// A face with no achievement behind it: the town's own furniture.
  void _plain(Projector p, Facet f, Palette pal, V3 light, double decay) {
    final at = f.v.first;
    final albedo = _weather(Color(f.tint ?? 0xFF808080), decay, 0);
    final colour = _hazeAt(
      _shade(f.n, albedo, light, pal, f.ao, 0, 0),
      p,
      at.x,
      at.z,
      pal,
    ).toARGB32();
    _push(p, f.v, colour, null, null);
    final decals = f.decals;
    if (decals == null) return;
    for (final g in decals) {
      final c = _hazeAt(
        _shade(
          g.n,
          _weather(Color(g.tint ?? 0xFF808080), decay, 0),
          light,
          pal,
          g.ao,
          0,
          0,
        ),
        p,
        at.x,
        at.z,
        pal,
      ).toARGB32();
      _push(p, g.v, c, null, null);
    }
  }

  void _push(
    Projector p,
    List<V3> v,
    int colour,
    TownPiece? piece,
    Size? size,
  ) {
    final m = v.length;
    if (m < 3 || m > 24) return;
    for (var i = 0; i < m; i++) {
      final q = v[i];
      final cp = p.cameraOf(q);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    final before = _faceCount;
    _emit(p, _clipA, m, colour);
    if (piece == null || size == null) return;
    // Todas sus caras, no la primera: la caja de una pieza es la de todo lo
    // que se ve de ella.
    if (_picking && _faceCount > before) {
      var near = double.infinity;
      for (var i = 0; i < m; i++) {
        final z = _clipA[i * 3 + 2];
        if (z < near) near = z;
      }
      _registerPick(
        _facePool[before],
        piece.index,
        size,
        math.max(near, p.near),
      );
    }
  }

  /// The colours a house is painted in. They belong to the house, not to the
  /// piece: a wall that changes tone halfway up, or a dormer that does not
  /// match its own roof, is the fastest way to make a town look like a pile of
  /// blocks.
  _Tone _toneOf(TownEntry e, TownPiece piece, Palette pal, double decay) {
    final key = piece.building;
    final had = _tone[key];
    if (had != null) return had;
    final h = hash32(piece.building, 0x51ed, 3);
    final ch = e.layout.character;
    // A house is plaster over stone: pale walls, a stone base, a warm roof.
    // Plaster takes a limewash, and every town has one it favours: Ribera is
    // white, Marca ochre, Costa indigo. Most houses take the local colour and
    // the rest go their own way, which is what stops a town reading as one
    // material repeated — and what makes two towns two places.
    final warm = hash01(h, 1);
    var wall = Color.lerp(pal.stoneCool, pal.stoneWarm, 0.35 + warm * 0.55)!;
    final wash = hash01(h, 2);
    if (wash < ch.washShare) {
      // At a third of the way the wash was not a colour, it was a hint of one:
      // the pale stone underneath won every time, and a town whose limewash is
      // indigo came out grey while the one whose limewash is ochre came out
      // beige — every region within a twelfth of every other. What varies now
      // is how much of the same wash a house took, not whether it took it, so
      // a street reads as one limewash weathered differently rather than as
      // six houses that never agreed on a colour.
      wall = Color.lerp(wall, ch.wash, 0.52 + hash01(h, 21) * 0.30)!;
    } else if (wash < ch.washShare + 0.07) {
      wall = Color.lerp(wall, const Color(0xFFC9836E), 0.34)!;
    } else if (wash < ch.washShare + 0.12) {
      wall = Color.lerp(wall, const Color(0xFFA8B47A), 0.28)!;
    }
    // What this roof is made of was settled when the town was laid out — the
    // straw ones are a different shape, so it had to be — and this only asks.
    // It used to roll its own hash here from the same mix, which meant two
    // files agreeing by hand about which houses were thatched.
    final b = piece.building;
    final marks = e.layout.buildings;
    final stuff = b >= 0 && b < marks.length ? marks[b].roof : RoofStuff.tile;
    final base = switch (stuff) {
      RoofStuff.tile => const Color(0xFFC05C38),
      RoofStuff.slate => const Color(0xFF5B6B72),
      RoofStuff.thatch => const Color(0xFFC2A054),
    };
    return _tone[key] = _Tone(
      wall,
      Color.lerp(pal.stoneCool, pal.stone, 0.55)!,
      Color.lerp(base, pal.stone, 0.08)!,
    );
  }

  /// What one face looks like right now, or null when it is not there at all —
  /// a plank across a window that nobody has abandoned yet.
  int? _colourOf(
    Projector p,
    Facet f,
    TownPiece piece,
    _Tone tone,
    Palette pal,
    V3 light,
    double decay,
    bool night,
  ) {
    final s = piece.seed;
    var flash = 0.0;
    if (_sweep >= 0 && piece.building == scene.finished) {
      final d = (piece.y0 - _sweep).abs();
      if (d < 0.9) flash = (1 - d / 0.9) * (1 - d / 0.9) * _sweepFade;
    }
    final fx = scene.fx;
    if (fx != null && fx.brickIndex == piece.index) flash = fx.flash;

    Color albedo;
    switch (f.surface) {
      case Surface.wall:
        albedo = _weather(tone.wall, decay, s);
      case Surface.stone:
        albedo = _weather(tone.stone, decay, s);
      case Surface.tile:
        albedo = _weather(tone.tile, decay, s);
      case Surface.thatch:
        // Straw is not a painted surface, it is a heaped one: every plane of
        // a thatched roof takes a step of its own so the thing reads as
        // bundles laid by hand and not as a wedge the colour of straw.
        albedo = _weather(
          Color.lerp(tone.tile, pal.stone, hash01(s, 17 + f.data) * 0.16)!,
          decay,
          s,
        );
      case Surface.brick:
        albedo = _weather(const Color(0xFF8C6A52), decay, s);
      case Surface.own:
        albedo = _weather(Color(f.tint ?? 0xFF808080), decay, s);
      case Surface.leaf:
        final leaf = Color.lerp(
          const Color(0xFF4E5C3C),
          const Color(0xFF6E7448),
          hash01(s, 11),
        )!;
        // Pulled towards the ground's own tone so a tree reads as part of the
        // landscape rather than as a green block dropped onto it.
        albedo = Color.lerp(
          Color.lerp(leaf, pal.ground, 0.28)!,
          const Color(0xFF8A6E42),
          decay * 0.6,
        )!;
      case Surface.hollow:
        // The dark inside an arch is a shadow, not a surface: it is not lit,
        // and lighting it is what turns an opening into a grey sticker.
        return _hazeAt(
          Color.lerp(pal.ink, tone.stone, 0.22)!,
          p,
          piece.cx,
          piece.cz,
          pal,
        ).toARGB32();
      case Surface.window:
        return _window(p, f, piece, pal, decay, night);
      case Surface.plank:
        if (!_shut(f, piece, decay, night)) return null;
        return _hazeAt(
          _weather(const Color(0xFF7A6549), decay, s),
          p,
          piece.cx,
          piece.cz,
          pal,
        ).toARGB32();
    }
    return _hazeAt(
      _shade(f.n, albedo, light, pal, f.ao, flash, 0),
      p,
      piece.cx,
      piece.cz,
      pal,
    ).toARGB32();
  }

  /// Whether this window has a light on behind it.
  ///
  /// One place, because two places is what it was: the same expression written
  /// out twice, in the code that paints a window and in the code that decides
  /// whether to board one up, and two copies of a rule are two rules waiting
  /// to disagree.
  ///
  /// At full health every window is lit, which is what the app has been saying
  /// all along — «todas las ventanas encendidas» — while this quietly lit
  /// seventy-two per cent of them and left the rest dark on a town that had
  /// nothing wrong with it. They go out as the days without a piece add up,
  /// and always in the same order, so a town empties in a way you can
  /// recognise instead of flickering at random.
  bool _litWindow(Facet f, TownPiece piece, double decay, bool night) {
    if (!night) return false;
    final life = clampD(1 - decay, 0, 1);
    final lifeCurve = life * life * (3 - 2 * life);
    return hash01(piece.seed, 70, f.data) < lifeCurve;
  }

  /// Whether a window has been boarded up. The same ones go first every time,
  /// so a town empties in an order you can recognise rather than flickering at
  /// random.
  bool _shut(Facet f, TownPiece piece, double decay, bool night) {
    final s = piece.seed;
    if (_litWindow(f, piece, decay, night)) return false;
    final boarded = decay > 0.30 && hash01(s, 72) < (decay - 0.30) * 1.5;
    return boarded || hash01(s, 73, f.data) < decay * 0.8;
  }

  /// A window, which is where the town says how you are doing. A lit window is
  /// one achievement showing from the outside; a whole town of them read in a
  /// single glance is the thing the wall could never do. And when the days
  /// start going by without a piece, they go out one by one.
  int _window(
    Projector p,
    Facet f,
    TownPiece piece,
    Palette pal,
    double decay,
    bool night,
  ) {
    final life = clampD(1 - decay, 0, 1);
    final lifeCurve = life * life * (3 - 2 * life);
    final lit = _litWindow(f, piece, decay, night);
    final colour = lit
        ? Color.lerp(
            const Color(0xFF7A5C2E),
            const Color(0xFFFFD79A),
            0.35 + 0.65 * lifeCurve,
          )!
        : Color.lerp(pal.ink, pal.stoneCool, night ? 0.12 : 0.30)!;
    if (!lit) return _hazeAt(colour, p, piece.cx, piece.cz, pal).toARGB32();
    // A lit window is a light, not a yellow rectangle. Remember where it fell
    // so a glow can be laid over the town once the walls are down.
    if (_lamps.length < 4 * 220) {
      final at = p.project(f.centroid);
      if (at != null) {
        final r = p.focal / at.depth * 0.34;
        if (r > 1.2) {
          _lamps
            ..add(at.x)
            ..add(at.y)
            ..add(math.min(r, 34))
            ..add(clampD(1 - decay * 0.7, 0.2, 1.0));
        }
      }
    }
    return colour.toARGB32();
  }

  // ------------------------------------------------------------------ wind

  /// One travelling gust, in -1..1.
  ///
  /// Everything that moves in the town moves to this same field, so the grass,
  /// the crops, the trees and the banners all lean the same way at the same
  /// moment. A dozen things each fidgeting to their own clock reads as noise;
  /// a dozen things leaning together reads as weather.
  double _gust(double x, double z, [double phase = 0]) {
    final t = scene.time;
    final a = math.sin(x * 0.36 + z * 0.23 - t * 1.25 + phase);
    final b = math.sin(x * 0.11 - z * 0.17 - t * 0.51 + phase * 0.6);
    return a * 0.62 + b * 0.38;
  }

  /// How hard it is blowing just now, so there are calm spells and gusty ones
  /// instead of one endless breeze.
  double get _windForce =>
      0.42 + 0.58 * (0.5 + 0.5 * math.sin(scene.time * 0.31));

  /// Ploughed rows, and the crop standing in them rippling with the wind.
  void _emitField(
    Projector p,
    TownPiece piece,
    double y0,
    Palette pal,
    double decay,
  ) {
    final s = piece.seed;
    // Real crop colours rather than a wash of the ground tone: young green,
    // ripe barley, the deep green of a kitchen garden.
    final t = hash01(s, 9);
    final crop = t < 0.36
        ? const Color(0xFF6FA341)
        : (t < 0.72 ? const Color(0xFFC9A94A) : const Color(0xFF4E8C46));
    final soil = const Color(0xFF6B563E);
    final along = piece.alongX;
    final across = along ? piece.d : piece.w;
    final rows = clampD(across / 0.26, 3, 14).round();
    final y = y0 + 0.012;
    final sway = 0.055 * _windForce;

    // The rows are sheets lying one behind the other on the ground: paint them
    // starting from the far side and each covers the join of the one before.
    // Which end is the far one depends on where you are standing, and that is
    // the whole of it.
    final back = along ? p.eye.z > piece.cz : p.eye.x > piece.cx;
    for (var k = 0; k < rows; k++) {
      final i = back ? k : rows - 1 - k;
      final lean = _gust(piece.cx, piece.cz, i * 0.5) * sway;
      final a = (i + 0.10) / rows, b = (i + 0.86) / rows;
      final ripe = Color.lerp(
        crop,
        const Color(0xFFE0C86A),
        0.18 * (0.5 + 0.5 * _gust(piece.cx, piece.cz, i * 0.9)),
      )!;
      final c = _hazeAt(
        Color.lerp(i.isEven ? ripe : soil, pal.ground, decay * 0.45)!,
        p,
        piece.cx,
        piece.cz,
        pal,
      );
      // The crop stands a little proud of the soil, and leans.
      final h = i.isEven ? y + 0.10 : y;
      final push = i.isEven ? lean : 0.0;
      final V3 q0, q1, q2, q3;
      if (along) {
        final z0 = piece.z0 + across * a, z1 = piece.z0 + across * b;
        q0 = V3(piece.x0 + push, h, z0);
        q1 = V3(piece.x1 + push, h, z0);
        q2 = V3(piece.x1, y, z1);
        q3 = V3(piece.x0, y, z1);
      } else {
        final x0 = piece.x0 + across * a, x1 = piece.x0 + across * b;
        q0 = V3(x0, h, piece.z0 + push);
        q1 = V3(x0, h, piece.z1 + push);
        q2 = V3(x1, y, piece.z1);
        q3 = V3(x1, y, piece.z0);
      }
      _quad(p, q0, q1, q2, q3, c.toARGB32());
    }
  }

  /// Standing water: a colour of its own, bands of light running across it,
  /// and foam where it meets the bank.
  void _emitWater(
    Projector p,
    TownPiece piece,
    double y0,
    Palette pal,
    bool night,
  ) {
    final y = y0 + 0.05;
    final deep = night ? const Color(0xFF1E3A52) : const Color(0xFF35707B);
    final lit = night ? const Color(0xFF33556F) : const Color(0xFF5C9AA0);
    // Foam is water with air in it, not paint: it keeps the water's own colour
    // underneath, which is what stops it reading as a white sticker.
    final foam = Color.lerp(
      night ? const Color(0xFF8FA4B8) : const Color(0xFFE8F4F2),
      deep,
      0.32,
    )!;
    final cx = piece.cx, cz = piece.cz;

    int tint(Color c) => _hazeAt(c, p, cx, cz, pal).toARGB32();

    // Every sheet here sits a hair higher than the one before it, and the
    // camera never gets below the waterline, so painting them in the order
    // they are written is painting them bottom up — which is the right order
    // and needs nothing said about depth.
    void plate(double x0, double x1, double z0, double z1, double h, Color c) {
      _quad(
        p,
        V3(x0, h, z1),
        V3(x1, h, z1),
        V3(x1, h, z0),
        V3(x0, h, z0),
        tint(c),
      );
    }

    plate(piece.x0, piece.x1, piece.z0, piece.z1, y, deep);

    // Bands of reflected light travelling across it. Each sits a hair higher
    // than the last so they never fight each other for the same depth.
    final w = piece.w, d = piece.d;
    const bands = 3;
    for (var i = 0; i < bands; i++) {
      final phase = scene.time * 0.33 + i * 0.41 + hash01(piece.seed, 21, i);
      final t = phase - phase.floorToDouble();
      final z = piece.z0 + d * t;
      final thick = d * (0.05 + 0.03 * math.sin(scene.time * 1.1 + i));
      if (z + thick > piece.z1) continue;
      final inset = w * 0.06;
      plate(
        piece.x0 + inset,
        piece.x1 - inset,
        z,
        z + thick,
        y + 0.004 + i * 0.002,
        Color.lerp(deep, lit, 0.55)!,
      );
    }

    // Foam: a frill round the edge that breathes with the wind, so still water
    // still looks alive.
    final swell = 0.014 + 0.012 * _windForce;
    final rim = math.min(math.min(w, d) * (0.05 + 0.025 * _windForce), 0.13);
    if (rim < 0.02) return;
    final fy = y + 0.012;
    for (var side = 0; side < 4; side++) {
      final wob = rim * (0.7 + 0.5 * _gust(cx, cz, side * 1.7).abs());
      switch (side) {
        case 0:
          plate(piece.x0, piece.x1, piece.z0, piece.z0 + wob, fy, foam);
        case 1:
          plate(piece.x0, piece.x1, piece.z1 - wob, piece.z1, fy, foam);
        case 2:
          plate(piece.x0, piece.x0 + wob, piece.z0, piece.z1, fy, foam);
        case 3:
          plate(piece.x1 - wob, piece.x1, piece.z0, piece.z1, fy, foam);
      }
    }
    // And a lick of white further in on the windward side.
    final lick = rim * 0.6 * (0.5 + 0.5 * math.sin(scene.time * 1.7));
    if (lick > 0.01) {
      plate(
        piece.x0 + rim,
        piece.x1 - rim,
        piece.z0 + rim,
        piece.z0 + rim + lick,
        y + swell,
        foam,
      );
    }
  }

  /// A pole with a banner hanging from it. The one piece of the town allowed a
  /// colour that is not stone, plaster or tile.
  void _emitBanner(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Palette pal,
  ) {
    final ht = y1 - y0;
    // The pole is masonry and stands in the tree with everything else; what is
    // left here is the cloth, which is the one thing in the town that flies.
    final pick = hash01(piece.seed, 13);
    final cloth = pick < 0.34
        ? const Color(0xFFC0392B)
        : (pick < 0.67 ? const Color(0xFFE0A32E) : const Color(0xFF2E6FA8));
    final e = p.eye;
    final gust = _gust(piece.cx, piece.cz, piece.seed * 0.0007);
    final fly = ht * (0.30 + 0.18 * _windForce * (0.5 + 0.5 * gust));
    final top = y1 - ht * 0.08, bot = top - ht * 0.34;
    // The free corner lifts and falls; the hoist stays on the pole.
    final wave = ht * 0.11 * gust * _windForce;
    final c = _hazeAt(cloth, p, piece.cx, piece.cz, pal).toARGB32();
    final shade = _hazeAt(
      Color.lerp(cloth, Colors.black, 0.22)!,
      p,
      piece.cx,
      piece.cz,
      pal,
    ).toARGB32();
    if ((e.x - piece.cx).abs() > (e.z - piece.cz).abs()) {
      final z0 = piece.cz + 0.04, z1 = piece.cz + 0.04 + fly;
      _quad(
        p,
        V3(piece.cx, bot, z0),
        V3(piece.cx, bot + wave, z1),
        V3(piece.cx, top + wave, z1),
        V3(piece.cx, top, z0),
        c,
      );
      _quad(
        p,
        V3(piece.cx, bot, z0),
        V3(piece.cx, bot + wave, z1),
        V3(piece.cx, bot + wave - ht * 0.06, z1),
        V3(piece.cx, bot - ht * 0.02, z0),
        shade,
      );
    } else {
      final x0 = piece.cx + 0.04, x1 = piece.cx + 0.04 + fly;
      _quad(
        p,
        V3(x0, bot, piece.cz),
        V3(x1, bot + wave, piece.cz),
        V3(x1, top + wave, piece.cz),
        V3(x0, top, piece.cz),
        c,
      );
      _quad(
        p,
        V3(x0, bot, piece.cz),
        V3(x1, bot + wave, piece.cz),
        V3(x1, bot + wave - ht * 0.06, piece.cz),
        V3(x0, bot - ht * 0.02, piece.cz),
        shade,
      );
    }
  }

  /// Four sails on a windmill's cap, turning.
  ///
  /// Drawn as flat quads in the plane of the cap rather than as boxes, which is
  /// what lets them sit at any angle — and a windmill whose sails go round is
  /// the single most alive thing in the town.
  void _emitSails(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
  ) {
    final r = (y1 - y0) / 2;
    final cy = y0 + r;
    final cx = piece.cx, cz = piece.cz - 0.16;
    const wood = Color(0xFF5A4835);
    final cloth = Color.lerp(const Color(0xFFF6EBD2), pal.stoneWarm, 0.18)!;
    final shade = Color.lerp(cloth, const Color(0xFF8A6E4A), 0.30)!;

    // The wheel turns at the wind's own pace, and freewheels a little when the
    // gust drops, so it never looks like a clock hand.
    final turn =
        scene.time * (0.55 + 0.75 * _windForce) + hash01(piece.seed, 17) * 6.28;

    void blade(
      double ang,
      double from,
      double to,
      double halfW,
      Color c,
      double ao,
    ) {
      final dx = math.cos(ang), dy = math.sin(ang);
      final nx = -dy * halfW, ny = dx * halfW;
      _quad(
        p,
        V3(cx + dx * from + nx, cy + dy * from + ny, cz),
        V3(cx + dx * to + nx, cy + dy * to + ny, cz),
        V3(cx + dx * to - nx, cy + dy * to - ny, cz),
        V3(cx + dx * from - nx, cy + dy * from - ny, cz),
        _hazeAt(
          _shade(const V3(0, 0, -1), c, light, pal, ao, 0, 0),
          p,
          cx,
          cz,
          pal,
        ).toARGB32(),
      );
    }

    for (var i = 0; i < 4; i++) {
      final a = turn + i * math.pi / 2;
      // The cloth first, then the stock over it, so the frame reads on top.
      blade(a, r * 0.30, r * 0.98, r * 0.20, i.isEven ? cloth : shade, 1.06);
      blade(a, r * 0.06, r * 1.0, r * 0.055, wood, 0.95);
    }
  }

  Color _weather(Color c, double decay, int seed) {
    if (decay < 0.02) return c;
    final moss = hash01(seed, 61) < decay * 0.55;
    final t = decay * (moss ? 0.42 : 0.22);
    return Color.lerp(c, const Color(0xFF5C6B4A), t)!;
  }

  /// The name of each landmark the town has finished.
  void _drawTownLabels(Canvas canvas, Projector p, Size size, TownLayout town) {
    if (!scene.labels) return;
    // From far enough back the valley is about which town is which, not which
    // building is which. The landmark names stand down for the town signs.
    if (scene.towns.length > 1 && scene.camera.distance > 95) return;
    // Nearest first, so when two names collide it is the one further away that
    // gives up its place.
    final show = <(double, Offset2, String, double)>[];
    for (final b in town.buildings) {
      if (!b.isLandmark || !b.finished) continue;
      if (scene.placed < b.firstPiece + b.cost) continue;
      final at = p.project(V3(b.cx, b.peakY + 0.5, b.cz));
      if (at == null) continue;
      if (at.x < -120 || at.x > size.width + 120) continue;
      // The one just finished comes in last so nothing can push it aside, and
      // rises into place rather than blinking on.
      final pop = b.index == scene.finished
          ? clampD(scene.finishedAge / 0.55, 0, 1)
          : 1.0;
      show.add((
        b.index == scene.finished ? -1.0 : at.depth,
        at,
        b.name.toUpperCase(),
        pop,
      ));
    }
    show.sort((a, b) => a.$1.compareTo(b.$1));
    final taken = <Rect>[];
    for (final row in show) {
      _drawLabel(canvas, row.$2, row.$3, size, taken: taken, pop: row.$4);
    }
  }

  Color _shade(
    V3 n,
    Color albedo,
    V3 light,
    Palette pal,
    double ao,
    double flash,
    double repairGlow,
  ) {
    final ndl = math.max(0.0, n.dot(light));
    final skyTerm = 0.5 + 0.5 * n.y;
    // Stone in shadow is still stone: the sky term is modulated by the albedo
    // so unlit faces stay pale limestone instead of collapsing to black.
    final k = (0.44 + 0.58 * ndl + 0.26 * skyTerm) * ao * pal.contrast;
    var r =
        albedo.r * k +
        pal.sun.r * ndl * 0.06 +
        pal.skyLight.r * skyTerm * 0.045;
    var g =
        albedo.g * k +
        pal.sun.g * ndl * 0.06 +
        pal.skyLight.g * skyTerm * 0.045;
    var b =
        albedo.b * k +
        pal.sun.b * ndl * 0.06 +
        pal.skyLight.b * skyTerm * 0.045;
    if (flash > 0) {
      r = lerpD(r, 1.0, flash * 0.85);
      g = lerpD(g, 0.97, flash * 0.85);
      b = lerpD(b, 0.82, flash * 0.85);
    }
    if (repairGlow > 0) {
      r = lerpD(r, 1.0, repairGlow * 0.55);
      g = lerpD(g, 0.92, repairGlow * 0.5);
      b = lerpD(b, 0.68, repairGlow * 0.45);
    }
    return Color.fromARGB(255, _ch(r), _ch(g), _ch(b));
  }

  // ---------------------------------------------------------------- flush

  /// Paints what was collected, in the order it was collected.
  ///
  /// There is no sort here any more and there is not meant to be one: by the
  /// time a face reaches this list its place has already been decided by
  /// geometry rather than guessed from a distance.
  void _flush(Canvas canvas) {
    if (_faceCount == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // Two neighbouring faces drawn separately with antialiasing leave a
    // hairline of whatever is behind them showing between the two. Cutting the
    // geometry is what makes the order right, and cutting makes more
    // neighbours, so closing the seam matters more here than it ever did:
    // running the same colour round the edge does it.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (var k = 0; k < _faceCount; k++) {
      final f = _facePool[k];
      _scratch.reset();
      _scratch.moveTo(f.pts[0], f.pts[1]);
      for (var i = 1; i < f.n; i++) {
        _scratch.lineTo(f.pts[i * 2], f.pts[i * 2 + 1]);
      }
      _scratch.close();
      paint.color = Color(f.color);
      canvas.drawPath(_scratch, paint);
      seam.color = paint.color;
      canvas.drawPath(_scratch, seam);
    }
  }

  // ------------------------------------------------------------- extras

  /// A name set straight on the sky with a halo, and a hairline under it to tie
  /// it to the thing it names. No filled pill: that was the last of the heavy
  /// white chrome.
  void _drawLabel(
    Canvas canvas,
    Offset2 top,
    String name,
    Size size, {
    double? at,
    List<Rect>? taken,
    double pop = 1,
  }) {
    final depth = at ?? top.depth;
    // How far a name carries depends on how far back the camera has gone: from
    // across the valley the town should still say what its landmarks are.
    final far = math.max(24.0, scene.camera.distance * 1.15);
    final fade = clampD(1 - (depth - far) / (far * 0.75), 0, 1) * pop;
    if (fade <= 0.02) return;
    final dark = _isDarkSky();
    final glow = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: (dark ? Colors.white : scene.palette.ink).withValues(
            alpha: 0.88 * fade,
          ),
          fontSize: 9.5,
          letterSpacing: 2.6,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
                alpha: (dark ? 0.6 : 0.34) * fade,
              ),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The camera buttons live down the right-hand edge; a name that lands
    // under them is unreadable, so it slides left far enough to clear them.
    var cx = top.x;
    final inButtons = top.y > 80 && top.y < 250;
    final right = size.width - (inButtons ? 74 : 6) - glow.width / 2;
    final left = 6 + glow.width / 2;
    if (right > left) cx = clampD(cx, left, right);

    // A name that has just been earned rises into place instead of appearing.
    final lift = (1 - pop) * 16;
    final origin = Offset(cx - glow.width / 2, top.y - glow.height / 2 + lift);

    // A town has a lot of names in it. Two of them written across each other
    // are worth less than one of them alone, so a name that would land on one
    // already written simply is not written.
    if (taken != null) {
      final box = Rect.fromLTWH(
        origin.dx - 6,
        origin.dy - 3,
        glow.width + 12,
        glow.height + 14,
      );
      for (final other in taken) {
        if (box.overlaps(other)) return;
      }
      taken.add(box);
    }

    glow.paint(canvas, origin);

    // A hairline under it, to tie the name to the thing it names.
    final w = glow.width * 0.5;
    canvas.drawLine(
      Offset(cx - w / 2, origin.dy + glow.height + 5),
      Offset(cx + w / 2, origin.dy + glow.height + 5),
      Paint()
        ..strokeWidth = 1
        ..color = (dark ? Colors.white : scene.palette.ink).withValues(
          alpha: 0.30 * fade,
        ),
    );
  }

  bool _isDarkSky() {
    final c = scene.palette.skyHorizon;
    return (c.r * 0.3 + c.g * 0.55 + c.b * 0.15) < 0.45;
  }

  // ---------------------------------------------------------- stone marks

  // ------------------------------------------------------------- particles

  void _drawParticles(Canvas canvas, Projector p) {
    final pal = scene.palette;
    final paint = Paint();
    for (final part in scene.effects.live) {
      final pt = p.project(V3(part.x, part.y, part.z));
      if (pt == null) continue;
      final life = (part.life / part.maxLife).clamp(0.0, 1.0);
      final r = part.size * p.focal / pt.depth;
      if (r < 0.3) continue;
      switch (part.kind) {
        case ParticleKind.dust:
          paint
            ..color = Color.lerp(
              pal.stoneWarm,
              pal.haze,
              0.4,
            )!.withValues(alpha: life * 0.42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (2.2 - life), paint);
          paint.maskFilter = null;
        case ParticleKind.chip:
          paint.color = pal.stoneCool.withValues(alpha: life);
          canvas.save();
          canvas.translate(pt.x, pt.y);
          canvas.rotate(part.angle);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.4),
            paint,
          );
          canvas.restore();
        case ParticleKind.spark:
          paint.color = Color.lerp(
            pal.accent,
            Colors.white,
            0.4,
          )!.withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 1.3, paint);
        case ParticleKind.gold:
          paint.color = const Color(
            0xFFF2C25B,
          ).withValues(alpha: life * life * 0.85);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 0.9, paint);
        case ParticleKind.ember:
          paint.color = Color.lerp(
            const Color(0xFFFF8A3D),
            const Color(0xFFFFD79A),
            life,
          )!.withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.moteRepair:
          paint.color = const Color(0xFFBFE8D0).withValues(alpha: life * 0.8);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.smoke:
          // Thickest just after it leaves the flue, then thinning as it spreads
          // and takes the colour of the air it is drifting through.
          final age = 1 - life;
          final puff = Color.lerp(
            Color.lerp(pal.stoneCool, pal.ink, 0.22)!,
            pal.haze,
            age * 0.8,
          )!;
          paint
            ..color = puff.withValues(alpha: life * life * 0.30)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + age * 6);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (1.0 + age * 3.2), paint);
          paint.maskFilter = null;
        case ParticleKind.glint:
          final k = math.sin(life * math.pi);
          paint
            ..color = Color.lerp(
              pal.sun,
              Colors.white,
              0.5,
            )!.withValues(alpha: k * 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (0.8 + k), paint);
          paint.maskFilter = null;
      }
    }
  }

  // ----------------------------------------------------------------- ghost

  void _drawAtmosphere(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    final decay = 1 - scene.integrity;
    if (decay > 0.05) {
      // A town left alone does not fog over, it goes cold and quiet. Grey mist
      // reads as bad visibility; a cold, dim town reads as nobody home.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.lerp(
            pal.ink,
            const Color(0xFF3E4758),
            0.55,
          )!.withValues(alpha: 0.06 + decay * 0.20),
      );
    }
    // A soft vignette to hold the eye on the town.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.52),
          size.longestSide * 0.72,
          [Colors.transparent, pal.ink.withValues(alpha: 0.26)],
          [0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant TownPainter old) => true;
}
