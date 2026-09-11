import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/ui/legend_card.dart';
import 'package:la_muralla/ui/overlays.dart';
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
              onWrite: (_) {},
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

  testWidgets('lo que falta por escribir no es un aviso, y es de esta hora', (
    tester,
  ) async {
    // Una leyenda que no está escrita no es una alerta. En el naranja de la
    // hora lo parecía, y de ahí viene esto.
    //
    // Lo que se exige cambió: era «que tire a pardo», y un pardo de mediodía a
    // las tres de la mañana es una mancha que no es de esa hora. Ahora sale de
    // la paleta como todo lo demás, así que de noche puede ser fría. Lo que no
    // puede es cantar: tiene que leerse como un texto apagado y no como el
    // color con que la app avisa de algo.
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
              onWrite: (_) {},
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
      double lejos(Color a, Color b) =>
          (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      expect(
        lejos(color, t.fgSoft),
        lessThan(lejos(color, t.accent)),
        reason:
            'a las $hora se parece más al color de aviso que al del texto: '
            'una leyenda sin escribir es un hueco esperando, no una alerta',
      );
      expect(
        lejos(color, t.fgSoft),
        greaterThan(0.02),
        reason: 'a las $hora es exactamente el texto normal y no se distingue',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la leyenda se escribe en la propia tarjeta', (tester) async {
    // Antes esto abría una hoja por debajo, con su título, su explicación y
    // sus botones. Una pantalla entera para una frase de sesenta letras que ya
    // estaba en pantalla.
    final size = _pantallas.last;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? escrito;
    await tester.pumpWidget(
      _marco(
        size,
        Center(
          child: StoneCard(
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            when: DateTime(2026, 9, 10),
            number: 7,
            label: null,
            onWrite: (t) => escrito = t,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Se lee, se toca, y se escribe ahí mismo: una sola tarjeta de principio a
    // fin, sin ninguna pantalla nueva.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('escribir una leyenda'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LegendCard), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Leí un rato');
    // Y sin botón de guardar: tocar fuera guarda, que es lo que iba a pasar
    // igual.
    expect(find.text('Guardar'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 200));
    expect(escrito, 'Leí un rato');
    expect(find.byType(TextField), findsNothing);
  });
}
