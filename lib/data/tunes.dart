/// Las cinco piezas que pueden estar sonando de fondo.
///
/// Cada una son tres archivos y una curva: qué se oye de cada capa a cada hora
/// del día. Están aquí y no dentro de `Sensory` porque las preferencias
/// también tienen que saber cuáles hay —para guardar cuáles entran en el
/// sorteo— y un catálogo que vive dentro del motor de sonido obliga al modelo
/// a depender del motor, que es justo al revés de como tiene que ser.
///
/// Se generan con `tool/make_music.py`, que es donde está explicado de qué
/// están hechas y por qué.
library;

/// Una pieza: tres capas y cómo se reparten a lo largo del día.
class Tune {
  const Tune(this.id, this.name, this.blurb, this.hours);

  /// Nunca cambia: es con lo que se guarda que ésta entra en el sorteo, y es
  /// la mitad del nombre de sus tres archivos.
  final String id;
  final String name;

  /// De qué está hecha, en una línea, para poder elegir sin oír las cinco.
  final String blurb;

  /// Las cuatro horas —noche, alba, mediodía, ocaso— y cuánto suena cada capa
  /// en cada una, en el orden en que están los archivos. Entre hora y hora se
  /// interpola: a las ocho y un minuto no puede sonar distinto que a las ocho
  /// menos uno.
  final List<List<double>> hours;

  /// La cama, la parte que se mueve, y lo que flota por encima.
  ///
  /// Las dos primeras duran exactamente lo mismo porque las dos llevan
  /// armonía; la tercera dura otra cosa a propósito, y sus notas están
  /// elegidas para que suenen bien sobre los cuatro acordes de la pieza. Eso
  /// es lo que hace que la combinación no vuelva a repetirse igual en varios
  /// minutos sin que nada choque nunca.
  List<String> get files => [
    'mus_${id}_pad.wav',
    'mus_${id}_keys.wav',
    'mus_${id}_air.wav',
  ];
}

const List<Tune> tunes = [
  Tune(
    'tarde',
    'Tarde',
    'Rhodes, bajo redondo y campanitas. Fa mayor, setenta y dos.',
    [
      [1.00, 0.30, 0.55], // noche
      [0.90, 0.80, 0.75], // alba
      [0.75, 1.00, 0.55], // mediodía
      [0.95, 0.65, 0.85], // ocaso
    ],
  ),
  Tune(
    'bruma',
    'Bruma',
    'Sin pulso ninguno: sólo cosas que entran y salen. Lab mayor.',
    [
      [1.00, 0.55, 0.80],
      [0.85, 0.85, 0.60],
      [0.70, 1.00, 0.40],
      [0.90, 0.70, 0.75],
    ],
  ),
  Tune(
    'sendero',
    'Sendero',
    'Cuerda de nailon y flauta de madera. Sol mayor, sesenta y seis.',
    [
      [1.00, 0.25, 0.45],
      [0.85, 0.90, 0.85],
      [0.70, 1.00, 0.50],
      [0.90, 0.60, 0.90],
    ],
  ),
  Tune(
    'caja',
    'Caja de música',
    'Campanitas de cola muy larga. Do mayor, sesenta.',
    [
      [1.00, 0.45, 0.35],
      [0.85, 0.85, 0.70],
      [0.70, 1.00, 0.60],
      [0.92, 0.70, 0.80],
    ],
  ),
  Tune(
    'brasa',
    'Brasa',
    'Rhodes grave y una campana cada tanto, muy arriba. Reb mayor.',
    [
      [1.00, 0.60, 0.70],
      [0.85, 0.55, 0.45],
      [0.75, 0.85, 0.35],
      [1.00, 1.00, 0.80],
    ],
  ),
];

/// La pieza con ese identificador, o la primera. Nunca falla: una preferencia
/// guardada por una versión que tenía otras piezas no puede dejar la app sin
/// música.
Tune tuneOf(String? id) {
  for (final t in tunes) {
    if (t.id == id) return t;
  }
  return tunes.first;
}
