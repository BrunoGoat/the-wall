/// Las constelaciones que se pueden ver desde el pueblo, y son de verdad.
///
/// Cada estrella lleva su ascensión recta y su declinación reales, en el
/// sistema J2000, que es el catálogo con el que trabaja cualquiera que apunte
/// un telescopio. No están «inspiradas en»: son las coordenadas, y por eso la
/// figura que sale en pantalla es la que se ve levantando la cabeza.
///
/// Lo que **no** hay aquí es una esfera celeste con tiempo sidéreo: esto es una
/// app de hábitos y no un planetario, y simular la rotación de la Tierra para
/// que Orión salga por el este a la hora que le toca sería un motor entero al
/// servicio de un detalle. Lo que se hace es más honesto y más barato: se toma
/// la forma real —los ángulos entre sus estrellas, que es lo que la hace
/// reconocible— y se cuelga entera de un sitio del cielo.
///
/// Cómo se conserva la forma: se calcula la dirección media del grupo y se
/// mide cada estrella contra ella en el plano tangente, en radianes al este y
/// al norte. Colgarla después en otro sitio del cielo es rehacer ese mismo
/// plano tangente allí. Como una constelación abarca entre diez y cuarenta
/// grados, la distorsión es la misma que tiene cualquier foto de ese trozo de
/// cielo — que es exactamente la que tiene la pantalla, porque la pantalla
/// también es una proyección gnomónica.
library;

import 'dart:math' as math;

/// Una estrella: dónde está y cuánto brilla.
class Star {
  const Star(this.ra, this.dec, this.mag);

  /// Ascensión recta, en horas. Declinación, en grados. J2000.
  final double ra, dec;

  /// Magnitud aparente. Al revés de lo que parece: cuanto más chica, más
  /// brilla — Sirio está en menos uno y media, y lo que se ve a ojo desnudo
  /// desde un pueblo sin luz llega a seis.
  final double mag;
}

/// Una figura: sus estrellas y qué se une con qué.
class Constellation {
  const Constellation(
    this.id,
    this.name,
    this.latin,
    this.blurb,
    this.stars,
    this.lines,
  );

  /// Nunca cambia: es lo que se guarda cuando alguien la registra.
  final String id;
  final String name;
  final String latin;

  /// Una línea sobre ella, para cuando se anota.
  final String blurb;

  final List<Star> stars;

  /// Pares de índices en [stars]: los trazos de la figura.
  final List<int> lines;

  /// Dónde cae cada estrella respecto del centro del grupo, en radianes: al
  /// este la primera, al norte la segunda.
  ///
  /// Se calcula una vez y se guarda fuera de la clase, porque el catálogo es
  /// `const` —una constelación no cambia nunca y no tiene por qué ocupar un
  /// montón— y una clase con un campo que se rellena después no puede serlo.
  List<(double, double)> get shape => _shapes[id] ??= _measure();

  /// Cuánto ocupa de lado a lado, en radianes. Para colgarla a una altura
  /// donde entre entera.
  double get spread => _spreads[id] ??= _measureSpread();

  static List<double> _unit(Star s) {
    final ra = s.ra * math.pi / 12.0;
    final dec = s.dec * math.pi / 180.0;
    final cd = math.cos(dec);
    return [cd * math.cos(ra), cd * math.sin(ra), math.sin(dec)];
  }

  List<(double, double)> _measure() {
    // La dirección media del grupo, normalizada.
    var mx = 0.0, my = 0.0, mz = 0.0;
    for (final s in stars) {
      final v = _unit(s);
      mx += v[0];
      my += v[1];
      mz += v[2];
    }
    final ln = math.sqrt(mx * mx + my * my + mz * mz);
    mx /= ln;
    my /= ln;
    mz /= ln;

    // Y una base local en ella: el este es perpendicular al eje del mundo, el
    // norte cierra el triedro. Es la misma base que usa cualquier carta
    // celeste, y por eso la figura sale con el norte arriba.
    var ex = -my, ey = mx, ez = 0.0;
    var el = math.sqrt(ex * ex + ey * ey);
    if (el < 1e-9) {
      // Justo en un polo: cualquier este vale, pero hay que elegir uno.
      ex = 1.0;
      ey = 0.0;
      el = 1.0;
    }
    ex /= el;
    ey /= el;
    final nx = my * ez - mz * ey;
    final ny = mz * ex - mx * ez;
    final nz = mx * ey - my * ex;

    return [
      for (final s in stars)
        () {
          final v = _unit(s);
          // Plano tangente: se divide por la componente hacia el centro, que
          // es lo que hace que esto sea gnomónico y no una deformación.
          final along = v[0] * mx + v[1] * my + v[2] * mz;
          final k = 1.0 / (along.abs() < 1e-6 ? 1e-6 : along);
          return (
            (v[0] * ex + v[1] * ey + v[2] * ez) * k,
            (v[0] * nx + v[1] * ny + v[2] * nz) * k,
          );
        }(),
    ];
  }

  double _measureSpread() {
    var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (final (x, y) in shape) {
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
    return math.max(x1 - x0, y1 - y0);
  }
}

/// Ocho, elegidas por ser las que cualquiera reconoce.
const List<Constellation> constellations = [
  Constellation(
    'orion',
    'Orión',
    'Orion',
    'El cazador. Las tres del cinturón son las tres estrellas más fáciles de '
        'encontrar del cielo entero.',
    [
      Star(5.9195, 7.407, 0.5), // Betelgeuse
      Star(5.4188, 6.350, 1.6), // Bellatrix
      Star(5.5334, -0.299, 2.2), // Mintaka
      Star(5.6036, -1.202, 1.7), // Alnilam
      Star(5.6793, -1.943, 1.8), // Alnitak
      Star(5.7959, -9.670, 2.1), // Saiph
      Star(5.2423, -8.202, 0.1), // Rigel
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 0, 4, 5, 5, 6, 6, 2],
  ),
  Constellation(
    'osamayor',
    'Osa Mayor',
    'Ursa Major',
    'El Carro. Los dos de la caja, prolongados, dan siempre con la estrella '
        'polar: es la brújula de quien no la tiene.',
    [
      Star(11.0622, 61.751, 1.8), // Dubhe
      Star(11.0307, 56.383, 2.4), // Merak
      Star(11.8972, 53.695, 2.4), // Phecda
      Star(12.2571, 57.033, 3.3), // Megrez
      Star(12.9005, 55.960, 1.8), // Alioth
      Star(13.3988, 54.925, 2.2), // Mizar
      Star(13.7923, 49.313, 1.9), // Alkaid
    ],
    [0, 1, 1, 2, 2, 3, 3, 0, 3, 4, 4, 5, 5, 6],
  ),
  Constellation(
    'casiopea',
    'Casiopea',
    'Cassiopeia',
    'La uve doble torcida, al otro lado de la polar que el Carro. Nunca se '
        'pone: da vueltas toda la noche sin tocar el horizonte.',
    [
      Star(0.1529, 59.150, 2.3), // Caph
      Star(0.6751, 56.537, 2.2), // Schedar
      Star(0.9451, 60.717, 2.5), // Gamma
      Star(1.4303, 60.235, 2.7), // Ruchbah
      Star(1.9067, 63.670, 3.4), // Segin
    ],
    [0, 1, 1, 2, 2, 3, 3, 4],
  ),
  Constellation(
    'cruz',
    'Cruz del Sur',
    'Crux',
    'La más chica de las ochenta y ocho, y la que ordena el cielo del sur: su '
        'palo largo, estirado cuatro veces, apunta al polo.',
    [
      Star(12.4433, -63.099, 0.8), // Acrux
      Star(12.5194, -57.113, 1.6), // Gacrux
      Star(12.7953, -59.689, 1.3), // Mimosa
      Star(12.2524, -58.749, 2.8), // Delta
    ],
    [0, 1, 2, 3],
  ),
  Constellation(
    'cisne',
    'Cisne',
    'Cygnus',
    'La Cruz del Norte, volando por el medio de la Vía Láctea. Deneb, en la '
        'cola, es de las estrellas más lejanas que se ven a ojo.',
    [
      Star(20.6905, 45.280, 1.3), // Deneb
      Star(20.3705, 40.257, 2.2), // Sadr
      Star(19.5120, 27.960, 3.1), // Albireo
      Star(20.7702, 33.970, 2.5), // Gienah
      Star(19.7498, 45.131, 2.9), // Delta
    ],
    [0, 1, 1, 2, 1, 3, 1, 4],
  ),
  Constellation(
    'escorpio',
    'Escorpio',
    'Scorpius',
    'De las pocas que se parecen a lo que dicen ser: tiene pinzas, lomo y un '
        'aguijón curvado. Antares, en el centro, es roja de verdad.',
    [
      Star(16.0906, -19.805, 2.6), // Graffias
      Star(16.0055, -22.622, 2.3), // Dschubba
      Star(15.9888, -26.114, 2.9), // Pi
      Star(16.4901, -26.432, 1.1), // Antares
      Star(16.5983, -28.216, 2.8), // Tau
      Star(16.8361, -34.293, 2.3), // Epsilon
      Star(16.8721, -38.048, 3.0), // Mu
      Star(16.9119, -42.361, 3.6), // Zeta
      Star(17.2028, -43.239, 3.3), // Eta
      Star(17.6220, -42.998, 1.9), // Theta
      Star(17.7930, -40.127, 3.0), // Iota
      Star(17.7083, -39.030, 2.4), // Kappa
      Star(17.5601, -37.104, 1.6), // Shaula
      Star(17.5121, -37.296, 2.7), // Lesath
    ],
    [
      0, 1, 1, 2, 1, 3, 3, 4, 4, 5, 5, 6, 6, 7, //
      7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13,
    ],
  ),
  Constellation(
    'lira',
    'Lira',
    'Lyra',
    'Un triangulito y un rombo colgando. Vega, la de la punta, fue la primera '
        'estrella a la que alguien le sacó una foto.',
    [
      Star(18.6156, 38.784, 0.0), // Vega
      Star(18.7400, 39.670, 3.9), // Epsilon
      Star(18.7461, 37.605, 4.3), // Zeta
      Star(18.8347, 33.363, 3.5), // Sheliak
      Star(18.9824, 32.690, 3.2), // Sulafat
      Star(18.9089, 36.899, 4.2), // Delta
    ],
    [0, 1, 0, 2, 2, 3, 3, 4, 4, 5, 5, 2],
  ),
  Constellation(
    'canmayor',
    'Can Mayor',
    'Canis Major',
    'El perro de Orión, y en su collar va Sirio: la estrella más brillante de '
        'todo el cielo nocturno.',
    [
      Star(6.7525, -16.716, -1.5), // Sirio
      Star(6.3783, -17.956, 2.0), // Mirzam
      Star(7.0637, -15.633, 4.1), // Muliphein
      Star(7.1399, -26.393, 1.8), // Wezen
      Star(6.9770, -28.972, 1.5), // Adhara
      Star(7.4015, -29.303, 2.4), // Aludra
      Star(7.0288, -27.935, 3.5), // Sigma
    ],
    [0, 1, 0, 2, 2, 3, 3, 4, 4, 6, 6, 0, 3, 5],
  ),
];

/// Las formas ya medidas, por identificador. Ver arriba por qué no viven
/// dentro de su constelación.
final Map<String, List<(double, double)>> _shapes = {};
final Map<String, double> _spreads = {};

/// Cuelga la figura de un punto del cielo y dice dónde queda cada estrella.
///
/// Devuelve, por estrella y en el mismo orden, su azimut y su elevación.
/// Rehacer el plano tangente en el sitio nuevo es lo que conserva la forma:
/// los ángulos entre estrellas salen los mismos que arriba, y por eso la
/// figura sigue siendo reconocible por más que se la cuelgue del oeste en vez
/// del este.
List<(double, double)> hang(Constellation c, double az, double el) {
  final ce = math.cos(el), se = math.sin(el);
  final ca = math.cos(az), sa = math.sin(az);
  // El centro, y en él un este y un norte. Igual que arriba, pero en el marco
  // del mundo: la ye es la vertical.
  final mx = sa * ce, my = se, mz = ca * ce;
  final ex = ca, ez = -sa;
  final nx = my * ez, ny = mz * ex - mx * ez, nz = -my * ex;
  return [
    for (final (dx, dy) in c.shape)
      () {
        final x = mx + dx * ex + dy * nx;
        final y = my + dy * ny;
        final z = mz + dx * ez + dy * nz;
        final ln = math.sqrt(x * x + y * y + z * z);
        return (
          math.atan2(x / ln, z / ln),
          math.asin((y / ln).clamp(-1.0, 1.0)),
        );
      }(),
  ];
}

Constellation? constellationOf(String? id) {
  for (final c in constellations) {
    if (c.id == id) return c;
  }
  return null;
}

/// Qué noche es ésta, contada desde un día cualquiera y fijo.
///
/// La noche va de mediodía a mediodía y no de medianoche a medianoche: quien
/// mira el cielo a la una de la mañana está en la misma noche que a las once
/// de la anterior, y cambiarle la constelación en la mano por haber pasado las
/// doce sería una pequeña traición.
int nightOf(DateTime when) {
  final noon = when.subtract(const Duration(hours: 12));
  return DateTime(
        noon.year,
        noon.month,
        noon.day,
      ).difference(DateTime(2020)).inDays %
      1000000;
}

/// Cuál se ve esta noche.
///
/// Tres de paso sobre ocho: como tres y ocho no comparten divisor, en ocho
/// noches seguidas salen las ocho y ninguna repetida. Al azar puro habría
/// quien esperase un mes por la última, y eso no es un hallazgo, es un peaje.
Constellation tonight(int night) =>
    constellations[(night * 3) % constellations.length];
