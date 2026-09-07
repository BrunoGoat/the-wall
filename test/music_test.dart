import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/fx/sensory.dart';

/// Las tres capas se generan en `tool/make_music.py`, y todo el diseño se
/// apoya en una sola propiedad: las tres duran un número entero de compases
/// del mismo pulso. Si alguien regenera con otro tempo u otro largo, dejan de
/// caer en el mismo sitio del compás y la música se desarma sin que ningún
/// otro test se entere.
const int _sr = 16000;
const double _beat = 1.0; // 60 pulsos por minuto
const double _bar = 4 * _beat;

/// Cuántos compases dura cada capa, y por qué es cada número: seis, ocho y
/// diez no tienen divisor común más allá del dos, así que la combinación no
/// se repite igual hasta los ciento veinte compases.
const Map<String, int> _layers = {
  'mus_bordon': 6,
  'mus_laud': 8,
  'mus_flauta': 10,
};

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

void main() {
  group('las tres capas', () {
    test('cada una dura un número entero de compases del mismo pulso', () {
      for (final e in _layers.entries) {
        final w = _wav('assets/sfx/${e.key}.wav');
        expect(w.rate, _sr, reason: '${e.key}: otra frecuencia de muestreo');
        expect(w.channels, 1, reason: '${e.key}: tiene que ser mono');
        expect(w.bits, 16);
        expect(
          w.pcm.length,
          (e.value * _bar * _sr).round(),
          reason: '${e.key} debería durar ${e.value} compases exactos',
        );
      }
    });

    test('sus largos no comparten frase, así que la mezcla no se repite', () {
      // El mínimo común múltiplo de 6, 8 y 10 compases: ciento veinte, que a
      // este pulso son ocho minutos antes de volver a sonar igual.
      var lcm = 1;
      for (final bars in _layers.values) {
        var a = lcm, b = bars;
        while (b != 0) {
          final t = b;
          b = a % b;
          a = t;
        }
        lcm = lcm ~/ a * bars;
      }
      expect(lcm, 120);
      expect(lcm * _bar, greaterThan(7 * 60));
    });

    test('el bucle cierra sin chasquido y sin pedestal de continua', () {
      for (final name in _layers.keys) {
        final s = _wav('assets/sfx/$name.wav').pcm;
        var sum = 0.0, worst = 0;
        for (var i = 1; i < s.length; i++) {
          sum += s[i];
          final int step = (s[i] - s[i - 1]).abs();
          if (step > worst) worst = step;
        }
        // El salto al empalmar no puede ser mayor que el mayor salto que la
        // propia onda da dentro del bucle: si lo fuera, se oiría un clic cada
        // vez que vuelve a empezar.
        expect(
          (s.first - s.last).abs(),
          lessThanOrEqualTo(worst),
          reason: '$name: la costura del bucle se oye',
        );
        // Y nada de continua: en una cuerda pulsada el lazo es un promediador
        // y cualquier continua que entre no se apaga nunca.
        expect((sum / s.length).abs() / 32767, lessThan(0.01), reason: name);
      }
    });

    test('ninguna se escribió tan floja como para tirar bits', () {
      for (final name in _layers.keys) {
        final s = _wav('assets/sfx/$name.wav').pcm;
        final peak = s.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
        expect(peak / 32767, greaterThan(0.7));
        expect(peak, lessThan(32767), reason: '$name: recorta');
      }
    });
  });

  group('la mezcla del día', () {
    test('da la vuelta al reloj sin una arista en ninguna hora', () {
      List<double> at(double h) => Sensory.dayMix(h % 24);
      var worst = 0.0;
      for (var q = 0; q < 24 * 60; q++) {
        final a = at(q / 60), b = at((q + 1) / 60);
        for (var i = 0; i < 3; i++) {
          final d = (b[i] - a[i]).abs();
          if (d > worst) worst = d;
        }
      }
      // Un minuto de reloj no puede mover ninguna capa ni un uno por ciento.
      expect(worst, lessThan(0.01));
    });

    test('a ninguna hora se apaga del todo ni se pasa de uno', () {
      for (var q = 0; q < 24 * 4; q++) {
        final m = Sensory.dayMix(q / 4);
        expect(m.length, 3);
        for (final v in m) {
          expect(v, inInclusiveRange(0.0, 1.0));
        }
        // Siempre hay algo sonando: el silencio se lee como una app rota.
        expect(m.reduce((a, b) => a + b), greaterThan(1.0));
      }
    });

    test('la noche es el bordón y el mediodía es el laúd', () {
      final noche = Sensory.dayMix(3), medio = Sensory.dayMix(14);
      expect(
        noche[0],
        greaterThan(noche[1]),
        reason: 'de noche manda el bordón',
      );
      expect(
        medio[1],
        greaterThan(medio[0]),
        reason: 'al mediodía manda el laúd',
      );
      expect(
        Sensory.dayMix(20)[2],
        greaterThan(Sensory.dayMix(14)[2]),
        reason: 'la flauta pesa más al atardecer que al mediodía',
      );
    });
  });
}
