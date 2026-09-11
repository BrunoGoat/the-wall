import 'dart:math' as math;

import '../core/rng.dart';
import '../data/gossip.dart';
import '../ui/board_plan.dart';
import '../engine/town.dart';
import 'findings.dart';
import 'habit.dart';
import 'piece.dart';

/// Lo que hay clavado en el tablón de un pueblo.
///
/// Una sola cuenta para las dos cosas que la necesitan: el tablón de cerca,
/// que las escribe, y el de la plaza, que enseña su silueta. Si fueran dos, el
/// tablón de lejos tendría cuatro papeles y el de cerca seis, y la única
/// manera de enterarse sería acercarse y contar.
///
/// Primero lo que el pueblo sabe de vos, y detrás lo que el pueblo tiene
/// clavado por su cuenta. Nunca al revés: un bando sobre una cabra perdida no
/// puede ser lo primero que se lee de tu propio tablón. Y si de vos no sabe
/// nada todavía, se dice que está vacío y se clavan unos cuantos bandos más,
/// que es lo que tendría un tablón de plaza el primer día.
List<Notice> boardNotices(
  Habit h, {
  List<Habit> valley = const [],
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final work = TownPlan.of(h.place).underway(h.total, h.chronicle);
  final said = noticesFor(
    h,
    others: valley,
    underway: work?.$1,
    left: work?.$2 ?? 0,
    at: at,
  );
  // Cuántos bandos toca clavar hoy: entre dos y cuatro, sorteado por la fecha
  // y por el pueblo. Que sea distinto cada día es lo que hace que el tablón
  // tenga días con más vida del pueblo y días con menos.
  final quiere = 2 + hashInt(3, dayKey(dayStart(now)), h.slot, 61);
  // Pero lo que el pueblo sabe de vos va primero y no se recorta nunca: si hay
  // ocho notas de verdad, caben dos bandos y se clavan dos. Un bando sobre una
  // cabra no puede dejar fuera lo que el tablón averiguó.
  final hueco = BoardPlan.capacity - said.length - (said.isEmpty ? 1 : 0);
  final cuantos = quiere.clamp(0, math.max(0, hueco)).toInt();
  return [
    if (said.isEmpty) emptyNotice(h),
    ...said,
    ...villageNotices(now, town: h.slot, count: cuantos),
  ];
}

/// La hoja que se clava cuando de vos no se sabe nada.
///
/// Va clavada como cualquier otra porque es lo que sería en la plaza: nadie
/// deja el hueco en blanco, se clava un papel avisando.
Notice emptyNotice(Habit h) {
  final days = daysOf(h).length;
  return Notice(
    NoticeKind.life,
    'El tablón está vacío.',
    days == 0
        ? 'Todavía no hay nada que contar. Poné la primera pieza.'
        : 'Llevás $days ${days == 1 ? 'día' : 'días'}. El pueblo prefiere '
              'callarse a inventar: cuando tenga bastante para estar seguro '
              'de algo, lo escribe acá.',
  );
}
