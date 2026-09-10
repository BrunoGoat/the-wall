import '../data/gossip.dart';
import '../engine/town.dart';
import 'findings.dart';
import 'habit.dart';

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
  return [
    if (said.isEmpty) emptyNotice(h),
    ...said,
    ...villageNotices(now, town: h.slot, count: said.isEmpty ? 3 : 2),
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
