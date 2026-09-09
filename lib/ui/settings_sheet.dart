import 'package:flutter/material.dart';

import '../data/landmarks.dart';
import '../engine/town.dart';
import '../data/tunes.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/store.dart';
import 'backup_sheet.dart';
import 'debug_sheet.dart';
import 'gallery_screen.dart';
import 'notice_board.dart';
import 'style.dart';

/// Everything about the app that is a setting rather than a town.
///
/// It used to live at the bottom of the journey, under the stats and the
/// milestones, which meant scrolling past your own history to turn the sound
/// down. Now the gear opens this and the numbers still open the journey: two
/// doors, two different things behind them.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  /// While this sheet is open the music can be asked to play some other hour
  /// than the one it is. It goes back to the clock on the way out — leaving
  /// somebody's app stuck at three in the morning would be a strange souvenir.
  double? _pretend;

  @override
  void dispose() {
    Sensory.instance.pretendItIs(null);
    super.dispose();
  }

  void _hour(double? h) {
    setState(() => _pretend = h);
    Sensory.instance.pretendItIs(h);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return SheetSurface(
      theme: t,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
      child: ListenableBuilder(
        listenable: Appearance.instance,
        builder: (context, _) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.fg.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('AJUSTES', style: t.label),
              const SizedBox(height: 10),
              Expanded(child: _body(context, t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, UiTheme t) {
    final wants = Appearance.instance;
    final store = widget.store;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _Head(theme: t, text: 'SONIDO'),
        _Switch(
          theme: t,
          title: 'Sonido',
          subtitle: 'El interruptor de todo, música incluida.',
          on: !wants.soundOff,
          onChanged: (v) => wants.setSoundOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Efectos',
          subtitle: 'Lo que suena al poner una pieza.',
          on: !wants.effectsOff,
          enabled: !wants.soundOff,
          onChanged: (v) => wants.setEffectsOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Música',
          subtitle: 'De fondo, y distinta según la hora del día.',
          on: !wants.musicOff,
          enabled: !wants.soundOff,
          onChanged: (v) => wants.setMusicOff(!v),
        ),
        const SizedBox(height: 8),
        _Slider(
          theme: t,
          title: 'Volumen de la música',
          value: wants.musicVolume,
          onChanged: wants.setMusicVolume,
        ),
        _Slider(
          theme: t,
          title: 'Volumen de los efectos',
          value: wants.effectsVolume,
          onChanged: (v) {
            wants.setEffectsVolume(v);
          },
          onSettled: () => Sensory.instance.preview('place'),
        ),
        Text(
          'La mitad es como sonaba antes de que hubiera dónde tocarlo, así que '
          'lo que muevas se mide contra algo que ya conocés.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'CADA SONIDO'),
        Text(
          'Tocá el altavoz para oírlo. El interruptor lo silencia sólo a él.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 8),
        for (final bite in Sensory.catalogue)
          _Bite(
            theme: t,
            bite: bite,
            enabled: !wants.soundOff && !wants.effectsOff,
          ),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LOS DISCOS'),
        Text(
          'Tocá el disco para oírlo ahora mismo. La casilla decide cuáles '
          'entran en el sorteo: al abrir la app suena una de ellas al azar.'
          '${wants.rotation == tunes.length ? '' : ' Ahora hay '
                    '${wants.rotation} elegido${wants.rotation == 1 ? '' : 's'}.'}',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 6),
        for (final tune in tunes)
          _Disc(
            theme: t,
            tune: tune,
            playing: Sensory.instance.tune.id == tune.id,
            enabled: !wants.soundOff && !wants.musicOff,
            onPlay: () async {
              await Sensory.instance.playTune(tune);
              if (mounted) setState(() {});
            },
            onKeep: (v) => wants.setRotation(tune.id, v),
          ),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LA MÚSICA A CUALQUIER HORA'),
        _Clock(theme: t, at: _pretend, onPick: _hour),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LO DEMÁS'),
        _Switch(
          theme: t,
          title: 'Vibración',
          subtitle: 'El peso de la pieza al caer.',
          on: !wants.hapticsOff,
          onChanged: (v) => wants.setHapticsOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Modo rápido',
          subtitle:
              'Mantener pone piezas seguidas. Para probar, no para usar: una '
              'pieza es un logro.',
          on: wants.rapid,
          onChanged: wants.setRapid,
        ),
        _Row(
          theme: t,
          icon: Icons.save_alt,
          title: 'Tus datos',
          subtitle: 'Copiar tu valle y volver a meterlo.',
          open: () => BackupSheet(store: store, theme: t),
        ),
        _Row(
          theme: t,
          icon: Icons.tune,
          title: 'Ver el pueblo a futuro',
          subtitle: 'Cómo se vería con 100, 500 o 5000 piezas.',
          open: () => DebugSheet(store: store, theme: t),
        ),
        _Row(
          theme: t,
          icon: Icons.push_pin_outlined,
          title: 'El tablón del pueblo',
          subtitle: 'Lo que el pueblo fue notando de vos.',
          page: () =>
              NoticeBoardScreen(store: store, habit: store.habit, theme: t),
        ),
        _Row(
          theme: t,
          icon: Icons.view_in_ar,
          title: 'El expositor',
          subtitle:
              'Las ${landmarks.length + BuildingKind.values.length} estructuras '
              'que el pueblo sabe construir.',
          page: () => GalleryScreen(theme: t),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.theme, required this.text});
  final UiTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: theme.label.copyWith(color: theme.accent)),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onChanged,
    this.enabled = true,
  });

  final UiTheme theme;
  final String title;
  final String subtitle;
  final bool on;
  final bool enabled;
  final void Function(bool v) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: on,
        activeThumbColor: t.accent,
        title: Text(title, style: t.body),
        subtitle: Text(
          subtitle,
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.35),
        ),
        onChanged: enabled
            ? (v) {
                Sensory.instance.tick();
                onChanged(v);
              }
            : null,
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.theme,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onSettled,
  });

  final UiTheme theme;
  final String title;
  final double value;
  final void Function(double v) onChanged;

  /// Something to hear once the finger comes off, so a volume can be judged
  /// rather than guessed.
  final VoidCallback? onSettled;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.body)),
              Text(
                '${(value * 100).round()}%',
                style: t.bodySoft.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.accent.withValues(alpha: 0.85),
              inactiveTrackColor: t.fg.withValues(alpha: 0.12),
              thumbColor: t.accent,
              overlayColor: t.accent.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: (_) => onSettled?.call(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sound: what it is called, a speaker to hear it, and a switch that
/// silences only this one.
class _Bite extends StatelessWidget {
  const _Bite({required this.theme, required this.bite, required this.enabled});

  final UiTheme theme;
  final SoundBite bite;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hushed = Appearance.instance.isHushed(bite.id);
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bite.name,
                style: t.body.copyWith(
                  fontSize: 14,
                  color: hushed ? t.fgFaint : t.fg,
                  decoration: hushed ? TextDecoration.lineThrough : null,
                  decorationColor: t.fgFaint,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Sensory.instance.preview(bite.id),
              icon: const Icon(Icons.volume_up_outlined, size: 19),
              color: t.accent,
              tooltip: 'Escuchar ${bite.name}',
              visualDensity: VisualDensity.compact,
            ),
            Switch(
              value: !hushed,
              activeThumbColor: t.accent,
              onChanged: enabled
                  ? (v) {
                      Sensory.instance.tick();
                      Appearance.instance.hush(bite.id, !v);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Una de las cinco piezas: el disco para oírla y la casilla para dejarla en
/// el sorteo.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.theme,
    required this.tune,
    required this.playing,
    required this.enabled,
    required this.onPlay,
    required this.onKeep,
  });

  final UiTheme theme;
  final Tune tune;

  /// La que suena ahora mismo. Lleva el disco relleno y el nombre en color:
  /// con cinco filas iguales, saber cuál estás oyendo es la mitad de poder
  /// compararlas.
  final bool playing;
  final bool enabled;
  final VoidCallback onPlay;
  final void Function(bool keep) onKeep;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final keep = Appearance.instance.inRotation(tune.id);
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            IconButton(
              onPressed: enabled ? onPlay : null,
              icon: Icon(
                playing ? Icons.album : Icons.album_outlined,
                size: 26,
              ),
              color: playing ? t.accent : t.fg.withValues(alpha: 0.65),
              tooltip: 'Oír ${tune.name}',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tune.name,
                    style: t.body.copyWith(
                      fontSize: 14,
                      color: playing ? t.accent : t.fg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tune.blurb,
                    style: t.bodySoft.copyWith(fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: keep,
              activeColor: t.accent,
              visualDensity: VisualDensity.compact,
              onChanged: enabled
                  ? (v) {
                      Sensory.instance.tick();
                      onKeep(v ?? false);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The music at any hour of the day, and what it is playing while you listen.
class _Clock extends StatelessWidget {
  const _Clock({required this.theme, required this.at, required this.onPick});

  final UiTheme theme;
  final double? at;
  final void Function(double? hour) onPick;

  static const List<(String, double)> _moments = [
    ('Noche', 3),
    ('Mañana', 8),
    ('Mediodía', 14),
    ('Tarde', 20),
  ];

  /// Las tres capas de cualquiera de las cinco, por lo que hacen y no por qué
  /// instrumento son: en una es un Rhodes y en otra una caja de música, pero
  /// en las cinco es la parte que se mueve.
  static const List<String> _layers = [
    'Cama',
    'Lo que se mueve',
    'Lo de arriba',
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final now = DateTime.now();
    final hour = at ?? (now.hour + now.minute / 60.0);
    final mix = Sensory.dayMix(Sensory.instance.tune, hour);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          at == null
              ? 'Sonando la hora que es. Elegí otra para escucharla.'
              : 'Sonando como a las ${_clock(hour)}.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, h) in _moments)
              _Chip(
                theme: t,
                text: name,
                on: at != null && (at! - h).abs() < 0.01,
                onTap: () => onPick(h),
              ),
            _Chip(
              theme: t,
              text: 'Ahora',
              on: at == null,
              onTap: () => onPick(null),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.accent.withValues(alpha: 0.85),
            inactiveTrackColor: t.fg.withValues(alpha: 0.12),
            thumbColor: t.accent,
            overlayColor: t.accent.withValues(alpha: 0.12),
            trackHeight: 3,
          ),
          child: Slider(
            value: hour,
            max: 24,
            divisions: 96,
            label: _clock(hour),
            onChanged: onPick,
          ),
        ),
        // What the three layers are actually at, so the tool answers rather
        // than only demonstrates.
        for (var i = 0; i < _layers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    _layers[i],
                    style: t.bodySoft.copyWith(fontSize: 11.5),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: mix[i],
                      minHeight: 4,
                      backgroundColor: t.fg.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(
                        t.accent.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(mix[i] * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: t.bodySoft.copyWith(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _clock(double h) {
    final whole = h.floor() % 24;
    final mins = ((h - h.floor()) * 60).round();
    return '${whole.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.theme,
    required this.text,
    required this.on,
    required this.onTap,
  });
  final UiTheme theme;
  final String text;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () {
        Sensory.instance.tick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? t.accent : t.stroke),
        ),
        child: Text(
          text,
          style: t.bodySoft.copyWith(
            fontSize: 12.5,
            color: on ? t.accent : t.fgSoft,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.open,
    this.page,
  });

  final UiTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;

  /// A sheet that rises over this one.
  final Widget Function()? open;

  /// A whole screen that replaces it.
  final Widget Function()? page;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Sensory.instance.tick();
        final nav = Navigator.of(context);
        nav.pop();
        if (page != null) {
          nav.push(MaterialPageRoute<void>(builder: (_) => page!()));
          return;
        }
        showModalBottomSheet<void>(
          context: nav.context,
          backgroundColor: Colors.transparent,
          barrierColor: sheetScrim(t.dark),
          isScrollControlled: true,
          builder: (_) => open!(),
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
                  Text(title, style: t.body),
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
