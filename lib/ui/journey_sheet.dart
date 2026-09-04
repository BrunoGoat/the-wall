import 'package:flutter/material.dart';

import '../model/models.dart';
import '../fx/sensory.dart';
import '../model/wall_store.dart';
import '../engine/layout.dart';
import 'overlays.dart';
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
                Text(locked ? '·' : type.glyph,
                    style: const TextStyle(fontSize: 26)),
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

/// Every stone the person actually wrote something on.
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
    final t = theme;
    final items = store.labelled;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
        child: Column(
          children: [
            Icon(Icons.edit_note, size: 34, color: t.fgFaint),
            const SizedBox(height: 14),
            Text('Todavía no escribiste ninguna',
                style: t.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Tocá cualquier ladrillo de la muralla y podés dejarle una '
              'leyenda: “Leí”, “Corrí”, lo que quieras. Es opcional; el '
              'ladrillo cuenta igual.',
              textAlign: TextAlign.center,
              style: t.bodySoft,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final b = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.fromLTRB(15, 12, 6, 12),
          decoration: BoxDecoration(
            color: t.fg.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.label!,
                        style: t.body.copyWith(
                            fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      'Ladrillo ${b.index + 1} · ${StoneCard.formatDate(b.placedAt)}',
                      style: t.bodySoft.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 17, color: t.fgSoft),
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit(b);
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.my_location, size: 17, color: t.fgSoft),
                onPressed: () {
                  final slot = WallLayout(store.total).slotFor(b.index);
                  Navigator.of(context).pop();
                  if (slot != null) onGoTo(slot.x);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
