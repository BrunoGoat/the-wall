import 'dart:math' as math;

import '../core/rng.dart';

/// Una estrella fugaz.
///
/// Sin nada que guardar: el tiempo se parte en ventanas, y de qué ventana es
/// éste decide —siempre igual— si hay una, cuándo dentro de la ventana y por
/// dónde. Un estado más para algo que dura segundo y pico sería un estado más
/// que mantener sincronizado con la pausa, con el rebobinado del expositor y
/// con la hora fingida de los ajustes.
///
/// Vive aparte porque la miran dos sitios: el valle y el tablón de cerca, que
/// dibuja su propio cielo. Dos copias serían dos cielos con dos ritmos.
class ShootingStar {
  const ShootingStar({
    required this.az0,
    required this.el0,
    required this.sweep,
    required this.drop,
    required this.u,
    required this.glow,
  });

  /// De dónde sale y hacia dónde va. Bajas y en diagonal, que es como se ven:
  /// una raya en mitad del cielo parece un avión.
  final double az0, el0, sweep, drop;

  /// Por dónde va de su vuelo, de 0 a 1, y cuánto luce ahora mismo.
  final double u, glow;

  /// Cada cuánto se tira el dado, y cuánto dura el vuelo.
  static const double window = 24.0, flight = 1.15;

  /// A partir de qué hora puede haberlas, y hasta cuál.
  ///
  /// Antes bastaba con que el cielo estuviera oscuro, que en invierno es a las
  /// seis de la tarde. Una fugaz a las seis y media no es una fugaz: es una luz
  /// rara mientras todavía se ve el campo.
  static const double fromHour = 20.0, toHour = 5.0;

  static bool nightEnough(double hour) => hour >= fromHour || hour < toHour;

  /// Hasta cuándo hay una pedida a mano. Para el botón de probarlo: esperar
  /// diecisiete minutos a ver si funciona no es probar nada.
  static DateTime? forcedUntil;

  static void force() => forcedUntil = DateTime.now().add(
    Duration(milliseconds: (flight * 1000).round()),
  );

  /// La de ahora, si la hay.
  ///
  /// [chance] es qué parte de las ventanas traen una. En el valle es baja a
  /// propósito —la gracia de mirar al cielo es que casi nunca pasa nada— y en
  /// el tablón es alta, porque ahí uno está mirando a propósito y poco rato.
  static ShootingStar? at(double time, double hour, {double chance = 0.30}) {
    final pedida = forcedUntil;
    if (pedida != null) {
      final falta = pedida.difference(DateTime.now()).inMilliseconds / 1000.0;
      if (falta > 0 && falta <= flight) return _shape(0, 1 - falta / flight);
      if (falta <= 0) forcedUntil = null;
    }
    if (!nightEnough(hour)) return null;
    final epoch = (time / window).floor();
    if (hash01(epoch, 401) > chance) return null;
    final began = epoch * window + hash01(epoch, 403) * (window - flight);
    final u = (time - began) / flight;
    if (u < 0 || u > 1) return null;
    return _shape(epoch, u);
  }

  static ShootingStar _shape(int epoch, double u) => ShootingStar(
    az0: hash01(epoch, 405) * math.pi * 2,
    el0: 0.22 + hash01(epoch, 407) * 0.55,
    sweep:
        (hash01(epoch, 409) < 0.5 ? -1 : 1) *
        (0.20 + hash01(epoch, 411) * 0.22),
    drop: 0.10 + hash01(epoch, 413) * 0.16,
    u: u,
    // Entra y se apaga: nunca aparece ni desaparece de golpe.
    glow: math.pow(math.sin(math.pi * u.clamp(0.0, 1.0)), 0.65).toDouble(),
  );

  /// Dónde está en el cielo en el punto [k] de su vuelo, o null si ya bajó del
  /// horizonte.
  (double az, double el)? aim(double k) {
    final el = el0 - drop * k;
    if (el <= 0.01) return null;
    return (az0 + sweep * k, el);
  }

  /// Cada cuánto se ve una, en minutos, contando que hay que estar mirando
  /// hacia ella. Para poder decirlo sin inventarlo.
  ///
  /// [fov] es lo que abarca la lente a lo ancho, en radianes.
  static double minutesBetween(double chance, double fov) {
    final porMinuto = 60 / window * chance;
    // La fugaz barre mientras cae, así que la ventana útil es lo que abarca la
    // lente más lo que ella se mueve. Y de las elevaciones posibles, las bajas
    // se van por debajo del horizonte antes de acabar.
    final trozo = (fov + 0.31) / (math.pi * 2);
    return 1 / (porMinuto * trozo * 0.7);
  }
}
