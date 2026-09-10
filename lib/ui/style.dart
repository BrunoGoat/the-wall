import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/palette.dart';

/// UI chrome derived from whatever the sky is doing right now, so the interface
/// belongs to the scene instead of sitting on top of it.
class UiTheme {
  UiTheme(this.palette) {
    final l = palette.skyHorizon;
    dark = (l.r * 0.3 + l.g * 0.55 + l.b * 0.15) < 0.45;
    fg = dark ? const Color(0xFFF3EEE3) : const Color(0xFF221D14);
    fgSoft = fg.withValues(alpha: 0.62);
    fgFaint = fg.withValues(alpha: 0.34);
    // Deliberately faint. A panel here should read as a change in the air,
    // not as a card sitting on top of the scene.
    panel = dark
        ? const Color(0xFF14131A).withValues(alpha: 0.40)
        : const Color(0xFFFBF7ED).withValues(alpha: 0.42);
    // Still a change in the air, only more of it. What makes a sheet legible
    // is the blur behind it, not paint: at ninety-five per cent it was a card
    // laid over the town and the town might as well not have been there.
    panelStrong = dark
        ? const Color(0xFF14131A).withValues(alpha: 0.58)
        : const Color(0xFFFBF7ED).withValues(alpha: 0.64);
    stroke = fg.withValues(alpha: 0.07);
    accent = palette.accent;
  }

  final Palette palette;
  late final bool dark;
  late final Color fg, fgSoft, fgFaint, panel, panelStrong, stroke, accent;

  TextStyle get label => TextStyle(
    color: fgSoft,
    fontSize: 9.5,
    letterSpacing: 2.4,
    fontWeight: FontWeight.w600,
  );

  /// A soft halo so type can sit straight on the scene without a card behind
  /// it and still be legible over stone, grass or sky.
  List<Shadow> get halo => [
    Shadow(
      color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
        alpha: dark ? 0.55 : 0.30,
      ),
      blurRadius: 12,
    ),
  ];

  TextStyle get number => TextStyle(
    color: fg,
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w200,
    letterSpacing: -0.8,
    fontFeatures: const [ui.FontFeature.tabularFigures()],
  );

  TextStyle get body => TextStyle(color: fg, fontSize: 14, height: 1.45);

  TextStyle get bodySoft =>
      TextStyle(color: fgSoft, fontSize: 13, height: 1.45);

  TextStyle get title => TextStyle(
    color: fg,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}

/// The scrim behind a sheet.
///
/// Light on purpose: the town is the thing, and a sheet that blacks it out is
/// a sheet that could have been any app's.
Color sheetScrim(bool dark) =>
    Colors.black.withValues(alpha: dark ? 0.34 : 0.24);

/// The one surface every sheet in the app is made of.
///
/// Its colour comes from the sky of the moment, so the same sheet is a
/// different colour at dusk and at noon, and what makes the type legible is
/// the blur rather than the paint.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.theme,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.top = 28,
    this.all = false,
  });

  final UiTheme theme;
  final Widget child;
  final EdgeInsets padding;

  /// How round the top corners are.
  final double top;

  /// True for a sheet that floats rather than sitting on the bottom edge.
  final bool all;

  @override
  Widget build(BuildContext context) {
    final radius = all
        ? BorderRadius.circular(top)
        : BorderRadius.vertical(top: Radius.circular(top));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.panelStrong,
            borderRadius: radius,
            border: Border.all(color: theme.fg.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A frosted panel used for every floating surface in the app.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    required this.theme,
    this.radius = 22,
    this.padding = const EdgeInsets.all(14),
    this.strong = false,
    this.onTap,
  });

  final Widget child;
  final UiTheme theme;
  final double radius;
  final EdgeInsets padding;
  final bool strong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: strong ? 30 : 18,
          sigmaY: strong ? 30 : 18,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: strong ? theme.panelStrong : theme.panel,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.stroke),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// A camera control: just the glyph, with a breath of shade behind it so it
/// stays readable over stone or sky. No disc, no border.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.icon,
    required this.theme,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final UiTheme theme;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final b = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              widget.icon,
              size: 20,
              color: t.fg.withValues(alpha: _down ? 0.95 : 0.62),
              shadows: t.halo,
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? b
        : Tooltip(message: widget.tooltip!, child: b);
  }
}
