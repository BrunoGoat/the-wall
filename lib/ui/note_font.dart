/// Las letras que puede llevar un papel del tablón.
///
/// Van en el repositorio y no traídas de internet: un tablón tiene que poder
/// leerse en un tren sin cobertura. Son diez, de tres familias distintas —
/// manuscritas, de imprenta vieja y de máquina de escribir— porque lo que hay
/// clavado en un tablón de plaza lo escribió alguien a mano, lo imprimió una
/// prensa o lo picó una máquina, y las tres cosas conviven.
library;

enum NoteFont {
  /// La del sistema, que es con la que venía. Se queda para poder comparar.
  sistema(null, 'La de ahora', 1.0),

  // ------------------------------------------------------------ a mano
  caveat('Caveat', 'Caveat', 1.22),
  kalam('Kalam', 'Kalam', 1.02),
  patrick('PatrickHand', 'Patrick', 1.1),
  sombras('ShadowsIntoLight', 'Sombras', 1.16),
  arquitecta('ArchitectsDaughter', 'Arquitecta', 1.04),
  amatic('AmaticSC', 'Amatic', 1.5),

  // -------------------------------------------------- de imprenta vieja
  fell('IMFellEnglish', 'Fell', 1.08),
  garamond('EBGaramond', 'Garamond', 1.12),

  // ------------------------------------------------- de máquina de escribir
  elite('SpecialElite', 'Elite', 1.0),
  courier('CourierPrime', 'Courier', 1.02);

  const NoteFont(this.family, this.label, this.scale);

  /// Null quiere decir la del sistema.
  final String? family;
  final String label;

  /// Cuánto hay que agrandarla para que se lea como las demás.
  ///
  /// No es un capricho: una manuscrita de cuerpo doce se lee mucho más chica
  /// que una de palo seco del mismo cuerpo, porque su altura de equis es menor.
  /// Sin esto, elegir Amatic sería elegir «letra diminuta» y la comparación no
  /// diría nada sobre la letra.
  final double scale;

  static NoteFont? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
