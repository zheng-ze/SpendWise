import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  Ledger buildLedger(List<RecurringPlan> plans) {
    return Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {for (final p in plans) p.id: p},
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    container.listen(planListViewModelProvider, (previous, next) {});
    return container;
  }

  ProviderContainer buildContainerWithFailingProjection(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        planListProjectionProvider.overrideWith(FailingProjectionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(planListViewModelProvider, (previous, next) {});
    return container;
  }

  group('PlanListNotifier', () {
    final today = DateTime.now().toUtc();
    final soonerPlan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('-10'),
        name: 'Bravo',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.weekly,
      anchor: today,
      lastResolvedDate: today.subtract(const Duration(days: 1)),
    );
    final laterPlan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('5'),
        name: 'Alpha',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.yearly,
      anchor: today,
      lastResolvedDate: today.subtract(const Duration(days: 1)),
    );

    test('build starts with editing off and no step', () {
      final container = buildContainer(buildLedger([soonerPlan]));

      final state = container.read(planListViewModelProvider).value;

      expect(state?.plans.map((p) => p.id), [soonerPlan.id]);
      expect(state?.editing, isFalse);
      expect(state?.step, isNull);
    });

    test('the first read with a ready projection is AsyncData', () {
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger([soonerPlan])),
        ],
      );
      addTearDown(container.dispose);
      container.read(planListProjectionProvider);

      final first = container.read(planListViewModelProvider);

      expect(first, isA<AsyncData<PlanListViewState>>());
    });

    test('an unmounted view model resets editing and keeps the data', () async {
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger([soonerPlan])),
        ],
      );
      addTearDown(container.dispose);
      final mounted = container.listen(planListViewModelProvider, (_, _) {});
      container.read(planListViewModelProvider.notifier).toggleEditing();

      mounted.close();
      await container.pump();

      final remounted = container.read(planListViewModelProvider);
      expect(remounted.value?.editing, isFalse);
      expect(remounted.value?.plans, isNotEmpty);
    });

    test('a projection failing after it had a value is an AsyncError', () {
      final container = buildContainerWithFailingProjection(
        buildLedger([soonerPlan]),
      );
      expect(container.read(planListViewModelProvider).hasValue, isTrue);

      (container.read(
        planListProjectionProvider.notifier,
      ) as FailingProjectionNotifier).fail();

      expect(container.read(planListViewModelProvider).hasError, isTrue);
    });

    test('a ledger change keeps editing and the pending step', () {
      final ledger = buildLedger([soonerPlan, laterPlan]);
      final container = buildContainer(ledger);
      final viewModel = container.read(planListViewModelProvider.notifier);
      viewModel.toggleEditing();
      viewModel.requestEditPlan(soonerPlan);

      ledger.deletePlan(laterPlan.id);

      final state = container.read(planListViewModelProvider).value;
      expect(state?.editing, isTrue);
      expect(state?.step, isA<PlanFormRequested>());
    });

    test('toggleEditing flips editing on and off', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.toggleEditing();
      expect(container.read(planListViewModelProvider).value?.editing, isTrue);

      viewModel.toggleEditing();
      expect(container.read(planListViewModelProvider).value?.editing, isFalse);
    });

    test('requestEditPlan emits PlanFormRequested carrying the plan', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestEditPlan(soonerPlan);

      final step = container.read(planListViewModelProvider).value?.step;
      expect(step, isA<PlanFormRequested>());
      expect((step as PlanFormRequested).plan.id, soonerPlan.id);
    });

    test('deletePlan removes the plan without emitting a step', () async {
      final ledger = buildLedger([soonerPlan]);
      final container = buildContainer(ledger);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.deletePlan(soonerPlan.id);

      expect(ledger.state.plans.containsKey(soonerPlan.id), isFalse);
      expect(container.read(planListViewModelProvider).value?.step, isNull);
    });

    test(
      'requestDeletePlan emits DeleteConfirmationRequested without deleting',
      () async {
        final ledger = buildLedger([soonerPlan]);
        final container = buildContainer(ledger);
        final viewModel = container.read(planListViewModelProvider.notifier);

        viewModel.requestDeletePlan(soonerPlan.id);

        final step = container.read(planListViewModelProvider).value?.step;
        expect(step, isA<DeleteConfirmationRequested>());
        expect((step as DeleteConfirmationRequested).plan.id, soonerPlan.id);
        expect(ledger.state.plans.containsKey(soonerPlan.id), isTrue);
      },
    );

    test('applyDeleteConfirmed(true) deletes the requested plan', () async {
      final ledger = buildLedger([soonerPlan]);
      final container = buildContainer(ledger);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestDeletePlan(soonerPlan.id);
      viewModel.applyDeleteConfirmed(true);

      expect(ledger.state.plans.containsKey(soonerPlan.id), isFalse);
    });

    test('applyDeleteConfirmed(false) leaves the plan in place', () async {
      final ledger = buildLedger([soonerPlan]);
      final container = buildContainer(ledger);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestDeletePlan(soonerPlan.id);
      viewModel.applyDeleteConfirmed(false);

      expect(ledger.state.plans.containsKey(soonerPlan.id), isTrue);
    });

    test('clearStep resets the step to null', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestEditPlan(soonerPlan);
      expect(container.read(planListViewModelProvider).value?.step, isNotNull);

      viewModel.clearStep();
      expect(container.read(planListViewModelProvider).value?.step, isNull);
    });
  });
}

class FailingProjectionNotifier extends PlanListProjectionNotifier {
  void fail() {
    state = AsyncError<PlanListProjection>(
      StateError('projection failed'),
      StackTrace.empty,
    );
  }
}
