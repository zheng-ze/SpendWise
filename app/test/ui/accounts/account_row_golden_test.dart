import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';

void main() {
  testWidgets('account row layout, plain total and the card two-column form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final plainRow = AccountRow(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Main Checking',
      amount: SingleTotal(_dec('-120.50')),
      ownBalance: _dec('-120.50'),
      pockets: const [],
    );

    final rowWithPockets = AccountRow(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Wallet',
      amount: SingleTotal(_dec('300')),
      ownBalance: _dec('250'),
      pockets: [
        PocketRow(
          id: 'a0000000-0000-0000-0000-000000000003',
          name: 'Rent',
          balance: _dec('50'),
        ),
      ],
    );

    final cardRow = AccountRow(
      id: 'a0000000-0000-0000-0000-000000000004',
      name: 'Visa',
      amount: CardAmounts(payable: _dec('80'), outstanding: _dec('45')),
      ownBalance: _dec('-80'),
      pockets: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AccountRowTile(
                row: plainRow,
                expanded: false,
                onToggleExpanded: null,
                onTap: () {},
                confirmDeleteAccount: () async => false,
                onAccountDeleted: () {},
                onOpenAccountAlone: () {},
                onOpenPocket: (_) {},
                confirmDeletePocket: (_) async => false,
                onPocketDeleted: (_) {},
              ),
              AccountRowTile(
                row: rowWithPockets,
                expanded: true,
                onToggleExpanded: () {},
                onTap: () {},
                confirmDeleteAccount: () async => false,
                onAccountDeleted: () {},
                onOpenAccountAlone: () {},
                onOpenPocket: (_) {},
                confirmDeletePocket: (_) async => false,
                onPocketDeleted: (_) {},
              ),
              AccountRowTile(
                row: cardRow,
                expanded: false,
                onToggleExpanded: null,
                onTap: () {},
                confirmDeleteAccount: () async => false,
                onAccountDeleted: () {},
                onOpenAccountAlone: () {},
                onOpenPocket: (_) {},
                confirmDeletePocket: (_) async => false,
                onPocketDeleted: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/account_row.png'),
    );
  });
}

Decimal _dec(String value) => Decimal.parse(value);
