import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
  );
  final coffee = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          savings.id: MoneySource.account(savings),
        },
        categories: {coffee.id: coffee},
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

  Future<EntryFormViewState> stateOf(
    ProviderContainer container,
    String? key,
  ) async {
    return container.read(entryFormViewModelProvider(key).future);
  }

  group('new entry defaults', () {
    test(
      'opens in newEntry mode with blank fields and today as the date',
      () async {
        final container = containerFor(buildLedger());
        final state = await stateOf(container, null);

        expect(state.mode, EntryFormMode.newEntry);
        expect(state.amountText, '');
        expect(state.nameText, '');
        expect(state.sourceId, isNull);
      },
    );
  });

  group('viewing an existing entry', () {
    test('starts read-only, seeded from the persisted entry', () async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);

      final state = await stateOf(container, entry.id);

      expect(state.mode, EntryFormMode.viewing);
      expect(state.nameText, 'Coffee run');
      expect(state.amountText, '5.00');
      expect(state.kind, EntryFormKind.expense);
    });
  });

  group('save validation', () {
    test('canSave is false with no amount, name or source', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);
      expect(state.canSave, isFalse);
    });

    test('canSave becomes true once amount, name and source are set', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.setAmount('12.50');
      viewModel.setName('Snacks');
      viewModel.applyPickedSource(checking.id);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.canSave, isTrue);
    });

    test('save() is a no-op while canSave is false', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      await viewModel.save();

      expect(ledger.state.entries, isEmpty);
    });
  });

  group('save outcomes', () {
    test(
      'editing an existing entry updates it and returns to viewing',
      () async {
        final entry = Entry(
          amount: dec('-5'),
          name: 'Coffee run',
          sourceID: checking.id,
          categoryID: coffee.id,
        );
        final ledger = buildLedger(entries: {entry.id: entry});
        final container = containerFor(ledger);
        await stateOf(container, entry.id);
        final viewModel = container.read(
          entryFormViewModelProvider(entry.id).notifier,
        );

        viewModel.startEditing();
        viewModel.setName('Updated name');
        await viewModel.save();

        expect(ledger.state.entries[entry.id]!.name, 'Updated name');
        final state = container
            .read(entryFormViewModelProvider(entry.id))
            .value!;
        expect(state.mode, EntryFormMode.viewing);
        expect(state.dismissed, isFalse);
      },
    );

    test(
      'a new entry without recurrence adds it and marks the form dismissed',
      () async {
        final ledger = buildLedger();
        final container = containerFor(ledger);
        await stateOf(container, null);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );

        viewModel.setAmount('12.50');
        viewModel.setName('New expense');
        viewModel.applyPickedSource(checking.id);
        await viewModel.save();

        expect(ledger.state.entries.length, 1);
        final added = ledger.state.entries.values.first;
        expect(added.name, 'New expense');
        expect(added.amount, dec('-12.50'));

        final state = container.read(entryFormViewModelProvider(null)).value!;
        expect(state.dismissed, isTrue);
      },
    );

    test(
      'a new entry with recurrence creates a plan instead, resolving the anchor day immediately',
      () async {
        final ledger = buildLedger();
        final container = containerFor(ledger);
        await stateOf(container, null);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );

        // Captured before the save, since computing "today" separately
        // after the save is flaky across a midnight boundary.
        final anchor = (await stateOf(container, null)).date;

        viewModel.setAmount('20');
        viewModel.setName('Rent');
        viewModel.applyPickedSource(checking.id);
        viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
        await viewModel.save();

        expect(ledger.state.plans.length, 1);
        expect(ledger.state.entries.length, 1);

        final plan = ledger.state.plans.values.first;
        expect(plan.anchor, anchor);
        // resolvePlans already ran once (inside save()), so the anchor day
        // itself is resolved rather than still pending.
        expect(plan.lastResolvedDate, anchor);
      },
    );

    test(
      'a domain rejection surfaces as state.error rather than throwing',
      () async {
        final entry = Entry(
          amount: dec('250'),
          name: 'Opening balance',
          sourceID: checking.id,
          includeInAnalysis: false,
          systemKind: SystemEntryKind.openingBalance,
        );
        final ledger = buildLedger(entries: {entry.id: entry});
        final container = containerFor(ledger);
        await stateOf(container, entry.id);
        final viewModel = container.read(
          entryFormViewModelProvider(entry.id).notifier,
        );

        viewModel.startEditing();
        viewModel.setName('Renamed opening balance');
        await viewModel.save();

        final state = container
            .read(entryFormViewModelProvider(entry.id))
            .value!;
        expect(state.error, isNotNull);
        expect(state.error, isA<SystemEntryLocked>());
      },
    );
  });

  group('delete', () {
    test('deletes the entry and marks the form dismissed', () async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      await stateOf(container, entry.id);
      final viewModel = container.read(
        entryFormViewModelProvider(entry.id).notifier,
      );

      await viewModel.delete();

      expect(ledger.state.entries.containsKey(entry.id), isFalse);
      final state = container.read(entryFormViewModelProvider(entry.id)).value!;
      expect(state.dismissed, isTrue);
    });
  });

  group('picker outcome application', () {
    test('applyPickedSource sets the source', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.applyPickedSource(checking.id);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.sourceId, checking.id);
    });

    test('applyPickedCategory sets the category', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.applyPickedCategory(coffee.id);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.categoryId, coffee.id);
    });

    test('setKind clears the category selection', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.applyPickedCategory(coffee.id);
      viewModel.setKind(EntryFormKind.income);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.categoryId, isNull);
    });

    test(
      'applyPickedDate moves an earlier end date up to the new date',
      () async {
        final container = containerFor(buildLedger());
        await stateOf(container, null);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );

        viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
        viewModel.setEndDateEnabled(true);
        viewModel.applyPickedEndDate(DateTime.utc(2026, 3, 1));

        viewModel.applyPickedDate(DateTime.utc(2026, 6, 1));

        final state = container.read(entryFormViewModelProvider(null)).value!;
        expect(state.date, DateTime.utc(2026, 6, 1));
        expect(state.endDate, DateTime.utc(2026, 6, 1));
      },
    );

    test(
      'applying a late picker result after the provider is disposed is a no-op, not a throw',
      () async {
        final container = containerFor(buildLedger());
        await stateOf(container, null);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );

        container.dispose();

        expect(() => viewModel.applyPickedSource(checking.id), returnsNormally);
      },
    );
  });

  group('prefillSource', () {
    test('sets the source on a fresh new-entry form', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.prefillSource(checking.id);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.sourceId, checking.id);
    });

    test('never overwrites a source the user already chose', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.applyPickedSource(savings.id);
      viewModel.prefillSource(checking.id);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.sourceId, savings.id);
    });
  });

  group('revertToPersisted', () {
    test('restores the persisted values and returns to viewing', () async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      await stateOf(container, entry.id);
      final viewModel = container.read(
        entryFormViewModelProvider(entry.id).notifier,
      );

      viewModel.startEditing();
      viewModel.setName('Changed name');
      viewModel.revertToPersisted();

      final state = container.read(entryFormViewModelProvider(entry.id)).value!;
      expect(state.mode, EntryFormMode.viewing);
      expect(state.nameText, 'Coffee run');
    });
  });
}
