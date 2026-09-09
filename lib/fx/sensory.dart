import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/appearance.dart';

/// Which family a sound belongs to, for listing them in an order that means
/// something to somebody looking for one to switch off.
enum Sounds {
  /// Made by something you did.
  doing,

  /// The valley speaking up on its own: a bell, a cockerel, a crow.
  valley,

  /// The three loops the place itself is made of.
  air,
}

/// One noise, with a name a person would recognise it by.
class SoundBite {
  const SoundBite(this.id, this.file, this.name, this.level, this.of);

  /// Never changes: it is what a silenced sound is written down as.
  final String id;
  final String file;
  final String name;

  /// How loud this one is relative to the others, before the slider.
  final double level;
  final Sounds of;
}

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

  /// What is on, what is off and how loud, all of it read from the one place
  /// the app writes preferences down. It used to be two booleans held right
  /// here, which is why turning the sound off lasted until you closed the app.
  Appearance get _wants => Appearance.instance;

  /// Everything this app can make a noise with, by name.
  ///
  /// A catalogue rather than file names scattered through the code, because
  /// every one of these can now be silenced on its own and listened to on
  /// demand, and both of those need something to point at.
  static const List<SoundBite> catalogue = [
    SoundBite('place', 'place.wav', 'Poner una pieza', 0.72, Sounds.doing),
    SoundBite('tap', 'tap.wav', 'Toque', 0.45, Sounds.doing),
    SoundBite('repair', 'repair.wav', 'Reparar', 0.70, Sounds.doing),
    SoundBite(
      'milestone',
      'milestone.wav',
      'Obra terminada',
      0.85,
      Sounds.doing,
    ),
    SoundBite('epic', 'epic.wav', 'Hito del pueblo', 0.90, Sounds.doing),
    SoundBite('bell', 'bell.wav', 'Campana', 0.30, Sounds.valley),
    SoundBite('cock', 'cock.wav', 'Gallo', 0.30, Sounds.valley),
    SoundBite('crow', 'crow.wav', 'Cuervo', 0.24, Sounds.valley),
    SoundBite('creak', 'creak.wav', 'Gozne', 0.24, Sounds.valley),
    SoundBite(
      'amb_field',
      'amb_field.wav',
      'Viento y pájaros',
      0.40,
      Sounds.air,
    ),
    SoundBite(
      'amb_town',
      'amb_town.wav',
      'Murmullo del pueblo',
      0.46,
      Sounds.air,
    ),
    SoundBite('amb_life', 'amb_life.wav', 'Día de mercado', 0.40, Sounds.air),
  ];

  static SoundBite? biteOf(String id) {
    for (final b in catalogue) {
      if (b.id == id) return b;
    }
    return null;
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
  /// Half the slider is what the app has always sounded like.
  double get _musLevel => _wants.musicVolume;

  /// Qué se oye a cada hora, en el orden de arriba. De noche el bordón se
  /// queda casi solo con la flauta encima, que es lo que suena a noche; al
  /// mediodía manda el laúd, que es lo que suena a gente trabajando.
  static const List<double> _atNight = [1.00, 0.22, 0.50]; // las 3
  static const List<double> _atDawn = [0.85, 0.85, 0.80]; // las 8
  static const List<double> _atNoon = [0.70, 1.00, 0.65]; // las 14
  static const List<double> _atDusk = [0.90, 0.55, 0.90]; // las 20

  final List<AudioPlayer> _mus = [];
  final List<double> _musAt = [0, 0, 0];

  /// Lo último que se le dijo de verdad a cada reproductor. El volumen que
  /// queremos y el volumen que ya mandamos son dos cosas distintas, y
  /// confundirlas es lo que dejó la música en silencio: si el que se ahorra la
  /// llamada es el mismo `if` que guarda el estado, un volumen que sube
  /// despacio no sube nunca.
  final List<double> _musSent = [0, 0, 0];
  bool _musReady = false;

  /// La entrada. Nada debería empezar a sonar de golpe al abrir la app.
  double _musIn = 0;

  /// An hour to pretend it is, for listening to the mix of a moment that is
  /// not now. Null means the real clock, which is what it is for everybody who
  /// is not standing in the settings screen holding the slider.
  double? _hourOverride;

  double? get hourOverride => _hourOverride;

  void pretendItIs(double? hour) {
    _hourOverride = hour;
    // Straight there rather than eased: this is a tool for comparing two
    // moments, and a tool that takes ten seconds to answer is not one.
    if (hour == null) return;
    final day = dayMix(hour);
    final level = _musLevel * (_musIn <= 0 ? 1 : _musIn);
    for (var i = 0; i < _mus.length && i < 3; i++) {
      _musAt[i] = _musMix[i] * day[i] * level;
      _musSent[i] = _musAt[i];
      try {
        _mus[i].setVolume(_musAt[i].clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  /// What each layer is playing at right now, for showing it.
  List<double> get heard => List.unmodifiable(_musAt);

  Future<void> _initMusic() async {
    if (_musReady) return;
    // One at a time, each on its own: a layer that will not start is one
    // layer missing, not three. It used to be a single try around the loop,
    // so the first failure took the whole piece with it and said nothing.
    for (final name in _music) {
      try {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
        await p.play(AssetSource('sfx/$name'));
        _mus.add(p);
      } catch (_) {
        _mus.add(AudioPlayer());
      }
    }
    _musReady = _mus.isNotEmpty;
  }

  /// Interpola entre las cuatro horas de arriba dando la vuelta al reloj, con
  /// una curva suave: a las ocho y un minuto no puede sonar distinto que a las
  /// ocho menos uno.
  /// Not only for tests any more: the settings screen shows this, so somebody
  /// can hear what four in the morning sounds like without waiting for it.
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
    if (_asleep || !_wants.hearsMusic) return;
    _musIn = (_musIn + dt / 6.0).clamp(0.0, 1.0);
    final day = dayMix(_hourOverride ?? hour);
    // Un pueblo dejado pierde parte de su música, pero no toda: el silencio
    // absoluto se lee como una app rota, no como un pueblo abandonado.
    final level =
        _musLevel * _musIn * (0.72 + 0.28 * integrity.clamp(0.0, 1.0));
    final want = [for (var i = 0; i < 3; i++) _musMix[i] * day[i] * level];
    for (var i = 0; i < _mus.length && i < 3; i++) {
      // El estado se mueve siempre, con o sin llamada.
      _musAt[i] = approach(_musAt[i], want[i], dt);
      if (!worthSending(_musAt[i], _musSent[i], want[i])) continue;
      _musSent[i] = _musAt[i];
      try {
        await _mus[i].setVolume(_musAt[i]);
      } catch (_) {}
    }
  }

  /// Un fotograma de subida hacia el volumen que toca.
  ///
  /// Constante de tiempo larga: pasar de la tarde a la noche es un cambio de
  /// luz, no un cambio de canción.
  @visibleForTesting
  static double approach(double at, double want, double dt) =>
      at + (want - at) * (1 - math.exp(-dt / 2.5));

  /// Si vale la pena gastar una llamada al reproductor por este cambio.
  ///
  /// Sólo eso. No decide si el volumen sube — el volumen sube igual — porque
  /// mezclar las dos preguntas es exactamente lo que apagó la música: a
  /// sesenta fotogramas por segundo el paso de una capa que va hacia 0,08 es
  /// de cinco diezmilésimas, y un umbral que además se tragaba el estado la
  /// dejaba en cero para siempre.
  @visibleForTesting
  static bool worthSending(double at, double sent, double want) {
    final drift = (at - sent).abs();
    // Ha cambiado lo bastante como para que se oiga.
    if (drift >= 0.002) return true;
    // O ya llegó a donde iba y lo último que se mandó todavía no era esto:
    // una llamada más, y a partir de ahí ninguna.
    return (at - want).abs() < 0.0005 && drift > 0.0005;
  }

  /// Brings every loop into line with what the person asked for, and with
  /// whether the app is even on screen. Pausing rather than turning down: a
  /// paused player costs nothing, and a phone in a pocket should be quiet.
  void settle() {
    final musicOff = _asleep || !_wants.hearsMusic;
    for (var i = 0; i < _mus.length; i++) {
      try {
        if (musicOff) {
          _mus[i].pause();
        } else {
          _mus[i].setVolume(_musAt[i].clamp(0.0, 1.0));
          _musSent[i] = _musAt[i];
          _mus[i].resume();
        }
      } catch (_) {}
    }
    for (var i = 0; i < _amb.length; i++) {
      final off = _asleep || !_wants.hears(_layers[i]);
      try {
        if (off) {
          _amb[i].pause();
        } else {
          _amb[i].resume();
        }
      } catch (_) {}
    }
  }

  /// True while the app is not the thing on screen.
  bool _asleep = false;
  bool get asleep => _asleep;

  /// Leaving the app should stop the sound, and coming back should start it
  /// again — without having to throw the app out of the recents list, which is
  /// what it took before anybody was listening for this.
  void sleep() {
    if (_asleep) return;
    _asleep = true;
    settle();
  }

  void wake() {
    if (!_asleep) return;
    _asleep = false;
    settle();
  }

  // ------------------------------------------------------------- ambience

  /// The three layers of the valley's own noise. They stack rather than swap:
  /// the field is always there, the town murmur comes in as the place grows,
  /// and the busy layer only once it is both big and lived in.
  static const List<String> _layers = ['amb_field', 'amb_town', 'amb_life'];
  final List<AudioPlayer> _amb = [];
  final List<double> _ambAt = [0, 0, 0];
  final List<double> _ambSent = [0, 0, 0];
  bool _ambReady = false;

  /// One-shots, and which of them belong to a town that is doing well.
  static const List<String> _alive = ['bell', 'cock'];
  static const List<String> _empty = ['crow', 'creak'];
  double _sinceOneShot = 0;

  Future<void> _initAmbience() async {
    if (_ambReady) return;
    // One at a time, for the same reason as the music: a layer that will not
    // start is one layer missing, not all of them.
    for (final name in _layers) {
      try {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
        await p.play(AssetSource('sfx/${biteOf(name)!.file}'));
        _amb.add(p);
      } catch (_) {
        _amb.add(AudioPlayer());
      }
    }
    _ambReady = _amb.isNotEmpty;
  }

  /// How loud the valley is, from how big and how lit the town in front of you
  /// is.
  ///
  /// A big, kept-up town is a place with people in it and sounds like one. A
  /// small or abandoned one is not silent — that would read as broken — it just
  /// keeps the wind and loses the voices, which is what nobody home sounds
  /// like.
  Future<void> ambience(double size01, double integrity) async {
    if (!_ambReady) return;
    final life = size01.clamp(0.0, 1.0) * (0.35 + 0.65 * integrity);
    final shape = [
      0.30 + 0.10 * (1 - life),
      0.46 * _ramp(life, 0.08, 0.55),
      0.40 * _ramp(life, 0.42, 0.95),
    ];
    for (var i = 0; i < _amb.length && i < shape.length; i++) {
      // Each layer can be silenced on its own, and the whole valley rides the
      // same slider the rest of the effects do.
      final want = _asleep || !_wants.hears(_layers[i])
          ? 0.0
          : shape[i] * _effectsGain;
      // Eased, so walking between two towns is a change of place rather than a
      // switch being thrown. The state moves every frame whatever happens: the
      // threshold below decides whether to spend a call on the player, and
      // nothing else — mixing those two was what left the music at zero.
      _ambAt[i] += (want - _ambAt[i]) * 0.10;
      if ((_ambAt[i] - _ambSent[i]).abs() < 0.004) continue;
      _ambSent[i] = _ambAt[i];
      try {
        await _amb[i].setVolume(_ambAt[i].clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  static double _ramp(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  /// Every so often, one sound that says what kind of place this is.
  void ambientOneShot(double dt, double size01, double integrity) {
    if (!_ready || _asleep) return;
    _sinceOneShot += dt;
    // Busy towns speak up often; a quiet one only now and then.
    final gap = 26.0 - 16.0 * size01.clamp(0.0, 1.0) * integrity;
    if (_sinceOneShot < gap) return;
    _sinceOneShot = 0;
    final alive = integrity > 0.6 && size01 > 0.10;
    final pool = alive ? _alive : _empty;
    _say(pool[DateTime.now().microsecond % pool.length]);
  }

  /// How this app asks Android and iOS for the speaker.
  ///
  /// It asks for nothing, and that is the whole point.
  ///
  /// By default every `AudioPlayer` requests `AUDIOFOCUS_GAIN` the moment it
  /// starts, and Android grants that to one client at a time. Every other
  /// client gets `AUDIOFOCUS_LOSS` — including the other players of the same
  /// app, because each one registers its own listener — and audioplayers
  /// answers a loss by pausing that player. This app runs six loops at once:
  /// three of valley noise and three of music. So the sixth to start paused
  /// the other five, and a single tap on the place button paused whatever was
  /// left. That is why the music was silent on a phone and perfect in a
  /// browser, where there is no such thing as audio focus.
  ///
  /// Asking for no focus is also the honest thing: these are the sounds of a
  /// town in the background, not a record somebody put on, and they have no
  /// business stopping whatever the person was already listening to.
  @visibleForTesting
  static AudioContext theAir() => AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> _shareTheAir() async {
    try {
      await AudioPlayer.global.setAudioContext(theAir());
    } catch (_) {
      // A device that will not say is a device we carry on without.
    }
  }

  Future<void> init() async {
    if (_ready) return;
    // First, before a single player exists: a player is born holding a copy of
    // whatever the global context was at the time, so setting this afterwards
    // would leave everything already made still fighting over the speaker.
    await _shareTheAir();
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

  /// Plays one of the catalogue, at whatever the person left the effects
  /// slider on. Every noise this app makes short of the loops comes through
  /// here, which is why "is this one allowed?" is asked in exactly one place.
  Future<void> _say(String id, {double louder = 1.0}) async {
    if (!_wants.hears(id)) return;
    final bite = biteOf(id);
    if (bite == null) return;
    await _fire(bite.file, bite.level * louder * _effectsGain);
  }

  /// Half the slider is what the app has always sounded like, so anything from
  /// there is measured against something already known. All the way up is
  /// twice that, and the top is still the top: nothing clips.
  double get _effectsGain => _wants.effectsVolume * 2;

  Future<void> _fire(String asset, double volume) async {
    if (!_ready || _pool.isEmpty || _asleep) return;
    try {
      final p = _pool[_cursor];
      _cursor = (_cursor + 1) % _pool.length;
      await p.stop();
      await p.setVolume(volume.clamp(0.0, 1.0));
      await p.play(AssetSource('sfx/$asset'));
    } catch (_) {
      // Audio is a bonus, never a requirement.
    }
  }

  /// What one sound is like, on demand, ignoring whether it is silenced —
  /// listening to a thing to decide whether to silence it is the whole point.
  Future<void> preview(String id) async {
    final bite = biteOf(id);
    if (bite == null) return;
    await _fire(bite.file, (bite.level * _effectsGain).clamp(0.12, 1.0));
  }

  void _haptic(void Function() f) {
    if (_wants.hapticsOff) return;
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
    _say('place', louder: 0.9 + 0.5 * strength);
    _haptic(HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 78), () {
      _haptic(HapticFeedback.mediumImpact);
    });
  }

  void epic() {
    _say('epic');
    _haptic(HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 120), () {
      _haptic(HapticFeedback.mediumImpact);
    });
    Future.delayed(const Duration(milliseconds: 240), () {
      _haptic(HapticFeedback.lightImpact);
    });
  }

  void milestone() {
    _say('milestone');
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 90 * i), () {
        _haptic(HapticFeedback.mediumImpact);
      });
    }
  }

  void repair() {
    _say('repair');
    _haptic(HapticFeedback.lightImpact);
  }

  void tick() {
    _say('tap');
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
