// ============================================================
// كِتابي - تغيير كلمة المرور (يتحقق من الحالية ثم يحدّث SQLite)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../state/session.dart';
import '../shared/widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await context.read<Session>().changePassword(_current.text, _next.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      notify(context, 'كلمة المرور الحالية غير صحيحة', error: true);
      return;
    }
    notify(context, 'تم تغيير كلمة المرور بنجاح', icon: Icons.verified_user_outlined);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.gold.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.gold.withValues(alpha: .35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Palette.gold),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تُحفظ كلمة المرور مشفّرة (SHA-256 مع Salt) داخل قاعدة البيانات المحلية.',
                        style: TextStyle(color: Palette.ivoryDim, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _current,
                obscureText: !_show,
                validator: (v) => (v ?? '').isEmpty ? 'أدخل كلمة المرور الحالية' : null,
                decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: !_show,
                validator: (v) {
                  final e = vPassword(v);
                  if (e != null) return e;
                  if (v == _current.text) return 'الكلمة الجديدة يجب أن تختلف عن الحالية';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: !_show,
                validator: (v) => v != _next.text ? 'كلمتا المرور غير متطابقتين' : null,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة', prefixIcon: Icon(Icons.check_circle_outline)),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                    : const Icon(Icons.save_outlined),
                label: const Text('تحديث كلمة المرور'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
