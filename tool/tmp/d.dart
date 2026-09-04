import 'package:la_muralla/data/milestones.dart';
import 'package:la_muralla/engine/layout.dart';
void main() {
  final l = WallLayout(6000);
  for (final st in l.structures) {
    if (st.type.kind == MilestoneKind.shrine ||
        st.type.kind == MilestoneKind.casemate) {
      final counts = <int, int>{};
      for (final s in l.slots) {
        if (s.structureIndex == st.index) {
          counts[(s.y * 10).round()] = (counts[(s.y * 10).round()] ?? 0) + 1;
        }
      }
      final ys = counts.keys.toList()..sort();
      print('${st.type.kind.name} bricks=${st.brickCount} peak=${st.peakY.toStringAsFixed(2)}');
      print('  y bands: ${ys.map((y) => '${(y/10).toStringAsFixed(1)}:${counts[y]}').join(' ')}');
    }
  }
}
