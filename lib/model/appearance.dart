import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the wall is pointed: how much mortar shows between the stones, how deep
/// it sits, and how far each stone stands proud of its neighbours.
enum MortarStyle { viva, rehundida, fina, enrasada, seca }

/// One way of pointing the masonry.
class MortarLook {
  const MortarLook({
    required this.style,
    required this.name,
    required this.blurb,
    required this.joint,
    required this.tint,
    required this.recess,
    required this.relief,
  });

  final MortarStyle style;
  final String name;
  final String blurb;

  /// How far each stone is cut back inside its own slot. The gap left is the
  /// joint, and the mortar behind is what shows through it.
  final double joint;

  /// How far the mortar's colour is pulled towards the stone's. At 1 it is the
  /// same tone and the joints stop reading as mortar at all.
  final double tint;

  /// How far behind the face of the stone the mortar sits.
  final double recess;

  /// How much each stone stands out from the wall's face.
  final double relief;

  static const MortarLook viva = MortarLook(
    style: MortarStyle.viva,
    name: 'Junta viva',
    blurb: 'El mortero se ve entre piedra y piedra, como estaba.',
    joint: 0.006,
    tint: 0.62,
    recess: 0.07,
    relief: 1.0,
  );

  static const List<MortarLook> all = [
    viva,
    MortarLook(
      style: MortarStyle.rehundida,
      name: 'Junta rehundida',
      blurb: 'El mortero muy metido hacia adentro: cada piedra queda '
          'recortada por su propia sombra.',
      joint: 0.010,
      tint: 0.52,
      recess: 0.15,
      relief: 1.35,
    ),
    MortarLook(
      style: MortarStyle.fina,
      name: 'Junta fina',
      blurb: 'Menos mortero y más piedra. La junta queda como una línea.',
      joint: 0.003,
      tint: 0.78,
      recess: 0.05,
      relief: 0.85,
    ),
    MortarLook(
      style: MortarStyle.enrasada,
      name: 'Junta enrasada',
      blurb: 'Mortero al ras y del mismo tono que la piedra: las juntas son '
          'sólo sombra.',
      joint: 0.003,
      tint: 0.93,
      recess: 0.02,
      relief: 0.5,
    ),
    MortarLook(
      style: MortarStyle.seca,
      name: 'Piedra seca',
      blurb: 'Sin mortero. Las piedras se calzan unas contra otras.',
      joint: 0.001,
      tint: 1.0,
      recess: 0.01,
      relief: 1.1,
    ),
  ];

  static MortarLook of(MortarStyle s) =>
      all.firstWhere((l) => l.style == s, orElse: () => all.first);
}

/// What the wall looks like. Kept apart from what the wall *is*: changing any
/// of this never touches a brick.
class Appearance extends ChangeNotifier {
  Appearance._();
  static final Appearance instance = Appearance._();

  static const String _key = 'muralla_mortar_v1';

  MortarStyle _mortar = MortarStyle.viva;

  MortarStyle get mortar => _mortar;
  MortarLook get look => MortarLook.of(_mortar);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        for (final l in MortarLook.all) {
          if (l.style.name == saved) _mortar = l.style;
        }
      }
    } catch (_) {
      // A phone that will not give us its preferences still gets a wall.
    }
    notifyListeners();
  }

  Future<void> setMortar(MortarStyle s) async {
    if (s == _mortar) return;
    _mortar = s;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, s.name);
    } catch (_) {}
  }
}
