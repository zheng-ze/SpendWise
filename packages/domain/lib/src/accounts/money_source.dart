import 'package:domain/src/accounts/account.dart';
import 'package:domain/src/accounts/sub_pocket.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

/// Gives accounts and pockets one table and one id space in LedgerState.
@immutable
sealed class MoneySource {
  const MoneySource();

  const factory MoneySource.account(Account account) = AccountSource;

  const factory MoneySource.pocket(SubPocket pocket) = PocketSource;

  String get id;
  String get name;
  bool get incomingTransfersAsExpenses;
  LifecycleState get lifecycle;

  Account? get asAccount => switch (this) {
    AccountSource(:final account) => account,
    PocketSource() => null,
  };

  SubPocket? get asPocket => switch (this) {
    AccountSource() => null,
    PocketSource(:final pocket) => pocket,
  };

  MoneySource settingLifecycle(LifecycleState lifecycle);
}

final class AccountSource extends MoneySource {
  const AccountSource(this.account);

  final Account account;

  @override
  String get id => account.id;

  @override
  String get name => account.name;

  @override
  bool get incomingTransfersAsExpenses => account.incomingTransfersAsExpenses;

  @override
  LifecycleState get lifecycle => account.lifecycle;

  @override
  MoneySource settingLifecycle(LifecycleState lifecycle) {
    return AccountSource(account.settingLifecycle(lifecycle));
  }

  @override
  bool operator ==(Object other) =>
      other is AccountSource && other.account == account;

  @override
  int get hashCode => account.hashCode;
}

final class PocketSource extends MoneySource {
  const PocketSource(this.pocket);

  final SubPocket pocket;

  @override
  String get id => pocket.id;

  @override
  String get name => pocket.name;

  @override
  bool get incomingTransfersAsExpenses => pocket.incomingTransfersAsExpenses;

  @override
  LifecycleState get lifecycle => pocket.lifecycle;

  @override
  MoneySource settingLifecycle(LifecycleState lifecycle) {
    return PocketSource(pocket.settingLifecycle(lifecycle));
  }

  @override
  bool operator ==(Object other) =>
      other is PocketSource && other.pocket == pocket;

  @override
  int get hashCode => pocket.hashCode;
}
