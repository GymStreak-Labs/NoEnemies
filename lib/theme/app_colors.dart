import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core palette
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141925);
  static const Color surfaceLight = Color(0xFF1C2233);
  static const Color surfaceBorder = Color(0xFF252B3D);

  // Brand colors
  static const Color primary = Color(0xFFD4A853);
  static const Color primaryDim = Color(0xFF8B7035);
  static const Color accent = Color(0xFF5BBFBA);
  static const Color accentDim = Color(0xFF3A7D79);

  // Semantic colors
  static const Color peace = Color(0xFF6BCB77);
  static const Color peaceDim = Color(0xFF3A7240);
  static const Color war = Color(0xFFC75050);
  static const Color warDim = Color(0xFF7A3030);

  // Text
  static const Color textPrimary = Color(0xFFE8E6E3);
  static const Color textSecondary = Color(0xFFD0CDD5);
  static const Color textTertiary = Color(0xFFB0ADB8);

  // Onboarding / Quiz
  static const Color quizOption = Color(0xFF1A2035);
  static const Color quizOptionSelected = Color(0xFF252B45);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD4A853), Color(0xFFE8C87A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF141925)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient peaceGradient = LinearGradient(
    colors: [Color(0xFF6BCB77), Color(0xFF5BBFBA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
