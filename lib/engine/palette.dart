import 'dart:math' as math;
import 'dart:ui';

import '../core/math3.dart';

/// The look of La Muralla: stylised flat-shaded limestone under a big sky.
///
/// Colours are computed, not sampled from textures, so the whole scene shifts
/// coherently with the time of day and with how badly the wall has been
/// neglected.
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
    required this.sunHeight,
    required this.contrast,
  });

  final Color skyTop, skyHorizon, haze, ground, groundFar;
  final Color stone, stoneWarm, stoneCool, mortar;
  final Color sun, skyLight, accent, ink;

  /// 0 = sun on the horizon, 1 = overhead. Drives the light direction.
  final double sunHeight;
  final double contrast;

  V3 get lightDir {
    final el = lerpD(0.22, 0.86, sunHeight);
    final az = lerpD(-1.15, -0.55, sunHeight);
    return V3(math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el))
        .normalized;
  }

  static const _dawn = _PaletteSpec(
    skyTop: Color(0xFF3B4A6B),
    skyHorizon: Color(0xFFF0C9A0),
    haze: Color(0xFFDCC3AC),
    ground: Color(0xFF615E45),
    groundFar: Color(0xFFA39074),
    stone: Color(0xFFDCCDA8),
    stoneWarm: Color(0xFFF6E8C6),
    stoneCool: Color(0xFF8A7B5E),
    mortar: Color(0xFF4F4636),
    sun: Color(0xFFFFD9A6),
    skyLight: Color(0xFF9FB6D8),
    accent: Color(0xFFE8A24A),
    ink: Color(0xFF2A2418),
    sunHeight: 0.16,
    contrast: 1.06,
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
    sun: Color(0xFFFFF3D6),
    skyLight: Color(0xFFAFC6E0),
    accent: Color(0xFFCE8B3A),
    ink: Color(0xFF241F16),
    sunHeight: 0.78,
    contrast: 1.0,
  );

  static const _dusk = _PaletteSpec(
    skyTop: Color(0xFF232C46),
    skyHorizon: Color(0xFFE2925C),
    haze: Color(0xFFB78D74),
    ground: Color(0xFF4A4536),
    groundFar: Color(0xFF8A6E55),
    stone: Color(0xFFD2BF9A),
    stoneWarm: Color(0xFFFBDCA6),
    stoneCool: Color(0xFF6B5F49),
    mortar: Color(0xFF3E3729),
    sun: Color(0xFFFFC078),
    skyLight: Color(0xFF6E7FA8),
    accent: Color(0xFFF0A055),
    ink: Color(0xFF1B1710),
    sunHeight: 0.14,
    contrast: 1.1,
  );

  static const _night = _PaletteSpec(
    skyTop: Color(0xFF0E1424),
    skyHorizon: Color(0xFF3A4560),
    haze: Color(0xFF2C3550),
    ground: Color(0xFF23283A),
    groundFar: Color(0xFF3B4560),
    stone: Color(0xFF98948B),
    stoneWarm: Color(0xFFCFCABA),
    stoneCool: Color(0xFF4A4D5C),
    mortar: Color(0xFF272A3B),
    sun: Color(0xFFBFD0F0),
    skyLight: Color(0xFF5C6C96),
    accent: Color(0xFF89B6E8),
    ink: Color(0xFF0A0D16),
    sunHeight: 0.52,
    contrast: 0.9,
  );

  /// Blends the four time-of-day palettes and then weathers the result by
  /// [integrity] (1 = pristine, 0.12 = long abandoned).
  factory Palette.forMoment(double hourOfDay, double integrity) {
    final specs = <double, _PaletteSpec>{
      0: _night,
      5.0: _night,
      7.0: _dawn,
      10.0: _day,
      17.0: _day,
      19.5: _dusk,
      21.5: _night,
      24.0: _night,
    };
    final keys = specs.keys.toList()..sort();
    var lo = keys.first, hi = keys.last;
    for (var i = 0; i < keys.length - 1; i++) {
      if (hourOfDay >= keys[i] && hourOfDay <= keys[i + 1]) {
        lo = keys[i];
        hi = keys[i + 1];
        break;
      }
    }
    final t = hi == lo ? 0.0 : (hourOfDay - lo) / (hi - lo);
    final spec = _PaletteSpec.lerp(specs[lo]!, specs[hi]!, t);
    return spec.weathered(integrity);
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
    required this.sunHeight,
    required this.contrast,
  });

  final Color skyTop, skyHorizon, haze, ground, groundFar;
  final Color stone, stoneWarm, stoneCool, mortar, sun, skyLight, accent, ink;
  final double sunHeight, contrast;

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
        sunHeight: lerpD(a.sunHeight, b.sunHeight, t),
        contrast: lerpD(a.contrast, b.contrast, t),
      );

  /// Neglect drains the warmth out of everything and thickens the air.
  Palette weathered(double integrity) {
    final decay = 1.0 - integrity.clamp(0.0, 1.0);
    const grim = Color(0xFF6D7367);
    const grimSky = Color(0xFF8A8F92);
    Color w(Color c, double amount) => Color.lerp(c, grim, decay * amount)!;
    Color s(Color c, double amount) => Color.lerp(c, grimSky, decay * amount)!;
    return Palette(
      skyTop: s(skyTop, 0.5),
      skyHorizon: s(skyHorizon, 0.55),
      haze: s(haze, 0.6),
      ground: w(ground, 0.4),
      groundFar: w(groundFar, 0.5),
      stone: w(stone, 0.45),
      stoneWarm: w(stoneWarm, 0.5),
      stoneCool: w(stoneCool, 0.35),
      mortar: w(mortar, 0.3),
      sun: s(sun, 0.6),
      skyLight: s(skyLight, 0.4),
      accent: accent,
      ink: ink,
      sunHeight: sunHeight,
      contrast: lerpD(contrast, 0.82, decay),
    );
  }
}

/// Accent colours available to habits, kept deliberately muted so the limestone
/// stays the hero.
const List<Color> kHabitColors = [
  Color(0xFFD98E3B),
  Color(0xFF6E9E86),
  Color(0xFF5B87B8),
  Color(0xFFB2643F),
  Color(0xFF8E7BB0),
  Color(0xFFC0A03C),
  Color(0xFFA8556A),
  Color(0xFF4E8C8A),
];

const List<String> kHabitGlyphs = [
  '🏃', '📖', '💧', '🧘', '💪', '✍️', '🎸', '🥗',
  '🌱', '🛏️', '🧹', '📞', '🧠', '🎨', '🚭', '☕',
];
