import 'dart:math' as math;

import '../data/character.dart';
import '../data/symbols.dart';
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
    int? character,
    List<Piece>? pieces,
    List<String>? chronicle,
  }) : character = character ?? TownCharacter.forSlot(slot).order,
       pieces = pieces ?? [],
       chronicle = chronicle ?? [];

  /// Never reused and never changed: it is what a saved town is filed under.
  final String id;

  String name;

  /// Which drawn mark this habit wears: an id from [habitSymbols], never a
  /// font character. It stands over the town in the wide view, which is how
  /// four towns are told apart from far enough away to see all of them.
  String symbol;

  /// Where in the valley this habit's town stands. Assigned when the habit is
  /// made and kept for good, so adding a fifth habit never moves the first
  /// four — the same promise the pieces themselves get.
  final int slot;

  final DateTime createdAt;

  /// What kind of place this habit builds, chosen the day it was founded.
  ///
  /// Never changed afterwards, and there is no way to: the character decides
  /// how wide the plots are and in what order the hundred and twelve arrive,
  /// so changing it would move pieces that were laid years ago. The one
  /// promise this app makes is that a piece stays where it was put.
  final int character;

  TownCharacter get place => TownCharacter.byOrder(character);

  final List<Piece> pieces;

  /// Qué fue cada edificio de este pueblo, en orden y escrito el día que se
  /// empezó.
  ///
  /// Es lo que hace que el catálogo pueda crecer. Sin esto, el orden de las
  /// obras se recalculaba entero en cada arranque a partir del catálogo, así
  /// que añadir un hito le cambiaba las casas a un pueblo de treinta piezas.
  /// Con esto, lo que ya se empezó está escrito y no se vuelve a decidir; lo
  /// que se decide es sólo lo que todavía no empezó, y ahí sí entra lo nuevo.
  final List<String> chronicle;

  int get total => pieces.length;

  DateTime? get lastPlacedAt => pieces.isEmpty ? null : pieces.last.placedAt;

  /// The most towns the valley holds. Six is as many as can be told apart at a
  /// glance, and a person with seven habits has a different problem.
  static const int maxSlots = 6;

  /// Where a slot's town stands. Slot zero is the middle of the valley — el
  /// primer hábito es la capital— y los demás lo rodean.
  ///
  /// El anillo mide ciento ocho. Medía setenta y ocho, y setenta y ocho era
  /// poco: el pueblo del centro y uno del anillo se tocan en cuanto la suma de
  /// sus radios pasa del anillo, y un Valle de ochocientas piezas ya mide
  /// cuarenta y uno. Es decir que dos Valles de ochocientas no cabían, y eso
  /// era así desde antes de que existiera el Coloso —que con las mismas
  /// ochocientas mide cincuenta y dos y no cabría de ninguna manera.
  ///
  /// Con ciento ocho caben los dos más grandes del catálogo con ochocientas
  /// piezas cada uno y sobra sitio. Donde vuelve a quedarse corto es en dos
  /// pueblos de dos mil, que son años de dos hábitos a la vez; ensancharlo más
  /// se paga en la vista del valle, donde seis pueblos chicos quedarían
  /// perdidos en el prado.
  ///
  /// Nada de esto está guardado: la posición sale del número de hueco, así que
  /// ensanchar el anillo no le mueve una piedra a ningún pueblo, sólo los
  /// separa.
  static (double, double) centreOf(int slot) {
    if (slot <= 0) return (0.0, 0.0);
    const ring = 108.0;
    final k = (slot - 1) % (maxSlots - 1);
    final a = -math.pi / 2 + k * 2 * math.pi / (maxSlots - 1);
    return (math.cos(a) * ring, math.sin(a) * ring);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    's': symbol,
    'slot': slot,
    'ch': character,
    'c': createdAt.millisecondsSinceEpoch,
    'p': pieces.map((p) => p.toJson()).toList(),
    'w': chronicle,
  };

  static Habit fromJson(Map<String, dynamic> j) {
    final list =
        ((j['p'] as List?) ?? [])
            .map((e) => Piece.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    // A town is built in order and nothing else about a piece matters, so a
    // save with gaps in it is renumbered rather than refused.
    for (var i = 0; i < list.length; i++) {
      if (list[i].index != i) {
        list[i] = Piece(
          index: i,
          placedAt: list[i].placedAt,
          label: list[i].label,
        );
      }
    }
    return Habit(
      id: j['id'] as String? ?? 'h0',
      name: j['n'] as String? ?? 'Mi hábito',
      // Older saves hold an emoji here. They are read back as the mark that
      // means the same thing, so nobody's habit changes what it is about.
      symbol: resolveHabitSymbol(j['s'] as String?),
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      // Una copia vieja no la trae: se rellena al cargar, a partir del
      // catálogo de hoy, y desde entonces queda escrita.
      chronicle: [for (final e in (j['w'] as List?) ?? []) e.toString()],
      // A save from before towns could be chosen keeps the one its plot was
      // given, so nobody's town changes shape under them.
      character: (j['ch'] as num?)?.toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['c'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      pieces: list,
    );
  }
}
