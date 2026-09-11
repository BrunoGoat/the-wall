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
/// Todas llevan licencia abierta de fuentes o Apache, así que todas se pueden
/// publicar. Aquí no entra ninguna que no se pueda: hubo cinco de prueba —Mi
/// pueblo, Verde, Recta, Torcida y Sureña— que sin licencia clara viajaban
/// dentro de cada APK, y por eso se fueron del repositorio enteras.
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
  //
  // Las nueve que se reparten entre los papeles. Salen de probarlas una a una
  // en el tablón y no de la medida: la medida dice cuánto texto cabe por
  // línea, y eso no es lo mismo que cuál se lee bien escrita a mano.
  sal('RockSalt', 'RockSalt.ttf', 'Sal', 0.76, mano: true),
  campana('Schoolbell', 'Schoolbell.ttf', 'Campana', 1.16, mano: true),
  gracia(
    'CoveredByYourGrace',
    'CoveredByYourGrace.ttf',
    'Gracia',
    1.27,
    mano: true,
  ),
  rotulador(
    'PermanentMarker',
    'PermanentMarker.ttf',
    'Rotulador',
    0.93,
    mano: true,
  ),
  catalejo(
    'AnnieUseYourTelescope',
    'AnnieUseYourTelescope.ttf',
    'Catalejo',
    1.37,
    mano: true,
  ),
  sue('SueEllenFrancisco', 'SueEllenFrancisco.ttf', 'Sue', 1.70, mano: true),
  gloria(
    'GloriaHallelujah',
    'GloriaHallelujah.ttf',
    'Gloria',
    0.94,
    mano: true,
  ),
  amatic('AmaticSC', 'AmaticSC.ttf', 'Amatic', 1.63, mano: true),
  // Su medida decía 2,21 y era demasiado: puesta junto a las otras había que
  // bajarle el deslizador a menos de la mitad para que pareciera la misma
  // letra. Lo que se corrige es la medida, no el deslizador.
  otraMano(
    'JustAnotherHand',
    'JustAnotherHand.ttf',
    'Otra mano',
    0.98,
    mano: true,
  ),

  // Y las demás, que siguen estando para elegirlas a mano.
  turncoat('WalterTurncoat', 'WalterTurncoat.ttf', 'Turncoat', 0.95),
  reenie('ReenieBeanie', 'ReenieBeanie.ttf', 'Reenie', 1.33),
  nada('NothingYouCouldDo', 'NothingYouCouldDo.ttf', 'Nada', 0.95),
  pronto('ComingSoon', 'ComingSoon.ttf', 'Pronto', 1.02),
  manitas('CraftyGirls', 'CraftyGirls.ttf', 'Manitas', 0.91),
  zeyada('Zeyada', 'Zeyada.ttf', 'Zeyada', 1.33),
  caveat('Caveat', 'Caveat.ttf', 'Caveat', 1.41),
  kalam('Kalam', 'Kalam.ttf', 'Kalam', 1.09),
  patrick('PatrickHand', 'PatrickHand.ttf', 'Patrick', 1.31),
  sombras('ShadowsIntoLight', 'ShadowsIntoLight.ttf', 'Sombras', 1.25),
  arquitecta(
    'ArchitectsDaughter',
    'ArchitectsDaughter.ttf',
    'Arquitecta',
    1.01,
  ),

  // -------------------------------------------------- de imprenta vieja
  fell('IMFellEnglish', 'IMFellEnglish.ttf', 'Fell', 1.17),
  garamond('EBGaramond', 'EBGaramond.ttf', 'Garamond', 1.26),

  // ------------------------------------------------- de máquina de escribir
  elite('SpecialElite', 'SpecialElite.ttf', 'Elite', 0.91),
  courier('CourierPrime', 'CourierPrime.ttf', 'Courier', 0.79);

  const NoteFont(
    this.family,
    this.asset,
    this.label,
    this.scale, {
    this.mano = false,
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

  /// Las manos que se reparten entre los papeles.
  static List<NoteFont> get manos => [
    for (final f in values)
      if (f.mano) f,
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
