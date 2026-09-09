import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Picks and stores photos (customers / receipts) inside the app's private
/// documents dir. Returns a path string usable by [CustomerAvatar]:
/// - mobile: absolute file path
/// - web (preview only): `mem:` in-memory key (not persisted across reloads)
class PhotoService {
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  /// In-memory store for web preview (no filesystem there).
  static final Map<String, Uint8List> memoryStore = {};
  static const memPrefix = 'mem:';

  /// Shows camera first (illiterate-friendly default) or gallery.
  Future<String?> pick({required bool fromCamera, String folder = 'customers'}) async {
    try {
      final x = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      return save(bytes, folder: folder);
    } catch (e) {
      debugPrint('photo pick failed: $e');
      return null;
    }
  }

  Future<String> save(Uint8List bytes, {String folder = 'customers'}) async {
    final name = '${_uuid.v4()}.jpg';
    if (kIsWeb) {
      final key = '$memPrefix$name';
      memoryStore[key] = bytes;
      return key;
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/photos/$folder');
    if (!await target.exists()) await target.create(recursive: true);
    final f = File('${target.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }
}
