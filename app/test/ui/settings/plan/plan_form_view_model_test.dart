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

  RecurringPlan buildPlan({required Decimal amount, String? note}) {
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
    test('rejects a blank name and zero amount', () {
      expect(canSavePlanForm(name: '   ', amount: dec('10')), isFalse);
      expect(canSavePlanForm(name: 'Rent', amount: dec('0')), isFalse);
    });

    test('accepts a trimmed name and non-zero amount', () {
      expect(canSavePlanForm(name: ' Rent ', amount: dec('10')), isTrue);
    });
  });

  test('initial state mirrors the editable plan values', () async {
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
  });

  test('applyPickedRecurrence replaces the frequency', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.applyPickedRecurrence(RecurrenceFrequency.yearly);

    final formState = container.read(planFormViewModelProvider(plan.id)).value;
    expect(formState?.frequency, RecurrenceFrequency.yearly);
  });

  test('applyPickedRecurrence with null keeps the current frequency', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.applyPickedRecurrence(null);

    final formState = container.read(planFormViewModelProvider(plan.id)).value;
    expect(formState?.frequency, RecurrenceFrequency.monthly);
  });

  test('applyPickedAnchor normalizes to UTC midnight', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.applyPickedAnchor(DateTime(2026, 3, 15, 13, 45));

    final formState = container.read(planFormViewModelProvider(plan.id)).value;
    expect(formState?.anchor, DateTime.utc(2026, 3, 15));
  });

  test('applyPickedAnchor with null keeps the current anchor', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.applyPickedAnchor(null);

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.anchor,
      DateTime.utc(2026, 1, 1),
    );
  });

  test('applyPickedEndDate normalizes to UTC midnight', () async {
    final plan = buildPlan(amount: dec('-10'));
    final container = buildContainer(buildLedger(plan));
    await container.read(planFormViewModelProvider(plan.id).future);
    final viewModel = container.read(
      planFormViewModelProvider(plan.id).notifier,
    );

    viewModel.setHasEndDate(true);
    viewModel.applyPickedEndDate(DateTime(2026, 6, 1, 9, 30));

    expect(
      container.read(planFormViewModelProvider(plan.id)).value?.endDate,
      DateTime.utc(2026, 6, 1),
    );
  });

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

  test(
    'editing an expense amount preserves its negative sign on save',
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
    'editing an income amount preserves its positive sign on save',
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

  test('saving preserves a template note that arrived after opening', () async {
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
}
