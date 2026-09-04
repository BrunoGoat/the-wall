import 'dart:math' as math;
import 'dart:ui' as ui;

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
  });

  final UiTheme theme;
  final VoidCallback onPlace;

  /// Reports 0..1 while charging, so the wall can react to it.
  final void Function(double charge) onCharge;
  final bool enabled;

  static const Duration hold = Duration(milliseconds: 1250);

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
        widget.onPlace();
      }
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final scale = (_down ? 0.96 : 1.0) +
        _charge * 0.05 +
        Curves.easeOutBack.transform(1 - _punch) * 0 +
        _punch * 0.10;

    // A raw pointer listener rather than a GestureDetector: the tap and
    // long-press recognisers fight each other in the gesture arena, and the
    // hand-off between them cancels the hold half a second in. Pointer events
    // never go to arbitration, so the charge just runs.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _HoldPainter(
              theme: t,
              charge: _charge,
              punch: _punch,
              down: _down,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 26,
                    color: t.fg.withValues(alpha: _charge > 0.02 ? 1.0 : 0.82),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _charge > 0.02 ? 'SOSTENÉ' : 'MANTENER',
                    style: t.label.copyWith(
                      fontSize: 9,
                      letterSpacing: 2.2,
                      color: t.fg.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final r = size.width * 0.34;

    // The glow builds with the charge, so the button feels like it is loading.
    if (charge > 0.02 || punch > 0) {
      final g = math.max(charge, punch);
      canvas.drawCircle(
        c,
        r * (1.6 + g * 1.2),
        Paint()
          ..shader = ui.Gradient.radial(c, r * (1.6 + g * 1.2), [
            theme.accent.withValues(alpha: 0.34 * g),
            theme.accent.withValues(alpha: 0.0),
          ]),
      );
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = theme.dark
            ? const Color(0xFF17161A).withValues(alpha: 0.72)
            : const Color(0xFFFCF8EE).withValues(alpha: 0.80),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = theme.stroke,
    );

    // The track and the closing ring.
    canvas.drawCircle(
      c,
      r + 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = theme.fg.withValues(alpha: 0.13),
    );
    if (charge > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + 7),
        -math.pi / 2,
        math.pi * 2 * charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round
          ..color = theme.accent,
      );
    }

    // The ring flies outwards as the stone goes up.
    if (punch > 0) {
      final k = 1 - punch;
      canvas.drawCircle(
        c,
        (r + 7) + k * 34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * punch
          ..color = theme.accent.withValues(alpha: punch * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoldPainter old) =>
      old.charge != charge || old.punch != punch || old.down != down;
}
