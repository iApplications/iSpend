import 'package:flutter/material.dart';

abstract final class AppColors {
  static const teal = Color(0xFF0D7C78);
  static const cyan = Color(0xFF22B8C7);
  static const navy = Color(0xFF101A2B);
  static const darkSurface = Color(0xFF18263A);
  static const darkSurfaceVariant = Color(0xFF22334A);

  static const heroGradient = LinearGradient(
    colors: [teal, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  static const screen = EdgeInsets.fromLTRB(xl, xl, xl, 0);
  static const listScreen = EdgeInsets.fromLTRB(xl, xl, xl, 24);
}

abstract final class AppRadii {
  static const row = Radius.circular(14);
  static const card = Radius.circular(20);
  static const pill = Radius.circular(999);

  static const rowBorder = BorderRadius.all(row);
  static const cardBorder = BorderRadius.all(card);
  static const pillBorder = BorderRadius.all(pill);
}
