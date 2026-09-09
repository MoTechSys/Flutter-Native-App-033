import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Offline activation codes (docs/01 monetization: sold via Jawali/OneCash,
/// no internet needed to activate).
///
/// Code format (human-typeable, 4 groups):  `SJL-PPPP-EEEE-SSSSSS`
/// - PPPP   : plan (`Y1` one year, `Y3` three years, `LIFE` lifetime), padded
/// - EEEE   : expiry as days since 2024-01-01 in base36 (LIFE → `ZZZZ`)
/// - SSSSSS : first 6 base32 chars of HMAC-SHA256(secret, "$plan|$expiry|$deviceId")
///
/// The code is bound to a device id so one code cannot be shared. The seller
/// runs `tool/gen_activation.dart` with the secret; the app only holds the
/// same secret to verify. Brute-force space: 32^6 ≈ 1.07e9 per device/plan/expiry
/// — plus the app rate-limits attempts (5 per hour, see ActivationScreen).
class Activation {
  Activation._();

  /// Replace before release; keep identical in tool/gen_activation.dart.
  static const secret = 'SIJIL-2026-OFFLINE-ACTIVATION-SECRET-CHANGE-ME';

  static final _epoch = DateTime.utc(2024, 1, 1);
  static const _b32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 confusion

  static String generate({
    required String plan,
    required DateTime? expires,
    required String deviceId,
    String secretKey = secret,
  }) {
    final p = _pad(plan.toUpperCase(), 4);
    final e = expires == null ? 'ZZZZ' : _b36(expires.toUtc().difference(_epoch).inDays).padLeft(4, '0');
    final sig = _sign(p, e, deviceId, secretKey);
    return 'SJL-$p-$e-$sig';
  }

  /// Returns the parsed activation or null when invalid for this device.
  static ActivationInfo? verify(String code, String deviceId, {String secretKey = secret}) {
    final c = _normalize(code);
    final m = RegExp(r'^SJL-([A-Z0-9-]{4})-([A-Z0-9]{4})-([A-Z2-9]{6})$').firstMatch(c);
    if (m == null) return null;
    final p = m[1]!, e = m[2]!, sig = m[3]!;
    if (_sign(p, e, deviceId, secretKey) != sig) return null;
    DateTime? expires;
    if (e != 'ZZZZ') {
      final days = int.tryParse(e, radix: 36);
      if (days == null) return null;
      expires = _epoch.add(Duration(days: days));
    }
    return ActivationInfo(plan: p.replaceAll('-', ''), expires: expires, code: c);
  }

  static String _sign(String p, String e, String deviceId, String key) {
    final mac = Hmac(sha256, utf8.encode(key)).convert(utf8.encode('$p|$e|$deviceId')).bytes;
    // 6 chars × 5 bits = 30 bits from the first 4 bytes.
    var bits = 0;
    for (var i = 0; i < 4; i++) {
      bits = (bits << 8) | mac[i];
    }
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.write(_b32[(bits >> (27 - i * 5)) & 31]);
    }
    return sb.toString();
  }

  static String _pad(String s, int n) => s.length >= n ? s.substring(0, n) : s.padRight(n, '-');
  static String _b36(int v) => v.toRadixString(36).toUpperCase();

  /// Accepts lowercase, Arabic digits, missing dashes, spaces.
  static String _normalize(String raw) {
    var s = raw.trim().toUpperCase();
    s = s.replaceAllMapped(RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString());
    s = s.replaceAll(RegExp(r'[\s_]'), '');
    // Canonical form is 3-4-4-6 = 17 chars + 3 separators. Rebuild separators
    // from the raw alphanumerics; a plan shorter than 4 is padded with '-'.
    final body = s.replaceAll('-', '');
    if (s.startsWith('SJL') && body.length >= 15 && body.length <= 17) {
      final plan = body.substring(3, body.length - 10).padRight(4, '-');
      final tail = body.substring(body.length - 10);
      s = 'SJL-$plan-${tail.substring(0, 4)}-${tail.substring(4)}';
    }
    return s;
  }
}

class ActivationInfo {
  final String plan;
  final DateTime? expires;
  final String code;
  const ActivationInfo({required this.plan, required this.expires, required this.code});

  bool get isLifetime => expires == null;
  bool isValidAt(DateTime now) => expires == null || now.toUtc().isBefore(expires!);

  String get planAr => switch (plan) {
        'Y1' => 'سنة واحدة',
        'Y3' => 'ثلاث سنوات',
        'LIFE' => 'مدى الحياة',
        _ => plan,
      };
}

/// Trial policy: 30 days from install, then read-only + PDF watermark
/// (docs/01 D-monetization). Nothing is ever deleted.
class TrialPolicy {
  TrialPolicy._();
  static const trialDays = 30;

  static int daysLeft(DateTime installedAt, DateTime now) =>
      trialDays - now.toUtc().difference(installedAt.toUtc()).inDays;
}
