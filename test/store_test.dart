import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/piece.dart';
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
      expect(s.pieceAt(0)!.hasLabel, isFalse,
          reason: 'blank should clear the note, not store whitespace');
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
      SharedPreferences.setMockInitialValues(
          {'flutter.la_muralla_state_v2': 'not json at all'});
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
        s.pieces.add(Piece(
          index: s.total,
          placedAt: today.subtract(Duration(days: offset, hours: -12)),
        ));
      }
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });
  });
}
