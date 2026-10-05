import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

ThemeData buildSpendWiseTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? SpendWiseColors.dark
      : SpendWiseColors.light;
  final amountRoles = brightness == Brightness.dark
      ? SpendWiseText.dark
      : SpendWiseText.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.action,
    onPrimary: tokens.onAction,
    secondary: tokens.action,
    onSecondary: tokens.onAction,
    surface: tokens.surface,
    onSurface: tokens.text,
    onSurfaceVariant: tokens.subtext,
    surfaceContainerLowest: tokens.surface,
    surfaceContainerLow: tokens.tint,
    surfaceContainer: tokens.tint,
    surfaceContainerHigh: tokens.raised,
    surfaceContainerHighest: tokens.tint,
    outline: tokens.control,
    outlineVariant: tokens.edge,
    error: tokens.error,
    onError: tokens.onAction,
    errorContainer: tokens.errorBg,
    onErrorContainer: tokens.error,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.base,
    fontFamily: 'InstrumentSans',
    extensions: [tokens, amountRoles],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.action,
        foregroundColor: tokens.onAction,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.action),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: tokens.action),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(borderSide: BorderSide(color: tokens.edge)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.edge),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.focus, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.error),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.error, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: tokens.tint,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.raised,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
  );
}
