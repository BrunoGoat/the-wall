import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/epics.dart';
import '../data/milestones.dart';
import '../data/pacing.dart';
import '../engine/camera.dart';
import '../engine/layout.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/models.dart';
import '../model/wall_store.dart';

/// Handle the surrounding UI uses to drive the wall.
class WallViewController {
  _WallViewState? _state;

  void place(String habitId) => _state?.placeBrick(habitId);
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
    required this.onEpicFound,
    required this.onMilestoneComplete,
    required this.onStoneTapped,
    required this.onWhisper,
    required this.onPaletteChanged,
  });

  final WallStore store;
  final WallViewController controller;
  final void Function(Epic epic) onEpicFound;
  final void Function(PlanSegment seg) onMilestoneComplete;
  final void Function(Brick brick, Habit? habit, int? epicNumber) onStoneTapped;
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
  int _layoutFor = -1;

  PlacementFx? _placement;
  PlaceResult? _pendingResult;

  double _time = 0;
  Duration _last = Duration.zero;

  double _displayIntegrity = 1;
  double? _repairSweep;
  double _revealPulse = 0;
  V3? _revealAt;

  static const int _budgetOverride =
      int.fromEnvironment('BUDGET', defaultValue: -1);
  int _detailBudget = _budgetOverride > 0 ? _budgetOverride : 300;
  double _frameAvg = 16;

  late Palette _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _palette = _buildPalette();
    _rebuildLayout();
    _displayIntegrity = widget.store.integrity;
    _cam.wallLength = _layout.length;
    _cam.travelTarget = math.max(1.5, _layout.length - 3.5);
    _cam.distanceTarget = clampD(9.0 + _layout.length * 0.42, 9.0, 34.0);
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.30;
    // Fixed framing for development screenshots.
    const camYaw = int.fromEnvironment('CAM_YAW', defaultValue: -999);
    const camPitch = int.fromEnvironment('CAM_PITCH', defaultValue: -999);
    const camDist = int.fromEnvironment('CAM_DIST', defaultValue: -999);
    const camAt = int.fromEnvironment('CAM_AT', defaultValue: -999);
    if (camYaw != -999) _cam.yawTarget = camYaw * math.pi / 180;
    if (camPitch != -999) _cam.pitchTarget = camPitch * math.pi / 180;
    if (camDist != -999) _cam.distanceTarget = camDist.toDouble();
    if (camAt != -999) _cam.travelTarget = _layout.length * camAt / 100;
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
    if (widget.store.total != _layoutFor) _rebuildLayout();
  }

  void _rebuildLayout() {
    _layout = WallLayout(widget.store.total);
    _layoutFor = widget.store.total;
    _cam.wallLength = _layout.length;
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
      if (_frameAvg > 21 && _detailBudget > 150) {
        _detailBudget -= 6;
      } else if (_frameAvg < 13 && _detailBudget < 460) {
        _detailBudget += 3;
      }
    }

    _cam.step(dt);
    _fx.update(dt);

    final p = _placement;
    if (p != null) {
      final wasLanded = p.landed;
      p.update(dt);
      if (!wasLanded && p.landed) _onImpact(p);
      if (p.done) _placement = null;
    }

    if (_repairSweep != null) {
      _repairSweep = _repairSweep! - dt * math.max(9.0, _layout.length * 0.9);
      final origin = _layout.slotFor(widget.store.total - 1);
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

    if (_revealPulse > 0) {
      _revealPulse = math.max(0, _revealPulse - dt * 1.6);
    }

    _spawnAmbient(dt);

    final pal = _buildPalette();
    _palette = pal;

    if (mounted) setState(() {});
  }

  int _ambientCounter = 0;

  /// Fires on completed beacons keep licking upwards on their own.
  void _spawnAmbient(double dt) {
    _ambientCounter++;
    if (_ambientCounter % 3 != 0) return;
    for (final st in _layout.structures) {
      if (st.type.kind != MilestoneKind.beacon) continue;
      if (widget.store.total < st.firstBrick + st.brickCount) continue;
      if ((st.featureX - _cam.travel).abs() > _cam.detailRadius) continue;
      _fx.ember(st.featureX, st.featureY - 0.1, 0);
    }
  }

  // --------------------------------------------------------------- placing

  void placeBrick(String habitId) {
    final store = widget.store;
    final wasDecaying = store.integrity < 0.995;
    final before = store.integrity;
    final result = store.placeBrick(habitId);
    _rebuildLayout();

    final slot = _layout.slotFor(result.brick.index);
    if (slot != null) {
      _cam.follow = true;
      _cam.travelTo(slot.x);
      _cam.focusYTarget = clampD(slot.y + 0.35, 0.9, 3.4);
      // Pull in a little if we are miles away, so the landing is legible.
      if (_cam.distanceTarget > 26) {
        _cam.distanceTarget = 18;
      }
    }
    if (wasDecaying) _displayIntegrity = before;
    _pendingResult = result;
    _placement = PlacementFx(result.brick.index);
    setState(() {});
  }

  void _onImpact(PlacementFx p) {
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

    if (result.epicSeeded != null) {
      // Seeded, never revealed: the wall now hides something, and finding it is
      // the player's job.
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) widget.onWhisper('Algo quedó escondido entre las piedras');
      });
    }
  }

  // ---------------------------------------------------------------- camera

  void frameAll() {
    _cam.frameAll();
    Sensory.instance.tick();
  }

  void goToLatest() {
    final slot =
        _layout.slotFor(widget.store.total - 1) ??
        _layout.slotFor(widget.store.total);
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
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
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
      // Anything hiding an epic gets a slightly more forgiving target.
      final reach = t.epicNumber != null ? t.radius * 1.9 + 14 : t.radius;
      if (dist < reach && dist < bestD) {
        bestD = dist;
        best = t;
      }
    }
    if (best == null) return;

    final store = widget.store;
    final epicNo = best.epicNumber;
    if (epicNo != null && !store.isFound(epicNo)) {
      final epic = store.discover(epicNo);
      if (epic != null) {
        final slot = _layout.slotFor(best.brickIndex);
        if (slot != null) {
          final at = V3(slot.x, slot.y, slot.zCenter + slot.halfDepth);
          _fx.reveal(at);
          _revealAt = at;
          _revealPulse = 1.0;
          _cam.travelTo(slot.x);
          _cam.follow = false;
          _cam.shake = 0.05;
        }
        Sensory.instance.epic();
        widget.onEpicFound(epic);
        return;
      }
    }

    if (best.brickIndex < store.bricks.length) {
      final brick = store.bricks[best.brickIndex];
      Sensory.instance.tick();
      widget.onStoneTapped(
        brick,
        store.habitById(brick.habitId),
        epicNo != null && store.isFound(epicNo) ? epicNo : null,
      );
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final epicByBrick = <int, int>{};
    for (final e in store.seeds.all) {
      final brickIndex = e.key - 1;
      if (brickIndex < store.total) epicByBrick[brickIndex] = e.value;
    }

    final scene = WallScene(
      layout: _layout,
      placed: store.total,
      palette: _palette,
      camera: _cam,
      integrity: _displayIntegrity,
      time: _time,
      effects: _fx,
      epicByBrick: epicByBrick,
      foundEpics: store.discoveries.keys.toSet(),
      structureNames: {
        for (final s in _layout.structures) s.index: s.type.name,
      },
      fx: _placement,
      repairSweep: _repairSweep,
      detailBudget: _detailBudget,
      revealPulse: _revealPulse,
      revealAt: _revealAt,
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
