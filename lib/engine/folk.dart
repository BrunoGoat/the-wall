import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/math3.dart';
import '../core/rng.dart';
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
    this._stops,
    this._stay,
    this._facing,
    this.period,
  );

  /// El edificio en el que vive, que es el que lo puso en el mundo.
  final int home;
  final int seed;

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
        );
      }
      acc += walk;
      walked += d;
      final stay = _stay[(i + 1) % n];
      if (u < acc + stay) {
        // Parado: mirando a donde vino a mirar, con un balanceo lento que es
        // lo que separa a alguien esperando de un poste.
        final look = _facing[(i + 1) % n];
        final sway = math.sin((u - acc) * 0.7 + hash01(seed, 9) * 6) * 0.18;
        return FolkAt(to.$1, to.$2, look + sway, 0, false);
      }
      acc += stay;
    }
    final last = _stops.first;
    return FolkAt(last.$1, last.$2, _facing.first, 0, false);
  }
}

/// Una persona en un instante: dónde está, hacia dónde mira, y por dónde va su
/// paso.
class FolkAt {
  const FolkAt(this.x, this.z, this.heading, this.gait, this.moving);
  final double x, z;

  /// Hacia dónde mira, en radianes, como el `yaw` de la cámara.
  final double heading;

  /// La fase del paso, en radianes. Cero cuando está quieto.
  final double gait;
  final bool moving;
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
  final key = '${layout.cx},${layout.cz},${layout.character.order}';
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
  final sitios = <(double x, double z, double reach)>[
    (layout.cx, layout.cz, 0.9),
  ];
  for (final b in layout.buildings) {
    if (!b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    final c = huella[b.index];
    sitios.add((b.cx, b.cz, (c == null ? b.reach : _spanOf(c)) + 0.55));
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
    ));
  }

  final out = <Townsfolk>[];
  for (final b in casas) {
    final seed = hash32(b.seed, 0xF01C, b.index);
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
    final stops = <(double, double)>[door];
    final dwell = <double>[0.0];
    // Al volver a casa mira a la puerta, que es lo suyo.
    final look = <double>[math.atan2(-dx, -dz)];
    for (var k = 0; k < 3; k++) {
      final s = sitios[hashInt(sitios.length, seed, 20 + k)];
      // Alrededor del sitio y no encima: se ponen en corro mirando al medio,
      // que es lo que hace la gente delante de un tablón o de una fuente.
      final a = hash01(seed, 30 + k) * 2 * math.pi;
      stops.add(
        calles.onStreets((
          s.$1 + math.sin(a) * s.$3,
          s.$2 + math.cos(a) * s.$3,
        )),
      );
      look.add(math.atan2(-math.sin(a), -math.cos(a)));
      dwell.add(hashRange(5.0, 15.0, seed, 40 + k));
    }

    // El camino de verdad: los recados, y los quiebros para no meterse por
    // dentro de las casas que queden en medio.
    //
    // En casa no se para: entrar por la puerta y volver a salir sería una
    // persona parpadeando en el umbral, así que la ronda sigue.
    final path = <(double, double)>[];
    final stay = <double>[];
    final facing = <double>[];
    for (var i = 0; i < stops.length; i++) {
      final from = stops[i], to = stops[(i + 1) % stops.length];
      path.add(from);
      stay.add(dwell[i]);
      facing.add(look[i]);
      for (final q in calles.route(from, to)) {
        path.add(q);
        // Un paso del camino no es un sitio al que se va: ni se para en él ni
        // se queda mirando nada.
        stay.add(0);
        facing.add(look[i]);
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
      Townsfolk._(b.index, seed, path, stay, facing, math.max(period, 1)),
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
const List<int> _skin = [
  0xFFC79B77,
  0xFF8C6247,
  0xFFE3BE9B,
  0xFF6A4630,
  0xFFA87A57,
];

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
  final h = size * (0.93 + hash01(seed, 1) * 0.15);
  final cos = math.cos(at.heading), sin = math.sin(at.heading);

  // Del sistema de la persona —adelante en +z, a su izquierda en +x— al del
  // valle. Girar aquí y no en cada caja es lo que mantiene esto legible.
  V3 world(double x, double y, double z) =>
      V3(at.x + x * cos + z * sin, lift + y * h, at.z - x * sin + z * cos);

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
  // Las piernas de otro tono: calzas, o el mismo paño más sucio de andar.
  final calzas = _cloth[hashInt(_cloth.length, seed, 4)];

  // El bamboleo. Un cuerpo que anda sube y baja dos veces por zancada —una por
  // pierna— y se inclina un punto hacia adelante. Sin esto, una persona es una
  // pieza de ajedrez que se desliza.
  final bob = at.moving ? math.cos(at.gait * 2) * 0.012 : 0.0;
  final lean = at.moving ? 0.02 : 0.0;

  if (detail > 0.5) {
    final swing = math.sin(at.gait) * 0.13;
    for (final s in [1.0, -1.0]) {
      final paso = swing * s;
      // La pierna adelantada se levanta un poco del suelo, que es de donde
      // sale la sensación de que pisa y no de que patina.
      final alza = math.max(0.0, paso) * 0.22;
      box(
        s * 0.072 - 0.058,
        alza,
        paso - 0.05,
        s * 0.072 + 0.058,
        // Hasta por encima de donde empieza el tronco: solapadas, porque dos
        // cajas que se tocan justo dejan una raya de fondo entre ellas en
        // cuanto la cámara se mueve un grado.
        0.50 + bob,
        paso + 0.05,
        calzas,
        0.88,
      );
    }
  }

  // El cuerpo, más ancho de hombros que de cintura sin gastar otra caja: se
  // inclina hacia adelante y basta.
  box(
    -0.15,
    (detail > 0.5 ? 0.44 : 0.0) + bob,
    -0.093 + lean,
    0.15,
    0.83 + bob,
    0.093 + lean,
    pano,
    1.0,
  );
  // La cabeza, de una séptima parte del alto: menos que eso y no se ve, más y
  // es un muñeco. Y un poco más adelantada que el tronco, porque el tronco va
  // inclinado hacia donde anda.
  box(
    -0.088,
    0.82 + bob,
    -0.082 + lean * 1.7,
    0.088,
    0.99 + bob,
    0.082 + lean * 1.7,
    piel,
    1.02,
  );
  return out;
}
