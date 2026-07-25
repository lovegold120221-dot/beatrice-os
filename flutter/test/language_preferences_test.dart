import 'package:beatrice/data/services/language_preferences.dart';
import 'package:beatrice/ui/features/settings/language_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('language catalog includes requested dialects without UI artifacts', () {
    expect(
      LanguagePreferences.supportedLanguages,
      containsAll(['Dutch (Flemish)', 'Itawes', 'Ybanag']),
    );
    expect(LanguagePreferences.supportedLanguages, isNot(contains('history')));
    expect(LanguagePreferences.supportedLanguages, isNot(contains('check')));
    expect(
      LanguagePreferences.supportedLanguages.toSet().length,
      LanguagePreferences.supportedLanguages.length,
    );
  });

  test(
    'language instruction requests idiomatic delivery without stereotypes',
    () {
      final instruction = LanguagePreferences.responseInstruction('Itawes');

      expect(instruction, contains('PREFERRED RESPONSE LANGUAGE: Itawes'));
      expect(instruction, contains('natural, idiomatic'));
      expect(instruction, contains('Do not imitate stereotypes'));
    },
  );

  testWidgets('language dropdown provides searchable selection', (
    tester,
  ) async {
    String selected = LanguagePreferences.defaultLanguage;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: LanguagePickerField(
            selectedLanguage: selected,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search languages'),
      'Yba',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ybanag'), findsOneWidget);
    await tester.tap(find.text('Ybanag'));
    await tester.pumpAndSettle();
    expect(selected, 'Ybanag');
  });
}
