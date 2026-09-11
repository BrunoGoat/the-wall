import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/symbols.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/ui/habit_sigil.dart';

void main() {
  group('the marks a habit wears', () {
    test('there are enough of them, and none is a font character', () {
      expect(habitSymbols.length, greaterThanOrEqualTo(60));
      expect(habitSymbols.toSet().length, habitSymbols.length);
      for (final s in habitSymbols) {
        // An id, drawn by us. Anything outside plain lowercase ascii would be
        // a character somebody's phone gets to decide the look of.
        expect(RegExp(r'^[a-z]+$').hasMatch(s), isTrue, reason: s);
        expect(habitSymbolNames[s], isNotNull, reason: s);
      }
      expect(habitSymbols, contains(kDefaultHabitSymbol));
    });

    test('every mark has a drawing behind it', () {
      for (final s in habitSymbols) {
        expect(HabitSigils.marksFor(s), isNotEmpty, reason: s);
      }
    });

    test('la lista cubre lo que la gente de verdad se propone', () {
      // El corte de tres filas que se arrastran sólo tiene sentido si detrás
      // hay algo que encontrar. Éstos son los que faltaban y por los que se
      // preguntó: la mesa, los animales, el oficio, la casa y el aseo.
      for (final s in [
        'taza', 'jarra', 'pan', 'plato', 'pez', 'ave', 'gato', 'lobo',
        'herradura',
        'arco', 'puno', 'manos', 'ojo', 'dialogo', 'pergamino', 'abaco',
        'engranaje',
        'martillo',
        'puerta',
        'brujula',
        'hoz',
        'balanza',
        'vela',
        'casa',
        'puente',
        'barco', 'escalera', 'bota', 'cama', 'balde', 'espejo', 'peine',
        'dado', 'puerta', 'nube', 'copo', //
      ]) {
        expect(habitSymbols, contains(s), reason: s);
        expect(HabitSigils.marksFor(s), isNotEmpty, reason: s);
      }
    });

    test('caben en tres filas sin dejar la última coja de más de dos', () {
      // El carrete se lee hacia abajo y luego a la derecha; una columna con
      // un solo hueco vacío está bien, tres huecos serían una columna en
      // blanco al final.
      expect(habitSymbols.length % 3, 0);
    });

    test('the emoji of older saves keep their meaning', () {
      expect(resolveHabitSymbol('🏠'), 'torre');
      expect(resolveHabitSymbol('📖'), 'libro');
      expect(resolveHabitSymbol('🏃'), 'carrera');
      // Stored with the variation selector, as phones write them.
      expect(resolveHabitSymbol('✍️'), 'pluma');
      expect(resolveHabitSymbol('☎️'), 'campana');
    });

    test('anything unknown still lands on one mark, and always the same', () {
      for (final odd in ['🦖', '', 'no-such-mark', '🥔🥔']) {
        final got = resolveHabitSymbol(odd);
        expect(habitSymbols, contains(got), reason: odd);
        expect(resolveHabitSymbol(odd), got, reason: odd);
      }
    });

    test('a habit read back from an old save wears a drawn mark', () {
      final h = Habit.fromJson({
        'id': 'h0',
        'n': 'Leer',
        's': '📖',
        'slot': 0,
        'c': 0,
        'p': <dynamic>[],
      });
      expect(h.symbol, 'libro');
      expect(habitSymbols, contains(h.symbol));
    });

    test(
      'y a media tinta sale de un solo tono, sin cruces más oscuros',
      () async {
        // Cada icono son varias formas. Pintadas por separado con tinta a media
        // fuerza —que es como se piden casi siempre: la barra de hábitos, el
        // tablón, el cartel del pueblo— cada sitio donde dos se cruzan suma su
        // transparencia con la de debajo y sale más oscuro: la mancuerna tenía
        // las barras más oscuras que los discos y el puño la muñeca más oscura
        // que los dedos. Un icono es una cosa, no un montón de formas apiladas.
        //
        // Negro al sesenta y dos por ciento sobre blanco da 97 de gris. Dos
        // capas dan 37: no hace falta afinar el listón, el fallo es enorme.
        const lado = 120;
        const alfa = 0.62;
        final piso = (255 * (1 - alfa)).round();
        for (final id in habitSymbols) {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          c.drawRect(
            const Rect.fromLTWH(0, 0, lado * 1.0, lado * 1.0),
            Paint()..color = const Color(0xFFFFFFFF),
          );
          HabitSigils.draw(
            c,
            const Rect.fromLTWH(10, 10, lado - 20.0, lado - 20.0),
            id,
            const Color(0xFF000000).withValues(alpha: alfa),
          );
          final img = await rec.endRecording().toImage(lado, lado);
          final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final px = data!.buffer.asUint8List();
          var masOscuro = 255;
          for (var i = 0; i < px.length; i += 4) {
            if (px[i] < masOscuro) masOscuro = px[i];
          }
          expect(
            masOscuro,
            greaterThanOrEqualTo(piso - 2),
            reason:
                'en «$id» hay un cruce a $masOscuro cuando el tono plano es '
                '$piso: dos formas apilando su transparencia',
          );
          // Y que haya dibujo: un icono en blanco pasaría lo de arriba solo.
          expect(masOscuro, lessThanOrEqualTo(piso + 2), reason: '«$id» vacío');
        }
      },
    );
  });
}
