import '../lib/engine/layout.dart';
import '../lib/data/pacing.dart';

void main() {
  print('--- epic pacing ---');
  for (final n in [1, 2, 3, 5, 8, 10, 15, 20, 30, 40, 50, 70, 90, 100]) {
    print('epic $n -> brick ${Pacing.epicBrick(n)}');
  }
  for (final b in [30, 45, 60, 90, 200, 365, 700, 1100]) {
    print('by $b bricks: ${Pacing.epicsHiddenBy(b)} epics hidden');
  }
  print('--- milestones ---');
  final plan = WallPlan(1200);
  for (final s in plan.segments.where((s) => s.isMilestone).take(16)) {
    print('#${s.milestoneNo} ${s.type!.name} bricks ${s.firstBrick}..${s.lastBrick} (${s.length})');
  }
  print('--- layout ---');
  for (final n in [1, 5, 12, 30, 60, 120, 365, 1100]) {
    final sw = Stopwatch()..start();
    final l = WallLayout(n);
    sw.stop();
    var maxY = 0.0;
    for (final s in l.slots) {
      if (s.top > maxY) maxY = s.top;
    }
    print('n=$n slots=${l.slots.length} len=${l.length.toStringAsFixed(2)} '
        'h=${maxY.toStringAsFixed(2)} structs=${l.structures.length} '
        'build=${sw.elapsedMilliseconds}ms');
  }
  final l = WallLayout(60);
  print('--- first 14 slots ---');
  for (final s in l.slots.take(14)) {
    print('  #${s.brickIndex} c${s.course} x=${s.x.toStringAsFixed(2)} '
        'y=${s.y.toStringAsFixed(2)} w=${s.w.toStringAsFixed(2)} ${s.kind.name}');
  }
}
