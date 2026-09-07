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
};
