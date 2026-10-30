import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_seo/main.dart';

void main() {
  testWidgets('App renders the home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MobileSEO'), findsOneWidget);
    expect(find.text('Start building your app here'), findsOneWidget);
  });
}
