import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_seo/controllers/audit_controller.dart';
import 'package:mobile_seo/controllers/workspace_controller.dart';
import 'package:mobile_seo/main.dart';
import 'package:mobile_seo/services/app_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fixtures.dart';

class AppHarness {
  AppHarness({MemoryStore? store, http.Client Function()? clientFactory})
    : store = store ?? MemoryStore() {
    workspace = workspaceFor(this.store);
    settings = AppSettings(store: this.store);
    audit = AuditController(
      workspace: workspace,
      clientFactory:
          clientFactory ??
          () => throw StateError('Unexpected live audit request'),
    );
  }

  final MemoryStore store;
  late final WorkspaceController workspace;
  late final AppSettings settings;
  late final AuditController audit;

  Widget get app =>
      SeoAuditApp(settings: settings, workspace: workspace, audit: audit);

  void dispose() {
    audit.dispose();
    workspace.dispose();
    settings.dispose();
  }
}

Future<AppHarness> pumpTestApp(
  WidgetTester tester, {
  AppHarness? harness,
  Size size = const Size(412, 892),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'MobileSEO',
    packageName: 'com.example.mobile_seo',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  final resources = harness ?? AppHarness();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    resources.dispose();
  });
  await tester.pumpWidget(resources.app);
  await tester.pumpAndSettle();
  return resources;
}

Future<void> selectDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> selectAuditTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  final bar = tester.widget<TabBar>(
    find.ancestor(of: tab, matching: find.byType(TabBar)),
  );
  if (bar.isScrollable) {
    // Scroll the tab strip only. A recursive ensureVisible can also move the
    // enclosing destination PageView when the tab itself is already visible.
    await Scrollable.of(tester.element(tab)).position
        .ensureVisible(tester.renderObject(tab), alignment: .5);
    await tester.pumpAndSettle();
  }
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// NestedScrollView coordinates two scroll positions. Dragging the visible
/// viewport exercises that coordination, unlike a direct ensureVisible jump.
Future<void> revealByScrolling(
  WidgetTester tester,
  Finder target, {
  bool upwards = false,
  int maxDrags = 60,
  double horizontalFraction = .5,
}) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (
    var drag = 0;
    target.hitTestable().evaluate().isEmpty && drag < maxDrags;
    drag++
  ) {
    await tester.dragFrom(
      Offset(
        size.width * horizontalFraction,
        upwards ? size.height * .4 : size.height * .72,
      ),
      Offset(0, (upwards ? 1 : -1) * size.height * .3),
    );
    await tester.pumpAndSettle();
  }
  expect(
    target.hitTestable(),
    findsWidgets,
    reason: 'The control must be reachable by scrolling.',
  );
}
