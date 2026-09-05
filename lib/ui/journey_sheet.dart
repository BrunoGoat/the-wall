import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/appearance.dart';
import '../model/models.dart';
import '../fx/sensory.dart';
import '../model/wall_store.dart';
import '../engine/layout.dart';
import 'appearance_sheet.dart';
import 'debug_sheet.dart';
import 'papyrus.dart';
import 'sigil.dart';
import 'style.dart';

/// Everything the wall has become: the numbers, the landmarks and the hundred
/// epics, found and unfound.
class JourneySheet extends StatefulWidget {
  const JourneySheet({
    super.key,
    required this.store,
    required this.theme,
    required this.onGoTo,
    required this.structureX,
    required this.onEditLabel,
  });

  final WallStore store;
  final UiTheme theme;

  /// Jumps the camera to a position along the wall.
  final void Function(double x) onGoTo;

  /// Centre of each built landmark, keyed by the brick it started on.
  final Map<int, double> structureX;

  /// Opens the note editor for a brick.
  final void Function(Brick brick) onEditLabel;

  @override
  State<JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends State<JourneySheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: t.panelStrong,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: t.stroke),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fgFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _tabs(t),
              const SizedBox(height: 6),
              Expanded(
                child: switch (_tab) {
                  0 => _Summary(store: widget.store, theme: t),
                  1 => _Milestones(
                      store: widget.store,
                      theme: t,
                      onGoTo: widget.onGoTo,
                      structureX: widget.structureX),
                  _ => _Legends(
                      store: widget.store,
                      theme: t,
                      onGoTo: widget.onGoTo,
                      onEdit: widget.onEditLabel,
                    ),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabs(UiTheme t) {
    const labels = ['LA MURALLA', 'HITOS', 'LEYENDAS'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i == _tab;
        return GestureDetector(
          onTap: () {
            Sensory.instance.tick();
            setState(() => _tab = i);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: on ? t.fg.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: on ? t.stroke : Colors.transparent),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: on ? t.fg : t.fgFaint,
                fontSize: 10.5,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.store, required this.theme});
  final WallStore store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final days = store.recentDays(35);
    final maxDay = days.fold<int>(1, (m, d) => d.count > m ? d.count : m);
    final integrity = store.integrity;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
      children: [
        Row(
          children: [
            _stat(t, '${store.total}', 'LADRILLOS'),
            _stat(t, '${store.wallLengthMeters.toStringAsFixed(0)} m', 'LARGO'),
            _stat(t, '${store.streak}', 'RACHA'),
            _stat(t, '${store.bestStreak}', 'MEJOR'),
          ],
        ),
        const SizedBox(height: 26),
        Text('NIVEL DE LA MURALLA', style: t.label),
        const SizedBox(height: 10),
        _TierBar(store: store, theme: t),
        const SizedBox(height: 26),
        Text('ESTADO DE LA MURALLA', style: t.label),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: integrity,
            minHeight: 7,
            backgroundColor: t.fg.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(
              integrity > 0.85
                  ? const Color(0xFF6E9E86)
                  : (integrity > 0.5 ? t.accent : const Color(0xFFA8556A)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          integrity > 0.99
              ? 'Intacta. Cada día que sumás un ladrillo se mantiene así.'
              : integrity > 0.6
                  ? 'Empieza a resentirse. Un solo ladrillo la repara entera.'
                  : 'Se está viniendo abajo. Un ladrillo alcanza para frenarlo.',
          style: t.bodySoft,
        ),
        const SizedBox(height: 28),
        Text('ÚLTIMOS 35 DÍAS', style: t.label),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final h = d.count == 0 ? 3.0 : 6 + 44 * (d.count / maxDay);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.2),
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: d.count == 0
                          ? t.fg.withValues(alpha: 0.10)
                          : t.accent.withValues(alpha: 0.45 + 0.55 * (d.count / maxDay)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 28),
        Text('LO QUE VIENE', style: t.label),
        const SizedBox(height: 10),
        Text(store.nextEventLabel, style: t.body),
        const SizedBox(height: 6),
        Text(
          'Un ladrillo es siempre un logro. Nunca un lote.',
          style: t.bodySoft.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 30),
        Text('AJUSTES', style: t.label),
        const SizedBox(height: 6),
        _SoundToggles(theme: t),
        const SizedBox(height: 4),
        _SheetRow(
          theme: t,
          icon: Icons.grain,
          title: 'Mortero y juntas',
          subtitle: 'Cómo se ve la piedra: junta viva, fina, enrasada o '
              'piedra seca.',
          trailing: MortarLook.of(Appearance.instance.mortar).name,
          open: (nav) => AppearanceSheet(theme: t),
        ),
        _RapidToggle(theme: t),
        _SheetRow(
          theme: t,
          icon: Icons.tune,
          title: 'Ver la muralla a futuro',
          subtitle: 'Cómo se vería con 100, 500 o 5000 ladrillos. '
              'No toca los tuyos.',
          open: (nav) => DebugSheet(store: store, theme: t),
        ),
      ],
    );
  }

  Widget _stat(UiTheme t, String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: t.number),
            const SizedBox(height: 5),
            Text(label, style: t.label.copyWith(fontSize: 9, letterSpacing: 1.4)),
          ],
        ),
      );
}

/// How high the wall has climbed, and how far the next level still is.
///
/// Every level opens a whole new band of courses above the old crenellations:
/// the stones already laid stay exactly where they are, and the wall grows up
/// over them instead of only sideways.
class _TierBar extends StatelessWidget {
  const _TierBar({required this.store, required this.theme});
  final WallStore store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tier = WallTiers.tierAt(math.max(0, store.total - 1));
    final left = WallStore.bricksToNextTier(store.total);
    final from = tier == 0 ? 0 : WallTiers.thresholds[tier - 1];
    final to = left == null ? store.total : store.total + left;
    final progress = to <= from
        ? 1.0
        : ((store.total - from) / (to - from)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              WallStore.tierNameFor(store.total),
              style: t.number.copyWith(
                fontSize: 27,
                fontFamily: Papyrus.serif,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                left == null
                    ? 'Altura máxima alcanzada.'
                    : 'Faltan $left para que suba otro nivel.',
                style: t.bodySoft.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: t.fg.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(t.accent),
          ),
        ),
      ],
    );
  }
}

/// The one switch in the app that breaks its own rule, kept for testing.
class _RapidToggle extends StatefulWidget {
  const _RapidToggle({required this.theme});
  final UiTheme theme;

  @override
  State<_RapidToggle> createState() => _RapidToggleState();
}

class _RapidToggleState extends State<_RapidToggle> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: Appearance.instance.rapid,
      activeThumbColor: t.accent,
      title: Text('Obra rápida', style: t.body),
      subtitle: Text(
        'Para probar: dejá el botón apretado y las piedras siguen cayendo, '
        'cada vez más rápido, hasta que lo sueltes.',
        style: t.bodySoft.copyWith(fontSize: 11.5),
      ),
      onChanged: (v) async {
        Sensory.instance.tick();
        await Appearance.instance.setRapid(v);
        if (mounted) setState(() {});
      },
    );
  }
}

/// A quiet way into one of the sheets that changes how the wall looks.
///
/// Every one of them opens without a scrim: they are all judgements about the
/// wall, and you cannot make those against a dimmed wall.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
    this.trailing,
  });

  final UiTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final Widget Function(NavigatorState nav) open;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Sensory.instance.tick();
        // The navigator's own context, not this row's: this row is inside the
        // sheet being closed, and its context is gone the moment it pops.
        final nav = Navigator.of(context);
        nav.pop();
        showModalBottomSheet<void>(
          context: nav.context,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => open(nav),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: t.fgSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: t.body)),
                      if (trailing != null)
                        Text(
                          trailing!,
                          style: t.bodySoft.copyWith(
                            fontSize: 11.5,
                            color: t.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySoft.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 19, color: t.fgFaint),
          ],
        ),
      ),
    );
  }
}

class _SoundToggles extends StatefulWidget {
  const _SoundToggles({required this.theme});
  final UiTheme theme;

  @override
  State<_SoundToggles> createState() => _SoundTogglesState();
}

class _SoundTogglesState extends State<_SoundToggles> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: !Sensory.instance.muted,
          activeThumbColor: t.accent,
          title: Text('Sonido', style: t.body),
          onChanged: (v) {
            setState(() => Sensory.instance.setMuted(!v));
            if (v) Sensory.instance.tick();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: !Sensory.instance.hapticsOff,
          activeThumbColor: t.accent,
          title: Text('Vibración', style: t.body),
          onChanged: (v) {
            setState(() => Sensory.instance.setHapticsOff(!v));
            if (v) Sensory.instance.tick();
          },
        ),
      ],
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({
    required this.store,
    required this.theme,
    required this.onGoTo,
    required this.structureX,
  });
  final WallStore store;
  final UiTheme theme;
  final void Function(double x) onGoTo;
  final Map<int, double> structureX;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final segs = store.plan.segments.where((s) => s.isMilestone).toList();
    final shown = segs.where((s) => s.firstBrick <= store.total + 400).toList();
    final layout = store.total;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final s = shown[i];
        final type = s.type!;
        final done = layout >= s.firstBrick + s.length;
        final active = layout > s.firstBrick && !done;
        final progress = s.progress(layout);
        final locked = layout <= s.firstBrick;

        return Opacity(
          opacity: locked ? 0.45 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.fg.withValues(alpha: active ? 0.07 : 0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? t.accent.withValues(alpha: 0.5) : t.stroke,
              ),
            ),
            child: Row(
              children: [
                LandmarkSigil(
                  kind: type.kind,
                  color: locked
                      ? t.fg.withValues(alpha: 0.34)
                      : (active ? t.accent : t.fg.withValues(alpha: 0.78)),
                  size: 34,
                  locked: locked,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locked ? 'Hito ${s.milestoneNo + 1}' : type.name,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        done
                            ? 'Levantado con ${s.length} ladrillos'
                            : active
                                ? 'En obra · ${layout - s.firstBrick} de ${s.length}'
                                : 'Empieza en el ladrillo ${s.firstBrick + 1}',
                        style: t.bodySoft.copyWith(fontSize: 11.5),
                      ),
                      if (active) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: t.fg.withValues(alpha: 0.10),
                            valueColor: AlwaysStoppedAnimation(t.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (done)
                  IconButton(
                    icon: Icon(Icons.my_location,
                        size: 18, color: t.fg.withValues(alpha: 0.6)),
                    onPressed: () {
                      final x = structureX[s.firstBrick];
                      if (x != null) {
                        Navigator.of(context).pop();
                        onGoTo(x);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The chronicle: every stone the person actually wrote something on, read as
/// a scribe's log on a sheet of papyrus rather than as a list of rows.
class _Legends extends StatelessWidget {
  const _Legends({
    required this.store,
    required this.theme,
    required this.onGoTo,
    required this.onEdit,
  });

  final WallStore store;
  final UiTheme theme;
  final void Function(double x) onGoTo;
  final void Function(Brick brick) onEdit;

  @override
  Widget build(BuildContext context) {
    // Oldest first: a chronicle is read forwards, from the first stone to the
    // last, which is the whole point of it being a story.
    final items = store.labelled.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: PapyrusPainter()),
          ),
          Material(
            type: MaterialType.transparency,
            child: items.isEmpty
                ? _empty(context)
                : _log(context, items),
          ),
        ],
      ),
    );
  }

  Widget _heading() => Column(
        children: [
          const SizedBox(height: 26),
          Text(
            'BITÁCORA DE LA MURALLA',
            textAlign: TextAlign.center,
            style: Papyrus.body(13, w: FontWeight.w700, c: Papyrus.ink)
                .copyWith(letterSpacing: 2.6),
          ),
          const SizedBox(height: 6),
          Text(
            '· ${Papyrus.roman(store.total)} piedras asentadas ·',
            textAlign: TextAlign.center,
            style: Papyrus.body(11.5, c: Papyrus.inkFaint)
                .copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          const PapyrusRule(),
          const SizedBox(height: 4),
        ],
      );

  Widget _empty(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        children: [
          _heading(),
          const SizedBox(height: 24),
          Text(
            'Aquí no hay nada escrito todavía.',
            textAlign: TextAlign.center,
            style: Papyrus.body(16.5, w: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Tocá cualquier piedra de la muralla y dejale una leyenda: '
            '“Leí”, “Corrí”, lo que quieras. No hace falta —la piedra ya '
            'está puesta— pero lo que se escribe queda en esta bitácora, y '
            'dentro de un año esto va a ser una historia.',
            textAlign: TextAlign.center,
            style: Papyrus.body(14, c: Papyrus.inkSoft),
          ),
          const SizedBox(height: 26),
          const PapyrusRule(wide: true),
        ],
      );

  Widget _log(BuildContext context, List<Brick> items) {
    // Broken into months, each with its own illuminated heading.
    final rows = <Widget>[_heading()];
    String? month;
    for (var i = 0; i < items.length; i++) {
      final b = items[i];
      final m = Papyrus.monthHeading(b.placedAt);
      if (m != month) {
        month = m;
        rows.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 18 : 26, bottom: 2),
          child: Text(
            m,
            style: Papyrus.body(10.5, w: FontWeight.w700, c: Papyrus.rubric)
                .copyWith(letterSpacing: 2.0),
          ),
        ));
        rows.add(const Divider(color: Papyrus.rule, height: 12));
      }
      rows.add(PapyrusEntry(
        brick: b,
        ordinal: i + 1,
        dropCap: i == 0,
        onGo: () {
          final slot = WallLayout(store.total).slotFor(b.index);
          Navigator.of(context).pop();
          if (slot != null) onGoTo(slot.x);
        },
        onEdit: () {
          Navigator.of(context).pop();
          onEdit(b);
        },
      ));
    }
    rows
      ..add(const SizedBox(height: 22))
      ..add(const PapyrusRule(wide: true))
      ..add(const SizedBox(height: 10))
      ..add(Text(
        'Y la muralla sigue creciendo.',
        textAlign: TextAlign.center,
        style: Papyrus.body(12.5, c: Papyrus.inkFaint)
            .copyWith(fontStyle: FontStyle.italic),
      ));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 30),
      children: rows,
    );
  }
}
