import '../engine/city.dart';
import '../model/appearance.dart';

/// The words the app uses, which depend on what the achievements are building.
///
/// The same act — one achievement, one piece, laid and never moved — is a
/// brick in a wall or a course of a house depending on which world is on. Two
/// worlds sharing one set of words would mean one of them always speaking a
/// language that is not its own, which is exactly how "Contrafuertes en 37
/// ladrillos" ended up written across a town.
class Lexicon {
  const Lexicon({
    required this.title,
    required this.unit,
    required this.units,
    required this.unitsCaps,
    required this.world,
    required this.worldCaps,
    required this.firstPrompt,
    required this.decayWhisper,
    required this.decayLine,
    required this.stateIntact,
    required this.stateSlipping,
    required this.stateFalling,
    required this.creed,
    required this.futureTitle,
    required this.futureBlurb,
    required this.seeAll,
    required this.goLatest,
    required this.logTitle,
    required this.logCount,
    required this.noteInvite,
    required this.tabs,
  });

  /// What the app calls itself on the way in.
  final String title;

  /// One achievement, and many of them.
  final String unit, units, unitsCaps;

  /// The thing being built, in running text and as a heading.
  final String world, worldCaps;

  final String firstPrompt;
  final String decayWhisper, decayLine;
  final String stateIntact, stateSlipping, stateFalling;
  final String creed;
  final String futureTitle, futureBlurb;
  final String seeAll, goLatest;
  final String logTitle, logCount, noteInvite;
  final List<String> tabs;

  static Lexicon get of =>
      Appearance.instance.world == World.city ? town : wall;

  static bool get isTown => Appearance.instance.world == World.city;

  static const Lexicon wall = Lexicon(
    title: 'LA MURALLA',
    unit: 'ladrillo',
    units: 'ladrillos',
    unitsCaps: 'LADRILLOS',
    world: 'la muralla',
    worldCaps: 'LA MURALLA',
    firstPrompt: 'Mantené el botón para colocar tu primer ladrillo',
    decayWhisper: 'La muralla se está resintiendo.',
    decayLine: 'La muralla se deteriora · un ladrillo la repara',
    stateIntact: 'Intacta. Cada día que sumás un ladrillo se mantiene así.',
    stateSlipping: 'Empieza a resentirse. Un solo ladrillo la repara entera.',
    stateFalling: 'Se está viniendo abajo. Un ladrillo alcanza para frenarlo.',
    creed: 'Un ladrillo es siempre un logro. Nunca un lote.',
    futureTitle: 'Ver la muralla a futuro',
    futureBlurb: 'Cómo se vería con 100, 500 o 5000 ladrillos. No toca los tuyos.',
    seeAll: 'Ver toda la muralla',
    goLatest: 'Ir al último ladrillo',
    logTitle: 'BITÁCORA DE LA MURALLA',
    logCount: 'piedras asentadas',
    noteInvite: 'Tocá cualquier piedra de la muralla y dejale una leyenda: '
        '“Leí”, “Corrí”, lo que quieras. No hace falta —la piedra ya está '
        'puesta— pero lo que se escribe queda en esta bitácora, y dentro de '
        'un año esto va a ser una historia.',
    tabs: ['LA MURALLA', 'HITOS', 'LEYENDAS'],
  );

  static const Lexicon town = Lexicon(
    title: 'EL PUEBLO',
    unit: 'pieza',
    units: 'piezas',
    unitsCaps: 'PIEZAS',
    world: 'el pueblo',
    worldCaps: 'EL PUEBLO',
    firstPrompt: 'Mantené el botón para poner tu primera piedra',
    decayWhisper: 'El pueblo se está quedando a oscuras.',
    decayLine: 'Se están apagando las ventanas · una pieza las enciende',
    stateIntact: 'Todas las ventanas encendidas. Cada día que sumás una pieza '
        'siguen así.',
    stateSlipping: 'Empiezan a apagarse ventanas. Una sola pieza las vuelve a '
        'encender todas.',
    stateFalling: 'El pueblo se está quedando vacío. Una pieza alcanza para '
        'que vuelvan a encenderse.',
    creed: 'Una pieza es siempre un logro. Nunca un lote.',
    futureTitle: 'Ver el pueblo a futuro',
    futureBlurb: 'Cómo se vería con 100, 500 o 5000 piezas. No toca las tuyas.',
    seeAll: 'Ver todo el pueblo',
    goLatest: 'Ir a lo último que pusiste',
    logTitle: 'BITÁCORA DEL PUEBLO',
    logCount: 'piezas asentadas',
    noteInvite: 'Tocá cualquier parte del pueblo y dejale una leyenda: '
        '“Leí”, “Corrí”, lo que quieras. No hace falta —la pieza ya está '
        'puesta— pero lo que se escribe queda en esta bitácora, y dentro de '
        'un año esto va a ser una historia.',
    tabs: ['EL PUEBLO', 'HITOS', 'LEYENDAS'],
  );

  /// How many of something, with the right word after it.
  String count(int n) => '$n ${n == 1 ? unit : units}';

  /// What the town or the wall is working on right now.
  static String nextEvent(int placed) {
    if (!isTown) return '';
    final work = CityPlan.underway(placed);
    if (work == null) return 'El pueblo sigue creciendo';
    final left = work.$2;
    if (work.$3) {
      // A landmark is named while it is going up; it is the thing being waited
      // for, and saying so is most of what the waiting is worth.
      return left == 1
          ? 'Una pieza más y ${work.$1} queda en pie'
          : 'Levantando ${work.$1} · faltan $left';
    }
    return left == 1
        ? 'Una pieza más y ${work.$1} queda en pie'
        : '${work.$1} · faltan $left';
  }
}
