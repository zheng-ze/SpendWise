import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';

export 'package:spendwise/ui/accounts/accounts_steps.dart';

// MARK: - AccountsViewState
class AccountsViewState implements HasStep<AccountsViewState, AccountsStep> {
  const AccountsViewState({
    required this.sections,
    required this.netWorth,
    required this.expandedAccountId,
    this.step,
  });

  final List<AccountSection> sections;
  final NetWorth netWorth;
  final String? expandedAccountId;
  @override
  final AccountsStep? step;

  AccountsViewState copyWith({
    List<AccountSection>? sections,
    NetWorth? netWorth,
    String? Function()? expandedAccountId,
    AccountsStep? Function()? step,
  }) {
    return AccountsViewState(
      sections: sections ?? this.sections,
      netWorth: netWorth ?? this.netWorth,
      expandedAccountId: expandedAccountId == null
          ? this.expandedAccountId
          : expandedAccountId(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  AccountsViewState withStep(AccountsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - AccountsViewModel
abstract class AccountsViewModel {
  void toggleExpanded(String accountId);
  Future<void> deleteAccount(String id);
  Future<void> deletePocket(String id);
  void openAccount(String id);
  void openAccountAlone(String id);
  void openPocket(String id);
  void requestNewAccount();

  void requestSourceEdit(String holderId);
  void clearStep();
}

// MARK: - AccountsNotifier
class AccountsNotifier extends AsyncNotifier<AccountsViewState>
    with
        LedgerBackedNotifier<AccountsViewState>,
        StepEmitting<AccountsViewState, AccountsStep>
    implements AccountsViewModel {
  @override
  AccountsViewState build() {
    final currentLedger = ledger;
    final today = ref.watch(todayProvider);
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _viewState(currentLedger, today, state.value);
  }

  void _onLedgerChanged() {
    if (!ref.mounted) return;
    state = AsyncData(_viewState(ledger, ref.read(todayProvider), state.value));
  }

  AccountsViewState _viewState(
    Ledger ledger,
    DateTime today,
    AccountsViewState? current,
  ) {
    final ledgerState = ledger.state;
    return AccountsViewState(
      sections: accountSections(ledgerState, now: today),
      netWorth: Accounting.netWorth(ledgerState),
      expandedAccountId: current?.expandedAccountId,
      step: current?.step,
    );
  }

  AccountRow? _findRow(String accountId) {
    for (final section in state.value?.sections ?? const <AccountSection>[]) {
      for (final row in section.rows) {
        if (row.id == accountId) return row;
      }
    }
    return null;
  }

  @override
  void toggleExpanded(String accountId) {
    final current = state.value;
    if (current == null) return;
    final next = current.expandedAccountId == accountId ? null : accountId;
    state = AsyncData(current.copyWith(expandedAccountId: () => next));
  }

  @override
  Future<void> deleteAccount(String id) async {
    ledger.deleteAccount(id);
    final current = state.value;
    if (current != null && current.expandedAccountId == id) {
      state = AsyncData(current.copyWith(expandedAccountId: () => null));
    }
  }

  @override
  Future<void> deletePocket(String id) async {
    ledger.deletePocket(id);
  }

  @override
  void openAccount(String id) {
    final row = _findRow(id);
    if (row == null) return;
    emitStep(
      AccountOpened(row.name, {row.id, for (final p in row.pockets) p.id}),
    );
  }

  @override
  void openAccountAlone(String id) {
    final row = _findRow(id);
    if (row == null) return;
    emitStep(AccountAloneOpened(row.name, {row.id}));
  }

  @override
  void openPocket(String id) {
    for (final section in state.value?.sections ?? const <AccountSection>[]) {
      for (final row in section.rows) {
        for (final pocket in row.pockets) {
          if (pocket.id == id) {
            emitStep(PocketOpened(pocket.name, {pocket.id}));
            return;
          }
        }
      }
    }
  }

  @override
  void requestNewAccount() => emitStep(AccountFormRequested());

  @override
  void requestSourceEdit(String holderId) =>
      emitStep(SourceEditRequested(holderId));
}

// MARK: - Constants
final accountsViewModelProvider =
    AsyncNotifierProvider.autoDispose<AccountsNotifier, AccountsViewState>(
      AccountsNotifier.new,
      retry: (_, _) => null,
    );
