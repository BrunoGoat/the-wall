import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/ui/legend_card.dart';
import 'package:la_muralla/ui/overlays.dart';
import 'package:la_muralla/ui/placed_note.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/town_sign.dart';

/// Un teléfono estrecho y uno ancho: lo que se rompe en un diseño puesto sobre
/// la escena es que se salga por un costado o que se desborde, y las dos cosas
/// dependen del ancho.
const _pantallas = [Size(320, 640), Size(440, 950)];

/// Un nombre largo de verdad. Los cinco diseños tienen que aguantarlo: los
/// hábitos de la gente no se llaman «Leer».
const _largo = 'Despertarse temprano sin excusas';

/// El campo de texto de la leyenda quiere un Material y sus localizaciones
/// encima. En la app se los pone el MaterialApp; aquí hay que ponerlo igual, o
/// lo que falla es el andamio y no el diseño.
Widget _marco(Size size, Widget child) => MediaQuery(
  data: MediaQueryData(
    size: size,
    padding: const EdgeInsets.only(top: 34, bottom: 22),
  ),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: const Color(0xFF7E9058),
      child: Stack(children: [Positioned.fill(child: child)]),
    ),
  ),
);

void main() {
  group('los cinco carteles del pueblo', () {
    for (final s in TownSign.values) {
      testWidgets('${s.name} cabe en la pantalla y no desborda', (
        tester,
      ) async {
        for (final size in _pantallas) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final t = UiTheme(Palette.forMoment(13, 1.0));
          await tester.pumpWidget(
            _marco(
              size,
              TownSignOverlay(name: _largo, symbol: 'sol', theme: t, sign: s),
            ),
          );
          // A la mitad de la entrada y ya entero: si algo se sale, se sale en
          // uno de los dos momentos.
          for (final ms in [90, 700]) {
            await tester.pump(Duration(milliseconds: ms));
            expect(tester.takeException(), isNull);
            for (final e in find.byType(Text).evaluate()) {
              final box = e.renderObject! as RenderBox;
              final at = box.localToGlobal(Offset.zero);
              expect(
                at.dx,
                greaterThan(-1),
                reason: '$s se sale por la izquierda en $size',
              );
              expect(
                at.dx + box.size.width,
                lessThan(size.width + 1),
                reason: '$s se sale por la derecha en $size',
              );
              expect(
                at.dy + box.size.height,
                lessThan(size.height + 1),
                reason: '$s se sale por abajo en $size',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('las cinco maneras de anunciar la pieza', () {
    for (final s in NoteStyle.values) {
      testWidgets('${s.name} cabe, y lleva al mismo papel', (tester) async {
        for (final size in _pantallas) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final t = UiTheme(Palette.forMoment(13, 1.0));
          await tester.pumpWidget(
            _marco(
              size,
              PlacedNote(
                habit: Habit(
                  id: 'x',
                  name: _largo,
                  symbol: 'sol',
                  slot: 0,
                  createdAt: DateTime(2026),
                ),
                ordinal: 128,
                theme: t,
                style: s,
                card: CardStyle.esmerilada,
                onWrite: (_) {},
                onDismiss: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          for (final e in find.byType(Text).evaluate()) {
            final box = e.renderObject! as RenderBox;
            final at = box.localToGlobal(Offset.zero);
            expect(at.dx, greaterThan(-1), reason: '$s se sale en $size');
            expect(
              at.dx + box.size.width,
              lessThan(size.width + 1),
              reason: '$s se sale en $size',
            );
          }
          // Las cinco desembocan en el mismo papel, que es la parte que ya
          // estaba decidida y no entra en la comparación.
          expect(find.byType(TextField), findsNothing);
          await tester.tap(find.byKey(anotar));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.byType(TextField),
            findsOneWidget,
            reason: 'desde $s no se llega a escribir la leyenda',
          );
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('los cinco materiales de la tarjeta', () {
    // Una leyenda larga y una pieza de cuatro cifras: es donde una tarjeta se
    // rompe, no en «Leí».
    const leyenda = 'Corrí ocho kilómetros por el parque, con lluvia';

    for (final c in CardStyle.values) {
      testWidgets('${c.name} cabe y se lee', (tester) async {
        for (final size in _pantallas) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final t = UiTheme(Palette.forMoment(13, 1.0));
          await tester.pumpWidget(
            _marco(
              size,
              Center(
                child: StoneCard(
                  theme: t,
                  style: c,
                  when: DateTime(2026, 9, 10, 8, 50),
                  number: 1284,
                  label: leyenda,
                  onEdit: () {},
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          expect(find.text(leyenda), findsOneWidget);
          for (final e in find.byType(Text).evaluate()) {
            final box = e.renderObject! as RenderBox;
            final at = box.localToGlobal(Offset.zero);
            expect(at.dx, greaterThan(-1), reason: '$c se sale en $size');
            expect(
              at.dx + box.size.width,
              lessThan(size.width + 1),
              reason: '$c se sale en $size',
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    testWidgets('leer y escribir salen del mismo material', (tester) async {
      // La decisión que ya estaba tomada y que estos cinco no pueden romper:
      // escribir una leyenda y leerla son la misma cosa vista dos veces.
      for (final c in CardStyle.values) {
        tester.view.physicalSize = _pantallas.last;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final t = UiTheme(Palette.forMoment(13, 1.0));
        for (final leyendo in [true, false]) {
          await tester.pumpWidget(
            _marco(
              _pantallas.last,
              leyendo
                  ? Center(
                      child: StoneCard(
                        theme: t,
                        style: c,
                        when: DateTime(2026, 9, 10),
                        number: 7,
                        label: 'algo',
                        onEdit: () {},
                      ),
                    )
                  : PlacedNote(
                      habit: Habit(
                        id: 'x',
                        name: 'Correr',
                        symbol: 'sol',
                        slot: 0,
                        createdAt: DateTime(2026),
                      ),
                      ordinal: 7,
                      theme: t,
                      style: NoteStyle.tarjeta,
                      card: c,
                      onWrite: (_) {},
                      onDismiss: () {},
                    ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          if (!leyendo) await tester.tap(find.byKey(anotar));
          await tester.pump(const Duration(milliseconds: 300));
          final tarjeta = tester.widget<LegendCard>(find.byType(LegendCard));
          expect(
            tarjeta.style,
            c,
            reason: leyendo
                ? 'al leer, la tarjeta no salió de $c'
                : 'al escribir, la tarjeta no salió de $c',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  });
}
