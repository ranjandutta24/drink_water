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

/// Export and import the whole configuration as one JSON file.
/// Nothing leaves the device unless the user picks a destination themselves.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
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
                    foregroundColor: AppColors.clay,
                    side: const BorderSide(color: AppColors.clay),
                  ),
                  child: const Text('Erase everything'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      backgroundColor: Colors.white,
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
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste your backup JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          minLines: 5,
          decoration: const InputDecoration(
            hintText: '{ "app": "drink_water" …',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Read it'),
          ),
        ],
      ),
    );
    controller.dispose();
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
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
