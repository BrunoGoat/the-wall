import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/symbols.dart';

/// The mark of a habit, drawn.
///
/// Every glyph is authored by hand inside a hundred-by-hundred box, out of the
/// same vocabulary the town is: straight runs, squared masses, a few honest
/// curves. That is the whole point — the mark over a town has to look like it
/// came from the same place the town did, and no font on any phone was ever
/// going to do that.
class HabitSigil extends StatelessWidget {
  const HabitSigil({
    super.key,
    required this.symbol,
    required this.color,
    this.size = 22,
  });

  final String symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: habitSymbolNames[resolveHabitSymbol(symbol)],
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SigilPainter(resolveHabitSymbol(symbol), color),
        ),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  const _SigilPainter(this.symbol, this.color);
  final String symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    HabitSigils.draw(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      symbol,
      color,
    );
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.symbol != symbol || old.color != color;
}

/// The drawings themselves, cut once and kept.
class HabitSigils {
  const HabitSigils._();

  static final Map<String, List<_Mark>> _cache = {};

  /// The strokes and fills a mark is made of. Exposed so a test can prove
  /// every id in the catalogue has a drawing behind it.
  @visibleForTesting
  static List<Object> marksFor(String id) => _marks(resolveHabitSymbol(id));

  static List<_Mark> _marks(String id) => _cache.putIfAbsent(id, () {
    final pen = _Pen();
    (_glyphs[id] ?? _glyphs[kDefaultHabitSymbol]!)(pen);
    return pen.marks;
  });

  /// The crown of the valley: three points and a band.
  ///
  /// Worn by whichever town has laid the most pieces, which is the only
  /// competition this app has any business running — everybody is racing the
  /// same thing, one achievement at a time, and the valley is where you can
  /// see it.
  static void crown(Canvas canvas, Rect box, Color color) {
    final w = box.width, h = box.height;
    double x(double u) => box.left + u * w;
    double y(double v) => box.top + v * h;
    final path = Path()
      ..moveTo(x(0.06), y(0.74))
      ..lineTo(x(0.06), y(0.24))
      ..lineTo(x(0.28), y(0.50))
      ..lineTo(x(0.50), y(0.16))
      ..lineTo(x(0.72), y(0.50))
      ..lineTo(x(0.94), y(0.24))
      ..lineTo(x(0.94), y(0.74))
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  /// Paints a mark into [box], which should be square.
  ///
  /// Everything is authored to fill the same box, so a tall mark stays tall
  /// beside a wide one instead of every glyph being stretched to the same
  /// weight — a row of them reads as a set rather than as a rummage.
  static void draw(Canvas canvas, Rect box, String id, Color color) {
    final marks = _marks(resolveHabitSymbol(id));
    final k = math.min(box.width, box.height) / 100.0;
    canvas.save();
    canvas.translate(
      box.left + (box.width - 100 * k) / 2,
      box.top + (box.height - 100 * k) / 2,
    );
    canvas.scale(k);
    for (final m in marks) {
      final paint = Paint()
        ..color = color
        ..isAntiAlias = true;
      if (m.width > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      }
      canvas.drawPath(m.path, paint);
    }
    canvas.restore();
  }
}

class _Mark {
  const _Mark(this.path, this.width);
  final Path path;

  /// Zero means the shape is filled.
  final double width;
}

/// The hand that draws them: everything in the box is x right, y down, nought
/// to a hundred.
class _Pen {
  final List<_Mark> marks = [];

  void fill(void Function(Path) build, {void Function(Path)? cut}) {
    var p = Path();
    build(p);
    if (cut != null) {
      final c = Path();
      cut(c);
      p = Path.combine(PathOperation.difference, p, c);
    }
    marks.add(_Mark(p, 0));
  }

  void line(double w, void Function(Path) build) {
    final p = Path();
    build(p);
    marks.add(_Mark(p, w));
  }

  /// A closed filled polygon, with any number of holes punched through it.
  void shape(List<double> xy, {List<List<double>> holes = const []}) => fill(
    (p) => _run(p, xy, true),
    cut: holes.isEmpty
        ? null
        : (p) {
            for (final h in holes) {
              _run(p, h, true);
            }
          },
  );

  void poly(double w, List<double> xy) => line(w, (p) => _run(p, xy, false));

  void dot(double cx, double cy, double r) => fill(
    (p) => p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
  );

  void oval(double l, double t, double r, double b) =>
      fill((p) => p.addOval(Rect.fromLTRB(l, t, r, b)));

  void ring(double cx, double cy, double r, double w) => line(
    w,
    (p) => p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
  );

  void rect(double l, double t, double r, double b, {double round = 0}) => fill(
    (p) => round > 0
        ? p.addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(round)))
        : p.addRect(Rect.fromLTRB(l, t, r, b)),
  );

  static void _run(Path p, List<double> xy, bool close) {
    p.moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    if (close) p.close();
  }
}

final Map<String, void Function(_Pen)> _glyphs = {
  // ------------------------------------------------------------- lo de todos
  'libro': (p) {
    p.shape([8, 30, 47, 21, 47, 74, 8, 68]);
    p.shape([53, 21, 92, 30, 92, 68, 53, 74]);
  },
  'carrera': (p) {
    p.dot(63, 17, 10);
    p.poly(9, [57, 32, 46, 54]);
    p.poly(8, [46, 54, 63, 65, 59, 85]);
    p.poly(8, [46, 54, 30, 61, 19, 79]);
    p.poly(7, [53, 37, 73, 41, 82, 29]);
    p.poly(7, [53, 40, 34, 37, 26, 49]);
  },
  'pesa': (p) {
    p.poly(10, [30, 50, 70, 50]);
    p.rect(12, 30, 25, 70, round: 3);
    p.rect(75, 30, 88, 70, round: 3);
    p.rect(26, 38, 34, 62, round: 2);
    p.rect(66, 38, 74, 62, round: 2);
  },
  'loto': (p) {
    p.dot(50, 17, 10);
    p.fill((q) {
      q.moveTo(38, 33);
      q.cubicTo(44, 29, 56, 29, 62, 33);
      q.cubicTo(70, 43, 72, 54, 70, 62);
      q.lineTo(30, 62);
      q.cubicTo(28, 54, 30, 43, 38, 33);
      q.close();
    });
    p.fill((q) {
      q.moveTo(50, 58);
      q.cubicTo(74, 58, 88, 70, 86, 80);
      q.cubicTo(74, 87, 60, 84, 50, 79);
      q.cubicTo(40, 84, 26, 87, 14, 80);
      q.cubicTo(12, 70, 26, 58, 50, 58);
      q.close();
    });
  },
  'pipa': (p) {
    p.fill((q) {
      q.moveTo(25, 46);
      q.lineTo(51, 46);
      q.lineTo(49, 57);
      q.cubicTo(47, 67, 42, 72, 37, 72);
      q.cubicTo(30, 72, 26, 65, 25, 55);
      q.close();
    });
    p.poly(6, [51, 50, 73, 50]);
    p.ring(50, 50, 42, 7);
    p.poly(7, [21, 79, 79, 21]);
  },
  'gota': (p) {
    p.fill((q) {
      q.moveTo(50, 8);
      q.cubicTo(68, 32, 84, 48, 84, 62);
      q.cubicTo(84, 80, 69, 92, 50, 92);
      q.cubicTo(31, 92, 16, 80, 16, 62);
      q.cubicTo(16, 48, 32, 32, 50, 8);
      q.close();
    });
  },
  'hoja': (p) {
    p.fill(
      (q) {
        q.moveTo(88, 8);
        q.cubicTo(50, 13, 26, 35, 20, 72);
        q.cubicTo(60, 65, 84, 44, 88, 8);
        q.close();
      },
      cut: (q) {
        // The rib, corner to corner. Without it the leaf is only a lozenge.
        q.moveTo(85, 8);
        q.lineTo(90, 13);
        q.lineTo(25, 74);
        q.lineTo(20, 69);
        q.close();
      },
    );
    p.poly(5, [23, 72, 10, 91]);
  },
  'luna': (p) {
    p.fill(
      (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(48, 50), radius: 40)),
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(72, 34), radius: 37)),
    );
  },

  // ----------------------------------------------------------------- oficios
  'pluma': (p) {
    p.fill((q) {
      q.moveTo(94, 3);
      q.cubicTo(62, 14, 44, 34, 38, 58);
      q.cubicTo(64, 52, 86, 30, 94, 3);
      q.close();
    });
    p.poly(6, [43, 54, 19, 87]);
    p.shape([8, 98, 22, 81, 27, 87]);
  },
  'laud': (p) {
    // A big body and a short neck: at the size a town sign draws it, a small
    // body on a long stalk reads as a spoon.
    p.fill(
      (q) {
        q.moveTo(50, 36);
        q.cubicTo(77, 36, 90, 56, 90, 72);
        q.cubicTo(90, 88, 72, 98, 50, 98);
        q.cubicTo(28, 98, 10, 88, 10, 72);
        q.cubicTo(10, 56, 23, 36, 50, 36);
        q.close();
      },
      cut: (q) {
        q.addOval(Rect.fromCircle(center: const Offset(50, 66), radius: 9));
      },
    );
    p.rect(43, 6, 57, 42);
    p.rect(33, 0, 67, 11, round: 3);
    // The frets, poking out either side of the neck: the one thing a bottle
    // has never had.
    p.poly(3, [38, 19, 62, 19]);
    p.poly(3, [38, 30, 62, 30]);
  },
  'pincel': (p) {
    p.poly(9, [50, 8, 50, 50]);
    p.rect(36, 49, 64, 62, round: 2);
    p.fill((q) {
      q.moveTo(37, 62);
      q.lineTo(63, 62);
      q.cubicTo(60, 80, 56, 93, 50, 93);
      q.cubicTo(44, 93, 40, 80, 37, 62);
      q.close();
    });
  },
  'escoba': (p) {
    p.poly(8, [66, 6, 49, 52]);
    p.shape(
      [30, 50, 66, 50, 76, 92, 20, 92],
      holes: [
        [29, 63, 33, 63, 33, 92, 29, 92],
        [41, 62, 45, 62, 45, 92, 41, 92],
        [53, 62, 57, 62, 57, 92, 53, 92],
        [65, 63, 69, 63, 69, 92, 65, 92],
      ],
    );
  },
  'frasco': (p) {
    p.rect(29, 5, 71, 18, round: 3);
    p.rect(41, 18, 59, 29);
    p.fill(
      (q) => q.addRRect(
        RRect.fromLTRBR(21, 28, 79, 95, const Radius.circular(11)),
      ),
      cut: (q) {
        q.addRect(const Rect.fromLTRB(44, 44, 56, 82));
        q.addRect(const Rect.fromLTRB(31, 57, 69, 69));
      },
    );
  },
  'diente': (p) {
    p.fill((q) {
      q.moveTo(22, 36);
      q.cubicTo(22, 10, 78, 10, 78, 36);
      q.cubicTo(78, 58, 70, 66, 66, 86);
      q.cubicTo(64, 94, 56, 94, 54, 84);
      q.lineTo(50, 60);
      q.lineTo(46, 84);
      q.cubicTo(44, 94, 36, 94, 34, 86);
      q.cubicTo(30, 66, 22, 58, 22, 36);
      q.close();
    });
  },
  'campana': (p) {
    p.rect(44, 6, 56, 20, round: 3);
    p.fill((q) {
      q.moveTo(23, 74);
      q.cubicTo(25, 44, 38, 36, 38, 20);
      q.lineTo(62, 20);
      q.cubicTo(62, 36, 75, 44, 77, 74);
      q.close();
    });
    p.rect(17, 73, 83, 84, round: 4);
    p.dot(50, 91, 6);
  },

  // ------------------------------------------------------------------ afuera
  'brote': (p) {
    p.poly(6, [50, 94, 50, 42]);
    p.fill((q) {
      q.moveTo(50, 58);
      q.cubicTo(28, 58, 13, 45, 13, 26);
      q.cubicTo(36, 26, 50, 39, 50, 58);
      q.close();
    });
    p.fill((q) {
      q.moveTo(50, 50);
      q.cubicTo(72, 50, 87, 37, 87, 18);
      q.cubicTo(64, 18, 50, 31, 50, 50);
      q.close();
    });
  },
  'rueda': (p) {
    p.ring(50, 50, 36, 6);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      p.poly(4, [
        50 + math.cos(a) * 8,
        50 + math.sin(a) * 8,
        50 + math.cos(a) * 34,
        50 + math.sin(a) * 34,
      ]);
    }
    p.dot(50, 50, 9);
  },
  'ola': (p) {
    for (var i = 0; i < 3; i++) {
      final y = 30.0 + i * 21;
      p.line(7, (q) {
        q.moveTo(9, y);
        q.cubicTo(23, y - 15, 34, y + 13, 50, y);
        q.cubicTo(66, y - 13, 77, y + 15, 91, y);
      });
    }
  },
  'huella': (p) {
    p.oval(28, 50, 72, 89);
    p.oval(12, 34, 31, 59);
    p.oval(32, 15, 48, 42);
    p.oval(52, 15, 68, 42);
    p.oval(69, 34, 88, 59);
  },
  'olla': (p) {
    p.rect(15, 27, 85, 38, round: 4);
    p.dot(50, 21, 7);
    p.shape([24, 38, 76, 38, 70, 89, 30, 89]);
    p.rect(5, 44, 18, 59, round: 4);
    p.rect(82, 44, 95, 59, round: 4);
  },
  'diana': (p) {
    p.ring(50, 50, 38, 7);
    p.ring(50, 50, 23, 6);
    p.dot(50, 50, 10);
  },
  'sol': (p) {
    p.dot(50, 50, 21);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      p.poly(6, [
        50 + math.cos(a) * 30,
        50 + math.sin(a) * 30,
        50 + math.cos(a) * 44,
        50 + math.sin(a) * 44,
      ]);
    }
  },
  'estrella': (p) {
    final pts = <double>[];
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? 45.0 : 19.0;
      pts
        ..add(50 + math.cos(a) * r)
        ..add(50 + math.sin(a) * r);
    }
    p.shape(pts);
  },
  'corazon': (p) {
    p.fill((q) {
      q.moveTo(50, 91);
      q.cubicTo(10, 62, 6, 33, 24, 21);
      q.cubicTo(38, 11, 48, 22, 50, 32);
      q.cubicTo(52, 22, 62, 11, 76, 21);
      q.cubicTo(94, 33, 90, 62, 50, 91);
      q.close();
    });
  },
  'montana': (p) {
    p.shape([4, 87, 34, 24, 51, 53, 63, 35, 96, 87]);
  },
  'arbol': (p) {
    p.rect(45, 52, 55, 93);
    p.dot(50, 35, 25);
    p.dot(28, 49, 16);
    p.dot(72, 49, 16);
  },
  'espiga': (p) {
    p.poly(5, [50, 94, 50, 24]);
    p.oval(41, 8, 59, 34);
    for (var i = 0; i < 3; i++) {
      final y = 32.0 + i * 17;
      p.oval(24, y, 47, y + 17);
      p.oval(53, y, 76, y + 17);
    }
  },

  // ------------------------------------------------------------- de la villa
  'copa': (p) {
    p.fill((q) {
      q.moveTo(25, 16);
      q.lineTo(75, 16);
      q.cubicTo(73, 42, 63, 55, 50, 57);
      q.cubicTo(37, 55, 27, 42, 25, 16);
      q.close();
    });
    p.poly(7, [50, 56, 50, 80]);
    p.rect(28, 80, 72, 91, round: 4);
  },
  'bolsa': (p) {
    p.line(5, (q) {
      q.moveTo(31, 30);
      q.cubicTo(36, 13, 64, 13, 69, 30);
    });
    p.fill((q) {
      q.moveTo(39, 31);
      q.lineTo(61, 31);
      q.cubicTo(79, 38, 96, 58, 93, 76);
      q.cubicTo(90, 91, 73, 98, 50, 98);
      q.cubicTo(27, 98, 10, 91, 7, 76);
      q.cubicTo(4, 58, 21, 38, 39, 31);
      q.close();
    });
    // The knot, one lobe either side of the pinch.
    p.dot(32, 33, 9);
    p.dot(68, 33, 9);
  },
  'llave': (p) {
    p.ring(28, 50, 17, 8);
    p.poly(8, [45, 50, 88, 50]);
    p.poly(7, [80, 50, 80, 69]);
    p.poly(7, [67, 50, 67, 64]);
  },
  'yunque': (p) {
    p.shape([16, 30, 62, 30, 90, 43, 62, 51, 16, 51]);
    p.shape([34, 51, 62, 51, 58, 66, 38, 66]);
    p.shape([24, 66, 72, 66, 79, 87, 17, 87]);
  },
  'espada': (p) {
    p.shape([50, 2, 61, 18, 61, 54, 39, 54, 39, 18]);
    p.rect(26, 54, 74, 65, round: 3);
    p.rect(43, 65, 57, 84);
    p.dot(50, 89, 8);
  },
  'escudo': (p) {
    p.fill(
      (q) {
        q.moveTo(13, 13);
        q.lineTo(87, 13);
        q.lineTo(87, 47);
        q.cubicTo(87, 74, 68, 88, 50, 95);
        q.cubicTo(32, 88, 13, 74, 13, 47);
        q.close();
      },
      cut: (q) {
        q.addRect(const Rect.fromLTRB(44, 21, 56, 79));
        q.addRect(const Rect.fromLTRB(21, 38, 79, 50));
      },
    );
  },
  'reloj': (p) {
    p.shape([24, 14, 76, 14, 54, 50, 76, 86, 24, 86, 46, 50]);
    p.rect(15, 5, 85, 14, round: 3);
    p.rect(15, 86, 85, 95, round: 3);
  },
  'farol': (p) {
    p.line(4, (q) {
      q.addArc(
        Rect.fromCircle(center: const Offset(50, 18), radius: 9),
        math.pi,
        math.pi,
      );
    });
    p.shape([32, 18, 68, 18, 77, 30, 23, 30]);
    p.fill(
      (q) =>
          q.addRRect(RRect.fromLTRBR(28, 30, 72, 78, const Radius.circular(5))),
      cut: (q) {
        q.moveTo(50, 39);
        q.cubicTo(63, 52, 63, 63, 56, 69);
        q.cubicTo(52, 73, 48, 73, 44, 69);
        q.cubicTo(37, 63, 37, 52, 50, 39);
        q.close();
      },
    );
    p.rect(21, 78, 79, 89, round: 3);
  },
  'torre': (p) {
    p.shape([
      21, 34, 21, 19, 31, 19, 31, 27, 37, 27, 37, 19, 47, 19, 47, 27, //
      53, 27, 53, 19, 63, 19, 63, 27, 69, 27, 69, 19, 79, 19, 79, 34,
    ]);
    p.shape(
      [27, 34, 73, 34, 73, 93, 27, 93],
      holes: [
        [36, 44, 45, 44, 45, 55, 36, 55],
        [55, 44, 64, 44, 64, 55, 55, 55],
        [42, 68, 58, 68, 58, 90, 42, 90],
      ],
    );
  },
  // ------------------------------------------------------------- la mesa
  'taza': (p) {
    p.line(
      6,
      (q) => q.addArc(
        Rect.fromCircle(center: const Offset(72, 54), radius: 15),
        -math.pi / 2,
        math.pi,
      ),
    );
    p.shape([24, 36, 70, 36, 63, 86, 31, 86]);
    p.rect(16, 86, 78, 94, round: 3);
    p.line(5, (q) {
      q.moveTo(38, 28);
      q.cubicTo(45, 20, 33, 14, 40, 4);
    });
    p.line(5, (q) {
      q.moveTo(56, 28);
      q.cubicTo(63, 20, 51, 14, 58, 4);
    });
  },
  'jarra': (p) {
    // Tachada como la pipa, y con el mismo aro: lo que se deja también es un
    // hábito. Al principio la raya iba sobre la jarra a pelo y se la comía —
    // el aro es lo que dice «esto no» sin borrar el dibujo de debajo.
    p.rect(28, 32, 64, 41, round: 2);
    p.shape([32, 41, 60, 41, 57, 75, 35, 75]);
    p.line(
      5,
      (q) => q.addArc(
        Rect.fromCircle(center: const Offset(64, 55), radius: 10),
        -math.pi / 2,
        math.pi,
      ),
    );
    p.ring(50, 50, 42, 7);
    p.poly(7, [21, 79, 79, 21]);
  },
  'pan': (p) {
    p.fill(
      (q) {
        q.moveTo(9, 74);
        q.cubicTo(9, 38, 26, 22, 50, 22);
        q.cubicTo(74, 22, 91, 38, 91, 74);
        q.close();
      },
      cut: (q) {
        for (var i = 0; i < 3; i++) {
          final x = 22.0 + i * 20;
          q.moveTo(x, 58);
          q.lineTo(x + 13, 36);
          q.lineTo(x + 20, 36);
          q.lineTo(x + 7, 58);
          q.close();
        }
      },
    );
    p.rect(6, 74, 94, 85, round: 4);
  },
  'plato': (p) {
    p.ring(41, 57, 30, 7);
    p.dot(41, 57, 8);
    p.oval(74, 10, 96, 40);
    p.rect(80, 34, 90, 90, round: 5);
  },

  // ---------------------------------------------------------- los animales
  'pez': (p) {
    p.fill(
      (q) {
        q.moveTo(22, 50);
        q.cubicTo(40, 22, 74, 22, 90, 50);
        q.cubicTo(74, 78, 40, 78, 22, 50);
        q.close();
      },
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(74, 42), radius: 5)),
    );
    p.shape([26, 50, 6, 26, 6, 74]);
  },
  'ave': (p) {
    p.fill(
      (q) {
        q.moveTo(31, 29);
        q.cubicTo(47, 16, 63, 25, 65, 42);
        q.cubicTo(85, 51, 91, 69, 84, 87);
        q.cubicTo(59, 90, 32, 78, 26, 56);
        q.cubicTo(22, 45, 25, 35, 31, 29);
        q.close();
      },
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(43, 33), radius: 4)),
    );
    p.shape([30, 32, 7, 39, 30, 47]);
    p.line(5, (q) {
      q.moveTo(52, 57);
      q.cubicTo(65, 59, 73, 68, 75, 80);
    });
  },
  'gato': (p) {
    p.fill(
      (q) {
        q.moveTo(19, 45);
        q.lineTo(14, 12);
        q.lineTo(41, 27);
        q.cubicTo(47, 25, 53, 25, 59, 27);
        q.lineTo(86, 12);
        q.lineTo(81, 45);
        q.cubicTo(90, 61, 83, 86, 50, 90);
        q.cubicTo(17, 86, 10, 61, 19, 45);
        q.close();
      },
      cut: (q) {
        q.addOval(Rect.fromCircle(center: const Offset(36, 52), radius: 6));
        q.addOval(Rect.fromCircle(center: const Offset(64, 52), radius: 6));
        q.moveTo(43, 63);
        q.lineTo(57, 63);
        q.lineTo(50, 73);
        q.close();
      },
    );
  },
  'lobo': (p) {
    // Hocico largo y ojos rasgados: es lo que lo separa del gato, que es
    // redondo y con los ojos abiertos.
    p.fill(
      (q) {
        q.moveTo(17, 41);
        q.lineTo(9, 5);
        q.lineTo(38, 24);
        q.cubicTo(45, 21, 55, 21, 62, 24);
        q.lineTo(91, 5);
        q.lineTo(83, 41);
        q.cubicTo(88, 53, 84, 63, 74, 69);
        q.lineTo(66, 91);
        q.lineTo(50, 98);
        q.lineTo(34, 91);
        q.lineTo(26, 69);
        q.cubicTo(16, 63, 12, 53, 17, 41);
        q.close();
      },
      cut: (q) {
        q.moveTo(24, 46);
        q.lineTo(43, 53);
        q.lineTo(43, 61);
        q.lineTo(24, 56);
        q.close();
        q.moveTo(76, 46);
        q.lineTo(57, 53);
        q.lineTo(57, 61);
        q.lineTo(76, 56);
        q.close();
        q.addOval(Rect.fromCircle(center: const Offset(50, 82), radius: 7));
      },
    );
  },
  'herradura': (p) {
    p.line(
      16,
      (q) => q.addArc(
        Rect.fromCircle(center: const Offset(50, 48), radius: 31),
        math.pi * 0.75,
        math.pi * 1.5,
      ),
    );
    p.dot(28, 70, 10);
    p.dot(72, 70, 10);
  },

  // ------------------------------------------------------------- el cuerpo
  'arco': (p) {
    // En diagonal, como el emoji: el arco abajo a la izquierda y la flecha
    // saliendo hacia arriba a la derecha. De frente y con la flecha cruzada
    // no se sabía qué era el arco y qué la flecha.
    p.line(
      8,
      (q) => q.addArc(
        Rect.fromCircle(center: const Offset(29, 71), radius: 52),
        -math.pi * 0.65,
        math.pi * 0.80,
      ),
    );
    p.poly(3, [6, 25, 75, 94]);
    p.poly(6, [35, 65, 85, 15]);
    p.shape([96, 4, 90, 21, 79, 10]);
    p.poly(4, [35, 65, 23, 69]);
    p.poly(4, [35, 65, 31, 81]);
  },
  'puno': (p) {
    p.fill(
      (q) => q.addRRect(
        RRect.fromLTRBR(23, 32, 82, 82, const Radius.circular(14)),
      ),
    );
    for (var i = 0; i < 4; i++) {
      p.dot(32 + i * 14, 34, 9);
    }
    p.fill(
      (q) =>
          q.addRRect(RRect.fromLTRBR(11, 46, 30, 70, const Radius.circular(9))),
    );
    p.rect(31, 82, 74, 93, round: 4);
  },
  'manos': (p) {
    p.fill((q) {
      q.moveTo(6, 44);
      q.cubicTo(10, 74, 28, 90, 50, 90);
      q.cubicTo(72, 90, 90, 74, 94, 44);
      q.lineTo(79, 44);
      q.cubicTo(75, 66, 64, 75, 50, 75);
      q.cubicTo(36, 75, 25, 66, 21, 44);
      q.close();
    });
    p.poly(9, [15, 44, 18, 25]);
    p.poly(9, [28, 44, 33, 21]);
    p.poly(9, [40, 44, 46, 24]);
    p.poly(9, [85, 44, 82, 25]);
    p.poly(9, [72, 44, 67, 21]);
    p.poly(9, [60, 44, 54, 24]);
  },
  'ojo': (p) {
    p.fill(
      (q) {
        q.moveTo(5, 50);
        q.cubicTo(24, 21, 76, 21, 95, 50);
        q.cubicTo(76, 79, 24, 79, 5, 50);
        q.close();
      },
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 19)),
    );
    p.dot(50, 50, 11);
  },

  // -------------------------------------------------------------- el oficio
  'dialogo': (p) {
    p.fill(
      (q) {
        q.addRRect(RRect.fromLTRBR(7, 15, 93, 67, const Radius.circular(13)));
        q.moveTo(25, 65);
        q.lineTo(47, 65);
        q.lineTo(24, 93);
        q.close();
      },
      cut: (q) {
        for (var i = 0; i < 3; i++) {
          q.addOval(
            Rect.fromCircle(center: Offset(32 + i * 18, 41), radius: 6),
          );
        }
      },
    );
  },
  'pergamino': (p) {
    p.fill(
      (q) => q.addRect(const Rect.fromLTRB(22, 22, 78, 78)),
      cut: (q) {
        for (var i = 0; i < 3; i++) {
          q.addRect(Rect.fromLTRB(31, 32.0 + i * 13, 69, 37.0 + i * 13));
        }
      },
    );
    p.poly(10, [15, 22, 85, 22]);
    p.poly(10, [15, 78, 85, 78]);
  },
  'abaco': (p) {
    p.rect(9, 12, 91, 21, round: 3);
    p.rect(9, 79, 91, 88, round: 3);
    p.rect(9, 12, 18, 88, round: 3);
    p.rect(82, 12, 91, 88, round: 3);
    for (var i = 0; i < 3; i++) {
      p.poly(3, [18, 31.0 + i * 17, 82, 31.0 + i * 17]);
    }
    for (final b in const [
      [27, 31],
      [41, 31],
      [73, 31],
      [27, 48],
      [63, 48],
      [77, 48],
      [34, 65],
      [48, 65],
      [76, 65],
    ]) {
      p.dot(b[0].toDouble(), b[1].toDouble(), 7);
    }
  },
  'engranaje': (p) {
    // Los dientes van de uno en uno, cada cual su propia figura: dos figuras
    // superpuestas se pintan dos veces del mismo color, que no se nota, y en
    // cambio una sola figura que se cruza a sí misma deja agujeros.
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final ca = math.cos(a), sa = math.sin(a);
      p.shape([
        50 + ca * 26 - sa * 11, 50 + sa * 26 + ca * 11, //
        50 + ca * 47 - sa * 8, 50 + sa * 47 + ca * 8,
        50 + ca * 47 + sa * 8, 50 + sa * 47 - ca * 8,
        50 + ca * 26 + sa * 11, 50 + sa * 26 - ca * 11,
      ]);
    }
    p.fill(
      (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 33)),
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 14)),
    );
  },
  'martillo': (p) {
    p.shape([46, 11, 88, 11, 88, 39, 46, 39]);
    // La uña, que es lo que lo separa de un mazo: dos puntas y el hueco de
    // sacar el clavo entre ellas.
    p.shape([
      46, 11, 46, 39, 27, 39, 12, 51, 3, 41, //
      17, 30, 21, 21, 10, 11,
    ]);
    p.rect(58, 39, 75, 95, round: 6);
  },
  'hacha': (p) {
    // El astil atraviesa la cabeza y sigue mucho más abajo, y la cabeza es
    // una cuña de cantos rectos.
    p.rect(40, 6, 54, 96, round: 6);
    p.fill((q) {
      q.moveTo(52, 23);
      q.lineTo(88, 9);
      q.cubicTo(96, 26, 96, 46, 88, 63);
      q.lineTo(52, 50);
      q.close();
    });
  },
  'brujula': (p) {
    p.ring(50, 50, 42, 7);
    p.shape([
      50, 16, 62, 38, 84, 50, 62, 62, //
      50, 84, 38, 62, 16, 50, 38, 38,
    ]);
  },
  'hoz': (p) {
    p.fill((q) {
      q.moveTo(94, 6);
      q.cubicTo(94, 58, 60, 86, 14, 86);
      q.lineTo(14, 66);
      q.cubicTo(50, 66, 74, 44, 74, 6);
      q.close();
    });
    p.rect(4, 62, 31, 97, round: 8);
  },
  'balanza': (p) {
    p.poly(7, [50, 16, 50, 84]);
    p.poly(7, [17, 30, 83, 30]);
    p.dot(50, 15, 8);
    p.rect(28, 84, 72, 93, round: 3);
    p.poly(4, [17, 30, 17, 45]);
    p.poly(4, [83, 30, 83, 45]);
    p.shape([1, 45, 33, 45, 17, 64]);
    p.shape([67, 45, 99, 45, 83, 64]);
  },

  // -------------------------------------------------------------- y la casa
  'vela': (p) {
    p.fill((q) {
      q.moveTo(50, 5);
      q.cubicTo(62, 19, 66, 27, 66, 34);
      q.cubicTo(66, 44, 59, 50, 50, 50);
      q.cubicTo(41, 50, 34, 44, 34, 34);
      q.cubicTo(34, 27, 38, 19, 50, 5);
      q.close();
    });
    p.poly(4, [50, 50, 50, 57]);
    p.rect(35, 57, 65, 86, round: 3);
    p.rect(23, 86, 77, 95, round: 3);
  },
  'casa': (p) {
    p.shape([50, 7, 96, 45, 4, 45]);
    p.rect(70, 15, 80, 32);
    p.shape(
      [16, 45, 84, 45, 84, 93, 16, 93],
      holes: [
        [42, 62, 58, 62, 58, 93, 42, 93],
        [25, 56, 36, 56, 36, 68, 25, 68],
        [64, 56, 75, 56, 75, 68, 64, 68],
      ],
    );
  },
  'puerta': (p) {
    // Sin la junta central ni el travesaño: las dos cosas juntas hacían una
    // cruz en medio de la puerta y era lo primero que se veía.
    p.fill(
      (q) {
        q.moveTo(15, 96);
        q.lineTo(15, 42);
        q.cubicTo(15, 12, 85, 12, 85, 42);
        q.lineTo(85, 96);
        q.close();
      },
      cut: (q) {
        q.addRRect(RRect.fromLTRBR(39, 27, 61, 45, const Radius.circular(4)));
        q.addOval(Rect.fromCircle(center: const Offset(68, 70), radius: 6));
      },
    );
  },
  'puente': (p) {
    p.rect(5, 36, 95, 49, round: 3);
    p.fill(
      (q) => q.addRect(const Rect.fromLTRB(14, 49, 86, 88)),
      cut: (q) =>
          q.addOval(Rect.fromCircle(center: const Offset(50, 90), radius: 31)),
    );
    p.poly(5, [11, 36, 11, 21]);
    p.poly(5, [50, 36, 50, 23]);
    p.poly(5, [89, 36, 89, 21]);
    p.poly(5, [11, 22, 89, 22]);
  },
  'barco': (p) {
    p.shape([48, 5, 48, 60, 12, 60]);
    p.shape([56, 20, 56, 60, 89, 60]);
    p.poly(5, [50, 6, 50, 64]);
    p.fill((q) {
      q.moveTo(7, 67);
      q.lineTo(93, 67);
      q.cubicTo(87, 88, 72, 95, 50, 95);
      q.cubicTo(28, 95, 13, 88, 7, 67);
      q.close();
    });
  },
  'escalera': (p) {
    p.rect(19, 5, 30, 95, round: 4);
    p.rect(70, 5, 81, 95, round: 4);
    for (var i = 0; i < 5; i++) {
      p.rect(25, 17.0 + i * 17, 75, 25.0 + i * 17, round: 2);
    }
  },
  'bota': (p) {
    p.fill((q) {
      q.moveTo(24, 7);
      q.lineTo(56, 7);
      q.lineTo(56, 47);
      q.cubicTo(73, 49, 88, 58, 92, 72);
      q.lineTo(92, 83);
      q.lineTo(24, 83);
      q.close();
    });
    p.rect(17, 83, 96, 94, round: 3);
  },
  'cama': (p) {
    p.rect(5, 25, 17, 89, round: 4);
    p.rect(83, 49, 95, 89, round: 4);
    p.rect(5, 55, 95, 72, round: 4);
    p.rect(22, 42, 48, 57, round: 5);
  },
  'balde': (p) {
    p.line(
      6,
      (q) => q.addArc(
        Rect.fromCircle(center: const Offset(50, 34), radius: 28),
        math.pi,
        math.pi,
      ),
    );
    p.rect(13, 30, 87, 43, round: 3);
    p.shape([18, 43, 82, 43, 70, 93, 30, 93]);
  },
  'espejo': (p) {
    p.ring(50, 34, 27, 8);
    p.line(6, (q) {
      q.moveTo(39, 23);
      q.cubicTo(31, 29, 29, 39, 33, 47);
    });
    p.rect(43, 60, 57, 92, round: 5);
    p.rect(35, 86, 65, 97, round: 4);
  },
  'peine': (p) {
    p.rect(9, 18, 91, 38, round: 4);
    for (var i = 0; i < 9; i++) {
      p.rect(12.0 + i * 9, 38, 18.0 + i * 9, 84, round: 2);
    }
  },
  'nube': (p) {
    p.fill((q) {
      q.addOval(Rect.fromCircle(center: const Offset(33, 46), radius: 20));
      q.addOval(Rect.fromCircle(center: const Offset(57, 38), radius: 26));
      q.addOval(Rect.fromCircle(center: const Offset(78, 52), radius: 17));
      q.addRRect(RRect.fromLTRBR(13, 50, 95, 74, const Radius.circular(12)));
    });
  },
  'copo': (p) {
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      final ca = math.cos(a), sa = math.sin(a);
      p.poly(6, [50 - ca * 44, 50 - sa * 44, 50 + ca * 44, 50 + sa * 44]);
    }
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      for (final turn in [a + 0.95, a - 0.95]) {
        final bx = 50 + math.cos(a) * 28, by = 50 + math.sin(a) * 28;
        p.poly(5, [
          bx, by, //
          bx + math.cos(turn) * 14, by + math.sin(turn) * 14,
        ]);
      }
    }
  },
  'dado': (p) {
    p.fill(
      (q) => q.addRRect(
        RRect.fromLTRBR(11, 11, 89, 89, const Radius.circular(15)),
      ),
      cut: (q) {
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 2; c++) {
            q.addOval(
              Rect.fromCircle(
                center: Offset(32 + c * 36, 32 + r * 18),
                radius: 8,
              ),
            );
          }
        }
      },
    );
  },
};
