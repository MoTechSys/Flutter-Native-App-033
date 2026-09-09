// ============================================================
// كِتابي - جلسة المستخدم (تُحفظ في SharedPreferences)
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repos/repos.dart';
import '../models/models.dart';

class Session extends ChangeNotifier {
  static const _kUserId = 'session.user_id';
  final _users = UserRepo();

  AppUser? _user;
  AppUser? get user => _user;
  bool get signedIn => _user != null;
  int get uid => _user?.id ?? 0;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt(_kUserId);
    if (id != null) {
      _user = await _users.byId(id);
      if (_user == null) await p.remove(_kUserId);
    }
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    final u = await _users.authenticate(email, password);
    if (u == null) return 'البريد أو كلمة المرور غير صحيحة';
    _user = u;
    (await SharedPreferences.getInstance()).setInt(_kUserId, u.id);
    notifyListeners();
    return null;
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? city,
  }) async {
    final err = await _users.register(name: name, email: email, password: password, phone: phone, city: city);
    if (err != null) return err;
    // دخول تلقائي بعد التسجيل مباشرة
    return signIn(email, password);
  }

  Future<void> refresh() async {
    if (_user == null) return;
    _user = await _users.byId(_user!.id);
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? phone, String? city}) async {
    await _users.updateProfile(uid, name: name, phone: phone, city: city);
    await refresh();
  }

  Future<bool> changePassword(String current, String next) =>
      _users.changePassword(uid, current, next);

  Future<void> signOut() async {
    _user = null;
    (await SharedPreferences.getInstance()).remove(_kUserId);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _users.deleteAccount(uid);
    await signOut();
  }
}
