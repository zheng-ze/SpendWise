import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/mappers/mappers.dart';
import 'package:sync/sync.dart';

void main() {
  final version = VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 3});
  const accountID = 'a1b2c3d4-1111-4111-8111-aaaaaaaaaaaa';

  group('account', () {
    test('accountRoundTrips', () {
      final account = Account(
        id: accountID,
        name: 'Everyday',
        type: AccountType.card,
        subPocketIDs: {'b1b2c3d4-2222-4222-8222-bbbbbbbbbbbb'},
        incomingTransfersAsExpenses: true,
        includeInNetWorth: false,
        statementDay: 12,
        lifecycle: LifecycleState.archived,
      );

      final row = accountToRow(account, version);
      expect(accountFromRow(row), account);
      expect(versionFromRow(row.versionData), version);
    });

    test('the account row stores the type code and the lifecycle code', () {
      final row = accountToRow(
        Account(
          id: accountID,
          name: 'Everyday',
          type: AccountType.insurance,
          lifecycle: LifecycleState.referenceOnly,
        ),
        version,
      );

      expect(row.type, 6);
      expect(row.lifecycle, 2);
    });
  });
}
