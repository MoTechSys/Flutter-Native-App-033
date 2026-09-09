import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/db/schema.dart';

/// Backup / restore (docs/06 phases 1 & 4).
///
/// Format `.sijil` = JSON envelope:
/// { "format": "sijil-backup", "version": 1, "schema": 1, "created_at": ms,
///   "device_id": "...", "sha256": hex-of-tables-json, "tables": {name: [rows]} }
/// Transactions are exported verbatim (append-only), so a restore re-imports
/// with INSERT OR IGNORE keyed by (device_id, local_seq) — idempotent (R6).
class BackupService {
  final Database _db;
  final String deviceId;
  BackupService(this._db, {required this.deviceId});

  static const tables = [
    'shops', 'users', 'currencies', 'fx_rates', 'customers', 'transactions',
    'reminders', 'audit_log', 'doc_templates', 'settings', 'sync_state',
  ];

  Future<Map<String, Object?>> snapshot() async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      data[t] = await _db.query(t);
    }
    final payload = jsonEncode(data);
    return {
      'format': 'sijil-backup',
      'version': 1,
      'schema': Schema.version,
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'device_id': deviceId,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'tables': data,
    };
  }

  Future<Uint8List> exportBytes() async => Uint8List.fromList(utf8.encode(jsonEncode(await snapshot())));

  /// Local daily backup into `سِجِل/النسخ_الاحتياطية/`. Keeps the last 14.
  Future<File?> writeLocal() async {
    if (kIsWeb) return null;
    final dir = await backupDir();
    final ts = DateTime.now();
    final name = 'sijil_${ts.year}-${two(ts.month)}-${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}.sijil';
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(await exportBytes(), flush: true);
    await _prune(dir, keep: 14);
    return f;
  }

  Future<List<File>> localBackups() async {
    if (kIsWeb) return [];
    final dir = await backupDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.sijil')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Validates envelope + checksum. Throws with an Arabic message on failure.
  static Map<String, Object?> parse(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('الملف ليس نسخة سِجِل صالحة');
    }
    if (decoded is! Map || decoded['format'] != 'sijil-backup') {
      throw const FormatException('الملف ليس نسخة سِجِل');
    }
    final m = Map<String, Object?>.from(decoded);
    if ((m['schema'] as int? ?? 0) > Schema.version) {
      throw const FormatException('النسخة من إصدار أحدث — حدّث التطبيق أولاً');
    }
    final tablesJson = jsonEncode(m['tables']);
    if (sha256.convert(utf8.encode(tablesJson)).toString() != m['sha256']) {
      throw const FormatException('الملف تالف (فشل التحقق)');
    }
    return m;
  }

  /// Restore strategy (docs/06 phase 4): a safety backup is written first,
  /// then rows are merged with INSERT OR IGNORE (never overwrite, never delete).
  /// Returns counts of inserted rows per table.
  Future<Map<String, int>> restore(Uint8List bytes, {bool safetyBackup = true}) async {
    final m = parse(bytes);
    if (safetyBackup) await writeLocal();
    final tablesData = Map<String, Object?>.from(m['tables'] as Map);
    final counts = <String, int>{};
    await _db.transaction((txn) async {
      for (final t in tables) {
        final rows = (tablesData[t] as List?)?.cast<Map>() ?? const [];
        var n = 0;
        for (final r in rows) {
          final row = Map<String, Object?>.from(r);
          if (t == 'settings') {
            // settings: keep local value if present (device preferences)
            final id = await txn.insert('settings', row, conflictAlgorithm: ConflictAlgorithm.ignore);
            if (id != 0) n++;
            continue;
          }
          final id = await txn.insert(t, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (id != 0) n++;
        }
        counts[t] = n;
      }
    });
    return counts;
  }

  static Future<Directory> backupDir() async {
    Directory base;
    try {
      final ext = Platform.isAndroid ? await getExternalStorageDirectory() : null;
      if (ext != null) {
        final root = ext.path.split('/Android/').first;
        final pkg = ext.path.split('/Android/data/').last.split('/').first;
        base = Directory('$root/Android/media/$pkg/سِجِل');
      } else {
        base = Directory('${(await getApplicationDocumentsDirectory()).path}/سِجِل');
      }
    } catch (_) {
      base = Directory('${(await getApplicationDocumentsDirectory()).path}/سِجِل');
    }
    final dir = Directory('${base.path}/النسخ_الاحتياطية');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _prune(Directory dir, {required int keep}) async {
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.sijil')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static String two(int n) => n.toString().padLeft(2, '0');
}
