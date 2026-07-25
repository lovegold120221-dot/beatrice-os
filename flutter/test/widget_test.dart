import 'package:flutter_test/flutter_test.dart';
import 'package:beatrice/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BeatriceApp());
    expect(find.byType(BeatriceApp), findsOneWidget);
  });
}
