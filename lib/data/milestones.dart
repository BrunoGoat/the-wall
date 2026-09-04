/// The varied landmarks that punctuate the wall.
///
/// A milestone is never dropped in finished. It reserves a stretch of the plan
/// and is raised course by course out of the very bricks the person earns, so
/// watching it grow is the reward for the next two weeks of habits.
enum MilestoneKind {
  watchtower,
  gate,
  greatTower,
  stair,
  drawbridge,
  beacon,
  bastion,
  aqueduct,
  shrine,
  barbican,
}

class MilestoneType {
  const MilestoneType({
    required this.kind,
    required this.name,
    required this.brickCost,
    required this.blurb,
    required this.glyph,
  });

  final MilestoneKind kind;
  final String name;
  final int brickCost;
  final String blurb;
  final String glyph;
}

class MilestoneCatalog {
  const MilestoneCatalog._();

  /// Base cost and character of each landmark. Costs are tuned so the first one
  /// completes inside the first month of ordinary use.
  static const Map<MilestoneKind, MilestoneType> base = {
    MilestoneKind.watchtower: MilestoneType(
      kind: MilestoneKind.watchtower,
      name: 'Torre de Vigía',
      brickCost: 22,
      blurb: 'Desde aquí se ve venir el desánimo con mucha antelación.',
      glyph: '🗼',
    ),
    MilestoneKind.gate: MilestoneType(
      kind: MilestoneKind.gate,
      name: 'Puerta de Piedra',
      brickCost: 30,
      blurb: 'Toda muralla que se respeta decide también por dónde se entra.',
      glyph: '🚪',
    ),
    MilestoneKind.greatTower: MilestoneType(
      kind: MilestoneKind.greatTower,
      name: 'Torre Mayor',
      brickCost: 40,
      blurb: 'La primera cosa que se ve desde lejos. Y se ve desde muy lejos.',
      glyph: '🏰',
    ),
    MilestoneKind.stair: MilestoneType(
      kind: MilestoneKind.stair,
      name: 'Escalinata',
      brickCost: 20,
      blurb: 'Ahora se puede subir. Antes solo se podía mirar.',
      glyph: '🪜',
    ),
    MilestoneKind.drawbridge: MilestoneType(
      kind: MilestoneKind.drawbridge,
      name: 'Puente Levadizo',
      brickCost: 34,
      blurb: 'Había un barranco. Ahora hay un cruce, y cadenas para cerrarlo.',
      glyph: '🌉',
    ),
    MilestoneKind.beacon: MilestoneType(
      kind: MilestoneKind.beacon,
      name: 'Almenara',
      brickCost: 26,
      blurb: 'Un fuego que avisa a la torre siguiente que seguís acá.',
      glyph: '🔥',
    ),
    MilestoneKind.bastion: MilestoneType(
      kind: MilestoneKind.bastion,
      name: 'Bastión',
      brickCost: 46,
      blurb: 'El punto donde la muralla deja de defenderse y empieza a imponer.',
      glyph: '🛡️',
    ),
    MilestoneKind.aqueduct: MilestoneType(
      kind: MilestoneKind.aqueduct,
      name: 'Arcada',
      brickCost: 36,
      blurb: 'Arcos para salvar el vacío, porque el vacío también se cruza.',
      glyph: '🌊',
    ),
    MilestoneKind.shrine: MilestoneType(
      kind: MilestoneKind.shrine,
      name: 'Santuario',
      brickCost: 28,
      blurb: 'Un hueco en la piedra para lo que no se puede contar en ladrillos.',
      glyph: '🕯️',
    ),
    MilestoneKind.barbican: MilestoneType(
      kind: MilestoneKind.barbican,
      name: 'Barbacana',
      brickCost: 42,
      blurb: 'Dos torres custodiando un solo paso. Ya no es una pared: es una obra.',
      glyph: '⚔️',
    ),
  };

  /// The order in which landmarks appear. Deliberately shuffled so no two
  /// neighbours share a silhouette.
  static const List<MilestoneKind> order = [
    MilestoneKind.watchtower,
    MilestoneKind.gate,
    MilestoneKind.greatTower,
    MilestoneKind.stair,
    MilestoneKind.drawbridge,
    MilestoneKind.beacon,
    MilestoneKind.bastion,
    MilestoneKind.aqueduct,
    MilestoneKind.shrine,
    MilestoneKind.barbican,
  ];

  /// Names for later laps around the catalogue, so a returning landmark still
  /// reads as a new place rather than a repeat.
  static const Map<MilestoneKind, List<String>> _laterNames = {
    MilestoneKind.watchtower: ['Torre del Alba', 'Atalaya Gemela', 'Vigía del Norte'],
    MilestoneKind.gate: ['Puerta de los Reyes', 'Portón de Hierro', 'Puerta Callada'],
    MilestoneKind.greatTower: ['Torre del Trueno', 'Torre Alta', 'Torre del Ocaso'],
    MilestoneKind.stair: ['Escalera Larga', 'Gradas del Muro', 'Subida del Cantero'],
    MilestoneKind.drawbridge: ['Paso Colgante', 'Puente de las Cadenas', 'Cruce Hondo'],
    MilestoneKind.beacon: ['Fuego Vigía', 'Faro de Tierra', 'Brasero Mayor'],
    MilestoneKind.bastion: ['Bastión Negro', 'Reducto', 'Espolón'],
    MilestoneKind.aqueduct: ['Arcos Largos', 'Acueducto', 'Puente de Arcos'],
    MilestoneKind.shrine: ['Capilla del Muro', 'Nicho de Piedra', 'Altar del Camino'],
    MilestoneKind.barbican: ['Barbacana Doble', 'Antemuro', 'Puerta Fuerte'],
  };

  /// The landmark for milestone number [n] (0-based).
  ///
  /// Each lap through the catalogue adds a little to the cost so later
  /// landmarks feel heavier, and takes a fresh name so nothing feels recycled.
  static MilestoneType typeFor(int n) {
    final kind = order[n % order.length];
    final lap = n ~/ order.length;
    final b = base[kind]!;
    if (lap == 0) return b;
    final names = _laterNames[kind]!;
    return MilestoneType(
      kind: kind,
      name: names[(lap - 1) % names.length],
      brickCost: b.brickCost + 6 * lap,
      blurb: b.blurb,
      glyph: b.glyph,
    );
  }
}
