/// Lo que el pueblo clava en el tablón cuando no está hablando de vos.
///
/// El tablón de la plaza no puede estar vacío. Un pueblo de verdad tiene
/// siempre un par de papeles clavados —una cabra perdida, un baile el sábado,
/// alguien que busca aprendiz—, y son justamente esos papeles los que hacen
/// que el sitio parezca habitado en vez de un panel de estadísticas al que le
/// faltan datos.
///
/// Ninguno habla de vos ni finge saber nada: son cosas del pueblo, y por eso
/// no se pueden confundir con lo que el tablón sí sabe. Cambian cada día y
/// salen de la fecha, así que el pueblo tiene su propia vida siguiendo su
/// propio calendario y uno vuelve al día siguiente a ver qué hay de nuevo.
///
/// Aquí está sólo el reparto: quién se lleva cuál y qué día. Las frases están
/// en `bandos.dart`, y están aparte porque son cientos y no paran de crecer —
/// juntas, la lógica se perdía dentro del texto.
library;

import 'bandos.dart';

import '../core/rng.dart';
import '../model/findings.dart';
import '../model/habit.dart';
import '../model/piece.dart';

/// Los papeles que le tocan hoy al pueblo [town] del valle.
///
/// Dos, o [count] si se piden otros tantos, y **nunca los mismos que a otro
/// pueblo el mismo día**: seis pueblos enseñando la misma cabra perdida no son
/// seis pueblos, son seis copias de una pantalla. Lo que sí se repite es de un
/// día para otro, que es lo que hace un tablón de verdad.
///
/// Se hace barajando el catálogo entero con la fecha y dándole a cada pueblo
/// su tramo: el pueblo cero se lleva los tres primeros de la baraja del día,
/// el uno los tres siguientes, y así. Repartir así y no sortear por separado
/// es lo que hace que no puedan chocar — con seis pueblos y treinta y seis
/// bandos sobra baraja de sobra.
List<Notice> villageNotices(DateTime at, {required int town, int count = 2}) {
  if (bandos.isEmpty || count <= 0) return const [];
  final baraja = _shuffled(dayKey(dayStart(at)));
  // Tres por pueblo, que es lo más que se le piden. De ancho fijo para que
  // pedir dos o pedir tres no le corra el tramo al pueblo de al lado.
  const window = 3;
  final from = (town.clamp(0, Habit.maxSlots - 1)) * window;
  final out = <Notice>[];
  for (var k = 0; k < count; k++) {
    final (dice, y) = bandos[baraja[(from + k) % baraja.length]];
    out.add(Notice(NoticeKind.pueblo, dice, y));
  }
  return out;
}

/// El catálogo barajado con la fecha: la baraja del día.
///
/// Barajado de verdad y no recorrido a saltos, para que valga sea cual sea el
/// número de bandos. Con saltos habría que elegir un paso primo con ese
/// número, y añadir un bando podría romperlo en silencio.
List<int> _shuffled(int day) {
  final out = [for (var i = 0; i < bandos.length; i++) i];
  for (var i = out.length - 1; i > 0; i--) {
    final j = hashInt(i + 1, day, i, 77);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// Cuántos hay. Para que el catálogo se pueda contar sin abrirlo.
int get villageNoticeCount => bandos.length;
