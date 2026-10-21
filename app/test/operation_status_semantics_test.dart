import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final announce in [false, true]) {
    testWidgets(
      'status live region is $announce without duplicate child label',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: OperationStatusWidget(
                  state: OperationState.error,
                  errorMessage: 'Test error',
                  announceChanges: announce,
                  onDismissError: () {},
                ),
              ),
            ),
          );
          final node = tester.getSemantics(find.byType(OperationStatusWidget));
          expect(node.label, 'Status: Test error');
          expect(
            node.getSemanticsData().flagsCollection.isLiveRegion,
            announce,
          );
          expect(find.bySemanticsLabel('Test error'), findsNothing);
          expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      },
    );
  }
}
