import 'dart:math' as math;

import 'habit.dart';
import 'piece.dart';

/// What kind of thing a notice is, so the board can put them in a sensible
/// order and give each one its own mark.
enum NoticeKind {
  /// What the town will have finished, and when.
  ahead,

  /// The hour of the day it nearly always happens at.
  hour,

  /// The day of the week that stands out, high or low.
  week,

  /// What one blank day does to the next.
  relapse,

  /// How long it takes to come back after a gap.
  comeback,

  /// Two habits that go together, or never do.
  pair,

  /// How long this has been going on.
  life,
}

/// One thing the town noticed.
///
/// Every notice carries the numbers it rests on, and none is ever made without
/// enough behind it to be true. A claim with no evidence under it is a slogan,
/// and a town that flatters you is worth nothing: the whole point of watching
/// it is that it does not.
class Notice {
  const Notice(this.kind, this.said, this.because);
  final NoticeKind kind;

  /// One plain sentence.
  final String said;

  /// The counts it came from.
  final String because;
}

/// Everything worth pinning up about one habit, in the order it should be read.
///
/// [others] are the town's neighbours in the valley, for the notices that only
/// exist when there is more than one habit. [underway] and [left] are what the
/// town is building right now, which is what turns a rate into a date.
List<Notice> noticesFor(
  Habit h, {
  List<Habit> others = const [],
  String? underway,
  int left = 0,
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final out = <Notice>[];
  void add(Notice? n) {
    if (n != null) out.add(n);
  }

  // What is coming first, then who you are on a normal week, then the two
  // hard ones — and those two in that order, because "un fallo se lleva al
  // siguiente" read on its own is worth much less than read next to "y volvés
  // a los dos días".
  add(ahead(h, underway, left, now));
  add(peakHour(h));
  add(standoutDay(h, now));
  add(pairing(h, others, now));
  add(relapse(h, now));
  add(comeback(h));
  add(lifetime(h, now));
  return out;
}

// ----------------------------------------------------------------- the days

/// Every day this habit was touched at all, in order and without repeats.
List<DateTime> daysOf(Habit h) {
  final set = <int, DateTime>{};
  for (final p in h.pieces) {
    final d = dayStart(p.placedAt);
    set[dayKey(d)] = d;
  }
  final list = set.values.toList()..sort();
  return list;
}

/// How far back a question about how you are doing is worth asking.
///
/// Half a year. A habit somebody kept beautifully in 2023 and dropped in 2024
/// would otherwise go on being described by 2023 for ever, and the board is
/// meant to say what is true of you now.
const int _lookBack = 180;

/// One entry per calendar day over that window: true where a piece was laid.
/// This is the grid every question about consistency is really asking about.
List<bool> _grid(Habit h, DateTime now) {
  final days = daysOf(h);
  if (days.isEmpty) return const [];
  final today = dayStart(now);
  final edge = today.subtract(const Duration(days: _lookBack));
  final first = days.first.isAfter(edge) ? days.first : edge;
  final span = today.difference(first).inDays;
  if (span < 0) return const [];
  final on = <int>{for (final d in days) dayKey(d)};
  return [
    for (var i = 0; i <= span; i++)
      on.contains(dayKey(first.add(Duration(days: i)))),
  ];
}

// -------------------------------------------------------------- the notices

/// A rate turned into a date: what the town is building, and when it lands.
///
/// The one notice that looks forward, and the only one that has any business
/// doing so, because it says exactly what it is doing — carrying on at the
/// pace of the last month — instead of pretending to know the future.
Notice? ahead(Habit h, String? what, int left, DateTime now) {
  if (what == null || left <= 0) return null;
  final since = now.subtract(const Duration(days: 30));
  var recent = 0;
  for (final p in h.pieces) {
    if (p.placedAt.isAfter(since)) recent++;
  }
  if (recent < 8) return null;
  final perDay = recent / 30.0;
  final days = (left / perDay).ceil();
  if (days > 400) return null; // too far off to mean anything
  final when = dayStart(now).add(Duration(days: days));
  return Notice(
    NoticeKind.ahead,
    days <= 1
        ? 'A este ritmo, $what queda en pie mañana.'
        : 'A este ritmo, $what queda en pie el ${_date(when)}'
              '${when.year == now.year ? '' : ' de ${when.year}'}.',
    'Le faltan $left ${_pieces(left)}, y llevás $recent en los últimos 30 días.',
  );
}

/// What one blank day does to the next.
///
/// The most useful thing in here, because it turns "un día no pasa nada" into
/// a number that is yours: for most people a miss really does drag the next
/// day with it, and seeing by how much is worth more than being told not to
/// miss.
Notice? relapse(Habit h, DateTime now) {
  final grid = _grid(h, now);
  if (grid.length < 30) return null;
  var misses = 0, after = 0, afterMiss = 0;
  for (var i = 0; i < grid.length; i++) {
    if (!grid[i]) misses++;
    if (i == 0 || grid[i - 1]) continue;
    afterMiss++;
    if (!grid[i]) after++;
  }
  if (misses < 6 || afterMiss < 5) return null;
  final base = misses / grid.length;
  final then = after / afterMiss;
  if ((then - base).abs() < 0.12) return null;
  return then > base
      ? Notice(
          NoticeKind.relapse,
          'Un día en blanco se lleva al siguiente.',
          'Después de faltar un día, faltás el ${_pct(then)} de las veces. '
              'Un día cualquiera, el ${_pct(base)}.',
        )
      : Notice(
          NoticeKind.relapse,
          'Un fallo no te tumba: volvés antes de lo normal.',
          'Después de faltar un día, faltás el ${_pct(then)} de las veces. '
              'Un día cualquiera, el ${_pct(base)}.',
        );
}

/// The stretch of the day it nearly always happens in.
///
/// The window is grown, not fixed: somebody who always lays a piece at ten
/// past eight is told "a las 8", and somebody who does it any time between
/// breakfast and lunch is told the whole stretch. A fixed three-hour band
/// would flatten both into the same sentence and be wrong about each.
Notice? peakHour(Habit h) {
  if (h.pieces.length < 20) return null;
  final byHour = List<int>.filled(24, 0);
  for (final p in h.pieces) {
    byHour[p.placedAt.hour]++;
  }
  final n = h.pieces.length;
  for (var width = 1; width <= 5; width++) {
    var at = 0, best = -1;
    for (var s = 0; s < 24; s++) {
      var sum = 0;
      for (var k = 0; k < width; k++) {
        sum += byHour[(s + k) % 24];
      }
      if (sum > best) {
        best = sum;
        at = s;
      }
    }
    // "Casi siempre" has to mean casi siempre: seven in ten inside a fifth of
    // the day is an hour somebody keeps, and anything looser is a sentence
    // that hides a third of the truth to sound tidier.
    if (best / n < 0.7) continue;
    final end = (at + width) % 24;
    return Notice(
      NoticeKind.hour,
      width == 1
          ? 'Casi siempre a las $at${_partOfDay(at)}.'
          : 'Casi siempre entre las $at y las $end${_partOfDay(at)}.',
      'Ahí caen el ${_pct(best / n)} de tus piezas.',
    );
  }
  return null;
}

/// The day of the week that stands out, whichever way it stands out.
///
/// Measured against how many of that weekday have actually gone by since the
/// first piece, not against the other days' totals: eight Mondays and five
/// Sundays are not the same denominator.
Notice? standoutDay(Habit h, DateTime now) {
  final all = daysOf(h);
  if (all.isEmpty) return null;
  final today = dayStart(now);
  final edge = today.subtract(const Duration(days: _lookBack));
  final first = all.first.isAfter(edge) ? all.first : edge;
  final days = [
    for (final d in all)
      if (!d.isBefore(first)) d,
  ];
  if (days.isEmpty) return null;
  final span = today.difference(first).inDays;
  if (span < 27) return null;
  final seen = List<int>.filled(8, 0);
  for (var i = 0; i <= span; i++) {
    seen[first.add(Duration(days: i)).weekday]++;
  }
  final hit = List<int>.filled(8, 0);
  for (final d in days) {
    hit[d.weekday]++;
  }
  for (var w = 1; w <= 7; w++) {
    if (seen[w] < 4) return null;
  }
  var high = 1, low = 1;
  for (var w = 2; w <= 7; w++) {
    if (hit[w] / seen[w] > hit[high] / seen[high]) high = w;
    if (hit[w] / seen[w] < hit[low] / seen[low]) low = w;
  }
  double rest(int w) {
    var a = 0, b = 0;
    for (var k = 1; k <= 7; k++) {
      if (k == w) continue;
      a += hit[k];
      b += seen[k];
    }
    return b == 0 ? 0 : a / b;
  }

  final upGap = hit[high] / seen[high] - rest(high);
  final downGap = rest(low) - hit[low] / seen[low];
  if (math.max(upGap, downGap) < 0.18) return null;
  if (upGap >= downGap) {
    return Notice(
      NoticeKind.week,
      'Los ${_weekday(high)} son tu día fuerte.',
      'Cumplís el ${_pct(hit[high] / seen[high])} de los ${_weekday(high)}, '
          'contra el ${_pct(rest(high))} del resto de la semana.',
    );
  }
  return Notice(
    NoticeKind.week,
    'Los ${_weekday(low)} casi nunca.',
    'Cumplís el ${_pct(hit[low] / seen[low])} de los ${_weekday(low)}, '
        'contra el ${_pct(rest(low))} del resto de la semana.',
  );
}

/// How long a gap usually lasts, and the worst one ever climbed out of.
Notice? comeback(Habit h) {
  final days = daysOf(h);
  if (days.length < 6) return null;
  final gaps = <int>[];
  for (var i = 1; i < days.length; i++) {
    final missed = days[i].difference(days[i - 1]).inDays - 1;
    if (missed > 0) gaps.add(missed);
  }
  if (gaps.length < 4) return null;
  gaps.sort();
  final mid = gaps[gaps.length ~/ 2];
  final worst = gaps.last;
  return Notice(
    NoticeKind.comeback,
    mid == 1
        ? 'Cuando faltás, volvés al día siguiente.'
        : 'Cuando faltás, solés volver a los $mid días.',
    worst == 1
        ? 'Nunca has estado más de un día fuera.'
        : 'El hueco más largo que remontaste fue de $worst días.',
  );
}

/// Two habits that turn up together, or never do.
///
/// Stated as the two odds side by side rather than as one number, because
/// "el 78% de las veces, contra el 41%" is a thing anybody can check against
/// their own week, and a correlation coefficient is not.
Notice? pairing(Habit h, List<Habit> others, DateTime now) {
  Notice? best;
  var bestGap = 0.20;
  for (final o in others) {
    if (o.id == h.id) continue;
    for (final pair in [(h, o), (o, h)]) {
      final n = _pairing(pair.$1, pair.$2, now);
      if (n == null) continue;
      if (n.$2 > bestGap) {
        bestGap = n.$2;
        best = n.$1;
      }
    }
  }
  return best;
}

(Notice, double)? _pairing(Habit a, Habit b, DateTime now) {
  final da = daysOf(a), db = daysOf(b);
  if (da.isEmpty || db.isEmpty) return null;
  final from = da.first.isAfter(db.first) ? da.first : db.first;
  final today = dayStart(now);
  final span = today.difference(from).inDays;
  if (span < 20) return null;
  final onA = <int>{for (final d in da) dayKey(d)};
  final onB = <int>{for (final d in db) dayKey(d)};
  var withA = 0, bothOn = 0, withoutA = 0, bOnly = 0;
  for (var i = 0; i <= span; i++) {
    final k = dayKey(from.add(Duration(days: i)));
    if (onA.contains(k)) {
      withA++;
      if (onB.contains(k)) bothOn++;
    } else {
      withoutA++;
      if (onB.contains(k)) bOnly++;
    }
  }
  if (withA < 6 || withoutA < 6) return null;
  final near = bothOn / withA;
  final far = bOnly / withoutA;
  final gap = (near - far).abs();
  if (gap < 0.20) return null;
  final said = near > far
      ? '${a.name} arrastra a ${b.name}.'
      : '${a.name} y ${b.name} casi nunca el mismo día.';
  return (
    Notice(
      NoticeKind.pair,
      said,
      'Los días de ${a.name}, ${b.name} aparece el ${_pct(near)} de las veces. '
      'El resto de los días, el ${_pct(far)}.',
    ),
    gap,
  );
}

/// How long this has been going on, which is the one number nobody can argue
/// with and the only one worth being proud of on its own.
Notice? lifetime(Habit h, DateTime now) {
  final days = daysOf(h);
  if (days.length < 25) return null;
  return Notice(
    NoticeKind.life,
    '${days.length} días de tu vida.',
    'Desde el ${_date(days.first)} de ${days.first.year}. '
        '${h.total} ${_pieces(h.total)} en total.',
  );
}

// ------------------------------------------------------------------- saying

const List<String> _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábados',
  'domingos',
];

String _weekday(int w) => _weekdays[(w - 1).clamp(0, 6)];

String _date(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

String _pieces(int n) => n == 1 ? 'pieza' : 'piezas';

String _pct(double v) => '${(v * 100).round()}%';

String _partOfDay(int hour) {
  if (hour >= 5 && hour < 12) return ' de la mañana';
  if (hour >= 12 && hour < 20) return ' de la tarde';
  return ' de la noche';
}
