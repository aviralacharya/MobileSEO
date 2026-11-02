import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/services/app_settings.dart';
import 'package:mobile_seo/services/fix_guides.dart';

import '../support/test_fixtures.dart';

void main() {
  test(
    'rapid preference changes wait for loading and preserve each field',
    () async {
      final store = MemoryStore({
        AppSettings.storageKey: jsonEncode({
          'theme': 'light',
          'reduceMotion': false,
          'haptics': false,
          'websitePlatform': 'shopify',
        }),
      });
      final reading = Completer<void>();
      final release = Completer<void>();
      store.beforeRead = (_) async {
        reading.complete();
        await release.future;
      };
      final settings = AppSettings(store: store);
      addTearDown(settings.dispose);
      final load = settings.load();
      await reading.future;
      final theme = settings.update(themeMode: ThemeMode.dark);
      final motion = settings.update(reduceMotion: true);
      final guide = settings.update(showAuditGuide: false);
      expect(settings.saving, isTrue);
      release.complete();
      await Future.wait([load, theme, motion, guide]);
      expect(settings.saving, isFalse);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.reduceMotion, isTrue);
      expect(settings.haptics, isFalse);
      expect(settings.showAuditGuide, isFalse);
      expect(settings.websitePlatform, WebsitePlatform.shopify);
      store.beforeRead = null;
      final restored = AppSettings(store: store);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.reduceMotion, isTrue);
      expect(restored.haptics, isFalse);
      expect(restored.showAuditGuide, isFalse);
      expect(restored.websitePlatform, WebsitePlatform.shopify);
    },
  );

  test(
    'failed preference writes leave the prior values and permit a retry',
    () async {
      final store = MemoryStore()..failWrites = true;
      final settings = AppSettings(store: store);
      addTearDown(settings.dispose);
      await expectLater(
        settings.update(
          themeMode: ThemeMode.dark,
          showAuditGuide: false,
          websitePlatform: WebsitePlatform.html,
        ),
        throwsStateError,
      );
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.showAuditGuide, isTrue);
      expect(settings.websitePlatform, WebsitePlatform.wordpress);
      expect(settings.saving, isFalse);
      store.failWrites = false;
      await settings.update(
        themeMode: ThemeMode.dark,
        haptics: false,
        showAuditGuide: false,
        websitePlatform: WebsitePlatform.html,
      );
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.haptics, isFalse);
      expect(settings.showAuditGuide, isFalse);
      expect(settings.websitePlatform, WebsitePlatform.html);
    },
  );
}
