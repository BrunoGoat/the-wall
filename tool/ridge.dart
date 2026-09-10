import 'dart:math' as math;
import '../lib/engine/landscape.dart';

void main() {
  for (final l in Landscape.ridges) {
    var lo = 1e9, hi = -1e9, sum = 0.0;
    for (var i = 0; i < 720; i++) {
      final th = i / 720 * math.pi * 2;
      final wx = math.sin(th) * l.radius;
      final wz = math.cos(th) * l.radius;
      final h = Landscape.ridgeHeight(l, wx, wz);
      if (h < lo) lo = h;
      if (h > hi) hi = h;
      sum += h;
    }
    print('radius=${l.radius}  min=${lo.toStringAsFixed(1)}  max=${hi.toStringAsFixed(1)}  '
        'avg=${(sum / 720).toStringAsFixed(1)}  angular=${(hi / l.radius * 57.3).toStringAsFixed(1)} deg');
  }
}
