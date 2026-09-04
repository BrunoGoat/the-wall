import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/epics.dart';
import '../data/pacing.dart';
import 'models.dart';

/// What happened when a brick was placed. Drives the celebration.
class PlaceResult {
  PlaceResult({
    required this.brick,
    required this.repaired,
    required this.repairedFrom,
    this.epicSeeded,
    this.milestoneStarted,
    this.milestoneCompleted,
    this.newStreakRecord = false,
    this.startedNewDay = false,
  });

  final Brick brick;

  /// True when this brick pulled the wall back out of decay.
  final bool repaired;
  final double repairedFrom;

  /// An epic was hidden by this brick (not revealed — hidden).
  final int? epicSeeded;

  final PlanSegment? milestoneStarted;
  final PlanSegment? milestoneCompleted;
  final bool newStreakRecord;
  final bool startedNewDay;
}

/// The whole persistent state of La Muralla.
class WallStore extends ChangeNotifier {
  WallStore();

  static const _key = 'la_muralla_state_v1';

  final List<Habit> habits = [];
  final List<Brick> bricks = [];
  final Map<int, Discovery> discoveries = {};

  bool loaded = false;
  bool _dirty = false;
  SharedPreferences? _prefs;

  late WallPlan plan = WallPlan(0);
  late EpicSeeds seeds = EpicSeeds(0);

  /// Set when the app is showing the "your wall decayed while you were away"
  /// state, so the first brick back can play the repair sweep.
  double integrityAtLaunch = 1.0;

  int get total => bricks.length;

  DateTime? get lastPlacedAt => bricks.isEmpty ? null : bricks.last.placedAt;

  Future<void> load() async {
    // Storage must never be able to hold the app hostage: if the platform
    // channel is slow or unavailable we carry on in memory and try to attach
    // the store later.
    try {
      _prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      _prefs = null;
    }
    final raw = _prefs?.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt save must never brick the app; start clean instead.
        habits.clear();
        bricks.clear();
        discoveries.clear();
      }
    }
    if (habits.isEmpty) _seedStarterHabits();
    _rebuildDerived();
    integrityAtLaunch = integrity;
    loaded = true;
    notifyListeners();
  }

  void _seedStarterHabits() {
    final now = DateTime.now();
    habits.addAll([
      Habit(
        id: 'h1',
        name: 'Moverme',
        glyph: '🏃',
        colorIndex: 0,
        createdAt: now,
      ),
      Habit(
        id: 'h2',
        name: 'Leer',
        glyph: '📖',
        colorIndex: 1,
        createdAt: now,
      ),
      Habit(
        id: 'h3',
        name: 'Agua',
        glyph: '💧',
        colorIndex: 2,
        createdAt: now,
        perDayTarget: 4,
      ),
    ]);
  }

  void _decode(Map<String, dynamic> j) {
    habits
      ..clear()
      ..addAll(((j['habits'] as List?) ?? [])
          .map((e) => Habit.fromJson(e as Map<String, dynamic>)));
    bricks
      ..clear()
      ..addAll(((j['bricks'] as List?) ?? [])
          .map((e) => Brick.fromJson(e as Map<String, dynamic>)));
    bricks.sort((a, b) => a.index.compareTo(b.index));
    discoveries.clear();
    for (final e in (j['found'] as List?) ?? []) {
      final d = Discovery.fromJson(e as Map<String, dynamic>);
      discoveries[d.epicNumber] = d;
    }
  }

  Map<String, dynamic> _encode() => {
        'v': 1,
        'habits': habits.map((h) => h.toJson()).toList(),
        'bricks': bricks.map((b) => b.toJson()).toList(),
        'found': discoveries.values.map((d) => d.toJson()).toList(),
      };

  void _rebuildDerived() {
    plan = WallPlan(total);
    seeds = EpicSeeds(total);
  }

  void _save() {
    _dirty = true;
    // Writes are cheap but not free; coalesce bursts of taps into one write.
    Future.microtask(() {
      if (!_dirty) return;
      _dirty = false;
      _prefs?.setString(_key, jsonEncode(_encode()));
    });
  }

  // ---------------------------------------------------------------- habits

  Habit addHabit(String name, String glyph, int colorIndex, {int target = 1}) {
    final h = Habit(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      glyph: glyph,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
      perDayTarget: target,
    );
    habits.add(h);
    _save();
    notifyListeners();
    return h;
  }

  void updateHabit(Habit h) {
    _save();
    notifyListeners();
  }

  /// Habits are archived, never deleted: the bricks they earned stay in the
  /// wall forever, and a wall that loses stones would be a lie.
  void archiveHabit(Habit h) {
    h.archived = true;
    _save();
    notifyListeners();
  }

  void restoreHabit(Habit h) {
    h.archived = false;
    _save();
    notifyListeners();
  }

  List<Habit> get activeHabits => habits.where((h) => !h.archived).toList();

  Habit? habitById(String id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  // ---------------------------------------------------------------- placing

  /// The one and only way the wall grows. One call, one stone.
  PlaceResult placeBrick(String habitId) {
    final now = DateTime.now();
    final beforeIntegrity = integrity;
    final beforeStreak = streak;
    final beforeBest = bestStreak;
    final hadToday = _countOn(now) > 0;

    final brick = Brick(index: total, habitId: habitId, placedAt: now);
    bricks.add(brick);
    _rebuildDerived();

    final placed = total;
    final segBefore = plan.segmentOf(brick.index);
    PlanSegment? started;
    PlanSegment? completed;
    if (segBefore.isMilestone) {
      if (brick.index == segBefore.firstBrick) started = segBefore;
      if (placed >= segBefore.firstBrick + segBefore.length) {
        completed = segBefore;
      }
    }

    final epic = seeds.epicAt(brick.index);

    _save();
    notifyListeners();

    return PlaceResult(
      brick: brick,
      repaired: beforeIntegrity < 0.999,
      repairedFrom: beforeIntegrity,
      epicSeeded: epic,
      milestoneStarted: started,
      milestoneCompleted: completed,
      newStreakRecord: streak > beforeBest && streak > beforeStreak,
      startedNewDay: !hadToday,
    );
  }

  /// Undo for the fat-finger case. Only the most recent brick, only within a
  /// couple of minutes, and never one that has already revealed an epic.
  bool canUndoLast() {
    if (bricks.isEmpty) return false;
    final last = bricks.last;
    if (DateTime.now().difference(last.placedAt).inMinutes > 2) return false;
    final epic = seeds.epicAt(last.index);
    if (epic != null && discoveries.containsKey(epic)) return false;
    return true;
  }

  void undoLast() {
    if (!canUndoLast()) return;
    bricks.removeLast();
    _rebuildDerived();
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- epics

  bool isFound(int epicNumber) => discoveries.containsKey(epicNumber);

  /// Every epic seeded into the wall so far, whether or not it has been found.
  List<int> get seededEpics {
    final out = <int>[];
    for (final e in seeds.all) {
      if (e.key <= total) out.add(e.value);
    }
    out.sort();
    return out;
  }

  int get hiddenRemaining =>
      seededEpics.where((n) => !isFound(n)).length;

  Epic? discover(int epicNumber) {
    if (epicNumber < 1 || epicNumber > 100) return null;
    if (discoveries.containsKey(epicNumber)) return null;
    discoveries[epicNumber] = Discovery(epicNumber, DateTime.now());
    _save();
    notifyListeners();
    return kEpics[epicNumber - 1];
  }

  // ---------------------------------------------------------------- decay

  double get daysIdle {
    final last = lastPlacedAt;
    if (last == null) return 0;
    final d = DateTime.now().difference(last).inMinutes / 1440.0;
    return d < 0 ? 0 : d;
  }

  double get integrity =>
      bricks.isEmpty ? 1.0 : Pacing.integrityFor(daysIdle);

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
    for (final b in bricks) {
      if (dayKey(b.placedAt) == k) n++;
    }
    return n;
  }

  int todayCount(String habitId) {
    final k = dayKey(DateTime.now());
    var n = 0;
    for (var i = bricks.length - 1; i >= 0; i--) {
      final b = bricks[i];
      if (dayKey(b.placedAt) != k) break;
      if (b.habitId == habitId) n++;
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

  /// Bricks left until something new happens — the next milestone brick or the
  /// next hidden epic, whichever lands first.
  int get bricksToNextEvent {
    var best = 1 << 30;
    final nm = plan.nextMilestone(total);
    if (nm != null && nm.firstBrick >= total) {
      best = nm.firstBrick - total + 1;
    } else if (nm != null) {
      best = 1; // already building it: every brick is progress
    }
    for (var n = 1; n <= 100; n++) {
      final b = Pacing.epicBrick(n);
      if (b > total) {
        final d = b - total;
        if (d < best) best = d;
        break;
      }
    }
    return best;
  }

  String get nextEventLabel {
    final nm = plan.nextMilestone(total);
    if (nm != null && total > nm.firstBrick && total < nm.lastBrick + 1) {
      return 'Levantando ${nm.type!.name}';
    }
    var nextEpicIn = 1 << 30;
    for (var n = 1; n <= 100; n++) {
      final b = Pacing.epicBrick(n);
      if (b > total) {
        nextEpicIn = b - total;
        break;
      }
    }
    final nextMilestoneIn =
        nm == null ? 1 << 30 : (nm.firstBrick - total + 1);
    if (nextEpicIn <= nextMilestoneIn) {
      return nextEpicIn == 1
          ? 'Algo se esconde en el próximo ladrillo'
          : 'Algo se esconde en $nextEpicIn ladrillos';
    }
    final t = nm!.type!;
    return nextMilestoneIn == 1
        ? 'Empieza ${t.name} con el próximo ladrillo'
        : '${t.name} en $nextMilestoneIn ladrillos';
  }

  /// Wall length in metres, at one course-run per stone width.
  double get wallLengthMeters => total * 0.42;

  /// Reset used by the "empezar de nuevo" action in settings.
  Future<void> wipe() async {
    habits.clear();
    bricks.clear();
    discoveries.clear();
    _seedStarterHabits();
    _rebuildDerived();
    await _prefs?.remove(_key);
    integrityAtLaunch = 1.0;
    notifyListeners();
  }

  /// Fast-forwards the wall for development, so the pacing and the look of a
  /// year of use can be inspected without waiting a year. Never reachable in a
  /// normal build: it is driven by a compile-time define that defaults to off.
  void debugFill(int count, {int endedDaysAgo = 0}) {
    final end = DateTime.now().subtract(Duration(days: endedDaysAgo));
    final ids = habits.isEmpty ? ['h1'] : habits.map((h) => h.id).toList();
    for (var i = 0; i < count; i++) {
      bricks.add(Brick(
        index: total,
        habitId: ids[i % ids.length],
        placedAt: end.subtract(Duration(minutes: (count - i) * 137)),
      ));
    }
    _rebuildDerived();
    integrityAtLaunch = integrity;
    notifyListeners();
  }
}
