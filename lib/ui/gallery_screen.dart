import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import 'style.dart';

/// One thing the town knows how to build.
class _Exhibit {
  const _Exhibit.mark(this.landmark) : kind = null, name = '', cost = 0;
  const _Exhibit.house(this.kind, this.name, this.cost) : landmark = null;

  final Landmark? landmark;
  final BuildingKind? kind;
  final String name;
  final int cost;

  String get title => landmark?.name ?? name;
  int get pieces => landmark?.cost ?? cost;
  String get note =>
      landmark?.blurb ?? 'Una de las casas corrientes del pueblo.';
  int get tier => landmark?.tier ?? -1;
  String get id => landmark?.id ?? kind!.name;
}

List<_Exhibit> _catalogue() => [
  for (final k in BuildingKind.values)
    _Exhibit.house(k, buildingName[k]!, buildingCost[k]!),
  for (final m in landmarks) _Exhibit.mark(m),
];

/// The exhibition hall: every structure the town can build, one at a time, in
/// an empty world.
///
/// A landmark turns up once every few hundred achievements and half of them
/// nobody reaches for a year, so nothing about the catalogue is visible from
/// inside a real town. Here each recipe stands on its own ground and can be
/// walked around, and — this is the point — watched going up piece by piece.
/// A chimney standing on thin air or a cottage perched on a bell tower shows
/// up in the middle of a build, not at the end of one.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.theme, this.start = 0});

  final UiTheme theme;

  /// Which exhibit to open on. Only the debug entry point uses it.
  final int start;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final OrbitCamera _cam = OrbitCamera();
  final EffectSystem _fx = EffectSystem();
  final List<PickTarget> _picks = [];
  final List<SignHit> _signs = [];
  final List<_Exhibit> _all = _catalogue();

  late int _at = widget.start.clamp(0, _catalogue().length - 1);

  /// How many pieces of it are standing. Null means all of them.
  int? _step;

  /// Which region's houses and roofs it is being shown in.
  int _character = 0;

  double _time = 0;
  Duration _last = Duration.zero;
  double _lastScale = 1;

  late TownLayout _layout;
  String _layoutKey = '';

  _Exhibit get _it => _all[_at];
  int get _shown => _step ?? _it.pieces;

  @override
  void initState() {
    super.initState();
    _rebuild();
    _frame();
    // Fixed framing for development screenshots.
    const camYaw = int.fromEnvironment('CAM_YAW', defaultValue: -999);
    const camPitch = int.fromEnvironment('CAM_PITCH', defaultValue: -999);
    if (camYaw != -999) _cam.yawTarget = camYaw * math.pi / 180;
    if (camPitch != -999) _cam.pitchTarget = camPitch * math.pi / 180;
    _cam.snap();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0005, 0.05);
    _last = elapsed;
    _time += dt;
    _cam.step(dt);
    _fx.update(dt);
    setState(() {});
  }

  void _rebuild() {
    final ch = TownCharacter.all[_character % TownCharacter.all.length];
    final key = '${_it.id}:$_shown:${ch.order}';
    if (key == _layoutKey) return;
    _layoutKey = key;
    _layout = TownLayout.showcase(
      ch,
      landmark: _it.landmark,
      kind: _it.kind,
      placed: _shown,
    );
  }

  /// Far enough back to take the whole thing in, and aimed a little low so it
  /// sits in the upper half rather than behind the controls.
  void _frame() {
    final full = TownLayout.showcase(
      TownCharacter.all[_character % TownCharacter.all.length],
      landmark: _it.landmark,
      kind: _it.kind,
      placed: _it.pieces,
    );
    var top = 1.0;
    for (final p in full.pieces) {
      if (p.y1 > top) top = p.y1;
    }
    _cam.travelTarget = 0;
    _cam.focusZTarget = 0;
    _cam.focusYTarget = top * 0.45;
    _cam.distanceTarget = clampD(math.max(full.radius * 2.1, top * 2.6), 6, 60);
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.38;
    _cam.wallLength = full.radius * 2;
  }

  void _go(int delta) {
    setState(() {
      _at = (_at + delta) % _all.length;
      if (_at < 0) _at += _all.length;
      if (_step != null) _step = 0;
      _rebuild();
      _frame();
    });
    Sensory.instance.tick();
  }

  void _setStep(int? n) {
    setState(() {
      _step = n?.clamp(0, _it.pieces);
      _rebuild();
    });
  }

  void _pick() async {
    final t = widget.theme;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IndexSheet(all: _all, at: _at, theme: t),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _at = chosen;
      if (_step != null) _step = 0;
      _rebuild();
      _frame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final media = MediaQuery.of(context);
    final palette = Palette.forMoment(11, 1.0);
    _rebuild();

    final scene = TownScene(
      placed: _shown,
      palette: palette,
      camera: _cam,
      integrity: 1,
      time: _time,
      effects: _fx,
      labelledBricks: const {},
      fx: null,
      budget: 4000,
      towns: [
        TownEntry(
          layout: _layout,
          name: _it.title,
          symbol: 'torre',
          integrity: 1,
          placed: _shown,
        ),
      ],
      active: 0,
      finished: null,
      finishedAge: 99,
      selectedBrick: null,
      charge: 0,
      labels: false,
    );

    return Scaffold(
      backgroundColor: palette.skyTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _lastScale = 1,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) {
                  final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
                  _lastScale = d.scale;
                  if (f.isFinite && f > 0) _cam.zoomBy(1 / f);
                } else {
                  _cam.orbitBy(
                    -d.focalPointDelta.dx * 0.0062,
                    d.focalPointDelta.dy * 0.0048,
                  );
                }
              },
              onDoubleTap: () {
                _cam.pitchTarget = _cam.pitchTarget > 0.9 ? 0.28 : 1.42;
                Sensory.instance.tick();
              },
              child: CustomPaint(
                painter: TownPainter(scene, _picks, _signs),
                size: Size.infinite,
                isComplex: true,
                willChange: true,
              ),
            ),
          ),

          // --- what you are looking at
          Positioned(
            top: media.padding.top + 6,
            left: 8,
            right: 8,
            child: _Header(
              theme: t,
              exhibit: _it,
              at: _at,
              total: _all.length,
              onBack: () => Navigator.of(context).pop(),
              onPick: _pick,
            ),
          ),

          // --- the controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Controls(
              theme: t,
              exhibit: _it,
              shown: _shown,
              stepping: _step != null,
              region: TownCharacter
                  .all[_character % TownCharacter.all.length]
                  .region,
              onPrev: () => _go(-1),
              onNext: () => _go(1),
              onWhole: () => _setStep(null),
              onStep: () => _setStep(_shown >= _it.pieces ? 0 : _shown),
              onOne: () => _setStep(math.min(_shown + 1, _it.pieces)),
              onBackOne: () => _setStep(math.max(_shown - 1, 0)),
              onSlide: (v) => _setStep(v),
              onRegion: () {
                setState(() {
                  _character++;
                  _rebuild();
                  _frame();
                });
                Sensory.instance.tick();
              },
              onFrame: () => setState(_frame),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.exhibit,
    required this.at,
    required this.total,
    required this.onBack,
    required this.onPick,
  });

  final UiTheme theme;
  final _Exhibit exhibit;
  final int at, total;
  final VoidCallback onBack, onPick;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tier = exhibit.tier;
    final where = tier < 0
        ? 'CASA · ${exhibit.pieces} PIEZAS'
        : 'HITO ${'·' * (tier + 1)} · ${exhibit.pieces} PIEZAS';

    return Frosted(
      theme: t,
      strong: true,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, size: 20, color: t.fgSoft),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exhibit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(where, style: t.label.copyWith(fontSize: 9)),
              ],
            ),
          ),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(foregroundColor: t.fgSoft),
            child: Text(
              '${at + 1}/$total',
              style: t.bodySoft.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.theme,
    required this.exhibit,
    required this.shown,
    required this.stepping,
    required this.region,
    required this.onPrev,
    required this.onNext,
    required this.onWhole,
    required this.onStep,
    required this.onOne,
    required this.onBackOne,
    required this.onSlide,
    required this.onRegion,
    required this.onFrame,
  });

  final UiTheme theme;
  final _Exhibit exhibit;
  final int shown;
  final bool stepping;
  final String region;
  final VoidCallback onPrev, onNext, onWhole, onStep, onOne, onBackOne;
  final void Function(int) onSlide;
  final VoidCallback onRegion, onFrame;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.palette.ink.withValues(alpha: 0),
            t.palette.ink.withValues(alpha: t.dark ? 0.42 : 0.20),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            exhibit.note,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: t.bodySoft.copyWith(fontSize: 12, shadows: t.halo),
          ),
          const SizedBox(height: 10),

          // Whole, or laid one piece at a time — which is the only way to see
          // a recipe go wrong halfway up.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Pill(theme: t, label: 'Completa', on: !stepping, onTap: onWhole),
              const SizedBox(width: 8),
              _Pill(
                theme: t,
                label: 'Pieza a pieza',
                on: stepping,
                onTap: onStep,
              ),
            ],
          ),

          if (stepping) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: onBackOne,
                  icon: Icon(Icons.remove, size: 20, color: t.fgSoft),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      activeTrackColor: t.accent,
                      inactiveTrackColor: t.stroke,
                      thumbColor: t.accent,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: shown.toDouble().clamp(0, exhibit.pieces * 1.0),
                      max: exhibit.pieces.toDouble(),
                      divisions: math.max(1, exhibit.pieces),
                      onChanged: (v) => onSlide(v.round()),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onOne,
                  icon: Icon(Icons.add, size: 20, color: t.fgSoft),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    '$shown/${exhibit.pieces}',
                    textAlign: TextAlign.right,
                    style: t.bodySoft.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 4),
          Row(
            children: [
              _Round(theme: t, icon: Icons.chevron_left, onTap: onPrev),
              const SizedBox(width: 8),
              _Round(theme: t, icon: Icons.zoom_out_map, onTap: onFrame),
              const Spacer(),
              TextButton(
                onPressed: onRegion,
                style: TextButton.styleFrom(foregroundColor: t.fgSoft),
                child: Text(
                  region.toUpperCase(),
                  style: t.label.copyWith(fontSize: 9.5),
                ),
              ),
              const Spacer(),
              _Round(theme: t, icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.theme,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final UiTheme theme;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? t.accent.withValues(alpha: 0.20)
              : t.fg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? t.accent : t.stroke),
        ),
        child: Text(
          label,
          style: t.bodySoft.copyWith(
            fontSize: 12.5,
            color: on ? t.fg : t.fgSoft,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.theme, required this.icon, required this.onTap});
  final UiTheme theme;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: t.stroke),
        ),
        child: Icon(icon, size: 22, color: t.fgSoft),
      ),
    );
  }
}

/// The whole catalogue as a list, for jumping straight to one.
class _IndexSheet extends StatelessWidget {
  const _IndexSheet({required this.all, required this.at, required this.theme});

  final List<_Exhibit> all;
  final int at;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: t.panelStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.fgFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('TODO LO QUE SE CONSTRUYE', style: t.label),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: all.length,
              itemBuilder: (context, i) {
                final e = all[i];
                final on = i == at;
                return ListTile(
                  dense: true,
                  selected: on,
                  onTap: () => Navigator.of(context).pop(i),
                  leading: SizedBox(
                    width: 34,
                    child: Text(
                      '${i + 1}',
                      style: t.bodySoft.copyWith(fontSize: 11),
                    ),
                  ),
                  title: Text(
                    e.title,
                    style: t.body.copyWith(
                      fontSize: 14,
                      color: on ? t.accent : t.fg,
                    ),
                  ),
                  subtitle: Text(
                    e.tier < 0
                        ? 'casa · ${e.pieces} piezas'
                        : 'hito ${'·' * (e.tier + 1)} · ${e.pieces} piezas',
                    style: t.bodySoft.copyWith(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
