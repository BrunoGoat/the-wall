import 'dart:math' as math;
import 'dart:ui';

import '../core/math3.dart';

/// The look of La Muralla: stylised flat-shaded limestone under a big sky.
///
/// Colours are computed rather than sampled, so the whole scene moves with the
/// real clock: the sun climbs and sets, the moon takes over, shadows swing
/// round through the day, and everything drains as the wall is neglected.
class Palette {
  Palette({
    required this.skyTop,
    required this.skyHorizon,
    required this.haze,
    required this.ground,
    required this.groundFar,
    required this.stone,
    required this.stoneWarm,
    required this.stoneCool,
    required this.mortar,
    required this.sun,
    required this.skyLight,
    required this.accent,
    required this.ink,
    required this.contrast,
    required this.hour,
    required this.starAlpha,
  });

  final Color skyTop, skyHorizon, haze, ground, groundFar;
  final Color stone, stoneWarm, stoneCool, mortar;
  final Color sun, skyLight, accent, ink;
  final double contrast;

  /// Local time of day, 0..24.
  final double hour;

  /// How visible the stars are, 0..1.
  final double starAlpha;

  /// Where the sun is, whether or not it is above the horizon.
  ///
  /// It rises in the east at 06:00, is overhead around 13:00 and sets in the
  /// west at 20:00. This is what makes the shadows swing across the ground
  /// over the course of a day.
  V3 get sunDir {
    const rise = 6.0, set = 20.0;
    final t = (hour - rise) / (set - rise); // 0 at sunrise, 1 at sunset
    final a = t * math.pi;
    final elev = math.sin(a) * 1.16 - 0.07;
    final az = math.cos(a) * 1.25; // east -> west
    return V3(
      math.sin(az) * math.cos(elev),
      math.sin(elev),
      math.cos(az) * math.cos(elev),
    ).normalized;
  }

  bool get isDaylight => sunDir.y > 0.02;

  /// The moon rides the opposite arc, so there is still a direction to the
  /// light at night instead of flat ambience.
  V3 get moonDir {
    final s = sunDir;
    final m = V3(-s.x, -s.y, -s.z);
    return V3(m.x, math.max(m.y, 0.28), m.z).normalized;
  }

  /// The body actually lighting the scene right now.
  V3 get lightDir => isDaylight ? sunDir : moonDir;

  /// How strongly the key light reads, 0..1. Low at the horizon.
  double get lightStrength =>
      isDaylight ? clampD(0.45 + sunDir.y * 0.9, 0.35, 1.0) : 0.42;

  static const _night = _PaletteSpec(
    skyTop: Color(0xFF090E1C),
    skyHorizon: Color(0xFF27314C),
    haze: Color(0xFF1D2740),
    ground: Color(0xFF191E2E),
    groundFar: Color(0xFF2C3550),
    stone: Color(0xFF8C8C92),
    stoneWarm: Color(0xFFC4C2BE),
    stoneCool: Color(0xFF454A5E),
    mortar: Color(0xFF1F2336),
    sun: Color(0xFFE6EDFF),
    skyLight: Color(0xFF54648E),
    accent: Color(0xFF89B6E8),
    ink: Color(0xFF060911),
    contrast: 0.86,
    starAlpha: 1.0,
  );

  static const _dawn = _PaletteSpec(
    skyTop: Color(0xFF2C3C66),
    skyHorizon: Color(0xFFE9A578),
    haze: Color(0xFFC5A28C),
    ground: Color(0xFF4C4A42),
    groundFar: Color(0xFF8C7B68),
    stone: Color(0xFFC9BB9D),
    stoneWarm: Color(0xFFF3D5B0),
    stoneCool: Color(0xFF6C6353),
    mortar: Color(0xFF3C362E),
    sun: Color(0xFFFFC98A),
    skyLight: Color(0xFF7E90BE),
    accent: Color(0xFFE8A24A),
    ink: Color(0xFF17140F),
    contrast: 1.06,
    starAlpha: 0.30,
  );

  static const _morning = _PaletteSpec(
    skyTop: Color(0xFF4B7CB6),
    skyHorizon: Color(0xFFE7DDC8),
    haze: Color(0xFFD0C9B5),
    ground: Color(0xFF6C7250),
    groundFar: Color(0xFF9DA37D),
    stone: Color(0xFFE0D3B0),
    stoneWarm: Color(0xFFF9F1DC),
    stoneCool: Color(0xFF897D5D),
    mortar: Color(0xFF52483A),
    sun: Color(0xFFFFF7E2),
    skyLight: Color(0xFFA6BEDC),
    accent: Color(0xFFCE8B3A),
    ink: Color(0xFF1F1B13),
    contrast: 1.02,
    starAlpha: 0.0,
  );

  static const _day = _PaletteSpec(
    skyTop: Color(0xFF5F8CBE),
    skyHorizon: Color(0xFFDFD9C6),
    haze: Color(0xFFCFC9B6),
    ground: Color(0xFF6B7052),
    groundFar: Color(0xFF9BA37C),
    stone: Color(0xFFE2D5B2),
    stoneWarm: Color(0xFFF9F1DC),
    stoneCool: Color(0xFF8F805F),
    mortar: Color(0xFF564C3B),
    sun: Color(0xFFFFF9EC),
    skyLight: Color(0xFFAFC6E0),
    accent: Color(0xFFCE8B3A),
    ink: Color(0xFF241F16),
    contrast: 1.0,
    starAlpha: 0.0,
  );

  static const _golden = _PaletteSpec(
    skyTop: Color(0xFF48709F),
    skyHorizon: Color(0xFFF2C68B),
    haze: Color(0xFFD9BC98),
    ground: Color(0xFF67623F),
    groundFar: Color(0xFFA69266),
    stone: Color(0xFFE9D3A6),
    stoneWarm: Color(0xFFFFEBC2),
    stoneCool: Color(0xFF877046),
    mortar: Color(0xFF4B412F),
    sun: Color(0xFFFFD79A),
    skyLight: Color(0xFF93A9CE),
    accent: Color(0xFFE09A45),
    ink: Color(0xFF1D1710),
    contrast: 1.08,
    starAlpha: 0.0,
  );

  static const _dusk = _PaletteSpec(
    skyTop: Color(0xFF212A45),
    skyHorizon: Color(0xFFE2925C),
    haze: Color(0xFFB08770),
    ground: Color(0xFF4A4536),
    groundFar: Color(0xFF8A6E55),
    stone: Color(0xFFD2BF9A),
    stoneWarm: Color(0xFFFBDCA6),
    stoneCool: Color(0xFF6B5F49),
    mortar: Color(0xFF3E3729),
    sun: Color(0xFFFFB878),
    skyLight: Color(0xFF6E7FA8),
    accent: Color(0xFFF0A055),
    ink: Color(0xFF181410),
    contrast: 1.1,
    starAlpha: 0.22,
  );

  static const _twilight = _PaletteSpec(
    skyTop: Color(0xFF121830),
    skyHorizon: Color(0xFF6B5473),
    haze: Color(0xFF423857),
    ground: Color(0xFF2B2B3A),
    groundFar: Color(0xFF524C68),
    stone: Color(0xFF9E96A0),
    stoneWarm: Color(0xFFD6C6C4),
    stoneCool: Color(0xFF534D62),
    mortar: Color(0xFF282637),
    sun: Color(0xFFCBCEEA),
    skyLight: Color(0xFF666C9A),
    accent: Color(0xFFB08AC0),
    ink: Color(0xFF0A0C16),
    contrast: 0.92,
    starAlpha: 0.72,
  );

  /// The full cycle: (hour, look), in order.
  static const List<(double, _PaletteSpec)> _cycle = [
    (0.0, _night),
    (4.3, _night),
    (5.6, _dawn),
    (7.2, _dawn),
    (9.0, _morning),
    (11.5, _day),
    (16.0, _day),
    (18.0, _golden),
    (19.6, _dusk),
    (20.8, _twilight),
    (22.2, _night),
    (24.0, _night),
  ];

  /// Blends the cycle at [hourOfDay] and then weathers it by [integrity]
  /// (1 = pristine, 0.12 = long abandoned).
  factory Palette.forMoment(double hourOfDay, double integrity) {
    final h = hourOfDay % 24.0;
    var lo = _cycle.first, hi = _cycle.last;
    for (var i = 0; i < _cycle.length - 1; i++) {
      if (h >= _cycle[i].$1 && h <= _cycle[i + 1].$1) {
        lo = _cycle[i];
        hi = _cycle[i + 1];
        break;
      }
    }
    final span = hi.$1 - lo.$1;
    final raw = span <= 0 ? 0.0 : (h - lo.$1) / span;
    // Ease the crossfade so dawn and dusk linger instead of snapping.
    final t = raw * raw * (3 - 2 * raw);
    return _PaletteSpec.lerp(lo.$2, hi.$2, t).weathered(integrity, h);
  }
}

class _PaletteSpec {
  const _PaletteSpec({
    required this.skyTop,
    required this.skyHorizon,
    required this.haze,
    required this.ground,
    required this.groundFar,
    required this.stone,
    required this.stoneWarm,
    required this.stoneCool,
    required this.mortar,
    required this.sun,
    required this.skyLight,
    required this.accent,
    required this.ink,
    required this.contrast,
    required this.starAlpha,
  });

  final Color skyTop, skyHorizon, haze, ground, groundFar;
  final Color stone, stoneWarm, stoneCool, mortar, sun, skyLight, accent, ink;
  final double contrast, starAlpha;

  static Color _l(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static _PaletteSpec lerp(_PaletteSpec a, _PaletteSpec b, double t) =>
      _PaletteSpec(
        skyTop: _l(a.skyTop, b.skyTop, t),
        skyHorizon: _l(a.skyHorizon, b.skyHorizon, t),
        haze: _l(a.haze, b.haze, t),
        ground: _l(a.ground, b.ground, t),
        groundFar: _l(a.groundFar, b.groundFar, t),
        stone: _l(a.stone, b.stone, t),
        stoneWarm: _l(a.stoneWarm, b.stoneWarm, t),
        stoneCool: _l(a.stoneCool, b.stoneCool, t),
        mortar: _l(a.mortar, b.mortar, t),
        sun: _l(a.sun, b.sun, t),
        skyLight: _l(a.skyLight, b.skyLight, t),
        accent: _l(a.accent, b.accent, t),
        ink: _l(a.ink, b.ink, t),
        contrast: lerpD(a.contrast, b.contrast, t),
        starAlpha: lerpD(a.starAlpha, b.starAlpha, t),
      );

  /// Neglect drains the warmth out of everything and thickens the air.
  Palette weathered(double integrity, double hour) {
    final decay = 1.0 - integrity.clamp(0.0, 1.0);
    const grim = Color(0xFF6D7367);
    const grimSky = Color(0xFF8A8F92);
    Color w(Color c, double amount) => Color.lerp(c, grim, decay * amount)!;
    Color s(Color c, double amount) => Color.lerp(c, grimSky, decay * amount)!;
    return Palette(
      skyTop: s(skyTop, 0.45),
      skyHorizon: s(skyHorizon, 0.52),
      haze: s(haze, 0.58),
      ground: w(ground, 0.40),
      groundFar: w(groundFar, 0.48),
      stone: w(stone, 0.45),
      stoneWarm: w(stoneWarm, 0.50),
      stoneCool: w(stoneCool, 0.35),
      mortar: w(mortar, 0.30),
      sun: s(sun, 0.5),
      skyLight: s(skyLight, 0.40),
      accent: accent,
      ink: ink,
      contrast: lerpD(contrast, 0.84, decay),
      hour: hour,
      starAlpha: starAlpha * (1 - decay * 0.7),
    );
  }
}
