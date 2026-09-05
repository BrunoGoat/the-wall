/// How fast the town falls quiet when nobody comes back.
///
/// The only rhythm the app still owns outside the town's own plan. Everything
/// else — what gets built, when, and how long it takes — lives in the plan in
/// `engine/town.dart`, expressed purely in achievements.
///
/// The numbers here are chosen for real use, not for a demo:
///
///  * A day and a half of grace, because life happens and a habit that
///    punishes a single missed evening is a habit nobody keeps.
///  * A fortnight from full to nearly dark, so the slide is slow enough to
///    notice and steep enough to mind.
///  * It never reaches zero. What you built stays built; only the lights go
///    out, and one piece turns them all back on.
class Pacing {
  const Pacing._();

  /// Days off before anything at all begins to dim.
  static const double decayGraceDays = 1.6;

  /// Days from the end of that grace to as empty as it ever gets.
  static const double decayFullDays = 14.0;

  /// The floor. A town is never abandoned, only unlit.
  static const double minIntegrity = 0.12;

  static double integrityFor(double daysIdle) {
    if (daysIdle <= decayGraceDays) return 1.0;
    final t = (daysIdle - decayGraceDays) / decayFullDays;
    final v = 1.0 - t;
    if (v < minIntegrity) return minIntegrity;
    return v > 1 ? 1 : v;
  }
}
