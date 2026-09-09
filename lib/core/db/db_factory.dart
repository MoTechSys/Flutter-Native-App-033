import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Picks the right SQLite backend: native sqflite on Android/iOS,
/// sql.js (ffi_web) on Web for the preview build.
Future<(DatabaseFactory, String)> resolveDatabaseFactory(String fileName) async {
  if (kIsWeb) {
    return (databaseFactoryFfiWeb, fileName);
  }
  final dir = await mobile.getDatabasesPath();
  return (mobile.databaseFactory, '$dir/$fileName');
}
