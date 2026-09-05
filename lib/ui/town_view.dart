import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../engine/camera.dart';

import '../data/character.dart';
import '../data/landmarks.dart';
import '../engine/town.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/piece.dart';

import '../model/habit.dart';
import '../model/store.dart';

/// Handle the surrounding UI uses to drive the wall.
class TownViewController {
  _TownViewState? _state;

  void place() => _state?.placePiece();

  /// 0..1 while the place button is being held. The wall answers by lighting
  /// up where the stone is about to land.
  void setCharge(double v) => _state?.setCharge(v);
  void clearSelection() => _state?.clearSelection();
  void frameAll() => _state?.frameAll();
  void frameValley() => _state?.frameValley();

  /// True once there is more than one town to compare.
  bool get hasValley => (_state?._entries.length ?? 1) > 1;
  void goToLatest() => _state?.goToLatest();
  void goTo(double x, double z) => _state?.goTo(x, z);
  void resetView() => _state?.resetView();
  double get travel => _state?._cam.travelTarget ?? 0;

  /// How wide the town in front of you reaches, for framing.
  double get townRadius => _state?._town.radius ?? 8;
  Palette? get palette => _state?._palette;
}

class TownView extends StatefulWidget {
  const TownView({
    super.key,
    required this.store,
    required this.controller,
    required this.onTownLandmark,
    required this.onStoneTapped,
    required this.onWhisper,
    required this.onPaletteChanged,
  });

  final Store store;
  final TownViewController controller;

  /// A landmark of the town finished, and which number it is.
  final void Function(Landmark mark, int ordinal) onTownLandmark;
  final void Function(Piece piece) onStoneTapped;
  final void Function(String message) onWhisper;
  final void Function(Palette palette) onPaletteChanged;

  @override
  State<TownView> createState() => _TownViewState();
}

class _TownViewState extends State<TownView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final OrbitCamera _cam = OrbitCamera();
  final EffectSystem _fx = EffectSystem();
  final List<PickTarget> _picks = [];

  late TownLayout _town;
  int _layoutFor = -1;
  int _slotFor = -1;

  /// Every town in the valley, the neighbours included. A neighbour's layout
  /// only changes when its own habit is built in, so they are kept rather than
  /// rebuilt on every piece.
  final Map<String, TownLayout> _valley = {};
  List<TownEntry> _entries = const [];

  PlacementFx? _placement;
  PlaceResult? _pendingResult;

  double _time = 0;
  Duration _last = Duration.zero;

  /// The building that has just been finished, and how long since.
  int? _finished;
  double _finishedAge = 99;

  /// A landmark being shown off: the camera turns slowly around it.
  int? _showcase;
  double _showcaseAge = 0;

  double _displayIntegrity = 1;
  int? _selectedPiece;
  double _charge = 0;

  static const int _budgetOverride =
      int.fromEnvironment('BUDGET', defaultValue: -1);

  /// How many pieces are worth drawing. Given away when the frame gets long
  /// and won back when it does not, so an old phone shows a smaller town
  /// rather than a stuttering one.
  int _budget = _budgetOverride > 0 ? _budgetOverride : 2400;
  double _frameAvg = 16;

  late Palette _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _palette = _buildPalette();
    _rebuildLayout();
    _displayIntegrity = widget.store.integrity;
    _frameTown();
    // Fixed framing for development screenshots.
    const camYaw = int.fromEnvironment('CAM_YAW', defaultValue: -999);
    const camPitch = int.fromEnvironment('CAM_PITCH', defaultValue: -999);
    const camDist = int.fromEnvironment('CAM_DIST', defaultValue: -999);
    if (camYaw != -999) _cam.yawTarget = camYaw * math.pi / 180;
    if (camPitch != -999) _cam.pitchTarget = camPitch * math.pi / 180;
    if (camDist != -999) _cam.distanceTarget = camDist.toDouble();
    // Aims the town camera at a spot on the ground while judging a landmark.
    const camX = int.fromEnvironment('CAM_X', defaultValue: -999);
    const camZ = int.fromEnvironment('CAM_Z', defaultValue: -999);
    if (camX != -999) _cam.travelTarget = camX / 10;
    if (camZ != -999) _cam.focusZTarget = camZ / 10;
    _cam.snap();
    _ticker = createTicker(_tick)..start();
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPaletteChanged(_palette);
    });
  }

  /// One town's layout, kept between frames unless its own count moved.
  TownLayout _layoutOf(Habit h, int? override) {
    final n = override ?? h.total;
    final key = '${h.id}:$n';
    final had = _valley[key];
    if (had != null) return had;
    // Only ever one layout per habit in flight: the old one is dropped the
    // moment its count changes.
    _valley.removeWhere((k, _) => k.startsWith('${h.id}:'));
    final (cx, cz) = Habit.centreOf(h.slot);
    return _valley[key] =
        TownLayout(n, TownCharacter.forSlot(h.slot), cx: cx, cz: cz);
  }

  /// Puts the camera where a town is best first seen: from its own plaza,
  /// far enough back to take it in.
  void _frameTown() {
    _cam.travelTarget = _town.cx;
    _cam.focusZTarget = _town.cz;
    _cam.focusYTarget = 1.4;
    _cam.distanceTarget = clampD(_town.radius * 1.9, 9.0, 60.0);
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.46;
    _cam.wallLength = _town.radius * 2;
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final store = widget.store;
    if (store.shownTotal != _layoutFor || store.habit.slot != _slotFor) {
      _rebuildLayout();
    }
  }

  void _rebuildLayout() {
    final store = widget.store;
    final wasSlot = _slotFor;

    _entries = [
      for (final h in store.habits)
        TownEntry(
          layout: _layoutOf(h, h.id == store.habit.id ? store.shownTotal : null),
          name: h.name,
          symbol: h.symbol,
          integrity: Store.integrityOf(h),
          placed: h.id == store.habit.id ? store.shownTotal : h.total,
        ),
    ];
    _town = _entries[store.active.clamp(0, _entries.length - 1)].layout;
    _layoutFor = store.shownTotal;
    _slotFor = store.habit.slot;
    _cam.wallLength = _town.radius * 2;
    // Moving to another habit is moving to another town: take the camera
    // there rather than leaving it hanging over an empty valley.
    if (wasSlot != _slotFor) {
      _frameTown();
      _fx.clear();
      _placement = null;
      _finished = null;
      _showcase = null;
    }
  }

  /// Overrides the clock during development so every time of day can be
  /// inspected without waiting for it.
  static const int _hourOverride = int.fromEnvironment('HOUR', defaultValue: -1);

  Palette _buildPalette() {
    final now = DateTime.now();
    final hour =
        _hourOverride >= 0 ? _hourOverride.toDouble() : now.hour + now.minute / 60.0;
    return Palette.forMoment(hour, _displayIntegrity);
  }

  // ------------------------------------------------------------------ tick

  void _tick(Duration elapsed) {
    final dtRaw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final dt = dtRaw.clamp(0.0005, 0.05);
    _time += dt;

    if (_budgetOverride <= 0) {
      _frameAvg = _frameAvg * 0.92 + dtRaw * 1000 * 0.08;
      if (_frameAvg > 21 && _budget > 700) {
        _budget -= 40;
      } else if (_frameAvg < 13 && _budget < 4200) {
        _budget += 24;
      }
    }

    _cam.step(dt);
    _fx.update(dt);
    if (_finished != null) {
      _finishedAge += dt;
      if (_finishedAge > 2.6) _finished = null;
    }
    _turnAround(dt);

    final p = _placement;
    if (p != null) {
      final wasLanded = p.landed;
      p.update(dt);
      if (!wasLanded && p.landed) _onImpact(p);
      if (p.done) _placement = null;
    }

    final target = widget.store.integrity;
    _displayIntegrity +=
        (target - _displayIntegrity) * (1 - math.exp(-dt * 1.4));

    _spawnAmbient(dt);

    // What the valley sounds like from here: a big, kept-up town has people in
    // it; a small or abandoned one keeps the wind and loses the voices.
    final size01 = math.sqrt(widget.store.shownTotal / 900.0).clamp(0.0, 1.0);
    Sensory.instance.ambience(size01, _displayIntegrity);
    Sensory.instance.ambientOneShot(dt, size01, _displayIntegrity);

    final pal = _buildPalette();
    _palette = pal;

    if (mounted) setState(() {});
  }

  /// The slow turn around a finished landmark, and the slower one the town
  /// takes on its own when nobody has touched it for a while.
  ///
  /// A town that sits perfectly still is a photograph. One that keeps turning,
  /// a degree every few seconds, is a place you keep watching without deciding
  /// to — which is exactly what it should be doing while you are not building.
  void _turnAround(double dt) {
    
    final show = _showcase;
    if (show != null) {
      _showcaseAge += dt;
      if (_showcaseAge > 6.5) {
        _showcase = null;
      } else {
        _cam.yawTarget += dt * 0.28;
        _cam.follow = false;
        return;
      }
    }
    _idleFor += dt;
    if (_idleFor > 5.0) {
      // Eases in over a couple of seconds so it never starts with a jolt.
      final k = clampD((_idleFor - 5.0) / 2.5, 0, 1);
      _cam.yawTarget += dt * 0.05 * k;
    }
  }

  double _idleFor = 0;
  void _touched() => _idleFor = 0;

  int _ambientCounter = 0;

  /// The town smoking away on its own.
  ///
  /// A chimney with smoke coming out of it is the cheapest thing in the whole
  /// app and the one that most makes the place look lived in: it turns a model
  /// of a town into a town where somebody has just lit a fire.
  void _spawnAmbient(double dt) {
    _ambientCounter++;
    final town = _town;
    final take = math.min(widget.store.shownTotal, town.pieces.length);
    if (take <= 0) return;

    // The same gust the renderer leans everything else with.
    final wx = math.sin(_time * 0.31) * 0.34 + 0.12;
    final wz = math.cos(_time * 0.23) * 0.26 - 0.08;

    // A handful of chimneys per frame, chosen round-robin so every one of them
    // gets its turn without the cost of walking the whole town.
    var found = 0;
    for (var k = 0; k < 40 && found < 3; k++) {
      final i = (_ambientCounter * 7 + k * 131) % take;
      final piece = town.pieces[i];
      if (piece.kind != PieceKind.chimney) continue;
      final dx = piece.cx - _cam.travel, dz = piece.cz - _cam.focusZ;
      if (dx * dx + dz * dz > 26 * 26) continue;
      // Not every hearth is lit, the same ones stay lit — and they go out as
      // the days go by without anybody laying a piece. A town with no smoke
      // over it is the most legible way of saying nobody has been here.
      final lit = 0.62 * _displayIntegrity * _displayIntegrity;
      if (hash01(piece.seed, 91) > lit) continue;
      found++;
      if (_ambientCounter % 4 != 0) continue;
      _fx.smoke(piece.cx, piece.y1 + 0.06, piece.cz, wx, wz);
    }

    // Sun on the water.
    if (_palette.isDaylight && _ambientCounter % 5 == 0) {
      for (var k = 0; k < 26; k++) {
        final i = (_ambientCounter * 13 + k * 97) % take;
        final piece = town.pieces[i];
        if (piece.kind != PieceKind.water) continue;
        final dx = piece.cx - _cam.travel, dz = piece.cz - _cam.focusZ;
        if (dx * dx + dz * dz > 20 * 20) continue;
        _fx.glint(
          piece.cx + hashJitter(piece.w * 0.42, _ambientCounter, k, 1),
          0.07,
          piece.cz + hashJitter(piece.d * 0.42, _ambientCounter, k, 2),
        );
        break;
      }
    }
  }


  /// Where the camera should sit to watch a piece land, in whichever world we
  /// are building. The wall travels along its own axis; the town orbits its
  /// plaza, so the most the camera does there is look at the right height.
  void _followPlacement(int index) {
    final piece = _town.pieceFor(index);
    if (piece == null) return;
    _cam.follow = true;
    _cam.travelTo(piece.cx);
    _cam.focusZTarget = piece.cz;
    _cam.focusYTarget = clampD(piece.y1 + 0.6, 1.0, 6.0);
    if (_cam.distanceTarget > 20) _cam.distanceTarget = 15;
  }

  // --------------------------------------------------------------- placing

  void placePiece() {
    _touched();
    _showcase = null;
    final store = widget.store;
    final wasDecaying = store.integrity < 0.995;
    final before = store.integrity;
    store.setPreview(null);
    final result = store.placePiece();
    _selectedPiece = null;
    _followPlacement(result.piece.index);
    if (wasDecaying) _displayIntegrity = before;
    _pendingResult = result;
    // In the town a piece is set down, not dropped from a crane: from high up
    // it reads as a bug, and the anticipation is in the shadow closing under
    // it rather than in the height it falls from.
    _placement = PlacementFx(result.piece.index,
        dropHeight: 2.3);
    setState(() {});
  }

  /// The town's version of the landing: the shake and the sound, and a
  /// celebration when a building is finished rather than when a milestone is.
  void _onImpact(PlacementFx fx) {
    final town = _town;
    final piece = town.pieceFor(fx.brickIndex);
    final result = _pendingResult;
    _pendingResult = null;
    if (piece == null) return;

    _fx.impact(V3(piece.cx, piece.y0, piece.cz), piece.w * 0.7, strength: 1.1);
    _cam.shake = 0.05;
    Sensory.instance.impact(strength: 1.1);

    final building = town.buildings[piece.building];
    final done = piece.index == building.firstPiece + building.cost - 1;
    if (done) {
      _finished = building.index;
      _finishedAge = 0;
      _fx.celebrate(
        V3(building.cx, 0, building.cz),
        (building.isLandmark ? 1.9 : 1.15),
        count: building.isLandmark ? 52 : 30,
      );
      // Step back far enough to see the whole of what was just finished. The
      // point of the moment is the building, not the confetti.
      _cam.follow = false;
      _cam.travelTo(building.cx);
      _cam.focusZTarget = building.cz;
      // Aimed a little low, so the building sits in the upper half of the
      // screen and the card that comes up has somewhere to go.
      _cam.focusYTarget = clampD(building.peakY * 0.18, 0.3, 2.2);
      _cam.pitchTarget = clampD(_cam.pitchTarget, 0.14, 0.34);
      _cam.distanceTarget = clampD(building.peakY * 2.6 + 4.0, 9, 28);
      Future.delayed(const Duration(milliseconds: 220), () {
        Sensory.instance.milestone();
      });
      final mark = building.landmark;
      if (mark != null) {
        var ordinal = 0;
        for (final b in town.buildings) {
          if (b.isLandmark && b.index <= building.index) ordinal++;
        }
        // The camera takes a slow turn around it while the card is up: it is
        // the one moment where the thing itself is worth looking at from more
        // than one side.
        _showcase = building.index;
        _showcaseAge = 0;
        widget.onTownLandmark(mark, ordinal);
      } else {
        widget.onWhisper('${building.name} en pie');
      }
    }
    if (result != null && result.relit) {
      widget.onWhisper('El pueblo vuelve a encenderse');
    }
  }

  // ---------------------------------------------------------------- camera

  /// The whole valley: every town at once, from high enough to take them all
  /// in. This is the view that answers how the habits are doing against each
  /// other, so it is one tap away rather than a gesture nobody finds.
  void frameValley() {
    _touched();
    var far = 20.0;
    for (final e in _entries) {
      final d = math.sqrt(e.layout.cx * e.layout.cx + e.layout.cz * e.layout.cz);
      if (d + e.layout.radius > far) far = d + e.layout.radius;
    }
    _cam.travelTarget = 0;
    _cam.focusZTarget = 0;
    _cam.focusYTarget = 2.0;
    _cam.wallLength = far * 2;
    _cam.distanceTarget = clampD(far * 1.5, 20, OrbitCamera.maxDistance);
    _cam.pitchTarget = 0.62;
    _cam.follow = false;
    Sensory.instance.tick();
  }

  /// The whole of this town, from its own plaza.
  void frameAll() {
    _touched();
    _cam.travelTarget = _town.cx;
    _cam.focusZTarget = _town.cz;
    _cam.focusYTarget = 1.8;
    _cam.distanceTarget = clampD(_town.radius * 2.4, 9, 90);
    _cam.pitchTarget = 0.52;
    _cam.follow = false;
    Sensory.instance.tick();
  }

  void goToLatest() {
    _touched();
    _followPlacement(widget.store.shownTotal - 1);
    Sensory.instance.tick();
  }

  /// Looks at a spot on the valley floor, for the map and the landmark list.
  void goTo(double x, double z) {
    _touched();
    _cam.travelTo(x);
    _cam.focusZTarget = z;
    _cam.follow = false;
  }

  void resetView() {
    _touched();
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.34;
    _cam.focusYTarget = 1.4;
    _cam.distanceTarget = clampD(_town.radius * 1.6, 9, 40);
    Sensory.instance.tick();
  }

  // -------------------------------------------------------------- gestures

  double _lastScale = 1;

  void _onScaleStart(ScaleStartDetails d) {
    _lastScale = 1;
    _touched();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    _touched();
    if (d.pointerCount >= 2) {
      final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = d.scale;
      if (f.isFinite && f > 0) _cam.zoomBy(1 / f);
      _travelByDrag(d.focalPointDelta);
    } else {
      final dx = d.focalPointDelta.dx;
      final dy = d.focalPointDelta.dy;
      _cam.orbitBy(-dx * 0.0062, dy * 0.0048);
      _cam.follow = false;
    }
  }

  /// Two-finger drag walks the camera along the wall, in whatever screen
  /// direction the wall happens to run right now.
  void _travelByDrag(Offset delta) {
    final size = context.size;
    if (size == null) return;
    final p = _cam.projector(size.width, size.height, _time);
    final ax = p.right.x;
    final ay = -p.up.x;
    final len = math.sqrt(ax * ax + ay * ay);
    if (len < 0.02) return;
    final along = (delta.dx * ax + delta.dy * ay) / len;
    final worldPerPixel = _cam.distance / (p.focal * len);
    _cam.travelBy(-along * worldPerPixel);
  }

  void _onTapUp(TapUpDetails d) {
    final pos = d.localPosition;
    PickTarget? best;
    var bestD = double.infinity;
    for (final t in _picks) {
      final dx = t.cx - pos.dx, dy = t.cy - pos.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      // A stone that already carries a note is a slightly easier target.
      final reach = t.labelled ? t.radius * 1.4 + 8 : t.radius;
      if (dist < reach && dist < bestD) {
        bestD = dist;
        best = t;
      }
    }
    if (best == null) {
      if (_selectedPiece != null) setState(() => _selectedPiece = null);
      return;
    }

    final brick = widget.store.pieceAt(best.brickIndex);
    if (brick == null) return;
    setState(() => _selectedPiece = brick.index);
    Sensory.instance.tick();
    widget.onStoneTapped(brick);
  }

  void setCharge(double v) {
    if ((_charge - v).abs() < 0.004) return;
    _charge = v;
    // Glide over to where the stone is going while the button is held, so the
    // landing is always in frame.
    if (v > 0.05) _followPlacement(widget.store.shownTotal);
  }

  void clearSelection() {
    if (_selectedPiece != null && mounted) {
      setState(() => _selectedPiece = null);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final scene = TownScene(
      placed: store.shownTotal,
      palette: _palette,
      camera: _cam,
      integrity: _displayIntegrity,
      time: _time,
      effects: _fx,
      labelledBricks: {
        for (final p in store.pieces)
          if (p.hasLabel) p.index,
      },
      fx: _placement,
      budget: _budget,
      towns: _entries,
      active: widget.store.active.clamp(0, _entries.length - 1),
      finished: _finished,
      finishedAge: _finishedAge,
      selectedBrick: _selectedPiece,
      charge: _charge,
    );

    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _cam.zoomBy(1 + e.scrollDelta.dy * 0.0012);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: _onTapUp,
        onDoubleTap: () {
          _cam.pitchTarget = _cam.pitchTarget > 0.9 ? 0.28 : 1.42;
          Sensory.instance.tick();
        },
        child: CustomPaint(
          painter: TownPainter(scene, _picks),
          size: Size.infinite,
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}
