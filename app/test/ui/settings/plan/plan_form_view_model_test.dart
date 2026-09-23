import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan/plan_form_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan buildPlan({required Decimal amount}) {
    return RecurringPlan(
      id: 'p0000000-0000-0000-0000-000000000001',
      template: EntryTemplate(
        amount: amount,
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2025, 12, 31),
    );
  }

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

  group('applyPickerResult', () {
    test('an explicit one-time choice keeps the current frequency', () {
      final result = applyPickerResult(RecurrenceFrequency.monthly, null);
      expect(result, RecurrenceFrequency.monthly);
    });

    test('a genuinely picked frequency replaces the current one', () {
      final result = applyPickerResult(
        RecurrenceFrequency.monthly,
        RecurrenceFrequency.yearly,
      );
      expect(result, RecurrenceFrequency.yearly);
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

  test(
    'disabling end date leaves the stored date but stops it applying on save',
    () async {
      final plan = buildPlan(amount: dec('-10'));
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      await container.read(planFormViewModelProvider(plan.id).future);
      final viewModel = container.read(
        planFormViewModelProvider(plan.id).notifier,
      );

      viewModel.setHasEndDate(true);
      viewModel.setHasEndDate(false);

      final formState = container
          .read(planFormViewModelProvider(plan.id))
          .value;
      expect(formState?.hasEndDate, isFalse);

      await viewModel.save();

      expect(ledger.state.plans[plan.id]!.endDate, isNull);
    },
  );

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
}
