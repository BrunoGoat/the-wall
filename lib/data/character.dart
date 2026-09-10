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
    required this.symbol,
    required this.storey,
    required this.spread,
    required this.pitch,
    required this.roofMix,
    required this.wash,
    required this.washShare,
    required this.plotPitch,
    required this.order,
    this.wallThick = 0.0,
    this.windowGap = 1.0,
    this.gardens = 0.0,
    this.trees = 0.0,
  });

  /// What this kind of place is called, and one line about it.
  final String region;
  final String blurb;

  /// The mark it is chosen by when a habit is founded. One of the same
  /// thirty-six the habits themselves wear, because they are the only marks
  /// this app knows how to draw.
  final String symbol;

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

  /// How thick the walls are, from nothing to as thick as they get.
  ///
  /// A wall has no thickness in this world — every house is a closed box — so
  /// thickness is read where a real one is read: at the openings. A thick wall
  /// makes a narrower window and sets it deep, so it is ringed by its own
  /// shadow; a thin one puts the glass almost flush. Nobody measures a wall,
  /// they look at a window and know.
  final double wallThick;

  /// How far apart the windows sit, as a multiple of the ordinary spacing.
  /// Above one is a frontier town that would rather have wall than window.
  final double windowGap;

  /// What this place puts on the ground beside a house: the share of houses
  /// with a kitchen garden, and the share with a tree over them.
  ///
  /// Neither is earned and neither is a piece. A garden is not an achievement,
  /// it is what a plot looks like in a place where people grow things, and
  /// charging an achievement for it would be charging for the scenery.
  final double gardens, trees;

  /// Seeds this town's own shuffle of the landmark catalogue, so no two towns
  /// meet the hundred and twelve in the same order.
  final int order;

  static const List<TownCharacter> all = [
    TownCharacter(
      region: 'Ribera',
      symbol: 'gota',
      blurb: 'Casas anchas y bajas, encaladas de blanco, casi todas de teja.',
      storey: 0.9,
      spread: 1.2,
      pitch: 0.8,
      roofMix: (0.72, 0.10, 0.18),
      wash: Color(0xFFF2E6D2),
      washShare: 0.86,
      plotPitch: 2.8,
      order: 0x1A7C,
      wallThick: 0.10,
      windowGap: 0.90,
      gardens: 0.30,
      trees: 0.10,
    ),
    TownCharacter(
      region: 'Sierra',
      symbol: 'montana',
      blurb: 'Alta y apretada, de piedra gris y pizarra, con tejados agudos.',
      storey: 1.34,
      spread: 0.8,
      pitch: 1.3,
      roofMix: (0.12, 0.76, 0.12),
      wash: Color(0xFFB9B7AE),
      washShare: 0.8,
      plotPitch: 2.1,
      order: 0x33F1,
      wallThick: 0.65,
      windowGap: 1.15,
      gardens: 0.10,
      trees: 0.05,
    ),
    TownCharacter(
      region: 'Marca',
      symbol: 'escudo',
      blurb: 'De frontera: muros gruesos, ocre, pocas ventanas y todo junto.',
      storey: 1.06,
      spread: 1.0,
      pitch: 0.92,
      roofMix: (0.52, 0.34, 0.14),
      wash: Color(0xFFD8A64C),
      washShare: 0.84,
      plotPitch: 2.2,
      order: 0x5E02,
      wallThick: 1.00,
      windowGap: 1.55,
      gardens: 0.08,
      trees: 0.04,
    ),
    TownCharacter(
      region: 'Valle',
      symbol: 'espiga',
      blurb: 'Madera y paja, solares grandes y huerta en casi todas.',
      storey: 0.96,
      spread: 1.1,
      pitch: 1.2,
      roofMix: (0.18, 0.14, 0.68),
      wash: Color(0xFFC7B48C),
      washShare: 0.74,
      plotPitch: 3.6,
      order: 0x7B45,
      wallThick: 0.25,
      windowGap: 1.00,
      gardens: 1.00,
      trees: 0.34,
    ),
    TownCharacter(
      region: 'Costa',
      symbol: 'ola',
      blurb: 'Cal y añil, tejados casi planos y mucho aire entre las casas.',
      storey: 0.8,
      spread: 1.1,
      pitch: 0.52,
      roofMix: (0.62, 0.24, 0.14),
      wash: Color(0xFF9EC0D2),
      washShare: 0.88,
      plotPitch: 3.05,
      order: 0x91C8,
      wallThick: 0.00,
      windowGap: 0.85,
      gardens: 0.16,
      trees: 0.08,
    ),
    TownCharacter(
      region: 'Robledal',
      symbol: 'arbol',
      blurb: 'Madera oscura bajo los robles, tejados de paja muy inclinados.',
      storey: 1.16,
      spread: 0.88,
      pitch: 1.75,
      roofMix: (0.10, 0.20, 0.70),
      wash: Color(0xFF9A7C55),
      washShare: 0.78,
      plotPitch: 2.75,
      order: 0xB30D,
      wallThick: 0.30,
      windowGap: 1.10,
      gardens: 0.40,
      trees: 0.88,
    ),
  ];

  /// The one a plot would have been given before anybody was asked. Kept for
  /// towns founded when the valley chose for you.
  static TownCharacter forSlot(int slot) => all[slot.abs() % all.length];

  /// By its stable id. Anything unknown falls back to the first, so a save
  /// from a version that had a region this one does not still opens.
  static TownCharacter byOrder(int order) {
    for (final c in all) {
      if (c.order == order) return c;
    }
    return all.first;
  }
}
