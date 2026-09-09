// ============================================================
// كِتابي - التحكم بالوصول عن بُعد (Access Control)
//
// المصدر: ملف license.json في مستودع GitHub
//   { "active": true|false, "code": "XXXX", "message": "..." }
//
// القرار (sealed class AccessDecision):
//   Granted    : active=true  -> دخول مباشر بلا كود
//   Locked     : active=false -> يلزم كود؛ يُحفظ بعد أول نجاح ويبقى ما دام
//                               نفس الكود في الملف
//   Terminated : الملف/المستودع محذوف (404) -> إغلاق نهائي
//   Offline    : لا اتصال -> آخر قرار محفوظ
//
// لماذا GitHub API أولاً؟ لأن raw.githubusercontent يمرّ عبر CDN بكاش ~5
// دقائق، بينما API يعكس الكوميت الحالي فوراً. الخام احتياط عند تجاوز
// حد الطلبات (60/ساعة).
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

sealed class AccessDecision {
  const AccessDecision();
  bool get allowed => this is Granted;
  String get note => switch (this) {
    Granted(:final message) => message,
    Locked(:final message) => message,
    Terminated(:final message) => message,
    Offline(:final last) => last.note,
  };
}

class Granted extends AccessDecision {
  final String message;
  const Granted([this.message = '']);
}

class Locked extends AccessDecision {
  final String message;
  const Locked([this.message = '']);
}

class Terminated extends AccessDecision {
  final String message;
  const Terminated([this.message = '']);
}

class Offline extends AccessDecision {
  final AccessDecision last;
  const Offline(this.last);
  @override
  bool get allowed => last.allowed;
}

class AccessControl {
  AccessControl._();

  /// قابل للاستبدال في الاختبارات
  static http.Client transport = http.Client();

  static const owner = 'MoTechSys';
  static const repo = 'Flutter-Native-App-033';
  static const file = 'license.json';

  static const _kind = 'ac.kind'; // 0 granted, 1 locked, 2 terminated
  static const _msg = 'ac.msg';
  static const _serverCode = 'ac.server_code';
  static const _acceptedCode = 'ac.accepted_code';

  /// على الويب تُسبب ترويسات Cache-Control طلب Preflight يرفضه GitHub (CORS)،
  /// لذا نعتمد هناك على معامل كسر الكاش في الرابط فقط.
  static Map<String, String> get _headers =>
      kIsWeb ? const {} : const {'Cache-Control': 'no-store', 'Pragma': 'no-cache'};
  static const _timeout = Duration(seconds: 7);

  // -------------------------------------------------------------- public

  static Future<AccessDecision> resolve() async {
    final p = await SharedPreferences.getInstance();
    final r = await _read();

    if (r == null) return Offline(_cached(p));

    if (r.missing) {
      const m = 'تم إنهاء ترخيص هذه النسخة. يرجى التواصل مع المطوّر.';
      await _save(p, 2, m, '');
      return const Terminated(m);
    }

    if (r.active) {
      await _save(p, 0, r.message, r.code);
      return Granted(r.message);
    }

    final accepted = p.getString(_acceptedCode) ?? '';
    final open = r.code.isNotEmpty && accepted == r.code;
    await _save(p, open ? 0 : 1, r.message, r.code);
    return open ? Granted(r.message) : Locked(r.message);
  }

  /// يتحقق من الكود مقابل الخادم (أو آخر كود محفوظ عند انقطاع الشبكة)
  static Future<bool> redeem(String input) async {
    final code = input.trim().toUpperCase().replaceAll(' ', '');
    if (code.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    final r = await _read();
    if (r != null && r.missing) return false;
    final expected = r?.code ?? p.getString(_serverCode) ?? '';
    if (expected.isEmpty || expected != code) return false;
    await p.setString(_acceptedCode, expected);
    await p.setInt(_kind, 0);
    return true;
  }

  // -------------------------------------------------------------- internals

  static AccessDecision _cached(SharedPreferences p) {
    final m = p.getString(_msg) ?? '';
    return switch (p.getInt(_kind) ?? 0) {
      1 => Locked(m),
      2 => Terminated(m),
      _ => Granted(m),
    };
  }

  static Future<void> _save(SharedPreferences p, int kind, String msg, String code) async {
    await p.setInt(_kind, kind);
    await p.setString(_msg, msg);
    await p.setString(_serverCode, code);
  }

  static Future<_Remote?> _read() async => (await _viaApi()) ?? (await _viaRaw());

  static Future<_Remote?> _viaApi() async {
    try {
      final uri = Uri.https('api.github.com', '/repos/$owner/$repo/contents/$file', {'ref': 'main', '_': '${DateTime.now().microsecondsSinceEpoch}'});
      final res = await transport
          .get(uri, headers: {..._headers, 'Accept': 'application/vnd.github+json'})
          .timeout(_timeout);
      if (res.statusCode == 404) return _Remote.missing();
      if (res.statusCode != 200) return null;
      final meta = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final b64 = (meta['content'] as String? ?? '').replaceAll(RegExp(r'\s'), '');
      if (b64.isEmpty) return null;
      return _Remote.parse(utf8.decode(base64Decode(b64)));
    } catch (_) {
      return null;
    }
  }

  static Future<_Remote?> _viaRaw() async {
    try {
      final uri = Uri.https('raw.githubusercontent.com', '/$owner/$repo/main/$file',
          {'_': '${DateTime.now().microsecondsSinceEpoch}'});
      final res = await transport.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 404) return _Remote.missing();
      if (res.statusCode != 200) return null;
      return _Remote.parse(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }
}

class _Remote {
  final bool active;
  final String code;
  final String message;
  final bool missing;
  const _Remote({this.active = false, this.code = '', this.message = '', this.missing = false});
  factory _Remote.missing() => const _Remote(missing: true);
  factory _Remote.parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return _Remote(
      active: j['active'] == true,
      code: (j['code'] ?? '').toString().trim().toUpperCase(),
      message: (j['message'] ?? '').toString(),
    );
  }
}
