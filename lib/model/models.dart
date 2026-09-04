import '../data/epics.dart';
import '../data/pacing.dart';

/// A habit. Completing it once places exactly one brick — never a batch.
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.glyph,
    required this.colorIndex,
    required this.createdAt,
    this.perDayTarget = 1,
    this.archived = false,
  });

  final String id;
  String name;
  String glyph;
  int colorIndex;
  final DateTime createdAt;
  int perDayTarget;
  bool archived;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'glyph': glyph,
        'color': colorIndex,
        'created': createdAt.millisecondsSinceEpoch,
        'target': perDayTarget,
        'archived': archived,
      };

  static Habit fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        glyph: (j['glyph'] as String?) ?? '◆',
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['created'] as num?)?.toInt() ?? 0),
        perDayTarget: (j['target'] as num?)?.toInt() ?? 1,
        archived: (j['archived'] as bool?) ?? false,
      );
}

/// One achievement, one stone. The index is its permanent position in the wall.
class Brick {
  const Brick({
    required this.index,
    required this.habitId,
    required this.placedAt,
  });

  final int index;
  final String habitId;
  final DateTime placedAt;

  Map<String, dynamic> toJson() => {
        'i': index,
        'h': habitId,
        't': placedAt.millisecondsSinceEpoch,
      };

  static Brick fromJson(Map<String, dynamic> j) => Brick(
        index: (j['i'] as num).toInt(),
        habitId: j['h'] as String,
        placedAt: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );
}

/// A found epic. Epics are seeded by pacing but only become discoveries when
/// the person actually spots the anomaly in the wall and taps it.
class Discovery {
  const Discovery(this.epicNumber, this.foundAt);
  final int epicNumber;
  final DateTime foundAt;

  Epic get epic => kEpics[epicNumber - 1];

  Map<String, dynamic> toJson() =>
      {'n': epicNumber, 't': foundAt.millisecondsSinceEpoch};

  static Discovery fromJson(Map<String, dynamic> j) => Discovery(
        (j['n'] as num).toInt(),
        DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );
}

/// Which brick hides which epic, derived from pacing rather than stored, so the
/// schedule stays identical no matter how the save file has aged.
class EpicSeeds {
  EpicSeeds(int totalBricks) {
    for (var n = 1; n <= 100; n++) {
      final b = Pacing.epicBrick(n);
      if (b > totalBricks + 400) break;
      _byBrick[b] = n;
    }
  }

  final Map<int, int> _byBrick = {};

  /// The epic hidden on [brickIndex], if any. Brick indices are 0-based while
  /// pacing counts bricks placed, so brick 0 is "brick 1" of the plan.
  int? epicAt(int brickIndex) => _byBrick[brickIndex + 1];

  Iterable<MapEntry<int, int>> get all => _byBrick.entries;
}

/// A single day in the person's history, used by the small activity strip.
class DayTally {
  DayTally(this.day, this.count);
  final DateTime day;
  final int count;
}

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
