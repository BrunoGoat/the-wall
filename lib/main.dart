import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/character.dart';
import 'fx/sensory.dart';
import 'model/appearance.dart';
import 'model/store.dart';
import 'engine/palette.dart';
import 'ui/gallery_screen.dart';
import 'ui/home_screen.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // The first frame goes up straight away; loading happens behind it, so a
  // slow disk can never turn into a blank screen.
  runApp(const PuebloApp());
}

class PuebloApp extends StatefulWidget {
  const PuebloApp({super.key});

  @override
  State<PuebloApp> createState() => _PuebloAppState();
}

class _PuebloAppState extends State<PuebloApp> with WidgetsBindingObserver {
  final Store store = Store();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leave the app and the valley goes quiet; come back and it starts again.
  ///
  /// Without this the loops keep playing out of a phone that is showing
  /// something else entirely, and the only way to stop them is to throw the
  /// app out of the recents list — which is not something anybody should have
  /// to work out on their own.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Sensory.instance.wake();
    } else {
      Sensory.instance.sleep();
      // And anything changed a moment ago goes to disk now, rather than
      // waiting for a timer that may not get another turn.
      Appearance.instance.flush();
    }
  }

  Future<void> _boot() async {
    await Appearance.instance.load();
    await store.load();

    // Development shortcut for inspecting how the wall reads after weeks or a
    // year of real use. Off unless explicitly compiled in.
    const seed = int.fromEnvironment('SEED');
    const idleDays = int.fromEnvironment('IDLE_DAYS');
    // Which of the six regions to build it in, for looking at one of them on
    // its own. The valley below shows all six at once, but from far enough
    // away that a thatched eave is two pixels.
    const region = int.fromEnvironment('REGION', defaultValue: -1);
    if (seed > 0 && store.total == 0) {
      if (region >= 0) {
        // Founded rather than edited: a town's region is chosen once, when it
        // is founded, and there is no way to change it afterwards on purpose.
        store.addHabit(
          'Leer',
          'libro',
          character: TownCharacter.forSlot(region).order,
        );
        store.removeHabit(0);
      }
      store.debugFill(seed, endedDaysAgo: idleDays);
    }
    // A whole valley, for looking at several habits side by side without
    // keeping four of them for a year first. Off unless compiled in.
    const valley = String.fromEnvironment('VALLEY');
    if (valley.isNotEmpty && store.habits.length == 1) {
      // Seis, que son las seis regiones: un valle de prueba al que le falta
      // una de ellas no sirve para comparar las seis.
      const names = [
        'Leer',
        'Correr',
        'Estudiar',
        'Guitarra',
        'Nadar',
        'Pintar',
      ];
      const symbols = ['libro', 'carrera', 'pesa', 'laud', 'ola', 'pluma'];
      final parts = valley.split(',');
      for (var i = 0; i < parts.length && i < names.length; i++) {
        final bits = parts[i].split(':');
        final n = int.tryParse(bits.first) ?? 0;
        final idle = bits.length > 1 ? (int.tryParse(bits[1]) ?? 0) : 0;
        if (i == 0) {
          store.renameHabit(0, name: names[0], symbol: symbols[0]);
          if (n > 0) store.debugFill(n, endedDaysAgo: idle, into: 0);
        } else {
          store.addHabit(names[i], symbols[i]);
          if (n > 0) store.debugFill(n, endedDaysAgo: idle);
        }
      }
      store.select(0);
    }

    if (mounted) setState(() {});
    Sensory.instance.init();
  }

  static const int _gallery = int.fromEnvironment('GALLERY', defaultValue: -1);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Towny',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD6C9A8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF9FB6D8),
      ),
      // Straight into the exhibition hall, for looking at one recipe without
      // walking through the app to reach it. Off unless compiled in.
      home: !store.loaded
          ? const _Opening()
          : (_gallery >= 0
                ? GalleryScreen(
                    theme: UiTheme(Palette.forMoment(11, 1)),
                    start: _gallery,
                  )
                : HomeScreen(store: store)),
    );
  }
}

/// The first half-second: the valley, before there is a town in it.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FB6D8),
      body: Center(
        child: Text(
          'EL PUEBLO',
          style: TextStyle(
            color: Color(0xCC241F16),
            fontSize: 15,
            letterSpacing: 6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
