import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/season.dart';

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

  // ------------------------------------------------------------- la hora

  /// Fingir una hora para poder mirar el pueblo a cualquiera de las
  /// veinticuatro sin esperarlas.
  ///
  /// No es sólo el color del cielo: la música, las ventanas encendidas y las
  /// fugaces salen todas de la misma hora, así que con esto se juega con el
  /// pueblo entero a las cuatro de la mañana a las once de la mañana. Al
  /// apagarlo vuelve el reloj de verdad.
  bool _fakeHour = false;
  double _fakeHourAt = 22.0;

  bool get fakeHour => _fakeHour;
  double get fakeHourAt => _fakeHourAt;

  Future<void> setFakeHour(bool v) async {
    if (v == _fakeHour) return;
    _fakeHour = v;
    await _keep();
  }

  Future<void> setFakeHourAt(double v) async {
    final want = v.clamp(0.0, 23.99);
    if (want == _fakeHourAt) return;
    _fakeHourAt = want;
    await _keep();
  }

  // -------------------------------------------------------------- el año

  /// De qué lado del ecuador está el valle.
  ///
  /// Hace falta y no se puede deducir del reloj: en enero medio mundo está
  /// bajo la nieve y el otro medio en lo más alto del verano. Por defecto sale
  /// del país del idioma del teléfono, que es lo único que hay sin pedir
  /// permisos, y se puede corregir a mano — la lista de países nunca va a
  /// acertar con todo el mundo, y equivocarse aquí se ve el primer día.
  ///
  /// Nulo quiere decir «lo que diga el teléfono». Se guarda sólo cuando
  /// alguien lo toca, así que a quien no lo toque le sigue valiendo lo que
  /// diga el teléfono aunque se mude.
  Hemisphere? _hemisphere;

  Hemisphere get hemisphere => _hemisphere ?? _fromLocale;

  /// Si está puesto a mano o sale del teléfono.
  bool get hemisphereChosen => _hemisphere != null;

  static Hemisphere get _fromLocale {
    try {
      final l = PlatformDispatcher.instance.locale;
      return Season.hemisphereOf(l.countryCode);
    } catch (_) {
      return Hemisphere.north;
    }
  }

  Future<void> setHemisphere(Hemisphere? v) async {
    if (v == _hemisphere) return;
    _hemisphere = v;
    await _keep();
  }

  /// Si el valle cambia con el año.
  ///
  /// Se puede apagar. No todo el mundo quiere que su pueblo esté pelado y
  /// blanco cinco meses, y hay a quien le gusta el verde de siempre.
  bool _seasonsOff = false;
  bool get seasons => !_seasonsOff;

  Future<void> setSeasons(bool v) async {
    if (v == !_seasonsOff) return;
    _seasonsOff = !v;
    await _keep();
  }

  /// Fingir un día del año, igual que se finge la hora: para poder ver el
  /// invierno en marzo sin esperar a que llegue.
  bool _fakeSeason = false;
  double _fakeSeasonAt = 0.0;

  bool get fakeSeason => _fakeSeason;
  double get fakeSeasonAt => _fakeSeasonAt;

  Future<void> setFakeSeason(bool v) async {
    if (v == _fakeSeason) return;
    _fakeSeason = v;
    await _keep();
  }

  Future<void> setFakeSeasonAt(double v) async {
    final want = v.clamp(0.0, 0.999);
    if (want == _fakeSeasonAt) return;
    _fakeSeasonAt = want;
    await _keep();
  }

  /// En qué punto del año está el valle ahora mismo.
  Season get season {
    if (_seasonsOff) return Season.none;
    if (_fakeSeason) return Season(_fakeSeasonAt);
    return Season.on(DateTime.now(), hemisphere);
  }

  // ------------------------------------------------------- la letra del papel

  /// Con qué letra están escritos los papeles del tablón.
  ///
  /// Ya no son ajustes y por eso ya no se guardan. El día que dejaron de
  /// elegirse, los valores viejos siguieron en el disco de quien los hubiera
  /// tocado: había gente —yo el primero, probándolas— con una letra fija
  /// guardada para los bandos, así que el tablón entero le salía de una sola
  /// mano y el reparto entre las nueve no se veía nunca. Una preferencia que
  /// no se puede cambiar no es una preferencia: es una constante con un sitio
  /// donde quedarse desactualizada.
  ///
  /// Lo que quedó elegido tras probarlas una a una en el tablón: las notas en
  /// Arquitecta a media altura del deslizador, y los bandos repartidos entre
  /// las nueve manos, casi arriba del todo.
  static const String noteFont = 'arquitecta';
  static const String villageFont = 'varias';
  static const double noteScale = 1.5;
  static const double villageScale = 2.06;

  // --------------------------------------------------------------- el sonido

  bool _soundOff = false;
  bool _musicOff = false;
  bool _effectsOff = false;
  bool _hapticsOff = false;

  /// La mitad del deslizador. Lo que suena ahí lo dice [_midwayGain].
  static const double _midway = 0.5;

  /// Y lo que suena en la mitad es el quince por ciento del volumen que puede
  /// dar el aparato. Es el punto al que llegó quien la usó de verdad durante
  /// un tiempo: la música es de fondo, y de fondo quiere decir bastante más
  /// baja de lo que uno pondría el primer día.
  static const double _midwayGain = 0.15;

  /// Y de la mitad hacia arriba crece rápido, no en línea recta.
  ///
  /// Si la mitad tiene que dar un quince por ciento y el tope un cien, entre
  /// los dos no puede haber una recta: haría que el ochenta por ciento sonara
  /// casi igual que el cincuenta y que sólo el último tramo hiciera algo. La
  /// curva es la potencia que pasa por los dos puntos, y sale de ellos en vez
  /// de estar puesta a mano: cambiar [_midwayGain] la recalcula sola.
  static final double _curve = math.log(_midwayGain) / math.log(_midway);

  /// Lo que hay que pedirle al reproductor. El deslizador guarda la posición
  /// del dedo; esto es lo que esa posición significa.
  double get musicGain => math.pow(_musicVolume, _curve).toDouble();

  /// La posición del dedo que sonaría igual que este volumen de antes, para no
  /// bajarle la música a quien ya la tenía donde quería.
  static double _asPosition(double oldGain) =>
      math.pow(oldGain.clamp(0.0, 1.0), 1 / _curve).toDouble();

  /// Qué versión de esa cuenta trae lo guardado. Sin marca es la de antes,
  /// cuando la posición y el volumen eran el mismo número.
  static const String _volMark = 'vol';
  static const String _volNow = '2';
  double _musicVolume = _midway;
  double _effectsVolume = _midway;

  /// The one switch that covers everything, music included.
  bool get soundOff => _soundOff;
  bool get musicOff => _musicOff;
  bool get effectsOff => _effectsOff;
  bool get hapticsOff => _hapticsOff;
  double get musicVolume => _musicVolume;
  double get effectsVolume => _effectsVolume;

  /// Whether this particular sound is allowed to make a noise right now.
  bool hears(String id) => !_soundOff && !_effectsOff;

  /// Whether the music is allowed to play at all.
  bool get hearsMusic => !_soundOff && !_musicOff;

  /// Todo como salió de fábrica.
  ///
  /// Leer no es mezclar con lo que hubiera: sin esto, un arranque que no
  /// encuentra nada guardado se queda con lo que hubiese en memoria de antes,
  /// que en la app es sólo el primer arranque pero en cualquier otro sitio
  /// —un test, un reinicio en caliente— es basura del anterior.
  void _forget() {
    _soundOff = false;
    _musicOff = false;
    _effectsOff = false;
    _hapticsOff = false;
    _musicVolume = _midway;
    _effectsVolume = _midway;
    _fakeHour = false;
    _fakeHourAt = 22.0;
  }

  Future<void> load() async {
    _forget();
    try {
      final prefs = await SharedPreferences.getInstance();
      _rapid = prefs.getBool(_rapidKey) ?? false;
      final saved = prefs.getStringList(_soundKey);
      if (saved != null) {
        final visto = _readPrefs(saved);
        // Lo guardado antes de la curva decía «0,15» queriendo decir «que
        // suene al quince por ciento». Ahora eso mismo se dice con el dedo a
        // la mitad, así que se traduce una vez y se marca como traducido.
        //
        // Sólo si había un volumen escrito. Un guardado que no lo traía —de
        // una versión anterior a que se pudiera tocar, o corrupto— no tiene
        // nada que conservar: se queda con el valor por defecto de hoy, que es
        // justamente lo que se acaba de cambiar.
        if (visto.contains('musicVol') && !visto.contains(_volMark)) {
          _musicVolume = _asPosition(_musicVolume);
          unawaited(_writeNow());
        }
      }
    } catch (_) {
      // A phone that will not give us its preferences still gets a town.
    }
    notifyListeners();
  }

  /// Written as a plain list of `key=value`, so a setting added later reads
  /// back as its default instead of throwing the whole lot away. Que la clave
  /// del disco se llame «sound» es historia: ahí dentro va ya todo lo que se
  /// elige, y renombrarla le borraría a todo el mundo lo que tenía puesto.
  Set<String> _readPrefs(List<String> rows) {
    final visto = <String>{};
    for (final row in rows) {
      final at = row.indexOf('=');
      if (at <= 0) continue;
      final key = row.substring(0, at), value = row.substring(at + 1);
      visto.add(key);
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
          // Un valor ilegible no es un volumen guardado: se queda el de hoy y
          // no hay nada que traducir a la curva nueva.
          final v = double.tryParse(value);
          if (v == null) {
            visto.remove(key);
          } else {
            _musicVolume = v.clamp(0.0, 1.0);
          }
        case 'effectsVol':
          _effectsVolume = (double.tryParse(value) ?? _midway).clamp(0.0, 1.0);
        case 'fakeHour':
          _fakeHour = value == '1';
        case 'fakeHourAt':
          _fakeHourAt = (double.tryParse(value) ?? 22.0).clamp(0.0, 23.99);
        case 'hemisphere':
          _hemisphere = switch (value) {
            'n' => Hemisphere.north,
            's' => Hemisphere.south,
            _ => null,
          };
        case 'seasons':
          _seasonsOff = value == '0';
        case 'fakeSeason':
          _fakeSeason = value == '1';
        case 'fakeSeasonAt':
          _fakeSeasonAt = (double.tryParse(value) ?? 0.0).clamp(0.0, 0.999);
        // Las cuatro de la letra ya no se eligen, así que ya no se guardan.
        // Se leen para tirarlas: al sacarlas de `visto`, la próxima escritura
        // no las vuelve a poner y el disco se limpia solo. Hace falta hacerlo
        // y no ignorarlas sin más, porque quien hubiera probado letras tenía
        // una guardada para los bandos y le salía el tablón entero de una
        // sola mano.
        case 'noteFont':
        case 'villageFont':
        case 'noteScale':
        case 'villageScale':
          visto.remove(key);
      }
    }
    return visto;
  }

  List<String> _writePrefs() => [
    'sound=${_soundOff ? 0 : 1}',
    'music=${_musicOff ? 0 : 1}',
    'effects=${_effectsOff ? 0 : 1}',
    'haptics=${_hapticsOff ? 0 : 1}',
    '$_volMark=$_volNow',
    'musicVol=$_musicVolume',
    'effectsVol=$_effectsVolume',
    'fakeHour=${_fakeHour ? 1 : 0}',
    'fakeHourAt=$_fakeHourAt',
    // Sólo si alguien lo puso a mano: sin fila, manda el teléfono.
    if (_hemisphere != null)
      'hemisphere=${_hemisphere == Hemisphere.south ? 's' : 'n'}',
    'seasons=${_seasonsOff ? 0 : 1}',
    'fakeSeason=${_fakeSeason ? 1 : 0}',
    'fakeSeasonAt=$_fakeSeasonAt',
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
      await prefs.setStringList(_soundKey, _writePrefs());
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
