import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_fields.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';

// MARK: - AccountFormViewState
class AccountFormViewState
    implements
        HasStep<AccountFormViewState, AccountsStep>,
        AccountFieldsState<AccountFormViewState> {
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
  @override
  final String name;
  @override
  final AccountType type;
  @override
  final int? statementDay;
  final String? parentId;
  @override
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

  @override
  AccountFormViewState withFields({
    String? name,
    AccountType? type,
    int? Function()? statementDay,
    String? balanceText,
  }) => copyWith(
    name: name,
    type: type,
    statementDay: statementDay,
    balanceText: balanceText,
  );

  @override
  AccountFormViewState withError(LedgerError? Function() error) =>
      copyWith(error: error);
}

// MARK: - AccountFormViewModel
abstract class AccountFormViewModel implements AccountFieldsActions {
  void setKind(AccountFormKind kind);
  void requestPickParent();
  void applyPickedParent(String? id);
  Future<void> save();
  void clearStep();
}

// MARK: - AccountFormNotifier
class AccountFormNotifier extends AsyncNotifier<AccountFormViewState>
    with
        LedgerBackedNotifier<AccountFormViewState>,
        StepEmitting<AccountFormViewState, AccountsStep>,
        AccountFieldsEditing<AccountFormViewState>
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
  void requestPickParent() => emitStep(PickParentRequested());

  @override
  void applyPickedParent(String? id) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(parentId: () => id, step: () => null));
  }

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;

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
      recordError(error);
    }
  }
}

// MARK: - Constants
final accountFormViewModelProvider =
    AsyncNotifierProvider<AccountFormNotifier, AccountFormViewState>(
      AccountFormNotifier.new,
    );
