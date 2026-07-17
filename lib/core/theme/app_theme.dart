import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final textTheme = AppTypography.from(
      base.textTheme,
    ).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark);

    return base.copyWith(
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }
}
