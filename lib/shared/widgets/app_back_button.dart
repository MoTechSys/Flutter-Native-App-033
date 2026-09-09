import 'package:flutter/material.dart';

/// Explicit, large (56dp) back control used on every non-home screen.
/// Client rule: "ضروري تعمل علامة رجوع". In RTL the arrow points right.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return IconButton(
      tooltip: 'رجوع',
      iconSize: 30,
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      onPressed: onPressed ??
          (canPop ? () => Navigator.of(context).maybePop() : null),
      icon: const Icon(Icons.arrow_forward_rounded),
    );
  }
}
