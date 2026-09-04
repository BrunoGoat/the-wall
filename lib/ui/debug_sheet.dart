import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/wall_store.dart';
import 'style.dart';

/// Looks at what the wall becomes after any number of bricks.
///
/// Strictly a preview: the real bricks are never touched, nothing is written
/// to disk, and closing it puts the real wall straight back. It is the only
/// honest way to judge pacing and landmarks without waiting years.
class DebugSheet extends StatefulWidget {
  const DebugSheet({super.key, required this.store, required this.theme});

  final WallStore store;
  final UiTheme theme;

  static const List<int> shortcuts = [50, 100, 200, 500, 1000, 5000];
  static const int maxPreview = 6000;

  @override
  State<DebugSheet> createState() => _DebugSheetState();
}

class _DebugSheetState extends State<DebugSheet> {
  late double _value =
      (widget.store.preview ?? widget.store.total).toDouble().clamp(0, 6000);

  void _apply(int n) {
    setState(() => _value = n.toDouble());
    widget.store.setPreview(n == widget.store.total ? null : n);
    Sensory.instance.tick();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final shown = _value.round();
    final layoutReady = store.isPreviewing;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      decoration: BoxDecoration(
        color: t.panelStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.fgFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('VER LA MURALLA A FUTURO', style: t.label),
          const SizedBox(height: 5),
          Text(
            'Sólo mira. Tus ${store.total} ladrillos reales quedan intactos.',
            style: t.bodySoft.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$shown', style: t.number.copyWith(fontSize: 40)),
              const SizedBox(width: 9),
              Text('LADRILLOS', style: t.label),
              const Spacer(),
              Text(
                'nivel ${WallStore.tierNameFor(shown)}',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 11.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.accent,
              inactiveTrackColor: t.fg.withValues(alpha: 0.14),
              thumbColor: t.accent,
              overlayColor: t.accent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _value,
              min: 0,
              max: DebugSheet.maxPreview.toDouble(),
              onChanged: (v) => setState(() => _value = v),
              // Applied on release: rebuilding a six-thousand-stone wall on
              // every pixel of drag would stutter for no reason.
              onChangeEnd: (v) => _apply(v.round()),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in DebugSheet.shortcuts)
                _Chip(
                  theme: t,
                  label: '$n',
                  selected: shown == n,
                  onTap: () => _apply(n),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (layoutReady)
                TextButton.icon(
                  onPressed: () {
                    widget.store.setPreview(null);
                    Sensory.instance.tick();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.undo, size: 17, color: t.fgSoft),
                  label: Text('Volver a la mía',
                      style: TextStyle(color: t.fgSoft)),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.accent),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Mirar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final UiTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.18)
              : t.fg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? t.accent.withValues(alpha: 0.7) : t.stroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? t.accent : t.fg.withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
