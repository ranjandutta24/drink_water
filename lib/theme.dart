import 'package:flutter/material.dart';

/// Palette notes
/// The app is glanced at a dozen times a day, often one-handed, sometimes in
/// the dark. So: a cool ground that never glares, one saturated marine blue
/// reserved for water, and a separate iris tone reserved for medicine so the two
/// reminder systems are never confused at a glance.
///
/// Colours are read through [AppColors.of] rather than as constants, because the
/// same token has to mean "near-white panel" in the light theme and "lifted
/// charcoal panel" in the dark one.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.panel,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.aqua,
    required this.aquaDeep,
    required this.aquaWash,
    required this.iris,
    required this.irisWash,
    required this.kelp,
    required this.clay,
    required this.onAccent,
    required this.noticeWash,
    required this.noticeInk,
    required this.vesselGlass,
    required this.medicinePalette,
  });

  /// Page ground.
  final Color canvas;

  /// Raised surfaces: panels, nav bar, inputs.
  final Color panel;

  /// The 1px border used everywhere instead of a shadow.
  final Color hairline;

  /// Primary and secondary text/icon colour.
  final Color ink;
  final Color inkSoft;

  /// Water.
  final Color aqua;
  final Color aquaDeep;
  final Color aquaWash;

  /// Medicine.
  final Color iris;
  final Color irisWash;

  /// Goal met, and destructive/missed.
  final Color kelp;
  final Color clay;

  /// Foreground on top of a filled accent colour.
  final Color onAccent;

  /// The "heads up" panel on the water settings screen.
  final Color noticeWash;
  final Color noticeInk;

  /// The carafe body on the home screen.
  final Color vesselGlass;

  /// Accent assigned to each medicine card.
  final List<Color> medicinePalette;

  static const AppPalette light = AppPalette(
    canvas: Color(0xFFF1F5F6),
    panel: Colors.white,
    hairline: Color(0xFFD9E2E5),
    ink: Color(0xFF0C2536),
    inkSoft: Color(0xFF5B6B77),
    aqua: Color(0xFF1B9AAA),
    aquaDeep: Color(0xFF0E6E7D),
    aquaWash: Color(0xFFE3F1F3),
    iris: Color(0xFF6B54D3),
    irisWash: Color(0xFFEDE9FB),
    kelp: Color(0xFF2A9D6E),
    clay: Color(0xFFC0563C),
    onAccent: Colors.white,
    noticeWash: Color(0xFFFDF4E7),
    noticeInk: Color(0xFFB5892B),
    vesselGlass: Color(0xFFFFFFFF),
    medicinePalette: <Color>[
      Color(0xFF6B54D3),
      Color(0xFF1B9AAA),
      Color(0xFFC0563C),
      Color(0xFF2A9D6E),
      Color(0xFFB5892B),
      Color(0xFF9A3F72),
    ],
  );

  /// Not an inversion of the light theme: the ground goes to a desaturated
  /// near-black so the water blues stay the brightest thing on screen, and the
  /// accents are lifted a step because saturated mid-tones go muddy on dark.
  static const AppPalette dark = AppPalette(
    canvas: Color(0xFF0C1216),
    panel: Color(0xFF151E23),
    hairline: Color(0xFF283840),
    ink: Color(0xFFE8F0F3),
    inkSoft: Color(0xFF9CB0BA),
    aqua: Color(0xFF34B7C8),
    aquaDeep: Color(0xFF7ED8E4),
    aquaWash: Color(0xFF14313A),
    iris: Color(0xFF9C8AF2),
    irisWash: Color(0xFF231F3C),
    kelp: Color(0xFF4CC48E),
    clay: Color(0xFFE0806A),
    onAccent: Color(0xFF04171C),
    noticeWash: Color(0xFF2E2411),
    noticeInk: Color(0xFFE2BA63),
    vesselGlass: Color(0xFF1B262C),
    medicinePalette: <Color>[
      Color(0xFF9C8AF2),
      Color(0xFF34B7C8),
      Color(0xFFE0806A),
      Color(0xFF4CC48E),
      Color(0xFFDCB05C),
      Color(0xFFD97FB0),
    ],
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? panel,
    Color? hairline,
    Color? ink,
    Color? inkSoft,
    Color? aqua,
    Color? aquaDeep,
    Color? aquaWash,
    Color? iris,
    Color? irisWash,
    Color? kelp,
    Color? clay,
    Color? onAccent,
    Color? noticeWash,
    Color? noticeInk,
    Color? vesselGlass,
    List<Color>? medicinePalette,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      aqua: aqua ?? this.aqua,
      aquaDeep: aquaDeep ?? this.aquaDeep,
      aquaWash: aquaWash ?? this.aquaWash,
      iris: iris ?? this.iris,
      irisWash: irisWash ?? this.irisWash,
      kelp: kelp ?? this.kelp,
      clay: clay ?? this.clay,
      onAccent: onAccent ?? this.onAccent,
      noticeWash: noticeWash ?? this.noticeWash,
      noticeInk: noticeInk ?? this.noticeInk,
      vesselGlass: vesselGlass ?? this.vesselGlass,
      medicinePalette: medicinePalette ?? this.medicinePalette,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      canvas: mix(canvas, other.canvas),
      panel: mix(panel, other.panel),
      hairline: mix(hairline, other.hairline),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      aqua: mix(aqua, other.aqua),
      aquaDeep: mix(aquaDeep, other.aquaDeep),
      aquaWash: mix(aquaWash, other.aquaWash),
      iris: mix(iris, other.iris),
      irisWash: mix(irisWash, other.irisWash),
      kelp: mix(kelp, other.kelp),
      clay: mix(clay, other.clay),
      onAccent: mix(onAccent, other.onAccent),
      noticeWash: mix(noticeWash, other.noticeWash),
      noticeInk: mix(noticeInk, other.noticeInk),
      vesselGlass: mix(vesselGlass, other.vesselGlass),
      medicinePalette: t < 0.5 ? medicinePalette : other.medicinePalette,
    );
  }
}

/// Entry point for colours anywhere in the widget tree.
class AppColors {
  const AppColors._();

  /// Falls back to the light palette rather than throwing, so a widget built
  /// outside the themed subtree still renders something sane.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
}

/// The typefaces offered in Settings.
///
/// Play is bundled from assets/fonts; the rest are families Android already has
/// on disk. Either way nothing is downloaded at runtime. [family] is passed
/// straight to Flutter as a font family name, and null means "whatever the
/// platform's default is", which on Android is Roboto.
enum AppFont {
  system('Default', null, 'The font your phone uses everywhere else'),
  roboto('Roboto', 'Roboto', "Android's own typeface — clean and neutral"),
  play('Play', 'Play', 'Squared-off and a little technical'),
  mono('Mono', 'monospace', 'Fixed width — every digit lines up');

  const AppFont(this.label, this.family, this.note);

  final String label;
  final String? family;
  final String note;
}

/// Tolerant parser: an unknown or missing name falls back to the default rather
/// than throwing, so an old or hand-edited backup can never brick startup.
AppFont appFontFromName(String? name) {
  for (final font in AppFont.values) {
    if (font.name == name) return font;
  }
  return AppFont.system;
}

ThemeData buildLightTheme([AppFont font = AppFont.system]) =>
    _buildTheme(AppPalette.light, Brightness.light, font);

ThemeData buildDarkTheme([AppFont font = AppFont.system]) =>
    _buildTheme(AppPalette.dark, Brightness.dark, font);

ThemeData _buildTheme(AppPalette palette, Brightness brightness, AppFont font) {
  final family = font.family;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: family,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.aqua,
      brightness: brightness,
      primary: palette.aqua,
      onPrimary: palette.onAccent,
      secondary: palette.iris,
      surface: palette.panel,
      onSurface: palette.ink,
      error: palette.clay,
    ),
    scaffoldBackgroundColor: palette.canvas,
  );

  // Derived from base.textTheme with copyWith rather than built from bare
  // TextStyles, so every style inherits the chosen font family instead of
  // silently falling back to the platform default.
  final inked = base.textTheme.apply(
    bodyColor: palette.ink,
    displayColor: palette.ink,
  );

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[palette],
    textTheme: inked.copyWith(
      // Large numerals are the centrepiece of this app, so the display sizes
      // are set tight and heavy rather than airy.
      displayLarge: inked.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
        height: 1.0,
        color: palette.ink,
      ),
      displayMedium: inked.displayMedium?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        color: palette.ink,
      ),
      titleLarge: inked.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: palette.ink,
      ),
      titleMedium: inked.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: palette.ink,
      ),
      bodyMedium: inked.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.45,
        color: palette.ink,
      ),
      bodySmall: inked.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.4,
        color: palette.inkSoft,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: family,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: palette.ink,
      ),
      iconTheme: IconThemeData(color: palette.ink),
    ),
    // Hairline borders instead of shadows: the only thing allowed to feel
    // dimensional is the water vessel on the home screen.
    cardTheme: CardThemeData(
      color: palette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.hairline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.aqua, width: 1.6),
      ),
      labelStyle: TextStyle(fontFamily: family, color: palette.inkSoft),
      hintStyle: TextStyle(fontFamily: family, color: palette.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.aqua,
        foregroundColor: palette.onAccent,
        minimumSize: const Size.fromHeight(52),
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: palette.hairline),
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.aqua),
    ),
    // Navigation is the side drawer; there is no bottom bar to theme.
    drawerTheme: DrawerThemeData(
      backgroundColor: palette.panel,
      surfaceTintColor: Colors.transparent,
      width: 300,
      // Directional so the rounded edge stays on the inner side of the sheet
      // rather than always the right one.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(22),
        ),
      ),
      scrimColor: Colors.black.withValues(alpha: 0.42),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: brightness == Brightness.light
          ? palette.ink
          : palette.panel,
      contentTextStyle: TextStyle(
        fontFamily: family,
        color: brightness == Brightness.light ? palette.panel : palette.ink,
        fontSize: 14.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.panel,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.inkSoft,
      textColor: palette.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.aqua,
      inactiveTrackColor: palette.hairline,
      thumbColor: palette.aqua,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(
        brightness == Brightness.light ? Colors.white : palette.panel,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.aqua
            : palette.hairline,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
