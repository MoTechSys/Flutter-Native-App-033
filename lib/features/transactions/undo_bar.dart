import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';

/// 8-second undo bar after saving (docs/03 §6.4 step 4). Undo = automatic
/// reversal entry with reason "تراجع المستخدم" — never a delete (R1).
class UndoBar {
  UndoBar._();

  static const duration = Duration(seconds: 8);

  static void show(ScaffoldMessengerState messenger, {required Future<void> Function() onUndo}) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        content: const _Content(),
        action: SnackBarAction(
          label: S.undo,
          textColor: const Color(0xFFFFD27A),
          onPressed: () => unawaited(onUndo()),
        ),
      ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();
  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: UndoBar.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.payment, size: 26),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(S.saved, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CircularProgressIndicator(
              value: 1 - _c.value,
              strokeWidth: 3,
              color: const Color(0xFFFFD27A),
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}
