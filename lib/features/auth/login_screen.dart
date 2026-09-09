import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/customer_avatar.dart';

/// Who-are-you screen (docs/03 §6.7): big user photos → 4-digit PIN pad.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AppUser? _picked;
  String _pin = '';
  bool _wrong = false;

  Future<void> _tap(AppUser u) async {
    final session = context.read<SessionProvider>();
    if (!u.hasPin) {
      await session.login(u.id);
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }
    setState(() {
      _picked = u;
      _pin = '';
      _wrong = false;
    });
  }

  Future<void> _key(String k) async {
    if (k == '⌫') {
      setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += k;
      _wrong = false;
    });
    if (_pin.length == 4) {
      final session = context.read<SessionProvider>();
      final ok = await session.verifyPin(_picked!.id, _pin);
      if (!mounted) return;
      if (ok) {
        await session.login(_picked!.id);
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        setState(() {
          _wrong = true;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final users = session.users;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(S.appName,
                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
              Text(session.shop?.name ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 18)),
              const SizedBox(height: 24),
              Expanded(
                child: _picked == null ? _users(users) : _pinPad(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _users(List<AppUser> users) {
    return Column(
      children: [
        const Text(S.whoAreYou,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170, mainAxisSpacing: 16, crossAxisSpacing: 16,
                childAspectRatio: 0.82),
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _tap(u),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomerAvatar(name: u.name, photoPath: u.photoPath, size: 92),
                      const SizedBox(height: 10),
                      Text(u.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(u.isOwner ? S.owner : S.worker,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pinPad() {
    final u = _picked!;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _picked = null),
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 30),
            ),
            const Spacer(),
            CustomerAvatar(name: u.name, photoPath: u.photoPath, size: 64, borderColor: Colors.white),
            const SizedBox(width: 10),
            Text(u.name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(flex: 2),
          ],
        ),
        const SizedBox(height: 16),
        Text(_wrong ? S.wrongPin : S.enterPin,
            style: TextStyle(
                color: _wrong ? const Color(0xFFFFB4A9) : Colors.white, fontSize: 20)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (i) => Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? Colors.white : Colors.transparent,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
                k.isEmpty
                    ? const SizedBox.shrink()
                    : Material(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _key(k),
                          child: Center(
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 28)
                                : Text(k,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ],
    );
  }
}
