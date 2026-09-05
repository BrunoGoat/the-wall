import 'package:audioplayers/audioplayers.dart';
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

  void setMuted(bool v) {
    _muted = v;
    for (final p in _amb) {
      try {
        p.setVolume(v ? 0 : _ambAt[_amb.indexOf(p)]);
      } catch (_) {}
    }
  }
  void setHapticsOff(bool v) => _hapticsOff = v;

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
    _haptic(progress > 0.7
        ? HapticFeedback.mediumImpact
        : HapticFeedback.selectionClick);
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
    for (final p in _pool) {
      p.dispose();
    }
    _pool.clear();
    _ready = false;
  }
}
