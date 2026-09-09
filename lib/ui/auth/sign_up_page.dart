// ============================================================
// كِتابي - إنشاء حساب (Form + Validation)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../shared/widgets.dart';

/// المدن المتاحة في نموذج التسجيل وتعديل الحساب
const kCities = ['صنعاء', 'عدن', 'تعز', 'الحديدة', 'إب', 'حضرموت', 'الرياض', 'جدة', 'أخرى'];

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _city;
  bool _hide = true;
  bool _busy = false;
  bool _agree = false;
  UserRole _role = UserRole.customer;


  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      notify(context, 'يجب الموافقة على الشروط للمتابعة', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<Session>().signUp(
      name: _name.text,
      email: _email.text,
      password: _pass.text,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      city: _city,
      role: _role,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      notify(context, err, error: true);
      return;
    }
    notify(context, 'أهلاً بك في كِتابي! تم إنشاء حسابك وتسجيل دخولك', icon: Icons.celebration_outlined);
    // البوابة (_Gate) تُبدّل إلى Shell تلقائياً بعد تسجيل الدخول؛ نُغلق صفحة التسجيل فقط
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'انضم إلى كِتابي واحصل على خصم ترحيبي بكود WELCOME15',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.ivoryDim, height: 1.5),
                ),
                const SizedBox(height: 18),
                // ---------------- نوع الحساب
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.customer, icon: Icon(Icons.person_outline), label: Text('مستخدم')),
                    ButtonSegment(value: UserRole.admin, icon: Icon(Icons.admin_panel_settings_outlined), label: Text('مدير المتجر')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Palette.gold,
                    selectedForegroundColor: Palette.night,
                    foregroundColor: Palette.ivory,
                    side: const BorderSide(color: Palette.line),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_role.hint, textAlign: TextAlign.center, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: vName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.alternate_email)),
                  validator: vEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'الجوال (اختياري)', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: vPhone,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المدينة', prefixIcon: Icon(Icons.location_city_outlined)),
                  dropdownColor: Palette.nightSoft,
                  items: kCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _city = v),
                  validator: (v) => v == null ? 'اختر المدينة' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: vPassword,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass2,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_person_outlined)),
                  validator: (v) => v != _pass.text ? 'كلمتا المرور غير متطابقتين' : null,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  activeColor: Palette.gold,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('أوافق على شروط الاستخدام وسياسة الخصوصية', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.how_to_reg),
                  label: Text(_busy ? 'جارٍ الإنشاء...' : 'إنشاء الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
