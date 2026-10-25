import 'package:flutter/material.dart';
import 'package:spatial_world/theme/app_colors.dart';

abstract final class AppTypography {
  static const headingLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.surface
  );

  static const headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

}