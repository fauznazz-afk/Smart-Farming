import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/settings/sections/ai_section.dart';
import 'package:plts_monitoring/services/ai_settings.dart';
import 'package:plts_monitoring/utils/ai_provider.dart';

/// Pins that a typed API key reaches storage **without any gesture**.
///
/// Found on the device on 13 October 2026. The field saved on `onSubmitted`
/// only — the keyboard's done key — so pasting a key and tapping the back arrow,
/// which is what everyone actually does, wrote nothing. The screen reopened
/// showing the field empty and the assistant off, which reads as a broken save
/// rather than as "you did not press done".
void main() {
  Future<void> pumpSection(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSection())),
    );
    await tester.pumpAndSettle();
  }

  Finder keyField(WidgetTester tester) =>
      find.widgetWithText(TextField, 'API key');

  testWidgets('a typed key is stored with no Enter and no back press', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.enterText(keyField(tester), 'sk-test-123');
    // **No `onSubmitted`, no tap elsewhere, no pop.** Just the keystrokes and
    // the debounce window.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final stored = await AiSettings.load();
    expect(stored.apiKey, 'sk-test-123');
  });

  testWidgets('a key still being typed when the screen closes is stored', (
    tester,
  ) async {
    // The second half of the same bug: the debounce has not fired yet, so
    // `dispose` has to flush what is on screen. Leaving within 600 ms of the
    // last keystroke is ordinary.
    await pumpSection(tester);

    await tester.enterText(keyField(tester), 'sk-half-typed');
    await tester.pump(const Duration(milliseconds: 100));
    // Replace the tree, which is what the back gesture does.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    final stored = await AiSettings.load();
    expect(stored.apiKey, 'sk-half-typed');
  });

  testWidgets('the model and the custom endpoint are stored the same way', (
    tester,
  ) async {
    await pumpSection(tester);

    // Custom is the only provider with an endpoint field, and the only way to
    // reach it is the dropdown — so this also covers that the section still
    // works when the user picks a provider rather than typing.
    await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom (OpenAI-compatible)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Chat endpoint (HTTPS)'),
      'https://example.test/v1/chat/completions',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Model'),
      'my-model',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final stored = await AiSettings.load();
    expect(stored.provider.name, 'custom');
    expect(stored.endpoint, 'https://example.test/v1/chat/completions');
    expect(stored.model, 'my-model');
  });

  testWidgets('deleting the key is not undone by a pending write', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.enterText(keyField(tester), 'sk-to-delete');
    await tester.pump(const Duration(milliseconds: 100));
    // Press delete inside the debounce window. A write still holding the old
    // text would fire after the delete and put the key back.
    await tester.tap(find.byTooltip('Remove key'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final stored = await AiSettings.load();
    expect(stored.apiKey, isEmpty);
  });

  testWidgets('a stored key is prefilled when the section reopens', (
    tester,
  ) async {
    // The other half of the report: the key was written, so the field must come
    // back with it rather than empty.
    FlutterSecureStorage.setMockInitialValues({'ai_api_key': 'sk-existing'});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSection())),
    );
    await tester.pumpAndSettle();

    expect(find.text('sk-existing'), findsOneWidget);
  });
}