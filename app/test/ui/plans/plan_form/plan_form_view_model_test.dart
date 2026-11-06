import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/plans/plan_form/plan_form_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan buildPlan({
    required Decimal amount,
    String? note,
    DateTime? endDate,
    DateTime? lastResolvedDate,
  }) {
    return RecurringPlan(
      id: 'p0000000-0000-0000-0000-000000000001',
      template: EntryTemplate(
        amount: amount,
        name: 'Rent',
        sourceID: source.id,
        note: note,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      endDate: endDate,
      lastResolvedDate: lastResolvedDate ?? DateTime.utc(2025, 12, 31),
    );
  }

  Future<PlanFormNotifier> openForm(
    ProviderContainer container,
    String planID,
  ) async {
    final provider = planFormViewModelProvider(planID);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return container.read(provider.notifier);
  }

  PlanFormViewState readForm(ProviderContainer container, String planID) =>
      container.read(planFormViewModelProvider(planID)).requireValue;

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Ledger buildLedger(RecurringPlan plan) => Ledger(
    state: LedgerState(
      moneySources: {source.id: MoneySource.account(source)},
      plans: {plan.id: plan},
    ),
  );

  group('canSavePlanForm', () {
    test('rejects a blank name', () {
      expect(canSavePlanForm(name: '   ', amount: dec('10')), isFalse);
    });

    test('rejects a zero amount', () {
      expect(canSavePlanForm(name: 'Rent', amount: dec('0')), isFalse);
    });

    test('accepts a trimmed name and non-zero amount', () {
      expect(canSavePlanForm(name: 'Rent', amount: dec('10')), isTrue);
    });
  });

  group('applyOriginalSign', () {
    test('reapplies a negative sign regardless of the typed magnitude', () {
      final result = applyOriginalSign(
        magnitude: dec('75'),
        originalAmount: dec('-10'),
      );
      expect(result, dec('-75'));
    });

    test('keeps a positive sign for an originally-positive amount', () {
      final result = applyOriginalSign(
        magnitude: dec('75'),
        originalAmount: dec('10'),
      );
      expect(result, dec('75'));
    });
  });

  test(
    'initial state mirrors the plan, with amount shown as a magnitude',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));

      final formState = await container.read(
        planFormViewModelProvider(plan.id).future,
      );

      expect(formState.name, 'Rent');
      expect(formState.amountText, '10.00');
      expect(formState.frequency, RecurrenceFrequency.monthly);
      expect(formState.anchor, DateTime.utc(2026, 1, 1));
      expect(formState.hasEndDate, isFalse);
      expect(formState.endDate, isNull);
      expect(formState.sourceName, 'Wallet');
    },
  );

  test('source name is not editable through the ViewModel surface', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));

    final formState = await container.read(
      planFormViewModelProvider(plan.id).future,
    );

    expect(formState.sourceName, 'Wallet');
  });

  test('cannot save with a blank name', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setName('   ');

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.canSave,
      isFalse,
    );
  });

  test('cannot save with a zero amount', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setAmount('0');

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.canSave,
      isFalse,
    );
  });

  test('requestPickRecurrence emits PickRecurrenceRequested', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.requestPickRecurrence();

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.step,
      isA<PickRecurrenceRequested>(),
    );
  });

  test(
    'applyPickedRecurrence replaces the frequency and clears the step',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.requestPickRecurrence();
      viewModel.applyPickedRecurrence(RecurrenceFrequency.yearly);

      final formState = container
          .read(planFormViewModelProvider(plan.id))
          .value;
      expect(formState?.frequency, RecurrenceFrequency.yearly);
      expect(formState?.step, isNull);
    },
  );

  test('applyPickedRecurrence with null keeps the current frequency', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.requestPickRecurrence();
    viewModel.applyPickedRecurrence(null);

    final formState = container.read(planFormViewModelProvider(plan.id)).value;
    expect(formState?.frequency, RecurrenceFrequency.monthly);
  });

  test('requestPickAnchor emits PickAnchorRequested', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.requestPickAnchor();

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.step,
      isA<PickAnchorRequested>(),
    );
  });

  test(
    'applyPickedAnchor normalizes to UTC midnight and clears the step',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.requestPickAnchor();
      viewModel.applyPickedAnchor(DateTime(2026, 3, 15, 13, 45));

      final formState = container
          .read(planFormViewModelProvider(plan.id))
          .value;
      expect(formState?.anchor, DateTime.utc(2026, 3, 15));
      expect(formState?.step, isNull);
    },
  );

  test(
    'applyPickedAnchor with null (dismissed picker) keeps the anchor',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.requestPickAnchor();
      viewModel.applyPickedAnchor(null);

      final formState = container
          .read(planFormViewModelProvider(plan.id))
          .value;
      expect(formState?.anchor, DateTime.utc(2026, 1, 1));
      expect(formState?.step, isNull);
    },
  );

  test('enabling end date defaults it to the anchor', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setHasEndDate(true);

    final formState = container.read(planFormViewModelProvider(plan.id)).value;
    expect(formState?.hasEndDate, isTrue);
    expect(formState?.endDate, DateTime.utc(2026, 1, 1));
  });

  test('Ends never clears the end date and nothing is saved with it', () async {
    final plan = buildPlan(
      amount: dec('-10'),
      endDate: DateTime.utc(2026, 9, 1),
    );
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    final viewModel = await openForm(container, plan.id);

    viewModel.setHasEndDate(false);

    final formState = readForm(container, plan.id);
    expect(formState.hasEndDate, isFalse);
    expect(formState.endDate, isNull);

    await viewModel.save();

    expect(ledger.state.plans[plan.id]!.endDate, isNull);
  });

  test('choosing a date reveals the stored end date', () async {
    final plan = buildPlan(
      amount: dec('-10'),
      endDate: DateTime.utc(2026, 9, 1),
    );
    final container = buildContainer(buildLedger(plan));
    final viewModel = await openForm(container, plan.id);

    viewModel.setHasEndDate(false);
    viewModel.setHasEndDate(true);

    expect(readForm(container, plan.id).endDate, DateTime.utc(2026, 1, 1));
  });

  test('choosing a date keeps an end date already set', () async {
    final plan = buildPlan(
      amount: dec('-10'),
      endDate: DateTime.utc(2026, 9, 1),
    );
    final container = buildContainer(buildLedger(plan));
    final viewModel = await openForm(container, plan.id);

    viewModel.setHasEndDate(true);

    expect(readForm(container, plan.id).endDate, DateTime.utc(2026, 9, 1));
  });

  test('requestPickEndDate emits PickEndDateRequested', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.requestPickEndDate();

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.step,
      isA<PickEndDateRequested>(),
    );
  });

  test(
    'applyPickedEndDate normalizes to UTC midnight and clears the step',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.setHasEndDate(true);
      viewModel.requestPickEndDate();
      viewModel.applyPickedEndDate(DateTime(2026, 6, 1, 9, 30));

      final formState = container
          .read(planFormViewModelProvider(plan.id))
          .value;
      expect(formState?.endDate, DateTime.utc(2026, 6, 1));
      expect(formState?.step, isNull);
    },
  );

  test(
    'editing the amount of an expense plan preserves the negative sign on save',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.setAmount('99.00');
      await viewModel.save();

      expect(ledger.state.plans[plan.id]!.template.amount, dec('-99'));
    },
  );

  test(
    'editing the amount of an income plan keeps the amount positive',
    () async {
      final plan = buildPlan(amount: dec('10'));
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.setAmount('42.00');
      await viewModel.save();

      expect(ledger.state.plans[plan.id]!.template.amount, dec('42'));
    },
  );

  test('saving does not change lastResolvedDate', () async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setAmount('15.00');
    await viewModel.save();

    expect(
      ledger.state.plans[plan.id]!.lastResolvedDate,
      plan.lastResolvedDate,
    );
  });

  test('saving emits PlanFormSaved', () async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    await viewModel.save();

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.step,
      isA<PlanFormSaved>(),
    );
  });

  test('saving an unrelated edit preserves the stored template note', () async {
    final plan = buildPlan(amount: dec('-10'), note: '  memo ');
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setAmount('15.00');
    await viewModel.save();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.template.note, 'memo');
    expect(saved.template.amount, dec('-15'));
  });

  test('saving keeps a template note that arrived after opening', () async {
    final plan = buildPlan(amount: dec('-10'), note: 'original');
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    final remote = ledger.state.plans[plan.id]!;
    ledger.updatePlan(
      RecurringPlan(
        id: remote.id,
        template: EntryTemplate(
          amount: remote.template.amount,
          name: remote.template.name,
          sourceID: remote.template.sourceID,
          note: 'remote',
        ),
        frequency: remote.frequency,
        anchor: remote.anchor,
        lastResolvedDate: remote.lastResolvedDate,
      ),
    );
    await viewModel.save();

    expect(ledger.state.plans[plan.id]!.template.note, 'remote');
  });

  test('saving a note-free plan keeps it note-free', () async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setName('Updated');
    await viewModel.save();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.template.note, isNull);
    expect(saved.template.name, 'Updated');
  });

  test('reopening after disposal starts from the persisted plan', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    final provider = planFormViewModelProvider(plan.id);
    final subscription = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    container.read(provider.notifier).setName('Edited');
    subscription.close();
    await container.pump();

    await openForm(container, plan.id);

    expect(readForm(container, plan.id).name, 'Rent');
  });

  test('a missing plan is an error and loads once it exists', () async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
      ),
    );
    final container = buildContainer(ledger);
    final provider = planFormViewModelProvider(plan.id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future).then((_) {}, onError: (_) {});

    expect(container.read(provider), isA<AsyncError<PlanFormViewState>>());

    ledger.addPlan(plan);
    container.invalidate(provider);
    await container.read(provider.future);

    expect(readForm(container, plan.id).name, 'Rent');
  });

  test('an unavailable ledger is an error and loads once ready', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    final provider = planFormViewModelProvider(plan.id);
    container.listen(provider, (_, _) {});
    await container.read(provider.future).then((_) {}, onError: (_) {});

    expect(container.read(provider), isA<AsyncError<PlanFormViewState>>());

    container.updateOverrides([
      ledgerProvider.overrideWithValue(buildLedger(plan)),
    ]);
    container.invalidate(provider);
    await container.read(provider.future);

    expect(readForm(container, plan.id).name, 'Rent');
  });

  test('a save rejected by the ledger keeps the draft and the error', () async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);
    final container = buildContainer(ledger);
    final viewModel = await openForm(container, plan.id);

    viewModel.setName('Edited');
    viewModel.setAmount('77');
    viewModel.applyPickedAnchor(DateTime.utc(2025, 6, 1));
    ledger.deletePlan(plan.id);
    await viewModel.save();

    final formState = readForm(container, plan.id);
    expect(formState.error, isA<UnknownPlan>());
    expect(formState.name, 'Edited');
    expect(formState.amountText, '77');
    expect(formState.anchor, DateTime.utc(2025, 6, 1));
    expect(formState.step, isNull);
  });

  test(
    'changing the schedule after resolution surfaces the stale cursor',
    () async {
      final plan = buildPlan(
        amount: dec('-10'),
        lastResolvedDate: DateTime.utc(2026, 2, 1),
      );
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      final viewModel = await openForm(container, plan.id);

      viewModel.applyPickedRecurrence(RecurrenceFrequency.yearly);
      await viewModel.save();

      final formState = readForm(container, plan.id);
      expect(formState.error, isA<StaleResolutionCursor>());
      expect(formState.frequency, RecurrenceFrequency.yearly);
      expect(formState.step, isNull);
    },
  );

  test(
    'an end date before the first date surfaces the exhausted plan',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final container = buildContainer(buildLedger(plan));
      final viewModel = await openForm(container, plan.id);

      viewModel.setHasEndDate(true);
      viewModel.applyPickedEndDate(DateTime.utc(2025, 1, 1));
      await viewModel.save();

      final formState = readForm(container, plan.id);
      expect(formState.error, isA<ExhaustedPlan>());
      expect(formState.endDate, DateTime.utc(2025, 1, 1));
    },
  );
}
