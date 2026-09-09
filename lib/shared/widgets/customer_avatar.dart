import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Round customer photo. Supports bundled assets (`asset:` prefix, used by
/// demo data) and device files. Falls back to a colored initial when there is
/// no photo (docs/03_DESIGN.md — "photo optional, avatar generated").
class CustomerAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 56,
    this.borderColor,
    this.borderWidth = 2.5,
  });

  static const assetPrefix = 'asset:';

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
    final inner = borderColor == null ? size : size - borderWidth * 2;
    Widget child = _photo(inner) ?? _initial(inner);

    if (borderColor != null) {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: borderColor),
        alignment: Alignment.center,
        child: child,
      );
    }
    return child;
  }

  Widget? _photo(double d) {
    final p = photoPath;
    if (p == null || p.isEmpty) return null;
    ImageProvider? provider;
    if (p.startsWith(assetPrefix)) {
      provider = AssetImage(p.substring(assetPrefix.length));
    } else if (!kIsWeb && File(p).existsSync()) {
      provider = FileImage(File(p));
    }
    if (provider == null) return null;
    return ClipOval(
      child: Image(
        image: provider,
        width: d,
        height: d,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initial(d),
      ),
    );
  }

  Widget _initial(double d) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: d * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
