import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/rng.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/town.dart';

/// What one region's town actually comes out as, measured off the pieces.
///
/// This whole file exists because nothing here was measured before. Six
/// regions were declared in a table, half of what the table said was never
/// read by anything, and the parts that were read were applied so gently that
/// the noise between two houses of the same region was as loud as the
/// difference between two regions. Nothing failed; the towns just quietly
/// converged, and only somebody looking at two of them side by side would ever
/// have known. So: numbers, and a floor under each of them.
class Measured {
  Measured(this.place, int pieces) {
    final town = TownLayout(pieces, place);
    final tall = <double>[], wide = <double>[], roofs = <double>[];
    for (final b in town.buildings) {
      if (b.isLandmark || b.firstPiece >= pieces) continue;
      var top = 0.0, w = 0.0, roof = 0.0;
      for (final p in town.pieces) {
        if (p.building != b.index) continue;
        if (p.y1 > top) top = p.y1;
        if (p.w > w) w = p.w;
        if (p.kind == PieceKind.roof || p.kind == PieceKind.thatch) {
          roof += p.y1 - p.y0;
        }
      }
      if (top <= 0) continue;
      tall.add(top);
      wide.add(w);
      if (roof > 0) roofs.add(roof);
      if (b.yardSize > 0) gardens++;
      if (b.treeSize > 0) trees++;
      houses++;
    }
    height = _mean(tall);
    footprint = _mean(wide);
    roofRise = _mean(roofs);
    radius = town.radius;

    for (final p in town.pieces) {
      if (p.kind == PieceKind.thatch) straw++;
      if (p.kind == PieceKind.roof) hard++;
    }

    // The walls, worked out the way the renderer works them out.
    final pal = Palette.forMoment(11, 1.0);
    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = 0; i < 400; i++) {
      final h = hash32(i, 0x51ed, 3);
      var c = Color.lerp(
        pal.stoneCool,
        pal.stoneWarm,
        0.35 + hash01(h, 1) * 0.55,
      )!;
      if (hash01(h, 2) < place.washShare) {
        c = Color.lerp(c, place.wash, 0.52 + hash01(h, 21) * 0.30)!;
      }
      r += c.r;
      g += c.g;
      b += c.b;
    }
    wall = Color.from(alpha: 1, red: r / 400, green: g / 400, blue: b / 400);
  }

  final TownCharacter place;
  late final double height, footprint, roofRise, radius;
  late final Color wall;
  int straw = 0, hard = 0, houses = 0, gardens = 0, trees = 0;

  double get strawShare => straw / (straw + hard);

  /// Lo inclinado que es un tejado es cuánto sube partido por lo que cruza.
  /// Medido sólo por lo que sube, el pueblo más alto gana siempre, que no es
  /// lo que «inclinado» quiere decir.
  double get slope => footprint == 0 ? 0 : roofRise / footprint;

  double get gardenShare => houses == 0 ? 0 : gardens / houses;
  double get treeShare => houses == 0 ? 0 : trees / houses;

  static double _mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
}

/// How many windows one wall of a plain house gets, which is the only place a
/// wall's thickness is ever visible.
int _windowsPerWall(TownCharacter place) {
  final span = 1.63 * place.spread - 0.4;
  return span < 0.5
      ? 1
      : (span / (0.62 * place.windowGap)).floor().clamp(1, 99);
}

void main() {
  final towns = {for (final c in TownCharacter.all) c.region: Measured(c, 400)};

  final regions = towns;

  ({String most, String least, double ratio}) rank(
    double Function(Measured) of,
  ) {
    final rows = regions.entries.toList()
      ..sort((a, b) => of(a.value).compareTo(of(b.value)));
    final lo = of(rows.first.value), hi = of(rows.last.value);
    return (
      most: rows.last.key,
      least: rows.first.key,
      ratio: lo == 0 ? double.infinity : hi / lo,
    );
  }

  group('los seis no son el mismo pueblo', () {
    test('cada eje separa de verdad al primero del último', () {
      // Menos de esto y la diferencia entre dos regiones es más chica que el
      // azar entre dos casas de la misma, que es exactamente como estaban.
      final floors = {
        'alto': (1.35, (Measured m) => m.height),
        'huella': (1.30, (Measured m) => m.footprint),
        'inclinación': (2.50, (Measured m) => m.slope),
        'radio': (1.20, (Measured m) => m.radius),
      };
      for (final e in floors.entries) {
        final (need, of) = e.value;
        final r = rank(of);
        expect(
          r.ratio,
          greaterThanOrEqualTo(need),
          reason:
              '${e.key}: ${r.most} apenas le saca a ${r.least} '
              '(${r.ratio.toStringAsFixed(2)}x, hace falta ${need}x)',
        );
      }
    });

    test('dos paredes cualesquiera se distinguen', () {
      final all = towns.values.toList();
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final a = all[i].wall, b = all[j].wall;
          final d = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
          expect(
            d,
            greaterThan(0.06),
            reason:
                '${all[i].place.region} y ${all[j].place.region} están '
                'pintados del mismo color (${d.toStringAsFixed(3)})',
          );
        }
      }
    });

    test('ningún par comparte techumbre', () {
      // La mezcla entera, no sólo la paja: dos pueblos pueden coincidir en
      // cuánta paja tienen y aun así uno ser de teja y el otro de pizarra.
      for (final a in towns.values) {
        for (final b in towns.values) {
          if (identical(a, b)) continue;
          final d =
              (a.place.roofMix.$1 - b.place.roofMix.$1).abs() +
              (a.place.roofMix.$2 - b.place.roofMix.$2).abs() +
              (a.place.roofMix.$3 - b.place.roofMix.$3).abs();
          expect(
            d,
            greaterThan(0.15),
            reason: '${a.place.region} y ${b.place.region} techan igual',
          );
        }
      }
    });
  });

  group('cada uno cumple lo que su descripción dice', () {
    test('Sierra es la más alta y la más apretada', () {
      expect(rank((m) => m.height).most, 'Sierra');
      expect(rank((m) => m.footprint).least, 'Sierra');
      expect(rank((m) => m.place.plotPitch).least, 'Sierra');
      expect(towns['Sierra']!.place.roofMix.$2, greaterThan(0.5)); // pizarra
    });

    test('Ribera es la más ancha, la más blanca y casi toda de teja', () {
      expect(rank((m) => m.footprint).most, 'Ribera');
      expect(rank((m) => m.wall.computeLuminance()).most, 'Ribera');
      expect(towns['Ribera']!.place.roofMix.$1, greaterThan(0.7));
      expect(towns['Ribera']!.height, lessThan(towns['Sierra']!.height));
    });

    test('Marca tiene los muros más gruesos y las menos ventanas', () {
      expect(rank((m) => m.place.wallThick).most, 'Marca');
      for (final c in TownCharacter.all) {
        if (c.region == 'Marca') continue;
        expect(
          _windowsPerWall(c),
          greaterThanOrEqualTo(_windowsPerWall(towns['Marca']!.place)),
          reason: '${c.region} tiene menos ventanas que la Marca',
        );
      }
      // Y es ocre: más rojo que azul, que es lo que ocre quiere decir.
      final w = towns['Marca']!.wall;
      expect(w.r - w.b, greaterThan(0.20));
    });

    test('Valle tiene los solares más grandes y una huerta en cada casa', () {
      expect(rank((m) => m.place.plotPitch).most, 'Valle');
      expect(towns['Valle']!.gardenShare, greaterThan(0.75));
      expect(towns['Valle']!.strawShare, greaterThan(0.55));
    });

    test('Costa es la más baja, la más plana y la más añil', () {
      expect(rank((m) => m.height).least, 'Costa');
      expect(rank((m) => m.slope).least, 'Costa');
      // Añil: el azul le gana al rojo. En ningún otro pueblo pasa.
      final w = towns['Costa']!.wall;
      expect(w.b, greaterThan(w.r));
      for (final t in regions.values) {
        if (t.place.region == 'Costa') continue;
        expect(t.wall.b, lessThan(t.wall.r), reason: t.place.region);
      }
    });

    test('Robledal tiene los tejados más agudos y está bajo los robles', () {
      expect(rank((m) => m.slope).most, 'Robledal');
      expect(towns['Robledal']!.treeShare, greaterThan(0.75));
      expect(towns['Robledal']!.strawShare, greaterThan(0.5));
      for (final t in regions.values) {
        if (t.place.region == 'Robledal') continue;
        expect(
          t.treeShare,
          lessThan(towns['Robledal']!.treeShare),
          reason: '${t.place.region} tiene tantos árboles como el Robledal',
        );
      }
    });
  });

  group('el carácter llega a los hitos, no sólo a las casas', () {
    test('el mismo castillo sale distinto en cada región', () {
      final tall = <String, double>{}, wide = <String, double>{};
      for (final place in TownCharacter.all) {
        final l = TownLayout.showcase(
          place,
          kind: BuildingKind.townhouse,
          placed: 40,
          seed: 7,
        );
        var top = 0.0, w = 0.0;
        for (final p in l.pieces) {
          if (p.y1 > top) top = p.y1;
          if (p.w > w) w = p.w;
        }
        tall[place.region] = top;
        wide[place.region] = w;
      }
      final hs = tall.values.toList()..sort();
      final ws = wide.values.toList()..sort();
      expect(
        hs.last / hs.first,
        greaterThan(1.5),
        reason: 'la misma receta sale igual de alta en los seis: $tall',
      );
      expect(
        ws.last / ws.first,
        greaterThan(1.4),
        reason: 'la misma receta sale igual de ancha en los seis: $wide',
      );
    });
  });
}
