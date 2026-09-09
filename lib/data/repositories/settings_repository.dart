import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Typed access to the `settings` key/value table (docs/05 §4).
/// Every key has a default so the app never reads null.
class SettingsRepository extends ChangeNotifier {
  final Database _db;
  SettingsRepository(this._db);

  final Map<String, Object?> _cache = {};
  bool _loaded = false;

  // ---- keys (D11: editable labels; docs/03 §7 voice; docs/03 §2 numerals) ----
  static const kLabelTook = 'label.took'; // "أخذ مني"
  static const kLabelPaid = 'label.paid'; // "دفع لي"
  static const kVoiceEnabled = 'voice.enabled';
  static const kVoiceRate = 'voice.rate';
  static const kArabicDigits = 'display.arabic_digits';
  static const kDarkMode = 'display.dark';
  static const kFontScale = 'display.font_scale';
  static const kOverdueDays = 'overdue.days';
  static const kLockedBefore = 'locked_before'; // read by LedgerService (ms epoch)
  static const kBigPaymentAlertMinor = 'alert.big_payment_minor';
  static const kReminderTemplate = 'reminder.template';
  static const kAutoLockMinutes = 'security.auto_lock_minutes';
  static const kActivationCode = 'activation.code';
  static const kActivationExpires = 'activation.expires_ms';
  static const kLastLocalBackupAt = 'backup.last_local_ms';
  static const kInstalledAt = 'app.installed_ms';

  static const Map<String, Object?> defaults = {
    kLabelTook: 'أخذ مني',
    kLabelPaid: 'دفع لي',
    kVoiceEnabled: true,
    kVoiceRate: 0.45,
    kArabicDigits: false,
    kDarkMode: false,
    kFontScale: 1.0,
    kOverdueDays: 30,
    kLockedBefore: null,
    kBigPaymentAlertMinor: 50000,
    kReminderTemplate:
        'السلام عليكم {name}،\nتذكير من {shop}: المتبقي عليك {amount} ({words}).\nنشكر تعاونك.',
    kAutoLockMinutes: 0,
    kActivationCode: null,
    kActivationExpires: null,
    kLastLocalBackupAt: null,
    kInstalledAt: null,
  };

  Future<void> load() async {
    final rows = await _db.query('settings');
    _cache.clear();
    for (final r in rows) {
      _cache[r['key'] as String] = jsonDecode(r['value_json'] as String);
    }
    if (_cache[kInstalledAt] == null) {
      await set(kInstalledAt, DateTime.now().toUtc().millisecondsSinceEpoch, notify: false);
    }
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;

  T get<T>(String key) {
    final v = _cache.containsKey(key) ? _cache[key] : defaults[key];
    if (v is T) return v;
    // JSON gives int for whole doubles; coerce.
    if (T == double && v is num) return v.toDouble() as T;
    if (T == int && v is num) return v.toInt() as T;
    return defaults[key] as T;
  }

  Future<void> set(String key, Object? value, {bool notify = true}) async {
    _cache[key] = value;
    await _db.insert(
      'settings',
      {'key': key, 'value_json': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (notify) notifyListeners();
  }

  // ---- convenience ----
  String get labelTook => get<String>(kLabelTook);
  String get labelPaid => get<String>(kLabelPaid);
  bool get voiceEnabled => get<bool>(kVoiceEnabled);
  bool get arabicDigits => get<bool>(kArabicDigits);
  bool get darkMode => get<bool>(kDarkMode);
  double get fontScale => get<double>(kFontScale);
  int get overdueDays => get<int>(kOverdueDays);
  DateTime? get lockedBefore {
    final v = get<int?>(kLockedBefore);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }
}
