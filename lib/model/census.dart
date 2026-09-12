import '../data/folknames.dart';
import '../engine/folk.dart';
import '../engine/town.dart';
import 'habit.dart';

/// Un vecino, escrito.
///
/// Todo lo demás de esta app se deriva: la casa sale del hash del pueblo, el
/// hito sale de la crónica, el sitio de cada uno sale del reloj. La gente no.
/// Una persona que lleva dos años en tu pueblo, con su nombre y su cara, no
/// puede cambiar porque yo toque una lista de nombres o mueva un tono de piel
/// medio punto — sería la única cosa de la app que rompe su propia promesa.
///
/// Así que cuando nace se apunta, y lo apuntado no se vuelve a decidir. Es el
/// mismo trato que tienen las piezas y la crónica de obra.
class Villager {
  const Villager(this.home, this.seed, this.born, this.name);

  /// El edificio en el que vive, que es el que lo trajo al mundo.
  final int home;

  /// De donde salen su cara, su ropa y su talla. Guardada, no recalculada.
  final int seed;

  /// El día que se remató su casa, que es el día que nació. No es «cuando lo
  /// apunté»: es la fecha de la pieza que cerró la casa, así que un pueblo que
  /// ya existía antes de que esto se escribiera recupera las fechas de verdad.
  final DateTime born;

  final String name;

  /// Una línea de texto, que es como se guarda todo lo demás en este hábito.
  /// El nombre va al final porque es lo único que puede llevar cualquier cosa
  /// dentro; los tres de delante son números.
  String get line =>
      '$home|$seed|${born.millisecondsSinceEpoch}|${name.replaceAll('\n', ' ')}';

  static Villager? parse(String raw) {
    final bits = raw.split('|');
    if (bits.length < 4) return null;
    final home = int.tryParse(bits[0]);
    final seed = int.tryParse(bits[1]);
    final born = int.tryParse(bits[2]);
    if (home == null || seed == null || born == null) return null;
    return Villager(
      home,
      seed,
      DateTime.fromMillisecondsSinceEpoch(born),
      bits.sublist(3).join('|'),
    );
  }
}

/// El padrón guardado de un pueblo, por edificio.
Map<int, Villager> censusOf(List<String> book) {
  final out = <int, Villager>{};
  for (final line in book) {
    final v = Villager.parse(line);
    if (v != null) out[v.home] = v;
  }
  return out;
}

/// Apunta a los que hayan nacido desde la última vez.
///
/// Devuelve los nuevos, en orden, para poder decir quién llegó. No toca a
/// nadie que ya esté apuntado, ni siquiera para corregirlo: eso es justamente
/// lo que este padrón existe para impedir.
///
/// La fecha sale de la pieza que remató la casa y no del reloj de ahora, así
/// que da igual cuándo se pase esto por primera vez — un pueblo de dos años
/// recupera los dos años de cumpleaños de golpe y en su sitio.
List<Villager> enrolFolk(Habit habit, TownLayout layout) {
  final had = <int>{
    for (final line in habit.folk) Villager.parse(line)?.home ?? -1,
  };
  final nuevos = <Villager>[];
  for (final b in layout.buildings) {
    if (b.isLandmark) continue;
    final last = b.firstPiece + b.cost - 1;
    if (last >= habit.pieces.length) continue;
    if (had.contains(b.index)) continue;
    final seed = folkSeedOf(b.seed, b.index);
    nuevos.add(
      Villager(b.index, seed, habit.pieces[last].placedAt, folkName(seed)),
    );
  }
  // Por orden de llegada, que es como se lee un padrón.
  nuevos.sort((a, b) => a.born.compareTo(b.born));
  for (final v in nuevos) {
    habit.folk.add(v.line);
  }
  return nuevos;
}
