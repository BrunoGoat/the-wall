import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/mason.dart';
import 'package:la_muralla/engine/town.dart';

/// Un hito de mentira, para meterlo en el catálogo en mitad de un test y ver
/// qué se rompe. Es la única forma de comprobar de verdad lo que se promete:
/// que el catálogo pueda crecer sin tocar lo construido.
Landmark probe(String id, int tier) => Landmark(
  id,
  'Prueba $id',
  tier == 0 ? 8 : (tier == 1 ? 20 : 40),
  tier,
  'Un edificio que sólo existe dentro de un test.',
  (m) {
    final n = tier == 0 ? 8 : (tier == 1 ? 20 : 40);
    for (var i = 0; i < n - 1; i++) {
      m.floor(1.4, 1.4, 0.4);
    }
    m.roof(1.6, 1.6, 0.5);
  },
);

/// Mete unos cuantos hitos nuevos, corre algo, y deja el catálogo como estaba.
T withNewLandmarks<T>(List<Landmark> extra, T Function() body) {
  landmarks.addAll(extra);
  try {
    return body();
  } finally {
    for (final l in extra) {
      landmarks.remove(l);
    }
  }
}

/// La crónica que tendría un pueblo con estas piezas puestas.
List<String> chronicleAt(TownCharacter c, int placed) =>
    TownPlan.of(c).chronicleFor(placed, const []);

/// Los hitos que vienen, leyendo de una crónica escrita.
List<String> ahead(TownCharacter c, int howMany, List<String> chronicle) {
  final out = <String>[];
  for (final w in TownPlan.of(c).walk(chronicle)) {
    if (w.at < chronicle.length) continue;
    final mark = w.landmark;
    if (mark != null) out.add(mark.id);
    if (out.length >= howMany) break;
  }
  return out;
}

void main() {
  group('el catálogo puede crecer', () {
    test('un hito nuevo no mueve una sola piedra de lo ya construido', () {
      // Esto es lo que se rompía, y se rompía calladamente: la baraja de hitos
      // se ordenaba por la posición de cada uno en la lista, así que meter uno
      // le cambiaba el índice a todos los de su nivel. Un pueblo de treinta
      // piezas amanecía con otras casas.
      for (final c in TownCharacter.all) {
        for (final placed in [1, 12, 30, 154, 420, 900]) {
          final chronicle = chronicleAt(c, placed);
          final was = TownLayout(placed, c, chronicle: chronicle);
          final now = withNewLandmarks([
            probe('probetaA', 0),
            probe('probetaB', 1),
            probe('probetaC', 2),
          ], () => TownLayout(placed, c, chronicle: chronicle));
          expect(
            now.pieces.length,
            was.pieces.length,
            reason: '${c.region} con $placed',
          );
          for (var i = 0; i < was.pieces.length; i++) {
            final a = was.pieces[i], b = now.pieces[i];
            expect(b.kind, a.kind, reason: '${c.region}/$placed: pieza $i');
            expect(
              b.cx,
              closeTo(a.cx, 1e-9),
              reason: '${c.region}/$placed: $i',
            );
            expect(
              b.cz,
              closeTo(a.cz, 1e-9),
              reason: '${c.region}/$placed: $i',
            );
            expect(
              b.y1,
              closeTo(a.y1, 1e-9),
              reason: '${c.region}/$placed: $i',
            );
            expect(
              b.building,
              a.building,
              reason: '${c.region}/$placed: la pieza $i cambió de casa',
            );
          }
          for (var i = 0; i < was.buildings.length; i++) {
            expect(
              now.buildings[i].name,
              was.buildings[i].name,
              reason: '${c.region}/$placed: el edificio $i cambió de identidad',
            );
          }
        }
      }
    });

    test('y lo que viene después sólo se abre para dejarlo entrar', () {
      // La otra mitad de la promesa. No basta con que lo construido no se
      // mueva: lo que viene tiene que seguir viniendo en el mismo orden, con
      // el nuevo intercalado. Si además se reordenase la cola, la pantalla de
      // «el camino por delante» diría una cosa distinta cada actualización.
      for (final c in TownCharacter.all) {
        final chronicle = chronicleAt(c, 200);
        final before = ahead(c, 30, chronicle);
        final after = withNewLandmarks([probe('probetaZ', 1)], () {
          return ahead(
            c,
            34,
            chronicle,
          ).where((id) => id != 'probetaZ').toList();
        });
        expect(
          after.take(before.length).toList(),
          before,
          reason: '${c.region}: la cola se reordenó, no sólo se abrió',
        );
      }
    });

    test('el nuevo entra en la baraja, no al final del todo', () {
      // Que no se pueda colar delante de lo construido no puede querer decir
      // que se vaya al final de ciento y pico obras: eso serían años. Con seis
      // pueblos y tres niveles, a alguien le tiene que tocar pronto.
      final soon = <String>{};
      withNewLandmarks(
        [probe('probetaA', 0), probe('probetaB', 1), probe('probetaC', 2)],
        () {
          for (final c in TownCharacter.all) {
            final chronicle = chronicleAt(c, 200);
            for (final id in ahead(c, 25, chronicle)) {
              if (id.startsWith('probeta')) soon.add('${c.region}/$id');
            }
          }
        },
      );
      expect(
        soon,
        isNotEmpty,
        reason: 'ninguno de los seis pueblos ve un hito nuevo en veinticinco',
      );
    });

    test('y nunca aparece entre lo que ya estaba escrito', () {
      for (final c in TownCharacter.all) {
        final chronicle = chronicleAt(c, 900);
        withNewLandmarks([probe('probetaA', 0), probe('probetaB', 1)], () {
          final again = TownPlan.of(c).chronicleFor(900, chronicle);
          expect(again.take(chronicle.length).toList(), chronicle);
          for (final id in chronicle) {
            expect(id.startsWith('probeta'), isFalse, reason: c.region);
          }
        });
      }
    });
  });

  group('la crónica', () {
    test('escribe lo empezado y ni un edificio más', () {
      // Escribir de más le cerraría la puerta a lo que se añada mañana: el
      // edificio siguiente ya estaría decidido y no podría ser el nuevo.
      final c = TownCharacter.all.first;
      final plan = TownPlan.of(c);
      for (final placed in [0, 1, 5, 30, 200]) {
        final chronicle = plan.chronicleFor(placed, const []);
        final town = TownLayout(placed, c, chronicle: chronicle);
        // Todo edificio con una pieza puesta está escrito.
        final started = town.buildings.where((b) => b.placedPieces > 0).length;
        expect(
          chronicle.length,
          greaterThanOrEqualTo(started),
          reason:
              'con $placed hay $started empezados y ${chronicle.length} escritos',
        );
        // Y como mucho uno más: el que la cabecera ya está nombrando.
        expect(
          chronicle.length,
          lessThanOrEqualTo(started + 1),
          reason: 'con $placed se escribió de más',
        );
      }
    });

    test('sólo crece, y lo escrito manda sobre el catálogo', () {
      // Una crónica que diga algo raro se respeta igual: es lo que pasó.
      final c = TownCharacter.all.first;
      final made = ['pozo', '${TownPlan.kindMark}shed', 'horno'];
      final town = TownLayout(40, c, chronicle: made);
      expect(town.buildings[0].name, TownPlan.landmarkOf('pozo')!.name);
      expect(town.buildings[1].isLandmark, isFalse);
      expect(town.buildings[2].name, TownPlan.landmarkOf('horno')!.name);
    });

    test('un pueblo sin crónica se construye igual que con la suya', () {
      // Es lo que hace que una copia guardada por una versión anterior no se
      // rompa: sin crónica se decide todo, y lo que se decide es lo mismo que
      // se habría escrito.
      for (final c in TownCharacter.all) {
        final blank = TownLayout(300, c);
        final kept = TownLayout(300, c, chronicle: chronicleAt(c, 300));
        for (var i = 0; i < blank.pieces.length; i++) {
          expect(
            kept.pieces[i].cx,
            closeTo(blank.pieces[i].cx, 1e-9),
            reason: '${c.region}: pieza $i',
          );
          expect(
            kept.pieces[i].y1,
            closeTo(blank.pieces[i].y1, 1e-9),
            reason: '${c.region}: pieza $i',
          );
        }
      }
    });
  });
}
