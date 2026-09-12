import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/folk.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/census.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';

/// Un hábito con [n] piezas, una por día, empezando el 1 de marzo.
Habit _habit(int n) => Habit(
  id: 'h',
  name: 'Prueba',
  symbol: 'rueda',
  slot: 0,
  createdAt: DateTime(2026, 3, 1),
  character: TownCharacter.all.first.order,
  pieces: [
    for (var i = 0; i < n; i++)
      Piece(
        index: i,
        placedAt: DateTime(2026, 3, 1).add(Duration(days: i)),
      ),
  ],
);

TownLayout _town(Habit h) =>
    TownLayout(h.total, h.place, chronicle: h.chronicle, folk: h.folk);

void main() {
  group('el padrón', () {
    test('una casa terminada, una línea; y ni una de más', () {
      final h = _habit(200);
      final t = _town(h);
      final nacidos = enrolFolk(h, t);
      final casas = t.buildings
          .where((b) => !b.isLandmark && b.firstPiece + b.cost <= 200)
          .length;
      expect(nacidos.length, casas);
      expect(h.folk.length, casas);
    });

    test('pasarlo dos veces no apunta a nadie dos veces', () {
      // Lo llama la vista cada vez que cambia la cuenta de piezas, y en un
      // arranque eso puede pasar varias veces sobre el mismo pueblo.
      final h = _habit(200);
      final t = _town(h);
      enrolFolk(h, t);
      final antes = List<String>.from(h.folk);
      expect(enrolFolk(h, _town(h)), isEmpty);
      expect(h.folk, antes);
    });

    test('nació el día que se remató su casa, no el día que lo apunté', () {
      // Es lo que hace que un pueblo de dos años recupere los dos años de
      // cumpleaños de golpe y en su sitio, en vez de que todos hayan nacido
      // hoy.
      final h = _habit(200);
      final t = _town(h);
      for (final v in enrolFolk(h, t)) {
        final b = t.buildings[v.home];
        final ultima = h.pieces[b.firstPiece + b.cost - 1];
        expect(v.born, ultima.placedAt);
      }
    });

    test('y el padrón sale en orden de llegada', () {
      final h = _habit(300);
      final nacidos = enrolFolk(h, _town(h));
      for (var i = 1; i < nacidos.length; i++) {
        expect(
          nacidos[i].born.isBefore(nacidos[i - 1].born),
          isFalse,
          reason: 'el padrón está desordenado',
        );
      }
    });

    test('el pueblo crece y el padrón crece con él, sin reescribirse', () {
      final h = _habit(60);
      enrolFolk(h, _town(h));
      final antes = List<String>.from(h.folk);
      for (var i = 60; i < 240; i++) {
        h.pieces.add(
          Piece(
            index: i,
            placedAt: DateTime(2026, 3, 1).add(Duration(days: i)),
          ),
        );
      }
      enrolFolk(h, _town(h));
      expect(h.folk.length, greaterThan(antes.length));
      // Lo de antes sigue palabra por palabra donde estaba.
      expect(h.folk.sublist(0, antes.length), antes);
    });

    test('una línea se escribe y se vuelve a leer igual', () {
      final v = Villager(
        7,
        123456789,
        DateTime(2025, 11, 4, 21, 30),
        'Ximena|X',
      );
      final leido = Villager.parse(v.line)!;
      expect(leido.home, v.home);
      expect(leido.seed, v.seed);
      expect(leido.born, v.born);
      // El nombre puede llevar cualquier cosa dentro, barras incluidas: por eso
      // va al final y se junta lo que quede.
      expect(leido.name, v.name);
    });

    test('una línea rota no tira el padrón entero', () {
      expect(Villager.parse(''), isNull);
      expect(Villager.parse('4|5'), isNull);
      expect(Villager.parse('no|es|un|padrón'), isNull);
      expect(censusOf(['roto', '3|9|1700000000000|Toda la Moza']).length, 1);
    });
  });

  group('lo apuntado manda', () {
    test('el nombre y la cara de un vecino no los cambia nadie', () {
      // La prueba de fuego de todo esto: si mañana toco la lista de nombres o
      // muevo un tono de piel, alguien que lleva dos años en tu pueblo tiene
      // que seguir siendo exactamente quien era. Lo que hay guardado gana
      // siempre a lo que se calcularía hoy.
      final h = _habit(200);
      final t = _town(h);
      enrolFolk(h, t);
      final quien = folkOf(t, 200).first;

      // Y ahora se abre la app con un padrón que dice otra cosa de él: otra
      // semilla y otro nombre, que es lo que habría escrito el día que nació
      // una versión mía con otra lista de nombres y otros tonos de piel.
      final otra = h.folk.first.split('|');
      final libro = [
        '${otra[0]}|987654321|${otra[2]}|Belasco el Zurdo',
        ...h.folk.skip(1),
        // Un renglón de más para que no sea el mismo pueblo en caché.
        '9999|1|0|Nadie de Ninguna Parte',
      ];
      final nuevo = TownLayout(200, h.place, folk: libro);
      final ahora = folkOf(nuevo, 200).firstWhere((w) => w.home == quien.home);

      expect(ahora.seed, 987654321);
      expect(ahora.name, 'Belasco el Zurdo');
      expect(ahora.born, quien.born);
    });

    test('sin padrón hay gente igual, sólo que sin fecha', () {
      // El expositor y los tests no tienen un hábito detrás, y el pueblo no se
      // puede quedar vacío por eso.
      final t = TownLayout(200, TownCharacter.all.first);
      final gente = folkOf(t, 200);
      expect(gente, isNotEmpty);
      for (final w in gente) {
        expect(w.born, isNull);
        expect(w.name, isNotEmpty);
      }
    });
  });
}
