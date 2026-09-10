import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/rng.dart';
import 'findings.dart';

/// Dónde quedó clavado cada papel, para siempre.
///
/// Un tablón de plaza no está ordenado: la gente clava donde hay hueco, y por
/// eso un papel acaba arriba a la izquierda y el siguiente abajo en el medio.
/// Pero lo que sí hace un tablón de verdad es no mover nada. Un papel que
/// alguien clavó en un sitio se queda en ese sitio hasta que lo descuelgan, y
/// eso es justo lo que un reparto calculado al vuelo no puede prometer: en
/// cuanto cambia lo que hay que clavar, se recoloca todo y el tablón deja de
/// ser un sitio para volver a ser una lista barajada.
///
/// Así que el hueco se sortea **una sola vez**, cuando el papel aparece, y
/// desde entonces se guarda. Al volver a abrir el tablón —o al reinstalar la
/// app y recuperar el valle— cada papel sigue donde estaba.
class BoardSlots {
  BoardSlots._();
  static final BoardSlots instance = BoardSlots._();

  static const String _key = 'pueblo_tablon_v1';

  /// `pueblo/papel` → hueco. Una sola tabla para todo el valle: dos pueblos no
  /// comparten papeles porque la clave lleva delante de qué pueblo es.
  final Map<String, int> _where = {};

  /// Cuántas filas se guardan como mucho.
  ///
  /// Con ocho notas posibles y treinta y seis bandos, un valle de seis pueblos
  /// no llega ni de lejos. El tope está para que un fallo que invente claves
  /// no crezca sin fin, no porque se espere alcanzarlo.
  static const int _cap = 400;

  Future<void> load() async {
    _where.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final row in prefs.getStringList(_key) ?? const <String>[]) {
        final at = row.lastIndexOf('=');
        if (at <= 0) continue;
        final slot = int.tryParse(row.substring(at + 1));
        if (slot != null && slot >= 0) _where[row.substring(0, at)] = slot;
      }
    } catch (_) {
      // Un teléfono que no da sus preferencias reparte el tablón de nuevo, que
      // es peor que recordarlo pero mucho mejor que no tener tablón.
    }
  }

  /// En qué hueco va cada una de [said], en el mismo orden.
  ///
  /// Las que ya tienen sitio lo reclaman primero, así que un papel nuevo nunca
  /// desplaza a uno viejo: sólo ocupa lo que quedó libre. Cuando dos papeles
  /// guardados piden el mismo hueco —sólo puede pasar si algo se guardó mal—
  /// gana el primero y el otro se vuelve a sortear.
  List<int> assign(String townId, List<Notice> said, {required int slots}) {
    final out = List<int>.filled(said.length, -1);
    final taken = <int>{};
    final ids = [for (final n in said) '$townId/${noticeId(n)}'];

    for (var i = 0; i < said.length && i < slots; i++) {
      final had = _where[ids[i]];
      if (had != null && had < slots && taken.add(had)) out[i] = had;
    }
    var nuevo = false;
    for (var i = 0; i < said.length && i < slots; i++) {
      if (out[i] >= 0) continue;
      final hueco = _free(ids[i], taken, slots);
      out[i] = hueco;
      taken.add(hueco);
      _where[ids[i]] = hueco;
      nuevo = true;
    }
    if (nuevo) _keep();
    return out;
  }

  /// El hueco que le toca a un papel que se clava hoy por primera vez.
  ///
  /// Se sortea de su propio nombre, y desde ahí se va probando a saltos de un
  /// paso que no divide al número de huecos: así se recorren todos y no se
  /// amontonan a la derecha del primer intento, que es lo que pasa cuando se
  /// prueba de uno en uno.
  static int _free(String id, Set<int> taken, int slots) {
    final semilla = stableHash(id);
    final paso = _steps[hashInt(_steps.length, semilla, 1)];
    var at = hashInt(slots, semilla, 2);
    for (var k = 0; k < slots; k++) {
      if (!taken.contains(at)) return at;
      at = (at + paso) % slots;
    }
    return 0;
  }

  /// Pasos primos con diez, que es el número de huecos del tablón.
  static const List<int> _steps = [1, 3, 7, 9];

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
      final rows = _where.entries.map((e) => '${e.key}=${e.value}').toList();
      if (rows.length > _cap) rows.removeRange(0, rows.length - _cap);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, rows);
    } catch (_) {}
  }

  /// Para los tests: empezar con el tablón en blanco.
  void forget() => _where.clear();
}

/// Cómo se llama un papel, para poder acordarse de dónde se clavó.
///
/// Las notas de verdad se llaman por su clase, porque hay como mucho una de
/// cada: la del horario es *la* del horario, diga hoy las siete y mañana las
/// ocho, y mueve su texto sin moverse de la pared. Los bandos del pueblo no
/// tienen clase propia —son treinta y seis— así que se llaman por lo que
/// dicen, y por eso el bando de la cabra vuelve siempre al mismo sitio.
String noticeId(Notice n) =>
    n.kind == NoticeKind.pueblo ? 'v${stableHash(n.said)}' : n.kind.name;

/// Un número a partir de un texto, igual en cualquier aparato y en cualquier
/// arranque. `String.hashCode` no sirve: no promete ser el mismo dos veces, y
/// aquí lo que se guarda en el disco tiene que valer mañana.
int stableHash(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = hash32(h, s.codeUnitAt(i));
  }
  return h;
}
