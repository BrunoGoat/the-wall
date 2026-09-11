import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:la_muralla/model/board_seen.dart';
import 'package:la_muralla/model/findings.dart';

Notice _n(NoticeKind k, String said) => Notice(k, said, 'porque sí');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BoardSeen.instance.forget();
  });

  group('lo que ya leíste del tablón', () {
    test('todo es nuevo hasta que lo descolgás', () {
      final said = [
        _n(NoticeKind.hour, 'Casi siempre a las 8 de la mañana.'),
        _n(NoticeKind.week, 'Los martes son tu día fuerte.'),
      ];
      final seen = BoardSeen.instance;
      expect(seen.unread('p1', said), 2);
      expect(seen.markRead('p1', said.first), isTrue);
      expect(seen.unread('p1', said), 1);
      expect(seen.isUnread('p1', said.first), isFalse);
      expect(seen.isUnread('p1', said.last), isTrue);
      // Dos veces la misma no es nada nuevo que guardar.
      expect(seen.markRead('p1', said.first), isFalse);
    });

    test('y cada pueblo lleva su propia cuenta', () {
      final una = _n(NoticeKind.hour, 'Casi siempre a las 8 de la mañana.');
      BoardSeen.instance.markRead('p1', una);
      expect(BoardSeen.instance.isUnread('p1', una), isFalse);
      expect(BoardSeen.instance.isUnread('p2', una), isTrue);
    });

    test('los bandos del pueblo no avisan de nada', () {
      // Son cuatrocientos treinta y seis rotando todos los días, y una cabra
      // perdida no es información sobre vos. Si contaran, el punto estaría
      // encendido siempre.
      final bando = _n(NoticeKind.pueblo, 'Se perdió una cabra.');
      expect(seenKey(bando), isEmpty);
      expect(BoardSeen.instance.isUnread('p1', bando), isFalse);
      expect(BoardSeen.instance.unread('p1', [bando]), 0);
      expect(BoardSeen.instance.markRead('p1', bando), isFalse);
    });

    test('una nota que cambia lo que dice vuelve a ser nueva', () {
      // Que el pueblo pase de «casi siempre a las ocho» a «casi siempre a las
      // seis» es algo que no sabías, y es de lo que tiene que avisar.
      final antes = _n(NoticeKind.hour, 'Casi siempre a las 8 de la mañana.');
      final ahora = _n(NoticeKind.hour, 'Casi siempre a las 6 de la mañana.');
      BoardSeen.instance.markRead('p1', antes);
      expect(BoardSeen.instance.isUnread('p1', ahora), isTrue);
    });

    test('pero las tres que se mueven solas avisan una vez y se callan', () {
      // La fecha de «queda en pie el trece» se corre con cada pieza, los días
      // de tu vida suben cada mañana y la cuenta de lo que repetís cambia con
      // cada leyenda. Si contaran por su texto, el punto no se apagaría nunca.
      for (final k in [NoticeKind.ahead, NoticeKind.life, NoticeKind.chore]) {
        BoardSeen.instance.forget();
        final hoy = _n(k, 'algo de hoy');
        final manana = _n(k, 'algo de mañana');
        expect(BoardSeen.instance.isUnread('p1', hoy), isTrue, reason: '$k');
        BoardSeen.instance.markRead('p1', hoy);
        expect(
          BoardSeen.instance.isUnread('p1', manana),
          isFalse,
          reason: '$k volvió a avisar por cambiar su propio número',
        );
      }
    });

    test('y lo leído sigue leído al volver a abrir la app', () async {
      // Un aviso que se olvida al cerrar avisa de lo mismo todos los días y
      // deja de querer decir nada.
      final una = _n(NoticeKind.week, 'Los martes son tu día fuerte.');
      BoardSeen.instance.markRead('el pueblo de bruno', una);
      await BoardSeen.instance.flush();

      BoardSeen.instance.forget();
      await BoardSeen.instance.load();
      expect(BoardSeen.instance.isUnread('el pueblo de bruno', una), isFalse);
      // Y no se confunde con otro pueblo cuyo nombre empiece igual.
      expect(BoardSeen.instance.isUnread('el pueblo', una), isTrue);
    });
  });
}
