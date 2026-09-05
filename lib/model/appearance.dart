import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The handful of things about the app that are a preference rather than a
/// record of what you did.
class Appearance extends ChangeNotifier {
  Appearance._();
  static final Appearance instance = Appearance._();

  static const String _rapidKey = 'pueblo_rapid_v1';

  bool _rapid = false;

  /// Testing aid: holding the button keeps laying pieces instead of stopping
  /// at one, so a town long enough to judge can be built in a minute. Off by
  /// default and deliberately awkward to leave on — a piece is an achievement,
  /// and this is the one place in the app where that is not true.
  bool get rapid => _rapid;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rapid = prefs.getBool(_rapidKey) ?? false;
    } catch (_) {
      // A phone that will not give us its preferences still gets a town.
    }
    notifyListeners();
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
