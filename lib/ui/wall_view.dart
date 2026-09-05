import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/milestones.dart';
import '../data/pacing.dart';
import '../engine/camera.dart';
import '../data/landmarks.dart';
import '../engine/city.dart';
import '../engine/layout.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/models.dart';
import '../model/appearance.dart';
import '../model/wall_store.dart';

/// Handle the surrounding UI uses to drive the wall.
class WallViewController {
  _WallViewState? _state;

  void place() => _state?.placeBrick();

  /// 0..1 while the place button is being held. The wall answers by lighting
  /// up where the stone is about to land.
  void setCharge(double v) => _state?.setCharge(v);
  void clearSelection() => _state?.clearSelection();
  void frameAll() => _state?.frameAll();
  void goToLatest() => _state?.goToLatest();
  void goToX(double x) => _state?.goToX(x);
  void resetView() => _state?.resetView();
  double get travel => _state?._cam.travelTarget ?? 0;
  double get wallLength => _state?._layout.length ?? 0;
  List<StructureInstance> get structures =>
      _state?._layout.structures ?? const [];
  Palette? get palette => _state?._palette;
}

class WallView extends StatefulWidget {
  const WallView({
    super.key,
    required this.store,
    required this.controller,
    required this.onMilestoneComplete,
    required this.onTownLandmark,
    required this.onStoneTapped,
    required this.onWhisper,
    required this.onPaletteChanged,
  });

  final WallStore store;
  final WallViewController controller;
  final void Function(PlanSegment seg) onMilestoneComplete;

  /// A landmark of the town finished, and which number it is.
  final void Function(Landmark mark, int ordinal) onTownLandmark;
  final void Function(Brick brick) onStoneTapped;
  final void Function(String message) onWhisper;
  final void Function(Palette palette) onPaletteChanged;

  @override
  State<WallView> createState() => _WallViewState();
}

class _WallViewState extends State<WallView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final OrbitCamera _cam = OrbitCamera();
  final EffectSystem _fx = EffectSystem();
  final List<PickTarget> _picks = [];

  WallLayout _layout = WallLayout(0);
  CityLayout? _city;
  int _layoutFor = -1;
  World _worldFor = World.wall;

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
  double? _repairSweep;
  int? _selectedBrick;
  double _charge = 0;

  static const int _budgetOverride =
      int.fromEnvironment('BUDGET', defaultValue: -1);
  int _detailBudget = _budgetOverride > 0 ? _budgetOverride : 300;

  /// Stones drawn as plain blocks past the detailed band. Generous on purpose:
  /// a wall that turns into a smooth ribbon a few metres from the camera is
  /// the single most obvious thing wrong with it, and a block costs a fraction
  /// of what a chipped stone costs.
  int _coarseBudget = 1600;
  double _frameAvg = 16;

  late Palette _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _palette = _buildPalette();
    _rebuildLayout();
    _displayIntegrity = widget.store.integrity;
    final city0 = _city;
    if (city0 != null) {
      _cam.travelTarget = 0;
      _cam.focusYTarget = 1.4;
      _cam.distanceTarget = clampD(city0.radius * 1.9, 9.0, 60.0);
      _cam.yawTarget = 0.62;
      _cam.pitchTarget = 0.46;
    } else {
      _cam.travelTarget = math.max(1.5, _layout.length - 3.5);
      _cam.distanceTarget = clampD(9.0 + _layout.length * 0.42, 9.0, 34.0);
      _cam.yawTarget = 0.62;
      _cam.pitchTarget = 0.30;
    }
    // Fixed framing for development screenshots.
    const camYaw = int.fromEnvironment('CAM_YAW', defaultValue: -999);
    const camPitch = int.fromEnvironment('CAM_PITCH', defaultValue: -999);
    const camDist = int.fromEnvironment('CAM_DIST', defaultValue: -999);
    const camAt = int.fromEnvironment('CAM_AT', defaultValue: -999);
    if (camYaw != -999) _cam.yawTarget = camYaw * math.pi / 180;
    if (camPitch != -999) _cam.pitchTarget = camPitch * math.pi / 180;
    if (camDist != -999) _cam.distanceTarget = camDist.toDouble();
    if (camAt != -999) _cam.travelTarget = _layout.length * camAt / 100;
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

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (widget.store.shownTotal != _layoutFor ||
        Appearance.instance.world != _worldFor) {
      _rebuildLayout();
    }
  }

  void _rebuildLayout() {
    final was = _layout.length;
    final world = Appearance.instance.world;
    _worldFor = world;
    _layout = WallLayout(widget.store.shownTotal);
    _city = world == World.city ? CityLayout(widget.store.shownTotal) : null;
    _layoutFor = widget.store.shownTotal;
    // The town orbits its own plaza, so the camera's travel axis is spent on
    // its width instead of the wall's length.
    final city = _city;
    if (city != null) {
      _cam.wallLength = city.radius * 2;
      return;
    }
    _cam.wallLength = _layout.length;
    // A preview can change the wall's size by orders of magnitude; reframe so
    // it is not left staring at empty ground.
    if (was > 0 && (_layout.length / was > 1.8 || _layout.length / was < 0.55)) {
      _cam.frameAll();
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
      // The coarse band is given up first and won back last: losing the far
      // masonry is much more noticeable than losing a few chipped corners.
      if (_frameAvg > 21) {
        if (_coarseBudget > 900) {
          _coarseBudget -= 40;
        } else if (_detailBudget > 150) {
          _detailBudget -= 6;
        }
      } else if (_frameAvg < 13) {
        if (_detailBudget < 460) {
          _detailBudget += 3;
        } else if (_coarseBudget < 3200) {
          _coarseBudget += 24;
        }
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

    if (_repairSweep != null) {
      _repairSweep = _repairSweep! - dt * math.max(9.0, _layout.length * 0.9);
      final origin = _layout.slotFor(widget.store.shownTotal - 1);
      if (origin != null) {
        for (var i = 0; i < 2; i++) {
          _fx.repairMote(
            _repairSweep! + hashJitter(0.6, (_time * 60).toInt(), i),
            hash01((_time * 60).toInt(), i + 5) * 1.9,
            0.42,
          );
        }
      }
      if (_repairSweep! < -3) {
        _repairSweep = null;
        _displayIntegrity = 1;
      }
    } else {
      final target = widget.store.integrity;
      _displayIntegrity +=
          (target - _displayIntegrity) * (1 - math.exp(-dt * 1.4));
    }

    _spawnAmbient(dt);

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
    if (_city == null) return;
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
  void _spawnCityAmbient(double dt) {
    final city = _city;
    if (city == null) return;
    _ambientCounter++;

    final take = math.min(widget.store.shownTotal, city.pieces.length);
    if (take <= 0) return;

    // The same gust the renderer leans everything else with.
    final wx = math.sin(_time * 0.31) * 0.34 + 0.12;
    final wz = math.cos(_time * 0.23) * 0.26 - 0.08;

    // A handful of chimneys per frame, chosen round-robin so every one of them
    // gets its turn without the cost of walking the whole town.
    var found = 0;
    for (var k = 0; k < 40 && found < 3; k++) {
      final i = (_ambientCounter * 7 + k * 131) % take;
      final piece = city.pieces[i];
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
        final piece = city.pieces[i];
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

  /// Fires on completed beacons keep licking upwards on their own.
  void _spawnAmbient(double dt) {
    if (_city != null) {
      _spawnCityAmbient(dt);
      return;
    }
    _ambientCounter++;
    if (_ambientCounter % 3 != 0) return;
    for (final st in _layout.structures) {
      if (st.type.kind != MilestoneKind.beacon) continue;
      if (widget.store.shownTotal < st.firstBrick + st.brickCount) continue;
      if ((st.featureX - _cam.travel).abs() > _cam.detailRadius) continue;
      _fx.ember(st.featureX, st.featureY - 0.1, 0);
    }
  }


  /// Where the camera should sit to watch a piece land, in whichever world we
  /// are building. The wall travels along its own axis; the town orbits its
  /// plaza, so the most the camera does there is look at the right height.
  void _followPlacement(int index) {
    final city = _city;
    if (city != null) {
      final piece = city.pieceFor(index);
      if (piece == null) return;
      _cam.follow = true;
      _cam.travelTo(piece.cx);
      _cam.focusZTarget = piece.cz;
      _cam.focusYTarget = clampD(piece.y1 + 0.6, 1.0, 6.0);
      if (_cam.distanceTarget > 20) _cam.distanceTarget = 15;
      return;
    }
    final slot = _layout.slotFor(index);
    if (slot == null) return;
    _cam.follow = true;
    _cam.travelTo(slot.x);
    _cam.focusYTarget = clampD(slot.y + 0.35, 0.9, 3.4);
    // Pull in a little if we are miles away, so the landing is legible.
    if (_cam.distanceTarget > 26) _cam.distanceTarget = 18;
  }

  // --------------------------------------------------------------- placing

  void placeBrick() {
    _touched();
    _showcase = null;
    final store = widget.store;
    final wasDecaying = store.integrity < 0.995;
    final before = store.integrity;
    store.setPreview(null);
    final result = store.placeBrick();
    _selectedBrick = null;
    _rebuildLayout();

    _followPlacement(result.brick.index);
    if (wasDecaying) _displayIntegrity = before;
    _pendingResult = result;
    // In the town a piece is set down, not dropped from a crane: from high up
    // it reads as a bug, and the anticipation is in the shadow closing under
    // it rather than in the height it falls from.
    _placement = PlacementFx(result.brick.index,
        dropHeight: _city != null ? 2.3 : 5.2);
    setState(() {});
  }

  void _onImpact(PlacementFx p) {
    final city = _city;
    if (city != null) {
      _onCityImpact(p);
      return;
    }
    final slot = _layout.slotFor(p.brickIndex);
    final result = _pendingResult;
    _pendingResult = null;
    if (slot == null) return;

    final at = V3(
      slot.x,
      slot.y - slot.h * 0.4,
      slot.zCenter + slot.halfDepth * 0.5,
    );
    final strength = clampD(slot.w / 0.7, 0.7, 1.5);
    _fx.impact(at, slot.w * 0.6, strength: strength);
    _cam.shake = 0.045 * strength;
    Sensory.instance.impact(strength: strength);

    if (result == null) return;

    if (result.repaired) {
      _repairSweep = slot.x + 0.8;
      Future.delayed(const Duration(milliseconds: 90), () {
        Sensory.instance.repair();
      });
    }

    if (result.milestoneCompleted != null) {
      final st = _layout.structures.where(
        (s) => s.firstBrick == result.milestoneCompleted!.firstBrick,
      );
      if (st.isNotEmpty) {
        final s = st.first;
        _fx.celebrate(
          V3((s.x0 + s.x1) / 2, s.peakY * 0.6, 0.5),
          1.6,
          count: 90,
        );
        _cam.travelTo((s.x0 + s.x1) / 2);
        _cam.distanceTarget = clampD(s.peakY * 3.2, 8, 22);
        _cam.focusYTarget = s.peakY * 0.55;
      }
      Future.delayed(const Duration(milliseconds: 260), () {
        Sensory.instance.milestone();
      });
      widget.onMilestoneComplete(result.milestoneCompleted!);
    } else if (result.milestoneStarted != null) {
      widget.onWhisper('Empieza ${result.milestoneStarted!.type!.name}');
    }

  }

  /// The town's version of the landing: the shake and the sound, and a
  /// celebration when a building is finished rather than when a milestone is.
  void _onCityImpact(PlacementFx fx) {
    final city = _city!;
    final piece = city.pieceFor(fx.brickIndex);
    final result = _pendingResult;
    _pendingResult = null;
    if (piece == null) return;

    _fx.impact(V3(piece.cx, piece.y0, piece.cz), piece.w * 0.7, strength: 1.1);
    _cam.shake = 0.05;
    Sensory.instance.impact(strength: 1.1);

    final building = city.buildings[piece.building];
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
      _cam.focusYTarget = clampD(building.peakY * 0.5, 1.0, 5.0);
      _cam.distanceTarget = clampD(building.peakY * 2.8 + 4.5, 10, 30);
      Future.delayed(const Duration(milliseconds: 220), () {
        Sensory.instance.milestone();
      });
      final mark = building.landmark;
      if (mark != null) {
        var ordinal = 0;
        for (final b in city.buildings) {
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
    // The wall's milestones do not belong in a town: it has a hundred and
    // twelve of its own, and they are announced by the building being
    // finished, not by a card about a bastion.
    if (result != null && result.repaired) {
      widget.onWhisper('El pueblo vuelve a encenderse');
    }
  }

  // ---------------------------------------------------------------- camera

  void frameAll() {
    final city = _city;
    if (city != null) {
      _cam.travelTarget = 0;
      _cam.focusZTarget = 0;
      _cam.focusYTarget = 1.8;
      _cam.distanceTarget = clampD(city.radius * 2.4, 9, 90);
      _cam.pitchTarget = 0.52;
      _cam.follow = false;
      Sensory.instance.tick();
      return;
    }
    _cam.frameAll();
    Sensory.instance.tick();
  }

  void goToLatest() {
    if (_city != null) {
      _followPlacement(widget.store.shownTotal - 1);
      Sensory.instance.tick();
      return;
    }
    final slot =
        _layout.slotFor(widget.store.shownTotal - 1) ??
        _layout.slotFor(widget.store.shownTotal);
    if (slot != null) {
      _cam.travelTo(slot.x);
      _cam.focusYTarget = clampD(slot.y + 0.3, 0.9, 3.2);
      _cam.distanceTarget = clampD(_cam.distanceTarget, 6, 16);
      _cam.follow = true;
    }
    Sensory.instance.tick();
  }

  void goToX(double x) {
    _cam.travelTo(x);
    _cam.follow = false;
  }

  void resetView() {
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.30;
    _cam.focusYTarget = 1.15;
    _cam.distanceTarget = 10;
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
      if (_selectedBrick != null) setState(() => _selectedBrick = null);
      return;
    }

    final brick = widget.store.brickAt(best.brickIndex);
    if (brick == null) return;
    setState(() => _selectedBrick = brick.index);
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
    if (_selectedBrick != null && mounted) {
      setState(() => _selectedBrick = null);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final scene = WallScene(
      layout: _layout,
      placed: store.shownTotal,
      palette: _palette,
      camera: _cam,
      integrity: _displayIntegrity,
      time: _time,
      effects: _fx,
      labelledBricks: {
        for (final b in store.bricks)
          if (b.hasLabel) b.index,
      },
      structureNames: {
        for (final s in _layout.structures) s.index: s.type.name,
      },
      fx: _placement,
      repairSweep: _repairSweep,
      detailBudget: _detailBudget,
      coarseBudget: _coarseBudget,
      mortar: Appearance.instance.look,
      city: _city,
      finished: _finished,
      finishedAge: _finishedAge,
      selectedBrick: _selectedBrick,
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
          painter: WallPainter(scene, _picks),
          size: Size.infinite,
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}
