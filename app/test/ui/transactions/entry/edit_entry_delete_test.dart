import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_form.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _deleteKey = ValueKey('edit-entry-delete');

class _EditForm extends ConsumerWidget {
  const _EditForm(this.entryId);

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(entryFormViewModelProvider(entryId)).value;
    if (state == null) return const SizedBox.shrink();

    return NewEntryForm(
      formKey: entryId,
      viewModel: ref.read(entryFormViewModelProvider(entryId).notifier),
      state: state,
      display: ref.watch(entryFormDisplayProvider(entryId)),
      frame: EntryFormFrame.pane,
      alert: null,
      onAlertAction: () {},
    );
  }
}

Future<void> _pumpEditing(
  WidgetTester tester,
  Ledger ledger,
  Entry entry,
) async {
  await pumpApp(
    tester,
    Material(child: _EditForm(entry.id)),
    ledger: ledger,
    settle: false,
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_EditForm)),
  );
  await container.read(entryFormViewModelProvider(entry.id).future);
  container.read(entryFormViewModelProvider(entry.id).notifier).startEditing();
  await tester.pumpAndSettle();
}

void main() {
  final checking = Account(name: 'Checking', type: AccountType.checking);
  final groceries = TransactionCategory(
    name: 'Groceries',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );

  Ledger ledgerWith(Entry entry) => Ledger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
      categories: {groceries.id: groceries},
      entries: {entry.id: entry},
    ),
  );

  testWidgets(
    'Delete entry archives an editable entry; a system entry has none',
    (tester) async {
      final entry = Entry(
        amount: Decimal.parse('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: groceries.id,
      );
      final ledger = ledgerWith(entry);
      await _pumpEditing(tester, ledger, entry);

      await tester.ensureVisible(find.byKey(_deleteKey));
      await tester.tap(find.byKey(_deleteKey));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(entry.id), isFalse);
      expect(ledger.state.binnedEntries.containsKey(entry.id), isTrue);

      final opening = Entry(
        amount: Decimal.parse('250'),
        name: 'Opening balance',
        sourceID: checking.id,
        includeInAnalysis: false,
        systemKind: SystemEntryKind.openingBalance,
      );
      await _pumpEditing(tester, ledgerWith(opening), opening);

      expect(find.byKey(_deleteKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    timeout: uiTestTimeout,
  );
}
