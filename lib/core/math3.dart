import 'dart:math' as math;
import 'dart:typed_data';

/// Minimal 3D vector maths for the software renderer.
///
/// The wall is drawn with a hand-written painter's-algorithm rasteriser rather
/// than a GL binding: it keeps the stylised flat-shaded look exact, has no
/// native dependencies, and gives full control over per-face shading.
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  static const zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  V3 cross(V3 o) =>
      V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  V3 get normalized {
    final l = length;
    return l < 1e-9 ? zero : V3(x / l, y / l, z / l);
  }

  V3 lerp(V3 o, double t) =>
      V3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);

  @override
  String toString() =>
      'V3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Camera-space + screen-space projection.
///
/// Points are transformed into a right-handed camera basis, then divided by
/// depth. Polygons crossing the near plane are clipped in camera space before
/// the divide, which is what keeps stones from smearing across the screen when
/// the camera is pushed right up against the wall.
class Projector {
  Projector({
    required this.eye,
    required this.right,
    required this.up,
    required this.forward,
    required this.focal,
    required this.cx,
    required this.cy,
    this.near = 0.06,
  });

  final V3 eye, right, up, forward;
  final double focal, cx, cy, near;

  /// Camera-space coordinates: x right, y up, z into the screen.
  void toCamera(double px, double py, double pz, Float64List out, int at) {
    final vx = px - eye.x, vy = py - eye.y, vz = pz - eye.z;
    out[at] = vx * right.x + vy * right.y + vz * right.z;
    out[at + 1] = vx * up.x + vy * up.y + vz * up.z;
    out[at + 2] = vx * forward.x + vy * forward.y + vz * forward.z;
  }

  V3 cameraOf(V3 p) {
    final v = p - eye;
    return V3(v.dot(right), v.dot(up), v.dot(forward));
  }

  /// Projects a camera-space point. Caller must ensure `z >= near`.
  double screenX(double camX, double camZ) => cx + camX * focal / camZ;
  double screenY(double camY, double camZ) => cy - camY * focal / camZ;

  /// Projects a world point, returning null when it sits behind the near plane.
  Offset2? project(V3 world) {
    final c = cameraOf(world);
    if (c.z < near) return null;
    return Offset2(screenX(c.x, c.z), screenY(c.y, c.z), c.z);
  }
}

/// A projected point plus the depth it came from.
class Offset2 {
  const Offset2(this.x, this.y, this.depth);
  final double x, y, depth;
}

/// Clips a camera-space polygon against the near plane.
///
/// [src] holds `count` xyz triples. Results are written into [dst] and the new
/// vertex count is returned. Both buffers are caller-owned scratch space so the
/// renderer never allocates inside the per-frame loop.
int clipNear(Float64List src, int count, Float64List dst, double near) {
  if (count < 3) return 0;
  var out = 0;
  for (var i = 0; i < count; i++) {
    final j = (i + 1) % count;
    final ax = src[i * 3], ay = src[i * 3 + 1], az = src[i * 3 + 2];
    final bx = src[j * 3], by = src[j * 3 + 1], bz = src[j * 3 + 2];
    final aIn = az >= near;
    final bIn = bz >= near;
    if (aIn) {
      dst[out * 3] = ax;
      dst[out * 3 + 1] = ay;
      dst[out * 3 + 2] = az;
      out++;
    }
    if (aIn != bIn) {
      final t = (near - az) / (bz - az);
      dst[out * 3] = ax + (bx - ax) * t;
      dst[out * 3 + 1] = ay + (by - ay) * t;
      dst[out * 3 + 2] = near;
      out++;
    }
  }
  return out;
}

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

double lerpD(double a, double b, double t) => a + (b - a) * t;

/// Smooth 0..1 ramp between two thresholds.
double smoothstep(double edge0, double edge1, double x) {
  if (edge1 <= edge0) return x < edge0 ? 0 : 1;
  final t = clampD((x - edge0) / (edge1 - edge0), 0, 1);
  return t * t * (3 - 2 * t);
}

/// Shortest signed angular difference, used so the orbit camera never spins the
/// long way round when it flies to a new brick.
double angleDelta(double from, double to) {
  var d = (to - from) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return d;
}
