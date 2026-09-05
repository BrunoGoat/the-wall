import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pacing.dart';
import '../data/character.dart';
import '../engine/town.dart';
import 'habit.dart';
import 'piece.dart';

/// What happened when a piece was laid. Drives the celebration.
class PlaceResult {
  PlaceResult({
    required this.piece,
    required this.relit,
    required this.relitFrom,
    this.startedNewDay = false,
  });

  final Piece piece;

  /// True when this piece brought a town's lights back on.
  final bool relit;
  final double relitFrom;

  final bool startedNewDay;
}

/// Everything the app remembers: the habits, and the towns they have built.
class Store extends ChangeNotifier {
  Store();

  static const _key = 'pueblo_state_v1';

  /// What the app was called when it was a wall. Read once, then left alone.
  static const _wallKey = 'la_muralla_state_v2';
  static const _wallLegacyKey = 'la_muralla_state_v1';

  final List<Habit> habits = [];
  int active = 0;

  bool loaded = false;
  bool _dirty = false;
  SharedPreferences? _prefs;

  /// Set at launch so the first piece back can play the relighting against the
  /// state the person actually walked in on.
  double integrityAtLaunch = 1.0;

  Habit get habit => habits[active.clamp(0, habits.length - 1)];

  /// What kind of place the town in front of you is.
  TownCharacter get character => TownCharacter.forSlot(habit.slot);

  /// Its plan: which landmark comes next, and what everything costs.
  TownPlan get plan => TownPlan.of(character);

  int get total => habit.total;

  /// A pretend count, for looking at what the town becomes without waiting
  /// years for it. The real pieces are untouched.
  int? preview;
  bool get isPreviewing => preview != null;
  int get shownTotal => preview ?? habit.total;

  void setPreview(int? count) {
    preview = count;
    notifyListeners();
  }

  DateTime? get lastPlacedAt => habit.lastPlacedAt;

  // ------------------------------------------------------------------ habits

  bool get canAddHabit => habits.length < Habit.maxSlots;

  /// The next free plot in the valley. Slots are never reused while their
  /// habit exists, so nobody's town ever moves.
  int _freeSlot() {
    final taken = habits.map((h) => h.slot).toSet();
    for (var i = 0; i < Habit.maxSlots; i++) {
      if (!taken.contains(i)) return i;
    }
    return habits.length;
  }

  Habit addHabit(String name, String symbol) {
    final h = Habit(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Sin nombre' : name.trim(),
      symbol: symbol.isEmpty ? '🏠' : symbol,
      slot: _freeSlot(),
      createdAt: DateTime.now(),
    );
    habits.add(h);
    active = habits.length - 1;
    _save();
    notifyListeners();
    return h;
  }

  void renameHabit(int index, {String? name, String? symbol}) {
    if (index < 0 || index >= habits.length) return;
    final h = habits[index];
    if (name != null && name.trim().isNotEmpty) h.name = name.trim();
    if (symbol != null && symbol.isNotEmpty) h.symbol = symbol;
    _save();
    notifyListeners();
  }

  /// Removing a habit removes its town. There is no way back, which is why the
  /// only caller asks twice.
  void removeHabit(int index) {
    if (index < 0 || index >= habits.length || habits.length <= 1) return;
    habits.removeAt(index);
    if (active >= habits.length) active = habits.length - 1;
    _save();
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= habits.length || index == active) return;
    active = index;
    preview = null;
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------- state

  Future<void> load() async {
    // Storage must never be able to hold the app hostage: if the platform
    // channel is slow or unavailable we carry on in memory.
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
        habits.clear();
      }
    } else {
      _adoptTheWall();
    }
    if (habits.isEmpty) {
      habits.add(Habit(
        id: 'h0',
        name: 'Mi hábito',
        symbol: '🏠',
        slot: 0,
        createdAt: DateTime.now(),
      ));
    }
    active = active.clamp(0, habits.length - 1);
    integrityAtLaunch = integrity;
    loaded = true;
    notifyListeners();
  }

  /// Everything laid back when this was one wall becomes the first habit's
  /// town. Nobody loses a year of work to a change of mind about the app.
  void _adoptTheWall() {
    final raw = _prefs?.getString(_wallKey) ?? _prefs?.getString(_wallLegacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list = ((j['bricks'] as List?) ?? [])
          .map((e) => Piece.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (var i = 0; i < list.length; i++) {
        list[i] =
            Piece(index: i, placedAt: list[i].placedAt, label: list[i].label);
      }
      if (list.isEmpty) return;
      habits.add(Habit(
        id: 'h0',
        name: 'Mi hábito',
        symbol: '🏠',
        slot: 0,
        createdAt: list.first.placedAt,
        pieces: list,
      ));
    } catch (_) {
      // A save from a version that no longer exists is not worth crashing for.
    }
  }

  void _decode(Map<String, dynamic> j) {
    habits
      ..clear()
      ..addAll(((j['h'] as List?) ?? [])
          .map((e) => Habit.fromJson(e as Map<String, dynamic>)));
    active = (j['a'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic> _encode() => {
        'v': 1,
        'a': active,
        'h': habits.map((h) => h.toJson()).toList(),
      };

  void _save() {
    _dirty = true;
    // Writes are cheap but not free; coalesce bursts into one write.
    Future.microtask(() {
      if (!_dirty) return;
      _dirty = false;
      _prefs?.setString(_key, jsonEncode(_encode()));
    });
  }

  // ----------------------------------------------------------------- placing

  /// The one and only way a town grows. One call, one piece.
  PlaceResult placePiece() {
    final now = DateTime.now();
    final before = integrity;
    final hadToday = _countOn(now) > 0;

    final piece = Piece(index: habit.total, placedAt: now);
    habit.pieces.add(piece);

    _save();
    notifyListeners();

    return PlaceResult(
      piece: piece,
      relit: before < 0.999,
      relitFrom: before,
      startedNewDay: !hadToday,
    );
  }

  /// Writes (or clears) the note on a piece. Always optional.
  void setLabel(int index, String? text) {
    final list = habit.pieces;
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].withLabel(text);
    _save();
    notifyListeners();
  }

  Piece? pieceAt(int index) {
    final list = habit.pieces;
    return index >= 0 && index < list.length ? list[index] : null;
  }

  List<Piece> get pieces => habit.pieces;

  List<Piece> get labelled =>
      habit.pieces.where((p) => p.hasLabel).toList().reversed.toList();

  /// Undo for the fat-finger case: only the most recent piece, only for a
  /// couple of minutes.
  bool canUndoLast() {
    if (habit.pieces.isEmpty) return false;
    return DateTime.now().difference(habit.pieces.last.placedAt).inMinutes < 2;
  }

  void undoLast() {
    if (!canUndoLast()) return;
    habit.pieces.removeLast();
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------- decay

  static double daysIdleOf(Habit h) {
    final last = h.lastPlacedAt;
    if (last == null) return 0;
    final d = DateTime.now().difference(last).inMinutes / 1440.0;
    return d < 0 ? 0 : d;
  }

  static double integrityOf(Habit h) =>
      h.pieces.isEmpty ? 1.0 : Pacing.integrityFor(daysIdleOf(h));

  double get daysIdle => daysIdleOf(habit);
  double get integrity => integrityOf(habit);
  bool get isDecaying => integrity < 0.995;

  // ----------------------------------------------------------------- streaks

  int get streak => streakOf(habit);
  int get bestStreak => _bestStreakOf(habit);

  static int streakOf(Habit h) {
    if (h.pieces.isEmpty) return 0;
    final days = <DateTime>{for (final p in h.pieces) dayStart(p.placedAt)};
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

  static int _bestStreakOf(Habit h) {
    if (h.pieces.isEmpty) return 0;
    final days = <DateTime>{for (final p in h.pieces) dayStart(p.placedAt)}
        .toList()
      ..sort();
    var best = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      run = gap == 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  int _countOn(DateTime when) {
    final k = dayKey(when);
    var n = 0;
    for (final p in habit.pieces) {
      if (dayKey(p.placedAt) == k) n++;
    }
    return n;
  }

  List<DayTally> lastDays(int days) {
    final counts = <int, int>{};
    for (final p in habit.pieces) {
      counts.update(dayKey(p.placedAt), (v) => v + 1, ifAbsent: () => 1);
    }
    final today = dayStart(DateTime.now());
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return DayTally(d, counts[dayKey(d)] ?? 0);
    });
  }

  /// What the town is putting up right now.
  String get nextEventLabel {
    final work = plan.underway(shownTotal);
    if (work == null) return 'El pueblo sigue creciendo';
    final left = work.$2;
    return left == 1
        ? 'Una pieza más y ${work.$1} queda en pie'
        : '${work.$1} · faltan $left';
  }

  Future<void> wipe() async {
    habits.clear();
    habits.add(Habit(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      name: 'Mi hábito',
      symbol: '🏠',
      slot: 0,
      createdAt: DateTime.now(),
    ));
    active = 0;
    await _prefs?.remove(_key);
    integrityAtLaunch = 1.0;
    notifyListeners();
  }

  /// Fast-forwards a town for development, so a year of use can be looked at
  /// without waiting a year. Driven by a compile-time define, off by default.
  static const List<String> _debugLabels = [
    'Leí', 'Corrí', 'Estudié', 'Escribí', 'No fumé', 'Salí a caminar',
    'Llamé a mamá', 'Ordené el taller', 'Toqué la guitarra', 'Nadé',
  ];

  void debugFill(int count, {int endedDaysAgo = 0, int? into}) {
    final h = habits[(into ?? active).clamp(0, habits.length - 1)];
    final end = DateTime.now().subtract(Duration(days: endedDaysAgo));
    for (var i = 0; i < count; i++) {
      h.pieces.add(Piece(
        index: h.total,
        placedAt: end.subtract(Duration(minutes: (count - i) * 137)),
        label: i % 9 == 3 ? _debugLabels[(i ~/ 9) % _debugLabels.length] : null,
      ));
    }
    integrityAtLaunch = integrity;
    notifyListeners();
  }
}
