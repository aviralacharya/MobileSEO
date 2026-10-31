import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SeoAuditApp());

class SeoAuditApp extends StatelessWidget {
  const SeoAuditApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppTheme.mode,
    builder: (context, mode, _) => MaterialApp(
      title: 'MobileSEO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      home: const HomeShell(),
    ),
  );
}
