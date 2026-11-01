import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_store.dart';

class AppSettings extends ChangeNotifier {
  AppSettings({LocalStore? store}) : _store = store ?? PreferencesStore();

  static final instance = AppSettings();
  static const storageKey = 'mobile_seo.settings.v1';
  final LocalStore _store;
  ThemeMode _themeMode = ThemeMode.system;
  bool _reduceMotion = false;
  bool _haptics = true;
  bool _disposed = false;
  int _pending = 0;
  Future<void>? _loaded;
  Future<void> _writes = Future.value();

  ThemeMode get themeMode => _themeMode;
  bool get reduceMotion => _reduceMotion;
  bool get haptics => _haptics;
  bool get saving => _pending > 0;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loaded ??= _read();

  Future<void> _read() async {
    try {
      final raw = await _store.read(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _themeMode = ThemeMode.values.firstWhere(
          (value) => value.name == data['theme'],
          orElse: () => ThemeMode.system,
        );
        _reduceMotion = data['reduceMotion'] == true;
        _haptics = data['haptics'] != false;
      }
    } catch (_) {
      // Defaults keep the app usable if preferences are unavailable.
    }
    _changed();
  }

  Future<void> update({
    ThemeMode? themeMode,
    bool? reduceMotion,
    bool? haptics,
  }) {
    _pending++;
    _changed();
    final next = _writes.then((_) async {
      await load();
      final nextTheme = themeMode ?? _themeMode;
      final nextMotion = reduceMotion ?? _reduceMotion;
      final nextHaptics = haptics ?? _haptics;
      try {
        await _store.write(
          storageKey,
          jsonEncode({
            'theme': nextTheme.name,
            'reduceMotion': nextMotion,
            'haptics': nextHaptics,
          }),
        );
        _themeMode = nextTheme;
        _reduceMotion = nextMotion;
        _haptics = nextHaptics;
      } finally {
        _pending--;
        _changed();
      }
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  void feedback({bool completed = false}) {
    if (!_haptics) return;
    final feedback = completed
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact();
    feedback.ignore();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier ??
      AppSettings.instance;
}
