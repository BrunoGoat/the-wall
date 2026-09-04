/// The hundred epics.
///
/// Exactly one hundred, every one of them different, none ever repeated. They
/// are *hidden*, not handed over: when the brick that carries one is placed the
/// stone gains a faint anomaly, and it stays a secret until the person notices
/// it and taps it. The reveal is the payoff.
enum EpicKind {
  rune,
  gem,
  fossil,
  carving,
  relic,
  creature,
  celestial,
  specter,
  mechanism,
  flora,
}

/// Flavour tier, purely cosmetic: it drives the colour and the intensity of the
/// reveal, and gives the collection a sense of ascent.
enum EpicTier { vestigio, reliquia, prodigio, leyenda }

class Epic {
  const Epic(this.number, this.title, this.lore, this.kind);

  /// 1..100.
  final int number;
  final String title;
  final String lore;
  final EpicKind kind;

  EpicTier get tier {
    if (number <= 40) return EpicTier.vestigio;
    if (number <= 70) return EpicTier.reliquia;
    if (number <= 92) return EpicTier.prodigio;
    return EpicTier.leyenda;
  }

  String get tierName => switch (tier) {
        EpicTier.vestigio => 'Vestigio',
        EpicTier.reliquia => 'Reliquia',
        EpicTier.prodigio => 'Prodigio',
        EpicTier.leyenda => 'Leyenda',
      };
}

const List<Epic> kEpics = [
  Epic(1, 'El Primer Guijarro', 'Debajo de todo esto hay una piedra que nadie eligió. Así empieza todo.', EpicKind.rune),
  Epic(2, 'La Marca del Cantero', 'Una firma diminuta. Alguien quiso que se supiera que estuvo acá.', EpicKind.carving),
  Epic(3, 'Escarabajo de Bronce', 'Verde de siglos. Todavía parece a punto de moverse.', EpicKind.relic),
  Epic(4, 'El Ojo bajo el Musgo', 'Lo apartás con el pulgar y algo devuelve la mirada.', EpicKind.creature),
  Epic(5, 'Vetas de Oro Falso', 'No vale nada y brilla igual. Como casi todo lo importante.', EpicKind.gem),
  Epic(6, 'La Caracola Petrificada', 'Este muro fue fondo de mar. Tuvo paciencia mucho antes que vos.', EpicKind.fossil),
  Epic(7, 'Un Reloj sin Agujas', 'Marca la única hora que importa: esta.', EpicKind.mechanism),
  Epic(8, 'La Estrella Encerrada', 'Quedó atrapada en la piedra y sigue encendida, tozuda.', EpicKind.celestial),
  Epic(9, 'Huella de Alguien que Pasó', 'Una mano se apoyó justo ahí. Hace mil años. Encaja con la tuya.', EpicKind.carving),
  Epic(10, 'Semilla en la Grieta', 'Eligió el peor lugar posible para crecer. Creció igual.', EpicKind.flora),
  Epic(11, 'El Ladrillo que Canta', 'Golpealo y suena una nota limpia. Solo este. Nadie sabe por qué.', EpicKind.rune),
  Epic(12, 'Moneda de un Reino Extinto', 'El reino no existe. La moneda sí. Duró más que su imperio.', EpicKind.relic),
  Epic(13, 'Diente de Dragón', 'Del tamaño de tu antebrazo. Los dragones no existen, claro.', EpicKind.fossil),
  Epic(14, 'La Grieta que Respira', 'Sale aire tibio. Adentro hay algo grande y dormido.', EpicKind.specter),
  Epic(15, 'Cristal de Luna', 'Solo se ve cuando no lo estás buscando.', EpicKind.gem),
  Epic(16, 'El Nombre Borrado', 'Alguien lo talló con cuidado y alguien lo raspó con furia.', EpicKind.carving),
  Epic(17, 'Nido de Vencejos', 'Se mudaron a tu muralla sin pedir permiso. Bienvenidos.', EpicKind.creature),
  Epic(18, 'Engranaje Perdido', 'Pertenece a una máquina que todavía no fue inventada.', EpicKind.mechanism),
  Epic(19, 'Mapa de Constelaciones', 'Un cielo que ya no existe, grabado por alguien que lo extrañaba.', EpicKind.celestial),
  Epic(20, 'Raíz Terca', 'Partió la piedra en dos sin apurarse ni un día.', EpicKind.flora),
  Epic(21, 'El Eco Enterrado', 'Gritás y te contesta con un segundo de más. Siempre uno de más.', EpicKind.specter),
  Epic(22, 'Sello de Cera Roja', 'Nunca fue abierto. La orden que traía ya no le importa a nadie.', EpicKind.relic),
  Epic(23, 'Ámbar con un Insecto', 'Cuarenta millones de años quieto y sigue impecable.', EpicKind.gem),
  Epic(24, 'Runa de la Paciencia', 'Se traduce, más o menos, como: mañana también.', EpicKind.rune),
  Epic(25, 'Costilla de Leviatán', 'Curva, enorme, incrustada como si el muro se la hubiera tragado.', EpicKind.fossil),
  Epic(26, 'La Puerta Diminuta', 'Quince centímetros de alto, con bisagras de verdad. Está cerrada.', EpicKind.carving),
  Epic(27, 'Gato de Piedra', 'Duerme en el sol de la tarde desde antes de que existiera el sol de esta tarde.', EpicKind.creature),
  Epic(28, 'Péndulo Detenido', 'Se paró exactamente el día que dejaste de venir. Ya arrancó de nuevo.', EpicKind.mechanism),
  Epic(29, 'Fragmento de Meteorito', 'Viajó cuatro mil millones de años para terminar en tu pared.', EpicKind.celestial),
  Epic(30, 'Flor que no Existe', 'No figura en ningún libro. Florece una vez cada tanto, sin avisar.', EpicKind.flora),
  Epic(31, 'La Sombra de Más', 'Contás las sombras de las almenas y siempre da una más.', EpicKind.specter),
  Epic(32, 'Llave sin Cerradura', 'Hierro pesado, dientes intactos. Falta la puerta.', EpicKind.relic),
  Epic(33, 'Geoda Violeta', 'Por fuera, un canto rodado feo. Por dentro, una catedral.', EpicKind.gem),
  Epic(34, 'Runa de Volver a Empezar', 'La más gastada de todas. Es la que más se usa.', EpicKind.rune),
  Epic(35, 'Huevo Fosilizado', 'Intacto. Nunca se abrió. Nunca se abrirá. Probablemente.', EpicKind.fossil),
  Epic(36, 'Los Tres Golpes', 'Tres muescas idénticas. Nadie recuerda qué se estaba contando.', EpicKind.carving),
  Epic(37, 'Zorro Tallado', 'Mira hacia atrás, hacia el tramo que ya construiste.', EpicKind.creature),
  Epic(38, 'Brújula que Apunta Acá', 'Da igual dónde la lleves. Siempre señala esta piedra.', EpicKind.mechanism),
  Epic(39, 'El Cometa de tu Año', 'Pasó una vez, el año que empezaste. Vuelve en setenta y seis.', EpicKind.celestial),
  Epic(40, 'Musgo Luminoso', 'De noche dibuja el borde entero de la muralla, como una costura.', EpicKind.flora),
  Epic(41, 'El Constructor que Nadie Vio', 'Aparece en el reflejo del agua, colocando un ladrillo que no está.', EpicKind.specter),
  Epic(42, 'Anillo de Hierro Torcido', 'Ataba algo enorme. La argolla cedió antes que la piedra.', EpicKind.relic),
  Epic(43, 'Cuarzo Lechoso', 'Turbio como un día malo, y aun así atraviesa la luz.', EpicKind.gem),
  Epic(44, 'Runa del Día Difícil', 'Está tallada torcida, con la mano temblando. Vale doble.', EpicKind.rune),
  Epic(45, 'Ala de Piedra', 'Dos metros de envergadura. El resto del animal nunca apareció.', EpicKind.fossil),
  Epic(46, 'Cuenta Regresiva Tallada', 'Llega hasta uno y sigue: cero, menos uno, menos dos...', EpicKind.carving),
  Epic(47, 'Lobo Durmiendo', 'Enroscado en la base, calentito. No lo despiertes.', EpicKind.creature),
  Epic(48, 'Autómata Roto', 'Le falta un brazo y todavía intenta seguir apilando.', EpicKind.mechanism),
  Epic(49, 'Eclipse Grabado', 'El día que el cielo se apagó y la obra no paró.', EpicKind.celestial),
  Epic(50, 'Hiedra Antigua', 'Tan vieja que ya no se sabe si sostiene el muro o al revés.', EpicKind.flora),
  Epic(51, 'La Voz del Fondo', 'Viene de dentro de la piedra y repite tu propio nombre, mal pronunciado.', EpicKind.specter),
  Epic(52, 'Daga sin Filo', 'Se gastó cortando cuerda, no gente. Buena vida tuvo.', EpicKind.relic),
  Epic(53, 'Ópalo de Tormenta', 'Cambia de color según cuánto hace que no venís.', EpicKind.gem),
  Epic(54, 'Runa del Silencio', 'No dice nada. Es su forma de decirlo.', EpicKind.rune),
  Epic(55, 'Espina de Kraken', 'Curva y negra, del largo de una puerta. El mar quedó lejísimos.', EpicKind.fossil),
  Epic(56, 'Manos Impresas', 'Once manos en negativo. Ninguna es del mismo tamaño.', EpicKind.carving),
  Epic(57, 'Cuervo Vigilante', 'Lleva años en la misma almena. Te reconoce.', EpicKind.creature),
  Epic(58, 'Caja que no Abre', 'Sin bisagras, sin tapa, sin junta. Adentro suena algo.', EpicKind.mechanism),
  Epic(59, 'Lluvia de Perseidas', 'Cuarenta rayas finísimas grabadas en una sola noche de agosto.', EpicKind.celestial),
  Epic(60, 'Bosque en Miniatura', 'Un centímetro de liquen que lleva doscientos años creciendo.', EpicKind.flora),
  Epic(61, 'El Pasillo que no Está', 'Hay una corriente de aire donde debería haber piedra maciza.', EpicKind.specter),
  Epic(62, 'Corona Aplastada', 'Alguien la usó de cuña para nivelar una hilada. Buen criterio.', EpicKind.relic),
  Epic(63, 'Obsidiana Negra', 'Tan pulida que te ves. Un poco más viejo, un poco más terco.', EpicKind.gem),
  Epic(64, 'Runa del Que Insiste', 'Solo aparece en murallas que pasaron el año.', EpicKind.rune),
  Epic(65, 'Concha Espiral', 'La misma proporción que usaron para las torres. Nadie se copió.', EpicKind.fossil),
  Epic(66, 'Calendario de Muescas', 'Días buenos hacia arriba, malos hacia abajo. Gana arriba, por poco.', EpicKind.carving),
  Epic(67, 'Ciervo de Musgo', 'Se forma solo con la humedad. Se deshace en verano. Vuelve.', EpicKind.creature),
  Epic(68, 'Mecanismo de Cuerda', 'Le das cuerda y la muralla, por un segundo, zumba entera.', EpicKind.mechanism),
  Epic(69, 'Sol de Invierno', 'Un agujero pasante. Un día al año, la luz cruza y da en el suelo.', EpicKind.celestial),
  Epic(70, 'Hongo Fosforescente', 'Verde eléctrico. Crece únicamente donde el mortero está fresco.', EpicKind.flora),
  Epic(71, 'El Susurro de la Junta', 'Pegá la oreja a la argamasa y se oye una obra trabajando.', EpicKind.specter),
  Epic(72, 'Cadena Fundida', 'El calor que hizo esto no lo hizo ningún fuego conocido.', EpicKind.relic),
  Epic(73, 'Esmeralda Turbia', 'Con una fisura enorme adentro, y por eso vale más.', EpicKind.gem),
  Epic(74, 'Runa del Regreso', 'Se enciende sola el día que volvés después de faltar.', EpicKind.rune),
  Epic(75, 'Pluma Mineralizada', 'Cada barba en su lugar. Pesa como una piedra y parece liviana.', EpicKind.fossil),
  Epic(76, 'Retrato de Perfil', 'No se parece a nadie conocido. Se parece bastante a vos.', EpicKind.carving),
  Epic(77, 'Serpiente Enroscada', 'Rodea una piedra entera, mordiéndose la cola. Ahí sigue.', EpicKind.creature),
  Epic(78, 'Reloj de Arena Sellado', 'La arena cae hacia arriba. Se comprobó tres veces.', EpicKind.mechanism),
  Epic(79, 'Cielo del Sur', 'Constelaciones de un hemisferio al que esta muralla nunca fue.', EpicKind.celestial),
  Epic(80, 'Rosa de Piedra', 'Cristalizó sola, pétalo por pétalo, en la oscuridad.', EpicKind.flora),
  Epic(81, 'El Vecino de Piedra', 'Camina el adarve de noche. Nunca baja. Nunca molesta.', EpicKind.specter),
  Epic(82, 'Yelmo Abollado', 'Una abolladura enorme y ni una sola grieta. Aguantó.', EpicKind.relic),
  Epic(83, 'Zafiro de Grieta', 'Se formó dentro de una fractura. La rotura fue el requisito.', EpicKind.gem),
  Epic(84, 'Runa de la Décima Vez', 'Nueve intentos tachados encima. El décimo, subrayado.', EpicKind.rune),
  Epic(85, 'Garra Enterrada', 'Cinco dedos, cada uno más largo que tu mano. Estaba subiendo.', EpicKind.fossil),
  Epic(86, 'Laberinto Grabado', 'Tiene salida. Tardás menos de lo que pensabas en encontrarla.', EpicKind.carving),
  Epic(87, 'Búho de Cantera', 'Tallado del mismo bloque, sin junta. Salió de adentro de la piedra.', EpicKind.creature),
  Epic(88, 'Llave de Cuerda Musical', 'Toca seis notas. Las mismas seis, siempre. Igual emociona.', EpicKind.mechanism),
  Epic(89, 'Aurora Tallada', 'Ondas verdes en bajorrelieve, a una latitud donde eso es imposible.', EpicKind.celestial),
  Epic(90, 'Trigo Petrificado', 'Una espiga entera. Alguien almorzó acá, apoyado en tu muralla.', EpicKind.flora),
  Epic(91, 'La Puerta que Recuerda', 'Se abre sola para quien ya pasó antes por acá.', EpicKind.specter),
  Epic(92, 'Estandarte Deshecho', 'Queda el asta y tres hilos. Se plantó igual, cada mañana.', EpicKind.relic),
  Epic(93, 'Diamante Bruto', 'Sin tallar, sin pulir, sin adornos. Es lo que lo vuelve imposible de falsificar.', EpicKind.gem),
  Epic(94, 'Runa del Último Tramo', 'Aparece cuando ya no hace falta que aparezca nada.', EpicKind.rune),
  Epic(95, 'Cráneo de Ave Gigante', 'El pico solo mide un metro. Miraba desde muy arriba.', EpicKind.fossil),
  Epic(96, 'Autorretrato del Cantero', 'Se talló a sí mismo colocando un ladrillo. Es la única imagen que dejó.', EpicKind.carving),
  Epic(97, 'Dragón Dormido', 'La muralla no lo rodea: se apoya en él. Siempre fue el cimiento.', EpicKind.creature),
  Epic(98, 'Motor de las Estrellas', 'Gira despacísimo. Una vuelta cada veintiséis mil años.', EpicKind.mechanism),
  Epic(99, 'El Cielo Entero', 'Toda la bóveda celeste en una sola piedra, y sobra sitio.', EpicKind.celestial),
  Epic(100, 'La Muralla dentro de la Muralla', 'Adentro de esta piedra hay una muralla igual a la tuya, con alguien construyéndola.', EpicKind.specter),
];
