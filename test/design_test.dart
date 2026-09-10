import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/mason.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/ui/legend_card.dart';
import 'package:la_muralla/ui/overlays.dart';
import 'package:la_muralla/ui/placed_note.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/town_sign.dart';

/// Un teléfono estrecho y uno ancho: lo que se rompe en algo puesto sobre la
/// escena es que se salga por un costado, y eso depende del ancho.
const _pantallas = [Size(320, 640), Size(440, 950)];

/// Un nombre largo de verdad. Los hábitos de la gente no se llaman «Leer».
const _largo = 'Despertarse temprano sin excusas';

/// El campo de texto quiere un Material y sus localizaciones encima. En la app
/// se los pone el MaterialApp; aquí hay que ponerlos igual, o lo que falla es
/// el andamio y no el diseño.
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

/// Que nada de lo que se escribe se salga de la pantalla.
void _dentro(WidgetTester tester, Size size, String quien) {
  for (final e in find.byType(Text).evaluate()) {
    final box = e.renderObject! as RenderBox;
    final at = box.localToGlobal(Offset.zero);
    expect(
      at.dx,
      greaterThan(-1),
      reason: '$quien se sale por la izquierda en $size',
    );
    expect(
      at.dx + box.size.width,
      lessThan(size.width + 1),
      reason: '$quien se sale por la derecha en $size',
    );
    expect(
      at.dy + box.size.height,
      lessThan(size.height + 1),
      reason: '$quien se sale por abajo en $size',
    );
  }
}

void main() {
  testWidgets('el cartel del pueblo cabe y no se queda puesto', (tester) async {
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const vida = Duration(milliseconds: 1700);
      await tester.pumpWidget(
        _marco(
          size,
          TownSignOverlay(
            name: _largo,
            symbol: 'sol',
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            life: vida,
          ),
        ),
      );
      // A media entrada y ya entero: si algo se sale, se sale en uno de los dos.
      for (final ms in [90, 700]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(tester.takeException(), isNull);
        _dentro(tester, size, 'el cartel');
      }
      // Y para el final de su vida se ha ido del todo, que es lo que se pidió:
      // que se desvanezca antes.
      await tester.pump(vida);
      final opacidad = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(
        opacidad.every((o) => o.opacity < 0.02),
        isTrue,
        reason: 'el cartel sigue puesto cuando ya debería haberse ido',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('el anuncio de la pieza dice de qué es y lleva al papel', (
    tester,
  ) async {
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          PlacedNote(
            kind: pieceName[PieceKind.chimney],
            ordinal: 1284,
            when: DateTime(2026, 9, 10, 8, 50),
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            onWrite: (_) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // Lo que dice es qué se construyó. Ni el pueblo ni el número de pieza:
      // el pueblo se está mirando y el número está arriba a la izquierda.
      expect(find.text('Chimenea'), findsOneWidget);
      expect(find.textContaining('1284'), findsNothing);
      _dentro(tester, size, 'el anuncio');

      // Y de ahí se llega al mismo papel que sale al releer una leyenda.
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(anotar));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LegendCard), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la tarjeta de la leyenda cabe y se lee', (tester) async {
    const leyenda = 'Corrí ocho kilómetros por el parque, con lluvia';
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          Center(
            child: StoneCard(
              theme: UiTheme(Palette.forMoment(13, 1.0)),
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
      _dentro(tester, size, 'la tarjeta');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('lo que falta por escribir va en pardo, no en color de aviso', (
    tester,
  ) async {
    // Una leyenda que no está escrita no es una alerta. En el naranja de la
    // hora lo parecía.
    for (final hora in [13.0, 2.0]) {
      final t = UiTheme(Palette.forMoment(hora, 1.0));
      tester.view.physicalSize = _pantallas.last;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          _pantallas.last,
          Center(
            child: StoneCard(
              theme: t,
              when: DateTime(2026, 9, 10),
              number: 7,
              label: null,
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final texto = tester.widget<Text>(find.text('escribir una leyenda'));
      final color = texto.style!.color!;
      expect(
        color,
        isNot(t.accent),
        reason: 'sigue siendo el color de la hora',
      );
      expect(
        color.r,
        greaterThan(color.b),
        reason: 'a las $hora no tira a pardo: el azul le gana al rojo',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('todas las piezas tienen nombre', () {
    // El anuncio dice de qué es la pieza, así que una sin nombre sale como
    // «Pieza» a secas y se pierde lo único que ese cartel tenía que decir.
    for (final k in PieceKind.values) {
      expect(pieceName[k], isNotNull, reason: '$k no tiene nombre');
      expect(pieceName[k]!.trim(), isNotEmpty, reason: '$k tiene nombre vacío');
    }
  });
}
