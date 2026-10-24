import 'package:flutter/material.dart';

/// Shared visual language for every user page, including local finance forms.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff087f6d),
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xff78dcc5) : const Color(0xff076b59),
    onPrimary: dark ? const Color(0xff00382d) : Colors.white,
    primaryContainer: dark ? const Color(0xff164b40) : const Color(0xffd9f1e8),
    onPrimaryContainer: dark ? const Color(0xffc9f6e8) : const Color(0xff073e32),
    secondary: dark ? const Color(0xffe4c480) : const Color(0xff785b22),
    surface: dark ? const Color(0xff14251f) : const Color(0xfffffefa),
    onSurface: dark ? const Color(0xffe7f0e9) : const Color(0xff193b30),
    onSurfaceVariant: dark ? const Color(0xffb8cdc2) : const Color(0xff52675d),
    outline: dark ? const Color(0xff829c8e) : const Color(0xff72887b),
    outlineVariant: dark ? const Color(0xff344d40) : const Color(0xffdce5db),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Noto Sans Myanmar',
    fontFamilyFallback: const ['Bahtzay UI Symbols', 'Noto Sans Symbols 2'],
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xff0d1b16) : const Color(0xfff5f6f0),
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.65),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.65),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.7),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.7),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.5),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff0d1b16) : const Color(0xfff5f6f0),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0, margin: const EdgeInsets.symmetric(vertical: 8),
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff102119) : const Color(0xfffafbf7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: rounded,
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: rounded, side: BorderSide(color: scheme.outlineVariant),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: rounded)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 24),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xffd9eee1) : const Color(0xff193b30),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: dark ? const Color(0xff193b30) : const Color(0xfff1f8f3), height: 1.7),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
  );
}
