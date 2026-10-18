import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/legal/legal_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The handle must be released inside the test body: tear-downs run after the
  // framework asserts that no handle is still active.
  Future<SemanticsHandle> pump(WidgetTester tester, String source) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: LegalMarkdown(source: source)),
        ),
      ),
    );
    await tester.pump();
    return handle;
  }

  /// Every string a listener would actually hear.
  ///
  /// Read from the semantics tree rather than from `RichText`, because
  /// decorative widgets wrapped in `ExcludeSemantics` still exist in the
  /// widget tree while never reaching a screen reader.
  List<String> spoken(WidgetTester tester) {
    SemanticsNode? root;
    void findRoot(PipelineOwner owner) {
      root ??= owner.semanticsOwner?.rootSemanticsNode;
      owner.visitChildren(findRoot);
    }

    findRoot(tester.binding.rootPipelineOwner);

    final labels = <String>[];
    void visit(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root!);
    return labels;
  }

  testWidgets('markdown syntax is never read aloud', (tester) async {
    final handle = await pump(tester, '''
# EyeSense Privacy Policy

**Effective date:** 18 October 2026

## 1. Who we are

Contact us at `info@devray.qzz.io` or see [our site](https://eyesense.dpdns.org).

- Read Text works **entirely** on your device.
''');

    final text = spoken(tester).join(' ');
    expect(text, contains('EyeSense Privacy Policy'));
    expect(text, contains('Effective date:'));
    expect(text, contains('info@devray.qzz.io'));
    expect(text, contains('our site'));
    expect(text, contains('Read Text works entirely on your device.'));

    // A screen reader must not announce the markup itself.
    expect(text, isNot(contains('**')));
    expect(text, isNot(contains('`')));
    expect(text, isNot(contains('#')));
    expect(text, isNot(contains('](')));
    expect(text, isNot(contains('https://')));
    // The bullet glyph is decorative and excluded from semantics.
    expect(text, isNot(contains('\u2022')));
    handle.dispose();
  });

  testWidgets('headings are announced as headings so section jumping works', (tester) async {
    final handle = await pump(tester, '''
# EyeSense Privacy Policy

## 3. What the app processes

### 3.7 Your IP address

Body text that is not a heading.
''');

    final headers = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.header ?? false)
        .length;

    expect(headers, 3);
    handle.dispose();
  });

  testWidgets('tables are flattened into labelled rows, not pipes', (tester) async {
    final handle = await pump(tester, '''
| Feature | What happens to the image |
| --- | --- |
| Read Text | Analysed on your device, then deleted. |
| Describe Scene | Sent to the AI provider you configured. |
''');

    final lines = spoken(tester);
    final text = lines.join(' ');

    expect(text, isNot(contains('|')));
    expect(text, isNot(contains('---')));

    // Each cell is paired with its column heading, so the row makes sense
    // when heard without the visual grid.
    expect(lines, contains('Read Text'));
    expect(
      text,
      contains('What happens to the image: Analysed on your device, then deleted.'),
    );
    expect(
      text,
      contains('What happens to the image: Sent to the AI provider you configured.'),
    );
    handle.dispose();
  });
}
