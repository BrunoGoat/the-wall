import 'dart:ui';

/// What kind of place a town is.
///
/// Four habits must not feel like the same thing four times. The pieces are
/// laid the same way — one achievement, one piece, never moved — but the place
/// they build is not: its houses are taller or wider, its roofs are tile or
/// slate or thatch, its streets are tight or open, its walls are limewashed
/// white or ochre or grey stone, and its hundred and twelve landmarks arrive
/// in a different order.
///
/// Characters are assigned by plot, not at random, so the six are always as
/// different from each other as the catalogue allows — and so a town never
/// changes character underneath somebody.
class TownCharacter {
  const TownCharacter({
    required this.region,
    required this.blurb,
    required this.storey,
    required this.spread,
    required this.pitch,
    required this.roofMix,
    required this.wash,
    required this.washShare,
    required this.plotPitch,
    required this.order,
  });

  /// What this kind of place is called, and one line about it.
  final String region;
  final String blurb;

  /// How tall a storey is here, and how wide a house sits. Northern towns pile
  /// their storeys up; southern ones spread out.
  final double storey;
  final double spread;

  /// How steep the roofs are. Snow country pitches steep; dry country does not.
  final double pitch;

  /// The share of tile, slate and thatch, in that order. Adds to one.
  final (double, double, double) roofMix;

  /// The limewash this town favours, and how many houses take it.
  final Color wash;
  final double washShare;

  /// How close together the plots are laid. Tight towns feel like a city;
  /// open ones feel like a village that grew.
  final double plotPitch;

  /// Seeds this town's own shuffle of the landmark catalogue, so no two towns
  /// meet the hundred and twelve in the same order.
  final int order;

  static const List<TownCharacter> all = [
    TownCharacter(
      region: 'Ribera',
      blurb: 'Casas bajas y encaladas, tejado de teja y calles anchas.',
      storey: 0.96,
      spread: 1.14,
      pitch: 0.86,
      roofMix: (0.72, 0.10, 0.18),
      wash: Color(0xFFF2E6D2),
      washShare: 0.58,
      plotPitch: 2.7,
      order: 0x1A7C,
    ),
    TownCharacter(
      region: 'Sierra',
      blurb: 'Alta y apretada, de piedra gris y pizarra, con tejados agudos.',
      storey: 1.18,
      spread: 0.86,
      pitch: 1.34,
      roofMix: (0.12, 0.76, 0.12),
      wash: Color(0xFFB9B7AE),
      washShare: 0.66,
      plotPitch: 2.25,
      order: 0x33F1,
    ),
    TownCharacter(
      region: 'Marca',
      blurb: 'De frontera: muros gruesos, ocre, pocas ventanas y todo junto.',
      storey: 1.02,
      spread: 1.02,
      pitch: 0.92,
      roofMix: (0.52, 0.34, 0.14),
      wash: Color(0xFFD8A64C),
      washShare: 0.50,
      plotPitch: 2.3,
      order: 0x5E02,
    ),
    TownCharacter(
      region: 'Valle',
      blurb: 'Madera y paja, solares grandes y una huerta en cada casa.',
      storey: 1.0,
      spread: 1.08,
      pitch: 1.16,
      roofMix: (0.18, 0.14, 0.68),
      wash: Color(0xFFC7B48C),
      washShare: 0.44,
      plotPitch: 2.95,
      order: 0x7B45,
    ),
    TownCharacter(
      region: 'Costa',
      blurb: 'Cal y añil, tejados casi planos y mucho aire entre las casas.',
      storey: 0.92,
      spread: 1.10,
      pitch: 0.62,
      roofMix: (0.62, 0.24, 0.14),
      wash: Color(0xFF9EC0D2),
      washShare: 0.62,
      plotPitch: 2.85,
      order: 0x91C8,
    ),
    TownCharacter(
      region: 'Robledal',
      blurb: 'Madera oscura bajo los robles, tejados de paja muy inclinados.',
      storey: 1.10,
      spread: 0.92,
      pitch: 1.40,
      roofMix: (0.10, 0.20, 0.70),
      wash: Color(0xFF9A7C55),
      washShare: 0.56,
      plotPitch: 2.4,
      order: 0xB30D,
    ),
  ];

  static TownCharacter forSlot(int slot) => all[slot.abs() % all.length];
}
