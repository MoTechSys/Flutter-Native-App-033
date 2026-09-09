// ============================================================
// كِتابي - تعديل بيانات الحساب (Form + Validation → UPDATE في SQLite)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../state/session.dart';
import '../auth/sign_up_page.dart' show kCities;
import '../shared/widgets.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _city;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<Session>().user!;
    _name = TextEditingController(text: u.name);
    _phone = TextEditingController(text: u.phone ?? '');
    _city = kCities.contains(u.city) ? u.city : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await context.read<Session>().updateProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      city: _city,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    notify(context, 'تم حفظ التعديلات', icon: Icons.check_circle_outline);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<Session>().user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل البيانات')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                initialValue: email,
                enabled: false,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني (ثابت)', prefixIcon: Icon(Icons.alternate_email)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                validator: vName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                validator: vPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _city,
                isExpanded: true,
                dropdownColor: Palette.nightSoft,
                decoration: const InputDecoration(labelText: 'المدينة', prefixIcon: Icon(Icons.location_city_outlined)),
                items: kCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _city = v),
                validator: (v) => v == null ? 'اختر المدينة' : null,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
