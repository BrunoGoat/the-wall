import 'package:flutter/material.dart';

/// De qué está hecho el tablón por detrás.
///
/// Cinco superficies para comparar. Lo que cambia es **el fondo**: el color, la
/// textura, el marco y el tono de los papeles que hacen falta para que se lean
/// encima. El tejadito y la manera de clavar los papeles no cambian, y es a
/// propósito: son lo que hace que el tablón sea el tablón de la plaza y no una
/// pantalla, y no es lo que había que comparar.
enum BoardLook {
  /// La de ahora: tablones de madera con sus juntas y su veta.
  tablon,

  /// Corcho: sin juntas, con el picado del corcho y un marco fino de madera.
  corcho,

  /// Cal: una pared encalada, casi blanca, con los papeles clavados a ella.
  cal,

  /// Pizarra: piedra oscura. Los papeles pasan a ser lo único claro.
  pizarra,

  /// Lienzo: tela cruda, con su trama.
  lienzo;

  /// Cómo se llama en los ajustes.
  String get label => const {
    BoardLook.tablon: 'Tablones',
    BoardLook.corcho: 'Corcho',
    BoardLook.cal: 'Cal',
    BoardLook.pizarra: 'Pizarra',
    BoardLook.lienzo: 'Lienzo',
  }[this]!;

  static BoardLook? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  BoardSkin get skin => switch (this) {
    BoardLook.tablon => const BoardSkin(
      heading: Color(0xFF8A6B47),
      surface: Color(0xFFB08D62),
      frame: Color(0xFF8A6B47),
      frameWidth: 3,
      papers: [Color(0xFFF4EEDD), Color(0xFFDCEBC6), Color(0xFFF5EDBE)],
      shadow: 0.22,
      texture: _Planks(),
    ),
    BoardLook.corcho => const BoardSkin(
      heading: Color(0xFF6E5030),
      surface: Color(0xFFC7A275),
      frame: Color(0xFF6E5030),
      frameWidth: 9,
      papers: [Color(0xFFFBF6EA), Color(0xFFE4EFD3), Color(0xFFF7EFC8)],
      shadow: 0.26,
      texture: _Cork(),
    ),
    BoardLook.cal => const BoardSkin(
      heading: Color(0xFF8C7F6A),
      surface: Color(0xFFE7E0D3),
      frame: Color(0xFFD2C9B8),
      frameWidth: 2,
      // Sobre una pared casi blanca un papel crema desaparece, así que aquí
      // los papeles se separan por el tono y por una sombra más marcada.
      papers: [Color(0xFFFFFFFF), Color(0xFFE9F0DC), Color(0xFFF6E9C6)],
      shadow: 0.32,
      texture: _Plaster(),
    ),
    BoardLook.pizarra => const BoardSkin(
      heading: Color(0xFFA9B6BE),
      surface: Color(0xFF3B4349),
      frame: Color(0xFF262C31),
      frameWidth: 4,
      papers: [Color(0xFFF6F1E3), Color(0xFFDFEBCB), Color(0xFFF3E9BE)],
      shadow: 0.42,
      texture: _Slate(),
    ),
    BoardLook.lienzo => const BoardSkin(
      heading: Color(0xFF8E7F63),
      surface: Color(0xFFD8CCB2),
      frame: Color(0xFFB2A183),
      frameWidth: 6,
      papers: [Color(0xFFFDFAF2), Color(0xFFE6EFD8), Color(0xFFF8F0CE)],
      shadow: 0.20,
      texture: _Linen(),
    ),
  };
}

/// De qué está hecha una de las cinco.
class BoardSkin {
  const BoardSkin({
    required this.heading,
    required this.surface,
    required this.frame,
    required this.frameWidth,
    required this.papers,
    required this.shadow,
    required this.texture,
  });

  /// El color del nombre del hábito, escrito sobre la superficie y no sobre
  /// un papel. Es lo único de la tinta que cambia con la superficie: sobre
  /// pizarra, marrón quemado no se lee.
  final Color heading;

  final Color surface;
  final Color frame;
  final double frameWidth;

  /// Los tres papeles que se van turnando.
  final List<Color> papers;

  /// Cuánta sombra echa cada papel sobre el fondo. En una pared clara hace
  /// falta más, porque el papel ya no se separa por el color.
  final double shadow;

  final CustomPainter texture;
}

/// La veta y las juntas entre tablones.
class _Planks extends CustomPainter {
  const _Planks();

  static const _dark = Color(0xFF8A6B47);

  @override
  void paint(Canvas canvas, Size size) {
    final seam = Paint()
      ..color = _dark.withValues(alpha: 0.55)
      ..strokeWidth = 1.6;
    final grain = Paint()
      ..color = _dark.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    const planks = 5;
    for (var i = 1; i < planks; i++) {
      final y = size.height * i / planks;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seam);
    }
    for (var i = 0; i < 14; i++) {
      final y = size.height * (i + 0.35) / 14;
      canvas.drawLine(
        Offset(size.width * 0.06, y),
        Offset(size.width * (0.4 + (i % 4) * 0.14), y),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(_Planks old) => false;
}

/// El picado del corcho: nada de líneas, sólo grano.
class _Cork extends CustomPainter {
  const _Cork();

  @override
  void paint(Canvas canvas, Size size) {
    final claro = Paint()..color = const Color(0x22FFF3DE);
    final oscuro = Paint()..color = const Color(0x2A6B4A26);
    // Sembrado con una cuenta y no con azar: el mismo tablón cada vez que se
    // abre, que es lo que uno espera de un corcho que lleva años ahí.
    var h = 0x2F6E5;
    for (var i = 0; i < 900; i++) {
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      final x = (h >> 7) % size.width.round().clamp(1, 1 << 20);
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      final y = (h >> 7) % size.height.round().clamp(1, 1 << 20);
      final r = 0.8 + ((h >> 3) % 22) / 10;
      canvas.drawCircle(
        Offset(x.toDouble(), y.toDouble()),
        r,
        i.isEven ? oscuro : claro,
      );
    }
  }

  @override
  bool shouldRepaint(_Cork old) => false;
}

/// Una pared encalada: casi lisa, con la mano de cal apenas marcada.
class _Plaster extends CustomPainter {
  const _Plaster();

  @override
  void paint(Canvas canvas, Size size) {
    final brocha = Paint()
      ..color = const Color(0x14A2917A)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = size.height * (i + 0.5) / 9;
      canvas.drawLine(
        Offset(size.width * (i.isEven ? 0.02 : 0.18), y),
        Offset(size.width * (i.isEven ? 0.86 : 0.99), y + 3),
        brocha,
      );
    }
    // Y la sombra que echa el alero sobre la pared, arriba.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 26),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x22000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 26)),
    );
  }

  @override
  bool shouldRepaint(_Plaster old) => false;
}

/// Piedra: las vetas de exfoliación, en diagonal y muy flojas.
class _Slate extends CustomPainter {
  const _Slate();

  @override
  void paint(Canvas canvas, Size size) {
    final veta = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.4;
    final honda = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 2.6;
    for (var i = 0; i < 16; i++) {
      final y = size.height * (i + 0.2) / 16;
      final corre = size.width * (0.12 + (i % 5) * 0.16);
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(corre, y + 7),
        i % 3 == 0 ? honda : veta,
      );
    }
  }

  @override
  bool shouldRepaint(_Slate old) => false;
}

/// Tela cruda: la trama, fina y en las dos direcciones.
class _Linen extends CustomPainter {
  const _Linen();

  @override
  void paint(Canvas canvas, Size size) {
    final hilo = Paint()
      ..color = const Color(0x168A7A5C)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hilo);
    }
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hilo);
    }
  }

  @override
  bool shouldRepaint(_Linen old) => false;
}
