import 'package:flutter/material.dart';

class AppColors {
  // Brand / Primary (ธีมสีชมพูคู่รัก - Pink Couples Theme)
  static const Color primary = Color(0xFFE91E63);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color primaryLight = Color(0xFFFCE4EC);
  static const Color accent = Color(0xFFFF4081);
  static const Color brandStart = Color(0xFFE91E63);
  static const Color brandEnd = Color(0xFFFF7A73);
  static const Color couplePurple = Color(0xFF7C5CE7);
  static const Color warmAmber = Color(0xFFF59E0B);

  // Financial Indicators
  static const Color income = Color(0xFF2E7D32);      // Green
  static const Color incomeLight = Color(0xFFE8F5E9);
  static const Color expense = Color(0xFFD32F2F);     // Red
  static const Color expenseLight = Color(0xFFFFEBEE);
  static const Color transfer = Color(0xFF0288D1);    // Blue
  static const Color taxDeductible = Color(0xFF7B1FA2); // Purple
  static const Color taxDeductibleLight = Color(0xFFF3E5F5);

  // Neutral / Background Light
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFEEEEEE);

  // Neutral / Background Dark (Modern Midnight Luxury)
  static const Color backgroundDark = Color(0xFF0F111A);
  static const Color surfaceDark = Color(0xFF181A26);
  static const Color cardDark = Color(0xFF1E2130);
  static const Color textPrimaryDark = Color(0xFFF1F3F9);
  static const Color textSecondaryDark = Color(0xFF8E93A6);
  static const Color dividerDark = Color(0xFF2B2E42);

  // Radiant Financial & Couple Colors for Dark Mode
  static const Color incomeDark = Color(0xFF4ADE80);
  static const Color expenseDark = Color(0xFFFF6B81);
  static const Color primaryDarkBrand = Color(0xFFFF6584);

  // Predefined Category Colors (for quick selection)
  static const List<Color> categoryPalette = [
    Color(0xFFFF5722), // Deep Orange (Food)
    Color(0xFF2196F3), // Blue (Living/Home)
    Color(0xFF4CAF50), // Green (Income/Salary)
    Color(0xFFFF9800), // Orange (Transport)
    Color(0xFF9C27B0), // Purple (Shopping)
    Color(0xFFE91E63), // Pink (Entertainment)
    Color(0xFF00BCD4), // Cyan (Health)
    Color(0xFF607D8B), // Blue Grey (Bills)
    Color(0xFFFFC107), // Amber (Education)
    Color(0xFF795548), // Brown (Work)
    Color(0xFF3F51B5), // Indigo (Investments)
    Color(0xFF009688), // Teal (Personal Care)
  ];

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return primary;
    }
  }

  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
