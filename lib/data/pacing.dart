import 'milestones.dart';

/// The rhythm of the wall.
///
/// This file is the second backbone of the app. Every threshold here is chosen
/// for *real* usage, not for a demo with thousands of bricks:
///
///  * One brick is always one achievement. Never a batch. That rule is not
///    negotiable, so pacing is expressed purely in brick counts.
///  * A person with one or two habits places roughly 30-60 bricks in a month.
///    That first month has to feel alive, so the first milestone starts at
///    brick 12 and the first epic is hidden at brick 4.
///  * A person who keeps it up for a year lands somewhere around 350-1100
///    bricks. By then they must have met many *different* milestones and a
///    large number of epics, without exhausting the 100 unique ones.
///  * The remaining epics stretch out to ~6000 bricks so there is always
///    something left for the very long haul.
class Pacing {
  const Pacing._();

  /// Brick index at which the first milestone begins to be built.
  static const int firstMilestoneAt = 12;

  /// Brick index at which the first epic is hidden in the wall.
  static const int firstEpicAt = 4;

  /// Where milestone number [n] (0-based) starts.
  ///
  /// Gaps widen gently rather than exploding, so milestones keep arriving for
  /// years: 12, 45, 86, 135, 192, 257, ...
  static int milestoneStart(int n) {
    var at = firstMilestoneAt;
    for (var i = 0; i < n; i++) {
      at += _milestoneGap(i);
    }
    return at;
  }

  static int _milestoneGap(int i) => 33 + 8 * i;

  /// Anchor points of the epic curve: (epic ordinal, brick index).
  ///
  /// Interpolated monotonically in between. Reading the curve: ~8 epics inside
  /// the first 45 bricks, ~34 by brick 400, ~56 by brick 1100, all 100 by 6000.
  static const List<List<int>> _epicAnchors = [
    [1, 4],
    [2, 8],
    [3, 13],
    [4, 19],
    [6, 29],
    [8, 43],
    [10, 58],
    [13, 88],
    [16, 124],
    [20, 180],
    [25, 262],
    [30, 356],
    [36, 490],
    [42, 645],
    [50, 890],
    [58, 1180],
    [66, 1530],
    [74, 1960],
    [82, 2520],
    [90, 3300],
    [95, 4300],
    [100, 6000],
  ];

  /// Brick index that hides epic number [n] (1-based, 1..100).
  static int epicBrick(int n) {
    if (n <= 1) return firstEpicAt;
    if (n >= 100) return 6000;
    for (var i = 0; i < _epicAnchors.length - 1; i++) {
      final a = _epicAnchors[i];
      final b = _epicAnchors[i + 1];
      if (n >= a[0] && n <= b[0]) {
        if (b[0] == a[0]) return a[1];
        final t = (n - a[0]) / (b[0] - a[0]);
        return (a[1] + (b[1] - a[1]) * t).round();
      }
    }
    return 6000;
  }

  /// Reverse lookup: how many epics are hidden in a wall of [bricks] bricks.
  static int epicsHiddenBy(int bricks) {
    var count = 0;
    for (var n = 1; n <= 100; n++) {
      if (epicBrick(n) <= bricks) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Grace period before the wall starts to suffer, in days.
  static const double decayGraceDays = 1.6;

  /// Days from the end of the grace period to full ruin.
  static const double decayFullDays = 14.0;

  /// Integrity never drops to zero: the wall weathers, it never disappears.
  static const double minIntegrity = 0.12;

  /// Structural integrity in 0..1 from days since the last brick.
  static double integrityFor(double daysIdle) {
    if (daysIdle <= decayGraceDays) return 1.0;
    final t = (daysIdle - decayGraceDays) / decayFullDays;
    final v = 1.0 - t;
    if (v < minIntegrity) return minIntegrity;
    return v > 1 ? 1 : v;
  }
}

/// The full ordered plan of the wall: alternating stretches of plain rampart
/// and milestone structures, expressed only in brick counts.
class WallPlan {
  WallPlan(this.totalBricks) {
    var index = 0;
    var milestoneNo = 0;
    var cursor = 0;
    // Build enough of the plan to cover the requested brick count plus a little
    // headroom so the "next milestone" preview always has something to show.
    final limit = totalBricks + 260;
    while (cursor < limit) {
      final start = Pacing.milestoneStart(milestoneNo);
      if (start > cursor) {
        final runLength = start - cursor;
        segments.add(PlanSegment.run(
          firstBrick: cursor,
          length: runLength,
          index: index++,
        ));
        cursor = start;
      }
      final type = MilestoneCatalog.typeFor(milestoneNo);
      segments.add(PlanSegment.milestone(
        firstBrick: cursor,
        length: type.brickCost,
        index: index++,
        milestoneNo: milestoneNo,
        type: type,
      ));
      cursor += type.brickCost;
      milestoneNo++;
    }
  }

  final int totalBricks;
  final List<PlanSegment> segments = [];

  /// The segment that contains a given brick index.
  PlanSegment segmentOf(int brick) {
    for (final s in segments) {
      if (brick >= s.firstBrick && brick < s.firstBrick + s.length) return s;
    }
    return segments.last;
  }

  /// The milestone currently under construction, if any.
  PlanSegment? activeMilestone(int placed) {
    for (final s in segments) {
      if (!s.isMilestone) continue;
      if (placed > s.firstBrick && placed < s.firstBrick + s.length) return s;
    }
    return null;
  }

  /// The next milestone that has not been finished yet.
  PlanSegment? nextMilestone(int placed) {
    for (final s in segments) {
      if (!s.isMilestone) continue;
      if (placed < s.firstBrick + s.length) return s;
    }
    return null;
  }

  /// Milestones fully built at [placed] bricks.
  List<PlanSegment> completedMilestones(int placed) => segments
      .where((s) => s.isMilestone && placed >= s.firstBrick + s.length)
      .toList();
}

class PlanSegment {
  PlanSegment.run({
    required this.firstBrick,
    required this.length,
    required this.index,
  })  : isMilestone = false,
        milestoneNo = -1,
        type = null;

  PlanSegment.milestone({
    required this.firstBrick,
    required this.length,
    required this.index,
    required this.milestoneNo,
    required this.type,
  }) : isMilestone = true;

  final int firstBrick;
  final int length;
  final int index;
  final bool isMilestone;
  final int milestoneNo;
  final MilestoneType? type;

  int get lastBrick => firstBrick + length - 1;

  /// 0..1 build progress of this segment at [placed] total bricks.
  double progress(int placed) {
    if (placed <= firstBrick) return 0;
    if (placed >= firstBrick + length) return 1;
    return (placed - firstBrick) / length;
  }
}
