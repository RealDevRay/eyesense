import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/legal/legal_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, String language) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // A bundle per test: the shared `rootBundle` caches the load *future*, and
    // awaiting one created inside an earlier test's async zone never resumes.
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: PlatformAssetBundle(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: LegalDocumentScreen(
            title: 'Privacy Policy',
            documentBase: 'assets/legal/privacy-policy',
            language: language,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('english loads the base document', (tester) async {
    await open(tester, 'en');

    expect(find.text('EyeSense Privacy Policy'), findsOneWidget);
    expect(find.textContaining('only available in English'), findsNothing);
  });

  testWidgets('kiswahili loads the translation', (tester) async {
    await open(tester, 'sw');

    expect(find.text('Sera ya Faragha ya EyeSense'), findsOneWidget);
    expect(find.textContaining('only available in English'), findsNothing);
  });

  testWidgets('an untranslated language falls back to english with a notice', (tester) async {
    // A missing translation must never leave someone facing an error screen
    // instead of the policy they are entitled to read.
    await open(tester, 'fr');

    expect(find.text('EyeSense Privacy Policy'), findsOneWidget);
    expect(find.textContaining('only available in English'), findsOneWidget);
  });
}
