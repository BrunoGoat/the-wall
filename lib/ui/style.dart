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
    panel = dark
        ? const Color(0xFF17161A).withValues(alpha: 0.58)
        : const Color(0xFFFCF8EE).withValues(alpha: 0.62);
    panelStrong = dark
        ? const Color(0xFF17161A).withValues(alpha: 0.90)
        : const Color(0xFFFCF8EE).withValues(alpha: 0.94);
    stroke = fg.withValues(alpha: 0.12);
    accent = palette.accent;
  }

  final Palette palette;
  late final bool dark;
  late final Color fg, fgSoft, fgFaint, panel, panelStrong, stroke, accent;

  TextStyle get label => TextStyle(
        color: fgSoft,
        fontSize: 10.5,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w600,
      );

  TextStyle get number => TextStyle(
        color: fg,
        fontSize: 26,
        height: 1.0,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
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
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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

/// A small circular control, used for the camera buttons.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.theme,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final UiTheme theme;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final b = GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? theme.accent.withValues(alpha: 0.85) : theme.panel,
              border: Border.all(color: theme.stroke),
            ),
            child: Icon(icon,
                size: 19, color: active ? Colors.white : theme.fg.withValues(alpha: 0.85)),
          ),
        ),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}
