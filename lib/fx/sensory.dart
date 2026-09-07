import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sound and haptics.
///
/// The whole point of the app is the moment a stone lands, so that moment gets
/// a layered response: a transient click, the weight of the stone, and a second
/// smaller haptic as it settles. Everything is best-effort — a device with no
/// vibrator or a blocked audio session must never break placing a brick.
class Sensory {
  Sensory._();
  static final Sensory instance = Sensory._();

  final List<AudioPlayer> _pool = [];
  int _cursor = 0;
  bool _ready = false;
  bool _muted = false;
  bool _hapticsOff = false;

  bool get muted => _muted;
  bool get hapticsOff => _hapticsOff;
  bool get musicOff => _musicOff;

  void setMuted(bool v) {
    _muted = v;
    for (var i = 0; i < _amb.length; i++) {
      try {
        _amb[i].setVolume(v ? 0 : _ambAt[i]);
      } catch (_) {}
    }
    _applyMusic();
  }

  void setHapticsOff(bool v) => _hapticsOff = v;

  /// La música aparte del resto del sonido: hay quien quiere el viento y los
  /// pájaros del valle y no quiere que le toquen nada encima.
  void setMusicOff(bool v) {
    _musicOff = v;
    _applyMusic();
  }

  // ---------------------------------------------------------------- music

  /// Tres capas en re dórico a sesenta pulsos por minuto: el bordón de
  /// zanfoña, el laúd punteado y una flauta. Se generan en `tool/make_music.py`.
  ///
  /// Las tres duran un número entero de compases del mismo pulso pero de
  /// largos distintos —seis, ocho y diez— así que caen siempre en el mismo
  /// sitio del compás y aun así la combinación no se repite igual hasta los
  /// ocho minutos. Como la armonía debajo es un bordón que no se mueve,
  /// cualquier desfase entre ellas suena bien. Es lo que hacía un juglar con
  /// una zanfoña: una nota que no para, y encima lo que se le ocurra.
  static const List<String> _music = [
    'mus_bordon.wav',
    'mus_laud.wav',
    'mus_flauta.wav',
  ];

  /// El sitio de cada capa en la mezcla, medido sobre el valor eficaz de cada
  /// archivo y no sobre su pico: los tres se escriben a escala completa para
  /// no tirar bits, y el equilibrio se pone aquí.
  static const List<double> _musMix = [0.193, 1.0, 0.231];

  /// Música de fondo quiere decir de fondo. Por debajo del viento.
  static const double _musLevel = 0.50;

  /// Qué se oye a cada hora, en el orden de arriba. De noche el bordón se
  /// queda casi solo con la flauta encima, que es lo que suena a noche; al
  /// mediodía manda el laúd, que es lo que suena a gente trabajando.
  static const List<double> _atNight = [1.00, 0.22, 0.50]; // las 3
  static const List<double> _atDawn = [0.85, 0.85, 0.80]; // las 8
  static const List<double> _atNoon = [0.70, 1.00, 0.65]; // las 14
  static const List<double> _atDusk = [0.90, 0.55, 0.90]; // las 20

  final List<AudioPlayer> _mus = [];
  final List<double> _musAt = [0, 0, 0];
  bool _musReady = false;
  bool _musicOff = false;

  /// La entrada. Nada debería empezar a sonar de golpe al abrir la app.
  double _musIn = 0;

  Future<void> _initMusic() async {
    if (_musReady) return;
    try {
      for (final name in _music) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
        await p.play(AssetSource('sfx/$name'));
        _mus.add(p);
      }
      _musReady = true;
    } catch (_) {
      _musReady = false;
    }
  }

  /// Interpola entre las cuatro horas de arriba dando la vuelta al reloj, con
  /// una curva suave: a las ocho y un minuto no puede sonar distinto que a las
  /// ocho menos uno.
  @visibleForTesting
  static List<double> dayMix(double hour) {
    const stops = [3.0, 8.0, 14.0, 20.0, 27.0];
    const mixes = [_atNight, _atDawn, _atNoon, _atDusk, _atNight];
    final h = hour < stops.first ? hour + 24 : hour;
    for (var i = 0; i < stops.length - 1; i++) {
      if (h > stops[i + 1]) continue;
      final k = ((h - stops[i]) / (stops[i + 1] - stops[i])).clamp(0.0, 1.0);
      final e = k * k * (3 - 2 * k);
      return [
        for (var j = 0; j < 3; j++)
          mixes[i][j] + (mixes[i + 1][j] - mixes[i][j]) * e,
      ];
    }
    return _atNight;
  }

  /// La mezcla de este instante. `hour` es la misma hora con la que se pinta
  /// el cielo, así que la música y la luz cambian juntas.
  Future<void> music(double hour, double dt, double integrity) async {
    if (!_musReady) return;
    if (_muted || _musicOff) return;
    _musIn = (_musIn + dt / 6.0).clamp(0.0, 1.0);
    final day = dayMix(hour);
    // Un pueblo dejado pierde parte de su música, pero no toda: el silencio
    // absoluto se lee como una app rota, no como un pueblo abandonado.
    final level =
        _musLevel * _musIn * (0.72 + 0.28 * integrity.clamp(0.0, 1.0));
    for (var i = 0; i < _mus.length && i < 3; i++) {
      final want = _musMix[i] * day[i] * level;
      // Constante de tiempo larga: pasar de la tarde a la noche es un cambio
      // de luz, no un cambio de canción.
      final next = _musAt[i] + (want - _musAt[i]) * (1 - math.exp(-dt / 2.5));
      if ((next - _musAt[i]).abs() < 0.003) continue;
      _musAt[i] = next;
      try {
        await _mus[i].setVolume(next);
      } catch (_) {}
    }
  }

  void _applyMusic() {
    final off = _muted || _musicOff;
    for (var i = 0; i < _mus.length; i++) {
      try {
        if (off) {
          _mus[i].pause();
        } else {
          _mus[i].setVolume(_musAt[i]);
          _mus[i].resume();
        }
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------- ambience

  /// The three layers of the valley's own noise. They stack rather than swap:
  /// the field is always there, the town murmur comes in as the place grows,
  /// and the busy layer only once it is both big and lived in.
  static const List<String> _layers = [
    'amb_field.wav',
    'amb_town.wav',
    'amb_life.wav',
  ];
  final List<AudioPlayer> _amb = [];
  final List<double> _ambAt = [0, 0, 0];
  bool _ambReady = false;

  /// One-shots, and which of them belong to a town that is doing well.
  static const List<String> _alive = ['bell.wav', 'cock.wav'];
  static const List<String> _empty = ['crow.wav', 'creak.wav'];
  double _sinceOneShot = 0;

  Future<void> _initAmbience() async {
    if (_ambReady) return;
    try {
      for (final name in _layers) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
        await p.play(AssetSource('sfx/$name'));
        _amb.add(p);
      }
      _ambReady = true;
    } catch (_) {
      _ambReady = false;
    }
  }

  /// How loud the valley is, from how big and how lit the town in front of you
  /// is.
  ///
  /// A big, kept-up town is a place with people in it and sounds like one. A
  /// small or abandoned one is not silent — that would read as broken — it just
  /// keeps the wind and loses the voices, which is what nobody home sounds
  /// like.
  Future<void> ambience(double size01, double integrity) async {
    if (!_ambReady || _muted) {
      if (_muted) {
        for (final p in _amb) {
          try {
            await p.setVolume(0);
          } catch (_) {}
        }
      }
      return;
    }
    final life = size01.clamp(0.0, 1.0) * (0.35 + 0.65 * integrity);
    final want = [
      0.30 + 0.10 * (1 - life),
      0.46 * _ramp(life, 0.08, 0.55),
      0.40 * _ramp(life, 0.42, 0.95),
    ];
    for (var i = 0; i < _amb.length && i < want.length; i++) {
      // Eased, so walking between two towns is a change of place rather than a
      // switch being thrown.
      final next = _ambAt[i] + (want[i] - _ambAt[i]) * 0.10;
      if ((next - _ambAt[i]).abs() < 0.004) continue;
      _ambAt[i] = next;
      try {
        await _amb[i].setVolume(next);
      } catch (_) {}
    }
  }

  static double _ramp(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  /// Every so often, one sound that says what kind of place this is.
  void ambientOneShot(double dt, double size01, double integrity) {
    if (_muted || !_ready) return;
    _sinceOneShot += dt;
    // Busy towns speak up often; a quiet one only now and then.
    final gap = 26.0 - 16.0 * size01.clamp(0.0, 1.0) * integrity;
    if (_sinceOneShot < gap) return;
    _sinceOneShot = 0;
    final alive = integrity > 0.6 && size01 > 0.10;
    final pool = alive ? _alive : _empty;
    final pick = pool[DateTime.now().microsecond % pool.length];
    _play(pick, volume: alive ? 0.30 : 0.24);
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(p);
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    await _initAmbience();
    await _initMusic();
  }

  Future<void> _play(String asset, {double volume = 1.0}) async {
    if (_muted || !_ready || _pool.isEmpty) return;
    try {
      final p = _pool[_cursor];
      _cursor = (_cursor + 1) % _pool.length;
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource('sfx/$asset'));
    } catch (_) {
      // Audio is a bonus, never a requirement.
    }
  }

  void _haptic(void Function() f) {
    if (_hapticsOff) return;
    try {
      f();
    } catch (_) {}
  }

  /// The instant the finger goes down: light, immediate acknowledgement.
  void press() {
    _haptic(HapticFeedback.selectionClick);
  }

  /// A tick as the hold builds. It gets firmer the closer the stone is to
  /// going up, so the charge can be felt without looking.
  void charge(double progress) {
    if (progress >= 0.99) return; // the impact itself covers the last one
    _haptic(
      progress > 0.7
          ? HapticFeedback.mediumImpact
          : HapticFeedback.selectionClick,
    );
  }

  /// The stone hits. This is the payoff.
  void impact({double strength = 1.0}) {
    _play('place.wav', volume: (0.65 + 0.35 * strength).clamp(0.0, 1.0));
    _haptic(HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 78), () {
      _haptic(HapticFeedback.mediumImpact);
    });
  }

  void epic() {
    _play('epic.wav', volume: 0.9);
    _haptic(HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 120), () {
      _haptic(HapticFeedback.mediumImpact);
    });
    Future.delayed(const Duration(milliseconds: 240), () {
      _haptic(HapticFeedback.lightImpact);
    });
  }

  void milestone() {
    _play('milestone.wav', volume: 0.85);
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 90 * i), () {
        _haptic(HapticFeedback.mediumImpact);
      });
    }
  }

  void repair() {
    _play('repair.wav', volume: 0.7);
    _haptic(HapticFeedback.lightImpact);
  }

  void tick() {
    _play('tap.wav', volume: 0.45);
    _haptic(HapticFeedback.selectionClick);
  }

  void dispose() {
    for (final p in [..._pool, ..._amb, ..._mus]) {
      p.dispose();
    }
    _pool.clear();
    _amb.clear();
    _mus.clear();
    _ready = false;
    _ambReady = false;
    _musReady = false;
  }
}
