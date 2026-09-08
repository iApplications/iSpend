import 'package:flutter/material.dart';

class CategoryIconStyle {
  const CategoryIconStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

CategoryIconStyle categoryIconStyle(String category) {
  return switch (category) {
    'Food' => const CategoryIconStyle(
      icon: Icons.restaurant_outlined,
      color: Color(0xFFE76F51),
    ),
    'Transport' => const CategoryIconStyle(
      icon: Icons.directions_car_outlined,
      color: Color(0xFF457B9D),
    ),
    'Shopping' => const CategoryIconStyle(
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF9B5DE5),
    ),
    'Bills' => const CategoryIconStyle(
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFF4A261),
    ),
    _ => const CategoryIconStyle(
      icon: Icons.more_horiz,
      color: Color(0xFF6B7280),
    ),
  };
}
