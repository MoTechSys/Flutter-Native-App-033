// ============================================================
// كِتابي - استعادة كلمة المرور (Stepper عمودي بثلاث خطوات)
//   1) البريد  2) رمز التحقق XX-XXX  3) كلمة مرور جديدة
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../data/repos/repos.dart';
import '../../security/otp_engine.dart';
import '../shared/widgets.dart';

class RecoverPasswordPage extends StatefulWidget {
  const RecoverPasswordPage({super.key});
  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  final _users = UserRepo();
  final _otp = OtpEngine();

  final _emailForm = GlobalKey<FormState>();
  final _passForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _hide = true;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ steps
  Future<void> _step1() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() => _busy = true);
    final u = await _users.byEmail(_email.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (u == null) {
      notify(context, 'لا يوجد حساب مرتبط بهذا البريد', error: true);
      return;
    }
    _otp.issue();
    _code.clear();
    _startTicker();
    setState(() => _step = 1);
    notify(context, 'تم إنشاء رمز التحقق', icon: Icons.vpn_key);
  }

  void _step2() {
    switch (_otp.verify(_code.text)) {
      case OtpResult.ok:
        _tick?.cancel();
        setState(() => _step = 2);
        notify(context, 'تم التحقق بنجاح');
      case OtpResult.wrong:
        notify(context, 'الرمز غير صحيح • بقي ${_otp.attemptsLeft} محاولة', error: true);
      case OtpResult.expired:
        notify(context, 'انتهت صلاحية الرمز، أنشئ رمزاً جديداً', error: true);
        setState(() {});
      case OtpResult.lockedOut:
        notify(context, 'تجاوزت الحد المسموح، أنشئ رمزاً جديداً', error: true);
        setState(() {});
      case OtpResult.noCode:
        notify(context, 'أنشئ رمزاً أولاً', error: true);
    }
  }

  Future<void> _step3() async {
    if (!_passForm.currentState!.validate()) return;
    setState(() => _busy = true);
    await _users.resetPassword(_email.text, _p1.text);
    if (!mounted) return;
    notify(context, 'تم تغيير كلمة المرور، سجّل الدخول الآن');
    Navigator.pop(context);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _otp.display));
    if (mounted) notify(context, 'تم نسخ الرمز', icon: Icons.copy);
  }

  void _resend() {
    if (!_otp.canResend) return;
    _otp.issue();
    _code.clear();
    _startTicker();
    setState(() {});
    notify(context, 'تم إنشاء رمز جديد', icon: Icons.vpn_key);
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: Palette.gold, onPrimary: Palette.night),
          ),
          child: Stepper(
            currentStep: _step,
            type: StepperType.vertical,
            controlsBuilder: (_, _) => const SizedBox.shrink(),
            steps: [
              Step(
                title: const Text('البريد الإلكتروني'),
                subtitle: _step > 0 ? Text(_email.text.trim(), textDirection: TextDirection.ltr) : null,
                isActive: _step >= 0,
                state: _step > 0 ? StepState.complete : StepState.editing,
                content: _emailStep(),
              ),
              Step(
                title: const Text('رمز التحقق'),
                isActive: _step >= 1,
                state: _step > 1 ? StepState.complete : (_step == 1 ? StepState.editing : StepState.indexed),
                content: _otpStep(),
              ),
              Step(
                title: const Text('كلمة مرور جديدة'),
                isActive: _step >= 2,
                state: _step == 2 ? StepState.editing : StepState.indexed,
                content: _passStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailStep() => Form(
    key: _emailForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('أدخل البريد المسجّل في حسابك لإنشاء رمز تحقق.', style: TextStyle(color: Palette.ivoryDim)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.alternate_email)),
          validator: vEmail,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _step1,
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('إنشاء رمز التحقق'),
        ),
      ],
    ),
  );

  Widget _otpStep() {
    final rem = _otp.remaining;
    final wait = _otp.resendWait;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // بطاقة الرمز
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [Palette.walnut, Palette.nightSoft]),
            border: Border.all(color: Palette.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Text('رمز التحقق الخاص بك', style: TextStyle(color: Palette.ivoryDim, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SelectableText(
                        _otp.hasCode ? _otp.display : '— — - — — —',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Palette.gold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ',
                    onPressed: _otp.hasCode ? _copy : null,
                    icon: const Icon(Icons.copy_rounded, color: Palette.gold),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: _otp.expired ? Palette.danger : Palette.ivoryDim),
                  Text(
                    !_otp.hasCode
                        ? 'لا يوجد رمز نشط'
                        : _otp.expired
                        ? 'انتهت الصلاحية'
                        : 'صالح ${_mmss(rem)}',
                    style: TextStyle(fontSize: 12, color: _otp.expired ? Palette.danger : Palette.ivoryDim),
                  ),
                  TextButton(
                    onPressed: _otp.canResend ? _resend : null,
                    child: Text(_otp.canResend ? 'رمز جديد' : 'رمز جديد بعد ${wait.inSeconds}ث'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('otp_input'),
          controller: _code,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
          onSubmitted: (_) => _step2(),
          style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'أدخل الرمز', hintText: 'XX-XXX', counterText: '', prefixIcon: Icon(Icons.password)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _step2, icon: const Icon(Icons.verified_outlined), label: const Text('تحقق')),
        TextButton(
          onPressed: () {
            _tick?.cancel();
            _otp.reset();
            setState(() => _step = 0);
          },
          child: const Text('تغيير البريد'),
        ),
      ],
    );
  }

  Widget _passStep() => Form(
    key: _passForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _p1,
          obscureText: _hide,
          decoration: InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
          validator: vPassword,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _p2,
          obscureText: _hide,
          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_person_outlined)),
          validator: (v) => v != _p1.text ? 'كلمتا المرور غير متطابقتين' : null,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _step3,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ كلمة المرور'),
        ),
      ],
    ),
  );
}
