/// Un valle de mentira, para poder mirar el tablón con algo escrito en él.
///
/// El tablón sólo habla cuando tiene bastante detrás: una hora que se repita
/// en siete de cada diez piezas, un día de la semana que se despegue del
/// resto, media docena de huecos remontados. Un pueblo recién fundado no le
/// da nada de eso, así que hasta ahora la única manera de ver el tablón lleno
/// era usar la app durante un año.
///
/// Esto es ese año, inventado: un hábito de entrenar con unas doscientas
/// piezas repartidas por trescientos días, y otro de leer al lado para que
/// existan las notas que comparan dos pueblos. Nada de esto se guarda ni toca
/// el valle de verdad: se construye al abrirlo y se tira al cerrarlo.
///
/// Todo sale de [hash01] y de la fecha del día, así que el mismo día enseña
/// siempre el mismo pueblo — se puede volver a mirar una nota y seguir ahí.
library;

import '../core/rng.dart';
import '../model/habit.dart';
import '../model/piece.dart';

/// Los dos pueblos, el de entrenar primero.
List<Habit> demoValley([DateTime? at]) {
  final today = dayStart(at ?? DateTime.now());
  final entrenar = _entrenar(today);
  return [entrenar, _leer(today, entrenar)];
}

/// Cuántos días hacia atrás llega la historia inventada.
const int _span = 300;

/// Con qué ganas se entrena cada día de la semana, de lunes a domingo.
///
/// No es un adorno: es lo que hace que el tablón tenga algo que decir. Un
/// reparto plano daría siete barras iguales y ninguna nota de la semana, que
/// es justamente lo que no se puede probar sin datos así.
const List<double> _ganas = [0.96, 0.74, 0.96, 0.74, 0.93, 0.68, 0.2];

/// Y lo que queda de esas ganas el día después de haberse saltado uno.
///
/// Tampoco es un adorno. Es lo que le pasa a casi todo el mundo —un día en
/// blanco se lleva al siguiente— y es lo que hace que la nota que mide
/// justamente eso tenga algo que medir. Sin esto los huecos caen sueltos, el
/// día de después de faltar es un día cualquiera, y el tablón se calla.
const double _bajon = 0.6;

/// Los dos huecos: una semana y media de gripe y dos de vacaciones.
///
/// A cuántos días del final empieza cada uno, y cuánto dura.
const List<(int, int)> _huecos = [(214, 10), (96, 14)];

bool _enHueco(int back) {
  for (final (desde, dura) in _huecos) {
    if (back <= desde && back > desde - dura) return true;
  }
  return false;
}

/// Lo que uno escribe en una pieza de entrenar, y a qué hora suele caer.
///
/// Las de fuerza son de tarde y las de calle de mañana, que es la manera en
/// que la gente entrena de verdad: la bici y la carrera antes de trabajar, el
/// gimnasio al salir.
const List<(String, bool)> _entrenos = [
  ('Andar en bici', true),
  ('Correr 5k', true),
  ('Saltar cuerda', true),
  ('Nadar', true),
  ('Caminata larga', true),
  ('Gimnasio', false),
  ('Pesas', false),
  ('Espalda y hombros', false),
  ('Piernas', false),
  ('Estiramientos', false),
];

const List<String> _lecturas = [
  'Veinte páginas',
  'Un capítulo',
  'Antes de dormir',
  'Media hora',
  'Terminé el libro',
  'Ensayo corto',
];

Habit _entrenar(DateTime today) {
  final pieces = <Piece>[];
  var enBlanco = false;
  for (var back = _span; back >= 0; back--) {
    final day = today.subtract(Duration(days: back));
    final key = dayKey(day);
    var ganas = _ganas[day.weekday - 1];
    if (enBlanco) ganas *= _bajon;
    if (_enHueco(back) || hash01(key, 1) > ganas) {
      enBlanco = true;
      continue;
    }
    enBlanco = false;
    // Casi siempre una, que es lo normal, y de vez en cuando dos: el día que
    // se corre a la mañana y se va al gimnasio a la tarde.
    final veces = hash01(key, 2) < 0.15 ? 2 : 1;
    for (var k = 0; k < veces; k++) {
      // La primera del día es de mañana cuatro de cada cinco veces; la
      // segunda, si la hay, es siempre de tarde.
      final manana = k == 0 && hash01(key, 3) < 0.86;
      final quiere = <int>[
        for (var i = 0; i < _entrenos.length; i++)
          if (_entrenos[i].$2 == manana) i,
      ];
      final cual = quiere[hashInt(quiere.length, key, 4, k)];
      pieces.add(
        Piece(
          index: pieces.length,
          placedAt: _hora(day, manana, key, k),
          // Poco más de la mitad de las piezas llevan leyenda, que es lo que
          // pasa de verdad: escribir es opcional y se escribe cuando hay algo
          // que decir.
          label: hash01(key, 5, k) < 0.55 ? _entrenos[cual].$1 : null,
        ),
      );
    }
  }
  return Habit(
    id: 'demo-entrenar',
    name: 'Entrenar',
    symbol: 'pesa',
    slot: 0,
    createdAt: today.subtract(const Duration(days: _span)),
    pieces: pieces,
  );
}

/// La hora en que cae una pieza de entrenar.
///
/// Entre semana, temprano: entre las seis y media y las ocho y media, antes de
/// que empiece el día. El fin de semana se duerme un poco más y se sale a las
/// ocho. Y lo de la tarde, al salir del trabajo, entre las siete y las nueve.
DateTime _hora(DateTime day, bool manana, int key, int k) {
  final finde = day.weekday >= 6;
  final desde = manana ? (finde ? 7.6 : 6.5) : 19.0;
  final hasta = manana ? (finde ? 8.9 : 8.6) : 20.8;
  final t = desde + (hasta - desde) * hash01(key, 6, k);
  return DateTime(
    day.year,
    day.month,
    day.day,
    t.floor(),
    ((t % 1) * 60).round(),
  );
}

/// El pueblo de al lado, para que existan las notas que comparan dos hábitos.
///
/// Leer va enganchado a entrenar sin ser lo mismo: el día que se entrena se
/// lee bastante más que el día que no. Es la forma que tiene que tener para
/// que la nota del par diga algo en vez de dos barras iguales.
Habit _leer(DateTime today, Habit entrenar) {
  final entrenados = <int>{
    for (final p in entrenar.pieces) dayKey(dayStart(p.placedAt)),
  };
  final pieces = <Piece>[];
  // Empieza más tarde que entrenar: dos hábitos fundados el mismo día es la
  // clase de coincidencia que sólo pasa en los datos inventados.
  for (var back = _span - 62; back >= 0; back--) {
    final day = today.subtract(Duration(days: back));
    final key = dayKey(day);
    final ganas = entrenados.contains(key) ? 0.72 : 0.24;
    if (hash01(key, 11) > ganas) continue;
    final t = 21.5 + 1.6 * hash01(key, 12);
    pieces.add(
      Piece(
        index: pieces.length,
        placedAt: DateTime(
          day.year,
          day.month,
          day.day,
          t.floor(),
          ((t % 1) * 60).round(),
        ),
        label: hash01(key, 13) < 0.4
            ? _lecturas[hashInt(_lecturas.length, key, 14)]
            : null,
      ),
    );
  }
  return Habit(
    id: 'demo-leer',
    name: 'Leer',
    symbol: 'libro',
    slot: 1,
    createdAt: today.subtract(const Duration(days: _span - 62)),
    pieces: pieces,
  );
}
