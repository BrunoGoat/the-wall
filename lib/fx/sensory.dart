import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/tunes.dart';
import '../model/appearance.dart';

/// One noise, with a name a person would recognise it by.
class SoundBite {
  const SoundBite(this.id, this.file, this.name, this.level);

  /// Never changes: it is what a silenced sound is written down as.
  final String id;
  final String file;
  final String name;

  /// How loud this one is relative to the others, before the slider.
  final double level;
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
  /// Five, and cada uno es algo que hiciste vos. Hubo cuatro más que decía el
  /// pueblo por su cuenta —campana, gallo, cuervo, gozne— y tres bucles de
  /// aire de valle. Se fueron: un pueblo que grazna solo cada veintitantos
  /// segundos no aporta nada y se nota mal, y un bucle de viento de ocho
  /// segundos se oye que es un bucle de ocho segundos.
  static const List<SoundBite> catalogue = [
    SoundBite('place', 'place.wav', 'Poner una pieza', 0.72),
    SoundBite('tap', 'tap.wav', 'Toque', 0.45),
    SoundBite('repair', 'repair.wav', 'Reparar', 0.70),
    SoundBite('milestone', 'milestone.wav', 'Obra terminada', 0.85),
    SoundBite('epic', 'epic.wav', 'Hito del pueblo', 0.90),
  ];

  static SoundBite? biteOf(String id) {
    for (final b in catalogue) {
      if (b.id == id) return b;
    }
    return null;
  }

  // ---------------------------------------------------------------- música

  /// La pieza que está sonando. Se cambia en caliente desde los ajustes.
  Tune _tune = tunes.first;
  Tune get tune => _tune;

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

  /// La última hora que nos pasaron, para poder saltar a la mezcla correcta al
  /// cambiar de pieza sin esperar a que llegue el fotograma siguiente.
  double _lastHour = 12;

  /// Lo que hay que pedirle al reproductor. La cuenta que traduce la posición
  /// del deslizador a esto vive con las preferencias, que es donde está
  /// escrito qué significa la posición.
  double get _musLevel => _wants.musicGain;

  /// What each layer is playing at right now, for showing it.
  List<double> get heard => List.unmodifiable(_musAt);

  /// Cuál suena hoy: una al azar, cada vez que se abre la app.
  Tune _pick() => tunes[DateTime.now().microsecondsSinceEpoch % tunes.length];

  Future<void> _loadTune(Tune want) async {
    for (final p in _mus) {
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
    _mus.clear();
    for (var i = 0; i < 3; i++) {
      _musAt[i] = 0;
      _musSent[i] = 0;
    }
    _tune = want;
    // One at a time, each on its own: a layer that will not start is one
    // layer missing, not three. It used to be a single try around the loop,
    // so the first failure took the whole piece with it and said nothing.
    for (final name in want.files) {
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

  /// Pone otra pieza, ya. Para el disquito de los ajustes.
  ///
  /// Sin la entrada lenta y sin esperar al fotograma siguiente: alguien que
  /// acaba de pedir oír un disco quiere oírlo. Y la que se elige aquí es la
  /// que sigue sonando al cerrar la pantalla — probar una y que al volver
  /// suene otra sería una broma pesada.
  Future<void> playTune(Tune want) async {
    await _loadTune(want);
    _musIn = 1.0;
    _jump();
  }

  /// El volumen que le toca a cada capa ahora mismo, sin transición.
  void _jump() {
    final day = dayMix(_tune, _lastHour);
    final level = _musLevel * (_musIn <= 0 ? 1 : _musIn);
    for (var i = 0; i < _mus.length && i < 3; i++) {
      _musAt[i] = day[i] * level;
      _musSent[i] = _musAt[i];
      try {
        _mus[i].setVolume(_musAt[i].clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  /// Interpola entre las cuatro horas de la pieza dando la vuelta al reloj, con
  /// una curva suave: a las ocho y un minuto no puede sonar distinto que a las
  /// ocho menos uno.
  ///
  /// Not only for tests any more: the settings screen shows this, so somebody
  /// can hear what four in the morning sounds like without waiting for it.
  static List<double> dayMix(Tune tune, double hour) {
    const stops = [3.0, 8.0, 14.0, 20.0, 27.0];
    final mixes = [...tune.hours, tune.hours.first];
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
    return tune.hours.first;
  }

  /// La mezcla de este instante. `hour` es la misma hora con la que se pinta
  /// el cielo, así que la música y la luz cambian juntas.
  Future<void> music(double hour, double dt, double integrity) async {
    _lastHour = hour;
    if (!_musReady) return;
    if (_asleep || !_wants.hearsMusic) return;
    _musIn = (_musIn + dt / 6.0).clamp(0.0, 1.0);
    final day = dayMix(_tune, hour);
    // Un pueblo dejado pierde parte de su música, pero no toda: el silencio
    // absoluto se lee como una app rota, no como un pueblo abandonado.
    final level =
        _musLevel * _musIn * (0.72 + 0.28 * integrity.clamp(0.0, 1.0));
    final want = [for (var i = 0; i < 3; i++) day[i] * level];
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
    await _loadTune(_pick());
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

  /// Lo que suena cuando cruza una fugaz.
  ///
  /// Flojito y a lo lejos: es algo que pasa en el cielo, no algo que hiciste.
  /// Comparte el sonido del hito porque es el que tiene esa campana larga, y un
  /// archivo nuevo para segundo y pico de sonido no lo vale.
  void wish() {
    _say('epic', louder: 0.42);
  }

  void tick() {
    _say('tap');
    _haptic(HapticFeedback.selectionClick);
  }

  void dispose() {
    for (final p in [..._pool, ..._mus]) {
      p.dispose();
    }
    _pool.clear();
    _mus.clear();
    _ready = false;
    _musReady = false;
  }
}
