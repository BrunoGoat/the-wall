import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pacing.dart';
import 'models.dart';

/// What happened when a brick was placed. Drives the celebration.
class PlaceResult {
  PlaceResult({
    required this.brick,
    required this.repaired,
    required this.repairedFrom,
    this.milestoneStarted,
    this.milestoneCompleted,
    this.startedNewDay = false,
  });

  final Brick brick;

  /// True when this brick pulled the wall back out of decay.
  final bool repaired;
  final double repairedFrom;

  final PlanSegment? milestoneStarted;
  final PlanSegment? milestoneCompleted;
  final bool startedNewDay;
}

/// The whole persistent state of La Muralla.
class WallStore extends ChangeNotifier {
  WallStore();

  static const _key = 'la_muralla_state_v2';
  static const _legacyKey = 'la_muralla_state_v1';

  final List<Brick> bricks = [];

  bool loaded = false;
  bool _dirty = false;
  SharedPreferences? _prefs;

  late WallPlan plan = WallPlan(0);

  /// Set at launch so the first brick back can play the repair sweep against
  /// the state the person actually walked in on.
  double integrityAtLaunch = 1.0;

  int get total => bricks.length;

  DateTime? get lastPlacedAt => bricks.isEmpty ? null : bricks.last.placedAt;

  Future<void> load() async {
    // Storage must never be able to hold the app hostage: if the platform
    // channel is slow or unavailable we carry on in memory.
    try {
      _prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      _prefs = null;
    }
    final raw = _prefs?.getString(_key) ?? _prefs?.getString(_legacyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt save must never brick the app; start clean instead.
        bricks.clear();
      }
    }
    _rebuildDerived();
    integrityAtLaunch = integrity;
    loaded = true;
    notifyListeners();
  }

  void _decode(Map<String, dynamic> j) {
    bricks
      ..clear()
      ..addAll(((j['bricks'] as List?) ?? [])
          .map((e) => Brick.fromJson(e as Map<String, dynamic>)));
    bricks.sort((a, b) => a.index.compareTo(b.index));
    // Older saves numbered bricks alongside habits that no longer exist; the
    // wall itself only ever cared about the order.
    for (var i = 0; i < bricks.length; i++) {
      if (bricks[i].index != i) {
        bricks[i] = Brick(
          index: i,
          placedAt: bricks[i].placedAt,
          label: bricks[i].label,
        );
      }
    }
  }

  Map<String, dynamic> _encode() => {
        'v': 2,
        'bricks': bricks.map((b) => b.toJson()).toList(),
      };

  void _rebuildDerived() {
    plan = WallPlan(total);
  }

  void _save() {
    _dirty = true;
    // Writes are cheap but not free; coalesce bursts into one write.
    Future.microtask(() {
      if (!_dirty) return;
      _dirty = false;
      _prefs?.setString(_key, jsonEncode(_encode()));
    });
  }

  // ---------------------------------------------------------------- placing

  /// The one and only way the wall grows. One call, one stone.
  PlaceResult placeBrick() {
    final now = DateTime.now();
    final beforeIntegrity = integrity;
    final hadToday = _countOn(now) > 0;

    final brick = Brick(index: total, placedAt: now);
    bricks.add(brick);
    _rebuildDerived();

    final placed = total;
    final seg = plan.segmentOf(brick.index);
    PlanSegment? started;
    PlanSegment? completed;
    if (seg.isMilestone) {
      if (brick.index == seg.firstBrick) started = seg;
      if (placed >= seg.firstBrick + seg.length) completed = seg;
    }

    _save();
    notifyListeners();

    return PlaceResult(
      brick: brick,
      repaired: beforeIntegrity < 0.999,
      repairedFrom: beforeIntegrity,
      milestoneStarted: started,
      milestoneCompleted: completed,
      startedNewDay: !hadToday,
    );
  }

  /// Writes (or clears) the note on a stone. Always optional.
  void setLabel(int index, String? text) {
    if (index < 0 || index >= bricks.length) return;
    bricks[index] = bricks[index].withLabel(text);
    _save();
    notifyListeners();
  }

  Brick? brickAt(int index) =>
      index >= 0 && index < bricks.length ? bricks[index] : null;

  List<Brick> get labelled =>
      bricks.where((b) => b.hasLabel).toList().reversed.toList();

  /// Undo for the fat-finger case: only the most recent stone, only for a
  /// couple of minutes.
  bool canUndoLast() {
    if (bricks.isEmpty) return false;
    return DateTime.now().difference(bricks.last.placedAt).inMinutes < 2;
  }

  void undoLast() {
    if (!canUndoLast()) return;
    bricks.removeLast();
    _rebuildDerived();
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- decay

  double get daysIdle {
    final last = lastPlacedAt;
    if (last == null) return 0;
    final d = DateTime.now().difference(last).inMinutes / 1440.0;
    return d < 0 ? 0 : d;
  }

  double get integrity => bricks.isEmpty ? 1.0 : Pacing.integrityFor(daysIdle);

  bool get isDecaying => integrity < 0.995;

  // ---------------------------------------------------------------- streaks

  int get streak {
    if (bricks.isEmpty) return 0;
    final days = <DateTime>{};
    for (final b in bricks) {
      days.add(dayStart(b.placedAt));
    }
    var cursor = dayStart(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get bestStreak {
    if (bricks.isEmpty) return 0;
    final days = <DateTime>{};
    for (final b in bricks) {
      days.add(dayStart(b.placedAt));
    }
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }
    return best;
  }

  int _countOn(DateTime when) {
    final k = dayKey(when);
    var n = 0;
    for (var i = bricks.length - 1; i >= 0; i--) {
      if (dayKey(bricks[i].placedAt) != k) break;
      n++;
    }
    return n;
  }

  int get todayTotal => _countOn(DateTime.now());

  /// Last [days] days of activity, oldest first, for the activity strip.
  List<DayTally> recentDays(int days) {
    final counts = <int, int>{};
    for (final b in bricks) {
      counts.update(dayKey(b.placedAt), (v) => v + 1, ifAbsent: () => 1);
    }
    final today = dayStart(DateTime.now());
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return DayTally(d, counts[dayKey(d)] ?? 0);
    });
  }

  // ---------------------------------------------------------------- progress

  PlanSegment? get activeMilestone => plan.activeMilestone(total);
  PlanSegment? get nextMilestone => plan.nextMilestone(total);
  List<PlanSegment> get builtMilestones => plan.completedMilestones(total);

  String get nextEventLabel {
    final nm = plan.nextMilestone(total);
    if (nm == null) return 'La muralla sigue';
    if (total > nm.firstBrick) {
      final left = nm.firstBrick + nm.length - total;
      return left == 1
          ? 'Un ladrillo más y ${nm.type!.name} queda en pie'
          : 'Levantando ${nm.type!.name} · faltan $left';
    }
    final away = nm.firstBrick - total + 1;
    return away == 1
        ? 'Empieza ${nm.type!.name} con el próximo ladrillo'
        : '${nm.type!.name} en $away ladrillos';
  }

  /// Wall length in metres, at roughly one stone-width per stone.
  double get wallLengthMeters => total * 0.42;

  Future<void> wipe() async {
    bricks.clear();
    _rebuildDerived();
    await _prefs?.remove(_key);
    await _prefs?.remove(_legacyKey);
    integrityAtLaunch = 1.0;
    notifyListeners();
  }

  /// Fast-forwards the wall for development, so the pacing and the look of a
  /// year of use can be inspected without waiting a year. Driven by a
  /// compile-time define that defaults to off.
  void debugFill(int count, {int endedDaysAgo = 0}) {
    final end = DateTime.now().subtract(Duration(days: endedDaysAgo));
    for (var i = 0; i < count; i++) {
      bricks.add(Brick(
        index: total,
        placedAt: end.subtract(Duration(minutes: (count - i) * 137)),
      ));
    }
    _rebuildDerived();
    integrityAtLaunch = integrity;
    notifyListeners();
  }
}
