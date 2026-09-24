import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The result of trying to put a generated file somewhere the user can reach it.
class SaveOutcome {
  const SaveOutcome._(this.status, {this.path, this.error});

  const SaveOutcome.cancelled() : this._(SaveStatus.cancelled);

  final SaveStatus status;
  final String? path;
  final Object? error;

  bool get ok =>
      status == SaveStatus.saved || status == SaveStatus.savedToAppFolder;
}

enum SaveStatus { saved, savedToAppFolder, cancelled, failed }

/// Writing generated files out and handing them to the share sheet.
///
/// Pulled out of the settings screen's backup export so the report PDF and the
/// hydration card get the same hard-won behaviour: some Android pickers hand
/// back a path without writing anything to it, and on the devices where the
/// picker fails outright the user should still end up with a real file.
class FileShareService {
  const FileShareService._();

  static Future<SaveOutcome> save(
    Uint8List bytes,
    String fileName, {
    String dialogTitle = 'Save file',
  }) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        bytes: bytes,
      );
      if (path == null) return const SaveOutcome.cancelled();

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return SaveOutcome._(SaveStatus.saved, path: path);
    } catch (error) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return SaveOutcome._(SaveStatus.savedToAppFolder, path: file.path);
      } catch (_) {
        return SaveOutcome._(SaveStatus.failed, error: error);
      }
    }
  }

  /// Hands [bytes] to the system share sheet.
  ///
  /// The file has to exist on disk for other apps to read it, so it goes to the
  /// cache directory first. Android clears that on its own schedule, which is
  /// what we want — a shared report is a copy, not something to accumulate.
  static Future<void> share(
    Uint8List bytes,
    String fileName, {
    String? text,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
        subject: subject,
      ),
    );
  }
}
