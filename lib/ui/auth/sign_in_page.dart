// ============================================================
// كِتابي - تسجيل الدخول
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../state/session.dart';
import '../shared/widgets.dart';
import 'recover_password_page.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await context.read<Session>().signIn(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) notify(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // خلفية: شعار كبير باهت
          Positioned(
            top: -40,
            left: -40,
            child: Icon(Icons.auto_stories, size: 260, color: Palette.gold.withValues(alpha: 0.05)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Palette.gold, Palette.goldDim]),
                            boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.35), blurRadius: 24)],
                          ),
                          child: const Icon(Icons.menu_book_rounded, size: 44, color: Palette.night),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'كِتابي',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 34, color: Palette.gold),
                      ),
                      const Text(
                        'مكتبتك الفاخرة في جيبك',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.ivoryDim, letterSpacing: 1),
                      ),
                      const SizedBox(height: 34),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.alternate_email)),
                        validator: vEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hide,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoverPasswordPage())),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                            : const Text('دخول'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: TextStyle(color: Palette.ivoryDim))),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage())),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('إنشاء حساب جديد'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
