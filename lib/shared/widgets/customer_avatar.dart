import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Round customer photo. Falls back to a colored initial when there is no
/// photo (docs/03_DESIGN.md — "photo optional, avatar generated").
class CustomerAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double size;
  final Color? borderColor;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 56,
    this.borderColor,
  });

  static const _palette = [
    Color(0xFF0B5D48),
    Color(0xFF8A6200),
    Color(0xFF1F3A5F),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFFAD1457),
    Color(0xFF4E342E),
    Color(0xFF283593),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    final color = _palette[name.hashCode.abs() % _palette.length];

    Widget child;
    final path = photoPath;
    if (path != null && path.isNotEmpty && !kIsWeb && File(path).existsSync()) {
      child = ClipOval(
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    } else {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (borderColor != null) {
      child = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2.5),
        ),
        child: child,
      );
    }
    return child;
  }
}
