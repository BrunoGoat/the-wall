import 'dart:math' as math;

import '../core/math3.dart';

/// Orbit camera for the wall.
///
/// The wall is straight and can get very long, so the camera has two separate
/// freedoms: it orbits around a focus point, and that focus point travels along
/// the wall. Pitch is clamped so you can look from the side, from behind and
/// from straight above, but never from underneath.
class OrbitCamera {
  OrbitCamera();

  static const double minPitch = 0.015;
  static const double maxPitch = 1.50; // ~86 degrees: top-down, never below
  static const double minDistance = 2.2;

  /// Far enough back to hold the whole valley in one frame: seis pueblos en un
  /// anillo de ciento veinticuatro, cada uno con su radio, y el más grande de
  /// todos —el Coloso— con torres de cuarenta de alto.
  ///
  /// Subió de seiscientos veinte cuando el anillo pasó de setenta y ocho a
  /// ciento veinticuatro. Con el tope viejo el valle entero ya no entraba, y lo
  /// que hacía la cámara era irse al tope y dejar dos pueblos fuera del cuadro
  /// sin decir nada.
  static const double maxDistance = 980.0;

  /// Where the camera is looking, on the wall axis.
  double travel = 0;
  double focusY = 1.15;

  /// Across the wall's axis. Always zero for the wall, which is straight; the
  /// town spreads both ways from its plaza and needs the second freedom.
  double focusZ = 0;

  double yaw = 0.62;
  double pitch = 0.30;
  double distance = 9.0;

  /// Damped targets. Everything the user does moves the target; the actual
  /// camera eases toward it, which is what makes the fly-to-brick move feel
  /// like a camera rather than a teleport.
  double travelTarget = 0;
  double focusYTarget = 1.15;
  double focusZTarget = 0;
  double yawTarget = 0.62;
  double pitchTarget = 0.30;
  double distanceTarget = 9.0;

  /// Extra shake applied on impact, in radians / world units.
  double shake = 0;

  /// True while the camera automatically follows the newest stone.
  bool follow = true;

  double wallLength = 1;

  /// How far along the world axis the camera is allowed to look.
  ///
  /// This used to be `[-2, wallLength + 2]`, which was right when the app was
  /// one straight wall that started at the origin and only ran one way. A
  /// valley does not: its towns sit on a ring seventy-eight units across, so
  /// three of the six have a centre the old range could not even reach, and
  /// asking the camera to look at one of them left it pointing at the empty
  /// field between them. Which is exactly what it did on every piece laid in
  /// those towns.
  double travelMin = -2.0;
  double travelMax = 2.0;

  /// Says how wide the world is. Everything that can be looked at has to be
  /// inside it, or the camera will refuse to look there and give no sign why.
  void reaches(double from, double to) {
    travelMin = math.min(from, to);
    travelMax = math.max(from, to);
  }

  void snap() {
    travel = travelTarget;
    focusY = focusYTarget;
    focusZ = focusZTarget;
    yaw = yawTarget;
    pitch = pitchTarget;
    distance = distanceTarget;
  }

  void orbitBy(double dYaw, double dPitch) {
    yawTarget += dYaw;
    pitchTarget = clampD(pitchTarget + dPitch, minPitch, maxPitch);
  }

  /// How far back it is worth going. Beyond about the wall's own length the
  /// wall is a thread in the middle of an empty field, so pulling further out
  /// only loses it: past that the zoom simply stops.
  ///
  /// Two lengths back rather than one: from a single length away a town fills
  /// the frame edge to edge, and standing far enough off to see it sit in its
  /// own fields is half of what there is to look at.
  double get usefulDistance =>
      clampD(math.max(wallLength * 2.0, 45.0), minDistance, maxDistance);

  void zoomBy(double factor) {
    distanceTarget = clampD(
      distanceTarget * factor,
      minDistance,
      usefulDistance,
    );
  }

  void travelBy(double d) {
    travelTarget = clampD(travelTarget + d, travelMin, travelMax);
    follow = false;
  }

  void travelTo(double x, {bool animate = true}) {
    travelTarget = clampD(x, travelMin, travelMax);
    if (!animate) travel = travelTarget;
  }

  /// Frames the whole wall, used by the "ver toda la muralla" button.
  void frameAll() {
    travelTarget = wallLength / 2;
    distanceTarget = clampD(
      math.max(wallLength * 0.62, 8.0),
      minDistance,
      usefulDistance,
    );
    pitchTarget = clampD(0.34 + wallLength * 0.002, minPitch, 0.7);
    yawTarget = _nearest(yawTarget, 0.55);
    focusYTarget = 1.6;
    follow = false;
  }

  /// Snaps yaw to the nearest equivalent of [want] so the camera never spins
  /// the long way round.
  double _nearest(double current, double want) =>
      current + angleDelta(current, want);

  void step(double dt) {
    final k = 1 - math.exp(-dt * 7.5);
    travel += (travelTarget - travel) * k;
    focusY += (focusYTarget - focusY) * k;
    focusZ += (focusZTarget - focusZ) * k;
    yaw += angleDelta(yaw, yawTarget) * k;
    pitch += (pitchTarget - pitch) * k;
    distance += (distanceTarget - distance) * k;
    shake *= math.exp(-dt * 9.0);
    if (shake < 0.0005) shake = 0;
  }

  /// La distancia más corta desde la que [points] caben en la pantalla.
  ///
  /// Con los ángulos y el foco que la cámara tiene puestos ahora mismo, así
  /// que quien la llame tiene que ponérselos antes —normalmente sobre una
  /// cámara de mentira, para no mover la de verdad mientras se prueba.
  ///
  /// Se busca a tientas sobre la proyección de verdad y no con una fórmula
  /// porque no hay fórmula corta: la lente abre distinto a lo ancho que a lo
  /// alto, la cámara mira hacia abajo, y lo que hay que encuadrar es un suelo
  /// en perspectiva y no una pared de frente. Multiplicar el radio por dos
  /// coma cuatro valía mirando al centro del anillo y dejaba el pueblo de
  /// enfrente a ciento treinta píxeles fuera de la pantalla en cuanto el foco
  /// se movía al borde.
  double distanceToFit(
    List<V3> points,
    double width,
    double height, {
    double margin = 0.92,
  }) {
    if (points.isEmpty) return distance;
    final mx = width * (1 - margin) / 2, my = height * (1 - margin) / 2;
    bool fits(double d) {
      final keep = distance;
      distance = d;
      final p = projector(width, height, 0);
      distance = keep;
      for (final v in points) {
        final c = p.cameraOf(v);
        if (c.z <= p.near) return false;
        final x = p.screenX(c.x, c.z), y = p.screenY(c.y, c.z);
        if (x < mx || x > width - mx) return false;
        if (y < my || y > height - my) return false;
      }
      return true;
    }

    if (!fits(maxDistance)) return maxDistance;
    var lo = minDistance, hi = maxDistance;
    for (var i = 0; i < 26; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  V3 get target => V3(travel, focusY, focusZ);

  V3 get eye {
    final cp = math.cos(pitch);
    final dir = V3(math.sin(yaw) * cp, math.sin(pitch), math.cos(yaw) * cp);
    return target + dir * distance;
  }

  /// Builds the projector for a given viewport.
  Projector projector(double width, double height, double shakePhase) {
    var e = eye;
    var t = target;
    if (shake > 0) {
      final s = shake;
      e =
          e +
          V3(
            math.sin(shakePhase * 41.0) * s,
            math.cos(shakePhase * 53.0) * s,
            math.sin(shakePhase * 37.0) * s * 0.6,
          );
    }
    final forward = (t - e).normalized;
    var right = forward.cross(const V3(0, 1, 0));
    if (right.length < 1e-4) {
      right = const V3(1, 0, 0);
    }
    right = right.normalized;
    final up = right.cross(forward).normalized;

    // A slightly long lens keeps the wall from bending away at the edges.
    const fovY = 0.86;
    final focal = (height / 2) / math.tan(fovY / 2);
    return Projector(
      eye: e,
      right: right,
      up: up,
      forward: forward,
      focal: focal,
      cx: width / 2,
      cy: height / 2,
    );
  }

  /// How far along the wall stones are drawn one by one. Set each frame from
  /// the stone density and the detail budget, so the budget is spent on a
  /// continuous stretch of wall rather than being scattered thinly over one
  /// that is far too long for it.
  double detailRadius = 20;

  /// How far the stones carry on as plain blocks past the detailed band.
  double coarseRadius = 60;
}
