import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/day_sectioned_entry_list.dart';
import 'package:spendwise/ui/common/lists/flat_entry_sliver.dart';
import 'package:spendwise/ui/common/sheets/sliver_tray.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

import '../../../support/ui_test_timeout.dart';

const _rowColor = Colors.green;

void main() {
  const scrollDelta = 500.0;
  const selectedTrayScrollDelta = 100.0;
  const maxScrolls = 100;

  test('day descriptors preserve header order and row identity', () {
    final firstRow = _row('first');
    final secondRow = _row('second');
    final thirdRow = _row('third');
    final firstDay = DateTime.utc(2026, 10, 2);
    final secondDay = DateTime.utc(2026, 10, 1);
    final sections = [
      DaySection(
        date: firstDay,
        rows: [firstRow, secondRow],
        income: Decimal.fromInt(5),
        expenses: Decimal.fromInt(3),
      ),
      DaySection(
        date: secondDay,
        rows: [thirdRow],
        income: Decimal.zero,
        expenses: Decimal.fromInt(4),
      ),
    ];

    final descriptors = daySectionedEntryDescriptors(sections);

    expect(descriptors.map(_descriptorValue), [
      firstDay,
      firstRow,
      secondRow,
      secondDay,
      thirdRow,
    ]);
    expect(
      (descriptors[0] as DaySectionHeaderDescriptor).net,
      Decimal.fromInt(2),
    );
    expect(
      (descriptors[3] as DaySectionHeaderDescriptor).net,
      Decimal.fromInt(-4),
    );
    expect(
      identical((descriptors[1] as DaySectionEntryDescriptor).row, firstRow),
      isTrue,
    );
    expect(
      identical((descriptors[2] as DaySectionEntryDescriptor).row, secondRow),
      isTrue,
    );
    expect(
      identical((descriptors[4] as DaySectionEntryDescriptor).row, thirdRow),
      isTrue,
    );
    expect(daySectionedEntryDescriptors(const []), isEmpty);
  });

  testWidgets(
    'entries constructor filters its supplied entries by the period',
    (tester) async {
      final ledger = _ledgerWithEntries(2);
      final first = ledger.state.entries.values.first;
      final outside = Entry(
        name: 'Outside period',
        amount: first.amount,
        sourceID: first.sourceID,
        categoryID: first.categoryID,
        date: DateTime.utc(2026, 10, 2),
      );
      ledger.addEntry(outside);
      final window = DateRange(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
      );
      final list = DaySectionedEntryList(
        ledger: ledger,
        state: ledger.state,
        window: window,
        entries: [first, outside],
      );
      await _pumpDayList(tester, ledger, () => list);

      final row = tester.widget<EntryRow>(find.byType(EntryRow));
      expect(row.row.id, first.id);
      expect(row.row.title, 'Food');
      expect(row.row.note, first.name);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'prepared sections deliver merchant and caption to the entry delete action',
    (tester) async {
      final ledger = _ledgerWithEntries(1);
      final entry = ledger.state.entries.values.single;
      final base = transactionRow(entry, ledger.state);
      final merchantRow = TransactionRow(
        id: entry.id,
        title: 'Merchant',
        note: '',
        accountLine: 'Direct to Food / Checking',
        symbolName: base.symbolName,
        color: base.color,
        amount: base.amount,
        amountKind: base.amountKind,
      );
      final section = DaySection(
        date: entry.date,
        rows: [merchantRow],
        income: Decimal.zero,
        expenses: entry.amount.abs(),
      );
      DaySectionedEntryList buildList() {
        final sections = ledger.state.entries.containsKey(entry.id)
            ? [section]
            : <DaySection>[];
        return DaySectionedEntryList.prepared(
          ledger: ledger,
          state: ledger.state,
          sections: sections,
        );
      }

      await _pumpDayList(tester, ledger, buildList);

      final row = tester.widget<EntryRow>(find.byType(EntryRow));
      expect(identical(row.row, merchantRow), isTrue);
      expect(find.text('Direct to Food / Checking'), findsOneWidget);
      expect(find.text(entry.name), findsNothing);
      await tester.drag(find.text('Merchant'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete Merchant?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Merchant'), findsNothing);
      expect(ledger.state.entries.containsKey(entry.id), isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'lazy sliver rows appear on scroll and delete the intended entry',
    (tester) async {
      final ledger = _ledgerWithEntries(240);
      final state = ledger.state;
      final entryRows = state.entries.values
          .map((entry) => transactionRow(entry, state))
          .toList();
      final window = DateRange(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
      );
      final selectedRows = _selectedRows(entryRows);
      await _pumpEntrySlivers(tester, ledger, entryRows, window);

      expect(find.byType(EntryRow), findsWidgets);
      expect(find.text('Entry 0000'), findsNothing);
      expect(find.text('Selected Entry 0239'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Entry 0000'),
        scrollDelta,
        scrollable: find.byType(Scrollable),
        maxScrolls: maxScrolls,
      );

      expect(find.text('Entry 0000'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Selected Entry 0005'),
        selectedTrayScrollDelta,
        scrollable: find.byType(Scrollable),
        maxScrolls: maxScrolls,
      );
      expect(find.text('Selected Entry 0005'), findsOneWidget);
      expect(find.text('Selected Entry 0239'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Selected Entry 0239'),
        scrollDelta,
        scrollable: find.byType(Scrollable),
        maxScrolls: maxScrolls,
      );
      expect(find.text('Selected Entry 0239'), findsOneWidget);
      final selectedCaption = find.text('Selected Entry 0239');
      final selectedEntryRowFinder = find.ancestor(
        of: selectedCaption,
        matching: find.byType(EntryRow),
      );
      final lastSelectedRow = tester.widget<EntryRow>(selectedEntryRowFinder);
      expect(lastSelectedRow.row.id, selectedRows.last.id);

      await tester.drag(
        find.text('Selected Entry 0239'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete Food?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Selected Entry 0239'), findsNothing);
      expect(state.entries.containsKey(selectedRows.last.id), isFalse);
      expect(find.text('Selected Entry 0238'), findsOneWidget);
      await tester.drag(
        find.text('Selected Entry 0238'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete Food?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Selected Entry 0238'), findsNothing);
      expect(state.entries.containsKey(selectedRows[238].id), isFalse);
      expect(state.entries.containsKey(selectedRows.first.id), isTrue);
    },
    timeout: uiTestTimeout,
  );
}

Future<void> _pumpDayList(
  WidgetTester tester,
  Ledger ledger,
  DaySectionedEntryList Function() buildList,
) async {
  Widget builder(BuildContext context, Widget? child) {
    final list = buildList();
    return CustomScrollView(slivers: [list]);
  }

  final body = AnimatedBuilder(animation: ledger, builder: builder);
  final screen = Scaffold(body: body);
  final app = MaterialApp(home: screen);
  final scope = ProviderScope(
    overrides: [ledgerProvider.overrideWithValue(ledger)],
    child: app,
  );
  await tester.pumpWidget(scope);
}

SliverTray _tray(String title, Widget sliver) {
  return SliverTray(title: title, slivers: [sliver]);
}

Future<void> _pumpEntrySlivers(
  WidgetTester tester,
  Ledger ledger,
  List<TransactionRow> rows,
  DateRange window,
) async {
  final body = AnimatedBuilder(
    animation: ledger,
    builder: (context, child) => _entrySliverScrollView(ledger, rows, window),
  );
  final screen = Scaffold(body: body);
  final app = MaterialApp(home: screen);
  final scope = ProviderScope(
    overrides: [ledgerProvider.overrideWithValue(ledger)],
    child: app,
  );
  await tester.pumpWidget(scope);
}

Widget _entrySliverScrollView(
  Ledger ledger,
  List<TransactionRow> rows,
  DateRange window,
) {
  final state = ledger.state;
  final selectedRows = _selectedRows(_rowsStillInLedger(rows, state));
  final primaryEntries = DaySectionedEntryList(
    ledger: ledger,
    state: state,
    window: window,
    entries: state.entries.values,
  );
  final primaryTray = _tray('Primary', primaryEntries);
  final selectedEntries = FlatEntrySliver(
    rows: selectedRows,
    ledger: ledger,
    state: state,
  );
  final selectedTray = _tray('Selected', selectedEntries);
  return CustomScrollView(slivers: [primaryTray, selectedTray]);
}

List<TransactionRow> _selectedRows(List<TransactionRow> rows) {
  return rows.map(_withSelectedCaption).toList();
}

List<TransactionRow> _rowsStillInLedger(
  List<TransactionRow> rows,
  LedgerState state,
) {
  final activeRows = <TransactionRow>[];
  for (final row in rows) {
    if (state.entries.containsKey(row.id)) activeRows.add(row);
  }
  return activeRows;
}

TransactionRow _withSelectedCaption(TransactionRow row) {
  return TransactionRow(
    id: row.id,
    title: row.title,
    note: 'Selected ${row.note}',
    accountLine: row.accountLine,
    symbolName: row.symbolName,
    color: row.color,
    amount: row.amount,
    amountKind: row.amountKind,
  );
}

Ledger _ledgerWithEntries(int count) {
  const accountID = 'a0000000-0000-0000-0000-000000000001';
  const categoryID = 'a0000000-0000-0000-0000-000000000002';
  final account = Account(
    id: accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  final category = TransactionCategory(
    id: categoryID,
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final entries = <String, Entry>{};
  for (var index = 0; index < count; index++) {
    final id = 'a0000000-0000-0000-0000-${index.toString().padLeft(12, '0')}';
    final entry = Entry(
      id: id,
      amount: Decimal.fromInt(-1),
      name: 'Entry ${index.toString().padLeft(4, '0')}',
      sourceID: accountID,
      categoryID: categoryID,
      date: DateTime.utc(2026, 10, 1),
    );
    entries[id] = entry;
  }
  return Ledger(
    state: LedgerState(
      moneySources: {accountID: MoneySource.account(account)},
      categories: {categoryID: category},
      entries: entries,
    ),
  );
}

TransactionRow _row(String id) {
  return TransactionRow(
    id: id,
    title: id,
    note: '',
    accountLine: 'Checking',
    symbolName: 'restaurant',
    color: _rowColor,
    amount: Decimal.one,
    amountKind: AmountKind.expense,
  );
}

Object _descriptorValue(DaySectionedEntryDescriptor descriptor) {
  return switch (descriptor) {
    DaySectionHeaderDescriptor(:final day) => day,
    DaySectionEntryDescriptor(:final row) => row,
  };
}
