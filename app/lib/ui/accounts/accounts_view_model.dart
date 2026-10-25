import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.selectedDetail,
    this.step,
  });

  final List<AccountSection> sections;
  final NetWorth netWorth;
  final String? expandedAccountId;
  final AccountDetail? selectedDetail;
  @override
  final AccountsStep? step;

  AccountsViewState copyWith({
    List<AccountSection>? sections,
    NetWorth? netWorth,
    String? Function()? expandedAccountId,
    AccountDetail? Function()? selectedDetail,
    AccountsStep? Function()? step,
  }) {
    return AccountsViewState(
      sections: sections ?? this.sections,
      netWorth: netWorth ?? this.netWorth,
      expandedAccountId: expandedAccountId == null
          ? this.expandedAccountId
          : expandedAccountId(),
      selectedDetail: selectedDetail == null
          ? this.selectedDetail
          : selectedDetail(),
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
  void selectDetail(String id);
  void clearSelectedDetail();
  void toggleAccountPockets(String accountId);
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
  Future<AccountsViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(
      currentLedger,
      expandedAccountId: null,
      selectedDetailId: null,
    );
  }

  void _onLedgerChanged() {
    final current = state.value;
    state = AsyncData(
      _buildState(
        ledger,
        expandedAccountId: current?.expandedAccountId,
        selectedDetailId:
            current?.selectedDetail?.pocket?.id ??
            current?.selectedDetail?.account.id,
        step: current?.step,
      ),
    );
  }

  AccountsViewState _buildState(
    Ledger ledger, {
    required String? expandedAccountId,
    required String? selectedDetailId,
    AccountsStep? step,
  }) {
    final ledgerState = ledger.state;
    final sections = accountSections(ledgerState, now: DateTime.now());
    return AccountsViewState(
      sections: sections,
      netWorth: Accounting.netWorth(ledgerState),
      expandedAccountId: expandedAccountId,
      selectedDetail: _findDetail(sections, selectedDetailId),
      step: step,
    );
  }

  AccountDetail? _findDetail(List<AccountSection> sections, String? id) {
    if (id == null) return null;
    for (final section in sections) {
      for (final account in section.rows) {
        if (account.id == id) {
          return AccountDetail(account: account, type: section.type);
        }
        for (final pocket in account.pockets) {
          if (pocket.id == id) {
            return AccountDetail(
              account: account,
              type: section.type,
              pocket: pocket,
            );
          }
        }
      }
    }
    return null;
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
  void toggleAccountPockets(String accountId) => toggleExpanded(accountId);

  @override
  void selectDetail(String id) {
    final current = state.value;
    if (current == null) return;
    final detail = _findDetail(current.sections, id);
    if (detail == null) return;
    state = AsyncData(
      current.copyWith(
        selectedDetail: () => detail,
        step: () => AccountDetailRequested(),
      ),
    );
  }

  @override
  void clearSelectedDetail() {
    final current = state.value;
    if (current == null || current.selectedDetail == null) return;
    state = AsyncData(current.copyWith(selectedDetail: () => null));
  }

  @override
  Future<void> deleteAccount(String id) async {
    final current = state.value;
    ledger.deleteAccount(id);
    if (current == null) return;
    if (current.expandedAccountId == id) {
      state = AsyncData(
        _buildState(
          ledger,
          expandedAccountId: null,
          selectedDetailId: current.selectedDetail?.account.id,
          step: current.step,
        ),
      );
    }
  }

  @override
  Future<void> deletePocket(String id) async {
    ledger.deletePocket(id);
    final current = state.value;
    if (current?.selectedDetail?.pocket?.id == id) clearSelectedDetail();
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
    AsyncNotifierProvider<AccountsNotifier, AccountsViewState>(
      AccountsNotifier.new,
    );
