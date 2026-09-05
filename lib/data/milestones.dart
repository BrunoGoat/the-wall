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
  roundTower,
  albarrana,
  cistern,
  bentGate,
  outworks,
  postern,
  machicolation,
  belfry,
  clockTower,
  windmill,
  doubleArcade,
  twinStair,
  moatBridge,
  spurTower,
  triumphalArch,
  casemate,
  buttresses,
  octagonTower,
  dovecote,
  lighthouse,
}

class MilestoneType {
  const MilestoneType({
    required this.kind,
    required this.name,
    required this.brickCost,
    required this.blurb,
  });

  final MilestoneKind kind;
  final String name;
  final int brickCost;
  final String blurb;
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
    ),
    MilestoneKind.gate: MilestoneType(
      kind: MilestoneKind.gate,
      name: 'Puerta de Piedra',
      brickCost: 30,
      blurb: 'Toda muralla que se respeta decide también por dónde se entra.',
    ),
    MilestoneKind.greatTower: MilestoneType(
      kind: MilestoneKind.greatTower,
      name: 'Torre Mayor',
      brickCost: 40,
      blurb: 'La primera cosa que se ve desde lejos. Y se ve desde muy lejos.',
    ),
    MilestoneKind.stair: MilestoneType(
      kind: MilestoneKind.stair,
      name: 'Escalinata',
      brickCost: 20,
      blurb: 'Ahora se puede subir. Antes solo se podía mirar.',
    ),
    MilestoneKind.drawbridge: MilestoneType(
      kind: MilestoneKind.drawbridge,
      name: 'Puente Levadizo',
      brickCost: 34,
      blurb: 'Había un barranco. Ahora hay un cruce, y cadenas para cerrarlo.',
    ),
    MilestoneKind.beacon: MilestoneType(
      kind: MilestoneKind.beacon,
      name: 'Almenara',
      brickCost: 26,
      blurb: 'Un fuego que avisa a la torre siguiente que seguís acá.',
    ),
    MilestoneKind.bastion: MilestoneType(
      kind: MilestoneKind.bastion,
      name: 'Bastión',
      brickCost: 46,
      blurb: 'El punto donde la muralla deja de defenderse y empieza a imponer.',
    ),
    MilestoneKind.aqueduct: MilestoneType(
      kind: MilestoneKind.aqueduct,
      name: 'Arcada',
      brickCost: 36,
      blurb: 'Arcos para salvar el vacío, porque el vacío también se cruza.',
    ),
    MilestoneKind.shrine: MilestoneType(
      kind: MilestoneKind.shrine,
      name: 'Santuario',
      brickCost: 28,
      blurb: 'Un hueco en la piedra para lo que no se puede contar en ladrillos.',
    ),
    MilestoneKind.barbican: MilestoneType(
      kind: MilestoneKind.barbican,
      name: 'Barbacana',
      brickCost: 42,
      blurb: 'Dos torres custodiando un solo paso. Ya no es una pared: es una obra.',
    ),
    MilestoneKind.roundTower: MilestoneType(
      kind: MilestoneKind.roundTower,
      name: 'Torreón Circular',
      brickCost: 38,
      blurb: 'Sin esquinas donde apoyar una escalera. Alguien pensó en todo.',
    ),
    MilestoneKind.albarrana: MilestoneType(
      kind: MilestoneKind.albarrana,
      name: 'Torre Albarrana',
      brickCost: 44,
      blurb: 'Separada del muro, unida por un solo arco. Si cae, cae sola.',
    ),
    MilestoneKind.cistern: MilestoneType(
      kind: MilestoneKind.cistern,
      name: 'Aljibe',
      brickCost: 24,
      blurb: 'Agua guardada para el mes en que no llueva. Y no va a llover.',
    ),
    MilestoneKind.bentGate: MilestoneType(
      kind: MilestoneKind.bentGate,
      name: 'Puerta de Codo',
      brickCost: 38,
      blurb: 'Se entra, se dobla, y recién ahí se ve lo que hay adentro.',
    ),
    MilestoneKind.outworks: MilestoneType(
      kind: MilestoneKind.outworks,
      name: 'Antemuro',
      brickCost: 32,
      blurb: 'Una segunda muralla, más baja, delante de la primera. Por las dudas.',
    ),
    MilestoneKind.postern: MilestoneType(
      kind: MilestoneKind.postern,
      name: 'Poterna',
      brickCost: 18,
      blurb: 'La puerta chica que nadie mira. La que de verdad se usa.',
    ),
    MilestoneKind.machicolation: MilestoneType(
      kind: MilestoneKind.machicolation,
      name: 'Matacán',
      brickCost: 24,
      blurb: 'Un balcón sin piso, colgado del muro. No es para asomarse.',
    ),
    MilestoneKind.belfry: MilestoneType(
      kind: MilestoneKind.belfry,
      name: 'Campanario',
      brickCost: 40,
      blurb: 'Ahora la muralla puede avisar. Antes solo podía aguantar.',
    ),
    MilestoneKind.clockTower: MilestoneType(
      kind: MilestoneKind.clockTower,
      name: 'Torre del Reloj',
      brickCost: 44,
      blurb: 'Marca las horas de una ciudad que todavía no existe.',
    ),
    MilestoneKind.windmill: MilestoneType(
      kind: MilestoneKind.windmill,
      name: 'Molino',
      brickCost: 36,
      blurb: 'Lo primero que se construye acá que no sirve para defenderse.',
    ),
    MilestoneKind.doubleArcade: MilestoneType(
      kind: MilestoneKind.doubleArcade,
      name: 'Arcada Doble',
      brickCost: 48,
      blurb: 'Arcos sobre arcos. Se cruzó el vacío, y después se cruzó más alto.',
    ),
    MilestoneKind.twinStair: MilestoneType(
      kind: MilestoneKind.twinStair,
      name: 'Escalera Doble',
      brickCost: 30,
      blurb: 'Dos tramos que suben enfrentados y se encuentran arriba.',
    ),
    MilestoneKind.moatBridge: MilestoneType(
      kind: MilestoneKind.moatBridge,
      name: 'Puente sobre el Foso',
      brickCost: 40,
      blurb: 'De piedra, esta vez. Los puentes de madera se queman.',
    ),
    MilestoneKind.spurTower: MilestoneType(
      kind: MilestoneKind.spurTower,
      name: 'Torre del Espolón',
      brickCost: 34,
      blurb: 'Termina en pico, como una proa. Desvía todo lo que le pega.',
    ),
    MilestoneKind.triumphalArch: MilestoneType(
      kind: MilestoneKind.triumphalArch,
      name: 'Arco Triunfal',
      brickCost: 42,
      blurb: 'No defiende nada. Está para que se note que llegaste hasta acá.',
    ),
    MilestoneKind.casemate: MilestoneType(
      kind: MilestoneKind.casemate,
      name: 'Casamata',
      brickCost: 30,
      blurb: 'Una sala hundida en el espesor del muro. Fresca todo el año.',
    ),
    MilestoneKind.buttresses: MilestoneType(
      kind: MilestoneKind.buttresses,
      name: 'Contrafuertes',
      brickCost: 26,
      blurb: 'El muro empezaba a ceder. Ahora ya no.',
    ),
    MilestoneKind.octagonTower: MilestoneType(
      kind: MilestoneKind.octagonTower,
      name: 'Torre Octogonal',
      brickCost: 42,
      blurb: 'Ocho caras. Alguien tuvo tiempo, y ganas de lucirse.',
    ),
    MilestoneKind.dovecote: MilestoneType(
      kind: MilestoneKind.dovecote,
      name: 'Palomar',
      brickCost: 22,
      blurb: 'Cien nichos en la piedra. Ahora la muralla también manda cartas.',
    ),
    MilestoneKind.lighthouse: MilestoneType(
      kind: MilestoneKind.lighthouse,
      name: 'Faro',
      brickCost: 50,
      blurb: 'Lo más alto que construiste. Se ve desde donde ya no se ve nada más.',
    ),
  };

  /// The order in which landmarks appear. Deliberately shuffled so no two
  /// neighbours share a silhouette family.
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
    MilestoneKind.postern,
    MilestoneKind.roundTower,
    MilestoneKind.buttresses,
    MilestoneKind.belfry,
    MilestoneKind.outworks,
    MilestoneKind.moatBridge,
    MilestoneKind.cistern,
    MilestoneKind.albarrana,
    MilestoneKind.twinStair,
    MilestoneKind.triumphalArch,
    MilestoneKind.machicolation,
    MilestoneKind.octagonTower,
    MilestoneKind.bentGate,
    MilestoneKind.windmill,
    MilestoneKind.casemate,
    MilestoneKind.doubleArcade,
    MilestoneKind.dovecote,
    MilestoneKind.spurTower,
    MilestoneKind.clockTower,
    MilestoneKind.lighthouse,
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
    MilestoneKind.barbican: ['Barbacana Doble', 'Antemuro Mayor', 'Puerta Fuerte'],
    MilestoneKind.roundTower: ['Cubo del Muro', 'Torreón Viejo', 'Tambor de Piedra'],
    MilestoneKind.albarrana: ['Torre Exenta', 'Torre del Puente', 'Albarrana Alta'],
    MilestoneKind.cistern: ['Aljibe Hondo', 'Cisterna', 'Pozo del Muro'],
    MilestoneKind.bentGate: ['Puerta Torcida', 'Codo del Muro', 'Entrada Doblada'],
    MilestoneKind.outworks: ['Falsabraga', 'Muro Bajo', 'Camisa'],
    MilestoneKind.postern: ['Portillo', 'Puerta Falsa', 'Salida Chica'],
    MilestoneKind.machicolation: ['Ladronera', 'Balcón Ciego', 'Matacán Doble'],
    MilestoneKind.belfry: ['Espadaña', 'Torre de la Campana', 'Campanil'],
    MilestoneKind.clockTower: ['Torre de las Horas', 'Reloj del Muro', 'Torre Puntual'],
    MilestoneKind.windmill: ['Molino Viejo', 'Aspa de Piedra', 'Molino del Cerro'],
    MilestoneKind.doubleArcade: ['Arcada Alta', 'Doble Puente', 'Arcos Sobre Arcos'],
    MilestoneKind.twinStair: ['Escaleras Gemelas', 'Doble Subida', 'Gradas Enfrentadas'],
    MilestoneKind.moatBridge: ['Puente de Piedra', 'Paso del Foso', 'Puente Largo'],
    MilestoneKind.spurTower: ['Torre en Proa', 'Espolón Alto', 'Pico de Piedra'],
    MilestoneKind.triumphalArch: ['Arco de los Años', 'Puerta de Honor', 'Arco Mayor'],
    MilestoneKind.casemate: ['Bóveda del Muro', 'Sala Hundida', 'Casamata Doble'],
    MilestoneKind.buttresses: ['Estribos', 'Machones', 'Contrafuertes Largos'],
    MilestoneKind.octagonTower: ['Torre de Ocho Caras', 'Octógono', 'Torre Labrada'],
    MilestoneKind.dovecote: ['Palomar Grande', 'Nidal de Piedra', 'Torre de Palomas'],
    MilestoneKind.lighthouse: ['Faro Mayor', 'Linterna', 'Torre de la Luz'],
  };

  /// The landmark for milestone number [n] (0-based).
  ///
  /// Each lap through the catalogue adds a little to the cost so later
  /// landmarks feel heavier, and takes a fresh name so nothing feels recycled.
  /// How much dearer a landmark gets as the wall grows under it.
  ///
  /// A landmark is built to the height of the wall it stands in, and the wall
  /// levels up. Without this the later, much taller landmarks would have to be
  /// built out of the same handful of stones, and each one would end up a pile
  /// of boulders instead of masonry.
  ///
  /// [wallGrowth] is how much taller the wall is where this landmark begins,
  /// which is a function of the landmark's number alone — never of how many
  /// bricks exist — so the plan of the whole wall is fixed from the first day
  /// and nothing ever shifts under a stone already laid. The first landmarks
  /// are untouched: the opening month is the one piece of pacing that cannot
  /// move.
  static double growth(int n, double wallGrowth) => 1 + 0.62 * (wallGrowth - 1);

  static MilestoneType typeFor(int n, {double wallGrowth = 1.0}) {
    final kind = order[n % order.length];
    final lap = n ~/ order.length;
    final b = base[kind]!;
    final cost = ((b.brickCost + 6 * lap) * growth(n, wallGrowth)).round();
    if (lap == 0 && cost == b.brickCost) return b;
    return MilestoneType(
      kind: kind,
      name: lap == 0 ? b.name : _laterNames[kind]![(lap - 1) % _laterNames[kind]!.length],
      brickCost: cost,
      blurb: b.blurb,
    );
  }
}
