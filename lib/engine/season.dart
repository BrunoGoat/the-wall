import 'dart:math' as math;

import '../core/math3.dart';

/// De qué lado del ecuador se está mirando el valle.
///
/// Hace falta saberlo y no hay manera de deducirlo del reloj: en enero, medio
/// mundo está bajo la nieve y el otro medio en lo más alto del verano. Poner
/// nieve en los tejados en pleno enero argentino sería un error que se ve
/// desde la primera pantalla.
enum Hemisphere { north, south }

/// El año, como un número entre cero y uno.
///
/// La app ya tenía el día: el sol sube, la luna lo releva, las sombras giran.
/// Lo que no tenía era el año, y para alguien que lleva ocho meses poniendo
/// piezas ésa es la escala que importa — el día se repite y el año no. Un
/// valle que en julio está pelado y blanco y en enero verde y largo es lo que
/// convierte «abrir la app» en algo que vale la pena aunque hoy no toque
/// poner nada.
///
/// Todo sale de un solo número, [turn], que da la vuelta una vez al año: cero
/// en pleno invierno, un cuarto en primavera, un medio en pleno verano, tres
/// cuartos en otoño. Las cuatro estaciones son funciones suaves de ése, así
/// que no hay ningún día en que el mundo cambie de golpe — el quince de marzo
/// no amanece de otro color que el catorce. Que es como pasa.
class Season {
  const Season(this.turn);

  /// Dónde está el año, de cero a uno. Cero es pleno invierno.
  final double turn;

  /// Un año sin estaciones: el que había antes de que esto existiera.
  ///
  /// Es verano pleno, que es la luz con la que se eligieron todos los colores
  /// del ciclo del día y con la que están hechas las capturas y los tests. Sin
  /// esto, añadir el año le habría cambiado el aspecto a todo lo que ya estaba
  /// medido, y no habría manera de saber si el cambio era la estación o un
  /// error.
  static const Season none = Season(0.5);

  /// El solsticio de invierno del norte cae alrededor del 21 de diciembre, que
  /// es el día 355 del año. Desde ahí se cuenta.
  static const int _midwinterNorth = 355;

  /// Qué día del año es hoy, para el lado del mundo en que se está.
  factory Season.on(DateTime day, Hemisphere where) {
    final doy = _dayOfYear(day);
    final year = _daysInYear(day.year);
    var t = (doy - _midwinterNorth) / year;
    if (where == Hemisphere.south) t += 0.5;
    t %= 1.0;
    return Season(t < 0 ? t + 1 : t);
  }

  static int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year)).inDays.toDouble().round();

  static double _daysInYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 366.0 : 365.0;

  /// Cuánto hay de cada estación ahora mismo, de cero a uno.
  ///
  /// Invierno y verano son opuestos y suman uno; primavera y otoño son los dos
  /// caminos de uno al otro y sólo uno de los dos está encendido a la vez. Así
  /// «hojas doradas» se pide por [autumn] y se apaga sola en cuanto empieza a
  /// caer la hoja, sin ninguna fecha escrita en ningún sitio.
  double get winter => (math.cos(turn * 2 * math.pi) + 1) / 2;
  double get summer => 1 - winter;
  double get spring => math.max(0.0, math.sin(turn * 2 * math.pi));
  double get autumn => math.max(0.0, -math.sin(turn * 2 * math.pi));

  /// Cuánta nieve hay puesta.
  ///
  /// No es el invierno entero: nieva en lo más crudo y no en cuanto refresca.
  /// Esto se queda en cero hasta bien entrado el invierno y sube rápido
  /// después, así que hay algo de nieve unos cien días al año. Con el umbral
  /// donde lo puse la primera vez eran ciento cincuenta y tres, y una
  /// escarcha de cinco meses es peor que no tener estaciones.
  double get snow => clampD((winter - 0.82) / 0.16, 0.0, 1.0);

  /// Lo pelados que están los árboles.
  ///
  /// Va detrás del oro del otoño, y ese orden es el asunto: primero las hojas
  /// cambian de color y después se caen. Con el umbral demasiado pronto, un
  /// veinte de octubre el árbol estaba ya medio pelado en mitad de su mejor
  /// semana.
  double get bare => clampD((winter - 0.62) / 0.34, 0.0, 1.0);

  /// El mediodía solar. No es las doce: el ciclo del día de esta app tiene el
  /// sol en lo más alto a la una, y todo lo de aquí se cuelga de eso para que
  /// una cosa y la otra no se peleen.
  static const double noon = 13.0;

  /// Media duración del día, en horas.
  ///
  /// De nueve horas y media en pleno invierno a catorce en pleno verano, que
  /// es lo que dura el día en las latitudes donde vive casi todo el mundo. En
  /// el ecuador serían doce siempre y en Islandia veinte, y ninguno de los dos
  /// extremos hace que la app se vea mejor.
  ///
  /// El extremo de verano está clavado en siete, y no por gusto: da un día de
  /// seis a veinte, que es exactamente el que supone el ciclo de colores del
  /// día. Así [none] deja la luz igualita a como estaba antes de que hubiera
  /// estaciones, y cualquier diferencia que se vea en una captura vieja es la
  /// estación y no un error mío.
  double get _half => 5.9 + 1.1 * (summer * 2 - 1);

  double get sunrise => noon - _half;
  double get sunset => noon + _half;

  /// Cuánto dura el día de hoy, en horas. Para poder decirlo.
  double get daylightHours => _half * 2;

  /// Cómo se llama esto donde vive quien lo mira.
  String get name => switch (((turn + 0.125) % 1.0 * 4).floor()) {
    0 => 'Invierno',
    1 => 'Primavera',
    2 => 'Verano',
    _ => 'Otoño',
  };

  /// El lado del mundo que le toca a un país, para no preguntar nada el primer
  /// día.
  ///
  /// Se mira el país del idioma del teléfono, que es lo único que hay sin
  /// pedir permisos ni tocar la red. La lista es corta a propósito: sólo los
  /// países que están claramente abajo. Lo que cae sobre el ecuador —Ecuador,
  /// Colombia, Kenia— no tiene estaciones que se parezcan a ninguna de las
  /// dos, así que da igual de qué lado se lo ponga, y se queda con el norte
  /// por ser lo que sale por defecto.
  ///
  /// Y se puede cambiar a mano en ajustes, porque una lista de países nunca va
  /// a acertar con todo el mundo y equivocarse aquí se ve enseguida: nieve en
  /// enero donde hace treinta y cinco grados.
  static Hemisphere hemisphereOf(String? country) => switch (country) {
    'AR' ||
    'CL' ||
    'UY' ||
    'PY' ||
    'BO' ||
    'BR' ||
    'PE' ||
    'ZA' ||
    'AU' ||
    'NZ' ||
    'NA' ||
    'BW' ||
    'ZW' ||
    'MZ' ||
    'ZM' ||
    'AO' ||
    'MG' ||
    'FJ' ||
    'PG' ||
    'ID' ||
    'TL' ||
    'LS' ||
    'SZ' ||
    'MW' ||
    'TZ' => Hemisphere.south,
    _ => Hemisphere.north,
  };
}
