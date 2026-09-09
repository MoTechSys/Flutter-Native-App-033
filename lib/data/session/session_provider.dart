import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/ledger/ledger_models.dart';

/// One row of `users`.
class AppUser {
  final String id;
  final String shopId;
  final String name;
  final String? photoPath;
  final bool isOwner;
  final bool hasPin;
  final bool isActive;
  const AppUser({
    required this.id,
    required this.shopId,
    required this.name,
    this.photoPath,
    required this.isOwner,
    required this.hasPin,
    required this.isActive,
  });

  factory AppUser.fromRow(Map<String, Object?> r) => AppUser(
        id: r['id'] as String,
        shopId: r['shop_id'] as String,
        name: r['name'] as String,
        photoPath: r['photo_path'] as String?,
        isOwner: r['role'] == 'owner',
        hasPin: r['pin_hash'] != null,
        isActive: (r['is_active'] as int? ?? 1) == 1,
      );

  Actor get actor => isOwner ? Actor.owner(id, name) : Actor.worker(id, name);
}

class Shop {
  final String id;
  final String name;
  final String? logoPath;
  final String? address;
  final String? phone;
  const Shop({required this.id, required this.name, this.logoPath, this.address, this.phone});

  factory Shop.fromRow(Map<String, Object?> r) => Shop(
        id: r['id'] as String,
        name: r['name'] as String,
        logoPath: r['logo_path'] as String?,
        address: r['address'] as String?,
        phone: r['phone'] as String?,
      );
}

/// Who is logged in on this phone (docs/03 §6.7, docs/05 §5).
/// Replaces the hard-coded owner Actor flagged in docs/10_AUDIT_PHASE0.md.
class SessionProvider extends ChangeNotifier {
  final Database _db;
  final SharedPreferences _prefs;
  SessionProvider(this._db, this._prefs);

  static const _kUser = 'session.user_id';
  static const _uuid = Uuid();

  Shop? _shop;
  AppUser? _user;
  List<AppUser> _users = const [];

  Shop? get shop => _shop;
  AppUser? get user => _user;
  List<AppUser> get users => _users;
  bool get hasShop => _shop != null;
  bool get isLoggedIn => _user != null;
  bool get isOwner => _user?.isOwner ?? false;

  /// Actor for ledger calls. Throws if nobody is logged in (never silently owner).
  Actor get actor {
    final u = _user;
    if (u == null) throw StateError('no user logged in');
    return u.actor;
  }

  Future<void> load() async {
    final shops = await _db.query('shops', orderBy: 'created_at', limit: 1);
    _shop = shops.isEmpty ? null : Shop.fromRow(shops.first);
    if (_shop != null) {
      final rows = await _db.query('users',
          where: 'shop_id = ? AND is_active = 1',
          whereArgs: [_shop!.id],
          orderBy: "CASE role WHEN 'owner' THEN 0 ELSE 1 END, created_at");
      _users = rows.map(AppUser.fromRow).toList();
      final saved = _prefs.getString(_kUser);
      _user = _users.where((u) => u.id == saved).firstOrNull;
    }
    notifyListeners();
  }

  /// First-run: create the shop and its owner. Returns the owner.
  Future<AppUser> createShop({
    required String shopName,
    required String ownerName,
    String? ownerPhotoPath,
    String? pin,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final shopId = _uuid.v4();
    final ownerId = _uuid.v4();
    await _db.insert('shops', {'id': shopId, 'name': shopName.trim(), 'created_at': now});
    final salt = _uuid.v4();
    await _db.insert('users', {
      'id': ownerId,
      'shop_id': shopId,
      'name': ownerName.trim(),
      'photo_path': ownerPhotoPath,
      'role': 'owner',
      'pin_hash': pin == null ? null : hashPin(pin, salt),
      'pin_salt': pin == null ? null : salt,
      'is_active': 1,
      'created_at': now,
    });
    await load();
    await login(ownerId);
    return _user!;
  }

  /// Log in without PIN check (user has no PIN) or after [verifyPin] succeeded.
  Future<void> login(String userId) async {
    final u = _users.where((x) => x.id == userId).firstOrNull;
    if (u == null) throw StateError('unknown user');
    _user = u;
    await _prefs.setString(_kUser, userId);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    await _prefs.remove(_kUser);
    notifyListeners();
  }

  Future<bool> verifyPin(String userId, String pin) async {
    final r = await _db.query('users',
        columns: ['pin_hash', 'pin_salt'], where: 'id = ?', whereArgs: [userId], limit: 1);
    if (r.isEmpty) return false;
    final hash = r.first['pin_hash'] as String?;
    final salt = r.first['pin_salt'] as String?;
    if (hash == null || salt == null) return true; // no PIN set
    return hashPin(pin, salt) == hash;
  }

  Future<void> setPin(String userId, String? pin) async {
    final salt = _uuid.v4();
    await _db.update(
        'users',
        {'pin_hash': pin == null ? null : hashPin(pin, salt), 'pin_salt': pin == null ? null : salt},
        where: 'id = ?',
        whereArgs: [userId]);
    await load();
  }

  @visibleForTesting
  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
