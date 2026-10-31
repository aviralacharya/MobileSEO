import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();
  static const Color seed = Color(0xFF3D5AFE);
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  static void toggle() => mode.value = mode.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    final border = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          surface: card,
          surfaceContainerLowest: bg,
          surfaceContainerLow: dark
              ? const Color(0xFF162236)
              : const Color(0xFFF1F5F9),
          surfaceContainer: card,
          surfaceContainerHigh: dark
              ? const Color(0xFF263449)
              : const Color(0xFFF1F5F9),
          surfaceContainerHighest: dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          outlineVariant: border,
          error: dark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: dark ? const Color(0xFF263449) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: const Color(0xFF8AB4F8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
