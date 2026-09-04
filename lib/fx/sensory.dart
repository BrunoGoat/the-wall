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

  void setMuted(bool v) => _muted = v;
  void setHapticsOff(bool v) => _hapticsOff = v;

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
