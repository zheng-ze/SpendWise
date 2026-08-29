import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit_form_logic.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';

class SourceEditFormViewState
    implements HasStep<SourceEditFormViewState, AccountsStep> {
  const SourceEditFormViewState({
    required this.holderID,
    required this.isAccount,
    required this.name,
    required this.type,
    required this.statementDay,
    required this.balanceText,
    required this.incomingTransfersAsExpenses,
    required this.includeInNetWorth,
    required this.showsTransferToggle,
    required this.currentBalance,
    this.error,
    this.step,
  });

  final String holderID;
  final bool isAccount;
  final String name;
  final AccountType type;
  final int? statementDay;
  final String balanceText;
  final bool incomingTransfersAsExpenses;
  final bool includeInNetWorth;
  final bool showsTransferToggle;
  final Decimal currentBalance;
  final LedgerError? error;
  @override
  final AccountsStep? step;

  Decimal? get parsedBalance => parseAmountInput(balanceText);

  bool get canSave => canSaveSourceEditForm(name: name, balance: parsedBalance);

  SourceEditFormViewState copyWith({
    String? name,
    AccountType? type,
    int? Function()? statementDay,
    String? balanceText,
    bool? incomingTransfersAsExpenses,
    bool? includeInNetWorth,
    bool? showsTransferToggle,
    LedgerError? Function()? error,
    AccountsStep? Function()? step,
  }) {
    return SourceEditFormViewState(
      holderID: holderID,
      isAccount: isAccount,
      name: name ?? this.name,
      type: type ?? this.type,
      statementDay: statementDay == null ? this.statementDay : statementDay(),
      balanceText: balanceText ?? this.balanceText,
      incomingTransfersAsExpenses:
          incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      showsTransferToggle: showsTransferToggle ?? this.showsTransferToggle,
      currentBalance: currentBalance,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  SourceEditFormViewState withStep(AccountsStep? Function() step) =>
      copyWith(step: step);
}

abstract class SourceEditFormViewModel {
  void setName(String name);
  void setType(AccountType type);
  void setStatementDay(int day);
  void setBalance(String raw);
  void setIncomingTransfersAsExpenses(bool value);
  void setIncludeInNetWorth(bool value);
  Future<void> save();
  void clearStep();
}

class SourceEditFormNotifier extends AsyncNotifier<SourceEditFormViewState>
    with
        LedgerBackedNotifier<SourceEditFormViewState>,
        StepEmitting<SourceEditFormViewState, AccountsStep>
    implements SourceEditFormViewModel {
  SourceEditFormNotifier(this._holderID);

  final String _holderID;

  Decimal _currentBalance(Ledger ledger) {
    final ledgerState = ledger.state;
    return Accounting.balance(
      of: _holderID,
      entries: ledgerState.entries.values.toList(),
      sourceIDs: ledgerState.moneySources.keys.toSet(),
    );
  }

  @override
  Future<SourceEditFormViewState> build() async {
    final source = ledger.state.moneySources[_holderID];
    final account = source?.asAccount;
    final pocket = account == null ? source?.asPocket : null;

    final eligibleType =
        account?.type ?? ledger.state.owningAccount(_holderID)?.type;

    return SourceEditFormViewState(
      holderID: _holderID,
      isAccount: account != null,
      name: account?.name ?? pocket?.name ?? '',
      type: account?.type ?? AccountType.cash,
      statementDay: account?.statementDay,
      balanceText: formatPlainAmount(_currentBalance(ledger)),
      incomingTransfersAsExpenses:
          account?.incomingTransfersAsExpenses ??
          pocket?.incomingTransfersAsExpenses ??
          false,
      includeInNetWorth: account?.includeInNetWorth ?? true,
      showsTransferToggle: eligibleType?.allowsTransfersAsExpense ?? false,
      currentBalance: _currentBalance(ledger),
    );
  }

  @override
  void setName(String name) => updateState((s) => s.copyWith(name: name));

  @override
  void setType(AccountType type) {
    updateState(
      (s) => s.copyWith(
        type: type,
        statementDay: type != AccountType.card ? () => null : null,
        showsTransferToggle: type.allowsTransfersAsExpense,
        incomingTransfersAsExpenses: type.allowsTransfersAsExpense
            ? s.incomingTransfersAsExpenses
            : false,
      ),
    );
  }

  @override
  void setStatementDay(int day) =>
      updateState((s) => s.copyWith(statementDay: () => day));

  @override
  void setBalance(String raw) =>
      updateState((s) => s.copyWith(balanceText: raw));

  @override
  void setIncomingTransfersAsExpenses(bool value) =>
      updateState((s) => s.copyWith(incomingTransfersAsExpenses: value));

  @override
  void setIncludeInNetWorth(bool value) =>
      updateState((s) => s.copyWith(includeInNetWorth: value));

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;
    final source = ledger.state.moneySources[_holderID];
    final account = source?.asAccount;
    final pocket = account == null ? source?.asPocket : null;

    final name = current.name.trim();
    final enteredBalance = current.parsedBalance ?? Decimal.zero;

    try {
      if (account != null) {
        ledger.updateAccount(
          Account(
            id: account.id,
            name: name,
            type: current.type,
            statementDay: current.type == AccountType.card
                ? current.statementDay
                : null,
            incomingTransfersAsExpenses: current.incomingTransfersAsExpenses,
            includeInNetWorth: current.includeInNetWorth,
            lifecycle: account.lifecycle,
          ),
        );
      } else if (pocket != null) {
        ledger.updatePocket(
          SubPocket(
            id: pocket.id,
            name: name,
            incomingTransfersAsExpenses: current.incomingTransfersAsExpenses,
            lifecycle: pocket.lifecycle,
          ),
        );
      }

      final adjustment = balanceAdjustmentEntry(
        enteredBalance: enteredBalance,
        currentBalance: current.currentBalance,
        holderID: _holderID,
      );
      if (adjustment != null) ledger.addEntry(adjustment);

      updateState(
        (s) => s.copyWith(error: () => null, step: () => SourceEditFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

final sourceEditFormViewModelProvider =
    AsyncNotifierProvider.family<
      SourceEditFormNotifier,
      SourceEditFormViewState,
      String
    >(SourceEditFormNotifier.new);
