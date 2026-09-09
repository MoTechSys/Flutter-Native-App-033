
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Google Drive appDataFolder backup (docs/06 phase 4, docs/05 §5).
/// One file per device: `sijil_<deviceId>.sijil`, overwritten on each upload.
/// The appDataFolder is hidden from the user's Drive UI and private to the app.
class DriveBackup {
  final GoogleSignIn _signIn = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);

  Future<GoogleSignInAccount?> currentUser() async {
    try {
      return _signIn.currentUser ?? await _signIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _signIn.signIn();
    } catch (e) {
      debugPrint('drive sign-in failed: $e');
      return null;
    }
  }

  Future<void> signOut() => _signIn.signOut();

  Future<drive.DriveApi?> _api() async {
    final client = await _signIn.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  static String fileName(String deviceId) => 'sijil_$deviceId.sijil';

  /// Uploads (creates or updates). Returns the Drive file id, or null on failure.
  Future<String?> upload(Uint8List bytes, {required String deviceId}) async {
    final api = await _api();
    if (api == null) return null;
    final name = fileName(deviceId);
    final existing = await _find(api, name);
    final media = drive.Media(Stream.value(bytes.toList()), bytes.length, contentType: 'application/json');
    if (existing != null) {
      final f = await api.files.update(drive.File(), existing, uploadMedia: media);
      return f.id;
    }
    final f = await api.files.create(drive.File()..name = name..parents = ['appDataFolder'], uploadMedia: media);
    return f.id;
  }

  /// Lists all device backups in the app folder (for restore on a new phone).
  Future<List<drive.File>> list() async {
    final api = await _api();
    if (api == null) return [];
    final r = await api.files.list(spaces: 'appDataFolder', $fields: 'files(id,name,modifiedTime,size)', orderBy: 'modifiedTime desc');
    return r.files ?? [];
  }

  Future<Uint8List?> download(String fileId) async {
    final api = await _api();
    if (api == null) return null;
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final chunks = <int>[];
    await for (final c in media.stream) {
      chunks.addAll(c);
    }
    return Uint8List.fromList(chunks);
  }

  Future<String?> _find(drive.DriveApi api, String name) async {
    final r = await api.files.list(spaces: 'appDataFolder', q: "name = '$name'", $fields: 'files(id)');
    return r.files?.firstOrNull?.id;
  }
}
