import 'package:domain/domain.dart';

// MARK: - AccountFields
abstract interface class AccountFields {
  String get name;
  AccountType get type;
  int? get statementDay;
  String get balanceText;
}

// MARK: - AccountFieldsState
abstract interface class AccountFieldsState<T> implements AccountFields {
  T withFields({
    String? name,
    AccountType? type,
    int? Function()? statementDay,
    String? balanceText,
  });

  T withError(LedgerError? Function() error);
}

// MARK: - AccountFieldsActions
abstract interface class AccountFieldsActions {
  void setName(String name);
  void setType(AccountType type);
  void setStatementDay(int day);
  void setBalance(String raw);
}

// MARK: - AccountFieldsEditing
mixin AccountFieldsEditing<T extends AccountFieldsState<T>>
    implements AccountFieldsActions {
  void updateState(T Function(T current) apply);

  @override
  void setName(String name) => updateState((s) => s.withFields(name: name));

  @override
  void setType(AccountType type) {
    updateState(
      (s) => s.withFields(
        type: type,
        statementDay: type != AccountType.card ? () => null : null,
      ),
    );
  }

  @override
  void setStatementDay(int day) =>
      updateState((s) => s.withFields(statementDay: () => day));

  @override
  void setBalance(String raw) =>
      updateState((s) => s.withFields(balanceText: raw));

  void recordError(LedgerError error) =>
      updateState((s) => s.withError(() => error));
}
