import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fx/sensory.dart';
import 'model/wall_store.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  // The first frame goes up straight away; loading happens behind it, so a
  // slow disk can never turn into a blank screen.
  runApp(const LaMurallaApp());
}

class LaMurallaApp extends StatefulWidget {
  const LaMurallaApp({super.key});

  @override
  State<LaMurallaApp> createState() => _LaMurallaAppState();
}

class _LaMurallaAppState extends State<LaMurallaApp> {
  final WallStore store = WallStore();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await store.load();

    // Development shortcut for inspecting how the wall reads after weeks or a
    // year of real use. Off unless explicitly compiled in.
    const seed = int.fromEnvironment('SEED');
    const idleDays = int.fromEnvironment('IDLE_DAYS');
    if (seed > 0 && store.total == 0) {
      store.debugFill(seed, endedDaysAgo: idleDays);
    }

    if (mounted) setState(() {});
    Sensory.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Muralla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD6C9A8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF9FB6D8),
      ),
      home: store.loaded ? HomeScreen(store: store) : const _Opening(),
    );
  }
}

/// The first half-second: the wall, before there is a wall.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF9FB6D8),
      body: Center(
        child: Text(
          'LA MURALLA',
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
