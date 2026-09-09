import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/photo_service.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/customer_avatar.dart';

/// First run: shop name + owner name + photo + optional PIN. Spoken intro.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _shop = TextEditingController();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _photos = PhotoService();
  String? _photo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpeechService>().speak('${S.welcome}. اكتب اسم المحل واسمك ثم اضغط ابدأ');
    });
  }

  @override
  void dispose() {
    _shop.dispose();
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final shop = _shop.text.trim(), name = _name.text.trim(), pin = _pin.text.trim();
    if (shop.isEmpty || name.isEmpty) {
      setState(() => _error = 'اسم المحل واسمك مطلوبان');
      return;
    }
    if (pin.isNotEmpty && pin.length != 4) {
      setState(() => _error = 'الرمز 4 أرقام');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await context.read<SessionProvider>().createShop(
          shopName: shop,
          ownerName: name,
          ownerPhotoPath: _photo,
          pin: pin.isEmpty ? null : pin,
        );
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset('assets/icon/app_icon.png', width: 96, height: 96),
                    ),
                    const SizedBox(height: 10),
                    const Text(S.welcome,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    const Text('دفتر ديونك — بلا ورق، بلا غلط',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () async {
                        final p = await _photos.pick(fromCamera: true, folder: 'users');
                        if (p != null && mounted) setState(() => _photo = p);
                      },
                      borderRadius: BorderRadius.circular(60),
                      child: _photo == null
                          ? Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 2)),
                              child: const Icon(Icons.add_a_photo_rounded,
                                  size: 44, color: AppColors.primary))
                          : CustomerAvatar(name: _name.text, photoPath: _photo, size: 110,
                              borderColor: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    const Text('صورتك (اختياري)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _shop,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          labelText: S.shopName, prefixIcon: Icon(Icons.storefront_rounded)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          labelText: S.yourName, prefixIcon: Icon(Icons.person_rounded)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                      decoration: const InputDecoration(
                          labelText: S.setPinOptional, prefixIcon: Icon(Icons.lock_rounded), counterText: ''),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppColors.debt)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _start,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 28),
                  label: const Text(S.start, style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
