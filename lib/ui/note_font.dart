/// Las letras que puede llevar un papel del tablón.
///
/// Van en el repositorio y no traídas de internet: un tablón tiene que poder
/// leerse en un tren sin cobertura.
///
/// ## Licencias
///
/// Las diez primeras son libres —licencia abierta de fuentes o Apache— y se
/// pueden publicar. **Las cinco últimas no**, y por eso están apartadas: son
/// para elegir, no para quedarse. Lo que dice cada una:
///
/// | Letra          | Autor           | Qué dice su licencia                  |
/// |----------------|-----------------|---------------------------------------|
/// | Mi pueblo      | —               | No trae ninguna. Se desconoce.        |
/// | Verde          | SKYTROOPAS      | No trae ninguna. Se desconoce.        |
/// | Recta          | MJType          | Sólo uso personal. Comercial se paga. |
/// | Torcida        | Khrys Bosland   | No trae ninguna. Se desconoce.        |
/// | Sureña         | Kimberly Gesw.  | Personal libre; comercial, 5 dólares. |
///
/// Antes de publicar en una tienda hay que quedarse con una y arreglarla:
/// pagar su licencia, escribirle al autor, o cambiarla por una libre que se
/// le parezca. Mientras tanto cada compilación las lleva dentro, así que
/// tampoco conviene repartir esas compilaciones más de la cuenta.
library;

enum NoteFont {
  /// La del sistema, que es con la que venía. Se queda para poder comparar.
  sistema(null, null, 'La de ahora', 1.0),

  // ------------------------------------------------------------ a mano
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
  amatic('AmaticSC', 'AmaticSC.ttf', 'Amatic', 1.63),

  // -------------------------------------------------- de imprenta vieja
  fell('IMFellEnglish', 'IMFellEnglish.ttf', 'Fell', 1.17),
  garamond('EBGaramond', 'EBGaramond.ttf', 'Garamond', 1.26),

  // ------------------------------------------------- de máquina de escribir
  elite('SpecialElite', 'SpecialElite.ttf', 'Elite', 0.91),
  courier('CourierPrime', 'CourierPrime.ttf', 'Courier', 0.79),

  // ------------------------------------------- de prueba, sin licencia clara
  miPueblo('MyTown', 'MyTown.otf', 'Mi pueblo', 1.14),
  verde('GreenTown', 'GreenTown.ttf', 'Verde', 0.91),
  recta('StraightTown', 'StraightTown.otf', 'Recta', 1.36),
  torcida('KBCrazyTown', 'KBCrazyTown.ttf', 'Torcida', 1.14),
  surena('KGSouthernGirl', 'KGSouthernGirl.ttf', 'Sureña', 1.25);

  const NoteFont(this.family, this.asset, this.label, this.scale);

  /// Null quiere decir la del sistema.
  final String? family;

  /// El archivo, dentro de `assets/fonts/`. En un solo sitio porque hay un
  /// test que las carga todas para medir si el texto cabe, y dos listas de
  /// nombres de archivo se separan en cuanto se añade una.
  final String? asset;

  final String label;

  /// Cuánto hay que agrandarla para que quepa lo mismo por línea que las demás.
  ///
  /// Medido, no puesto a ojo: es cuánto ocupa una frase larga con esta letra
  /// comparada con la de referencia. No es un capricho — una manuscrita
  /// estrecha de cuerpo doce cabe casi el doble por línea que una de máquina
  /// de escribir del mismo cuerpo, así que sin esto elegir Amatic sería elegir
  /// «letra diminuta» y la comparación no diría nada sobre la letra.
  final double scale;

  /// Si se puede publicar. Las de prueba no. Ver la tabla de arriba.
  bool get libre => index <= courier.index;

  static NoteFont? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
