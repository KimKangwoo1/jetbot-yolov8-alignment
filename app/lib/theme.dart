import 'package:flutter/material.dart';

class AppColors {
  // Neutral grayscale base — no blue tint. Functional colors (direction,
  // status, accent) keep their hue so they pop against the neutral surface.
  static const bg = Color(0xFF0A0A0B);       // near-black canvas
  static const bgAlt = Color(0xFF121214);    // header / sidebar surface
  static const panel = Color(0xFF18181B);    // primary panel
  static const panelAlt = Color(0xFF1F1F23); // raised inputs / chips
  static const stroke = Color(0xFF34343A);   // borders
  static const strokeDim = Color(0xFF28282C);// faint grid lines

  static const accent = Color(0xFF22D3EE);
  static const accentDeep = Color(0xFF0E7490);

  static const textPrimary = Color(0xFFEDEEF0);
  static const textSecondary = Color(0xFF9BA1AB);
  static const textMuted = Color(0xFF6B7280);

  static const ok = Color(0xFF22C55E);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const violet = Color(0xFFA855F7);

  // Direction colors
  static const north = Color(0xFF3B82F6); // blue
  static const east = Color(0xFFF97316);  // orange
  static const south = Color(0xFFEC4899); // pink
  static const west = Color(0xFFFACC15);  // yellow

  static Color forCongestion(double v) {
    if (v < 0.30) return ok;
    if (v < 0.50) return accent;
    if (v < 0.70) return warn;
    return danger;
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.panel,
      onSurface: AppColors.textPrimary,
      onPrimary: Colors.black,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.stroke,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
