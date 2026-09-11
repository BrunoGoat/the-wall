import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';

/// Lo que la cámara alcanza a ver del cielo, ahora mismo.
///
/// Existe por un motivo concreto: en esta app casi no hay cielo a la vista. La
/// lente abre 0,86 radianes de alto y la cámara mira hacia abajo, así que con
/// el encuadre de siempre lo que queda por encima del horizonte es una franja
/// de cuatro grados escasos. Las fugaces salían a elevaciones de doce a treinta
/// y un grados —repartidas por todo el cielo, como en el mundo— y por eso
/// pasaban varias y no se veía ninguna: estaban todas por encima del borde de
/// arriba de la pantalla.
class SkyView {
  const SkyView({
    required this.az,
    required this.el,
    required this.halfWide,
    required this.halfTall,
  });

  /// Hacia dónde mira, en azimut y elevación. La elevación es negativa cuando
  /// la cámara mira hacia abajo, que es lo normal aquí.
  final double az, el;

  /// Medio ángulo que abarca la lente, a lo ancho y a lo alto.
  final double halfWide, halfTall;

  /// De una cámara ya montada, para no tener que saber sus ángulos: salen del
  /// propio `forward`, así que esto vale igual para el valle y para el tablón,
  /// que arman su proyector cada uno por su cuenta.
  factory SkyView.of(Projector p, double width, double height) {
    final f = p.forward;
    return SkyView(
      az: math.atan2(f.x, f.z),
      el: math.asin(f.y.clamp(-1.0, 1.0)),
      halfWide: math.atan((width / 2) / p.focal),
      halfTall: math.atan((height / 2) / p.focal),
    );
  }

  /// Por dónde puede pasar una fugaz y verse: entre poco más que el horizonte
  /// y el borde de arriba de la pantalla.
  ///
  /// Las cuentas, con la cámara de siempre —que mira 0,3 radianes hacia abajo—
  /// y una pantalla de teléfono de pie: el horizonte cae a 139 píxeles del
  /// borde de arriba, y de ahí hacia arriba lo que hay es cordillera. Cielo
  /// limpio quedan cuarenta píxeles. Por eso el suelo de la franja está casi
  /// en el horizonte y no por encima de las cumbres: una fugaz que sólo pueda
  /// pasar por donde no hay montaña sólo puede pasar por esos cuarenta
  /// píxeles, y ahí no cabe nada que se quiera mirar.
  ///
  /// Lo que la hace visible es lo otro: se pinta **después** de las
  /// cordilleras, así que cruza por delante de ellas. No es donde estaría de
  /// verdad —una fugaz está más lejos que cualquier monte— pero es lo que la
  /// pone a la vista y lo que hace que su luz caiga sobre las cumbres, que es
  /// lo que se pidió.
  static const double skyline = 0.012;

  /// Casi hasta el borde de arriba. Queda justo: con la cámara inclinada
  /// treinta y cinco centésimas el horizonte ya se sale por arriba y no hay
  /// cielo ninguno, así que dejar sin usar el último trozo de franja es
  /// quedarse sin fugaces en medio pueblo.
  double get elTop => el + halfTall * 0.94;
  double get elFloor => math.max(skyline, el + halfTall * 0.10);

  /// Si queda algo de cielo por encima del horizonte dentro del encuadre.
  ///
  /// No se pide que la franja sea alta: aunque sea de medio grado, una fugaz
  /// cruza a lo ancho —que es a donde va— y lo único que pierde es lo que baja
  /// mientras cruza. Lo que sí hace falta es que haya cielo: pasada una
  /// inclinación de cuatro décimas el horizonte se sale por arriba de la
  /// pantalla, y entonces no hay fugaz. Mejor ninguna que una que nadie ve.
  bool get hasSky => elTop > skyline + 0.004;
}

/// Una estrella fugaz.
///
/// Sin nada que guardar salvo hacia dónde mirabas cuando salió: el tiempo se
/// parte en ventanas, y de qué ventana es éste decide —siempre igual— si hay
/// una, cuándo dentro de la ventana y por dónde. Un estado más para algo que
/// dura cinco segundos sería un estado más que mantener sincronizado con la
/// pausa, con el rebobinado del expositor y con la hora fingida de los ajustes.
///
/// Vive aparte porque la miran dos sitios: el valle y el tablón de cerca, que
/// dibuja su propio cielo. Dos copias serían dos cielos con dos ritmos.
class ShootingStar {
  const ShootingStar({
    required this.id,
    required this.az0,
    required this.el0,
    required this.sweep,
    required this.drop,
    required this.u,
    required this.glow,
    required this.light,
    required this.spin,
  });

  /// Cuál es ésta. Sirve para tocar su sonido una sola vez: esto se pregunta
  /// en cada fotograma y una fugaz dura cinco segundos.
  final int id;

  /// De dónde sale y hacia dónde va. Sale de un lado del encuadre y cruza
  /// hasta salirse por el otro, cayendo mientras tanto.
  final double az0, el0, sweep, drop;

  /// Por dónde va de su vuelo, de 0 a 1.
  final double u;

  /// Cuánto luce ella y cuánto alumbra el valle. Son dos: la fugaz se apaga
  /// antes del final y lo que queda medio segundo más es su luz deshaciéndose
  /// en el cielo, que es lo que hace que uno siga mirando después.
  final double glow, light;

  /// Cuánto lleva girado el destello de la cabeza.
  final double spin;

  /// Cada cuánto se tira el dado, y cuánto dura el vuelo.
  ///
  /// Cinco segundos: lo que se pidió, y lo que tarda en cruzar el encuadre a
  /// una velocidad que se lee como algo cayendo y no como algo pasando.
  static const double window = 90.0, flight = 5.0;

  /// A partir de qué hora puede haberlas, y hasta cuál.
  ///
  /// Antes bastaba con que el cielo estuviera oscuro, que en invierno es a las
  /// seis de la tarde. Una fugaz a las seis y media no es una fugaz: es una luz
  /// rara mientras todavía se ve el campo.
  static const double fromHour = 20.0, toHour = 5.0;

  static bool nightEnough(double hour) => hour >= fromHour || hour < toHour;

  /// Hasta cuándo hay una pedida a mano. Para el botón de probarlo: esperar
  /// un cuarto de hora a ver si funciona no es probar nada.
  static DateTime? forcedUntil;

  /// Cuántas se han pedido a mano. Dos seguidas son dos, no una repetida.
  static int _forcedSeq = 0;

  static void force() {
    _forcedSeq++;
    forcedUntil = DateTime.now().add(
      Duration(milliseconds: (flight * 1000).round()),
    );
  }

  /// Hacia dónde mirabas cuando salió cada una.
  ///
  /// Es el único estado que hay, y hace falta: la fugaz se pone donde la cámara
  /// está mirando para que se vea, pero se pone **una vez**. Si se recalculara
  /// en cada fotograma, girar la cámara arrastraría la estrella con ella y no
  /// se podría perder de vista, que es justo lo contrario de lo que es una
  /// fugaz. Por identificador y no un solo hueco porque el tablón se abre
  /// encima del valle y durante la transición los dos preguntan a la vez.
  static final Map<int, SkyView> _aimed = {};

  /// Olvidar hacia dónde se miraba. Para los tests y para el expositor, que
  /// rebobina el reloj y vuelve a pedir la misma.
  static void forget() => _aimed.clear();

  static SkyView _aim(int id, SkyView now) {
    final ya = _aimed[id];
    if (ya != null) return ya;
    if (_aimed.length > 8) _aimed.clear();
    _aimed[id] = now;
    return now;
  }

  /// La de ahora, si la hay.
  ///
  /// [chance] es qué parte de las ventanas traen una. Ahora todas las que
  /// salen se ven —salen donde estás mirando—, así que la cuenta ya no lleva
  /// el descuento de «y encima tenías que estar mirando para allá».
  static ShootingStar? at(
    double time,
    double hour,
    SkyView view, {
    double chance = 0.34,
  }) {
    final pedida = forcedUntil;
    if (pedida != null) {
      final falta = pedida.difference(DateTime.now()).inMilliseconds / 1000.0;
      if (falta > 0 && falta <= flight) {
        return _shape(-_forcedSeq, 1 - falta / flight, view);
      }
      if (falta <= 0) forcedUntil = null;
    }
    if (!nightEnough(hour)) return null;
    final epoch = (time / window).floor();
    if (hash01(epoch, 401) > chance) return null;
    final began = epoch * window + hash01(epoch, 403) * (window - flight);
    final u = (time - began) / flight;
    if (u < 0 || u > 1) return null;
    return _shape(epoch, u, view);
  }

  static ShootingStar? _shape(int id, double u, SkyView now) {
    final v = _aim(id, now);
    if (!v.hasSky) return null;

    // Cruza el encuadre entero y se sale un poco por los dos lados: entra ya
    // volando y se va sin frenar, que es lo que hace que parezca que venía de
    // lejos. El margen es corto a propósito: con uno ancho, la mitad del vuelo
    // pasaba fuera de la pantalla y de cinco segundos se veían dos y medio.
    final hacia = hash01(id, 409) < 0.5 ? -1.0 : 1.0;
    final span = v.halfWide * 2 + 0.16;

    // A qué altura cruza. En cualquier parte de la franja menos pegada al
    // techo: el resplandor de la cabeza mide un séptimo de la pantalla, y
    // saliendo del borde mismo se le va la mitad fuera.
    final alto = v.elTop - v.elFloor;
    final el0 = v.elFloor + alto * (0.30 + 0.55 * hash01(id, 407));

    // Y cuánto baja mientras cruza: casi nada.
    //
    // Caían en diagonal porque así caen las de verdad, pero aquí el cielo que
    // se ve es una franja de cuatro grados: una diagonal en cuatro grados no
    // se lee como una diagonal, se lee como que la estrella se mete debajo del
    // pueblo. Cruzando a lo largo, lo que se ve es lo que tiene que verse, que
    // es que atraviesa el cielo entero. Una de cada cinco baja un poco más,
    // para que no sean todas la misma raya.
    final cae = hash01(id, 415);
    final drop =
        (el0 - v.elFloor) * (cae > 0.80 ? 0.30 + 0.35 * hash01(id, 413) : 0.10);

    return ShootingStar(
      id: id,
      az0: v.az - hacia * span / 2,
      el0: el0,
      sweep: hacia * span,
      drop: drop,
      u: u,
      glow: _glow(u),
      light: _light(u),
      spin: u * 2.1,
    );
  }

  /// Cuánto luce la propia estrella.
  ///
  /// Enciende deprisa, se queda encendida casi todo el vuelo y se apaga antes
  /// del final. Con la campana de antes —un seno de punta a punta— sólo estaba
  /// brillante en mitad del recorrido, que sobre cinco segundos deja los dos
  /// extremos en nada.
  static double _glow(double u) {
    if (u <= 0) return 0;
    if (u < 0.06) return _suave(u / 0.06);
    if (u < 0.78) return 1;
    if (u >= 0.94) return 0;
    return _suave(1 - (u - 0.78) / 0.16);
  }

  /// Cuánto alumbra el valle. Llega después que ella y se va después que ella:
  /// el último medio segundo es cielo vacío con la luz deshaciéndose.
  static double _light(double u) {
    if (u <= 0.03) return 0;
    if (u < 0.30) return _suave((u - 0.03) / 0.27);
    if (u < 0.62) return 1;
    if (u >= 1) return 0;
    return _suave(1 - (u - 0.62) / 0.38);
  }

  static double _suave(double k) {
    final x = k.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// Dónde está en el cielo en el punto [k] de su vuelo, o null si ya bajó del
  /// horizonte.
  ///
  /// Cae acelerando, no a ritmo constante: una raya que avanza siempre igual
  /// es un avión.
  (double az, double el)? aim(double k) {
    final el = el0 - drop * (0.35 * k + 0.65 * k * k);
    if (el <= 0.005) return null;
    return (az0 + sweep * k, el);
  }

  /// Cada cuánto se ve una, en minutos.
  ///
  /// Ya no lleva el descuento por dónde estés mirando: todas salen dentro del
  /// encuadre, así que la cuenta es la ventana partido la probabilidad.
  static double minutesBetween(double chance) => window / chance / 60;
}
