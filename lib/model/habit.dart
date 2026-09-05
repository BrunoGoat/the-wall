import 'dart:math' as math;

import 'piece.dart';

/// One habit, and the town it is building.
///
/// The app's whole premise is that one achievement is one piece. This is the
/// thing that says *which* achievement: a name you wrote, a symbol you chose,
/// and a plot of the valley that is only ever this habit's. Two habits are two
/// towns you can see at the same time, which is the only honest way to answer
/// "how am I doing with reading versus running".
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.symbol,
    required this.slot,
    required this.createdAt,
    List<Piece>? pieces,
  }) : pieces = pieces ?? [];

  /// Never reused and never changed: it is what a saved town is filed under.
  final String id;

  String name;

  /// One character, usually an emoji. Flies on the town's banners and stands
  /// over it in the wide view.
  String symbol;

  /// Where in the valley this habit's town stands. Assigned when the habit is
  /// made and kept for good, so adding a fifth habit never moves the first
  /// four — the same promise the pieces themselves get.
  final int slot;

  final DateTime createdAt;

  final List<Piece> pieces;

  int get total => pieces.length;

  DateTime? get lastPlacedAt => pieces.isEmpty ? null : pieces.last.placedAt;

  /// The most towns the valley holds. Six is as many as can be told apart at a
  /// glance, and a person with seven habits has a different problem.
  static const int maxSlots = 6;

  /// Where a slot's town stands. Slot zero is the middle of the valley — the
  /// first habit is the capital — and the rest ring it, far enough apart that
  /// two towns of thirty thousand achievements still would not touch.
  static (double, double) centreOf(int slot) {
    if (slot <= 0) return (0.0, 0.0);
    // Close enough that the whole valley fits in one frame and the towns can
    // be compared, far enough that two towns of thirty thousand achievements
    // still have meadow between them.
    const ring = 78.0;
    final k = (slot - 1) % (maxSlots - 1);
    final a = -math.pi / 2 + k * 2 * math.pi / (maxSlots - 1);
    return (math.cos(a) * ring, math.sin(a) * ring);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        's': symbol,
        'slot': slot,
        'c': createdAt.millisecondsSinceEpoch,
        'p': pieces.map((p) => p.toJson()).toList(),
      };

  static Habit fromJson(Map<String, dynamic> j) {
    final list = ((j['p'] as List?) ?? [])
        .map((e) => Piece.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // A town is built in order and nothing else about a piece matters, so a
    // save with gaps in it is renumbered rather than refused.
    for (var i = 0; i < list.length; i++) {
      if (list[i].index != i) {
        list[i] = Piece(
            index: i, placedAt: list[i].placedAt, label: list[i].label);
      }
    }
    return Habit(
      id: j['id'] as String? ?? 'h0',
      name: j['n'] as String? ?? 'Mi hábito',
      symbol: j['s'] as String? ?? '🏠',
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (j['c'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      pieces: list,
    );
  }
}
