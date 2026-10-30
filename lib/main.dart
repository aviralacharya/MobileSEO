import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SeoAuditApp());
}

/// MobileSEO — audits the on-page SEO of any public URL.
class SeoAuditApp extends StatelessWidget {
  const SeoAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobileSEO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
