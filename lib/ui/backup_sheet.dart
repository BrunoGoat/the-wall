import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fx/sensory.dart';
import '../model/store.dart';
import 'style.dart';

/// Taking your valley with you, and putting it back.
///
/// A town is a year of mornings and it should not be able to vanish for a
/// reason that has nothing to do with you: a lost phone, a signing key that
/// changed so Android refused the update, somebody clearing an app's storage
/// by mistake. None of that is your fault and none of it should cost you the
/// pieces you actually earned.
///
/// So: two buttons and no cleverness. One copies everything to the clipboard,
/// the other reads it back. Plain text on purpose — paste it into a note, mail
/// it to yourself, keep it wherever you keep things. It is your history, and
/// you should be able to open it and read the dates.
class BackupSheet extends StatefulWidget {
  const BackupSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  State<BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<BackupSheet> {
  final TextEditingController _paste = TextEditingController();
  String? _said;
  bool _wrong = false;
  bool _pasting = false;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _say(String text, {bool wrong = false}) {
    setState(() {
      _said = text;
      _wrong = wrong;
    });
  }

  Future<void> _copy() async {
    Sensory.instance.tick();
    final text = widget.store.exportSave();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _say(
      'Copiado: ${widget.store.describe()}. Pegalo donde lo vayas a '
      'encontrar — una nota, un mail a vos mismo.',
    );
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _say('No hay nada copiado ahora mismo.', wrong: true);
      return;
    }
    _paste.text = text;
    _say('Pegado. Mirá que sea el tuyo y confirmá abajo.');
  }

  void _restore() {
    final store = widget.store;
    final before = store.describe();
    final wrong = store.importSave(_paste.text);
    if (wrong != null) {
      Sensory.instance.tick();
      _say(wrong, wrong: true);
      return;
    }
    Sensory.instance.milestone();
    _say('Listo: ${store.describe()}. Antes había $before.');
    setState(() {
      _pasting = false;
      _paste.clear();
    });
  }

  void _confirm() {
    final t = widget.theme;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        elevation: 0,
        title: Text('¿Reemplazar lo que hay?', style: t.body),
        content: Text(
          'Ahora mismo tenés ${widget.store.describe()}. Volver a meter una '
          'copia deja el valle exactamente como estaba en ella, y lo de ahora '
          'se pierde. Si no estás seguro, copiá esto primero.',
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialog).pop();
              _restore();
            },
            child: Text(
              'Reemplazar',
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SheetSurface(
        theme: t,
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text('TUS DATOS', style: t.label),
              const SizedBox(height: 10),
              Text(
                'Tenés ${widget.store.describe()}. Todo eso vive sólo en este '
                'teléfono: la app no manda nada a ningún lado y no hay cuenta '
                'que lo recupere. Sacá una copia de vez en cuando.',
                style: t.bodySoft,
              ),

              const SizedBox(height: 18),
              _Wide(
                theme: t,
                icon: Icons.copy_all_outlined,
                label: 'Copiar mi valle',
                onTap: _copy,
                filled: true,
              ),
              const SizedBox(height: 10),
              _Wide(
                theme: t,
                icon: Icons.settings_backup_restore,
                label: _pasting ? 'Dejar de restaurar' : 'Volver a meterlo',
                onTap: () {
                  Sensory.instance.tick();
                  setState(() {
                    _pasting = !_pasting;
                    _said = null;
                    if (!_pasting) _paste.clear();
                  });
                },
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_pasting
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pegá acá la copia que guardaste.',
                                    style: t.bodySoft,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _fromClipboard,
                                  style: TextButton.styleFrom(
                                    foregroundColor: t.accent,
                                  ),
                                  child: const Text('Pegar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _paste,
                              maxLines: 4,
                              style: t.bodySoft.copyWith(fontSize: 11),
                              decoration: InputDecoration(
                                hintText: '{"v":1,"a":0,"h":[…',
                                hintStyle: t.bodySoft.copyWith(fontSize: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: t.stroke),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: t.stroke),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Wide(
                              theme: t,
                              icon: Icons.check,
                              label: 'Reemplazar lo que hay',
                              onTap: _confirm,
                              filled: true,
                            ),
                          ],
                        ),
                      ),
              ),

              if (_said != null) ...[
                const SizedBox(height: 14),
                Text(
                  _said!,
                  style: t.bodySoft.copyWith(
                    color: _wrong ? const Color(0xFFC9736E) : t.accent,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final UiTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent.withValues(alpha: 0.85),
                foregroundColor: t.dark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.fg,
                side: BorderSide(color: t.stroke),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }
}
