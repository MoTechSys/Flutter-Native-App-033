// تخزين غلاف مُختار (ويب): لا نظام ملفات → نُرمّز الصورة base64 داخل SQLite
import 'dart:convert';

import 'package:image_picker/image_picker.dart';

Future<String> storeCover(XFile picked) async {
  final bytes = await picked.readAsBytes();
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}
