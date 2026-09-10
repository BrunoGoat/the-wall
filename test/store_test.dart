import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Store> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = Store();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('one brick is one achievement', () {
    test('placing adds exactly one brick, never a batch', () async {
      final s = await freshStore();
      expect(s.total, 0);
      s.placePiece();
      expect(s.total, 1);
      s.placePiece();
      s.placePiece();
      expect(s.total, 3);
    });

    test('bricks are numbered in the order they were earned', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.placePiece();
      expect(s.pieces.map((x) => x.index), [0, 1, 2]);
    });

    test('a brick starts with no note at all', () async {
      final s = await freshStore();
      final r = s.placePiece();
      expect(r.piece.hasLabel, isFalse);
      expect(r.piece.label, isNull);
    });
  });

  group('notes on a stone', () {
    test('a note is optional and can be written later', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      expect(s.labelled, isEmpty);

      s.setLabel(0, 'Leí');
      expect(s.pieceAt(0)!.label, 'Leí');
      expect(s.pieceAt(1)!.hasLabel, isFalse);
      expect(s.labelled.map((b) => b.index), [0]);
    });

    test('a note can be rewritten and cleared', () async {
      final s = await freshStore();
      s.placePiece();
      s.setLabel(0, 'Corrí');
      s.setLabel(0, 'Corrí 10k');
      expect(s.pieceAt(0)!.label, 'Corrí 10k');
      s.setLabel(0, '   ');
      expect(
        s.pieceAt(0)!.hasLabel,
        isFalse,
        reason: 'blank should clear the note, not store whitespace',
      );
    });

    test('writing a note never changes what the wall is', () async {
      final s = await freshStore();
      for (var i = 0; i < 5; i++) {
        s.placePiece();
      }
      final before = s.total;
      s.setLabel(2, 'Algo');
      expect(s.total, before);
    });

    test('the newest note comes first in the log', () async {
      final s = await freshStore();
      for (var i = 0; i < 4; i++) {
        s.placePiece();
      }
      s.setLabel(0, 'uno');
      s.setLabel(3, 'cuatro');
      expect(s.labelled.map((b) => b.index), [3, 0]);
    });
  });

  group('decay and repair', () {
    test('a fresh wall is intact', () async {
      final s = await freshStore();
      s.placePiece();
      expect(s.integrity, 1.0);
      expect(s.isDecaying, isFalse);
    });

    test('time away wears the wall down, one brick brings it back', () async {
      final s = await freshStore();
      s.debugFill(20, endedDaysAgo: 9);
      expect(s.integrity, lessThan(0.6));
      expect(s.isDecaying, isTrue);

      final r = s.placePiece();
      expect(r.relit, isTrue);
      expect(r.relitFrom, lessThan(0.6));
      expect(s.integrity, 1.0);
    });

    test('an empty wall cannot decay', () async {
      final s = await freshStore();
      expect(s.integrity, 1.0);
    });
  });

  group('what kind of place a habit builds', () {
    // Chosen the day it is founded and never again: the character decides how
    // wide the plots are and in what order the hundred and twelve arrive, so
    // changing it would move pieces laid years ago.
    test('the region chosen when founding is the one it keeps', () async {
      final store = await freshStore();
      final want = TownCharacter.all[3];
      store.addHabit('Correr', 'carrera', character: want.order);
      expect(store.habit.place.region, want.region);

      final again = Store();
      await again.load();
      final found = again.habits.firstWhere((h) => h.name == 'Correr');
      expect(found.place.region, want.region);
    });

    test('a habit saved before there was a choice keeps its plot\'s own', () {
      final old = Habit.fromJson({
        'id': 'h1',
        'n': 'Leer',
        's': 'libro',
        'slot': 2,
        'c': DateTime(2025).millisecondsSinceEpoch,
        'p': const [],
      });
      expect(old.place.region, TownCharacter.forSlot(2).region);
    });
  });

  group('eliminar un hábito', () {
    test('se lleva su pueblo y deja los demás donde estaban', () async {
      final s = await freshStore();
      s.renameHabit(0, name: 'Leer');
      s.addHabit('Correr', 'carrera');
      s.addHabit('Nadar', 'ola');
      s.select(1);
      s.placePiece();
      s.removeHabit(1);
      expect(s.habits.length, 2);
      expect(s.habits.map((h) => h.name), ['Leer', 'Nadar']);
      expect(s.habits.every((h) => h.total == 0), isTrue);
    });

    test(
      'el último también se puede eliminar: el valle vuelve a cero',
      () async {
        // Lo que pasaba: con un solo hábito el botón no hacía nada, así que no
        // había forma de borrar un pueblo empezado por error. Un valle sin
        // nada que dibujar no es un estado que la app tenga, así que eliminar
        // el único deja el mismo hábito en blanco de un teléfono recién
        // instalado — sin nombre puesto, sin piezas y sin la marca de antes.
        final s = await freshStore();
        s.renameHabit(0, name: 'Fumar menos', symbol: 'pipa');
        s.placePiece();
        s.placePiece();
        final was = s.habit.id;
        s.removeHabit(0);
        expect(s.habits.length, 1);
        expect(s.habit.id, isNot(was));
        expect(s.habit.total, 0);
        expect(s.habit.name, isNot('Fumar menos'));
        expect(s.habit.symbol, isNot('pipa'));
        expect(s.active, 0);
      },
    );

    test('un índice que no existe no toca nada', () async {
      final s = await freshStore();
      s.addHabit('Correr', 'carrera');
      s.removeHabit(7);
      s.removeHabit(-1);
      expect(s.habits.length, 2);
    });
  });

  group('el cielo del valle', () {
    test('el observatorio llega, y hasta entonces no hay cielo', () async {
      final s = await freshStore();
      expect(s.hasObservatory, isFalse);
      // Buscamos a qué altura lo levanta este pueblo, y comprobamos que
      // efectivamente antes no y después sí. El número exacto depende del
      // carácter del pueblo, así que se busca en vez de escribirse a mano.
      final plan = TownPlan.of(s.character);
      var at = -1;
      for (var n = 0; n <= 6000; n += 1) {
        if (plan.built('observatorio', n)) {
          at = n;
          break;
        }
      }
      expect(at, greaterThan(0), reason: 'este pueblo no lo construye nunca');
      expect(plan.built('observatorio', at - 1), isFalse);
      expect(plan.built('observatorio', at + 500), isTrue);
      // ignore: avoid_print
      print('observatorio a las $at piezas');
    });

    test('todos los pueblos lo construyen tarde o temprano', () async {
      // Un hito que en un carácter no sale nunca dejaría a ese hábito sin
      // cielo para siempre, y eso no se vería hasta que alguien llegase.
      for (final c in TownCharacter.all) {
        expect(
          TownPlan.of(c).built('observatorio', 4000),
          isTrue,
          reason:
              '${c.region} no levanta observatorio ni con cuatro mil piezas, '
              'así que ese hábito se queda sin cielo para siempre',
        );
      }
    });

    test('anotar una constelación es una sola vez', () async {
      final s = await freshStore();
      expect(s.sawIt('orion'), isFalse);
      expect(s.logConstellation('orion'), isTrue);
      expect(s.sawIt('orion'), isTrue);
      expect(
        s.logConstellation('orion'),
        isFalse,
        reason: 'la anotó dos veces',
      );
      expect(s.sky.length, 1);
    });

    test('y el cuaderno sobrevive a cerrar la app', () async {
      final s = await freshStore();
      s.logConstellation('orion');
      s.logConstellation('cruz');
      s.placePiece();
      final again = Store();
      await again.load();
      expect(again.sky, {'cruz', 'orion'});
      expect(again.sawIt('lira'), isFalse);
    });

    test('y sale y entra con el resto del valle', () async {
      final s = await freshStore();
      s.logConstellation('casiopea');
      final saved = s.exportSave();
      final other = await freshStore();
      expect(other.sawIt('casiopea'), isFalse);
      expect(other.importSave(saved), isNull, reason: 'no lo pudo leer');
      expect(other.sawIt('casiopea'), isTrue);
    });
  });

  group('quitar la última pieza', () {
    test('la quita, y sólo la última', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.placePiece();
      final gone = s.removeLastPiece();
      expect(gone, isNotNull);
      expect(gone!.index, 2);
      expect(s.total, 2);
      expect(s.pieceAt(0), isNotNull);
      expect(s.pieceAt(1), isNotNull);
      expect(s.pieceAt(2), isNull);
    });

    test('con el pueblo vacío no hace nada', () async {
      final s = await freshStore();
      expect(s.removeLastPiece(), isNull);
      expect(s.total, 0);
    });

    test('se lleva su leyenda', () async {
      final s = await freshStore();
      s.placePiece();
      s.setLabel(0, 'lo que fuera');
      expect(s.pieceAt(0)!.label, 'lo que fuera');
      s.removeLastPiece();
      s.placePiece();
      expect(
        s.pieceAt(0)!.hasLabel,
        isFalse,
        reason: 'volvió la leyenda vieja',
      );
    });

    test('y queda quitada al volver a abrir', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.removeLastPiece();
      final again = Store();
      await again.load();
      expect(again.total, 1);
    });

    test('la crónica de obra no se deshace con ella', () async {
      // Lo que se decidió, se decidió. Deshacer un dedo no es motivo para
      // volver a sortear qué edificio se está levantando: el que estaba
      // escrito sigue siendo el que se va a construir.
      final s = await freshStore();
      for (var i = 0; i < 40; i++) {
        s.placePiece();
      }
      final was = [...s.habit.chronicle];
      s.removeLastPiece();
      expect(s.habit.chronicle, was);
    });
  });

  group('persistence', () {
    test('the wall survives a restart exactly as it was', () async {
      SharedPreferences.setMockInitialValues({});
      final a = Store();
      await a.load();
      for (var i = 0; i < 14; i++) {
        a.placePiece();
      }
      a.setLabel(3, 'Leí');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final b = Store();
      await b.load();
      expect(b.total, a.total);
      expect(b.pieceAt(3)!.label, 'Leí');
      expect(b.labelled.length, 1);
    });

    test('a corrupt save starts clean instead of failing', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.la_muralla_state_v2': 'not json at all',
      });
      final s = Store();
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.total, 0);
    });
  });

  group('streaks', () {
    test('consecutive days count, gaps break the run', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [0, 1, 2, 5, 6]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });
  });
}
