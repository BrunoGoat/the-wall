import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Store> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = Store();
  await s.load();
  return s;
}

/// Un pueblo entero como una línea de texto, para poder compararlo.
///
/// Como texto y no como registro: en Dart dos registros que llevan una lista
/// dentro se comparan por identidad, así que dos copias idénticas salen
/// distintas y el test se cae diciendo que Expected y Actual son iguales.
String shapeOf(Habit h) => [
  h.id,
  h.name,
  h.symbol,
  h.slot,
  h.character,
  h.total,
  // Al milisegundo, que es la resolución que el guardado tiene desde siempre:
  // una copia conserva exactamente lo mismo que conserva cerrar la app y
  // volver a abrirla, ni más ni menos.
  for (final p in h.pieces)
    '${p.index}@${p.placedAt.millisecondsSinceEpoch}:${p.label ?? ''}',
].join('|');

/// Un valle con algo dentro, para tener qué perder.
Future<Store> lived() async {
  final s = await freshStore();
  s.renameHabit(0, name: 'Leer', symbol: 'libro');
  for (var i = 0; i < 5; i++) {
    s.placePiece();
  }
  s.setLabel(2, 'el día que llovía');
  s.addHabit('Correr', 'carrera', character: TownCharacter.all[3].order);
  for (var i = 0; i < 3; i++) {
    s.placePiece();
  }
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('llevarse el valle', () {
    test('lo que sale vuelve a entrar igual', () async {
      final s = await lived();
      final copy = s.exportSave();
      final was = [for (final h in s.habits) shapeOf(h)];
      final wasActive = s.active;

      // Otro teléfono, otra instalación, nada dentro.
      final other = await freshStore();
      expect(other.total, 0);
      expect(other.importSave(copy), isNull);

      expect(other.active, wasActive);
      expect([for (final h in other.habits) shapeOf(h)], was);
    });

    test('la copia sobrevive a guardar y volver a abrir', () async {
      final s = await lived();
      final copy = s.exportSave();
      final other = await freshStore();
      other.importSave(copy);
      // La importación tiene que haber escrito en disco, no sólo en memoria.
      final again = Store();
      await again.load();
      expect(again.exportSave(), copy);
    });

    test('la fecha exacta de cada pieza se conserva al milisegundo', () async {
      final s = await lived();
      final when = [
        for (final h in s.habits)
          for (final p in h.pieces) p.placedAt.millisecondsSinceEpoch,
      ];
      final other = await freshStore();
      other.importSave(s.exportSave());
      final back = [
        for (final h in other.habits)
          for (final p in h.pieces) p.placedAt.millisecondsSinceEpoch,
      ];
      expect(back, when);
    });
  });

  group('una copia rota no se lleva por delante lo que hay', () {
    Future<void> refuses(String text, {String? because}) async {
      final s = await lived();
      final before = s.exportSave();
      final said = s.importSave(text);
      expect(said, isNotNull, reason: 'debería haberse negado: $because');
      expect(said, isNotEmpty);
      expect(
        s.exportSave(),
        before,
        reason: 'se negó pero igual tocó el valle: $because',
      );
    }

    test('nada, basura, y cosas que no son esto', () async {
      await refuses('', because: 'vacío');
      await refuses('   \n ', because: 'sólo espacios');
      await refuses('hola qué tal', because: 'texto suelto');
      await refuses('[1,2,3]', because: 'JSON pero no un objeto');
      await refuses('{"otra":"app"}', because: 'sin la lista de pueblos');
      await refuses('{"h":"no es una lista"}', because: 'h no es lista');
      await refuses('{"h":[]}', because: 'ningún pueblo dentro');
      await refuses('{"h":[{"p":[{"i":0}]}]}', because: 'pieza sin fecha');
      await refuses('{"h":[1,2]}', because: 'pueblos que no son objetos');
    });

    test('más pueblos de los que el valle tiene sitio', () async {
      final many = List.generate(
        Habit.maxSlots + 1,
        (i) => '{"id":"h$i","n":"P$i","s":"libro","slot":$i,"c":0,"p":[]}',
      ).join(',');
      await refuses('{"h":[$many]}', because: 'un pueblo más de los que caben');
    });
  });

  group('una copia vieja sigue entrando', () {
    test('sin región elegida, sin símbolo dibujado y sin etiquetas', () async {
      // Lo que habría escrito una versión anterior: sin `ch`, con un emoji
      // donde ahora va una marca, y sin `l` en las piezas.
      const old =
          '{"v":1,"a":0,"h":[{"id":"h0","n":"Leer","s":"📖","slot":0,'
          '"c":1700000000000,"p":[{"i":0,"t":1700000000000},'
          '{"i":1,"t":1700086400000}]}]}';
      final s = await freshStore();
      expect(s.importSave(old), isNull);
      expect(s.habits.single.total, 2);
      expect(s.habits.single.name, 'Leer');
      // El emoji se lee como la marca que significa lo mismo.
      expect(s.habits.single.symbol, isNot('📖'));
      // Y sin región guardada se queda con la que su parcela tenía.
      expect(s.habits.single.character, TownCharacter.forSlot(0).order);
    });

    test('piezas con huecos en la numeración se renumeran', () async {
      const gappy =
          '{"h":[{"id":"h0","n":"Leer","s":"libro","slot":0,"c":0,'
          '"p":[{"i":9,"t":3},{"i":0,"t":1},{"i":4,"t":2}]}]}';
      final s = await freshStore();
      expect(s.importSave(gappy), isNull);
      final p = s.habits.single.pieces;
      expect(p.map((e) => e.index), [0, 1, 2]);
      // Y en el orden en que se pusieron, no en el que venían escritas.
      expect(p.map((e) => e.placedAt.millisecondsSinceEpoch), [1, 2, 3]);
    });
  });

  group('lo que se dice en voz alta', () {
    test('cuenta piezas y pueblos, en singular y en plural', () async {
      final s = await freshStore();
      expect(s.describe(), '0 piezas en 1 pueblo');
      s.placePiece();
      expect(s.describe(), '1 pieza en 1 pueblo');
      s.placePiece();
      s.addHabit('Correr', 'carrera');
      expect(s.describe(), '2 piezas en 2 pueblos');
    });
  });
}
