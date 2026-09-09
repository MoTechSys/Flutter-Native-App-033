// ============================================================
// كِتابي - شاشة القفل (تظهر عند إيقاف النسخة عن بُعد)
// تصميم: شعار كبير في الأعلى + لوح سفلي ثابت بأزرار الإجراء
// ============================================================

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../security/access_control.dart';

class LockedPage extends StatefulWidget {
  final AccessDecision decision;
  final VoidCallback onGranted;
  const LockedPage({super.key, required this.decision, required this.onGranted});

  @override
  State<LockedPage> createState() => _LockedPageState();
}

class _LockedPageState extends State<LockedPage> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _checking = false;
  String? _err;

  bool get _terminated =>
      widget.decision is Terminated || (widget.decision is Offline && (widget.decision as Offline).last is Terminated);

  Future<void> _redeem() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _err = 'أدخل كود التفعيل');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final ok = await AccessControl.redeem(_code.text);
    if (!mounted) return;
    if (ok) {
      widget.onGranted();
    } else {
      setState(() {
        _busy = false;
        _err = 'الكود غير صحيح';
      });
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    final d = await AccessControl.resolve();
    if (!mounted) return;
    setState(() => _checking = false);
    if (d.allowed) {
      widget.onGranted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(d is Offline ? 'لا يوجد اتصال بالإنترنت' : 'النسخة ما زالت مقفلة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // الجزء العلوي: الشعار
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.gold.withValues(alpha: 0.5), width: 2),
                        color: Palette.nightSoft,
                      ),
                      child: Icon(_terminated ? Icons.block : Icons.lock_person_outlined, size: 52, color: Palette.gold),
                    ),
                    const SizedBox(height: 18),
                    Text('كِتابي', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.gold, fontSize: 30)),
                    const SizedBox(height: 6),
                    Text(
                      _terminated ? 'النسخة موقوفة نهائياً' : 'هذه النسخة تحتاج تفعيلاً',
                      style: const TextStyle(color: Palette.ivoryDim),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // اللوح السفلي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              color: Palette.nightSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Palette.line)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.decision.note.isNotEmpty
                        ? widget.decision.note
                        : 'للمتابعة أدخل كود التفعيل المقدَّم من المطوّر.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.ivoryDim, height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  if (!_terminated) ...[
                    TextField(
                      controller: _code,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _redeem(),
                      style: const TextStyle(fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'كود التفعيل',
                        errorText: _err,
                        prefixIcon: const Icon(Icons.qr_code_2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _redeem,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(_busy ? 'جارٍ التحقق...' : 'تفعيل ودخول'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton.icon(
                    onPressed: _checking ? null : _recheck,
                    icon: _checking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('إعادة التحقق من الخادم'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
