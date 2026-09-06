// Not a test, which is why it lives here and not in test/: it is a way of
// looking at every mark at once, at the sizes they are actually used, without
// opening the app.
//
//   flutter test tool/sigil_sheet_test.dart --dart-define=OUT=/tmp/sigils.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/symbols.dart';
import 'package:la_muralla/ui/habit_sigil.dart';

void main() {
  testWidgets('contact sheet', (tester) async {
    const cols = 6;
    const cell = 96.0;
    final rows = (habitSymbols.length / cols).ceil();
    final w = cols * cell, h = rows * cell + 40;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF3EDE2));

    for (var i = 0; i < habitSymbols.length; i++) {
      final x = (i % cols) * cell, y = (i ~/ cols) * cell + 20;
      // Big, the way the sheet shows it.
      HabitSigils.draw(canvas, Rect.fromLTWH(x + 14, y + 8, 44, 44),
          habitSymbols[i], const Color(0xFF3A3128));
      // Small, the way a chip and a town sign show it.
      HabitSigils.draw(canvas, Rect.fromLTWH(x + 24, y + 58, 17, 17),
          habitSymbols[i], const Color(0xFF3A3128));
      HabitSigils.draw(canvas, Rect.fromLTWH(x + 50, y + 58, 17, 17),
          habitSymbols[i], const Color(0x803A3128));
    }

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(const String.fromEnvironment('OUT', defaultValue: '/tmp/sigils.png'))
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
