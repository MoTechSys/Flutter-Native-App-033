// تخزين غلاف مُختار (أندرويد/سطح المكتب): نسخ الملف إلى مجلد التطبيق الدائم
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// يُعيد المسار المطلق المحفوظ في SQLite
Future<String> storeCover(XFile picked) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/covers');
  if (!await dir.exists()) await dir.create(recursive: true);
  final dest = '${dir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await picked.saveTo(dest);
  return dest;
}
