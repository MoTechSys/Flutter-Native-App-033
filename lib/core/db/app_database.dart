import 'package:sqflite_common/sqlite_api.dart';

import 'schema.dart';

/// Thin owner of the SQLite [Database]. The concrete [DatabaseFactory] is
/// injected so the same code runs on Android (sqflite), Web (ffi_web) and
/// in unit tests (ffi in-memory).
class AppDatabase {
  final Database db;
  AppDatabase._(this.db);

  static Future<AppDatabase> open({
    required DatabaseFactory factory,
    required String path,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: Schema.version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          for (final s in Schema.createStatements) {
            await db.execute(s);
          }
          for (final s in Schema.seedStatements) {
            await db.execute(s);
          }
          await db.insert('schema_meta', {'version': version});
        },
        onUpgrade: (db, oldV, newV) async {
          // Future migrations go here (docs/04_LEDGER_RULES.md §5).
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}
