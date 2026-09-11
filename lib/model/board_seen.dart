import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'findings.dart';

/// Qué notas del tablón ya leíste.
///
/// El tablón se mira de vez en cuando, y lo que tiene escrito cambia solo: un
/// día el pueblo se da cuenta de a qué hora aparecés, y ese papel lleva ahí
/// desde la semana pasada sin que nadie haya entrado a leerlo. Esto es lo que
/// hace que se sepa desde fuera que hay algo nuevo.
///
/// Se guarda porque es lo único que tiene sentido: un aviso que se olvida al
/// cerrar la app avisa de lo mismo todos los días y deja de querer decir nada.
class BoardSeen {
  BoardSeen._();
  static final BoardSeen instance = BoardSeen._();

  static const String _key = 'pueblo_visto_v1';

  /// Pueblo -> lo que ya se leyó de él, por su clave.
  final Map<String, Set<String>> _read = {};

  /// Cuántas claves se guardan por pueblo.
  ///
  /// Con nueve clases de nota y unas pocas versiones de cada una, un pueblo que
  /// lleve años no pasa de unas decenas. El tope está para que una clave que
  /// cambie más de lo que debería no haga crecer esto sin fin.
  static const int _cap = 60;

  /// El separador entre el pueblo y la clave. Un carácter de control, porque
  /// los dos lados son texto escrito por gente —el nombre de un pueblo y una
  /// frase entera— y cualquier signo normal aparece antes o después dentro de
  /// uno de los dos.
  static const String _sep = '\u0001';

  Future<void> load() async {
    _read.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final row in prefs.getStringList(_key) ?? const <String>[]) {
        final at = row.indexOf(_sep);
        if (at <= 0) continue;
        _read
            .putIfAbsent(row.substring(0, at), () => <String>{})
            .add(row.substring(at + 1));
      }
    } catch (_) {
      // Un teléfono que no da sus preferencias enseña el punto una vez de más.
    }
  }

  /// Cuántas de [said] no se han leído todavía en [townId].
  int unread(String townId, List<Notice> said) {
    final ya = _read[townId];
    var n = 0;
    for (final key in said.map(seenKey)) {
      if (key.isEmpty) continue;
      if (ya == null || !ya.contains(key)) n++;
    }
    return n;
  }

  bool isUnread(String townId, Notice n) {
    final key = seenKey(n);
    if (key.isEmpty) return false;
    return !(_read[townId]?.contains(key) ?? false);
  }

  /// Dar una por leída. Devuelve si había algo que marcar, para que quien
  /// llama sepa si hace falta repintar.
  bool markRead(String townId, Notice n) {
    final key = seenKey(n);
    if (key.isEmpty) return false;
    final ya = _read.putIfAbsent(townId, () => <String>{});
    if (!ya.add(key)) return false;
    _keep();
    return true;
  }

  Timer? _soon;

  void _keep() {
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Escribe ya lo que hubiera pendiente.
  Future<void> flush() async {
    _soon?.cancel();
    _soon = null;
    try {
      final rows = <String>[];
      for (final MapEntry(key: town, value: keys) in _read.entries) {
        final list = keys.toList();
        if (list.length > _cap) list.removeRange(0, list.length - _cap);
        for (final k in list) {
          rows.add('$town$_sep$k');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, rows);
    } catch (_) {}
  }

  /// Para los tests: empezar sin haber leído nada.
  void forget() => _read.clear();
}

/// Cómo se llama una nota a efectos de «esto ya lo leí».
///
/// No es lo mismo que el nombre con el que se acuerda de su hueco en la
/// plancha. Ahí lo que importa es que la nota del horario sea *la* del horario
/// y no se mueva de la pared aunque hoy diga las siete y mañana las ocho. Aquí
/// lo que importa es si lo que dice es algo que ya sabías, y que cambie de las
/// siete a las ocho sí es algo que no sabías.
///
/// Con tres excepciones, que son las que se mueven solas. La fecha de «queda
/// en pie el trece» se corre con cada pieza que ponés; los días de tu vida
/// suben cada mañana; y la cuenta de lo que repetís cambia en cuanto escribís
/// una leyenda más. Si ésas contaran por su texto, el punto estaría encendido
/// siempre y dejaría de querer decir nada: de ésas se avisa cuando aparecen, y
/// una sola vez.
///
/// Los bandos del pueblo no avisan: una cabra perdida no es información sobre
/// vos, y son cuatrocientos treinta y seis rotando todos los días.
String seenKey(Notice n) => switch (n.kind) {
  NoticeKind.pueblo => '',
  NoticeKind.ahead || NoticeKind.life || NoticeKind.chore => n.kind.name,
  _ => '${n.kind.name}|${n.said}',
};
