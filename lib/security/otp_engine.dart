// ============================================================
// كِتابي - محرّك رموز التحقق (OTP) لاستعادة كلمة المرور
//   الرمز: 5 خانات حرف/رقم بصيغة  XX-XXX  (مثال: K7-3BQ)
//   الصلاحية: دقيقتان · الحد: 3 محاولات · قفل إعادة الإرسال 30 ثانية
// ============================================================

import 'dart:math';

class OtpEngine {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بلا 0/O/1/I
  static const length = 5;
  static const validity = Duration(minutes: 2);
  static const maxAttempts = 3;
  static const resendCooldown = Duration(seconds: 30);

  final Random _rng;
  OtpEngine([Random? rng]) : _rng = rng ?? Random.secure();

  String _code = '';
  DateTime? _issuedAt;
  int _attempts = 0;

  String get raw => _code;

  /// عرض منسّق: K7-3BQ
  String get display =>
      _code.isEmpty ? '' : '${_code.substring(0, 2)}-${_code.substring(2)}';

  bool get hasCode => _code.isNotEmpty;
  int get attemptsLeft => maxAttempts - _attempts;

  Duration get remaining {
    if (_issuedAt == null) return Duration.zero;
    final d = _issuedAt!.add(validity).difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get expired => hasCode && remaining == Duration.zero;

  Duration get resendWait {
    if (_issuedAt == null) return Duration.zero;
    final d = _issuedAt!.add(resendCooldown).difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get canResend => !hasCode || resendWait == Duration.zero;

  String issue() {
    _code = List.generate(length, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();
    _issuedAt = DateTime.now();
    _attempts = 0;
    return _code;
  }

  OtpResult verify(String input) {
    if (!hasCode) return OtpResult.noCode;
    if (expired) return OtpResult.expired;
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean == _code) {
      _code = '';
      return OtpResult.ok;
    }
    _attempts++;
    if (_attempts >= maxAttempts) {
      _code = '';
      return OtpResult.lockedOut;
    }
    return OtpResult.wrong;
  }

  void reset() {
    _code = '';
    _issuedAt = null;
    _attempts = 0;
  }
}

enum OtpResult { ok, wrong, expired, lockedOut, noCode }
