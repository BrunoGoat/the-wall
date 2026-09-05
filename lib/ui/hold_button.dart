import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../fx/sensory.dart';
import 'style.dart';

/// The one control in the app.
///
/// Hold it down and a ring closes over about a second and a quarter. Only when
/// the ring completes does the stone go up — the wait is deliberate. It makes
/// placing a brick a decision rather than a twitch, it makes an accidental tap
/// impossible, and the release at the end is what the whole gesture is built
/// around.
class HoldToPlace extends StatefulWidget {
  const HoldToPlace({
    super.key,
    required this.theme,
    required this.onPlace,
    required this.onCharge,
    this.enabled = true,
    this.rapid = false,
  });

  final UiTheme theme;
  final VoidCallback onPlace;

  /// Reports 0..1 while charging, so the wall can react to it.
  final void Function(double charge) onCharge;
  final bool enabled;

  /// Testing aid: keep laying stones for as long as the button is held,
  /// quickening as it goes.
  final bool rapid;

  static const Duration hold = Duration(milliseconds: 1250);

  /// The wait between stones in [rapid] mode: it starts here, shortens by a
  /// seventh each time and never goes below the floor, so a held button
  /// accelerates into a run of masonry rather than a burst of confetti.
  static const double rapidFirst = 0.40;
  static const double rapidFloor = 0.075;
  static const double rapidEase = 0.86;

  @override
  State<HoldToPlace> createState() => _HoldToPlaceState();
}

class _HoldToPlaceState extends State<HoldToPlace>
    with SingleTickerProviderStateMixin {
  // Created in initState, not as a `late final` initialiser: a lazy field is
  // only built on first access, and nothing reads the ticker before dispose,
  // so it would never have started at all.
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// When the current hold started, on the ticker's own clock.
  Duration? _pressedAt;

  double _charge = 0;
  bool _down = false;
  bool _fired = false;

  /// Punch animation after a stone goes up.
  double _punch = 0;
  int _ticksDone = 0;

  /// Rapid mode: how long until the next stone, and how long since the last.
  double _repeatWait = HoldToPlace.rapidFirst;
  double _sinceFire = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final before = _charge;

    if (_down && !_fired) {
      // Measured against the clock rather than accumulated per frame, so the
      // hold always takes the same real time however fast the device draws.
      _pressedAt ??= elapsed;
      _charge = (elapsed - _pressedAt!).inMicroseconds /
          (HoldToPlace.hold.inMicroseconds);
      // A tick of haptic at each quarter, so the charge is felt building.
      final quarters = (_charge * 4).floor().clamp(0, 4);
      if (quarters > _ticksDone) {
        _ticksDone = quarters;
        Sensory.instance.charge(quarters / 4);
      }
      if (_charge >= 1) {
        _charge = 1;
        _fired = true;
        _punch = 1;
        _repeatWait = HoldToPlace.rapidFirst;
        _sinceFire = 0;
        widget.onPlace();
      }
    } else if (_down && _fired && widget.rapid) {
      // Still held after the first stone: keep going, quicker each time.
      _sinceFire += dt;
      if (_sinceFire >= _repeatWait) {
        _sinceFire = 0;
        _repeatWait = math.max(
          HoldToPlace.rapidFloor,
          _repeatWait * HoldToPlace.rapidEase,
        );
        _punch = 1;
        widget.onPlace();
      }
      // The ring runs round again between stones, so the quickening is visible.
      _charge = (_sinceFire / _repeatWait).clamp(0.0, 1.0);
    } else if (_charge > 0) {
      // Letting go early drains it quickly, and visibly.
      _charge = math.max(0, _charge - dt * 3.4);
      if (_charge == 0) _ticksDone = 0;
    }

    if (_punch > 0) _punch = math.max(0, _punch - dt * 2.2);

    if (before != _charge || _punch > 0) {
      // Once the stone is away the wall should settle on it, so stop
      // reporting a charge — otherwise the camera keeps gliding on to
      // wherever the *next* stone would go and leaves the new one behind.
      widget.onCharge(_fired ? 0.0 : _charge);
      if (mounted) setState(() {});
    }
  }

  void _press() {
    if (!widget.enabled) return;
    _down = true;
    _fired = false;
    _ticksDone = 0;
    _pressedAt = null;
    Sensory.instance.press();
    setState(() {});
  }

  void _release() {
    _down = false;
    _fired = false;
    _pressedAt = null;
    _charge = 0;
    _repeatWait = HoldToPlace.rapidFirst;
    _sinceFire = 0;
    widget.onCharge(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final scale = (_down ? 0.97 : 1.0) + _punch * 0.06;

    // A raw pointer listener rather than a GestureDetector: the tap and
    // long-press recognisers fight each other in the gesture arena, and the
    // hand-off between them cancels the hold half a second in. Pointer events
    // never go to arbitration, so the charge just runs.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: SizedBox(
        width: 150,
        height: 122,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _HoldPainter(
                    theme: t,
                    charge: _charge,
                    punch: _punch,
                    down: _down,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w600,
                color: _charge > 0.02
                    ? t.accent
                    : t.fg.withValues(alpha: 0.45),
                shadows: t.halo,
              ),
              child: Text(_down && _fired && widget.rapid
                  ? 'EN OBRA'
                  : (_charge > 0.02 ? 'SOSTENÉ' : 'MANTENER')),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldPainter extends CustomPainter {
  _HoldPainter({
    required this.theme,
    required this.charge,
    required this.punch,
    required this.down,
  });

  final UiTheme theme;
  final double charge, punch;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;
    final fg = theme.fg;

    // A soft breath of shade so the ring reads over pale stone as well as sky.
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 1.35, [
          (theme.dark ? Colors.black : const Color(0xFF3A3426))
              .withValues(alpha: theme.dark ? 0.24 : 0.13),
          Colors.transparent,
        ], [0.55, 1.0]),
    );

    // The track.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = fg.withValues(alpha: 0.30),
    );

    // The charge closing round it.
    if (charge > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = theme.accent,
      );
      canvas.drawCircle(
        c,
        r * (1.0 + 0.5 * charge),
        Paint()
          ..shader = ui.Gradient.radial(c, r * (1.0 + 0.5 * charge), [
            theme.accent.withValues(alpha: 0.22 * charge),
            Colors.transparent,
          ]),
      );
    }

    // The stone waiting in the middle: a small mark that swells as the hold
    // builds, so the gesture has something growing to watch.
    final inner = lerpDouble(r * 0.13, r * 0.62, Curves.easeOut.transform(charge))!;
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..color = Color.lerp(fg.withValues(alpha: 0.55), theme.accent, charge)!
            .withValues(alpha: 0.55 + 0.45 * charge),
    );

    // The ring flies outwards as the stone goes up.
    if (punch > 0) {
      canvas.drawCircle(
        c,
        r + (1 - punch) * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * punch
          ..color = theme.accent.withValues(alpha: punch * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoldPainter old) =>
      old.charge != charge || old.punch != punch || old.down != down;
}
