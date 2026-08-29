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
    test('shows the default title and no edit-source action', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      expect(state.title, 'Transactions');
      expect(state.showEditSourceAction, isFalse);
    });
  });

  group('scoped screen', () {
    test('shows the scope title and the edit-source action', () async {
      final scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {account.id, pocket.id},
      );
      final container = containerFor(buildLedger());
      final state = await stateOf(container, scope);

      expect(state.title, 'Checking');
      expect(state.showEditSourceAction, isTrue);
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

  group('mode and date', () {
    test('setMode switches the window used for totals and sections', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.setMode(TransactionsScreenMode.monthly);

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.mode, TransactionsScreenMode.monthly);
    });

    test('switchToDaily jumps to daily mode at the given month', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.switchToDaily(DateTime.utc(2026, 3));

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.mode, TransactionsScreenMode.daily);
      expect(state.selectedDate, DateTime.utc(2026, 3));
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
      'requestNewEntry emits EntryFormRequested with a null entry',
      () async {
        final container = containerFor(buildLedger());
        await stateOf(container, null);
        final viewModel = container.read(
          transactionsViewModelProvider(null).notifier,
        );

        viewModel.requestNewEntry();

        final state = container
            .read(transactionsViewModelProvider(null))
            .value!;
        expect(state.step, isA<EntryFormRequested>());
        expect((state.step! as EntryFormRequested).entry, isNull);
      },
    );

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
        expect((state.step! as EntryFormRequested).entry?.id, entry.id);
      },
    );

    test('requestEditSource is a no-op when the screen is unscoped', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.requestEditSource();

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.step, isNull);
    });

    test('requestEditSource emits SourceEditRequested when scoped', () async {
      final scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {account.id},
      );
      final container = containerFor(buildLedger());
      await stateOf(container, scope);
      final viewModel = container.read(
        transactionsViewModelProvider(scope).notifier,
      );

      viewModel.requestEditSource();

      final state = container.read(transactionsViewModelProvider(scope)).value!;
      expect(state.step, isA<SourceEditRequested>());
    });

    test('clearStep clears a pending step', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.requestNewEntry();
      viewModel.clearStep();

      final state = container.read(transactionsViewModelProvider(null)).value!;
      expect(state.step, isNull);
    });
  });
}
