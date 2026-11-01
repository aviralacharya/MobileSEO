import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_seo/screens/licenses_screen.dart';
import 'package:mobile_seo/theme/app_theme.dart';

void main() {
  testWidgets(
    'preserves shared and additional licenses when opening a package',
    (tester) async {
      LicenseRegistry.reset();
      addTearDown(LicenseRegistry.reset);
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks([
          'alpha',
          'beta',
        ], 'Shared attribution and permission.');
        yield const LicenseEntryWithLineBreaks([
          'alpha',
        ], 'Additional copyright and conditions.');
      });
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: const LicensesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 licenses'), findsOneWidget);
      expect(find.text('1 license'), findsOneWidget);
      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Shared attribution and permission.'), findsOneWidget);
      expect(find.text('Additional copyright and conditions.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();
      expect(find.text('Shared attribution and permission.'), findsOneWidget);
      expect(find.text('Additional copyright and conditions.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
