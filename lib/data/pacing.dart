import 'milestones.dart';

/// The rhythm of the wall.
///
/// This file is the second backbone of the app. Every threshold here is chosen
/// for *real* usage, not for a demo with thousands of bricks:
///
///  * One brick is always one achievement. Never a batch. That rule is not
///    negotiable, so pacing is expressed purely in brick counts.
///  * Someone logging one or two things a day places roughly 30-60 bricks in a
///    month. That first month has to feel alive, so the first landmark starts
///    at brick 12 and is finished well inside the month.
///  * Someone who keeps it up for a year lands somewhere around 350-1100
///    bricks. By then they must have met many *different* landmarks.
///  * Landmarks keep arriving for years afterwards without ever bunching up.
class Pacing {
  const Pacing._();

  /// Brick index at which the first milestone begins to be built.
  static const int firstMilestoneAt = 12;

  /// Where milestone number [n] (0-based) starts.
  ///
  /// Gaps widen gently rather than exploding, so landmarks keep arriving for
  /// years: 12, 45, 86, 135, 192, 257, ...
  static int milestoneStart(int n) {
    var at = firstMilestoneAt;
    for (var i = 0; i < n; i++) {
      at += _milestoneGap(i);
    }
    return at;
  }

  static int _milestoneGap(int i) => 33 + 8 * i;

  /// How much taller the wall is at brick [index] than it was at the start.
  ///
  /// Set by the renderer's tier ladder; kept here as a plain table so the plan
  /// does not depend on the geometry engine and stays trivially inspectable.
  static double wallGrowthAt(int index) {
    const thresholds = [100, 350, 900];
    const growth = [1.0, 1.93, 2.64, 3.13];
    var k = 0;
    for (final t in thresholds) {
      if (index >= t) k++;
    }
    return growth[k];
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
      // Priced for the wall it will stand in, which depends only on where it
      // starts — a fixed function of its number. The plan is therefore the same
      // on the first day as on the thousandth.
      final type = MilestoneCatalog.typeFor(
        milestoneNo,
        wallGrowth: Pacing.wallGrowthAt(cursor),
      );
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
