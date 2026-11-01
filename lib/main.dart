import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/audit_controller.dart';
import 'controllers/workspace_controller.dart';
import 'screens/home_shell.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await AppSettings.instance.load();
  runApp(const SeoAuditApp());
  // Keep the native/web launch artwork visible until the first app frame can
  // include the decoded top-bar logo. No timed splash or extra route is needed.
  binding.addPostFrameCallback((_) async {
    try {
      await precacheImage(BrandLogo.image, binding.rootElement!);
    } finally {
      binding.allowFirstFrame();
    }
  });
}

class SeoAuditApp extends StatefulWidget {
  const SeoAuditApp({super.key, this.settings, this.workspace, this.audit});
  final AppSettings? settings;
  final WorkspaceController? workspace;
  final AuditController? audit;
  @override
  State<SeoAuditApp> createState() => _SeoAuditAppState();
}

class _SeoAuditAppState extends State<SeoAuditApp> {
  late final AppSettings _settings = widget.settings ?? AppSettings.instance;
  @override
  void initState() {
    super.initState();
    _settings.load().ignore();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    settings: _settings,
    child: ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        title: 'MobileSEO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: _settings.themeMode,
        themeAnimationDuration:
            _settings.reduceMotion ||
                (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        themeAnimationCurve: Curves.easeInOut,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || _settings.reduceMotion,
            ),
            child: child!,
          );
        },
        home: HomeShell(workspace: widget.workspace, audit: widget.audit),
      ),
    ),
  );
}
