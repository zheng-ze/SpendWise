import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final pocket = SubPocket(
    id: 'p0000000-0000-0000-0000-000000000001',
    name: 'Pocket',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          account.id: MoneySource.account(account.addSubPocket(pocket.id)),
          pocket.id: MoneySource.pocket(pocket),
        },
        entries: entries,
      ),
    );
  }

  ProviderContainer containerFor(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<TransactionsViewState> stateOf(
    ProviderContainer container,
    TransactionsScope? scope,
  ) {
    return container.read(transactionsViewModelProvider(scope).future);
  }

  group('unscoped screen', () {
    test('shows the default title', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      expect(state.title, 'History');
    });
  });

  group('scoped screen', () {
    test('shows the scope title', () async {
      final scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {account.id, pocket.id},
      );
      final container = containerFor(buildLedger());
      final state = await stateOf(container, scope);

      expect(state.title, 'Checking');
    });

    test('filters day sections to the scoped holders', () async {
      final scoped = Entry(
        amount: dec('-5'),
        name: 'in scope',
        sourceID: account.id,
        date: day(1),
      );
      final outOfScopeAccount = Account(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'Savings',
        type: AccountType.savings,
      );
      final outOfScope = Entry(
        amount: dec('-5'),
        name: 'not in scope',
        sourceID: outOfScopeAccount.id,
        date: day(1),
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {
            account.id: MoneySource.account(account),
            outOfScopeAccount.id: MoneySource.account(outOfScopeAccount),
          },
          entries: {scoped.id: scoped, outOfScope.id: outOfScope},
        ),
      );
      final scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {account.id},
      );
      final container = containerFor(ledger);

      final state = await stateOf(container, scope);

      expect(state.daySections, hasLength(1));
      expect(state.daySections.single.rows.single.title, isNot('not in scope'));
    });
  });

  group('totals', () {
    test('income and expenses sum the visible day sections', () async {
      final income = Entry(
        amount: dec('100'),
        name: 'Salary',
        sourceID: account.id,
        date: day(1),
      );
      final expense = Entry(
        amount: dec('-40'),
        name: 'Groceries',
        sourceID: account.id,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {income.id: income, expense.id: expense},
      );
      final container = containerFor(ledger);

      final state = await stateOf(container, null);

      expect(state.income, dec('100'));
      expect(state.expenses, dec('40'));
      expect(state.total, dec('60'));
    });
  });

  group('month selection', () {
    test('previous month crosses January into the prior December', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.setDate(DateTime.utc(2026, 1, 1));
      viewModel.previousMonth();

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.selectedDate, DateTime.utc(2025, 12));
    });

    test('next month crosses December into the next January', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.setDate(DateTime.utc(2026, 12, 31, 23));
      viewModel.nextMonth();

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.selectedDate, DateTime.utc(2027, 1));
    });

    test(
      'month commands normalize a non-UTC selection to UTC month start',
      () async {
        final container = containerFor(buildLedger());
        await stateOf(container, null);
        final viewModel = container.read(
          transactionsViewModelProvider(null).notifier,
        );

        viewModel.setDate(DateTime(2026, 3, 17, 22));
        viewModel.nextMonth();

        final state = container
            .read(transactionsViewModelProvider(null))
            .value!;
        expect(state.selectedDate, DateTime.utc(2026, 4));
        expect(state.selectedDate.isUtc, isTrue);
      },
    );

    test(
      'shows only the selected month in the scoped daily register',
      () async {
        final marchEntry = Entry(
          amount: dec('-5'),
          name: 'March',
          sourceID: account.id,
          date: DateTime.utc(2026, 3, 31),
        );
        final aprilEntry = Entry(
          amount: dec('-7'),
          name: 'April',
          sourceID: account.id,
          date: DateTime.utc(2026, 4, 1),
        );
        final container = containerFor(
          buildLedger(
            entries: {marchEntry.id: marchEntry, aprilEntry.id: aprilEntry},
          ),
        );
        final scope = TransactionsScope(
          title: 'Checking',
          scopeIDs: {account.id},
        );
        await stateOf(container, scope);
        final viewModel = container.read(
          transactionsViewModelProvider(scope).notifier,
        );

        viewModel.setDate(DateTime.utc(2026, 3));

        final state = container
            .read(transactionsViewModelProvider(scope))
            .value!;
        expect(state.selectedDate, DateTime.utc(2026, 3));
        expect(
          state.daySections
              .expand((section) => section.rows)
              .map((row) => row.note),
          ['March'],
        );
      },
    );

    test(
      'scoped next month preserves filtering and refreshes totals',
      () async {
        final aprilExpense = Entry(
          amount: dec('-5'),
          name: 'April scoped expense',
          sourceID: account.id,
          date: DateTime.utc(2026, 4, 1),
        );
        final mayIncome = Entry(
          amount: dec('20'),
          name: 'May scoped income',
          sourceID: account.id,
          date: DateTime.utc(2026, 5, 2),
        );
        final outOfScope = Entry(
          amount: dec('-99'),
          name: 'May other account',
          sourceID: 'a0000000-0000-0000-0000-000000000002',
          date: DateTime.utc(2026, 5, 3),
        );
        final scope = TransactionsScope(
          title: 'Checking',
          scopeIDs: {account.id, pocket.id},
        );
        final container = containerFor(
          buildLedger(
            entries: {
              aprilExpense.id: aprilExpense,
              mayIncome.id: mayIncome,
              outOfScope.id: outOfScope,
            },
          ),
        );
        await stateOf(container, scope);
        final viewModel = container.read(
          transactionsViewModelProvider(scope).notifier,
        );

        viewModel.setDate(DateTime.utc(2026, 4));
        viewModel.nextMonth();

        final state = container
            .read(transactionsViewModelProvider(scope))
            .value!;
        expect(state.title, 'Checking');
        expect(state.selectedDate, DateTime.utc(2026, 5));
        expect(state.daySections.expand((section) => section.rows).length, 1);
        expect(state.daySections.single.rows.single.id, mayIncome.id);
        expect(state.income, dec('20'));
        expect(state.expenses, Decimal.zero);
      },
    );

    test('shows an empty register for an empty selected month', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.setDate(DateTime.utc(2026, 5));

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.daySections, isEmpty);
      expect(state.income, Decimal.zero);
      expect(state.expenses, Decimal.zero);
    });
  });

  group('deleteEntry', () {
    test('removes the entry from the ledger', () async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        date: day(1),
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      await viewModel.deleteEntry(entry.id);

      expect(ledger.state.entries.containsKey(entry.id), isFalse);
    });
  });

  group('step emission', () {
    test(
      'openEntry emits EntryFormRequested with the resolved entry',
      () async {
        final entry = Entry(
          amount: dec('-5'),
          name: 'Coffee',
          sourceID: account.id,
          date: day(1),
        );
        final ledger = buildLedger(entries: {entry.id: entry});
        final container = containerFor(ledger);
        await stateOf(container, null);
        final viewModel = container.read(
          transactionsViewModelProvider(null).notifier,
        );

        viewModel.openEntry(entry.id);

        final state = container
            .read(transactionsViewModelProvider(null))
            .value!;
        expect((state.step! as EntryFormRequested).entry.id, entry.id);
      },
    );

    test('clearStep clears a pending step', () async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        date: day(1),
      );
      final container = containerFor(buildLedger(entries: {entry.id: entry}));
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.openEntry(entry.id);
      viewModel.clearStep();

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.step, isNull);
    });
  });
}
