import 'dart:convert';
import 'dart:io';

import '../../models/level.dart';
import 'save_data.dart';

class SaveRepository {
  SaveRepository(this.directory, {this.fileName = 'revolt_cabino_save.json'});

  final Directory directory;
  final String fileName;

  File get _main => File('${directory.path}/$fileName');
  File get _backup => File('${directory.path}/$fileName.bak');
  File get _temp => File('${directory.path}/$fileName.tmp');

  SaveData load(Level Function(String id) lookup) {
    final mainText = _read(_main);
    if (mainText != null) {
      final decoded = _decode(mainText, lookup);
      if (decoded != null) return decoded;
    }
    final backupText = _read(_backup);
    if (backupText != null) {
      final decoded = _decode(backupText, lookup);
      if (decoded != null) return decoded;
    }
    final ledger = _salvageLedger(mainText) ?? _salvageLedger(backupText);
    if (ledger != null) return ledger;
    return SaveData.fresh();
  }

  void save(SaveData data) {
    directory.createSync(recursive: true);
    final payload = const JsonEncoder.withIndent('  ').convert(data.toJson());
    if (_main.existsSync()) {
      _main.copySync(_backup.path);
    }
    _temp.writeAsStringSync(payload, flush: true);
    _temp.renameSync(_main.path);
  }

  SaveData? _decode(String text, Level Function(String id) lookup) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      return SaveData.fromJson(json.cast<String, Object?>(), lookup: lookup);
    } catch (_) {
      return null;
    }
  }

  SaveData? _salvageLedger(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final map = json.cast<String, Object?>();
      if (map['permanentEntitlements'] is! List &&
          map['processedTransactionIds'] is! List &&
          map['hintBalance'] == null) {
        return null;
      }
      return SaveData.fromJson(map, lookup: _missingLevel);
    } catch (_) {
      return null;
    }
  }

  String? _read(File file) {
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }
}

Level _missingLevel(String id) => throw StateError('Missing level $id');
