import 'dart:math' as math;

import '../core/rng.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import 'mason.dart';

export 'mason.dart' show PieceKind;

/// One achievement, as a piece of a building.
///
/// The whole point of the city over the wall: a brick in a wall only ever means
/// "the wall is one brick longer", but a piece of a house means "the house is
/// nearly finished", and three days later the house *is* finished. There is a
/// completion to look forward to that is closer than the next landmark.
class TownPiece {
  TownPiece({
    required this.index,
    required this.building,
    required this.kind,
    required this.cx,
    required this.cz,
    required this.w,
    required this.d,
    required this.y0,
    required this.y1,
    required this.seed,
    this.alongX = true,
  });

  /// Which achievement laid this piece.
  final int index;
  final int building;
  final PieceKind kind;

  /// Centre and footprint on the ground.
  final double cx, cz, w, d;

  /// Bottom and top. For a roof, [y1] is the ridge.
  final double y0, y1;

  final int seed;

  /// Ridge direction of a roof.
  final bool alongX;

  double get x0 => cx - w / 2;
  double get x1 => cx + w / 2;
  double get z0 => cz - d / 2;
  double get z1 => cz + d / 2;
}

/// The ordinary houses: the week-by-week fabric of the town. Everything
/// grander is a [Landmark], and lives in its own catalogue.
enum BuildingKind { shed, cottage, workshop, house, granary, townhouse, inn }

/// How many achievements each kind of building costs.
const Map<BuildingKind, int> buildingCost = {
  BuildingKind.shed: 2,
  BuildingKind.cottage: 3,
  BuildingKind.workshop: 4,
  BuildingKind.house: 5,
  BuildingKind.granary: 6,
  BuildingKind.townhouse: 7,
  BuildingKind.inn: 8,
};

const Map<BuildingKind, String> buildingName = {
  BuildingKind.shed: 'Cobertizo',
  BuildingKind.cottage: 'Casa',
  BuildingKind.workshop: 'Taller',
  BuildingKind.house: 'Casona',
  BuildingKind.granary: 'Granero',
  BuildingKind.townhouse: 'Casa de vecinos',
  BuildingKind.inn: 'Posada',
};

/// What a building roofs with. Chosen once, when the town is laid out, from
/// the character's own mix — and then it is both the shape the mason lays and
/// the colour the renderer paints, instead of two hashes in two files that
/// have to agree with each other and one day will not.
enum RoofStuff { tile, slate, thatch }

class TownBuilding {
  TownBuilding({
    required this.index,
    required this.kind,
    required this.landmark,
    required this.firstPiece,
    required this.cx,
    required this.cz,
    required this.seed,
    this.spread = 1.0,
    this.roof = RoofStuff.tile,
    this.names,
  });

  final int index;

  /// The house this is, when it is an ordinary house.
  final BuildingKind? kind;

  /// The landmark this is, when it is one. Exactly one of the two is set.
  final Landmark? landmark;

  /// The achievement that started it.
  final int firstPiece;
  final double cx, cz;
  final int seed;

  /// How wide this town builds on the ground, so the room a building keeps
  /// clear stretches with it.
  final double spread;

  /// Tile, slate or straw.
  final RoofStuff roof;

  /// Cómo llama esta región a las casas corrientes, si las llama de otra
  /// manera. Es el rótulo del edificio, no el edificio: un `shed` sigue
  /// costando dos piezas aunque acá se llame Zócalo.
  final Map<BuildingKind, String>? names;

  /// The plot's own yard: where it is, how big, and what is on it.
  ///
  /// None of it is a piece and none of it is earned. A kitchen garden is not
  /// an achievement — it is what a plot looks like in a place where people
  /// grow things — and charging somebody an achievement for the scenery would
  /// be charging them for the weather. It is filed like the notice board:
  /// furniture the town owns, which a house in front of it still hides.
  double yardX = 0, yardZ = 0, yardSize = 0;
  double treeX = 0, treeZ = 0, treeSize = 0;

  int get cost => landmark?.cost ?? buildingCost[kind]!;
  String get name => landmark?.name ?? names?[kind] ?? buildingName[kind]!;
  bool get isLandmark => landmark != null;

  /// How much room it keeps clear around its own middle. A house wants its
  /// plot; a landmark wants the room its tier is given.
  double get reach => (landmark?.room ?? 1.3) * spread;

  /// Filled in as the pieces are generated.
  double peakY = 0;
  int placedPieces = 0;
  bool get finished => placedPieces >= cost;
}

/// The order the town is built in.
///
/// Y, sobre todo, **cómo se le añaden cosas al catálogo sin mover nada de lo
/// que ya está en pie**.
///
/// Antes esto era una función pura del catálogo: la baraja de hitos se
/// ordenaba por la posición de cada uno en la lista, así que meter uno nuevo
/// —o incluso ponerlo en otro sitio— le cambiaba el índice a todos los de su
/// nivel y con él la baraja entera. Un pueblo de treinta piezas se despertaba
/// con otras casas. Y no es un caso raro: añadir estructuras es lo que va a
/// pasar todo el tiempo.
///
/// Dos cambios, y hacen falta los dos:
///
///  1. **Se puntúa por identificador y no por índice.** La puntuación de un
///     hito sale de su propio `id` y del carácter del pueblo, de nada más. Un
///     hito nuevo entra en la baraja con su puntuación y no le mueve la suya a
///     ninguno de los demás. Eso arregla el orden *relativo*.
///  2. **Lo decidido se escribe.** Aun con lo anterior, un hito nuevo con
///     buena puntuación se colaría delante de cosas ya construidas. Así que en
///     cuanto un edificio se empieza —en cuanto se puede leer su nombre en la
///     pantalla— queda anotado en la crónica del hábito, y de ahí no se mueve
///     nunca más. Lo que se decide es sólo lo que todavía no empezó.
///
/// El resultado es el que se pedía: un pueblo con treinta piezas sigue igual
/// después de la actualización, y la siguiente estructura que levante puede
/// perfectamente ser la que se acaba de añadir.
class TownPlan {
  TownPlan._(this.character);

  /// One plan per kind of place, built once and kept.
  static final Map<int, TownPlan> _plans = {};
  factory TownPlan.of(TownCharacter c) =>
      _plans.putIfAbsent(c.order, () => TownPlan._(c));

  final TownCharacter character;

  /// Cómo se anota un edificio corriente en la crónica, para no confundir
  /// `casa` la casa con `casa` el hito que algún día se llame así.
  static const String kindMark = '#';

  /// Landmarks arrive at a widening cadence, so the first one is close enough
  /// to be worth waiting for and the twentieth does not arrive every fortnight.
  static bool isLandmarkSlot(int b) {
    var at = _firstLandmark, gap = _firstGap, step = 0;
    while (at < b) {
      at += gap + step;
      step++;
    }
    return at == b;
  }

  static const int _firstLandmark = 4;
  static const int _firstGap = 6;

  /// Which landmark this is, counting from the first one the town builds.
  static int landmarkNumber(int b) {
    var n = 0, at = _firstLandmark, gap = _firstGap, step = 0;
    while (at < b) {
      at += gap + step;
      step++;
      n++;
    }
    return n;
  }

  /// The landmarks worth opening a town with.
  ///
  /// A town's first two years should show what the place is capable of — a mill
  /// with its crops, a wheel turning in a river, a bridge, a castle — and not a
  /// pigsty and a charnel house, which is what an honest shuffle keeps handing
  /// out. So the openers are chosen; but *which* of them a given town gets, and
  /// in what order, is its own, so two habits never walk the same road.
  ///
  /// Ésta es además la lista donde se mete algo que tiene que salirle a todo el
  /// mundo, como el observatorio: a quien le queden obras de apertura por
  /// terminar se lo va a encontrar, y a quien ya las tenga todas no se le mueve
  /// ni una piedra.
  static const List<String> _openers = [
    'pozo',
    'horno',
    'molinoViento',
    'cruz',
    'capilla',
    'molinoAgua',
    'palomar',
    'puente',
    'reloj',
    'fuente',
    'mercado',
    'castillo',
    'ermita',
    'faro',
    'iglesia',
    'lagar',
    'atalaya',
    'observatorio',
    'claustro',
    'acueducto',
    'concejo',
  ];

  /// Un número estable a partir de un texto. FNV-1a, que es corto y reparte
  /// bien.
  ///
  /// De aquí sale todo: la puntuación de un hito depende de su nombre y no de
  /// dónde esté escrito, y por eso el catálogo puede crecer, reordenarse o
  /// perder entradas sin que a los demás les pase nada.
  static int idHash(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// Cuándo le toca a un hito, en este pueblo. Un número y ya.
  ///
  /// Es la pieza central de todo esto. El orden en que un pueblo construye es
  /// **ordenar el catálogo por este número**, y nada más: ni cadencias por
  /// posición, ni turnos que ruedan de un nivel a otro cuando se agota, ni
  /// nada que dependa de cuántos hitos haya. Todo eso cascadea — meter uno
  /// cambiaba cuándo se vaciaba su nivel, y eso movía los turnos de los otros
  /// dos.
  ///
  /// Ordenar por un número que sólo depende del hito y del pueblo no puede
  /// cascadear: meter uno nuevo lo mete en su sitio de la lista ordenada y a
  /// los demás no les toca ni el orden relativo. Eso es exactamente lo que
  /// hacía falta.
  ///
  /// Las obras de apertura se van muy abajo, así que salen primero, barajadas
  /// entre ellas. Y los niveles se solapan a propósito: sesenta y cinco
  /// centésimas de sesgo por nivel sobre un azar que vale uno entero, así que
  /// un pueblo empieza con obras chicas y termina con catedrales, pero por el
  /// medio se mezclan en vez de venir en tres bloques.
  double _when(Landmark l) {
    final r = hash01(character.order, 0x51, idHash(l.id));
    return (_openers.contains(l.id) ? -10.0 : l.tier * 0.65) + r;
  }

  /// El catálogo entero en el orden en que este pueblo lo construye.
  ///
  /// Se guarda, pero atado al tamaño del catálogo: en la app no cambia nunca
  /// en marcha, y en un test que le mete uno se rehace.
  List<String> get order {
    if (_order != null && _orderOf == landmarks.length) return _order!;
    final all = [...landmarks]
      ..sort((a, b) {
        final c = _when(a).compareTo(_when(b));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    _orderOf = landmarks.length;
    return _order = [for (final l in all) l.id];
  }

  List<String>? _order;
  int? _orderOf;

  /// El hito número `no` de este pueblo: el primero de su orden que todavía no
  /// construyó.
  String landmarkFor(int no, Set<String> used) {
    for (final id in order) {
      if (!used.contains(id)) return id;
    }
    // Catálogo entero construido, que son ciento y pico obras y muchos años.
    // Vuelve a empezar en vez de dejar al pueblo sin nada que hacer.
    return order[no % order.length];
  }

  BuildingKind kindFor(int b) {
    // Ordinary houses get grander as the town does, but never so much that a
    // small one stops appearing: a town of nothing but mansions is a suburb.
    final List<BuildingKind> pool;
    if (character.grand) {
      // Un pueblo de gigantes se hace de masas simples y no de casonas con
      // buhardilla: lo que lo hace enorme es el tamaño, no el número de
      // cuerpos. Y de paso cada edificio cuesta dos o tres piezas en lugar de
      // cinco o seis, que es lo que hace que diez piezas al mes levanten algo.
      //
      // Crece igual que los demás, en tres tramos. Lo que cambia es el suelo:
      // acá el edificio más chico que existe son dos piezas y mide once
      // metros, así que el primer tramo es casi todo eso y aun así el pueblo
      // se ve enorme desde la primera semana. Y el tercer tramo guarda la
      // Ciudadela y el Coloso —siete y ocho piezas— que no son una casa sino
      // el remate de la ciudad, y que por eso tienen que costar lo que cuesta
      // llegar hasta ellos.
      if (b < 6) {
        pool = const [
          BuildingKind.shed,
          BuildingKind.cottage,
          BuildingKind.cottage,
          BuildingKind.shed,
          BuildingKind.workshop,
          BuildingKind.cottage,
        ];
      } else if (b < 18) {
        pool = const [
          BuildingKind.cottage,
          BuildingKind.shed,
          BuildingKind.workshop,
          BuildingKind.cottage,
          BuildingKind.house,
          BuildingKind.shed,
          BuildingKind.workshop,
          BuildingKind.cottage,
        ];
      } else {
        pool = const [
          BuildingKind.cottage,
          BuildingKind.workshop,
          BuildingKind.house,
          BuildingKind.shed,
          BuildingKind.granary,
          BuildingKind.workshop,
          BuildingKind.cottage,
          BuildingKind.townhouse,
          BuildingKind.shed,
          BuildingKind.inn,
        ];
      }
    } else if (b < 7) {
      pool = const [
        BuildingKind.shed,
        BuildingKind.cottage,
        BuildingKind.cottage,
        BuildingKind.workshop,
      ];
    } else if (b < 22) {
      pool = const [
        BuildingKind.cottage,
        BuildingKind.house,
        BuildingKind.workshop,
        BuildingKind.house,
        BuildingKind.granary,
        BuildingKind.shed,
      ];
    } else {
      pool = const [
        BuildingKind.house,
        BuildingKind.townhouse,
        BuildingKind.cottage,
        BuildingKind.townhouse,
        BuildingKind.inn,
        BuildingKind.granary,
        BuildingKind.workshop,
        BuildingKind.house,
      ];
    }
    return pool[hash32(b, 0x71c3, 5) % pool.length];
  }

  /// Lo que se construye en el turno `b`, sabiendo lo que ya se construyó.
  String decide(int b, Set<String> used) => isLandmarkSlot(b)
      ? landmarkFor(landmarkNumber(b), used)
      : '$kindMark${kindFor(b).name}';

  /// El hito de esa anotación, o nulo si era un edificio corriente.
  ///
  /// Por índice y no recorriendo el catálogo: esto se pregunta una vez por
  /// edificio, y un pueblo de cinco años tiene doscientos cincuenta. Buscar a
  /// mano entre ciento y pico eran sesenta mil comparaciones de texto por
  /// pueblo, y se notaba en el fotograma en que cae una pieza.
  static Landmark? landmarkOf(String id) {
    if (id.startsWith(kindMark)) return null;
    if (_byId == null || _byIdOf != landmarks.length) {
      _byId = {for (final l in landmarks) l.id: l};
      _byIdOf = landmarks.length;
    }
    return _byId![id];
  }

  static Map<String, Landmark>? _byId;
  static int? _byIdOf;

  static BuildingKind kindOf(String id) {
    final want = id.startsWith(kindMark) ? id.substring(1) : id;
    for (final k in BuildingKind.values) {
      if (k.name == want) return k;
    }
    return BuildingKind.house;
  }

  static int costOfId(String id) =>
      landmarkOf(id)?.cost ?? buildingCost[kindOf(id)]!;

  static String nameOfId(String id) =>
      landmarkOf(id)?.name ?? buildingName[kindOf(id)]!;

  /// Lo mismo, pero con la palabra que use esta región. Lo que lee el cartel
  /// de «se está levantando» tiene que decir lo mismo que dirá el edificio
  /// cuando esté en pie.
  String nameOf(String id) =>
      landmarkOf(id)?.name ??
      character.houseNames?[kindOf(id)] ??
      buildingName[kindOf(id)]!;

  /// La obra del pueblo, turno a turno.
  ///
  /// Lee de la crónica mientras alcance y decide de ahí en adelante. Lo que
  /// devuelve más allá de lo ya empezado es una previsión, y puede cambiar si
  /// mañana se añade algo al catálogo — que es justo lo que tiene que poder
  /// pasar, y por eso lo empezado se anota y lo previsto no.
  Iterable<Works> walk(List<String> chronicle) sync* {
    final used = <String>{};
    var from = 0;
    for (var b = 0; b < 20000; b++) {
      final id = b < chronicle.length ? chronicle[b] : decide(b, used);
      if (!id.startsWith(kindMark)) used.add(id);
      final cost = costOfId(id);
      yield Works(b, id, cost, from);
      from += cost;
    }
  }

  /// Si este pueblo ya terminó el hito [id] con [placed] piezas puestas.
  ///
  /// Terminado, no empezado: un observatorio a medio construir no tiene todavía
  /// una cúpula desde la que mirar.
  bool hasFinished(String id, int placed, [List<String> chronicle = const []]) {
    for (final w in walk(chronicle)) {
      if (w.from >= placed) return false;
      if (w.id == id) return w.from + w.cost <= placed;
    }
    return false;
  }

  /// Hasta dónde llega la crónica que hace falta para `placed` piezas.
  ///
  /// Se anota todo edificio que ya se pueda ver o leer: el que tiene piezas
  /// puestas y el que está a punto de empezar, porque su nombre ya está en la
  /// cabecera. Lo que viene después queda abierto, y ahí es donde entra lo que
  /// se añada mañana.
  List<String> chronicleFor(int placed, List<String> chronicle) {
    final out = <String>[];
    for (final w in walk(chronicle)) {
      if (w.from > placed) break;
      out.add(w.id);
    }
    return out;
  }

  /// What the town is putting up right now, how much of it is left, and
  /// whether it is one of the hundred and twelve landmarks.
  (String, int, bool)? underway(
    int placed, [
    List<String> chronicle = const [],
  ]) {
    for (final w in walk(chronicle)) {
      if (placed < w.from + w.cost) {
        return (
          nameOf(w.id),
          w.from + w.cost - placed,
          landmarkOf(w.id) != null,
        );
      }
    }
    return null;
  }

  /// Every landmark the town has built or is about to, with the achievement
  /// it starts at. Enough to show the road ahead without laying out a town.
  List<(Landmark, int)> landmarksAround(
    int placed, {
    int ahead = 500,
    List<String> chronicle = const [],
  }) {
    final out = <(Landmark, int)>[];
    for (final w in walk(chronicle)) {
      final mark = landmarkOf(w.id);
      if (mark != null) out.add((mark, w.from));
      if (w.from + w.cost > placed + ahead) break;
    }
    return out;
  }

  /// Si el pueblo ya terminó este hito.
  bool built(
    String landmarkId,
    int placed, [
    List<String> chronicle = const [],
  ]) {
    for (final w in walk(chronicle)) {
      // En cuanto uno no está terminado, no lo está ninguno de los de después.
      if (w.from + w.cost > placed) return false;
      if (w.id == landmarkId) return true;
    }
    return false;
  }

  /// How many buildings the town has finished.
  int finishedBuildings(int placed, [List<String> chronicle = const []]) {
    var n = 0;
    for (final w in walk(chronicle)) {
      if (w.from + w.cost > placed) break;
      n++;
    }
    return n;
  }
}

/// Un turno de obra: qué edificio es, qué cuesta y en qué pieza empieza.
class Works {
  const Works(this.at, this.id, this.cost, this.from);

  /// Su número de orden en el pueblo.
  final int at;

  /// Lo que quedó anotado: el `id` de un hito, o el nombre de una clase de
  /// edificio con una almohadilla delante.
  final String id;
  final int cost;

  /// La pieza en la que empieza.
  final int from;

  Landmark? get landmark => TownPlan.landmarkOf(id);
}

class TownLayout {
  TownLayout(
    this.placed,
    this.character, {
    this.cx = 0,
    this.cz = 0,
    this.chronicle = const [],
    this.notices = const [0, 3, 6],
  }) : plan = TownPlan.of(character),
       plotPitch = character.plotPitch,
       solo = false {
    _build();
  }

  /// En qué huecos del tablón de la plaza hay papel clavado ahora mismo.
  ///
  /// El pueblo no sabe leerlos —de eso se encarga el tablón de cerca— pero sí
  /// cuántos hay y dónde están, que es lo que hace falta para que su silueta
  /// diga la verdad desde el otro lado del valle. Los tres de por defecto son
  /// los de adorno que tenía, y son los que usa el expositor, que no tiene un
  /// hábito detrás del que sacar notas.
  final List<int> notices;

  /// Qué fue cada edificio, escrito el día que se empezó.
  ///
  /// Vacía quiere decir «decidilo todo ahora», que es lo que hace el expositor
  /// y lo que hacía la app entera antes de que esto existiera. Un pueblo de
  /// verdad la trae llena hasta donde llegó, y por eso lo que ya levantó no lo
  /// puede mover ningún cambio del catálogo.
  final List<String> chronicle;

  /// One structure on its own, in an empty world.
  ///
  /// Nothing about the catalogue is visible from inside a town: a landmark
  /// turns up once every few hundred achievements, and half of them nobody
  /// will reach for a year. This builds exactly one of them, at the origin, so
  /// every recipe can be looked at, walked around, and watched going up piece
  /// by piece — which is the only way to catch a chimney standing on thin air
  /// before somebody earns it.
  TownLayout.showcase(
    this.character, {
    Landmark? landmark,
    BuildingKind? kind,
    required this.placed,
    int seed = 0,
  }) : plan = TownPlan.of(character),
       plotPitch = character.plotPitch,
       cx = 0,
       cz = 0,
       chronicle = const [],
       notices = const [0, 3, 6],
       solo = true {
    final building = TownBuilding(
      index: 0,
      kind: landmark == null ? (kind ?? BuildingKind.house) : null,
      landmark: landmark,
      firstPiece: 0,
      cx: 0,
      cz: 0,
      seed: hash32(seed, 0x5A11, 7),
      spread: character.spread,
      roof: _roofOf(hash32(seed, 0x5A11, 7)),
      names: character.houseNames,
    );
    for (final p in _piecesOf(building)) {
      if (pieces.length > placed) break;
      pieces.add(
        TownPiece(
          index: pieces.length,
          building: 0,
          kind: p.kind,
          cx: p.cx,
          cz: p.cz,
          w: p.w,
          d: p.d,
          y0: p.y0,
          y1: p.y1,
          seed: hash32(building.seed, pieces.length, 31),
          alongX: p.alongX,
        ),
      );
      if (p.y1 > building.peakY) building.peakY = p.y1;
    }
    final built = math.min(pieces.length, placed);
    building.placedPieces = built;
    buildings.add(building);
    radius = building.reach + 1.5;
  }

  /// True for one structure standing on its own in an empty world. A town has
  /// a plaza with a notice board in it; a thing on a plinth in an exhibition
  /// hall does not.
  final bool solo;

  /// Where in the valley this town stands. Every habit has its own plot, so
  /// several towns can be looked at side by side without any of them moving.
  final double cx, cz;

  /// What kind of place this is: how tall its houses stand, how tight its
  /// streets run, and the order it meets the hundred and twelve.
  final TownCharacter character;
  final TownPlan plan;

  /// One extra piece is always laid out so the app can show a ghost of where
  /// the next one goes.
  final int placed;

  final List<TownPiece> pieces = [];
  final List<TownBuilding> buildings = [];

  /// El edificio de este hito, si está en pie. Para las cosas que un pueblo
  /// desbloquea al terminar algo, y para poder señalarlas en pantalla.
  TownBuilding? standing(String landmarkId) {
    for (final b in buildings) {
      if (b.landmark?.id == landmarkId && b.finished) return b;
    }
    return null;
  }

  /// How far the town reaches from its centre, for framing the camera.
  double radius = 4;

  /// How high this town reaches, counting only what is actually standing.
  ///
  /// A sign hung over a town has to clear it, and «a bit above the middle» is
  /// not the same height for a hamlet as for a place with a cathedral in it.
  double get tallest {
    var top = 0.0;
    for (final b in buildings) {
      if (b.placedPieces > 0 && b.peakY > top) top = b.peakY;
    }
    return top;
  }

  TownPiece? pieceFor(int index) =>
      index >= 0 && index < pieces.length ? pieces[index] : null;

  TownBuilding? buildingOf(int index) {
    final p = pieceFor(index);
    return p == null ? null : buildings[p.building];
  }

  /// How close together the plots are laid here.
  final double plotPitch;

  double get blockPitch => plotPitch * 3.6;

  void _build() {
    final want = placed + 1;

    // Qué es cada edificio: leído de la crónica mientras alcance, decidido
    // después. Un pueblo ya construido lee la suya entera y no decide nada.
    final works = <Works>[];
    var total = 0;
    for (final w in plan.walk(chronicle)) {
      works.add(w);
      total += w.cost;
      if (total >= want) break;
    }
    final count = math.max(works.length, 1);

    final plots = _plots(works);
    var index = 0;
    for (var b = 0; b < count; b++) {
      final mark = works[b].landmark;
      final seed = hash32(b, 0x9e37, 17);
      final building = TownBuilding(
        index: b,
        kind: mark == null ? TownPlan.kindOf(works[b].id) : null,
        landmark: mark,
        firstPiece: index,
        cx: cx + plots[b].$1,
        cz: cz + plots[b].$2,
        seed: seed,
        spread: character.spread,
        roof: _roofOf(seed),
        names: character.houseNames,
      );
      final made = _piecesOf(building);
      for (final p in made) {
        if (index >= want) break;
        pieces.add(
          TownPiece(
            index: index,
            building: b,
            kind: p.kind,
            cx: p.cx,
            cz: p.cz,
            w: p.w,
            d: p.d,
            y0: p.y0,
            y1: p.y1,
            seed: hash32(seed, index, 31),
            alongX: p.alongX,
          ),
        );
        if (p.y1 > building.peakY) building.peakY = p.y1;
        index++;
      }
      // The last piece of the town is the ghost of the next one: it is drawn
      // as an outline standing where the piece will go, and it is not built
      // yet. Counting it would give a plot its yard, and a wall the roof that
      // covers it, a whole achievement early.
      _layYard(building, made);
      final built = math.min(index, placed);
      building.placedPieces = math.max(0, built - building.firstPiece);
      buildings.add(building);
      final out = math.sqrt(
        (building.cx - cx) * (building.cx - cx) +
            (building.cz - cz) * (building.cz - cz),
      );
      if (out + building.reach > radius) radius = out + building.reach;
      if (index >= want) break;
    }
  }

  /// The plots, nearest the centre first.
  ///
  /// A square grid of blocks with streets between them, taken in order of
  /// distance from the middle with a little jitter so the edge of the town is
  /// ragged rather than a circle drawn with a compass. Buildings claim them in
  /// order and a landmark keeps its neighbours at arm's length, so a castle is
  /// never wearing somebody's cottage. Because a plot is chosen looking only at
  /// what is already standing, nothing built earlier ever has to move.
  List<(double, double)> _plots(List<Works> works) {
    final rings = math.max(3, (math.sqrt(works.length) / 2).ceil() + 3);
    final all = <(double, double, double)>[];
    for (var bx = -rings; bx <= rings; bx++) {
      for (var bz = -rings; bz <= rings; bz++) {
        for (var px = 0; px < 3; px++) {
          for (var pz = 0; pz < 3; pz++) {
            final x = bx * blockPitch + px * plotPitch + plotPitch / 2;
            final z = bz * blockPitch + pz * plotPitch + plotPitch / 2;
            final key =
                math.sqrt(x * x + z * z) +
                hashRange(0, 2.2, bx + 991, bz + 991, px, pz);
            all.add((x, z, key));
          }
        }
      }
    }
    all.sort((a, b) {
      final c = a.$3.compareTo(b.$3);
      if (c != 0) return c;
      final d = a.$1.compareTo(b.$1);
      return d != 0 ? d : a.$2.compareTo(b.$2);
    });

    final used = List<bool>.filled(all.length, false);
    final out = <(double, double)>[];
    final reaches = <double>[];
    var from = 0;
    for (var b = 0; b < works.length; b++) {
      // Stretched wider on the ground, a building needs more ground. The
      // plot has to know what the mason is going to do to it.
      final r = (works[b].landmark?.room ?? 1.3) * character.spread;
      // Lo apretado que se admite. Una ciudad de gigantes se apiña: sus
      // edificios son más anchos que la calle que los separa y se meten unos
      // en otros, que es lo que le da su silueta de bloque. El render lo
      // aguanta —corta la geometría donde dos sólidos se cruzan— y a cambio
      // el pueblo ocupa menos suelo, que es lo que decide si dos pueblos del
      // valle se tocan.
      final packed = character.grand ? 0.58 : 0.72;
      var placedIt = false;
      for (var i = from; i < all.length; i++) {
        if (used[i]) continue;
        final x = all[i].$1, z = all[i].$2;
        var ok = true;
        for (var k = 0; k < out.length; k++) {
          final dx = x - out[k].$1, dz = z - out[k].$2;
          if (dx.abs() > 14 || dz.abs() > 14) continue;
          final need = (r + reaches[k]) * packed;
          if (dx * dx + dz * dz < need * need) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        used[i] = true;
        out.add((x, z));
        reaches.add(r);
        placedIt = true;
        while (from < all.length && used[from]) {
          from++;
        }
        break;
      }
      // The grid ran out, which only happens for a town far larger than any
      // that will ever be built. Better a crowded corner than no plot at all.
      if (!placedIt) {
        out.add(
          all[out.length % all.length].$1 == 0
              ? (0.0, 0.0)
              : (
                  all[out.length % all.length].$1,
                  all[out.length % all.length].$2,
                ),
        );
        reaches.add(r);
      }
    }
    return out;
  }

  /// Which of the three this building roofs with, from the character's mix.
  /// Deterministic in the building's own seed, so it never changes under a
  /// town that is already standing.
  RoofStuff _roofOf(int seed) {
    final t = hash01(seed, 3);
    final (tile, slate, _) = character.roofMix;
    if (t < tile) return RoofStuff.tile;
    return t < tile + slate ? RoofStuff.slate : RoofStuff.thatch;
  }

  /// Turns this building's roofs to straw where straw is what it roofs with.
  ///
  /// Done here rather than in every recipe: a mason lays a roof, and what
  /// region he is standing in decides what it is made of. Which is also how
  /// it worked.
  List<Spec> _straw(TownBuilding b, List<Spec> specs) {
    if (b.roof != RoofStuff.thatch) return specs;
    return [
      for (final p in specs)
        if (p.kind != PieceKind.roof)
          p
        else
          Spec(
            kind: PieceKind.thatch,
            cx: p.cx,
            cz: p.cz,
            w: p.w,
            d: p.d,
            y0: p.y0,
            y1: p.y1,
            alongX: p.alongX,
          ),
    ];
  }

  /// Gives a house its yard, if this is a place that has them.
  ///
  /// It goes beside the house, clear of it, and clear of the neighbour: the
  /// far edge is kept inside half a plot so no garden ever ends up in
  /// somebody else's kitchen. Where the house is too big for its plot to have
  /// any room left, it simply has no yard, which is also what happens in a
  /// town where the houses got bigger.
  void _layYard(TownBuilding b, List<Spec> made) {
    if (solo || b.isLandmark || made.isEmpty) return;
    final wantGarden = hash01(b.seed, 42) < character.gardens;
    final wantTree = hash01(b.seed, 43) < character.trees;
    if (!wantGarden && !wantTree) return;

    var half = 0.0;
    for (final p in made) {
      final x = (p.cx - b.cx).abs() + p.w / 2;
      final z = (p.cz - b.cz).abs() + p.d / 2;
      if (x > half) half = x;
      if (z > half) half = z;
    }
    final dir = (hash01(b.seed, 41) * 4).floor() % 4;
    const step = [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)];

    // A garden wants clear ground: whatever is left over between this house
    // and the next one, minus a path to walk down. It is the size of the room
    // there is for one, and where the houses grew until there is none the plot
    // simply has no garden — which is what happens to a street that fills in.
    if (wantGarden) {
      final room = plotPitch - 2 * half - 0.24;
      final size = math.min(plotPitch * 0.34, room);
      if (size >= 0.38) {
        final off = half + size / 2 + 0.10;
        b.yardX = b.cx + step[dir].$1 * off;
        b.yardZ = b.cz + step[dir].$2 * off;
        b.yardSize = size;
      }
    }

    // A tree wants far less than a garden: somewhere to stand its trunk. It
    // goes on the corner of the plot, which is both where the room is and
    // where anybody would put one, and its crown is allowed out over the roof
    // — that is what a tree beside a house does, and since geometry that runs
    // through other geometry is cut where the two cross, it is drawn right
    // when it does.
    if (wantTree) {
      const corner = [(0.7, 0.7), (-0.7, 0.7), (-0.7, -0.7), (0.7, -0.7)];
      final c = corner[(dir + (wantGarden ? 2 : 1)) % 4];
      final off = half * 0.98 + 0.34;
      b.treeX = b.cx + c.$1 * off;
      b.treeZ = b.cz + c.$2 * off;
      b.treeSize = math.min(plotPitch * 0.34, 1.05);
    }
  }

  List<Spec> _piecesOf(TownBuilding b) {
    final s = b.seed;
    // Every building sits a little differently on its plot, so a grid of them
    // never lines up into a barracks. A landmark sits square: it is the thing
    // the street is arranged around, not one more house on it.
    final jitter = b.isLandmark ? 0.0 : 0.22;
    final m = Mason(
      b.cx + hashRange(-jitter, jitter, s, 3),
      b.cz + hashRange(-jitter, jitter, s, 4),
      s,
      hash01(s, 5) < 0.5,
      spread: character.spread,
      storey: character.storey,
      pitch: character.pitch,
    );

    final mark = b.landmark;
    if (mark != null) {
      mark.build(m);
      return _straw(b, m.finish(mark.cost));
    }

    // An ordinary house, in the units every recipe is written in. What makes
    // it a Sierra house or a Ribera house is the mason, not this.
    //
    // The spread here is deliberately narrow — a house differs from its
    // neighbour by a twentieth, not by a fifth. It used to be ±11%, which is
    // the same size as the difference between two whole regions, so standing
    // in a street you could not tell which region you were in: the noise was
    // as loud as the signal. A town is houses that agree with each other.
    final wide = hashRange(1.52, 1.74, s, 6);
    final deep = hashRange(1.44, 1.64, s, 7);
    final storey = hashRange(0.96, 1.06, s, 8);
    const pitch = 1.0;

    // Un pueblo de gigantes no se construye con las recetas de un pueblo de
    // gente, agrandadas. Agrandar una casa da una casa vista de cerca: la
    // puerta mide tres metros, la ventana dos, y no hay nada que diga que es
    // grande. Lo que hace una torre es que sea una torre — un basamento, un
    // fuste largo con muchas filas de ventanas, y algo arriba que remate.
    //
    // Están escritas en las mismas unidades que las demás, así que el ancho y
    // el alto del Coloso las estiran igual que estiran las de la Ribera. Lo
    // que cambia es la forma, no la escala.
    if (character.grand) {
      // Cómo se remata una torre. Todas con la misma aguja daban un pueblo de
      // lápices; y el remate es lo único que se ve de lejos, así que es lo que
      // tiene que cambiar de un edificio a otro.
      void crown(double w, double d) {
        final cual = hash01(s, 12);
        if (cual < 0.52) {
          m.spire(w * 1.16, d * 1.16, 1.9);
        } else if (cual < 0.80) {
          m.roof(w * 1.2, d * 1.2, 1.2);
        } else if (cual < 0.92) {
          m.dome(w * 1.02, d * 1.02, 1.1);
        } else {
          m.parapet(w * 1.14, d * 1.14, 0.62);
        }
      }

      switch (b.kind!) {
        case BuildingKind.shed:
          // La nave: un galpón de gigantes, ancho y con un tejado enorme. Es
          // lo más chico que existe acá y aun así le saca tres cabezas a una
          // casona de la Ribera.
          //
          // Lleva tejado y no azotea a propósito: es el primer edificio que
          // levanta el pueblo y con dos bloques planos con ventanas en
          // cuadrícula el sitio se leía como un barrio de torres de oficinas.
          // Un tejado a dos aguas de seis metros no se lee como otra cosa.
          m.floor(wide * 1.46, deep * 1.46, 1.75);
          m.roof(wide * 1.6, deep * 1.6, 1.3);
        case BuildingKind.cottage:
          // La torre: basamento ancho, fuste retranqueado y remate. El
          // retranqueo es lo que la hace leerse alta —un prisma recto de
          // arriba abajo se lee como un muro visto de cerca.
          m.plinth(wide * 1.48, deep * 1.48, 0.48);
          m.floor(wide * 1.06, deep * 1.06, 3.1);
          crown(wide * 1.06, deep * 1.06);
        case BuildingKind.workshop:
          // El baluarte: tres cuerpos que van menguando y un adarve que
          // vuela por encima del último.
          m.plinth(wide * 1.58, deep * 1.58, 0.56);
          m.floor(wide * 1.38, deep * 1.38, 1.95);
          m.floor(wide * 1.02, deep * 1.02, 1.55);
          m.parapet(wide * 1.18, deep * 1.18, 0.58);
        case BuildingKind.house:
          // El torreón: soportales abajo —que es donde se mete la gente, y
          // por eso son lo que dice de qué tamaño es todo lo demás— y dos
          // cuerpos encima.
          m.plinth(wide * 1.54, deep * 1.54, 0.42);
          m.arcade(wide * 1.4, 1.2, deep * 1.4, rise: true);
          m.floor(wide * 1.22, deep * 1.22, 2.45);
          m.floor(wide * 0.9, deep * 0.9, 1.8);
          crown(wide * 0.9, deep * 0.9);
        case BuildingKind.granary:
          // El bastión: escalinata y una pirámide escalonada de tres
          // cuerpos. Es el que menos sube y el que más pesa.
          m.stair(wide * 1.12, 0.44, deep * 0.88, dz: deep * 1.2);
          m.plinth(wide * 1.62, deep * 1.62, 0.46);
          m.floor(wide * 1.44, deep * 1.44, 1.95);
          m.floor(wide * 1.18, deep * 1.18, 1.7);
          m.floor(wide * 0.92, deep * 0.92, 1.5);
          m.parapet(wide * 1.06, deep * 1.06, 0.6);
        case BuildingKind.townhouse:
          // La ciudadela: escalinata, soportales, tres cuerpos y remate.
          // Siete piezas, que son meses.
          m.stair(wide * 1.16, 0.46, deep * 0.9, dz: deep * 1.24);
          m.plinth(wide * 1.66, deep * 1.66, 0.48);
          m.arcade(wide * 1.46, 1.25, deep * 1.46, rise: true);
          m.floor(wide * 1.28, deep * 1.28, 2.5);
          m.floor(wide * 1.06, deep * 1.06, 2.1);
          m.floor(wide * 0.84, deep * 0.84, 1.7);
          crown(wide * 0.84, deep * 0.84);
        case BuildingKind.inn:
          // El coloso, que es el que le da nombre al sitio: lo más grande que
          // se levanta sin ser un hito, y ocho piezas de espera.
          m.stair(wide * 1.2, 0.48, deep * 0.94, dz: deep * 1.3);
          m.plinth(wide * 1.72, deep * 1.72, 0.5);
          m.arcade(wide * 1.52, 1.3, deep * 1.52, rise: true);
          m.floor(wide * 1.34, deep * 1.34, 2.6);
          m.floor(wide * 1.12, deep * 1.12, 2.2);
          m.floor(wide * 0.88, deep * 0.88, 1.85);
          m.parapet(wide * 1.0, deep * 1.0, 0.62);
          m.spire(wide * 0.7, deep * 0.7, 2.1);
      }
      return _straw(b, m.finish(b.cost));
    }

    switch (b.kind!) {
      case BuildingKind.shed:
        m.floor(wide * 0.8, deep * 0.8, storey * 0.78);
        m.roof(wide * 0.86, deep * 0.86, 0.42 * pitch);
      case BuildingKind.cottage:
        m.floor(wide, deep, storey);
        m.roof(wide + 0.16, deep + 0.16, 0.62 * pitch);
        m.chimney(0.26, 0.75, dx: wide * 0.28, dz: deep * 0.18);
      case BuildingKind.workshop:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.85);
        m.roof(wide + 0.16, deep + 0.16, 0.58 * pitch);
        m.door(wide * 0.5, 0.66, dz: deep * 0.5 + 0.22);
      case BuildingKind.house:
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.92);
        m.roof(wide + 0.18, deep + 0.18, 0.7 * pitch);
        m.chimney(0.28, 0.9, dx: -wide * 0.3, dz: deep * 0.2);
        m.dormer(0.5, 0.42, dz: deep * 0.28);
      case BuildingKind.granary:
        m.plinth(wide + 0.3, deep + 0.3, 0.34);
        m.floor(wide, deep, storey * 1.15);
        m.floor(wide, deep, storey);
        m.roof(wide + 0.22, deep + 0.22, 0.78 * pitch);
        m.door(wide * 0.42, 0.5, dz: deep * 0.5 + 0.2);
        m.dormer(0.42, 0.4, dz: -deep * 0.28);
      case BuildingKind.townhouse:
        m.plinth(wide + 0.22, deep + 0.22, 0.28);
        m.floor(wide, deep, storey);
        m.floor(wide, deep, storey * 0.95);
        m.floor(wide, deep, storey * 0.9);
        m.roof(wide + 0.2, deep + 0.2, 0.72 * pitch);
        m.dormer(0.46, 0.4, dz: deep * 0.26);
        m.door(wide * 0.44, 0.62, dz: deep * 0.5 + 0.2);
      case BuildingKind.inn:
        m.floor(wide * 1.15, deep, storey * 1.1);
        m.floor(wide * 1.15, deep, storey);
        m.roof(wide * 1.25, deep + 0.2, 0.72 * pitch);
        // The side wing stands on the ground beside the inn, not on its roof.
        m.box(
          PieceKind.floor,
          wide * 0.6,
          deep * 0.7,
          storey * 0.9,
          dx: wide * 0.8,
          ridge: true,
          at: 0,
        );
        m.roof(
          wide * 0.66,
          deep * 0.76,
          0.44,
          dx: wide * 0.8,
          at: storey * 0.9,
          along: !m.alongX,
        );
        m.chimney(0.3, 1.0, dx: -wide * 0.4);
        m.chimney(0.26, 0.8, dx: wide * 0.2);
        m.door(wide * 0.7, 0.7, dz: deep * 0.5 + 0.24);
    }

    return _straw(b, m.finish(b.cost));
  }
}
