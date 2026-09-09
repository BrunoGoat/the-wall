import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/tunes.dart';
import 'package:la_muralla/fx/sensory.dart';

/// Los quince archivos se generan en `tool/make_music.py`, y todo el diseño se
/// apoya en dos propiedades que ningún otro test miraría:
///
///   · las dos capas que llevan armonía duran exactamente lo mismo, porque si
///     se desfasan los acordes chocan;
///   · la tercera dura otra cosa, porque si durase lo mismo la mezcla se
///     repetiría idéntica cada bucle y no habría nada que ganar con tenerla
///     aparte.
///
/// Si alguien regenera con otros compases, las dos se rompen calladas.

/// Los datos de un WAV mono de 16 bits, leídos a mano: no hay decodificador en
/// un test de Dart y tampoco hace falta uno.
({int rate, int channels, int bits, List<int> pcm}) _wav(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b);
  expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
  var at = 12, rate = 0, channels = 0, bits = 0;
  List<int> pcm = const [];
  while (at + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(at, at + 4));
    final size = d.getUint32(at + 4, Endian.little);
    if (id == 'fmt ') {
      channels = d.getUint16(at + 10, Endian.little);
      rate = d.getUint32(at + 12, Endian.little);
      bits = d.getUint16(at + 22, Endian.little);
    } else if (id == 'data') {
      pcm = [
        for (var i = at + 8; i + 1 < at + 8 + size; i += 2)
          d.getInt16(i, Endian.little),
      ];
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  return (rate: rate, channels: channels, bits: bits, pcm: pcm);
}

/// Cuánto suena cuando suena.
///
/// El valor eficaz del archivo entero no sirve para comparar una cama continua
/// con una capa de campanas que calla nueve segundos de cada diez: el silencio
/// le baja la nota a la segunda y saldría siempre «más floja» aunque atronase.
/// Así que se mide sólo por encima de un umbral, que es lo que hace cualquiera
/// que mida sonoridad.
double _loud(List<int> pcm) {
  var peak = 0;
  for (final v in pcm) {
    if (v.abs() > peak) peak = v.abs();
  }
  final gate = peak * 0.08;
  var sum = 0.0, n = 0;
  for (final v in pcm) {
    if (v.abs() > gate) {
      sum += v * v;
      n++;
    }
  }
  if (n < pcm.length ~/ 50) {
    sum = pcm.fold(0.0, (a, v) => a + v * v);
    n = pcm.length;
  }
  return math.sqrt(sum / math.max(1, n)) / 32767;
}

/// Cuánto brilla: el valor eficaz de la diferencia entre muestras contra el de
/// la señal. Una senoide a `f` da dos por seno de pi f sobre la frecuencia de
/// muestreo, así que este número sube con el contenido agudo. Es un análisis
/// espectral de pobre, y para «¿esto es oscuro o es un siseo?» alcanza.
double _bright(List<int> pcm) {
  var a = 0.0, b = 0.0;
  for (var i = 1; i < pcm.length; i++) {
    final d = (pcm[i] - pcm[i - 1]).toDouble();
    a += d * d;
    b += pcm[i].toDouble() * pcm[i].toDouble();
  }
  return b <= 0 ? 0 : math.sqrt(a / b);
}

void main() {
  group('los quince archivos', () {
    test('están todos, y son mono de dieciséis bits', () {
      for (final tune in tunes) {
        for (final f in tune.files) {
          final path = 'assets/sfx/$f';
          expect(File(path).existsSync(), isTrue, reason: 'falta $f');
          final w = _wav(path);
          expect(w.channels, 1, reason: '$f: tiene que ser mono');
          expect(w.bits, 16, reason: f);
          expect([8000, 16000], contains(w.rate), reason: f);
        }
      }
    });

    test('las dos capas con armonía duran exactamente lo mismo', () {
      // La regla que la versión anterior no necesitaba: allí la armonía era un
      // bordón que no se movía, así que daba igual cómo cayeran las capas unas
      // sobre otras. Con cuatro acordes que van a algún lado, dos capas que
      // llevan acordes y duran distinto se cruzan un fa mayor con un sol.
      for (final tune in tunes) {
        final pad = _wav('assets/sfx/${tune.files[0]}');
        final keys = _wav('assets/sfx/${tune.files[1]}');
        final a = pad.pcm.length / pad.rate;
        final b = keys.pcm.length / keys.rate;
        expect(
          (a - b).abs(),
          lessThan(0.01),
          reason:
              '${tune.id}: la cama dura ${a.toStringAsFixed(2)} s y lo que se '
              'mueve ${b.toStringAsFixed(2)} s — los acordes se van a desfasar',
        );
      }
    });

    test('y la de arriba dura otra cosa, o no habría nada que ganar', () {
      for (final tune in tunes) {
        final keys = _wav('assets/sfx/${tune.files[1]}');
        final air = _wav('assets/sfx/${tune.files[2]}');
        final a = keys.pcm.length / keys.rate;
        final b = air.pcm.length / air.rate;
        expect(
          (a - b).abs(),
          greaterThan(1.0),
          reason:
              '${tune.id}: si la capa que flota dura lo mismo que la de abajo, '
              'la mezcla se repite idéntica cada vuelta',
        );
      }
    });

    test('el bucle cierra sin chasquido y sin pedestal de continua', () {
      for (final tune in tunes) {
        for (final f in tune.files) {
          final s = _wav('assets/sfx/$f').pcm;
          var sum = 0.0, worst = 0;
          for (var i = 1; i < s.length; i++) {
            sum += s[i];
            final step = (s[i] - s[i - 1]).abs();
            if (step > worst) worst = step;
          }
          // El salto al empalmar no puede ser mayor que el mayor salto que la
          // propia onda da dentro del bucle: si lo fuera, se oiría un clic
          // cada vez que vuelve a empezar.
          expect(
            (s.first - s.last).abs(),
            lessThanOrEqualTo(worst),
            reason: '$f: la costura del bucle se oye',
          );
          expect((sum / s.length).abs() / 32767, lessThan(0.01), reason: f);
        }
      }
    });

    test('ninguna recorta ni se escribió tan floja que se pierda', () {
      for (final tune in tunes) {
        for (final f in tune.files) {
          final s = _wav('assets/sfx/$f').pcm;
          final peak = s.map((v) => v.abs()).reduce(math.max);
          expect(peak, lessThan(32767), reason: '$f: recorta');
          expect(peak / 32767, greaterThan(0.10), reason: '$f: casi no está');
        }
      }
    });

    test('las tres capas de una pieza se oyen las tres', () {
      // El equilibrio va escrito en el archivo y no repartido entre el
      // generador y el Dart, donde una de las dos copias se queda vieja. Esto
      // comprueba que quedó escrito: ninguna capa puede ser tan floja al lado
      // de otra que no se oiga, ni tan fuerte que tape a las demás.
      for (final tune in tunes) {
        final loud = [
          for (final f in tune.files) _loud(_wav('assets/sfx/$f').pcm),
        ];
        final top = loud.reduce(math.max), low = loud.reduce(math.min);
        expect(
          top / low,
          lessThan(4.0),
          reason:
              '${tune.id}: entre la capa más fuerte y la más floja hay '
              '${(top / low).toStringAsFixed(1)} veces',
        );
      }
    });

    test('la cama es oscura, que es lo que la hace una cama', () {
      // Un pad es sierras desafinadas con un paso bajo apretado encima. Si
      // este número sube, el filtro se soltó o hay algo doblando por arriba, y
      // las dos cosas suenan a zumbido y no a colchón.
      for (final tune in tunes) {
        final w = _wav('assets/sfx/${tune.files[0]}');
        expect(
          _bright(w.pcm),
          lessThan(0.80),
          reason: '${tune.id}: la cama brilla demasiado para ser una cama',
        );
      }
    });
  });

  group('las cinco piezas', () {
    test('tienen las cuatro horas, con tres capas cada una', () {
      for (final tune in tunes) {
        expect(tune.id, matches(RegExp(r'^[a-z]+$')));
        expect(tune.name, isNotEmpty);
        expect(tune.blurb, isNotEmpty);
        expect(tune.files.length, 3);
        expect(
          tune.hours.length,
          4,
          reason: '${tune.id}: noche, alba, medio, ocaso',
        );
        for (final h in tune.hours) {
          expect(h.length, 3, reason: tune.id);
          for (final v in h) {
            expect(v, inInclusiveRange(0.0, 1.0), reason: tune.id);
          }
        }
      }
    });

    test('no hay dos iguales, ni de nombre ni de reparto', () {
      expect(tunes.map((t) => t.id).toSet().length, tunes.length);
      expect(tunes.map((t) => t.name).toSet().length, tunes.length);
      final shapes = tunes.map((t) => t.hours.toString()).toSet();
      expect(shapes.length, tunes.length, reason: 'dos reparten el día igual');
    });

    test('un identificador que no existe cae en la primera, no en nada', () {
      expect(tuneOf('no existe').id, tunes.first.id);
      expect(tuneOf(null).id, tunes.first.id);
      for (final t in tunes) {
        expect(tuneOf(t.id).id, t.id);
      }
    });
  });

  group('la mezcla del día', () {
    test('da la vuelta al reloj sin una arista en ninguna hora', () {
      for (final tune in tunes) {
        var worst = 0.0;
        for (var q = 0; q < 24 * 60; q++) {
          final a = Sensory.dayMix(tune, (q / 60) % 24);
          final b = Sensory.dayMix(tune, ((q + 1) / 60) % 24);
          for (var i = 0; i < 3; i++) {
            final d = (b[i] - a[i]).abs();
            if (d > worst) worst = d;
          }
        }
        // Un minuto de reloj no puede mover ninguna capa ni un uno por ciento.
        expect(worst, lessThan(0.01), reason: tune.id);
      }
    });

    test('a ninguna hora se apaga del todo ni se pasa de uno', () {
      for (final tune in tunes) {
        for (var q = 0; q < 24 * 4; q++) {
          final m = Sensory.dayMix(tune, q / 4);
          expect(m.length, 3);
          for (final v in m) {
            expect(v, inInclusiveRange(0.0, 1.0), reason: tune.id);
          }
          // Siempre hay algo sonando: el silencio se lee como una app rota.
          expect(m.reduce((a, b) => a + b), greaterThan(1.0), reason: tune.id);
        }
      }
    });

    test('en las cinco, de noche manda la cama', () {
      // Lo único que las cinco comparten: de madrugada lo que sostiene es la
      // capa de abajo, y lo que se mueve se aparta.
      for (final tune in tunes) {
        final noche = Sensory.dayMix(tune, 3);
        expect(
          noche[0],
          greaterThan(noche[1]),
          reason: '${tune.id}: de noche no manda la cama',
        );
      }
    });

    test('y el día no suena igual que la noche en ninguna', () {
      for (final tune in tunes) {
        final noche = Sensory.dayMix(tune, 3);
        final medio = Sensory.dayMix(tune, 14);
        var apart = 0.0;
        for (var i = 0; i < 3; i++) {
          apart += (noche[i] - medio[i]).abs();
        }
        expect(
          apart,
          greaterThan(0.30),
          reason: '${tune.id}: la hora del día no cambia casi nada',
        );
      }
    });
  });

  group('la música llega a sonar', () {
    // El defecto que dejó la música muda entera: el `if` que se ahorraba una
    // llamada al reproductor era el mismo que guardaba el volumen, así que una
    // capa cuyo paso por fotograma cae por debajo del umbral no subía nunca.
    test('cada capa llega a su volumen desde el silencio', () {
      for (final dt in [1 / 30.0, 1 / 60.0, 1 / 120.0]) {
        for (final want in [0.08, 0.14, 0.5]) {
          var at = 0.0;
          for (var f = 0; f < (30 / dt).round(); f++) {
            at = Sensory.approach(at, want, dt);
          }
          expect(
            at,
            closeTo(want, want * 0.01),
            reason:
                'a ${(1 / dt).round()} fotogramas por segundo, una capa que '
                'va a $want se quedó en ${at.toStringAsFixed(4)}',
          );
        }
      }
    });

    test('la subida es un paso, no un salto', () {
      var at = 0.0;
      for (var f = 0; f < 30; f++) {
        at = Sensory.approach(at, 0.5, 1 / 60.0);
      }
      expect(at, lessThan(0.5 * 0.4));
    });

    test('no se gasta una llamada por fotograma, pero sí la última', () {
      var at = 0.0, sent = 0.0;
      var calls = 0;
      const want = 0.08;
      for (var f = 0; f < 60 * 30; f++) {
        at = Sensory.approach(at, want, 1 / 60.0);
        if (Sensory.worthSending(at, sent, want)) {
          sent = at;
          calls++;
        }
      }
      expect(calls, greaterThan(0), reason: 'nunca se le dijo nada al motor');
      expect(calls, lessThan(120), reason: 'una llamada por fotograma');
      expect(sent, closeTo(want, want * 0.02));
    });
  });

  group('el aire es de todos', () {
    // Lo que dejó la música muda en un teléfono y perfecta en un navegador.
    //
    // Cada AudioPlayer pide AUDIOFOCUS_GAIN al arrancar, y Android se lo
    // concede a uno solo: todos los demás reciben AUDIOFOCUS_LOSS —incluidos
    // los de la misma app, porque cada uno registra su propio escucha— y
    // audioplayers responde a una pérdida pausando ese reproductor.
    //
    // En web no existe el foco de audio. Por eso la comprobación del
    // navegador pasó y el teléfono se quedó callado.
    test('esta app no le quita el foco de audio a nadie', () {
      expect(
        Sensory.theAir().android.audioFocus,
        AndroidAudioFocus.none,
        reason: 'con foco, cada capa pausa a las anteriores',
      );
    });

    test('y en iOS tampoco interrumpe lo que ya estabas escuchando', () {
      expect(Sensory.theAir().iOS.category, AVAudioSessionCategory.ambient);
    });
  });
}
