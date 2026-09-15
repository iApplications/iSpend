import 'package:flutter/material.dart';

class CategoryIconStyle {
  const CategoryIconStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

const categoryIconKeys = [
  'food',
  'transport',
  'shopping',
  'bills',
  'home',
  'health',
  'pets',
  'education',
  'entertainment',
  'travel',
  'gift',
  'other',
];

String defaultCategoryIconKey(String category) => switch (category) {
  'Food' => 'food',
  'Transport' => 'transport',
  'Shopping' => 'shopping',
  'Bills' => 'bills',
  _ => 'other',
};

String categoryIconLabel(String iconKey) => switch (iconKey) {
  'food' => 'Food',
  'transport' => 'Transport',
  'shopping' => 'Shopping',
  'bills' => 'Bills',
  'home' => 'Home',
  'health' => 'Health',
  'pets' => 'Pets',
  'education' => 'Education',
  'entertainment' => 'Entertainment',
  'travel' => 'Travel',
  'gift' => 'Gift',
  _ => 'Other',
};

CategoryIconStyle categoryIconStyleForKey(String iconKey) {
  return switch (iconKey) {
    'food' => const CategoryIconStyle(
      icon: Icons.restaurant_outlined,
      color: Color(0xFFE76F51),
    ),
    'transport' => const CategoryIconStyle(
      icon: Icons.directions_car_outlined,
      color: Color(0xFF457B9D),
    ),
    'shopping' => const CategoryIconStyle(
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF9B5DE5),
    ),
    'bills' => const CategoryIconStyle(
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF2A9D8F),
    ),
    'home' => const CategoryIconStyle(
      icon: Icons.home_outlined,
      color: Color(0xFF4D7C0F),
    ),
    'health' => const CategoryIconStyle(
      icon: Icons.favorite_outline,
      color: Color(0xFFE63946),
    ),
    'pets' => const CategoryIconStyle(
      icon: Icons.pets_outlined,
      color: Color(0xFF8D6E63),
    ),
    'education' => const CategoryIconStyle(
      icon: Icons.school_outlined,
      color: Color(0xFF4361EE),
    ),
    'entertainment' => const CategoryIconStyle(
      icon: Icons.movie_outlined,
      color: Color(0xFF7209B7),
    ),
    'travel' => const CategoryIconStyle(
      icon: Icons.flight_outlined,
      color: Color(0xFF00B4D8),
    ),
    'gift' => const CategoryIconStyle(
      icon: Icons.card_giftcard_outlined,
      color: Color(0xFFE9C46A),
    ),
    _ => const CategoryIconStyle(
      icon: Icons.more_horiz,
      color: Color(0xFF6B7280),
    ),
  };
}

CategoryIconStyle categoryIconStyle(String category) =>
    categoryIconStyleForKey(defaultCategoryIconKey(category));

CategoryIconStyle paymentMethodIconStyle(String paymentMethod) {
  final normalized = paymentMethod.toLowerCase();
  if (normalized.contains('cash')) {
    return const CategoryIconStyle(
      icon: Icons.payments_outlined,
      color: Color(0xFF15803D),
    );
  }
  if (normalized.contains('credit') || normalized.contains('visa')) {
    return const CategoryIconStyle(
      icon: Icons.credit_card_outlined,
      color: Color(0xFF7C3AED),
    );
  }
  if (normalized.contains('debit') || normalized.contains('mastercard')) {
    return const CategoryIconStyle(
      icon: Icons.credit_card_outlined,
      color: Color(0xFFB45309),
    );
  }
  if (normalized.contains('card')) {
    return const CategoryIconStyle(
      icon: Icons.credit_card_outlined,
      color: Color(0xFF7C3AED),
    );
  }
  if (normalized == 'no payment method') {
    return const CategoryIconStyle(
      icon: Icons.help_outline,
      color: Color(0xFF94A3B8),
    );
  }
  return const CategoryIconStyle(
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF475569),
  );
}
