import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

void main() {
  testWidgets('a ledger rename updates the label and keeps the draft', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    await openAdd(tester, harness);
    harness.form.applyPickedSource(checkingId);
    await tester.pumpAndSettle();
    expect(find.text('Checking'), findsOneWidget);
    final before = harness.draft;

    harness.ledger.updateAccount(
      Account(id: checkingId, name: 'Everyday', type: AccountType.checking),
    );
    await tester.pumpAndSettle();

    expect(find.text('Everyday'), findsOneWidget);
    expect(harness.draft, before);
  }, timeout: uiTestTimeout);
}
