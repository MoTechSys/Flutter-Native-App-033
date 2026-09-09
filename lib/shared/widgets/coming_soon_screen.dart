import 'package:flutter/material.dart';

import '../l10n/ar_strings.dart';
import '../theme/app_colors.dart';
import 'app_back_button.dart';

/// Placeholder for routes scheduled in later phases (docs/06_PLAN.md).
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String phase;
  const ComingSoonScreen({super.key, required this.title, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded, size: 72, color: AppColors.accent),
              const SizedBox(height: 16),
              Text(S.comingSoon,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(S.comingSoonBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(phase,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
