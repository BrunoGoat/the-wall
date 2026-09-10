import 'package:flutter/material.dart';

/// Diez tablones de anuncios.
///
/// El fondo es madera en los diez, que es lo que se pidió y lo que el pueblo
/// tiene de verdad. Lo que se rediseña es todo lo demás: el remate de arriba,
/// el marco, los postes, el tono de la madera y su veta, la forma y el ancho
/// del papel, con qué se clava, la tinta y cómo se escribe el nombre.
///
/// **De dónde salen los colores.** El tablón existe en tres dimensiones en la
/// plaza y hay que reconocerlo al entrar: dos postes oscuros (`#6B573F`), una
/// plancha pálida (`#C9B896`), un tejadito bajo a dos aguas (`#8A7355`) y tres
/// papeles crema (`#F0E7D2`). La pantalla llevaba una madera más oscura y
/// anaranjada que la del modelo, sin postes y con el tejado ocupando cuarenta
/// y dos píxeles de pantalla, así que no se parecía a la cosa a la que uno se
/// acababa de acercar. Los diez parten de esa paleta y se van de ella a
/// propósito, no por descuido.
///
/// **Y arriba pesan poco.** El remate más alto de los diez mide veintiséis
/// píxeles, y varios miden doce. En el modelo el tejado es un sexto de lo que
/// mide la plancha; en la pantalla era casi lo mismo que una nota.
enum BoardLook {
  /// El del pueblo, tal cual: plancha pálida entre dos postes y su tejadito.
  poste,

  /// Sin marco. La madera llega a los bordes y los papeles ocupan todo el
  /// ancho, como un panel de obra clavado a la pared.
  alero,

  /// Nogal oscuro y papel de verdad: bordes rasgados y lacre en vez de
  /// chincheta.
  pergamino,

  /// Pino descolorido y recortes pequeños, clavados torcidos con clavos de
  /// hierro. Un tablón al que le fue clavando gente distinta.
  clavado,

  /// El bando del pregonero: madera formal, esquinas rectas, banda tallada
  /// arriba y sello de lacre en cada hoja.
  bando,

  /// Listones horizontales con hueco entre ellos, y los papeles metidos por
  /// detrás: cada uno lleva un listón cruzándole la cabeza.
  liston,

  /// Roble oscuro con moldura biselada, como un cuadro. Chinchetas de latón y
  /// papeles rectos.
  roble,

  /// Madera de miel y papeles de colores fuertes, colgados de un cordel y
  /// pegados con cinta. Un tablón de feria.
  feria,

  /// Madera ahumada de taberna: casi negra, papeles grises, tachuelas y las
  /// notas pegadas unas a otras.
  taberna,

  /// El nombre tallado en la madera y los papeles metidos en ranuras: nada los
  /// sujeta por delante, sólo la sombra dice que están puestos.
  muesca;

  String get label => const {
    BoardLook.poste: 'Poste',
    BoardLook.alero: 'Alero',
    BoardLook.pergamino: 'Pergamino',
    BoardLook.clavado: 'Clavado',
    BoardLook.bando: 'Bando',
    BoardLook.liston: 'Listones',
    BoardLook.roble: 'Roble',
    BoardLook.feria: 'Feria',
    BoardLook.taberna: 'Taberna',
    BoardLook.muesca: 'Muesca',
  }[this]!;

  static BoardLook? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  BoardSkin get skin => _skins[index];
}

/// El remate de arriba. Es lo que más decide si la cosa se lee como un tablón
/// de la plaza o como un panel, y es lo que estaba comiéndose la pantalla.
enum TopKind {
  /// Las dos aguas del modelo, en pequeño.
  tejado,

  /// Un alero recto que sobresale por los dos lados.
  alero,

  /// Un listón oscuro a ras, sin volar.
  liston,

  /// Un cordel con dos nudos, del que cuelga lo demás.
  cordel,

  /// Nada: la madera empieza arriba del todo.
  nada,
}

/// Con qué está sujeto el papel.
enum PinKind { chincheta, clavo, lacre, tachuela, cinta, ninguno }

/// Qué forma tiene el papel.
enum PaperShape {
  /// Cortado a máquina.
  recto,

  /// Rasgado por abajo.
  rasgado,

  /// Con un listón cruzándole la cabeza, porque está metido por detrás.
  tapado,
}

/// Cómo está escrito el nombre del hábito.
enum HeadKind {
  /// Quemado en la madera.
  quemado,

  /// Tallado: hundido, con una luz por debajo del trazo.
  tallado,

  /// En su propia etiqueta de papel.
  tarjeta,

  /// En una banda oscura de lado a lado.
  banda,
}

/// De qué está hecho un tablón.
class BoardSkin {
  const BoardSkin({
    required this.top,
    required this.topHeight,
    required this.topColor,
    required this.posts,
    required this.postColor,
    required this.wood,
    required this.grain,
    required this.frame,
    required this.frameWidth,
    required this.radius,
    required this.bevel,
    required this.papers,
    required this.shape,
    required this.inset,
    required this.lean,
    required this.gap,
    required this.pin,
    required this.pinColor,
    required this.shadow,
    required this.ink,
    required this.head,
    required this.heading,
  });

  final TopKind top;

  /// Lo que se lleva de pantalla el remate. Ninguno pasa de veintiséis.
  final double topHeight;
  final Color topColor;

  /// Dos postes oscuros a los lados, como los de la plaza.
  final bool posts;
  final Color postColor;

  final Color wood;
  final BoardGrain grain;

  final Color frame;
  final double frameWidth;
  final double radius;

  /// Una luz por dentro del marco, para que la moldura tenga bulto.
  final bool bevel;

  final List<Color> papers;
  final PaperShape shape;

  /// Cuánto del ancho ocupa un papel. Uno estrecho se lee como recorte y uno
  /// que llega a los dos bordes, como hoja de obra.
  final double inset;

  /// Cuánto se tuerce, en grados.
  final double lean;

  /// Cuánto aire hay entre uno y otro.
  final double gap;

  final PinKind pin;
  final Color pinColor;
  final double shadow;

  final Color ink;
  final HeadKind head;
  final Color heading;

  /// Cuánto respira el tablón contra los bordes de la pantalla. Va con el
  /// remate: el que llega a los bordes no puede tener margen.
  double get margin => frameWidth == 0 ? 0 : 10;
}

/// La veta, que no es la misma en un pino descolorido que en un roble ahumado.
enum GrainKind {
  /// Tablas verticales con sus juntas.
  tablas,

  /// Listones horizontales con hueco oscuro entre ellos.
  listones,

  /// Vetas largas y nudos.
  nudos,

  /// Manchas blandas de humo, sin una sola línea recta.
  humo,

  /// Casi lisa: dos juntas y poco más.
  lisa,
}

class BoardGrain extends CustomPainter {
  const BoardGrain(this.kind, this.dark, {this.slats = 5});

  final GrainKind kind;
  final Color dark;

  /// Cuántas tablas o listones.
  final int slats;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case GrainKind.tablas:
        _tablas(canvas, size);
      case GrainKind.listones:
        _listones(canvas, size);
      case GrainKind.nudos:
        _nudos(canvas, size);
      case GrainKind.humo:
        _humo(canvas, size);
      case GrainKind.lisa:
        _lisa(canvas, size);
    }
  }

  void _tablas(Canvas canvas, Size size) {
    final junta = Paint()
      ..color = dark.withValues(alpha: 0.5)
      ..strokeWidth = 1.6;
    final veta = Paint()
      ..color = dark.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var i = 1; i < slats; i++) {
      final x = size.width * i / slats;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), junta);
    }
    for (var i = 0; i < 26; i++) {
      final x = size.width * ((i % slats) + 0.2 + (i % 3) * 0.22) / slats;
      final y = size.height * (i + 0.3) / 26;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + size.height * (0.03 + (i % 4) * 0.015)),
        veta,
      );
    }
  }

  void _listones(Canvas canvas, Size size) {
    final hueco = Paint()..color = dark.withValues(alpha: 0.72);
    final luz = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    final alto = size.height / slats;
    for (var i = 0; i < slats; i++) {
      final y = alto * (i + 1);
      canvas.drawRect(Rect.fromLTWH(0, y - 3.5, size.width, 3.5), hueco);
      canvas.drawLine(Offset(0, y - 3.5), Offset(size.width, y - 3.5), luz);
    }
  }

  void _nudos(Canvas canvas, Size size) {
    final veta = Paint()
      ..color = dark.withValues(alpha: 0.2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 11; i++) {
      final y = size.height * (i + 0.4) / 11;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += size.width / 6) {
        path.quadraticBezierTo(
          x + size.width / 12,
          y + (i.isEven ? 5 : -5),
          x + size.width / 6,
          y,
        );
      }
      canvas.drawPath(path, veta);
    }
    // Tres nudos, que es lo que de verdad se ve en una tabla.
    final nudo = Paint()
      ..color = dark.withValues(alpha: 0.34)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final at in [
      Offset(size.width * 0.22, size.height * 0.18),
      Offset(size.width * 0.78, size.height * 0.46),
      Offset(size.width * 0.4, size.height * 0.82),
    ]) {
      for (var r = 2.0; r < 9; r += 2.6) {
        canvas.drawOval(
          Rect.fromCenter(center: at, width: r * 2.4, height: r * 1.5),
          nudo,
        );
      }
    }
  }

  void _humo(Canvas canvas, Size size) {
    var h = 0x51A3B;
    for (var i = 0; i < 60; i++) {
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      final x = (h >> 7) % size.width.round().clamp(1, 1 << 20);
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      final y = (h >> 7) % size.height.round().clamp(1, 1 << 20);
      canvas.drawCircle(
        Offset(x.toDouble(), y.toDouble()),
        9.0 + ((h >> 5) % 26),
        Paint()
          ..color = (i.isEven ? dark : Colors.white).withValues(alpha: 0.045),
      );
    }
  }

  void _lisa(Canvas canvas, Size size) {
    final junta = Paint()
      ..color = dark.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    for (final f in [0.34, 0.71]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        junta,
      );
    }
  }

  @override
  bool shouldRepaint(BoardGrain old) =>
      old.kind != kind || old.dark != dark || old.slats != slats;
}

// ---------------------------------------------------------------- los diez

const List<BoardSkin> _skins = [
  // 1. Poste — el de la plaza, con sus colores exactos.
  BoardSkin(
    top: TopKind.tejado,
    topHeight: 24,
    topColor: Color(0xFF8A7355),
    posts: true,
    postColor: Color(0xFF6B573F),
    wood: Color(0xFFC9B896),
    grain: BoardGrain(GrainKind.tablas, Color(0xFF8A7355), slats: 4),
    frame: Color(0xFF6B573F),
    frameWidth: 2,
    radius: 3,
    bevel: false,
    papers: [Color(0xFFF0E7D2), Color(0xFFE4EDD4), Color(0xFFF3E9C6)],
    shape: PaperShape.recto,
    inset: 0.93,
    lean: 1.1,
    gap: 12,
    pin: PinKind.chincheta,
    pinColor: Color(0xFF9C4A3C),
    shadow: 0.24,
    ink: Color(0xFF3B3730),
    head: HeadKind.quemado,
    heading: Color(0xFF6B573F),
  ),

  // 2. Alero — sin marco, a sangre, papeles de lado a lado.
  BoardSkin(
    top: TopKind.alero,
    topHeight: 13,
    topColor: Color(0xFF5E4A31),
    posts: false,
    postColor: Color(0xFF5E4A31),
    wood: Color(0xFFA8875D),
    grain: BoardGrain(GrainKind.tablas, Color(0xFF6E5738), slats: 3),
    frame: Color(0x00000000),
    frameWidth: 0,
    radius: 0,
    bevel: false,
    papers: [Color(0xFFF6F1E2)],
    shape: PaperShape.recto,
    inset: 1.0,
    lean: 0,
    gap: 9,
    pin: PinKind.ninguno,
    pinColor: Color(0xFF5E4A31),
    shadow: 0.34,
    ink: Color(0xFF332F28),
    head: HeadKind.banda,
    heading: Color(0xFFF6F1E2),
  ),

  // 3. Pergamino — nogal, papel rasgado, lacre.
  BoardSkin(
    top: TopKind.liston,
    topHeight: 11,
    topColor: Color(0xFF3E2F21),
    posts: false,
    postColor: Color(0xFF3E2F21),
    wood: Color(0xFF5A4632),
    grain: BoardGrain(GrainKind.nudos, Color(0xFF2E2317)),
    frame: Color(0xFF3E2F21),
    frameWidth: 3,
    radius: 2,
    bevel: false,
    papers: [Color(0xFFE8DCBE), Color(0xFFE2D6B4), Color(0xFFEFE4C8)],
    shape: PaperShape.rasgado,
    inset: 0.9,
    lean: 1.6,
    gap: 15,
    pin: PinKind.lacre,
    pinColor: Color(0xFF8E3B2E),
    shadow: 0.42,
    ink: Color(0xFF3A2E1E),
    head: HeadKind.tarjeta,
    heading: Color(0xFFC3AE84),
  ),

  // 4. Clavado — pino descolorido, recortes torcidos, clavos de hierro.
  BoardSkin(
    top: TopKind.liston,
    topHeight: 9,
    topColor: Color(0xFF9A876A),
    posts: false,
    postColor: Color(0xFF9A876A),
    wood: Color(0xFFD8C9AC),
    grain: BoardGrain(GrainKind.nudos, Color(0xFF9A876A)),
    frame: Color(0xFFB7A585),
    frameWidth: 2,
    radius: 3,
    bevel: false,
    papers: [Color(0xFFFBF7EC), Color(0xFFEDF2E0), Color(0xFFF8EFD3)],
    shape: PaperShape.recto,
    inset: 0.82,
    lean: 2.6,
    gap: 15,
    pin: PinKind.clavo,
    pinColor: Color(0xFF4A4640),
    shadow: 0.3,
    ink: Color(0xFF3B3730),
    head: HeadKind.tarjeta,
    heading: Color(0xFF7C6A4E),
  ),

  // 5. Bando — el del pregonero: recto, formal, con su banda y su sello.
  BoardSkin(
    top: TopKind.alero,
    topHeight: 15,
    topColor: Color(0xFF7A6242),
    posts: false,
    postColor: Color(0xFF7A6242),
    wood: Color(0xFFB99A6B),
    grain: BoardGrain(GrainKind.lisa, Color(0xFF7A6242)),
    frame: Color(0xFF7A6242),
    frameWidth: 5,
    radius: 0,
    bevel: false,
    papers: [Color(0xFFFBF6E8)],
    shape: PaperShape.recto,
    inset: 0.97,
    lean: 0,
    gap: 12,
    pin: PinKind.lacre,
    pinColor: Color(0xFF9C4A3C),
    shadow: 0.26,
    ink: Color(0xFF2F2A22),
    head: HeadKind.banda,
    heading: Color(0xFFF6EEDC),
  ),

  // 6. Listones — con hueco entre ellos, y el papel metido por detrás.
  BoardSkin(
    top: TopKind.alero,
    topHeight: 14,
    topColor: Color(0xFF8A7048),
    posts: true,
    postColor: Color(0xFF6E5836),
    wood: Color(0xFFC0A87E),
    grain: BoardGrain(GrainKind.listones, Color(0xFF6E5836), slats: 9),
    frame: Color(0xFF8A7048),
    frameWidth: 4,
    radius: 6,
    bevel: false,
    papers: [Color(0xFFF7F2E3), Color(0xFFE8F0D8), Color(0xFFF7ECC9)],
    shape: PaperShape.tapado,
    inset: 0.88,
    lean: 0.8,
    gap: 13,
    pin: PinKind.ninguno,
    pinColor: Color(0xFF6E5836),
    shadow: 0.3,
    ink: Color(0xFF3B3730),
    head: HeadKind.quemado,
    heading: Color(0xFF6E5836),
  ),

  // 7. Roble — moldura biselada de cuadro y latón.
  BoardSkin(
    top: TopKind.tejado,
    topHeight: 22,
    topColor: Color(0xFF6E5433),
    posts: false,
    postColor: Color(0xFF5E452B),
    wood: Color(0xFF8C6B45),
    grain: BoardGrain(GrainKind.nudos, Color(0xFF5E452B)),
    frame: Color(0xFF5E452B),
    frameWidth: 9,
    radius: 8,
    bevel: true,
    papers: [Color(0xFFF4EFDF), Color(0xFFE7EEDA), Color(0xFFF5EBCD)],
    shape: PaperShape.recto,
    inset: 0.9,
    lean: 0,
    gap: 12,
    pin: PinKind.tachuela,
    pinColor: Color(0xFFC8A44A),
    shadow: 0.36,
    ink: Color(0xFF352F26),
    head: HeadKind.quemado,
    heading: Color(0xFFE0CFAE),
  ),

  // 8. Feria — miel, colores fuertes, cordel y cinta.
  BoardSkin(
    top: TopKind.cordel,
    topHeight: 18,
    topColor: Color(0xFF8B6B36),
    posts: false,
    postColor: Color(0xFFA9762F),
    wood: Color(0xFFD9A85C),
    grain: BoardGrain(GrainKind.tablas, Color(0xFFA9762F), slats: 6),
    frame: Color(0xFFA9762F),
    frameWidth: 3,
    radius: 5,
    bevel: false,
    papers: [Color(0xFFFBE7C6), Color(0xFFDFEFD0), Color(0xFFF6D9D2)],
    shape: PaperShape.recto,
    inset: 0.87,
    lean: 3.4,
    gap: 16,
    pin: PinKind.cinta,
    pinColor: Color(0xCCF3E6C4),
    shadow: 0.28,
    ink: Color(0xFF41372A),
    head: HeadKind.banda,
    heading: Color(0xFFFBE7C6),
  ),

  // 9. Taberna — ahumada, papeles grises, todo apretado.
  BoardSkin(
    top: TopKind.liston,
    topHeight: 12,
    topColor: Color(0xFF33271B),
    posts: false,
    postColor: Color(0xFF33271B),
    wood: Color(0xFF4B3B2A),
    grain: BoardGrain(GrainKind.humo, Color(0xFF1F1810)),
    frame: Color(0xFF33271B),
    frameWidth: 6,
    radius: 4,
    bevel: false,
    papers: [Color(0xFFE9E2D2), Color(0xFFDFE4D2), Color(0xFFEDE3C9)],
    shape: PaperShape.recto,
    inset: 0.94,
    lean: 1.0,
    gap: 8,
    pin: PinKind.tachuela,
    pinColor: Color(0xFFB08A3C),
    shadow: 0.5,
    ink: Color(0xFF2E2A23),
    head: HeadKind.tarjeta,
    heading: Color(0xFFB5A184),
  ),

  // 10. Muesca — nombre tallado, papeles en ranuras, nada por delante.
  BoardSkin(
    top: TopKind.nada,
    topHeight: 0,
    topColor: Color(0xFFA8916B),
    posts: false,
    postColor: Color(0xFFA8916B),
    wood: Color(0xFFCDBC9B),
    grain: BoardGrain(GrainKind.lisa, Color(0xFFA8916B)),
    frame: Color(0xFFA8916B),
    frameWidth: 2,
    radius: 12,
    bevel: false,
    papers: [Color(0xFFF7F2E4)],
    shape: PaperShape.recto,
    inset: 0.91,
    lean: 0,
    gap: 11,
    pin: PinKind.ninguno,
    pinColor: Color(0xFFA8916B),
    shadow: 0.38,
    ink: Color(0xFF3B3730),
    head: HeadKind.tallado,
    heading: Color(0xFF7E6B4B),
  ),
];
