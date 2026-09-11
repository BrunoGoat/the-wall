import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../data/landmarks.dart';
import '../engine/town.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/piece.dart';
import '../model/store.dart';
import 'backup_sheet.dart';
import 'debug_sheet.dart';
import 'gallery_screen.dart';
import '../engine/shooting_star.dart';
import 'notice_board.dart';
import 'overlays.dart';
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
        _Head(theme: t, text: 'EL TABLÓN'),
        Text(
          'Las letras del tablón ya no se eligen: tus cuentas van todas de la '
          'misma mano y cada bando sale con la del vecino que lo colgó. Un '
          'tablón de plaza se lee así, no con una letra que se elige en un '
          'menú.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        _Row(
          theme: t,
          icon: Icons.auto_stories_outlined,
          title: 'Ver el tablón con un pueblo lleno',
          subtitle:
              'Un valle de mentira: entrenar durante 300 días. Trae un dado '
              'que vuelve a repartirlo con notas al azar, para ver si el texto '
              'cabe también en las que no salen nunca.',
          page: () {
            final valle = demoValley();
            return NoticeBoardScreen(
              valley: valle,
              habit: valle.first,
              theme: t,
              dice: true,
            );
          },
        ),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LA HORA'),
        _Switch(
          theme: t,
          title: 'Fingir la hora',
          subtitle:
              'Para mirar el pueblo a cualquier hora sin esperarla. Cambia el '
              'cielo, la música, las ventanas y las fugaces, porque las cuatro '
              'salen de la misma hora.',
          on: wants.fakeHour,
          onChanged: wants.setFakeHour,
        ),
        if (wants.fakeHour)
          _Slider(
            theme: t,
            title:
                'Son las ${wants.fakeHourAt.floor().toString().padLeft(2, '0')}'
                ':${((wants.fakeHourAt % 1) * 60).floor().toString().padLeft(2, '0')}',
            value: wants.fakeHourAt / 24,
            onChanged: (v) => wants.setFakeHourAt(v * 24),
          ),
        _Row(
          theme: t,
          icon: Icons.auto_awesome,
          title: 'Tirar una estrella fugaz',
          subtitle:
              'Sale ya mismo, sin esperar. De noche se ve una cada diecisiete '
              'minutos de media, y sólo si mirás hacia donde cae.',
          // Cierra los ajustes primero. Sin eso la fugaz cruzaba por detrás de
          // esta misma hoja durante el segundo y pico que dura, que es la
          // manera más tonta de que un botón de probar algo no pruebe nada. El
          // sonido no lo toca esto: lo toca el valle al verla, y así suena una
          // vez y no dos.
          act: (nav) {
            nav.pop();
            Future<void>.delayed(
              const Duration(milliseconds: 260),
              ShootingStar.force,
            );
          },
        ),

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
        _Undo(theme: t, store: store),
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
          page: () => NoticeBoardScreen(
            valley: store.habits,
            habit: store.habit,
            theme: t,
          ),
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

/// Deshacer la última pieza.
///
/// Vive aquí abajo, entre lo demás, y no al lado del botón de poner. Poner una
/// pieza es el gesto de la app y quitarla no puede estar a un dedo de él: lo
/// que se busca es que quien se equivocó pueda arreglarlo, no que quitar sea
/// tan fácil como poner.
class _Undo extends StatelessWidget {
  const _Undo({required this.theme, required this.store});

  final UiTheme theme;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final last = store.habit.pieces.isEmpty ? null : store.habit.pieces.last;
    return Opacity(
      opacity: last == null ? 0.42 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: last == null ? null : () => _ask(context, last),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.undo, size: 20, color: t.fgSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quitar la última pieza', style: t.body),
                    const SizedBox(height: 2),
                    Text(
                      last == null
                          ? 'Este pueblo todavía no tiene ninguna.'
                          : 'La ${store.habit.total} de '
                                '${store.habit.name}, puesta el '
                                '${StoneCard.formatDate(last.placedAt)}.',
                      style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ask(BuildContext context, Piece last) {
    final t = theme;
    Sensory.instance.tick();
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        elevation: 0,
        title: Text('¿Quitar la pieza ${store.habit.total}?', style: t.body),
        content: Text(
          last.hasLabel
              ? 'Dice «${last.label}». Se va con ella.'
              : 'Vuelve a quedar en ${store.habit.total - 1}.',
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              store.removeLastPiece();
              Navigator.of(dialog).pop();
            },
            child: Text(
              'Quitarla',
              style: TextStyle(
                color: t.dark
                    ? const Color(0xFFCC5B48)
                    : const Color(0xFF9E3124),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.open,
    this.page,
    this.act,
  });

  final UiTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;

  /// A sheet that rises over this one.
  final Widget Function()? open;

  /// A whole screen that replaces it.
  final Widget Function()? page;

  /// O nada de eso: algo que pasa y ya, sin salir de aquí.
  final void Function(NavigatorState nav)? act;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Sensory.instance.tick();
        final nav = Navigator.of(context);
        final hacer = act;
        if (hacer != null) {
          hacer(nav);
          return;
        }
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
