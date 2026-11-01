import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/workspace_controller.dart';
import '../services/app_settings.dart';
import '../services/pagespeed_insights_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/support_card.dart';
import 'help_screen.dart';
import 'legal_pages.dart';
import 'licenses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = 'Loading version…';
  int? _cacheCount;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(
          () => _version = 'Version ${info.version} (${info.buildNumber})',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _version = 'Version information unavailable');
    }
    await _readCacheCount();
  }

  Future<void> _readCacheCount() async {
    try {
      final count = await PageSpeedInsightsService.cachedReportCount();
      if (mounted) setState(() => _cacheCount = count);
    } catch (_) {
      if (mounted) setState(() => _cacheCount = null);
    }
  }

  Future<void> _update(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this preference. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _clear({required bool history}) async {
    if (_clearing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          history ? 'Clear audit history?' : 'Clear PageSpeed cache?',
        ),
        content: Text(
          history
              ? 'Remove all audit snapshots from this device? This also removes the evidence used for trends and verified comparisons. Your saved projects and in-progress fixes are kept.'
              : 'Remove PageSpeed reports saved by earlier in-app checks? This does not affect reports opened in your browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      if (history) {
        await widget.workspace.clearHistory();
      } else {
        await PageSpeedInsightsService.clearCache();
        await _readCacheCount();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              history ? 'Audit history cleared' : 'PageSpeed cache cleared',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not clear stored data. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const BrandTitle(title: 'Settings & Help')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Make it yours', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Appearance & accessibility',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mode in ThemeMode.values)
                            ChoiceChip(
                              label: Text(switch (mode) {
                                ThemeMode.system => 'System',
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                              }),
                              avatar: Icon(switch (mode) {
                                ThemeMode.system =>
                                  Icons.brightness_auto_outlined,
                                ThemeMode.light => Icons.light_mode_outlined,
                                ThemeMode.dark => Icons.dark_mode_outlined,
                              }, size: 18),
                              selected: settings.themeMode == mode,
                              onSelected: settings.saving
                                  ? null
                                  : (_) => _update(
                                      () => settings.update(themeMode: mode),
                                    ),
                            ),
                        ],
                      ),
                      const Divider(height: 28),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reduce motion'),
                        subtitle: const Text(
                          'Use gentler transitions. Device accessibility settings are also respected.',
                        ),
                        value: settings.reduceMotion,
                        onChanged: settings.saving
                            ? null
                            : (value) => _update(
                                () => settings.update(reduceMotion: value),
                              ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Haptic feedback'),
                        subtitle: const Text(
                          'Subtle feedback for navigation and completed audits.',
                        ),
                        value: settings.haptics,
                        onChanged: settings.saving
                            ? null
                            : (value) => _update(
                                () => settings.update(haptics: value),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On-device storage',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your workspace is saved locally. No account required.',
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: widget.workspace,
                        builder: (context, _) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: const Text('Clear audit history'),
                          subtitle: Text(
                            '${widget.workspace.history.length} snapshots · Up to 100 retained',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          enabled:
                              !_clearing && widget.workspace.history.isNotEmpty,
                          onTap: () => _clear(history: true),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.speed_rounded),
                        title: const Text('Clear PageSpeed cache'),
                        subtitle: Text(
                          _cacheCount == null
                              ? 'Data from earlier in-app checks'
                              : '$_cacheCount reports from earlier in-app checks',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        enabled: !_clearing,
                        onTap: () => _clear(history: false),
                      ),
                      if (_clearing) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.help_outline_rounded),
                        title: const Text('Help & SEO glossary'),
                        subtitle: const Text(
                          'Answers, terminology and audit guidance',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const HelpScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const LegalPagesScreen(),
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms & Conditions'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const LegalPagesScreen(initialPage: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SupportCard(),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LicensesScreen(),
                    ),
                  ),
                  child: const Text('Open-source licenses'),
                ),
                Center(
                  child: Column(
                    children: [
                      Text('MobileSEO', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        _version,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
