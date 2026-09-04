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
  static const double maxDistance = 120.0;

  /// Where the camera is looking, on the wall axis.
  double travel = 0;
  double focusY = 1.15;

  double yaw = 0.62;
  double pitch = 0.30;
  double distance = 9.0;

  /// Damped targets. Everything the user does moves the target; the actual
  /// camera eases toward it, which is what makes the fly-to-brick move feel
  /// like a camera rather than a teleport.
  double travelTarget = 0;
  double focusYTarget = 1.15;
  double yawTarget = 0.62;
  double pitchTarget = 0.30;
  double distanceTarget = 9.0;

  /// Extra shake applied on impact, in radians / world units.
  double shake = 0;

  /// True while the camera automatically follows the newest stone.
  bool follow = true;

  double wallLength = 1;

  void snap() {
    travel = travelTarget;
    focusY = focusYTarget;
    yaw = yawTarget;
    pitch = pitchTarget;
    distance = distanceTarget;
  }

  void orbitBy(double dYaw, double dPitch) {
    yawTarget += dYaw;
    pitchTarget = clampD(pitchTarget + dPitch, minPitch, maxPitch);
  }

  void zoomBy(double factor) {
    distanceTarget = clampD(distanceTarget * factor, minDistance, maxDistance);
  }

  void travelBy(double d) {
    travelTarget = clampD(travelTarget + d, -2.0, math.max(2.0, wallLength + 2));
    follow = false;
  }

  void travelTo(double x, {bool animate = true}) {
    travelTarget = clampD(x, -2.0, math.max(2.0, wallLength + 2));
    if (!animate) travel = travelTarget;
  }

  /// Frames the whole wall, used by the "ver toda la muralla" button.
  void frameAll() {
    travelTarget = wallLength / 2;
    distanceTarget =
        clampD(math.max(wallLength * 0.62, 8.0), minDistance, maxDistance);
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
    yaw += angleDelta(yaw, yawTarget) * k;
    pitch += (pitchTarget - pitch) * k;
    distance += (distanceTarget - distance) * k;
    shake *= math.exp(-dt * 9.0);
    if (shake < 0.0005) shake = 0;
  }

  V3 get target => V3(travel, focusY, 0);

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
      e = e +
          V3(math.sin(shakePhase * 41.0) * s, math.cos(shakePhase * 53.0) * s,
              math.sin(shakePhase * 37.0) * s * 0.6);
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
