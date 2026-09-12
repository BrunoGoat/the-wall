import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/doings.dart';
import '../data/folknames.dart';
import 'solid.dart';
import 'town.dart';

/// La gente que vive en el pueblo.
///
/// Una casa terminada es una casa donde vive alguien, y hasta ahora no vivía
/// nadie: el pueblo era un sitio precioso y vacío. Cada casa corriente que se
/// remata pone una persona en la calle, y al hacerlo convierte la cuenta de
/// piezas en una cuenta de vecinos — que es la misma cuenta dicha de la manera
/// en que la gente se acuerda de las cosas.
///
/// **No son piezas y no se ganan.** Son consecuencia de lo ganado, como la
/// huerta o el roble de la parcela: nadie paga un logro por un vecino, el
/// vecino aparece porque su casa está en pie. La regla de una pieza un logro
/// no se toca por ningún lado.
///
/// **Y no se guardan.** Dónde está cada uno es una función pura del reloj y de
/// su semilla, igual que las bandadas de pájaros o el sol. No hay simulación
/// que adelantar al volver a abrir la app, no hay nada que se desincronice, no
/// hay nada que se corrompa, y dos vistas del mismo pueblo en el mismo momento
/// enseñan a la misma gente en el mismo sitio. Lo único que se paga por eso es
/// que al cerrar y abrir vuelven a empezar su ronda, que no lo nota nadie.
class Townsfolk {
  Townsfolk._(
    this.home,
    this.seed,
    this.name,
    this.born,
    this._stops,
    this._stay,
    this._facing,
    this._act,
    this.period,
  );

  /// El edificio en el que vive, que es el que lo puso en el mundo.
  final int home;

  /// De donde sale todo lo suyo: la cara, el paño, la talla, la ronda y a qué
  /// dedica la tarde. Viene del padrón cuando lo hay, y del plano cuando no.
  final int seed;

  /// Cómo se llama.
  final String name;

  /// El día que se remató su casa, que es el día que nació. Nulo en el
  /// expositor y en los tests, que no tienen un hábito detrás.
  final DateTime? born;

  /// Lo que hace en cada parada de su ronda. Nulo en los quiebros del camino,
  /// que no son sitios a los que se va.
  final List<Doing?> _act;

  /// Si es un crío. Más chico, y es el que sale al prado a soltar la cometa o
  /// a correr detrás de una mariposa — que es lo que hace un crío en un pueblo
  /// donde no hay nada más que hacer.
  bool get kid => hash01(seed, 12) < 0.24;

  /// Lo que mide, contra lo que mide una persona hecha.
  double get build =>
      kid ? 0.66 + hash01(seed, 13) * 0.10 : 0.94 + hash01(seed, 14) * 0.15;

  /// Por dónde pasa: su puerta, sus recados, y los quiebros que da para
  /// rodear las casas que le quedan en medio.
  final List<(double x, double z)> _stops;

  /// Lo que se queda parado al llegar a cada punto. Cero en los quiebros, que
  /// no son sitios a los que se va sino esquinas que se doblan.
  final List<double> _stay;

  /// Hacia dónde mira en cada parada mientras espera.
  final List<double> _facing;

  /// Lo que tarda en dar la ronda entera, en segundos.
  final double period;

  /// Dónde tiene la puerta. Es donde aparece al amanecer y donde se mete al
  /// anochecer.
  (double x, double z) get door => _stops.first;

  /// La ronda, vértice a vértice. Para poder medirla en un test: mirando sólo
  /// lo que devuelve [at] no se distingue un vértice metido en una pared de un
  /// tramo largo que corta una esquina, y son dos fallos con dos arreglos
  /// distintos.
  @visibleForTesting
  List<(double x, double z)> get debugPath => _stops;

  /// En qué anda cuando está parado. Para poder exigir en un test que un crío
  /// no se ponga a martillear un puente y que nadie suelte una cometa dentro
  /// de la plaza.
  @visibleForTesting
  List<Doing?> get debugActs => _act;

  /// Lo que anda una persona en un segundo.
  ///
  /// Medido contra la puerta de una casa, que mide dos tercios de unidad: a
  /// este paso cruza un pueblo de veinte de radio en menos de un minuto, que
  /// es lo que dura una mirada a la app. Más despacio y parecen estatuas; más
  /// rápido y parecen hormigas con prisa.
  static const double pace = 0.78;

  /// Cuánto mide una zancada, para que el paso no vaya por su cuenta.
  ///
  /// El balanceo se cuenta por metros andados y no por segundos: contándolo
  /// por segundos, una persona que va más despacio patina.
  static const double stride = 0.42;

  /// Dónde está y hacia dónde mira en el segundo [t].
  ///
  /// [t] es el reloj de la escena, que corre mientras se mira el pueblo. La
  /// ronda da la vuelta sola, así que esto vale para cualquier [t] por grande
  /// que sea.
  /// Dónde está y hacia dónde mira en el segundo [t].
  ///
  /// [t] es el reloj de la escena, que corre mientras se mira el pueblo. La
  /// ronda da la vuelta sola, así que esto vale para cualquier [t] por grande
  /// que sea.
  FolkAt at(double t) {
    final u = (t + hash01(seed, 7) * period) % period;
    var acc = 0.0;
    var walked = hash01(seed, 8) * 40; // para que no pisen todos a la vez
    final n = _stops.length;
    for (var i = 0; i < n; i++) {
      final from = _stops[i], to = _stops[(i + 1) % n];
      final dx = to.$1 - from.$1, dz = to.$2 - from.$2;
      final d = math.sqrt(dx * dx + dz * dz);
      final walk = d / pace;
      if (u < acc + walk) {
        final k = walk <= 0 ? 1.0 : (u - acc) / walk;
        return FolkAt(
          from.$1 + dx * k,
          from.$2 + dz * k,
          math.atan2(dx, dz),
          (walked + d * k) / stride * 2 * math.pi,
          true,
          null,
          u - acc,
        );
      }
      acc += walk;
      walked += d;
      final stay = _stay[(i + 1) % n];
      if (u < acc + stay) {
        // Parado: mirando a donde vino a mirar, con un balanceo lento que es
        // lo que separa a alguien esperando de un poste.
        final what = _act[(i + 1) % n];
        final look = _facing[(i + 1) % n];
        // La cabeza se va yendo a mirar alrededor, y cuánto depende de en qué
        // ande: quien pica piedra no levanta la vista y quien no hace nada la
        // levanta todo el rato.
        final sway =
            math.sin((u - acc) * 0.7 + hash01(seed, 9) * 6) *
            0.18 *
            (what?.turn ?? 1.0);
        return FolkAt(to.$1, to.$2, look + sway, 0, false, what, u - acc);
      }
      acc += stay;
    }
    final last = _stops.first;
    return FolkAt(last.$1, last.$2, _facing.first, 0, false, _act.first, 0);
  }
}

/// Una persona en un instante: dónde está, hacia dónde mira, y por dónde va su
/// paso.
class FolkAt {
  const FolkAt(
    this.x,
    this.z,
    this.heading,
    this.gait,
    this.moving, [
    this.act,
    this.phase = 0,
  ]);
  final double x, z;

  /// Hacia dónde mira, en radianes, como el `yaw` de la cámara.
  final double heading;

  /// La fase del paso, en radianes. Cero cuando está quieto.
  final double gait;
  final bool moving;

  /// Qué está haciendo ahora mismo. Nulo quiere decir que va de camino.
  final Doing? act;

  /// Cuántos segundos lleva haciéndolo. Es lo que mueve el gesto: sin esto,
  /// alguien charlando es alguien con el brazo levantado y quieto, que es peor
  /// que no levantarlo.
  final double phase;
}

/// La gente de un pueblo, guardada de un fotograma para el siguiente.
///
/// Quién vive dónde y por dónde anda no cambia mientras no caiga una pieza,
/// pero calcularlo no es gratis: cada vecino rodea las casas que le quedan en
/// medio, y eso son unas cuantas miles de cuentas para un pueblo mediano.
/// Hacerlas sesenta veces por segundo para llegar al mismo resultado sería
/// tirar un cuarto del fotograma a la basura.
///
/// Se guarda con la misma llave que la mampostería: dónde está el pueblo y
/// cuántas piezas lleva.
final Map<String, (int, List<Townsfolk>)> _folk = {};

/// La gente que hay ahora mismo en [layout], y por dónde andan.
///
/// Sale del plano y de nada más, así que dos llamadas con el mismo pueblo dan
/// la misma gente en el mismo orden — que es lo que hace que su semilla les
/// valga y que no cambien de ropa entre fotogramas.
List<Townsfolk> folkOf(TownLayout layout, int placed) {
  // Y el padrón entra en la llave. Sólo su tamaño: un padrón no se corrige
  // nunca, sólo crece, así que si tiene los mismos renglones que antes dice lo
  // mismo que antes. Sin esto, el primer arranque después de escribirlo se
  // quedaba con la gente sin nombre que había calculado un momento antes.
  final key =
      '${layout.cx},${layout.cz},${layout.character.order},'
      '${layout.folk.length}';
  final had = _folk[key];
  if (had != null && had.$1 == placed) return had.$2;
  final made = _folkOf(layout, placed);
  if (_folk.length > 24) _folk.clear();
  _folk[key] = (placed, made);
  return made;
}

List<Townsfolk> _folkOf(TownLayout layout, int placed) {
  final casas = <TownBuilding>[];
  for (final b in layout.buildings) {
    if (b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    casas.add(b);
  }
  if (casas.isEmpty) return const [];

  // A dónde va la gente. Pocos sitios y compartidos, que es lo que hace que se
  // encuentren: con un destino para cada uno, un pueblo de cuarenta vecinos
  // son cuarenta personas solas andando en paralelo. La plaza y los hitos son
  // de todos, así que a media tarde hay tres en el pozo, y eso no hubo que
  // programarlo.
  //
  // Y se ponen **fuera** de lo construido, no a una distancia inventada: el
  // sitio que se guarda una parcela no es lo que ocupa el edificio, y un
  // castillo ocupa mucho más que un pozo. Con una distancia fija, los vecinos
  // que iban al castillo se plantaban dentro de la muralla.
  final huella = _footprints(layout, placed);
  final estorbos = _blockers(layout, placed);
  final calles = _Streets.of(layout, estorbos);
  //
  // Cada sitio dice además qué clase de sitio es, porque de eso depende lo que
  // se hace al llegar: en la plaza se charla, en una obra se arrima el hombro,
  // y en el prado se suelta la cometa. Un crío soltando una cometa en medio de
  // la plaza es lo que pasa cuando esto no se distingue.
  final sitios = <(double x, double z, double reach, Where kind)>[
    (layout.cx, layout.cz, 0.9, Where.square),
  ];
  for (final b in layout.buildings) {
    if (!b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    final c = huella[b.index];
    sitios.add((
      b.cx,
      b.cz,
      (c == null ? b.reach : _spanOf(c)) + 0.55,
      _wet.contains(b.landmark?.id) ? Where.water : Where.work,
    ));
  }
  // Y un paseo al borde del pueblo, para que no sea todo ir de un edificio a
  // otro. Un pueblo también es la gente que sale a mirar el campo.
  final borde = math.max(layout.radius * 0.82, 3.0);
  for (var k = 0; k < 3; k++) {
    final a = k * 2 * math.pi / 3 + 0.4;
    sitios.add((
      layout.cx + math.sin(a) * borde,
      layout.cz + math.cos(a) * borde,
      0.6,
      Where.meadow,
    ));
  }

  // Lo que diga el padrón manda. Un vecino apuntado conserva su semilla —y con
  // ella su cara, su ropa y su talla— y su nombre, pase lo que pase con el
  // plano o con la lista de nombres.
  final padron = _censusOf(layout.folk);

  final out = <Townsfolk>[];
  for (final b in casas) {
    final apuntado = padron[b.index];
    final seed = apuntado?.$1 ?? folkSeedOf(b.seed, b.index);
    // La puerta, del lado por el que se sale al pueblo, y justo fuera de su
    // propia pared: si cae dentro, el vecino empieza el día dentro de su casa
    // y sale de ella atravesándola.
    final dx = layout.cx - b.cx, dz = layout.cz - b.cz;
    final d = math.sqrt(dx * dx + dz * dz);
    final c = huella[b.index];
    final fuera = (c == null ? b.reach * 0.7 : _spanOf(c)) + 0.30;
    final paso = d < 0.001 ? 1.0 : fuera / d;
    final door = calles.onStreets((b.cx + dx * paso, b.cz + dz * paso));

    // Tres recados y a casa. Tres y no más porque una ronda más larga es una
    // ronda que no se ve entera de una sentada.
    final crio = hash01(seed, 12) < 0.24;
    // Su propia puerta es el único sitio de la ronda que es suyo, y por eso es
    // donde pasan las cosas de casa: tomar el sol, hilar, partir leña. Casi la
    // mitad se queda un rato; los demás pasan de largo, que también es verdad.
    final stops = <(double, double)>[door];
    final encasa = hash01(seed, 61) < 0.45;
    final dwell = <double>[encasa ? hashRange(12.0, 30.0, seed, 62) : 0.0];
    final doing = <Doing>[_actAt(Where.door, seed, 9, crio)];
    // Al volver a casa mira a la puerta, que es lo suyo.
    final look = <double>[math.atan2(-dx, -dz)];
    for (var k = 0; k < 3; k++) {
      final s = sitios[hashInt(sitios.length, seed, 20 + k)];
      // Alrededor del sitio y no encima: se ponen en corro mirando al medio,
      // que es lo que hace la gente delante de un tablón o de una fuente.
      // En ocho sitios alrededor y no en cualquiera: con el ángulo libre, dos
      // que van al mismo pozo casi nunca quedan de cara, y con ocho puestos
      // coinciden a menudo. El corro se forma solo.
      final a = hashInt(8, seed, 30 + k) * math.pi / 4;
      stops.add(
        calles.onStreets((
          s.$1 + math.sin(a) * s.$3,
          s.$2 + math.cos(a) * s.$3,
        )),
      );
      look.add(math.atan2(-math.sin(a), -math.cos(a)));
      // Las paradas son más largas ahora que en ellas pasa algo: charlar seis
      // segundos y marcharse no es charlar, es saludar de lejos.
      dwell.add(hashRange(9.0, 26.0, seed, 40 + k));
      doing.add(_actAt(s.$4, seed, k, crio));
    }

    // El camino de verdad: los recados, y los quiebros para no meterse por
    // dentro de las casas que queden en medio.
    //
    // En casa no se para: entrar por la puerta y volver a salir sería una
    // persona parpadeando en el umbral, así que la ronda sigue.
    final path = <(double, double)>[];
    final stay = <double>[];
    final facing = <double>[];
    final acts = <Doing?>[];
    for (var i = 0; i < stops.length; i++) {
      final from = stops[i], to = stops[(i + 1) % stops.length];
      path.add(from);
      stay.add(dwell[i]);
      facing.add(look[i]);
      acts.add(doing[i]);
      for (final q in calles.route(from, to)) {
        path.add(q);
        // Un paso del camino no es un sitio al que se va: ni se para en él ni
        // se queda mirando nada.
        stay.add(0);
        facing.add(look[i]);
        acts.add(null);
      }
    }
    var period = 0.0;
    for (var i = 0; i < path.length; i++) {
      final from = path[i], to = path[(i + 1) % path.length];
      period +=
          math.sqrt(
            math.pow(to.$1 - from.$1, 2) + math.pow(to.$2 - from.$2, 2),
          ) /
          Townsfolk.pace;
      period += stay[(i + 1) % path.length];
    }
    out.add(
      Townsfolk._(
        b.index,
        seed,
        apuntado?.$2 ?? folkName(seed),
        apuntado?.$3,
        path,
        stay,
        facing,
        acts,
        math.max(period, 1),
      ),
    );
  }
  return out;
}

/// Qué clase de sitio es un recado.
/// Las obras que tienen agua.
///
/// Es lo que hace que se pueda pescar y echar barcos de papel sin inventarse
/// un río: en un pueblo con pozo hay quien saca agua, y en uno sin pozo no.
/// Un pueblo que todavía no ha levantado ninguna de éstas sencillamente no
/// tiene a nadie haciendo cosas de agua, que es lo correcto.
const Set<String> _wet = {
  'pozo',
  'fuente',
  'lavadero',
  'abrevadero',
  'acena',
  'noria',
  'vado',
  'barca',
  'pasarela',
  'puente',
  'acueducto',
  'presa',
  'embarcadero',
  'astillero',
  'banos',
  'aljibe',
  'salinas',
  'batan',
  'tinte',
  'pescaderia',
  'teneria',
};

/// Lo que se puede hacer en cada clase de sitio, repartido una sola vez.
final Map<Where, List<Doing>> _byWhere = {
  for (final w in Where.values)
    w: [
      for (final d in Doing.all)
        if (d.where == w) d,
    ],
};

/// A qué se dedica alguien al llegar a un sitio de esta clase.
///
/// Sale de la semilla, así que el mismo vecino hace lo mismo en el mismo
/// recado siempre — no hay nadie cambiando de oficio cada vez que se repinta.
///
/// Con peso: charlar en la plaza pasa mucho más que hacer malabares, y sin
/// pesos un pueblo de cuarenta vecinos tiene cuatro malabaristas. La rareza de
/// lo raro es lo que hace que valga la pena verlo.
Doing _actAt(Where where, int seed, int k, bool kid) {
  final puede = [
    for (final d in _byWhere[where]!)
      if (d.fits(kid)) d,
  ];
  if (puede.isEmpty) return Doing.walking;
  var total = 0.0;
  for (final d in puede) {
    total += d.weight;
  }
  var r = hash01(seed, 60 + k) * total;
  for (final d in puede) {
    r -= d.weight;
    if (r <= 0) return d;
  }
  return puede.last;
}

/// La semilla de quien viva en un edificio.
///
/// Aparte y pública porque el padrón la tiene que calcular igual el día que
/// apunta a alguien, y a partir de ahí es lo guardado lo que manda.
int folkSeedOf(int buildingSeed, int index) =>
    hash32(buildingSeed, 0xF01C, index);

/// El padrón de [layout], leído.
///
/// Formato: `casa|semilla|nacimiento|nombre`. Se lee aquí y se escribe en el
/// modelo, que es quien tiene el hábito y las fechas de las piezas; el motor
/// sólo necesita saber leerlo.
Map<int, (int, String, DateTime)> _censusOf(List<String> book) {
  final out = <int, (int, String, DateTime)>{};
  for (final line in book) {
    final bits = line.split('|');
    if (bits.length < 4) continue;
    final home = int.tryParse(bits[0]);
    final seed = int.tryParse(bits[1]);
    final born = int.tryParse(bits[2]);
    if (home == null || seed == null || born == null) continue;
    out[home] = (
      seed,
      bits.sublist(3).join('|'),
      DateTime.fromMillisecondsSinceEpoch(born),
    );
  }
  return out;
}

/// Lo que ocupa en el suelo cada edificio, medido de lo que tiene en pie.
///
/// **Cajas y no círculos**, y eso importa más de lo que parece. Con un círculo
/// por edificio —el que le cabe por las esquinas— en un pueblo de solares a
/// dos metros y ochenta los círculos se solapan unos con otros y **no queda
/// calle**: el interior del pueblo entero queda marcado como pared, no hay
/// ningún punto libre a donde empujar a nadie, y la gente acaba andando por
/// dentro de las casas porque no hay otro sitio. Lo comprobé midiendo: hasta
/// tres metros dentro de un círculo, con todos los puntos «sacados».
///
/// Una caja se ajusta a lo que hay, y entre dos cajas hay calle.
///
/// Sólo lo que está a la altura de una persona. Un alero que vuela metro y
/// medio por encima de la cabeza no es un obstáculo, es un sitio donde
/// guarecerse.
Map<int, (double x0, double z0, double x1, double z1)> _footprints(
  TownLayout layout,
  int placed,
) {
  final out = <int, (double, double, double, double)>{};
  final n = math.min(placed, layout.pieces.length);
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    if (p.y0 > 0.95) continue;
    final b = p.building;
    if (b < 0 || b >= layout.buildings.length) continue;
    final had = out[b];
    out[b] = had == null
        ? (p.x0, p.z0, p.x1, p.z1)
        : (
            math.min(had.$1, p.x0),
            math.min(had.$2, p.z0),
            math.max(had.$3, p.x1),
            math.max(had.$4, p.z1),
          );
  }
  return out;
}

/// Lo que estorba de verdad, **pieza a pieza y no edificio a edificio**.
///
/// Con una caja por edificio —la que envuelve todas sus piezas— un castillo
/// con patio, o cualquier obra en L, marca como pared un patio entero por el
/// que sí se puede andar. Y es peor que quedarse corto: al sacar un punto de
/// una caja de seis metros de alto, un paso sale por el sur y el siguiente por
/// el norte, y entre los dos queda un tramo recto de seis metros que cruza el
/// edificio de lado a lado. Eso era exactamente el tramo de nueve metros que
/// me estaba saliendo, y no se arregla partiéndolo más: el punto de en medio
/// vuelve a caer dentro y vuelve a salir por donde no es.
///
/// Una caja por pieza se ajusta a lo que hay de verdad. Son más cajas —dos
/// centenares en vez de cuarenta— pero el camino se calcula una vez, al
/// fundarse la ronda, y no sesenta veces por segundo.
const double _margin = 0.26;

List<(double x0, double z0, double x1, double z1)> _blockers(
  TownLayout layout,
  int placed,
) {
  final out = <(double, double, double, double)>[];
  final n = math.min(placed, layout.pieces.length);
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    // Lo que vuela por encima de la cabeza no estorba: un alero es un sitio
    // donde guarecerse, no una pared.
    if (p.y0 > 0.95) continue;
    // Un palmo de más por cada lado, que es lo que ocupa una persona de
    // ancho: rozando la pared con el hombro no se atraviesa, pero se ve mal.
    //
    // Y un poco más que un palmo, por lo que mide una casilla del plano: una
    // casilla cuenta como libre si su centro lo está, y un punto cualquiera
    // de ella está a lo sumo a media diagonal —veinticuatro centímetros— del
    // centro. Con este margen, todo lo que pase por casillas libres queda
    // fuera de lo construido por geometría y no por suerte.
    out.add((p.x0 - _margin, p.z0 - _margin, p.x1 + _margin, p.z1 + _margin));
  }
  return out;
}

/// Lo que abulta una caja, para poner a alguien a su lado sin meterlo dentro.
double _spanOf((double, double, double, double) c) =>
    math.max(c.$3 - c.$1, c.$4 - c.$2) / 2;

/// Las calles del pueblo, como plano por el que se puede buscar camino.
///
/// Esto es lo que había que hacer desde el principio y tardé seis intentos en
/// aceptarlo. Todo lo anterior —círculos de estorbo, quiebros por las
/// esquinas, partir el tramo y sacar el punto de en medio— era **reparación
/// local**: coger la línea recta de un recado al siguiente y arreglarla por
/// trozos. Y una reparación local no puede rodear un edificio, por definición;
/// lo más que consigue es pegar el camino a la pared por el lado que le toque,
/// y cuando el punto siguiente se pega por el lado contrario queda un tramo
/// recto de seis metros que cruza la casa de parte a parte. Lo medí: de
/// cuatro vecinos metidos en paredes se bajaba a uno, y de ahí no bajaba.
///
/// Un plano sí puede. El suelo del pueblo se parte en casillas de un tercio de
/// metro, se marcan las que pisa algo construido, y de una casilla libre a
/// otra se busca camino. No hay heurística que ajustar y no hay caso que se
/// escape: si el camino existe lo encuentra, y todas sus casillas están
/// libres, así que no hay por dónde meterse en una pared.
///
/// Se construye **una vez por pueblo** —no uno por vecino— y la ronda entera
/// se calcula al fundarla, no al pintarla.
class _Streets {
  _Streets(this.x0, this.z0, this.cols, this.rows, this._free) {
    _label();
    _cost = Float64List(_free.length);
    _from = Int32List(_free.length);
    _seen = Int32List(_free.length);
  }

  /// La esquina de la casilla (0, 0), en coordenadas del valle.
  final double x0, z0;
  final int cols, rows;

  /// Por dónde se puede pisar. Una casilla está libre si su centro no cae
  /// dentro de nada.
  final List<bool> _free;

  /// Lo que gasta el A*, de una vez y para siempre: un mapa por casilla en
  /// vez de un diccionario que se llena y se tira quinientas veces.
  /// [_seen] dice de qué búsqueda es lo que hay escrito, que es más barato que
  /// borrarlo todo entre una y otra.
  late final Float64List _cost;
  late final Int32List _from;
  late final Int32List _seen;
  int _run = 0;

  /// En qué trozo de pueblo cae cada casilla, y cual es el trozo grande.
  ///
  /// Un pueblo no siempre es de una pieza: el patio de un castillo, el hueco
  /// entre un muro y el río, la esquina que deja cerrada una obra nueva. Si a
  /// alguien le toca un recado al otro lado de una pared no hay camino, y sin
  /// camino lo que quedaba era la línea recta — por dentro de todo. Se marcan
  /// los trozos una vez y los recados se buscan siempre en el grande.
  late final List<int> _region;
  late final int _main;

  void _label() {
    _region = List<int>.filled(_free.length, -1);
    var next = 0, mejor = 0, cual = -1;
    final pila = <int>[];
    for (var seed = 0; seed < _free.length; seed++) {
      if (!_free[seed] || _region[seed] >= 0) continue;
      final id = next++;
      var size = 0;
      pila
        ..clear()
        ..add(seed);
      _region[seed] = id;
      while (pila.isNotEmpty) {
        final at = pila.removeLast();
        size++;
        final cx = at % cols, cz = at ~/ cols;
        for (var dz = -1; dz <= 1; dz++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dz == 0) continue;
            if (!_freeAt(cx + dx, cz + dz)) continue;
            // Igual que en el A*: por la punta de dos piezas no se pasa, así
            // que tampoco cuenta como el mismo trozo de pueblo.
            if (dx != 0 && dz != 0) {
              if (!_freeAt(cx + dx, cz) || !_freeAt(cx, cz + dz)) continue;
            }
            final j = (cz + dz) * cols + cx + dx;
            if (_region[j] >= 0) continue;
            _region[j] = id;
            pila.add(j);
          }
        }
      }
      if (size > mejor) {
        mejor = size;
        cual = id;
      }
    }
    _main = cual;
  }

  /// El sitio de verdad para un recado: éste mismo si se puede llegar a él, y
  /// si no el más cercano al que sí.
  (double, double) onStreets((double, double) p) {
    final (cx, cz) = _cellOf(p);
    if (_freeAt(cx, cz) && _region[cz * cols + cx] == _main) return p;
    for (var r = 1; r <= 30; r++) {
      for (var dz = -r; dz <= r; dz++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dz.abs() != r) continue;
          if (!_freeAt(cx + dx, cz + dz)) continue;
          final j = (cz + dz) * cols + cx + dx;
          if (_region[j] != _main) continue;
          return _centreOf(j);
        }
      }
    }
    return p;
  }

  /// Un tercio de metro, que es menos que el hueco más estrecho entre dos
  /// casas del pueblo más apretado. Con casillas más grandes una calle se
  /// cierra sola y la gente da un rodeo por donde sí se puede pasar.
  static const double cell = 1 / 3;

  factory _Streets.of(
    TownLayout layout,
    List<(double, double, double, double)> blocks,
  ) {
    final borde = layout.radius + 9;
    final x0 = layout.cx - borde, z0 = layout.cz - borde;
    final n = math.max(8, (borde * 2 / cell).ceil());
    final free = List<bool>.filled(n * n, true);
    for (final c in blocks) {
      // Sólo las casillas de esta caja, que es lo que hace que marcar
      // doscientas piezas en un plano de treinta mil casillas sea gratis.
      final ax = math.max(0, ((c.$1 - x0) / cell).floor());
      final az = math.max(0, ((c.$2 - z0) / cell).floor());
      final bx = math.min(n - 1, ((c.$3 - x0) / cell).ceil());
      final bz = math.min(n - 1, ((c.$4 - z0) / cell).ceil());
      for (var cz = az; cz <= bz; cz++) {
        final mz = z0 + (cz + 0.5) * cell;
        if (mz <= c.$2 || mz >= c.$4) continue;
        for (var cx = ax; cx <= bx; cx++) {
          final mx = x0 + (cx + 0.5) * cell;
          if (mx <= c.$1 || mx >= c.$3) continue;
          free[cz * n + cx] = false;
        }
      }
    }
    return _Streets(x0, z0, n, n, free);
  }

  bool _freeAt(int cx, int cz) =>
      cx >= 0 && cz >= 0 && cx < cols && cz < rows && _free[cz * cols + cx];

  (int, int) _cellOf((double, double) p) =>
      (((p.$1 - x0) / cell).floor(), ((p.$2 - z0) / cell).floor());

  (double, double) _centreOf(int i) =>
      (x0 + (i % cols + 0.5) * cell, z0 + (i ~/ cols + 0.5) * cell);

  /// La casilla libre más cerca de una. Hace falta porque un punto puede estar
  /// libre y caer en una casilla cuyo centro no lo está — el borde de una
  /// pared parte casillas por la mitad.
  int? _near((double, double) p) {
    final (cx, cz) = _cellOf(p);
    if (_freeAt(cx, cz)) return cz * cols + cx;
    for (var r = 1; r <= 5; r++) {
      for (var dz = -r; dz <= r; dz++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dz.abs() != r) continue;
          if (_freeAt(cx + dx, cz + dz)) {
            return (cz + dz) * cols + cx + dx;
          }
        }
      }
    }
    return null;
  }

  /// Los quiebros que hay que dar para ir de [a] a [b] sin pisar nada.
  ///
  /// Sin [a] ni [b], que los pone quien llama. Vacío cuando la línea recta ya
  /// está libre, que en un pueblo abierto es casi siempre.
  List<(double, double)> route((double, double) a, (double, double) b) {
    if (!_walled(a, b)) return const [];
    final from = _near(a), to = _near(b);
    if (from == null || to == null) return const [];
    final camino = _search(from, to);
    if (camino == null) return const [];
    return _straighten(a, b, camino);
  }

  /// Si el tramo recto de [a] a [b] pisa algo.
  ///
  /// Se lo pregunta al plano y no a las cajas. Cuesta lo que mide el tramo y
  /// no lo que mide el pueblo: mil piezas son mil cajas que probar por cada
  /// tramo, y estirar los caminos de ciento cuarenta vecinos así tardaba medio
  /// segundo —justo al poner una pieza, que es el único momento en que la app
  /// tiene que ir fina—. Y es igual de de fiar, porque el margen de [_margin]
  /// ya cuenta con lo que mide una casilla.
  bool _walled((double, double) a, (double, double) b) {
    final d = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
    final n = math.max(1, (d / (cell / 3)).ceil());
    for (var k = 0; k <= n; k++) {
      final t = k / n;
      final (cx, cz) = _cellOf((
        a.$1 + (b.$1 - a.$1) * t,
        a.$2 + (b.$2 - a.$2) * t,
      ));
      if (!_freeAt(cx, cz)) return true;
    }
    return false;
  }

  /// A* por las ocho vecinas, sin cortar esquinas en diagonal: pasar entre dos
  /// piezas que se tocan por la punta es pasar por dentro de las dos.
  List<int>? _search(int from, int to) {
    final tx = to % cols, tz = to ~/ cols;
    const raiz2 = 1.41421356237;
    final run = ++_run;
    _seen[from] = run;
    _cost[from] = 0;
    _from[from] = -1;
    final abierto = _Heap()..push(from, 0);
    var pasos = 0;
    while (abierto.isNotEmpty) {
      final at = abierto.pop();
      if (at == to) {
        final out = <int>[];
        for (var i = to; i >= 0; i = _from[i]) {
          out.add(i);
        }
        return out.reversed.toList();
      }
      // Un tope, porque un vecino encerrado por obra nueva puede no tener
      // camino a ninguna parte y no se va a buscar por el pueblo entero para
      // averiguarlo. Sin camino, la recta: se verá mal un instante, que es
      // mejor que una app que se queda pensando.
      if (++pasos > 60000) return null;
      final cx = at % cols, cz = at ~/ cols;
      final ya = _cost[at];
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          if (!_freeAt(cx + dx, cz + dz)) continue;
          if (dx != 0 && dz != 0) {
            if (!_freeAt(cx + dx, cz) || !_freeAt(cx, cz + dz)) continue;
          }
          final next = (cz + dz) * cols + cx + dx;
          final paso = ya + (dx != 0 && dz != 0 ? raiz2 : 1.0);
          if (_seen[next] == run && _cost[next] <= paso) continue;
          _seen[next] = run;
          _cost[next] = paso;
          _from[next] = at;
          final hx = (tx - cx - dx).abs(), hz = (tz - cz - dz).abs();
          final min = math.min(hx, hz);
          // Con la corazonada pesada: un camino de vecino no tiene por qué ser
          // el más corto que existe, tiene que ser uno que no pise casas y que
          // no se note raro, y después de estirarlo no hay ojo que distinga un
          // tres por ciento de rodeo. Buscando el óptimo exacto se exploraba
          // medio pueblo por cada recado.
          const afan = 1.4;
          abierto.push(next, paso + ((hx + hz - min) + raiz2 * min) * afan);
        }
      }
    }
    return null;
  }

  /// Estirar el camino: de la cuadrícula a una línea de verdad.
  ///
  /// Se va todo lo lejos que se pueda en recta y se quiebra sólo donde hay que
  /// quebrar. Sin esto, andar por las casillas se ve como andar por las
  /// casillas — a pasitos de un tercio de metro y en ocho direcciones.
  List<(double, double)> _straighten(
    (double, double) a,
    (double, double) b,
    List<int> camino,
  ) {
    final pts = <(double, double)>[a, for (final i in camino) _centreOf(i), b];
    final out = <(double, double)>[];
    var i = 0;
    while (i < pts.length - 1) {
      // Hacia delante y no hacia atrás desde el final: probando desde el final
      // se tira el tramo entero por cada quiebro, y son tantas pruebas como el
      // cuadrado de lo que mide el camino.
      var j = i + 1;
      while (j + 1 < pts.length && !_walled(pts[i], pts[j + 1])) {
        j++;
      }
      if (j < pts.length - 1) out.add(pts[j]);
      i = j;
    }
    return out;
  }
}

/// Un montón para el A*, que dart:core no trae.
///
/// Lo mínimo que hace falta: meter con prioridad y sacar la menor. Las
/// entradas viejas se quedan dentro y se descartan al salir, que es más barato
/// que buscarlas para cambiarlas de sitio.
class _Heap {
  final List<int> _what = [];
  final List<double> _cost = [];

  bool get isNotEmpty => _what.isNotEmpty;

  void push(int what, double cost) {
    _what.add(what);
    _cost.add(cost);
    var i = _what.length - 1;
    while (i > 0) {
      final up = (i - 1) >> 1;
      if (_cost[up] <= _cost[i]) break;
      _swap(up, i);
      i = up;
    }
  }

  int pop() {
    final top = _what.first;
    final last = _what.length - 1;
    _swap(0, last);
    _what.removeLast();
    _cost.removeLast();
    var i = 0;
    while (true) {
      final l = i * 2 + 1, r = l + 1;
      var min = i;
      if (l < _what.length && _cost[l] < _cost[min]) min = l;
      if (r < _what.length && _cost[r] < _cost[min]) min = r;
      if (min == i) break;
      _swap(i, min);
      i = min;
    }
    return top;
  }

  void _swap(int a, int b) {
    final w = _what[a];
    _what[a] = _what[b];
    _what[b] = w;
    final c = _cost[a];
    _cost[a] = _cost[b];
    _cost[b] = c;
  }
}

/// Cuánta gente sale hoy a la calle, de cero a uno.
///
/// Un pueblo desatendido no es sólo un pueblo más gris: es un pueblo del que
/// la gente se va. Es la única manera que tiene el sitio de decir «llevás doce
/// días sin venir» sin escribirlo en ninguna parte, y dice mucho más que el
/// color.
///
/// Nunca llega a cero, igual que la integridad: siempre queda alguien.
double folkOut(double integrity) => clampD(0.22 + integrity * 0.86, 0.0, 1.0);

/// Lo dentro de casa que está la gente ahora mismo, de cero a uno.
///
/// Cero de día, uno de noche. Sale de la luz que hay y no de la hora, así que
/// en invierno se recogen antes — que es lo que pasa — sin que haya ninguna
/// hora escrita en ningún sitio.
///
/// La franja es ancha a propósito. Con una estrecha el pueblo se vaciaba en
/// diez minutos de reloj del valle, y un pueblo que se vacía de golpe es una
/// luz que se apaga: lo que tiene que verse es a todo el mundo tirando para su
/// casa mientras el sol baja, que es hora y media larga. Empieza en cuanto la
/// luz cede —no cuando ya es de noche— porque nadie espera a que oscurezca
/// para volver.
double folkHome(double daylight) => 1 - smoothstep(0.04, 0.88, daylight);

/// El paño con el que va vestida la gente de este valle.
///
/// Tintes que se sacaban de lo que había: rubia, gualda, glasto, nogal, y la
/// lana sin teñir, que era lo más barato y por eso lo más común. Nada
/// saturado — un vecino de tres píxeles con una camisa roja de semáforo se
/// lleva la mirada por delante del pueblo entero, que es lo contrario de lo
/// que hace falta.
const List<int> _cloth = [
  0xFF9A5A46, // rubia
  0xFF7E6B47, // nogal
  0xFF4F5F6E, // glasto
  0xFFA08650, // gualda
  0xFF8C8477, // lana sin teñir
  0xFF5E6B52, // verde de líquenes
  0xFF6E5566, // malva
];

/// Y la piel, que también tiene más de un color.
///
/// Doce y no cinco, y repartidos de verdad por todo el rango en vez de cuatro
/// tonos medios y uno oscuro. Un pueblo de cuarenta vecinos con cinco tonos se
/// ve como cinco personas repetidas ocho veces; con doce no se nota que haya
/// una lista detrás, que es justo lo que hay que conseguir.
const List<int> _skin = [
  0xFFF2D7BC,
  0xFFE8C4A0,
  0xFFDCB088,
  0xFFC79B77,
  0xFFBE8C68,
  0xFFAD7F5C,
  0xFF9C6E4E,
  0xFF8C6247,
  0xFF7A533C,
  0xFF6A4630,
  0xFF573827,
  0xFF462C1E,
];

/// Y el pelo, que es lo que se ve de una cabeza a esta distancia: una mancha
/// de color encima de la cara, que separa a dos vecinos mejor que la cara.
const List<int> _hair = [
  0xFF2B211A,
  0xFF3E2C1E,
  0xFF5A3C24,
  0xFF7A5330,
  0xFF9A7040,
  0xFFB89055,
  0xFF8A8178,
  0xFFD8D2C6,
  0xFF6B3A22,
];

/// El paño de la cometa. Tiene que cantar contra el cielo o no es una cometa:
/// es lo único de este valle que se mira desde abajo.
const List<int> _kite = [
  0xFFC94F3B,
  0xFFE08A2E,
  0xFF4C7FB5,
  0xFFD9B441,
  0xFF7E4B86,
  0xFFCC5E7E,
];

/// Y las mariposas, que son blancas, amarillas o de las anaranjadas.
const List<int> _wing = [0xFFF0EEE4, 0xFFEFCE52, 0xFFDC8434, 0xFFC9D8EC];

/// La madera de los mangos y las varas, que es la misma en todo el valle.
const int _wood2 = 0xFF6B5236;

/// Una persona, en cajas cerradas como todo lo demás del valle.
///
/// Cuatro piezas: dos piernas, el cuerpo y la cabeza. Con eso basta y sobra —
/// a la distancia a la que se mira un pueblo, un vecino ocupa entre tres y
/// veinte píxeles, y lo que se lee de él es la silueta y el color, no los
/// dedos. Lo que sí se lee, y mucho, es **que se mueva**: el paso de las
/// piernas y el bamboleo del cuerpo es lo que separa a una persona andando de
/// un palo deslizándose por el suelo.
///
/// [size] es lo que mide de alto, y sale de la altura de planta de la región:
/// una persona tiene que caber por su propia puerta, y las puertas de la
/// Sierra no miden lo que las de la Ribera.
///
/// [detail] baja de uno a cero con la distancia. Por debajo de la mitad se
/// quedan cuerpo y cabeza y se van las piernas, que a esa distancia son dos
/// píxeles que parpadean.
List<Solid> folkSolids(
  Townsfolk who,
  FolkAt at,
  double size, {
  double detail = 1.0,
  double lift = 0.0,
}) {
  final seed = who.seed;
  // Lo que mide éste. Un crío mide dos tercios de lo que mide su madre, y un
  // pueblo donde todos miden lo mismo es un pueblo de maniquíes.
  final h = size * who.build;
  final cos = math.cos(at.heading), sin = math.sin(at.heading);

  // Del sistema de la persona —adelante en +z, a su izquierda en +x— al del
  // valle. Girar aquí y no en cada caja es lo que mantiene esto legible.
  //
  // **Todo va en partes de lo que mide.** Lo ancho estaba en unidades del
  // valle y lo alto en partes de la persona, y eso quiere decir dos cosas
  // malas a la vez: que un crío sale tan ancho como su madre —o sea, un
  // barril— y que en la Sierra, donde las plantas son más altas, la gente sale
  // más alta pero igual de ancha. Con una sola unidad, una persona es la misma
  // persona en las seis regiones y a cualquier talla.
  V3 world(double x, double y, double z) => V3(
    at.x + (x * cos + z * sin) * h,
    lift + y * h,
    at.z + (-x * sin + z * cos) * h,
  );

  final out = <Solid>[];
  void box(
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
    int tint,
    double ao,
  ) {
    // Las ocho esquinas giradas, y de ahí las seis caras. No se puede usar
    // `boxFaces`: eso da una caja alineada a los ejes del mundo, y una persona
    // mira hacia donde va.
    final p = [
      world(x0, y0, z0),
      world(x1, y0, z0),
      world(x1, y0, z1),
      world(x0, y0, z1),
      world(x0, y1, z0),
      world(x1, y1, z0),
      world(x1, y1, z1),
      world(x0, y1, z1),
    ];
    final up = V3(0, 1, 0);
    final fwd = V3(sin, 0, cos), right = V3(cos, 0, -sin);
    out.add(
      Solid(-1, [
        Facet([p[3], p[2], p[6], p[7]], fwd, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [p[1], p[0], p[4], p[5]],
          V3(-fwd.x, 0, -fwd.z),
          Surface.cloth,
          ao: ao * 0.94,
          tint: tint,
        ),
        Facet(
          [p[1], p[5], p[6], p[2]],
          right,
          Surface.cloth,
          ao: ao * 0.97,
          tint: tint,
        ),
        Facet(
          [p[0], p[3], p[7], p[4]],
          V3(-right.x, 0, -right.z),
          Surface.cloth,
          ao: ao * 0.97,
          tint: tint,
        ),
        Facet([p[4], p[7], p[6], p[5]], up, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [p[0], p[1], p[2], p[3]],
          V3(0, -1, 0),
          Surface.cloth,
          ao: ao * 0.8,
          tint: tint,
        ),
      ]),
    );
  }

  final pano = _cloth[hashInt(_cloth.length, seed, 2)];
  final piel = _skin[hashInt(_skin.length, seed, 3)];
  // La falda del sayo, de otro tono: el mismo paño más sucio de andar.
  final calzas = _cloth[hashInt(_cloth.length, seed, 4)];
  final pelo = _hair[hashInt(_hair.length, seed, 5)];

  final act = at.act;
  final ph = at.phase;

  // El cuerpo entero sale de cinco números de la tabla. No hay un caso por
  // actividad: hay una manera de moverse, y sesenta juegos de números.
  final sit = act?.sink ?? 0.0;
  final baja = sit * 0.26;

  // Lo único que anima a alguien sin brazos ni piernas: que suba y baje, que
  // se incline y que se balancee. Y alcanza de sobra — el paso de unas piernas
  // de dos píxeles no se ve, y el bamboleo de un cuerpo entero sí.
  //
  // Andando sube y baja dos veces por zancada, una por pie que no está ahí.
  // Parado, lo que diga lo que esté haciendo: el que habla se mueve, el que
  // pica piedra dobla el espinazo, el que baila da saltos, y el que no hace
  // nada respira.
  final swing = act == null
      ? 0.0
      : math.sin(ph * act.rate + hash01(seed, 16) * 6);
  final bob = at.moving
      ? math.cos(at.gait * 2) * 0.016
      : (act == null
            ? 0.0
            : act.bob * (act.bob < 0 ? math.max(0.0, swing) : swing));
  final wag = at.moving ? math.sin(at.gait) * 0.014 : (act?.wag ?? 0.0) * swing;
  final lean = at.moving ? 0.020 : (act?.lean ?? 0.0);

  /// Dónde le flota lo que lleva. No hay mano: hay un sitio a la altura y al
  /// lado de donde estaría, y lo que se sostiene se queda ahí. A esta
  /// distancia es lo mismo, y una mano de tres píxeles no es una mano.
  (double, double, double) hold(double s, double raise, double fwd) =>
      (s * 0.155 + wag, 0.50 + raise * 0.34 + bob - baja, 0.13 + fwd + lean);

  /// Una vara entre dos puntos: el hilo de la cometa, su cola, el mango de una
  /// herramienta, la cuerda de un caldero. [box] sólo sabe hacer cajas rectas
  /// en el sistema de la persona, y una cuerda va en diagonal.
  void link(
    (double, double, double) a,
    (double, double, double) b,
    double r,
    int tint,
    double ao,
  ) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2, dz = b.$3 - a.$3;
    final len = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (len < 1e-5) return;
    final u = V3(dx / len, dy / len, dz / len);
    // Un perpendicular cualquiera, evitando el caso en que la vara es vertical.
    var pv = u.y.abs() > 0.9 ? V3(1, 0, 0) : V3(0, 1, 0);
    pv = (pv - u * pv.dot(u)).normalized;
    final q = u.cross(pv).normalized;
    V3 corner(double sa, double sp, double sq) {
      final at0 = sa < 0 ? a : b;
      return world(
        at0.$1 + (pv.x * sp + q.x * sq) * r,
        at0.$2 + (pv.y * sp + q.y * sq) * r,
        at0.$3 + (pv.z * sp + q.z * sq) * r,
      );
    }

    // Índice = extremo * 4 + p * 2 + q.
    final c = [
      for (final sa in [-1.0, 1.0])
        for (final sp in [-1.0, 1.0])
          for (final sq in [-1.0, 1.0]) corner(sa, sp, sq),
    ];
    V3 turn(V3 v) =>
        V3(v.x * cos + v.z * sin, v.y, -v.x * sin + v.z * cos).normalized;
    final pw = turn(pv), qw = turn(q), uw = turn(u);
    out.add(
      Solid(-1, [
        Facet([c[2], c[3], c[7], c[6]], pw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[1], c[0], c[4], c[5]],
          V3(-pw.x, -pw.y, -pw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
        Facet([c[3], c[1], c[5], c[7]], qw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[0], c[2], c[6], c[4]],
          V3(-qw.x, -qw.y, -qw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
        Facet([c[5], c[4], c[6], c[7]], uw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[0], c[1], c[3], c[2]],
          V3(-uw.x, -uw.y, -uw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
      ]),
    );
  }

  /// Un paño plano, dado por sus esquinas en el plano de delante de la
  /// persona. La vela de la cometa, que es un rombo y no una caja: [box] sólo
  /// sabe hacer cajas rectas y un rombo está girado cuarenta y cinco grados.
  void panel(
    List<(double, double, double)> pts,
    double thick,
    int tint,
    double ao,
  ) {
    final fwd = V3(sin, 0, cos);
    final back = V3(-fwd.x, 0, -fwd.z);
    final a = [for (final q in pts) world(q.$1, q.$2, q.$3 - thick)];
    final b = [for (final q in pts) world(q.$1, q.$2, q.$3 + thick)];
    final faces = <Facet>[
      Facet(b, fwd, Surface.cloth, ao: ao, tint: tint),
      Facet(a.reversed.toList(), back, Surface.cloth, ao: ao, tint: tint),
    ];
    for (var i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      // El canto: hacia afuera en el plano del paño.
      final dx = pts[j].$1 - pts[i].$1, dy = pts[j].$2 - pts[i].$2;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-6) continue;
      final nx = dy / len, ny = -dx / len;
      faces.add(
        Facet(
          [a[i], a[j], b[j], b[i]],
          V3(nx * cos, ny, -nx * sin).normalized,
          Surface.cloth,
          ao: ao * 0.94,
          tint: tint,
        ),
      );
    }
    out.add(Solid(-1, faces));
  }

  // La figura: el sayo abajo, los hombros arriba, la cabeza y el pelo. Cuatro
  // cajas y ninguna extremidad.
  //
  // Sin brazos y sin piernas a propósito, y no por ahorrar caras. Un vecino
  // ocupa entre tres y veinte píxeles: unas piernas ahí son dos rayas que
  // parpadean y unos brazos son una mancha que ensancha la silueta hasta que
  // deja de parecer una persona. Lo que se lee a esa distancia es **la
  // silueta, el color y el movimiento**, y los tres salen mejor de una figura
  // limpia. Es además lo que hace el resto del valle: una casa tampoco tiene
  // picaporte.
  final pie = math.max(0.0, 0.44 - sit * 0.16);
  box(
    -0.140 + wag,
    0.0,
    -0.106,
    0.140 + wag,
    pie + bob * 0.4,
    0.106,
    calzas,
    0.90,
  );
  box(
    -0.116 + wag * 0.6,
    pie - 0.05 + bob * 0.7,
    -0.088 + lean * 0.7,
    0.116 + wag * 0.6,
    0.80 + bob - baja,
    0.088 + lean * 0.7,
    pano,
    1.0,
  );
  box(
    -0.074,
    0.775 + bob - baja,
    -0.070 + lean * 1.6,
    0.074,
    0.975 + bob - baja,
    0.070 + lean * 1.6,
    piel,
    1.02,
  );
  // El pelo, que es media caja encima de la cara. A quince píxeles la cara es
  // un punto y el pelo es la mitad de la cabeza: es lo que hace que dos
  // vecinos no se confundan de lejos.
  if (detail > 0.25) {
    box(
      -0.078,
      0.912 + bob - baja,
      -0.074 + lean * 1.6,
      0.078,
      0.995 + bob - baja,
      0.074 + lean * 1.6,
      pelo,
      1.0,
    );
  }

  // Y lo que lleva, que flota donde lo tendría. De eso va la tarde.
  //
  // Quince formas para setenta actividades. La diferencia entre un gato y un
  // cesto, a doce píxeles, es el tamaño y el color; gastar una geometría
  // propia por cada cosa sería gastarla justo en lo que no se ve. Lo que sí se
  // ve, y mucho, es que haya **algo** y que ese algo se mueva.
  if (act == null || detail <= 0.1) return out;
  final tinte = act.tint ?? pano;
  final z = act.size;
  final t = ph + hash01(seed, 17) * 40;

  switch (act.prop) {
    case PropKind.none:
      break;

    case PropKind.hand:
      // Lo que se lleva en la mano: un jarro, un pan, una flor, un farol.
      final m = hold(1, 0.28 + swing * 0.10, 0.02);
      final r = 0.052 * z;
      box(
        m.$1 - r,
        m.$2 - r,
        m.$3 - r,
        m.$1 + r,
        m.$2 + r * 1.5,
        m.$3 + r,
        tinte,
        1.0,
      );

    case PropKind.tool:
      // Mango y cabeza. Sube y baja con el mismo compás que el espinazo, que
      // es lo que hace que el golpe caiga cuando el cuerpo se dobla.
      final g = math.sin(ph * act.rate) * 0.5 + 0.5;
      final m = hold(1, 0.30 + g * 0.62, 0.05);
      link(m, (m.$1 + 0.02, m.$2 + 0.17 * z, m.$3 + 0.07), 0.020, _wood2, 0.90);
      box(
        m.$1 - 0.022 * z,
        m.$2 + 0.15 * z,
        m.$3 + 0.030,
        m.$1 + 0.080 * z,
        m.$2 + 0.205 * z,
        m.$3 + 0.115,
        tinte,
        0.92,
      );

    case PropKind.pole:
      // Una vara larga que apunta a donde diga la tabla: la caña al agua, la
      // escoba al suelo, el cayado al hombro.
      final m = hold(1, 0.42, 0.02);
      final largo = 0.95 * z;
      link(
        m,
        (
          m.$1 + 0.04,
          m.$2 + math.sin(act.aim) * largo,
          m.$3 + math.cos(act.aim) * largo,
        ),
        0.016,
        tinte,
        0.94,
      );

    case PropKind.kite:
      // La cometa: un rombo de paño que se mueve solo, muy por encima y por
      // delante, con su cola y su hilo. Es lo único de este valle que se mira
      // hacia arriba, y desde lejos una cometa sobre un prado dice «aquí vive
      // gente» mejor que cuarenta personas andando. Por eso no se va con la
      // distancia aunque su dueño se quede en cuatro píxeles.
      final kx = math.sin(t * 0.43) * 0.95;
      final ky = 3.10 + math.sin(t * 0.31 + 1.1) * 0.22;
      final kz = 1.55 + math.cos(t * 0.37) * 0.30;
      final tela = _kite[hashInt(_kite.length, seed, 18)];
      const ala = 0.30, alto = 0.40;
      final papel = [
        (kx, ky + alto, kz),
        (kx + ala, ky, kz),
        (kx, ky - alto, kz),
        (kx - ala, ky, kz),
      ];
      panel(papel, 0.012, tela, 1.06);
      link(papel[0], papel[2], 0.016, _wood2, 0.92);
      link(papel[3], papel[1], 0.014, _wood2, 0.92);
      for (var k = 1; k <= 3; k++) {
        final w2 = math.sin(t * 1.3 - k * 0.8) * 0.085 * k;
        link(
          (kx + w2 * 0.6, ky - alto - (k - 1) * 0.21, kz),
          (kx + w2, ky - alto - k * 0.21, kz),
          0.026,
          tela,
          1.0,
        );
      }
      link(hold(1, 0.85, 0.0), (kx, ky - alto, kz), 0.007, 0xFFEDE4D2, 1.05);

    case PropKind.flyer:
      // Lo que revolotea y no se deja: la mariposa, la abeja, el pájaro. Va
      // por su cuenta — no la sigue él a ella, es ella la que se le escapa.
      if (detail < 0.5) break;
      final mx = math.sin(t * 1.05) * 0.34 * z + 0.12;
      final my = 0.86 + math.sin(t * 1.7 + 0.7) * 0.22 * z;
      final mz = 0.42 + math.cos(t * 0.83) * 0.18 * z;
      final tono = act.tint ?? _wing[hashInt(_wing.length, seed, 20)];
      // El aleteo: las alas se abren y se cierran nueve veces por segundo, que
      // es lo que hace que un punto de color sea un bicho.
      final flap = ((math.sin(t * 9.0) * 0.5 + 0.5) * 0.060 + 0.014) * z;
      for (final w in [1.0, -1.0]) {
        box(
          mx + (w > 0 ? 0.005 : -0.005 - flap),
          my - 0.005 * z,
          mz - 0.034 * z,
          mx + (w > 0 ? 0.005 + flap : -0.005),
          my + 0.005 * z,
          mz + 0.034 * z,
          tono,
          1.08,
        );
      }

    case PropKind.floor:
      // Algo en el suelo, delante: el barco de papel, el carrito, el gato, las
      // gallinas, la peonza. Un bulto y un remate encima, que es todo lo que
      // hace falta para que se lea un animal o un cacharro.
      final bx = 0.10 + math.sin(t * 0.5) * 0.05 * z;
      final bz = 0.40 + math.cos(t * 0.4) * 0.04 * z;
      final w2 = 0.085 * z, alto2 = 0.10 * z;
      box(
        bx - w2,
        0.0,
        bz - w2 * 1.3,
        bx + w2,
        alto2,
        bz + w2 * 1.3,
        tinte,
        0.9,
      );
      box(
        bx - w2 * 0.55,
        alto2 * 0.85,
        bz + w2 * 0.3,
        bx + w2 * 0.55,
        alto2 * 1.85,
        bz + w2 * 1.35,
        tinte,
        0.98,
      );

    case PropKind.seat:
      // Una banqueta. Quien la tiene se sienta en ella, y por eso el asiento
      // queda justo donde la tabla le ha bajado el cuerpo.
      box(-0.130, 0.0, -0.115, 0.130, 0.26 - baja * 0.5, 0.115, tinte, 0.86);

    case PropKind.back:
      // El fardo: un haz de leña, un saco. A la espalda y un poco por encima
      // del hombro, que es como se carga.
      box(
        -0.115 * z + wag,
        0.46 - baja,
        -0.20 * z - 0.06,
        0.115 * z + wag,
        0.80 - baja + bob,
        -0.07,
        tinte,
        0.88,
      );

    case PropKind.board:
      // Una tabla, de dos maneras según a dónde apunte: tendida delante —la
      // artesa, la tabla de lavar, el madero que se sierra— o de canto y
      // agarrada con las dos manos —la vihuela, el libro, el pregón, el
      // tablero de las tablas—. Es el mismo sólido; lo que cambia es de qué
      // canto se ve, y con eso se lee una cosa o la otra.
      final m = hold(1, 0.22, 0.05);
      final w2 = 0.15 * z, alto2 = 0.14 * z;
      if (act.aim <= -0.5) {
        box(
          m.$1 - w2 - 0.12,
          m.$2 - 0.02,
          m.$3,
          m.$1 + w2 - 0.12,
          m.$2 + 0.02,
          m.$3 + alto2 * 2,
          tinte,
          1.0,
        );
      } else {
        box(
          -w2 + wag,
          m.$2 - alto2,
          m.$3 + 0.01,
          w2 + wag,
          m.$2 + alto2,
          m.$3 + 0.05,
          tinte,
          1.02,
        );
      }

    case PropKind.ball:
      // Algo redondo que sube y baja por el aire: las bolas de los malabares,
      // la piedra antes de caer al agua, el palo del perro.
      final k = (math.sin(t * 2.4) * 0.5 + 0.5);
      final bx = 0.05 + k * 0.14;
      final by = 0.62 + math.sin(t * 2.4) * 0.42 * z;
      final r = 0.045 * z;
      box(bx - r, by - r, 0.24, bx + r, by + r, 0.24 + r * 2, tinte, 1.05);

    case PropKind.rope:
      // Una cuerda de la mano a algo: el caldero del pozo, el cordel del
      // carrito, la cabra, la cuerda de medir. [aim] dice si va al suelo por
      // delante o hacia arriba.
      final m = hold(1, 0.36 + swing * 0.12, 0.02);
      final fin = act.aim >= 0
          ? (0.16, 0.06 * z, 0.52 + 0.22 * z)
          : (0.16, 0.95, 0.30);
      link(m, fin, 0.008, 0xFFC9B999, 1.0);
      final r = 0.070 * z;
      box(
        fin.$1 - r,
        fin.$2,
        fin.$3 - r,
        fin.$1 + r,
        fin.$2 + r * 1.6,
        fin.$3 + r,
        tinte,
        0.94,
      );

    case PropKind.puff:
      // Humo, o vaho: tres bocanadas que suben y se deshacen. Lo único de una
      // persona que se ve cuando ya no se ve la persona.
      for (var k = 0; k < 3; k++) {
        final u = ((t * 0.55 + k / 3) % 1.0);
        final r = (0.035 + u * 0.055) * z;
        if (u > 0.86) continue;
        box(
          0.08 + math.sin(u * 5 + k) * 0.05 - r,
          0.24 + u * 0.62,
          0.34 - r,
          0.08 + math.sin(u * 5 + k) * 0.05 + r,
          0.24 + u * 0.62 + r,
          0.34 + r,
          0xFFD8D4CC,
          1.10,
        );
      }

    case PropKind.hoop:
      // Un aro de canto, al lado, rodando. Ocho varas: a esta distancia es un
      // círculo, y un círculo de verdad serían cuarenta caras por un crío.
      if (detail < 0.35) break;
      const r = 0.27;
      final cx = 0.26, cy = r + 0.02, cz = 0.16;
      final gira = t * 2.2;
      final vueltas = [
        for (var k = 0; k < 8; k++)
          (
            cx + math.cos(gira + k * math.pi / 4) * r * 0.35,
            cy + math.sin(gira + k * math.pi / 4) * r,
            cz + math.cos(gira + k * math.pi / 4) * r * 0.94,
          ),
      ];
      for (var k = 0; k < 8; k++) {
        link(vueltas[k], vueltas[(k + 1) % 8], 0.018, tinte, 0.96);
      }

    case PropKind.plant:
      // Lo que crece delante, a ras de suelo: la mata de flores, el bancal del
      // huerto.
      for (var k = 0; k < 3; k++) {
        final px = 0.02 + (k - 1) * 0.15;
        final alto2 = (0.12 + hash01(seed, 40 + k) * 0.10) * z;
        box(
          px - 0.030,
          0.0,
          0.40 - 0.030,
          px + 0.030,
          alto2,
          0.40 + 0.030,
          0xFF4F7A34,
          0.92,
        );
        box(
          px - 0.042,
          alto2,
          0.40 - 0.042,
          px + 0.042,
          alto2 + 0.055 * z,
          0.40 + 0.042,
          tinte,
          1.06,
        );
      }
  }

  return out;
}
