import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/backup_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/shell_nav.dart';

/// Appearance, plus export and import of the whole configuration as one JSON
/// file. Nothing leaves the device unless the user picks a destination
/// themselves.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;

    return Scaffold(
      appBar: AppBar(
        leading: const NavMenuButton(),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          const SectionHeader(title: 'Appearance'),
          _AppearancePicker(
            selected: state.themeMode,
            onSelected: (mode) => AppScope.read(context).setThemeMode(mode),
          ),
          const SizedBox(height: 14),
          _FontPicker(
            selected: state.font,
            onSelected: (font) => AppScope.read(context).setFont(font),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Backup'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What gets saved',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your water settings, every medicine with its days and times, '
                  'your drink history and your dose history. All of it stays on '
                  'this phone — the export file is the only copy that can leave '
                  'it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${state.medicines.length}',
                        label: 'medicines',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${state.waterLog.length}',
                        label: 'drinks logged',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: formatInterval(settings.intervalMinutes),
                        label: 'interval',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Export'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Save JSON file'),
                  subtitle: Text(
                    'Choose where to keep your backup',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: _busy ? null : _exportToFile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copy JSON to clipboard'),
                  subtitle: Text(
                    'Paste it anywhere you like',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: _busy ? null : _copyToClipboard,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('Preview JSON'),
                  onTap: _busy ? null : _previewJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Import'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Open a backup file'),
                  subtitle: Text(
                    'Pick a .json file you exported before',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: _busy ? null : _importFromFile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.content_paste_go_outlined),
                  title: const Text('Paste JSON'),
                  subtitle: Text(
                    'Use this if the file picker is unavailable',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: _busy ? null : _importFromPaste,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Danger zone'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erase everything',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Removes all settings, medicines and history from this device '
                  'and cancels every scheduled reminder. Export first if you '
                  'might want it back.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: _busy ? null : _confirmReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.of(context).clay,
                    side: BorderSide(color: AppColors.of(context).clay),
                  ),
                  child: const Text('Erase everything'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'About'),
          _AboutPanel(onCopyEmail: _copyFeedbackEmail),
        ],
      ),
    );
  }

  Future<void> _copyFeedbackEmail() async {
    await Clipboard.setData(const ClipboardData(text: kFeedbackEmail));
    _snack('Email address copied — $kFeedbackEmail');
  }

  // --- Export ---------------------------------------------------------------

  Future<void> _exportToFile() async {
    final json = AppScope.read(context).exportJson();
    setState(() => _busy = true);
    try {
      final bytes = Uint8List.fromList(utf8.encode(json));
      final fileName = BackupService.suggestedFileName();

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your backup',
        fileName: fileName,
        bytes: bytes,
      );

      if (path == null) {
        // The user cancelled the picker; not an error worth reporting.
        return;
      }

      // Some Android pickers return a path without writing the bytes, so make
      // sure the file really exists on disk.
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes, flush: true);
      }

      _snack('Backup saved as $fileName');
    } catch (error) {
      await _fallbackExport(json, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// If the system picker fails, still give the user a real file.
  Future<void> _fallbackExport(String json, Object error) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${BackupService.suggestedFileName()}');
      await file.writeAsString(json, flush: true);
      _snack('Saved inside the app folder: ${file.path}');
    } catch (_) {
      _snack('Could not save the file. Copy the JSON instead. ($error)');
    }
  }

  Future<void> _copyToClipboard() async {
    final json = AppScope.read(context).exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    _snack('JSON copied to the clipboard');
  }

  Future<void> _previewJson() async {
    final json = AppScope.read(context).exportJson();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                BackupService.suggestedFileName(),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Import ---------------------------------------------------------------

  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      String raw;
      if (picked.bytes != null) {
        raw = utf8.decode(picked.bytes!, allowMalformed: true);
      } else if (picked.path != null) {
        raw = await File(picked.path!).readAsString();
      } else {
        _snack('Could not read that file.');
        return;
      }

      await _applyImport(raw);
    } catch (error) {
      _snack('Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromPaste() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteJsonDialog(),
    );
    if (raw == null || raw.trim().isEmpty) return;
    await _applyImport(raw);
  }

  Future<void> _applyImport(String raw) async {
    late final BackupBundle bundle;
    try {
      bundle = BackupService.decode(raw);
    } on BackupParseException catch (error) {
      _snack(error.message);
      return;
    }

    if (!mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import this backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bundle.summary),
            if (bundle.exportedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Exported ${formatDayLabel(bundle.exportedAt!)} at '
                '${formatClock(bundle.exportedAt!)}',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Replace wipes what is on this phone first. Merge keeps your '
              'current data and adds anything new.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('merge'),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('replace'),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (mode == null || !mounted) return;

    await AppScope.read(context).importBundle(bundle, merge: mode == 'merge');
    _snack(
      mode == 'merge'
          ? 'Backup merged and reminders rescheduled'
          : 'Backup restored and reminders rescheduled',
    );
  }

  // --- Reset ----------------------------------------------------------------

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erase everything?'),
        content: const Text(
          'All settings, medicines and history will be deleted from this '
          'device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.of(context).clay,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await AppScope.read(context).resetEverything();
    _snack('Everything erased');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Each row is set in the font it offers — a font list that all renders in the
/// same typeface tells you nothing. The sample uses digits and a unit because
/// that is what this app actually shows you all day.
class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.selected, required this.onSelected});

  final AppFont selected;
  final ValueChanged<AppFont> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final font in AppFont.values) ...[
            if (font != AppFont.values.first)
              Divider(height: 1, color: palette.hairline),
            _FontRow(
              font: font,
              selected: font == selected,
              onTap: () => onSelected(font),
            ),
          ],
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final AppFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '${font.label} font',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        font.label,
                        style: TextStyle(
                          fontFamily: font.family,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? palette.aquaDeep : palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        font.note,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // The sample, so the choice can be judged before it is made.
                Text(
                  '1,850 ml',
                  style: TextStyle(
                    fontFamily: font.family,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: palette.inkSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: selected ? palette.aqua : palette.hairline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its own controller so it lives exactly as long as the dialog does — see
/// the note on _AmountDialog in water_settings_screen.dart.
class _PasteJsonDialog extends StatefulWidget {
  const _PasteJsonDialog();

  @override
  State<_PasteJsonDialog> createState() => _PasteJsonDialogState();
}

class _PasteJsonDialogState extends State<_PasteJsonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste your backup JSON'),
      content: TextField(
        controller: _controller,
        maxLines: 8,
        minLines: 5,
        decoration: const InputDecoration(hintText: '{ "app": "drink_water" …'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Read it'),
        ),
      ],
    );
  }
}

/// Shown in About and copied to the clipboard on tap. Declared here rather than
/// inline so there is exactly one place to change it.
const String kFeedbackEmail = 'connecttoranjan@gmail.com';
const String kAppVersion = '1.0.0';
const String kAuthorName = 'Ranjan Dutta';

/// Who made this, what it does, and where to send feedback.
///
/// The email is copied to the clipboard rather than opened in a mail client:
/// launching a mailto: intent would mean taking on url_launcher, and copying
/// works even on a phone with no mail app configured.
class _AboutPanel extends StatelessWidget {
  const _AboutPanel({required this.onCopyEmail});

  final Future<void> Function() onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.aquaWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: palette.aquaDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Drink Water', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text('Version $kAppVersion', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'A quiet companion for two habits that are easy to forget: drinking '
            'enough water and taking your medicine on time.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Set an interval and a daily target, and reminders arrive on their '
            'own — even when the app is closed. Add as many medicines as you '
            'need, each with its own days and times. Log a drink or a dose '
            'straight from the notification, and look back over your week or '
            'month whenever you want to see how you are doing.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'There is no account, no sign-in and no server. Everything lives on '
            'this phone, and the only copy that ever leaves it is a backup file '
            'you save yourself.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: palette.hairline),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.code_rounded, size: 16, color: palette.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: text.bodySmall,
                    children: [
                      const TextSpan(text: 'Developed by '),
                      TextSpan(
                        text: kAuthorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('For your feedback please email to', style: text.bodySmall),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onCopyEmail,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.aquaWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.hairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 17,
                      color: palette.aquaDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kFeedbackEmail,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: palette.aquaDeep,
                        ),
                      ),
                    ),
                    Icon(Icons.copy_rounded, size: 15, color: palette.aquaDeep),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three swatch cards rather than a radio list: the point of a theme setting is
/// to show what you are choosing, so each card is painted in its own palette.
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({required this.selected, required this.onSelected});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Column(
      children: [
        Row(
          children: [
            for (final option in _themeOptions) ...[
              if (option != _themeOptions.first) const SizedBox(width: 10),
              Expanded(
                child: _ThemeCard(
                  option: option,
                  selected: selected == option.mode,
                  onTap: () => onSelected(option.mode),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.info_outline, size: 15, color: palette.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected == ThemeMode.system
                    ? 'Following your phone, so it switches with your '
                          'system-wide dark mode.'
                    : 'Locked to ${selected == ThemeMode.dark ? 'dark' : 'light'}, '
                          'whatever your phone is set to.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeOption {
  const _ThemeOption(this.mode, this.label, this.icon, this.preview);

  final ThemeMode mode;
  final String label;
  final IconData icon;

  /// Null for "system": that card shows both palettes split down the middle.
  final AppPalette? preview;
}

const List<_ThemeOption> _themeOptions = [
  _ThemeOption(
    ThemeMode.system,
    'System',
    Icons.brightness_auto_outlined,
    null,
  ),
  _ThemeOption(
    ThemeMode.light,
    'Light',
    Icons.light_mode_outlined,
    AppPalette.light,
  ),
  _ThemeOption(
    ThemeMode.dark,
    'Dark',
    Icons.dark_mode_outlined,
    AppPalette.dark,
  ),
];

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} theme',
      // The ink has to live *inside* the decorated box: an InkWell wrapped
      // around an opaque container paints its ripple underneath it, where
      // nobody can see it.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? palette.aquaWash : palette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? palette.aqua : palette.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  _Swatch(preview: option.preview),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : option.icon,
                        size: 15,
                        color: selected ? palette.aquaDeep : palette.inkSoft,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? palette.aquaDeep : palette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature of the home screen: ground, panel, and a water bar.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.preview});

  final AppPalette? preview;

  @override
  Widget build(BuildContext context) {
    final showBoth = preview == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 44,
        child: showBoth
            ? const Row(
                children: [
                  Expanded(
                    child: _SwatchHalf(
                      palette: AppPalette.light,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  Expanded(
                    child: _SwatchHalf(
                      palette: AppPalette.dark,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              )
            : _SwatchHalf(palette: preview!, alignment: Alignment.center),
      ),
    );
  }
}

class _SwatchHalf extends StatelessWidget {
  const _SwatchHalf({required this.palette, required this.alignment});

  final AppPalette palette;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.canvas,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: palette.hairline, width: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: alignment,
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.aqua,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: palette.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
