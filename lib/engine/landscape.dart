import 'dart:math' as math;

import '../core/math3.dart';

import '../core/rng.dart';

/// The country the wall runs through.
///
/// Everything here is a pure function of world position, so the same hills sit
/// in the same place on every launch, and walking a hundred units along the
/// wall reveals new country rather than the same backdrop sliding along.
class Landscape {
  const Landscape._();

  /// Smooth value noise on the ground plane.
  static double _noise(double x, double z, int seed) {
    final xi = x.floor();
    final zi = z.floor();
    final xf = x - xi;
    final zf = z - zi;
    final u = xf * xf * (3 - 2 * xf);
    final v = zf * zf * (3 - 2 * zf);
    double h(int a, int b) => hash01(a, b, seed);
    final a = lerpD(h(xi, zi), h(xi + 1, zi), u);
    final b = lerpD(h(xi, zi + 1), h(xi + 1, zi + 1), u);
    return lerpD(a, b, v);
  }

  static double _fbm(double x, double z, int seed) {
    var v = 0.0;
    var amp = 0.55;
    var f = 1.0;
    for (var i = 0; i < 4; i++) {
      v += _noise(x * f, z * f, seed + i * 131) * amp;
      f *= 2.03;
      amp *= 0.48;
    }
    return v;
  }

  /// The three ranges, from nearest to furthest. Sized so each one clears the
  /// last on the skyline instead of all three collapsing into one band.
  static const List<RidgeLayer> ridges = [
    RidgeLayer(radius: 150, scale: 0.0125, height: 40, base: -1.5, seed: 11),
    RidgeLayer(radius: 330, scale: 0.0060, height: 108, base: -3.0, seed: 37),
    RidgeLayer(radius: 690, scale: 0.0030, height: 250, base: -8.0, seed: 71),
  ];

  /// Height of a range at a point on it. Peaks are sharpened so the skyline
  /// reads as mountains rather than as dunes.
  static double ridgeHeight(RidgeLayer l, double wx, double wz) {
    final n = _fbm(wx * l.scale, wz * l.scale, l.seed);
    final shaped = math.pow(clampD(n, 0, 1), 1.55).toDouble();
    return l.base + shaped * l.height;
  }

}

class RidgeLayer {
  const RidgeLayer({
    required this.radius,
    required this.scale,
    required this.height,
    required this.base,
    required this.seed,
  });

  /// How far from the viewer this range sits.
  final double radius;

  /// Noise frequency: lower means broader mountains.
  final double scale;

  /// Peak height above the plain.
  final double height;

  /// How far the foot of the range sits below the plain, so it never floats.
  final double base;

  final int seed;
}
