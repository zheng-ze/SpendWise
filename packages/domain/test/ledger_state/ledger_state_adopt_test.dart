import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

LedgerState _fiveTableState() {
  final state = LedgerState();
  state.addAccount(account(uuid(1), name: 'wallet'));
  state.addPocket(pocket(uuid(2), name: 'jar'), uuid(1));
  state.addCategory(category(uuid(3), name: 'food'));
  state.addEntry(entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(3)));
  state.addPlan(
    RecurringPlan(
      id: uuid(5),
      template: EntryTemplate(
        amount: Decimal.fromInt(-100),
        name: 'rent',
        sourceID: uuid(1),
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 10),
      lastResolvedDate: DateTime.utc(2026, 1, 10),
    ),
  );
  state.addBudget(null, Decimal.fromInt(100), now: DateTime.utc(2026, 1, 15));
  return state;
}

void expectSameTables(LedgerState actual, LedgerState expected) {
  expect(actual.moneySources, expected.moneySources);
  expect(actual.entries, expected.entries);
  expect(actual.categories, expected.categories);
  expect(actual.plans, expected.plans);
  expect(actual.budgets, expected.budgets);
}

void main() {
  test('adopt keeps the live object and refills all five tables', () {
    final live = LedgerState();
    live.addAccount(account(uuid(9), name: 'stale'));
    final source = _fiveTableState();
    final ref = live;

    live.adopt(source);

    // No swap: an earlier holder of the live object sees the adopted tables.
    expect(identical(ref, live), isTrue);
    expectSameTables(ref, source);
    expect(ref.moneySources[uuid(9)], isNull);
  });

  test('adopting an empty state clears every live table', () {
    final live = _fiveTableState();

    live.adopt(LedgerState());

    expect(live.moneySources, isEmpty);
    expect(live.entries, isEmpty);
    expect(live.categories, isEmpty);
    expect(live.plans, isEmpty);
    expect(live.budgets, isEmpty);
  });

  test('selfAdoptionIsANoOp', () {
    final state = _fiveTableState();
    final moneySources = Map<String, MoneySource>.of(state.moneySources);
    final entries = Map<String, Entry>.of(state.entries);
    final categories = Map<String, TransactionCategory>.of(state.categories);
    final plans = Map<String, RecurringPlan>.of(state.plans);
    final budgets = Map<String, Budget>.of(state.budgets);

    state.adopt(state);

    expect(state.moneySources, moneySources);
    expect(state.entries, entries);
    expect(state.categories, categories);
    expect(state.plans, plans);
    expect(state.budgets, budgets);
  });

  test('unseen lifecycle transition passes structural validation', () {
    // The device archived then stopped referencing the account, so its
    // baseline sits at referenceOnly. Another device restored it to active:
    // a transition the mutator clause 12 baseline never observed, but a
    // structurally sound row.
    final live = LedgerState();
    live.addAccount(account(uuid(1), name: 'wallet'));
    live.addEntry(entry(id: uuid(2), sourceID: uuid(1)));
    live.deleteAccount(uuid(1));
    live.purgeAccount(uuid(1));
    expect(live.moneySources[uuid(1)]?.lifecycle, LifecycleState.referenceOnly);

    final candidate = LedgerState(
      moneySources: live.moneySources,
      entries: live.entries,
      categories: live.categories,
      plans: live.plans,
      budgets: live.budgets,
    );
    candidate.apply([UpsertAccount(account(uuid(1), name: 'wallet'))]);

    expect(candidate.assertInvariants, returnsNormally);
    live.adopt(candidate);
    expect(live.moneySources[uuid(1)]?.lifecycle, LifecycleState.active);
  });

  test('invalid candidate fails with assertions disabled', () async {
    final probe = File('test/ledger_state/sync_apply_probe.dart');
    expect(probe.existsSync(), isTrue, reason: 'probe script is missing');

    final result = await Process.run(Platform.resolvedExecutable, <String>[
      '--no-enable-asserts',
      probe.absolute.path,
    ]);

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(result.stdout, contains('PROBE_PASS'));
  });
}
