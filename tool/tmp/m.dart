import 'dart:math' as math;
import 'package:la_muralla/engine/layout.dart';
void main() {
  for (final n in [100, 400, 1000, 3000, 6000]) {
    final l = WallLayout(n);
    var ra = 0.0, rn = 0, sa = 0.0, sn = 0, rampart = 0.0;
    for (final s in l.slots) {
      if (s.structureIndex >= 0) { sa += s.w * s.h; sn++; }
      else { ra += s.w * s.h; rn++; if (s.top > rampart) rampart = s.top; }
    }
    final r = rn == 0 ? 1e-6 : ra / rn, t = sn == 0 ? 0.0 : sa / sn;
    var low = 0;
    for (final st in l.structures) { if (st.peakY < rampart - 0.1) low++; }
    print('n=$n len=${l.length.toStringAsFixed(0)} rampart=${rampart.toStringAsFixed(2)} '
      'stone run=${math.sqrt(r).toStringAsFixed(2)} lm=${math.sqrt(t).toStringAsFixed(2)} '
      'x${math.sqrt(t / r).toStringAsFixed(2)}  sunkLandmarks=$low/${l.structures.length}');
  }
}
