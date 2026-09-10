import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/tunes.dart';
import 'package:la_muralla/fx/sensory.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Appearance> fresh({Map<String, Object> from = const {}}) async {
  SharedPreferences.setMockInitialValues(from);
  final a = Appearance.instance;
  await a.load();
  return a;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // El singleton se comparte entre tests, así que se deja como recién
    // instalado antes de cada uno.
    SharedPreferences.setMockInitialValues({});
    final a = Appearance.instance;
    await a.setSoundOff(false);
    await a.setMusicOff(false);
    await a.setEffectsOff(false);
    await a.setHapticsOff(false);
    await a.setMusicVolume(0.5);
    await a.setEffectsVolume(0.5);
    for (final b in Sensory.catalogue) {
      await a.hush(b.id, false);
    }
  });

  group('el catálogo de sonidos', () {
    test('cada uno tiene id propio, archivo propio y nombre propio', () {
      final ids = <String>{}, files = <String>{}, names = <String>{};
      for (final b in Sensory.catalogue) {
        expect(ids.add(b.id), isTrue, reason: 'id repetido: ${b.id}');
        expect(
          files.add(b.file),
          isTrue,
          reason: 'archivo repetido: ${b.file}',
        );
        expect(names.add(b.name), isTrue, reason: 'nombre repetido: ${b.name}');
        expect(b.name.trim(), isNotEmpty);
        expect(b.file.endsWith('.wav'), isTrue);
        expect(b.level, inExclusiveRange(0.0, 1.01));
      }
    });

    test('todo lo que la app puede sonar está en el catálogo', () async {
      // Si alguien añade un wav y se olvida de listarlo, no se puede ni
      // silenciar ni escuchar desde ajustes: existe y nadie lo sabe.
      final listed = {for (final b in Sensory.catalogue) b.file};
      final onDisk = await _wavsInAssets();
      final missing = onDisk.difference(listed)
        ..removeWhere((f) => f.startsWith('mus_'));
      expect(
        missing,
        isEmpty,
        reason: 'estos wav existen y no están en el catálogo: $missing',
      );
      // Y al revés: nada del catálogo puede apuntar a un archivo que no está.
      expect(listed.difference(onDisk), isEmpty);
    });

    test('se puede encontrar por id, y lo que no existe da null', () {
      for (final b in Sensory.catalogue) {
        expect(Sensory.biteOf(b.id)?.file, b.file);
      }
      expect(Sensory.biteOf('no existe'), isNull);
    });

    test('todo lo que suena es algo que hiciste vos', () {
      // Se fueron los cuatro que decía el pueblo por su cuenta —campana,
      // gallo, cuervo, gozne— y los tres bucles de aire del valle. Lo que
      // queda tiene que seguir siendo respuesta a un dedo, no relleno: un
      // sonido que sale solo cada tantos segundos no lo pidió nadie.
      expect(Sensory.catalogue.length, 5);
      for (final gone in [
        'bell',
        'cock',
        'crow',
        'creak',
        'amb_field',
        'amb_town',
        'amb_life',
      ]) {
        expect(Sensory.biteOf(gone), isNull, reason: '$gone volvió');
        expect(
          File('assets/sfx/$gone.wav').existsSync(),
          isFalse,
          reason: '$gone.wav sigue ocupando sitio en la app',
        );
      }
    });
  });

  group('el sorteo de discos', () {
    test('sin elegir nada, entran las cinco', () async {
      final a = await fresh();
      expect(a.rotation, tunes.length);
      for (final t in tunes) {
        expect(a.inRotation(t.id), isTrue, reason: t.id);
      }
    });

    test('quitar una deja las otras cuatro', () async {
      final a = await fresh();
      await a.setRotation(tunes.first.id, false);
      expect(a.inRotation(tunes.first.id), isFalse);
      expect(a.rotation, tunes.length - 1);
      for (final t in tunes.skip(1)) {
        expect(a.inRotation(t.id), isTrue, reason: t.id);
      }
    });

    test('dejar una sola es dejar una sola, no dejarlas todas', () async {
      // El caso que se rompe si «vacío quiere decir todas» está mal escrito:
      // quitar cuatro de cinco tiene que dejar una, y no volver a cinco.
      final a = await fresh();
      for (final t in tunes.skip(1)) {
        await a.setRotation(t.id, false);
      }
      expect(a.rotation, 1);
      expect(a.inRotation(tunes.first.id), isTrue);
      expect(a.inRotation(tunes.last.id), isFalse);
    });

    test('quedarse sin ninguna vuelve a querer decir todas', () async {
      // Nadie apaga las cinco para quedarse sin música: para eso está el
      // interruptor de la música, dos dedos más arriba. Apagar la última es un
      // dedo que se fue, y dejar la app muda por eso sería una trampa.
      final a = await fresh();
      for (final t in tunes) {
        await a.setRotation(t.id, false);
      }
      expect(a.rotation, tunes.length);
      for (final t in tunes) {
        expect(a.inRotation(t.id), isTrue, reason: t.id);
      }
    });

    test('y se acuerda de cuáles al volver a abrir', () async {
      final a = await fresh();
      await a.setRotation('bruma', false);
      await a.setRotation('caja', false);
      await a.flush();
      final b = Appearance.instance;
      await b.load();
      expect(b.inRotation('bruma'), isFalse);
      expect(b.inRotation('caja'), isFalse);
      expect(b.inRotation('tarde'), isTrue);
      expect(b.rotation, tunes.length - 2);
    });
  });

  group('los tres interruptores', () {
    test('el de todo apaga también la música', () async {
      final a = await fresh();
      expect(a.hearsMusic, isTrue);
      expect(a.hears('place'), isTrue);
      await a.setSoundOff(true);
      expect(a.hearsMusic, isFalse);
      expect(a.hears('place'), isFalse);
    });

    test('el de efectos no toca la música, y al revés', () async {
      final a = await fresh();
      await a.setEffectsOff(true);
      expect(a.hears('place'), isFalse);
      expect(a.hearsMusic, isTrue, reason: 'apagar efectos calló la música');

      await a.setEffectsOff(false);
      await a.setMusicOff(true);
      expect(a.hearsMusic, isFalse);
      expect(
        a.hears('place'),
        isTrue,
        reason: 'apagar música calló los efectos',
      );
    });

    test('silenciar uno no silencia a los demás', () async {
      final a = await fresh();
      await a.hush('cock', true);
      await a.hush('crow', true);
      expect(a.hears('cock'), isFalse);
      expect(a.hears('crow'), isFalse);
      for (final b in Sensory.catalogue) {
        if (b.id == 'cock' || b.id == 'crow') continue;
        expect(a.hears(b.id), isTrue, reason: '${b.id} se calló de rebote');
      }
    });
  });

  group('lo elegido sobrevive a cerrar la app', () {
    test('arrastrar un slider no escribe a disco en cada fotograma', () async {
      final a = await fresh();
      SharedPreferences.setMockInitialValues({});
      // Sesenta cambios, como un dedo bajando el volumen.
      for (var k = 0; k < 60; k++) {
        await a.setEffectsVolume(k / 60);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('pueblo_sound_v1'),
        isNull,
        reason: 'escribió a disco mientras el dedo seguía en el slider',
      );
      await a.flush();
      expect(prefs.getStringList('pueblo_sound_v1'), isNotNull);
    });

    test('los apagados, los volúmenes y los silenciados', () async {
      final a = await fresh();
      await a.setMusicOff(true);
      await a.setHapticsOff(true);
      await a.setMusicVolume(0.23);
      await a.setEffectsVolume(0.77);
      await a.hush('tap', true);
      await a.hush('amb_life', true);

      // El disco se escribe con retardo —arrastrar un slider cambia esto
      // sesenta veces por segundo— así que se fuerza, igual que hace la app
      // al irse a segundo plano.
      await a.flush();
      final written = (await SharedPreferences.getInstance()).getStringList(
        'pueblo_sound_v1',
      );
      expect(written, isNotNull, reason: 'no se escribió nada');

      // Y ahora la app se abre de nuevo: nada en memoria, sólo lo escrito.
      await a.setMusicOff(false);
      await a.setHapticsOff(false);
      await a.setMusicVolume(0.5);
      await a.setEffectsVolume(0.5);
      await a.hush('tap', false);
      await a.hush('amb_life', false);
      SharedPreferences.setMockInitialValues({
        'flutter.pueblo_sound_v1': written!,
      });
      await a.load();

      expect(a.musicOff, isTrue);
      expect(a.hapticsOff, isTrue);
      expect(a.musicVolume, closeTo(0.23, 0.001));
      expect(a.effectsVolume, closeTo(0.77, 0.001));
      expect(a.isHushed('tap'), isTrue);
      expect(a.isHushed('amb_life'), isTrue);
      expect(a.isHushed('place'), isFalse);
    });

    test(
      'una preferencia que no existía se lee con su valor por defecto',
      () async {
        // Lo guardado es una lista de `clave=valor`, así que una versión vieja
        // sin el volumen de la música no puede tirar abajo el resto.
        final a = await fresh(
          from: {
            'flutter.pueblo_sound_v1': ['music=0', 'hushed=tap'],
          },
        );
        expect(a.musicOff, isTrue);
        expect(a.isHushed('tap'), isTrue);
        expect(a.musicVolume, 0.5, reason: 'lo que falta vale su defecto');
        expect(a.effectsVolume, 0.5);
        expect(a.soundOff, isFalse);
      },
    );

    test('un guardado corrupto no impide abrir la app', () async {
      final a = await fresh(
        from: {
          'flutter.pueblo_sound_v1': ['basura', '=', 'musicVol=hola'],
        },
      );
      expect(a.musicVolume, 0.5);
      expect(a.soundOff, isFalse);
    });

    test('el volumen por defecto es la mitad', () async {
      final a = await fresh();
      expect(a.musicVolume, 0.5);
      expect(a.effectsVolume, 0.5);
    });
  });

  group('la música a cualquier hora', () {
    test('la herramienta da una mezcla distinta para cada momento', () {
      final noche = Sensory.dayMix(tunes.first, 3),
          medio = Sensory.dayMix(tunes.first, 14);
      expect(noche, isNot(medio));
      // Y el reloj da la vuelta: las 24 son las 0.
      for (var i = 0; i < 3; i++) {
        expect(
          Sensory.dayMix(tunes.first, 24)[i],
          closeTo(Sensory.dayMix(tunes.first, 0)[i], 0.001),
        );
      }
    });
  });
}

/// Los wav que están de verdad en la carpeta de sonidos.
Future<Set<String>> _wavsInAssets() async {
  final dir = Directory.current.path;
  final folder = Directory('$dir/assets/sfx');
  return {
    for (final f in folder.listSync())
      if (f.path.endsWith('.wav')) f.uri.pathSegments.last,
  };
}
