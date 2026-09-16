import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'recovery_key.dart';

abstract interface class RecoveryEnvelopeAccess {
  Future<RecoveryKeyEnvelope?> read();
  Future<void> write(RecoveryKeyEnvelope envelope);
  Future<void> delete();
}

class RecoveryEnvelopeStore implements RecoveryEnvelopeAccess {
  RecoveryEnvelopeStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const fileName = 'ispend_recovery_key_envelope_v1.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, fileName));
  }

  @override
  Future<RecoveryKeyEnvelope?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return RecoveryKeyEnvelope.fromJson(json);
  }

  @override
  Future<void> write(RecoveryKeyEnvelope envelope) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(envelope.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
