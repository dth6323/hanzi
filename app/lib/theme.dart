import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF12100F);
  static const surface = Color(0xFF1D1A18);
  static const surface2 = Color(0xFF282320);
  static const primary = Color(0xFFE5483B); // vermilion
  static const gold = Color(0xFFE8B86B);
  static const accent = Color(0xFFE5483B);
  static const text = Color(0xFFF3ECE4);
  static const muted = Color(0xFFA79C91);

  // Writing canvas
  static const paper = Color(0xFFF7F0E3);
  static const ink = Color(0xFF221D1A);
  static const outline = Color(0xFFDCCFBC);
  static const userInk = Color(0xFF3A6EA5);
  static const hint = Color(0xFF2E9E6A);
  static const error = Color(0xFFD7392B);
  static const grid = Color(0xFFD9B8A0);
  static const gridStrong = Color(0xFFC0896B);

  static const hsk = [
    Color(0xFF4CAF84),
    Color(0xFF3E9BD6),
    Color(0xFF7A6FE0),
    Color(0xFFD06BC4),
    Color(0xFFE8914A),
    Color(0xFFE5483B),
    Color(0xFF9E2B25),
  ];
  static Color hskColor(int level) => hsk[(level - 1).clamp(0, 6)];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.gold,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: Colors.white10,
  );
}

class HskBadge extends StatelessWidget {
  final int level;
  const HskBadge(this.level, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.hskColor(level).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('HSK $level',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.hskColor(level))),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
        ]),
      );
}
