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

  RecurringPlan plan({
    required String name,
    required RecurrenceFrequency frequency,
    required DateTime anchor,
    DateTime? endDate,
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
      lastResolvedDate: anchor.subtract(const Duration(days: 1)),
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

  ProviderContainer buildContainer(Ledger ledger, {DateTime Function()? now}) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        if (now != null) clockProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(planListViewModelProvider, (previous, next) {});
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

    test('two plans sharing the same next occurrence tiebreak by name', () {
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

    test('plans sort by ascending next occurrence', () {
      final clockToday = DateTime.utc(2026, 1, 1);
      final sooner = plan(
        name: 'Bravo',
        frequency: RecurrenceFrequency.weekly,
        anchor: clockToday,
      );
      final later = plan(
        name: 'Alpha',
        frequency: RecurrenceFrequency.yearly,
        anchor: DateTime.utc(2026, 6, 1),
      );
      final container = buildContainer(
        buildLedger([later, sooner]),
        now: () => clockToday,
      );

      final state = container.read(planListViewModelProvider).value;

      expect(state?.plans.map((p) => p.id), [sooner.id, later.id]);
    });

    test('a plan due today keeps today as its next occurrence', () {
      final clockToday = DateTime.utc(2026, 1, 1);
      final dueToday = plan(
        name: 'Zulu',
        frequency: RecurrenceFrequency.monthly,
        anchor: clockToday,
      );
      final dueLater = plan(
        name: 'Alpha',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 15),
      );
      final container = buildContainer(
        buildLedger([dueLater, dueToday]),
        now: () => clockToday,
      );

      final state = container.read(planListViewModelProvider).value;

      expect(state?.plans.first.id, dueToday.id);
      expect(state?.nextOccurrences[dueToday.id], clockToday);
      expect(state?.nextOccurrences[dueLater.id], DateTime.utc(2026, 1, 15));
    });

    test('a ledger change refreshes the plans', () {
      final ledger = buildLedger([soonerPlan, laterPlan]);
      final container = buildContainer(ledger);

      ledger.deletePlan(laterPlan.id);

      final state = container.read(planListViewModelProvider).value;
      expect(state?.plans.map((p) => p.id), [soonerPlan.id]);
    });

    test('advancing today refreshes the next-occurrence order', () {
      var now = DateTime.utc(2026, 1, 1);
      final early = plan(
        name: 'Early',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 5),
      );
      final late = plan(
        name: 'Late',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 20),
      );
      final container = buildContainer(
        buildLedger([early, late]),
        now: () => now,
      );
      final before = container.read(planListViewModelProvider).value;

      now = DateTime.utc(2026, 1, 10);
      container.invalidate(todayProvider);

      final after = container.read(planListViewModelProvider).value;
      expect(before?.plans.map((p) => p.id), [early.id, late.id]);
      expect(after?.plans.map((p) => p.id), [late.id, early.id]);
    });

    test('an unmounted view model stops listening to the ledger', () async {
      final ledger = ListenerTrackingLedger(buildLedger([soonerPlan]).state);
      final container = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
      );
      addTearDown(container.dispose);
      final mounted = container.listen(planListViewModelProvider, (_, _) {});
      expect(ledger.isListened, isTrue);

      mounted.close();
      await container.pump();

      expect(ledger.isListened, isFalse);
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

class ListenerTrackingLedger extends Ledger {
  ListenerTrackingLedger(LedgerState state) : super(state: state);

  bool get isListened => hasListeners;
}
