import 'package:la_muralla/engine/layout.dart';
void main() {
  final l = WallLayout(6000);
  var rampart = 0.0;
  for (final s in l.slots) { if (s.structureIndex < 0 && s.top > rampart) rampart = s.top; }
  for (final st in l.structures) {
    if (st.peakY < rampart - 0.1) {
      print('${st.type.name} (${st.type.kind.name}) bricks=${st.brickCount} peak=${st.peakY.toStringAsFixed(2)} vs $rampart  firstBrick=${st.firstBrick}');
    }
  }
}
