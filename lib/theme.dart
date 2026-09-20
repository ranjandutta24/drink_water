import 'package:flutter/material.dart';

/// Palette notes
/// The app is glanced at a dozen times a day, often one-handed, sometimes in
/// the dark. So: a cool "mist" ground that never glares, one saturated marine
/// blue reserved for water, and a separate iris tone reserved for medicine so
/// the two reminder systems are never confused at a glance.
class AppColors {
  static const marine = Color(0xFF0C2536); // deepest ink, headings
  static const aqua = Color(0xFF1B9AAA); // water primary
  static const aquaDeep = Color(0xFF0E6E7D);
  static const aquaWash = Color(0xFFE3F1F3);
  static const mist = Color(0xFFF1F5F6); // page ground
  static const iris = Color(0xFF6B54D3); // medicine primary
  static const irisWash = Color(0xFFEDE9FB);
  static const kelp = Color(0xFF2A9D6E); // goal met
  static const clay = Color(0xFFC0563C); // destructive / missed
  static const slate = Color(0xFF5B6B77); // secondary text
  static const hairline = Color(0xFFD9E2E5);

  /// Accent assigned to each medicine card.
  static const medicinePalette = <Color>[
    Color(0xFF6B54D3),
    Color(0xFF1B9AAA),
    Color(0xFFC0563C),
    Color(0xFF2A9D6E),
    Color(0xFFB5892B),
    Color(0xFF9A3F72),
  ];
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.aqua,
      primary: AppColors.aqua,
      secondary: AppColors.iris,
      surface: Colors.white,
      error: AppColors.clay,
    ),
    scaffoldBackgroundColor: AppColors.mist,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.marine, displayColor: AppColors.marine)
        .copyWith(
          // Large numerals are the centrepiece of this app, so the display
          // sizes are set tight and heavy rather than airy.
          displayLarge: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            height: 1.0,
            color: AppColors.marine,
          ),
          displayMedium: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.05,
            color: AppColors.marine,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: AppColors.marine,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppColors.marine,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: AppColors.marine,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.slate,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mist,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.marine,
      ),
      iconTheme: IconThemeData(color: AppColors.marine),
    ),
    // Hairline borders instead of shadows: the only thing allowed to feel
    // dimensional is the water vessel on the home screen.
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.aqua, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.slate),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.aqua,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.marine,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.hairline),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.aquaWash,
      height: 68,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.marine,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.slate,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.aqua
            : const Color(0xFFC6D2D7),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
