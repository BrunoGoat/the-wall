import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tunes.dart';

/// The handful of things about the app that are a preference rather than a
/// record of what you did.
///
/// Sound lives here rather than inside the thing that makes it, and that is
/// deliberate: what somebody chose is a preference and belongs with the other
/// preferences, where it gets written down. It used to live in `Sensory` as
/// two loose booleans, which meant that turning the sound off lasted exactly
/// as long as the app stayed open.
class Appearance extends ChangeNotifier {
  Appearance._();
  static final Appearance instance = Appearance._();

  static const String _rapidKey = 'pueblo_rapid_v1';
  static const String _soundKey = 'pueblo_sound_v1';

  bool _rapid = false;

  /// Testing aid: holding the button keeps laying pieces instead of stopping
  /// at one, so a town long enough to judge can be built in a minute. Off by
  /// default and deliberately awkward to leave on — a piece is an achievement,
  /// and this is the one place in the app where that is not true.
  bool get rapid => _rapid;

  // --------------------------------------------------------------- el sonido

  bool _soundOff = false;
  bool _musicOff = false;
  bool _effectsOff = false;
  bool _hapticsOff = false;

  /// Half, and half is what the app shipped sounding like. Anything the person
  /// does from here is measured against what they already know.
  static const double _midway = 0.5;
  double _musicVolume = _midway;
  double _effectsVolume = _midway;

  /// Which single sounds have been silenced, by the ids in
  /// `Sensory.catalogue`. Everything else stays on: this is a list of
  /// exceptions, so a sound added later is heard rather than quietly missing.
  final Set<String> _hushed = <String>{};

  /// Qué piezas entran en el sorteo de cada apertura.
  ///
  /// Vacío quiere decir todas, y eso es a propósito por dos motivos. Uno, que
  /// una instalación nueva las oiga todas antes de tener que elegir. Y dos,
  /// que quedarse sin ninguna no es un estado que tenga sentido: quien no
  /// quiere música tiene el interruptor de la música justo arriba, así que
  /// apagar la última es casi siempre un dedo que se fue, no una decisión.
  final Set<String> _rotation = <String>{};

  bool inRotation(String id) => _rotation.isEmpty || _rotation.contains(id);

  /// Cuántas hay elegidas de verdad, para poder decirlo en la pantalla.
  int get rotation => _rotation.isEmpty ? tunes.length : _rotation.length;

  Future<void> setRotation(String id, bool on) async {
    // Vacío es «todas», así que quitar la primera hay que escribirlo como
    // «todas menos ésta» y no como un conjunto de una.
    if (_rotation.isEmpty) _rotation.addAll(tunes.map((t) => t.id));
    if (on ? !_rotation.add(id) : !_rotation.remove(id)) return;
    // Y si se quedó sin ninguna, vuelve a querer decir todas.
    if (_rotation.length >= tunes.length) _rotation.clear();
    await _keep();
  }

  /// The one switch that covers everything, music included.
  bool get soundOff => _soundOff;
  bool get musicOff => _musicOff;
  bool get effectsOff => _effectsOff;
  bool get hapticsOff => _hapticsOff;
  double get musicVolume => _musicVolume;
  double get effectsVolume => _effectsVolume;

  /// Whether this particular sound is allowed to make a noise right now.
  bool hears(String id) => !_soundOff && !_effectsOff && !_hushed.contains(id);
  bool isHushed(String id) => _hushed.contains(id);

  /// Whether the music is allowed to play at all.
  bool get hearsMusic => !_soundOff && !_musicOff;

  /// Todo como salió de fábrica.
  ///
  /// Leer no es mezclar con lo que hubiera: sin esto, un arranque que no
  /// encuentra nada guardado se queda con lo que hubiese en memoria de antes,
  /// que en la app es sólo el primer arranque pero en cualquier otro sitio
  /// —un test, un reinicio en caliente— es basura del anterior.
  void _forgetSound() {
    _soundOff = false;
    _musicOff = false;
    _effectsOff = false;
    _hapticsOff = false;
    _musicVolume = _midway;
    _effectsVolume = _midway;
    _hushed.clear();
    _rotation.clear();
  }

  Future<void> load() async {
    _forgetSound();
    try {
      final prefs = await SharedPreferences.getInstance();
      _rapid = prefs.getBool(_rapidKey) ?? false;
      final saved = prefs.getStringList(_soundKey);
      if (saved != null) _readSound(saved);
    } catch (_) {
      // A phone that will not give us its preferences still gets a town.
    }
    notifyListeners();
  }

  /// Written as a plain list of `key=value`, so a setting added later reads
  /// back as its default instead of throwing the whole lot away.
  void _readSound(List<String> rows) {
    for (final row in rows) {
      final at = row.indexOf('=');
      if (at <= 0) continue;
      final key = row.substring(0, at), value = row.substring(at + 1);
      switch (key) {
        case 'sound':
          _soundOff = value == '0';
        case 'music':
          _musicOff = value == '0';
        case 'effects':
          _effectsOff = value == '0';
        case 'haptics':
          _hapticsOff = value == '0';
        case 'musicVol':
          _musicVolume = (double.tryParse(value) ?? _midway).clamp(0.0, 1.0);
        case 'effectsVol':
          _effectsVolume = (double.tryParse(value) ?? _midway).clamp(0.0, 1.0);
        case 'hushed':
          _hushed
            ..clear()
            ..addAll(value.split(',').where((s) => s.isNotEmpty));
        case 'tunes':
          _rotation
            ..clear()
            ..addAll(value.split(',').where((s) => s.isNotEmpty));
      }
    }
  }

  List<String> _writeSound() => [
    'sound=${_soundOff ? 0 : 1}',
    'music=${_musicOff ? 0 : 1}',
    'effects=${_effectsOff ? 0 : 1}',
    'haptics=${_hapticsOff ? 0 : 1}',
    'musicVol=$_musicVolume',
    'effectsVol=$_effectsVolume',
    'hushed=${_hushed.join(',')}',
    'tunes=${_rotation.join(',')}',
  ];

  Timer? _writeSoon;

  /// The screen hears about it at once; the disk hears about it when the
  /// finger comes off. Dragging a volume slider changes this sixty times a
  /// second, and sixty writes a second to the phone's own storage is a way to
  /// make a slider feel broken.
  Future<void> _keep() async {
    notifyListeners();
    _writeSoon?.cancel();
    _writeSoon = Timer(const Duration(milliseconds: 400), _writeNow);
  }

  Future<void> _writeNow() async {
    _writeSoon?.cancel();
    _writeSoon = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_soundKey, _writeSound());
    } catch (_) {}
  }

  /// Writes whatever is pending right now. For leaving the app: a preference
  /// changed a tenth of a second before it went into the background is still
  /// a preference somebody chose.
  Future<void> flush() => _writeNow();

  Future<void> setSoundOff(bool v) async {
    if (v == _soundOff) return;
    _soundOff = v;
    await _keep();
  }

  Future<void> setMusicOff(bool v) async {
    if (v == _musicOff) return;
    _musicOff = v;
    await _keep();
  }

  Future<void> setEffectsOff(bool v) async {
    if (v == _effectsOff) return;
    _effectsOff = v;
    await _keep();
  }

  Future<void> setHapticsOff(bool v) async {
    if (v == _hapticsOff) return;
    _hapticsOff = v;
    await _keep();
  }

  Future<void> setMusicVolume(double v) async {
    final want = v.clamp(0.0, 1.0);
    if (want == _musicVolume) return;
    _musicVolume = want;
    await _keep();
  }

  Future<void> setEffectsVolume(double v) async {
    final want = v.clamp(0.0, 1.0);
    if (want == _effectsVolume) return;
    _effectsVolume = want;
    await _keep();
  }

  Future<void> hush(String id, bool quiet) async {
    if (quiet ? !_hushed.add(id) : !_hushed.remove(id)) return;
    await _keep();
  }

  Future<void> setRapid(bool v) async {
    if (v == _rapid) return;
    _rapid = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rapidKey, v);
    } catch (_) {}
  }
}
