/// One achievement, one stone. The index is its permanent position in the wall.
class Brick {
  const Brick({
    required this.index,
    required this.placedAt,
    this.label,
  });

  final int index;
  final DateTime placedAt;

  /// What this one was for, if the person cared to say. Always optional: the
  /// stone counts either way.
  final String? label;

  bool get hasLabel => label != null && label!.trim().isNotEmpty;

  Brick withLabel(String? text) {
    final t = text?.trim();
    return Brick(
      index: index,
      placedAt: placedAt,
      label: t == null || t.isEmpty ? null : t,
    );
  }

  Map<String, dynamic> toJson() => {
        'i': index,
        't': placedAt.millisecondsSinceEpoch,
        if (hasLabel) 'l': label,
      };

  static Brick fromJson(Map<String, dynamic> j) => Brick(
        index: (j['i'] as num).toInt(),
        placedAt: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        label: j['l'] as String?,
      );
}

/// A single day in the person's history, used by the small activity strip.
class DayTally {
  DayTally(this.day, this.count);
  final DateTime day;
  final int count;
}

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
