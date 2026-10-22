import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const accountID = '11111111-1111-4111-8111-111111111111';
  const pocketID = '22222222-2222-4222-8222-222222222222';

  final account = Account(
    id: accountID,
    name: 'Checking',
    type: AccountType.cash,
  );
  final pocket = SubPocket(id: pocketID, name: 'Reserve');

  test('account and pocket sources expose their row values and variants', () {
    final accountSource = MoneySource.account(account);
    final pocketSource = MoneySource.pocket(pocket);

    expect(accountSource.id, accountID);
    expect(accountSource.name, 'Checking');
    expect(accountSource.asAccount, account);
    expect(accountSource.asPocket, isNull);
    expect(pocketSource.id, pocketID);
    expect(pocketSource.name, 'Reserve');
    expect(pocketSource.asAccount, isNull);
    expect(pocketSource.asPocket, pocket);
  });

  test('setting lifecycle returns sources with updated rows', () {
    final accountSource = MoneySource.account(account);
    final pocketSource = MoneySource.pocket(pocket);

    expect(
      accountSource.settingLifecycle(LifecycleState.archived).lifecycle,
      LifecycleState.archived,
    );
    expect(
      pocketSource.settingLifecycle(LifecycleState.archived).lifecycle,
      LifecycleState.archived,
    );
    expect(accountSource.lifecycle, LifecycleState.active);
    expect(pocketSource.lifecycle, LifecycleState.active);
  });
}
