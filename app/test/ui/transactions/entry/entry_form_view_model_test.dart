import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

class _ImmediateScanCoordinator extends ReceiptEntryCoordinator {
  _ImmediateScanCoordinator() : super(null);

  @override
  Future<void> requestScan(
    ReceiptScanSource source, {
    Uint8List? preCapturedBytes,
    required ScanResultHandler onPrefill,
  }) async {
    onPrefill(
      name: 'Scanned shop',
      amount: Decimal.parse('9.99'),
      date: DateTime.utc(2026, 1, 15),
    );
  }
}

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

  Entry notedEntry({String? id, String? note}) => Entry(
    id: id,
    amount: dec('-5'),
    name: 'Coffee run',
    sourceID: checking.id,
    categoryID: coffee.id,
    note: note,
  );

  Future<EntryFormNotifier> openedEditor(
    ProviderContainer container,
    String key,
  ) async {
    await stateOf(container, key);
    final viewModel = container.read(entryFormViewModelProvider(key).notifier);
    viewModel.startEditing();
    return viewModel;
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
      viewModel.applyPickedCategory(coffee.id);

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
        viewModel.applyPickedCategory(coffee.id);
        await viewModel.save();

        expect(ledger.state.entries.length, 1);
        final added = ledger.state.entries.values.first;
        expect(added.name, 'New expense');
        expect(added.amount, dec('-12.50'));

        final state = container.read(entryFormViewModelProvider(null)).value!;
        expect(state.dismissed, isTrue);
      },
    );

    test('a new entry with recurrence creates a plan instead, resolving the anchor day immediately', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      final anchor = (await stateOf(container, null)).date;

      viewModel.setAmount('20');
      viewModel.setName('Rent');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
      await viewModel.save();

      expect(ledger.state.plans.length, 1);
      expect(ledger.state.entries.length, 1);

      final plan = ledger.state.plans.values.first;
      expect(plan.anchor, anchor);
      expect(plan.lastResolvedDate, anchor);
    });

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

  group('opening balance edit', () {
    final openingDate = DateTime.utc(2026, 1, 1);
    final editedDate = DateTime.utc(2026, 1, 5);

    test('saves a changed amount and date without a category', () async {
      final entry = Entry(
        date: openingDate,
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
      viewModel.setAmount('300');
      viewModel.applyPickedDate(editedDate);

      final edited = container
          .read(entryFormViewModelProvider(entry.id))
          .value!;
      expect(edited.categoryId, isNull);
      expect(edited.canSave, isTrue);

      await viewModel.save();

      final saved = ledger.state.entries[entry.id]!;
      expect(saved.amount, dec('300'));
      expect(saved.date, editedDate);
      expect(saved.categoryID, isNull);
    });
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

    test('applyPickedEndDate enables and sets the end date together', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);

      viewModel.applyPickedEndDate(DateTime.utc(2026, 12, 1));

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.hasEndDate, isTrue);
      expect(state.endDate, DateTime.utc(2026, 12, 1));
    });

    test('a null picked end date and Never keep the cached end date', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);

      viewModel.applyPickedEndDate(null);
      var state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.hasEndDate, isFalse);
      expect(state.endDate, isNull);

      viewModel.applyPickedEndDate(DateTime.utc(2026, 12, 1));
      viewModel.setEndDateEnabled(false);
      state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.hasEndDate, isFalse);
      expect(state.endDate, DateTime.utc(2026, 12, 1));
    });

    test('Does not repeat clears the end date and Never state', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
      viewModel.applyPickedEndDate(DateTime.utc(2026, 12, 1));

      viewModel.applyPickedRecurrence(null);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.hasEndDate, isFalse);
      expect(state.endDate, isNull);
    });

    test('requestPickEnds emits PickEndsRequested', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);

      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickEnds();

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.step, isA<PickEndsRequested>());
    });

    test('applying a late picker result after the provider is disposed is a no-op, not a throw', () async {
      final container = containerFor(buildLedger());
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      container.dispose();

      expect(() => viewModel.applyPickedSource(checking.id), returnsNormally);
    });
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

  group('note preservation', () {
    test('editing another field keeps the persisted note', () async {
      final entry = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      final viewModel = await openedEditor(container, entry.id);

      viewModel.setName('Updated name');
      await viewModel.save();

      expect(ledger.state.entries[entry.id]!.name, 'Updated name');
      expect(ledger.state.entries[entry.id]!.note, 'memo');
    });

    test('saving picks up a note changed after the form opened', () async {
      final entry = notedEntry(note: 'old');
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      final viewModel = await openedEditor(container, entry.id);

      ledger.updateEntry(notedEntry(id: entry.id, note: 'new'));
      viewModel.setName('Unrelated edit');
      await viewModel.save();

      expect(ledger.state.entries[entry.id]!.name, 'Unrelated edit');
      expect(ledger.state.entries[entry.id]!.note, 'new');
    });

    test('a new entry save produces no note beside a noted entry', () async {
      final existing = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {existing.id: existing});
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      await viewModel.save();

      final added = ledger.state.entries.values.singleWhere(
        (candidate) => candidate.id != existing.id,
      );
      expect(added.note, isNull);
      expect(ledger.state.entries[existing.id]!.note, 'memo');
    });

    test('a recurring-plan add resolves with no note', () async {
      final existing = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {existing.id: existing});
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      viewModel.setAmount('20');
      viewModel.setName('Rent');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
      await viewModel.save();

      expect(ledger.state.plans.length, 1);
      final resolved = ledger.state.entries.values.singleWhere(
        (candidate) => candidate.id != existing.id,
      );
      expect(resolved.note, isNull);
      expect(ledger.state.entries[existing.id]!.note, 'memo');
    });

    test('an add through a missing entry id keeps no note', () async {
      const missingID = 'b0000000-0000-0000-0000-000000000009';
      final existing = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {existing.id: existing});
      final container = containerFor(ledger);
      final initial = await stateOf(container, missingID);
      expect(initial.mode, EntryFormMode.newEntry);
      final viewModel = container.read(
        entryFormViewModelProvider(missingID).notifier,
      );

      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      await viewModel.save();

      final added = ledger.state.entries.values.singleWhere(
        (candidate) => candidate.id != existing.id,
      );
      expect(added.note, isNull);
      expect(ledger.state.entries[existing.id], existing);
    });

    test('a recurring add through a missing entry id keeps no note', () async {
      const missingID = 'b0000000-0000-0000-0000-000000000009';
      final existing = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {existing.id: existing});
      final container = containerFor(ledger);
      await stateOf(container, missingID);
      final viewModel = container.read(
        entryFormViewModelProvider(missingID).notifier,
      );

      viewModel.setAmount('20');
      viewModel.setName('Rent');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
      await viewModel.save();

      expect(ledger.state.plans.length, 1);
      final resolved = ledger.state.entries.values.singleWhere(
        (candidate) => candidate.id != existing.id,
      );
      expect(resolved.note, isNull);
      expect(ledger.state.entries[existing.id], existing);
    });
  });

  group('add note draft', () {
    Future<EntryFormNotifier> openedAdd(ProviderContainer container) async {
      await stateOf(container, null);
      return container.read(entryFormViewModelProvider(null).notifier);
    }

    Future<void> fillRequired(EntryFormNotifier viewModel) async {
      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
    }

    test('a new form starts with an empty note draft', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      expect(state.noteText, isEmpty);
    });

    test('setNote updates the draft without touching other fields', () async {
      final container = containerFor(buildLedger());
      final viewModel = await openedAdd(container);
      viewModel.setAmount('12.50');
      viewModel.setName('New expense');

      viewModel.setNote('lunch receipt');

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.noteText, 'lunch receipt');
      expect(state.amountText, '12.50');
      expect(state.nameText, 'New expense');
    });

    test('a new-entry save carries the note, trimmed', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      final viewModel = await openedAdd(container);
      await fillRequired(viewModel);
      viewModel.setNote('  lunch receipt  ');
      await viewModel.save();

      final added = ledger.state.entries.values.single;
      expect(added.note, 'lunch receipt');
    });

    test('a whitespace-only note saves as null', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      final viewModel = await openedAdd(container);
      await fillRequired(viewModel);
      viewModel.setNote('   ');
      await viewModel.save();

      final added = ledger.state.entries.values.single;
      expect(added.note, isNull);
    });

    test(
      'a recurring save puts the note on the plan and every occurrence',
      () async {
        final ledger = buildLedger();
        final container = containerFor(ledger);
        final viewModel = await openedAdd(container);
        await fillRequired(viewModel);
        viewModel.applyPickedRecurrence(RecurrenceFrequency.weekly);
        viewModel.setNote('  split\nrent  ');
        await viewModel.save();
        ledger.resolvePlans(
          startOfDayUtc(DateTime.now()).add(const Duration(days: 21)),
        );

        final plan = ledger.state.plans.values.single;
        expect(plan.template.note, 'split\nrent');
        expect(ledger.state.entries.length, greaterThan(1));
        for (final entry in ledger.state.entries.values) {
          expect(entry.note, 'split\nrent');
        }
      },
    );

    test(
      'a recurring save without a typed note leaves the plan note null',
      () async {
        final ledger = buildLedger();
        final container = containerFor(ledger);
        final viewModel = await openedAdd(container);
        await fillRequired(viewModel);
        viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
        viewModel.setNote('   ');
        await viewModel.save();

        expect(ledger.state.plans.values.single.template.note, isNull);
        expect(ledger.state.entries.values.single.note, isNull);
      },
    );

    test('setKind keeps the note draft while clearing the category', () async {
      final container = containerFor(buildLedger());
      final viewModel = await openedAdd(container);
      viewModel.applyPickedCategory(coffee.id);
      viewModel.setNote('keep me');

      viewModel.setKind(EntryFormKind.income);

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.noteText, 'keep me');
      expect(state.categoryId, isNull);
    });

    test('setNote on an editing form never leaks into the edit save', () async {
      final entry = notedEntry(note: 'memo');
      final ledger = buildLedger(entries: {entry.id: entry});
      final container = containerFor(ledger);
      final viewModel = await openedEditor(container, entry.id);

      viewModel.setNote('draft that must not save');
      viewModel.setName('Updated name');
      await viewModel.save();

      expect(ledger.state.entries[entry.id]!.name, 'Updated name');
      expect(ledger.state.entries[entry.id]!.note, 'memo');
    });

    test('receipt prefill preserves a typed note', () async {
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          receiptEntryCoordinatorProvider(null)
              .overrideWith(_ImmediateScanCoordinator.new),
        ],
      );
      addTearDown(container.dispose);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.setNote('typed note');

      viewModel.requestScan(ReceiptScanSource.gallery);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.noteText, 'typed note');
      expect(state.nameText, 'Scanned shop');
    });
  });

  group('save gating', () {
    test('concurrent save calls create exactly one entry', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);

      await Future.wait([viewModel.save(), viewModel.save()]);

      expect(ledger.state.entries.length, 1);
    });

    test('save after dismissal is a no-op', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      await viewModel.save();
      expect(ledger.state.entries.length, 1);

      await viewModel.save();

      expect(ledger.state.entries.length, 1);
    });

    test('a fresh save attempt clears a previous save error', () async {
      final ledger = buildLedger();
      final container = containerFor(ledger);
      await stateOf(container, null);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.setAmount('12.50');
      viewModel.setName('New expense');
      viewModel.applyPickedSource(checking.id);
      viewModel.applyPickedCategory(coffee.id);
      ledger.deleteAccount(checking.id);
      await viewModel.save();
      expect(
        container.read(entryFormViewModelProvider(null)).value!.error,
        isNotNull,
      );

      viewModel.applyPickedSource(savings.id);
      await viewModel.save();

      final state = container.read(entryFormViewModelProvider(null)).value!;
      expect(state.error, isNull);
      expect(ledger.state.entries.length, 1);
    });
  });

  group('display projection', () {
    test('resolves live names and category icon data', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      final display = projectEntryFormDisplay(
        state.copyWith(
          sourceId: () => checking.id,
          categoryId: () => coffee.id,
        ),
        container.read(ledgerProvider)!.state,
      );

      expect(display.sourceLabel, 'Checking');
      expect(display.categoryLabel, 'Coffee');
      expect(display.categorySymbol, 'local_cafe');
      expect(display.categoryColorHex, '#FF0000');
    });

    test('unresolvable selections use the named fallbacks', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      final display = projectEntryFormDisplay(
        state.copyWith(
          sourceId: () => checking.id,
          destinationId: () => 'missing-destination',
          categoryId: () => 'missing-category',
        ),
        container.read(ledgerProvider)!.state,
      );

      expect(display.sourceLabel, 'Checking');
      expect(display.destinationLabel, 'Unavailable account');
      expect(display.categoryLabel, 'Unavailable category');
      expect(display.categorySymbol, isNull);
    });

    test('null selections resolve to null labels', () async {
      final container = containerFor(buildLedger());
      final state = await stateOf(container, null);

      final display = projectEntryFormDisplay(
        state,
        container.read(ledgerProvider)!.state,
      );

      expect(display.sourceLabel, isNull);
      expect(display.destinationLabel, isNull);
      expect(display.categoryLabel, isNull);
    });

    test('an archived selection keeps its latest name', () async {
      final archived = coffee.settingLifecycle(LifecycleState.archived);
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {checking.id: MoneySource.account(checking)},
          categories: {archived.id: archived},
        ),
      );
      final container = containerFor(ledger);
      final state = await stateOf(container, null);

      final display = projectEntryFormDisplay(
        state.copyWith(categoryId: () => coffee.id),
        ledger.state,
      );

      expect(display.categoryLabel, 'Coffee');
      expect(display.categorySymbol, 'local_cafe');
    });

    test(
      'a ledger notification refreshes labels without rebuilding the form',
      () async {
        final ledger = buildLedger();
        final container = containerFor(ledger);
        await stateOf(container, null);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );
        viewModel.setName('Draft');
        viewModel.applyPickedCategory(coffee.id);
        final seen = <EntryFormDisplay>[];
        final subscription = container.listen(
          entryFormDisplayProvider(null),
          (_, next) => seen.add(next),
        );
        addTearDown(subscription.close);
        expect(seen, isEmpty);

        ledger.updateCategory(
          TransactionCategory(
            id: coffee.id,
            name: 'Espresso',
            kind: coffee.kind,
            colorHex: coffee.colorHex,
            includeInAnalysis: coffee.includeInAnalysis,
            parentID: coffee.parentID,
            symbol: coffee.symbol,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(seen, hasLength(1));
        expect(seen.single.categoryLabel, 'Espresso');
        final form = container.read(entryFormViewModelProvider(null)).value!;
        expect(form.nameText, 'Draft');
        expect(form.categoryId, coffee.id);
      },
    );
  });
}
