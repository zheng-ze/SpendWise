import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';

void main() {
  Account account(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
    Set<String> subPocketIDs = const {},
  }) => Account(
    id: id,
    name: name,
    type: AccountType.checking,
    lifecycle: lifecycle,
    subPocketIDs: subPocketIDs,
  );

  SubPocket pocket(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => SubPocket(id: id, name: name, lifecycle: lifecycle);

  TransactionCategory category(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => TransactionCategory(
    id: id,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  Ledger buildLedger({
    Map<String, MoneySource> moneySources = const {},
    Map<String, TransactionCategory> categories = const {},
  }) {
    return Ledger(
      state: LedgerState(moneySources: moneySources, categories: categories),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    container.listen(recycleBinViewModelProvider, (previous, next) {});
    return container;
  }

  ProviderContainer buildContainerWithFailingProjection(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        recycleBinProjectionProvider.overrideWith(
          FailingProjectionNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(recycleBinViewModelProvider, (previous, next) {});
    return container;
  }

  test('restore(account) reactivates the account', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.account, acc.id);

    expect(ledger.state.moneySources[acc.id]!.lifecycle, LifecycleState.active);
  });

  test('restore(pocket) is a no-op while the parent account is still '
      'archived', () {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.pocket, pkt.id);

    expect(
      ledger.state.moneySources[pkt.id]!.lifecycle,
      LifecycleState.archived,
    );
  });

  test('restore(category) reactivates the category', () {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.restore(BinRowKind.category, cat.id);

    expect(ledger.state.categories[cat.id]!.lifecycle, LifecycleState.active);
  });

  test('requestPurge emits PurgeConfirmationRequested carrying the row', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;

    viewModel.requestPurge(row);

    final step = container.read(recycleBinViewModelProvider).value?.step;
    expect(step, isA<PurgeConfirmationRequested>());
    expect((step as PurgeConfirmationRequested).row.id, acc.id);
    expect(step.row.name, 'Old Bank');
  });

  test('applyPurgeConfirmed(true) purges the account and clears the step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    viewModel.applyPurgeConfirmed(true, row.kind, row.id);

    expect(ledger.state.moneySources.containsKey(acc.id), isFalse);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('applyPurgeConfirmed(false) leaves the row untouched and clears the '
      'step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    viewModel.applyPurgeConfirmed(false, row.kind, row.id);

    expect(ledger.state.moneySources.containsKey(acc.id), isTrue);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('applyPurgeConfirmed(true) purges a pocket', () {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      lifecycle: LifecycleState.active,
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.pocket, pkt.id);

    expect(ledger.state.moneySources.containsKey(pkt.id), isFalse);
  });

  test('applyPurgeConfirmed(true) purges a category', () {
    final cat = category('a0000000-0000-0000-0000-000000000004', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);

    viewModel.applyPurgeConfirmed(true, BinRowKind.category, cat.id);

    expect(ledger.state.categories.containsKey(cat.id), isFalse);
  });

  test('clearStep resets the step to null', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;

    viewModel.requestPurge(row);
    expect(container.read(recycleBinViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('the first read with a ready projection is AsyncData', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(
          buildLedger(moneySources: {acc.id: MoneySource.account(acc)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(recycleBinProjectionProvider);

    final first = container.read(recycleBinViewModelProvider);

    expect(first, isA<AsyncData<RecycleBinViewState>>());
  });

  test('an unmounted view model drops its pending step', () async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(
          buildLedger(moneySources: {acc.id: MoneySource.account(acc)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final mounted = container.listen(recycleBinViewModelProvider, (_, _) {});
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    container.read(recycleBinViewModelProvider.notifier).requestPurge(row);

    mounted.close();
    await container.pump();

    expect(container.read(recycleBinViewModelProvider).value?.step, isNull);
  });

  test('a projection failing after it had a value is an AsyncError', () {
    final container = buildContainerWithFailingProjection(buildLedger());
    expect(container.read(recycleBinViewModelProvider).hasValue, isTrue);

    (container.read(
      recycleBinProjectionProvider.notifier,
    ) as FailingProjectionNotifier).fail();

    expect(container.read(recycleBinViewModelProvider).hasError, isTrue);
  });

  test('a ledger change keeps the pending step', () {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    final container = buildContainer(ledger);
    final viewModel = container.read(recycleBinViewModelProvider.notifier);
    final row = container
        .read(recycleBinViewModelProvider)
        .value!
        .accounts
        .single;
    viewModel.requestPurge(row);

    ledger.restoreAccount(acc.id);

    final state = container.read(recycleBinViewModelProvider).value;
    expect(state?.accounts, isEmpty);
    expect(state?.step, isA<PurgeConfirmationRequested>());
  });
}

class FailingProjectionNotifier extends RecycleBinProjectionNotifier {
  void fail() {
    state = AsyncError<RecycleBinProjection>(
      StateError('projection failed'),
      StackTrace.empty,
    );
  }
}
