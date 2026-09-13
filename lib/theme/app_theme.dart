import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_text_styles.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: Colors.white,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
    ),

    textTheme: GoogleFonts.robotoTextTheme(),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.peach,
        foregroundColor: AppColors.darkBrown,
        textStyle: AppTextStyles.h5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    ),

    

  );
}