/// Las letras que puede llevar un papel del tablón.
///
/// Van en el repositorio y no traídas de internet: un tablón tiene que poder
/// leerse en un tren sin cobertura.
///
/// ## Las manos
///
/// La mayoría son manuscritas desprolijas, y son tantas por un motivo: en un
/// tablón de plaza cada papel lo escribió alguien distinto. Con [varias], cada
/// nota se queda con una mano sacada de su propio nombre, así que el tablón se
/// lee como veinte vecinos y no como veinte copias de la misma letra — y como
/// sale del nombre y no del sitio, la nota de la cabra está siempre escrita
/// por la misma mano.
///
/// ## Licencias
///
/// Todas las libres llevan licencia abierta de fuentes o Apache, y se pueden
/// publicar. **Las cinco de prueba no**, y por eso están apartadas: son para
/// comparar, no para quedarse.
///
/// | Letra     | Autor          | Qué dice su licencia                  |
/// |-----------|----------------|---------------------------------------|
/// | Mi pueblo | —              | No trae ninguna. Se desconoce.        |
/// | Verde     | SKYTROOPAS     | No trae ninguna. Se desconoce.        |
/// | Recta     | MJType         | Sólo uso personal. Comercial se paga. |
/// | Torcida   | Khrys Bosland  | No trae ninguna. Se desconoce.        |
/// | Sureña    | Kimberly Gesw. | Personal libre; comercial, 5 dólares. |
library;

import '../core/rng.dart';
import '../model/board_slots.dart';
import '../model/findings.dart';

enum NoteFont {
  /// La del sistema, que es con la que venía. Se queda para poder comparar.
  sistema(null, null, 'La de ahora', 1.0),

  /// Una mano distinta por nota. Es lo que hace un tablón de plaza.
  varias(null, null, 'Varias manos', 1.0),

  // ------------------------------------------------- las manos del pueblo
  torcida2(
    'WalterTurncoat',
    'WalterTurncoat.ttf',
    'Turncoat',
    0.95,
    mano: true,
  ),
  gloria(
    'GloriaHallelujah',
    'GloriaHallelujah.ttf',
    'Gloria',
    0.94,
    mano: true,
  ),
  sal('RockSalt', 'RockSalt.ttf', 'Sal', 0.76, mano: true),
  otraMano(
    'JustAnotherHand',
    'JustAnotherHand.ttf',
    'Otra mano',
    2.21,
    mano: true,
  ),
  reenie('ReenieBeanie', 'ReenieBeanie.ttf', 'Reenie', 1.33, mano: true),
  nada('NothingYouCouldDo', 'NothingYouCouldDo.ttf', 'Nada', 0.95, mano: true),
  pronto('ComingSoon', 'ComingSoon.ttf', 'Pronto', 1.02, mano: true),
  campana('Schoolbell', 'Schoolbell.ttf', 'Campana', 1.16, mano: true),
  gracia(
    'CoveredByYourGrace',
    'CoveredByYourGrace.ttf',
    'Gracia',
    1.27,
    mano: true,
  ),
  manitas('CraftyGirls', 'CraftyGirls.ttf', 'Manitas', 0.91, mano: true),
  sue('SueEllenFrancisco', 'SueEllenFrancisco.ttf', 'Sue', 1.70, mano: true),
  catalejo(
    'AnnieUseYourTelescope',
    'AnnieUseYourTelescope.ttf',
    'Catalejo',
    1.37,
    mano: true,
  ),
  rotulador(
    'PermanentMarker',
    'PermanentMarker.ttf',
    'Rotulador',
    0.93,
    mano: true,
  ),
  zeyada('Zeyada', 'Zeyada.ttf', 'Zeyada', 1.33, mano: true),
  caveat('Caveat', 'Caveat.ttf', 'Caveat', 1.41, mano: true),
  kalam('Kalam', 'Kalam.ttf', 'Kalam', 1.09, mano: true),
  patrick('PatrickHand', 'PatrickHand.ttf', 'Patrick', 1.31, mano: true),
  sombras(
    'ShadowsIntoLight',
    'ShadowsIntoLight.ttf',
    'Sombras',
    1.25,
    mano: true,
  ),
  arquitecta(
    'ArchitectsDaughter',
    'ArchitectsDaughter.ttf',
    'Arquitecta',
    1.01,
    mano: true,
  ),
  amatic('AmaticSC', 'AmaticSC.ttf', 'Amatic', 1.63, mano: true),

  // -------------------------------------------------- de imprenta vieja
  fell('IMFellEnglish', 'IMFellEnglish.ttf', 'Fell', 1.17),
  garamond('EBGaramond', 'EBGaramond.ttf', 'Garamond', 1.26),

  // ------------------------------------------------- de máquina de escribir
  elite('SpecialElite', 'SpecialElite.ttf', 'Elite', 0.91),
  courier('CourierPrime', 'CourierPrime.ttf', 'Courier', 0.79),

  // ------------------------------------------- de prueba, sin licencia clara
  miPueblo('MyTown', 'MyTown.otf', 'Mi pueblo', 1.14, libre: false),
  verde('GreenTown', 'GreenTown.ttf', 'Verde', 0.91, libre: false),
  recta('StraightTown', 'StraightTown.otf', 'Recta', 1.36, libre: false),
  torcida('KBCrazyTown', 'KBCrazyTown.ttf', 'Torcida', 1.14, libre: false),
  surena('KGSouthernGirl', 'KGSouthernGirl.ttf', 'Sureña', 1.25, libre: false);

  const NoteFont(
    this.family,
    this.asset,
    this.label,
    this.scale, {
    this.mano = false,
    this.libre = true,
  });

  /// Null quiere decir la del sistema, o que hay que repartir manos.
  final String? family;

  /// El archivo, dentro de `assets/fonts/`. En un solo sitio porque hay un
  /// test que las carga todas para medir si el texto cabe, y dos listas de
  /// nombres de archivo se separan en cuanto se añade una.
  final String? asset;

  final String label;

  /// Cuánto hay que agrandarla para que quepa lo mismo por línea que las demás.
  ///
  /// Medido, no puesto a ojo: es cuánto ocupa una frase larga con esta letra
  /// comparada con la de referencia. Las diferencias son enormes —«Otra mano»
  /// cabe más del doble por línea que la de referencia y «Sal» bastante
  /// menos—, así que sin esto elegir una letra sería elegir un tamaño.
  final double scale;

  /// Si vale como mano de vecino para [varias].
  final bool mano;

  /// Si se puede publicar. Las de prueba no. Ver la tabla de arriba.
  final bool libre;

  /// Las manos que se reparten, sin las que no se pueden publicar.
  static List<NoteFont> get manos => [
    for (final f in values)
      if (f.mano && f.libre) f,
  ];

  /// Qué mano le toca a esta nota.
  ///
  /// Sale de su nombre y no de su sitio, igual que el hueco donde está clavada
  /// y la inclinación con que lo está: si saliera del orden, el día que una
  /// nota deja de estar, todas las de detrás cambiarían de letra a la vez.
  static NoteFont handFor(Notice n) {
    final m = manos;
    return m[hashInt(m.length, stableHash(noticeId(n)), 31)];
  }

  static NoteFont? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
