import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_view_model.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_steps.dart';

void main() {
  final today = DateTime.utc(2026, 3, 15);
  final anchor = DateTime.utc(2026, 1, 10);

  final wallet = Account(
    id: 'a0000000-0000-0000-0000-00000000000a',
    name: 'Wallet',
    type: AccountType.cash,
  );
  final savings = Account(
    id: 'b0000000-0000-0000-0000-00000000000b',
    name: 'Savings',
    type: AccountType.cash,
  );
  final food = TransactionCategory(
    id: 'c0000000-0000-0000-0000-00000000000c',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );

  RecurringPlan buildPlan({
    String amount = '-12.50',
    String? categoryID,
    String? destinationID,
    String sourceID = 'a0000000-0000-0000-0000-00000000000a',
    DateTime? endDate,
    DateTime? lastResolvedDate,
  }) {
    return RecurringPlan(
      template: EntryTemplate(
        amount: Decimal.parse(amount),
        name: 'Rent',
        categoryID: categoryID,
        sourceID: sourceID,
        destinationID: destinationID,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate:
          lastResolvedDate ?? anchor.subtract(const Duration(days: 1)),
    );
  }

  Ledger buildLedger(RecurringPlan? plan) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          wallet.id: MoneySource.account(wallet),
          savings.id: MoneySource.account(savings),
        },
        categories: {food.id: food},
        plans: {
          for (final p in [?plan]) p.id: p,
        },
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger, {DateTime? now}) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        clockProvider.overrideWithValue(() => now ?? today),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  PlanDetailViewState readDetail(RecurringPlan plan, {DateTime? now}) {
    final container = buildContainer(buildLedger(plan), now: now);
    final provider = planDetailViewModelProvider(plan.id);
    container.listen(provider, (_, _) {});
    return container.read(provider).requireValue;
  }

  group('PlanDetailNotifier fields', () {
    test('an expense plan fills every field', () {
      final plan = buildPlan(categoryID: food.id);

      final state = readDetail(plan);

      expect(state.phase, PlanDetailPhase.shown);
      expect(state.name, 'Rent');
      expect(state.amount, Decimal.parse('-12.50'));
      expect(state.kind, AmountKind.expense);
      expect(state.frequencyLabel, 'Every month');
      expect(state.next, formatEntryDate(DateTime.utc(2026, 4, 10)));
      expect(state.account, 'Wallet');
      expect(state.relationRow, (label: 'Category', value: 'Food'));
      expect(state.started, formatEntryDate(anchor));
    });

    test('a positive amount is income', () {
      final state = readDetail(buildPlan(amount: '100'));

      expect(state.amount, Decimal.parse('100'));
      expect(state.kind, AmountKind.income);
    });

    test('a plan without a category shows Uncategorized', () {
      final state = readDetail(buildPlan());

      expect(state.relationRow, (label: 'Category', value: 'Uncategorized'));
    });

    test('a deleted category falls back to Uncategorized', () {
      final state = readDetail(
        buildPlan(categoryID: 'd0000000-0000-0000-0000-00000000000d'),
      );

      expect(state.relationRow, (label: 'Category', value: 'Uncategorized'));
    });

    test('a transfer plan shows the destination in a To row', () {
      final plan = buildPlan(destinationID: savings.id, categoryID: food.id);

      final state = readDetail(plan);

      expect(state.relationRow, (label: 'To', value: 'Savings'));
      expect(state.kind, AmountKind.transfer);
    });

    test('an unknown source shows Unknown', () {
      final plan = buildPlan(sourceID: 'e0000000-0000-0000-0000-00000000000e');

      expect(readDetail(plan).account, 'Unknown');
    });
  });

  group('PlanDetailNotifier schedule fields', () {
    test('a plan without an end date ends Never', () {
      expect(readDetail(buildPlan()).ends, 'Never');
    });

    test('a plan with an end date shows it', () {
      final end = DateTime.utc(2026, 12, 1);

      expect(readDetail(buildPlan(endDate: end)).ends, formatEntryDate(end));
    });

    test('a plan past its end date shows Next as Ended', () {
      final plan = buildPlan(endDate: DateTime.utc(2026, 2, 1));

      expect(readDetail(plan).next, 'Ended');
    });

    test('a plan the cursor has not reached shows Last added Not yet', () {
      expect(readDetail(buildPlan()).lastAdded, 'Not yet');
    });

    test('a plan the cursor has covered shows its last added date', () {
      final plan = buildPlan(lastResolvedDate: DateTime.utc(2026, 3, 1));

      expect(
        readDetail(plan).lastAdded,
        formatEntryDate(DateTime.utc(2026, 2, 10)),
      );
    });

    test('advancing today refreshes Next', () {
      final plan = buildPlan();
      final first = readDetail(plan).next;
      final later = readDetail(plan, now: DateTime.utc(2026, 4, 11)).next;

      expect(first, formatEntryDate(DateTime.utc(2026, 4, 10)));
      expect(later, formatEntryDate(DateTime.utc(2026, 5, 10)));
    });
  });

  group('PlanDetailNotifier delete', () {
    final generated = Entry(
      date: DateTime.utc(2026, 2, 10),
      amount: Decimal.parse('-12.50'),
      name: 'Rent',
      sourceID: wallet.id,
    );

    test('requestEdit emits PlanEditRequested while the plan exists', () {
      final plan = buildPlan();
      final container = buildContainer(buildLedger(plan));
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});

      container.read(provider.notifier).requestEdit();

      expect(
        container.read(provider).requireValue.step,
        isA<PlanEditRequested>(),
      );
    });

    test('requestEdit emits nothing when the plan is missing', () {
      final container = buildContainer(buildLedger(null));
      final provider = planDetailViewModelProvider(
        'f0000000-0000-0000-0000-00000000000f',
      );
      container.listen(provider, (_, _) {});

      container.read(provider.notifier).requestEdit();

      expect(container.read(provider).requireValue.step, isNull);
    });

    test('requestDelete emits PlanDeleteRequested while the plan exists', () {
      final plan = buildPlan();
      final container = buildContainer(buildLedger(plan));
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});

      container.read(provider.notifier).requestDelete();

      expect(
        container.read(provider).requireValue.step,
        isA<PlanDeleteRequested>(),
      );
    });

    test('requestDelete emits nothing when the plan is missing', () {
      final container = buildContainer(buildLedger(null));
      final provider = planDetailViewModelProvider(
        'f0000000-0000-0000-0000-00000000000f',
      );
      container.listen(provider, (_, _) {});

      container.read(provider.notifier).requestDelete();

      expect(container.read(provider).requireValue.step, isNull);
    });

    test('clearStep removes the emitted step', () {
      final plan = buildPlan();
      final container = buildContainer(buildLedger(plan));
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});
      container.read(provider.notifier).requestDelete();

      container.read(provider.notifier).clearStep();

      expect(container.read(provider).requireValue.step, isNull);
    });

    test('deletePlan removes only the plan and keeps its entries', () {
      final plan = buildPlan();
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {wallet.id: MoneySource.account(wallet)},
          entries: {generated.id: generated},
          plans: {plan.id: plan},
        ),
      );
      final container = buildContainer(ledger);
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});

      container.read(provider.notifier).deletePlan();

      expect(ledger.state.plans, isEmpty);
      expect(ledger.state.entries.keys, [generated.id]);
    });

    test('deletePlan on a missing plan writes nothing', () {
      final ledger = buildLedger(null);
      final container = buildContainer(ledger);
      final provider = planDetailViewModelProvider(
        'f0000000-0000-0000-0000-00000000000f',
      );
      container.listen(provider, (_, _) {});
      final revision = ledger.revision;

      container.read(provider.notifier).deletePlan();

      expect(ledger.revision, revision);
    });
  });

  group('PlanDetailNotifier ledger changes', () {
    test('a plan missing from the ledger is deleted', () {
      final container = buildContainer(buildLedger(null));
      final provider = planDetailViewModelProvider(
        'f0000000-0000-0000-0000-00000000000f',
      );
      container.listen(provider, (_, _) {});

      expect(
        container.read(provider).requireValue.phase,
        PlanDetailPhase.deleted,
      );
    });

    test('removing the plan from the ledger moves the phase to deleted', () {
      final plan = buildPlan();
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});

      ledger.deletePlan(plan.id);

      expect(
        container.read(provider).requireValue.phase,
        PlanDetailPhase.deleted,
      );
    });

    test('a ledger change refreshes the shown fields', () {
      final plan = buildPlan();
      final ledger = buildLedger(plan);
      final container = buildContainer(ledger);
      final provider = planDetailViewModelProvider(plan.id);
      container.listen(provider, (_, _) {});

      ledger.updatePlan(plan.resolvedAt(DateTime.utc(2026, 3, 1)));

      final state = container.read(provider).requireValue;
      expect(state.phase, PlanDetailPhase.shown);
      expect(state.lastAdded, formatEntryDate(DateTime.utc(2026, 2, 10)));
    });

    test('an unmounted view model stops listening to the ledger', () async {
      final ledger = ListenerTrackingLedger(buildLedger(buildPlan()).state);
      final container = buildContainer(ledger);
      final provider = planDetailViewModelProvider('any');
      final mounted = container.listen(provider, (_, _) {});
      expect(ledger.isListened, isTrue);

      mounted.close();
      await container.pump();

      expect(ledger.isListened, isFalse);
    });
  });
}

class ListenerTrackingLedger extends Ledger {
  ListenerTrackingLedger(LedgerState state) : super(state: state);

  bool get isListened => hasListeners;
}
