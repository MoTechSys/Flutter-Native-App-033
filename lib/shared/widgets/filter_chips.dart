import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Row of pill filter chips matching mockup 03 (selected = filled emerald,
/// others outlined with an optional coloured dot). Min height 44dp.
class FilterChipsRow<T> extends StatelessWidget {
  final T value;

  /// (value, label, dotColor)
  final List<(T, String, Color?)> items;
  final ValueChanged<T> onChanged;

  const FilterChipsRow({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (v, label, dot) = items[i];
          final selected = v == value;
          return Material(
            color: selected ? AppColors.primary : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(color: selected ? AppColors.primary : AppColors.primary, width: 1.4),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onChanged(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dot != null && !selected) ...[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
