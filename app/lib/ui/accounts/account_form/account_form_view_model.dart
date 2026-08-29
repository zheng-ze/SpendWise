import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';

class AccountFormViewState
    implements HasStep<AccountFormViewState, AccountsStep> {
  const AccountFormViewState({
    required this.kind,
    required this.name,
    required this.type,
    required this.statementDay,
    required this.parentId,
    required this.balanceText,
    required this.pocketableParents,
    this.error,
    this.step,
  });

  final AccountFormKind kind;
  final String name;
  final AccountType type;
  final int? statementDay;
  final String? parentId;
  final String balanceText;
  final List<Account> pocketableParents;
  final LedgerError? error;
  @override
  final AccountsStep? step;

  bool get isLockedToAccount => pocketableParents.isEmpty;

  AccountFormKind get effectiveKind =>
      isLockedToAccount ? AccountFormKind.account : kind;

  bool get canSave =>
      canSaveAccountForm(kind: effectiveKind, name: name, parentId: parentId);

  AccountFormViewState copyWith({
    AccountFormKind? kind,
    String? name,
    AccountType? type,
    int? Function()? statementDay,
    String? Function()? parentId,
    String? balanceText,
    List<Account>? pocketableParents,
    LedgerError? Function()? error,
    AccountsStep? Function()? step,
  }) {
    return AccountFormViewState(
      kind: kind ?? this.kind,
      name: name ?? this.name,
      type: type ?? this.type,
      statementDay: statementDay == null ? this.statementDay : statementDay(),
      parentId: parentId == null ? this.parentId : parentId(),
      balanceText: balanceText ?? this.balanceText,
      pocketableParents: pocketableParents ?? this.pocketableParents,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  AccountFormViewState withStep(AccountsStep? Function() step) =>
      copyWith(step: step);
}

abstract class AccountFormViewModel {
  void setKind(AccountFormKind kind);
  void setName(String name);
  void setType(AccountType type);
  void setStatementDay(int day);
  void requestPickParent();
  void applyPickedParent(String? id);
  void setBalance(String raw);
  Future<void> save();
  void clearStep();
}

class AccountFormNotifier extends AsyncNotifier<AccountFormViewState>
    with
        LedgerBackedNotifier<AccountFormViewState>,
        StepEmitting<AccountFormViewState, AccountsStep>
    implements AccountFormViewModel {
  @override
  Future<AccountFormViewState> build() async {
    return AccountFormViewState(
      kind: AccountFormKind.account,
      name: '',
      type: AccountType.cash,
      statementDay: null,
      parentId: null,
      balanceText: '',
      pocketableParents: pocketableParents(ledger.state),
    );
  }

  @override
  void setKind(AccountFormKind kind) {
    updateState(
      (s) => s.copyWith(
        kind: kind,
        parentId: kind == AccountFormKind.account ? () => null : null,
      ),
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
      ),
    );
  }

  @override
  void setStatementDay(int day) =>
      updateState((s) => s.copyWith(statementDay: () => day));

  @override
  void requestPickParent() => emitStep(PickParentRequested());

  // A picker outcome can arrive after the sheet that opened it was
  // dismissed, so this must no-op rather than update a gone provider.
  @override
  void applyPickedParent(String? id) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(parentId: () => id, step: () => null));
  }

  @override
  void setBalance(String raw) =>
      updateState((s) => s.copyWith(balanceText: raw));

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;

    // Recomputed rather than trusting the stored kind, since the picked
    // parent may have gone stale between opening the picker and saving.
    final effectiveKind = current.effectiveKind;
    final name = current.name.trim();

    try {
      if (effectiveKind == AccountFormKind.subpocket) {
        final parentId = current.parentId;
        if (parentId == null) return;
        ledger.addPocket(SubPocket(name: name), parentId);
      } else {
        final isCard = current.type == AccountType.card;
        final account = Account(
          name: name,
          type: current.type,
          statementDay: isCard ? current.statementDay : null,
        );
        ledger.addAccount(account);

        final balance = parseAmountInput(current.balanceText);
        if (balance != null && balance != Decimal.zero) {
          ledger.setOpeningBalance(balance, account.id);
        }
      }
      updateState(
        (s) => s.copyWith(error: () => null, step: () => AccountFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

final accountFormViewModelProvider =
    AsyncNotifierProvider<AccountFormNotifier, AccountFormViewState>(
      AccountFormNotifier.new,
    );
