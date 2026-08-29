import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan_list_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan plan({
    required String name,
    required RecurrenceFrequency frequency,
    required DateTime anchor,
    DateTime? endDate,
    DateTime? lastResolvedDate,
  }) {
    return RecurringPlan(
      template: EntryTemplate(
        amount: dec('-10'),
        name: name,
        sourceID: source.id,
      ),
      frequency: frequency,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate:
          lastResolvedDate ?? anchor.subtract(const Duration(days: 1)),
    );
  }

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
    return container;
  }

  group('sortedPlans', () {
    final now = DateTime.utc(2026, 1, 1);

    test('ended plans sort after every plan with a next occurrence', () {
      final ended = plan(
        name: 'Zeta ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );
      final live = plan(
        name: 'Alpha live',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 3, 1),
      );

      final result = sortedPlans(
        [ended, live],
        buildLedger([ended, live]).state,
        now,
      );

      expect(result.map((p) => p.template.name), ['Alpha live', 'Zeta ended']);
    });

    test('two ended plans tiebreak by name', () {
      final b = plan(
        name: 'Bravo ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );
      final a = plan(
        name: 'Alpha ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );

      final result = sortedPlans([b, a], buildLedger([b, a]).state, now);

      expect(result.map((p) => p.template.name), [
        'Alpha ended',
        'Bravo ended',
      ]);
    });

    test('two plans sharing the same non-null next occurrence tiebreak by '
        'name (the strengthening over V1)', () {
      final anchor = DateTime.utc(2026, 2, 1);
      final b = plan(
        name: 'Bravo live',
        frequency: RecurrenceFrequency.monthly,
        anchor: anchor,
      );
      final a = plan(
        name: 'Alpha live',
        frequency: RecurrenceFrequency.monthly,
        anchor: anchor,
      );

      expect(
        a.nextOccurrence(onOrAfter: now),
        b.nextOccurrence(onOrAfter: now),
      );

      final result = sortedPlans([b, a], buildLedger([b, a]).state, now);

      expect(result.map((p) => p.template.name), ['Alpha live', 'Bravo live']);
    });

    test('a plan due sooner sorts before one due later', () {
      final later = plan(
        name: 'Later',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 6, 1),
      );
      final sooner = plan(
        name: 'Sooner',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 15),
      );

      final result = sortedPlans(
        [later, sooner],
        buildLedger([later, sooner]).state,
        now,
      );

      expect(result.map((p) => p.template.name), ['Sooner', 'Later']);
    });
  });

  group('PlanListNotifier', () {
    // Anchored today so the run stays valid regardless of the calendar date.
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

    test('build sorts plans by ascending next occurrence', () async {
      final ledger = buildLedger([laterPlan, soonerPlan]);
      final container = buildContainer(ledger);

      final state = await container.read(planListViewModelProvider.future);

      expect(state.plans.map((p) => p.id), [soonerPlan.id, laterPlan.id]);
      expect(state.editing, isFalse);
      expect(state.step, isNull);
    });

    test('toggleEditing flips editing on and off', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      await container.read(planListViewModelProvider.future);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.toggleEditing();
      expect(container.read(planListViewModelProvider).value?.editing, isTrue);

      viewModel.toggleEditing();
      expect(container.read(planListViewModelProvider).value?.editing, isFalse);
    });

    test('requestEditPlan emits PlanFormRequested carrying the plan', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      await container.read(planListViewModelProvider.future);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestEditPlan(soonerPlan);

      final step = container.read(planListViewModelProvider).value?.step;
      expect(step, isA<PlanFormRequested>());
      expect((step as PlanFormRequested).plan.id, soonerPlan.id);
    });

    test('deletePlan removes the plan without emitting a step', () async {
      final ledger = buildLedger([soonerPlan]);
      final container = buildContainer(ledger);
      await container.read(planListViewModelProvider.future);
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
        await container.read(planListViewModelProvider.future);
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
      await container.read(planListViewModelProvider.future);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestDeletePlan(soonerPlan.id);
      viewModel.applyDeleteConfirmed(true);

      expect(ledger.state.plans.containsKey(soonerPlan.id), isFalse);
    });

    test('applyDeleteConfirmed(false) leaves the plan in place', () async {
      final ledger = buildLedger([soonerPlan]);
      final container = buildContainer(ledger);
      await container.read(planListViewModelProvider.future);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestDeletePlan(soonerPlan.id);
      viewModel.applyDeleteConfirmed(false);

      expect(ledger.state.plans.containsKey(soonerPlan.id), isTrue);
    });

    test('clearStep resets the step to null', () async {
      final container = buildContainer(buildLedger([soonerPlan]));
      await container.read(planListViewModelProvider.future);
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.requestEditPlan(soonerPlan);
      expect(container.read(planListViewModelProvider).value?.step, isNotNull);

      viewModel.clearStep();
      expect(container.read(planListViewModelProvider).value?.step, isNull);
    });
  });
}
