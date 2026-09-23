import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';

sealed class AccountsStep {}

class AccountFormRequested extends AccountsStep {}

class SourceEditRequested extends AccountsStep {
  SourceEditRequested(this.holderId);

  final String holderId;
}

class PickParentRequested extends AccountsStep {}

class AccountFormSaved extends AccountsStep {}

class SourceEditFormSaved extends AccountsStep {}

class AccountOpened extends AccountsStep {
  AccountOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

class AccountAloneOpened extends AccountsStep {
  AccountAloneOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

class PocketOpened extends AccountsStep {
  PocketOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

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

class AccountsNotifier extends AsyncNotifier<AccountsViewState>
    with
        LedgerBackedNotifier<AccountsViewState>,
        StepEmitting<AccountsViewState, AccountsStep>
    implements AccountsViewModel {
  @override
  Future<AccountsViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(currentLedger, expandedAccountId: null);
  }

  void _onLedgerChanged() {
    final current = state.value;
    state = AsyncData(
      _buildState(ledger, expandedAccountId: current?.expandedAccountId),
    );
  }

  AccountsViewState _buildState(
    Ledger ledger, {
    required String? expandedAccountId,
    AccountsStep? step,
  }) {
    final ledgerState = ledger.state;
    return AccountsViewState(
      sections: accountSections(ledgerState, now: DateTime.now()),
      netWorth: Accounting.netWorth(ledgerState),
      expandedAccountId: expandedAccountId,
      step: step,
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
    final current = state.value;
    ledger.deleteAccount(id);
    if (current == null) return;
    if (current.expandedAccountId == id) {
      state = AsyncData(
        _buildState(ledger, expandedAccountId: null, step: current.step),
      );
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

final accountsViewModelProvider =
    AsyncNotifierProvider<AccountsNotifier, AccountsViewState>(
      AccountsNotifier.new,
    );
