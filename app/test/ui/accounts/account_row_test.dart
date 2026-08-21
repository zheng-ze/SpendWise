import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';

import '../../support/semantics_test_support.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final plainRow = AccountRow(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    amount: SingleTotal(dec('-120.50')),
    ownBalance: dec('-120.50'),
    pockets: const [],
  );

  final rowWithPocket = AccountRow(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Wallet',
    amount: SingleTotal(dec('300')),
    ownBalance: dec('250'),
    pockets: [
      PocketRow(
        id: 'a0000000-0000-0000-0000-000000000003',
        name: 'Rent',
        balance: dec('50'),
      ),
    ],
  );

  testWidgets(
    'the delete-account custom semantic action confirms then deletes, same '
    'as the swipe',
    (tester) async {
      final handle = tester.ensureSemantics();
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountRowTile(
              row: plainRow,
              expanded: false,
              onToggleExpanded: null,
              onTap: () {},
              onAccountDeleted: () => deleted = true,
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) {},
            ),
          ),
        ),
      );

      await performCustomSemanticsAction(
        tester,
        of: find.text('Main Checking'),
        label: 'Delete Main Checking',
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Main Checking?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      handle.dispose();
    },
  );

  testWidgets(
    'the delete-account custom semantic action does not delete when the '
    'confirm is declined',
    (tester) async {
      final handle = tester.ensureSemantics();
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountRowTile(
              row: plainRow,
              expanded: false,
              onToggleExpanded: null,
              onTap: () {},
              onAccountDeleted: () => deleted = true,
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) {},
            ),
          ),
        ),
      );

      await performCustomSemanticsAction(
        tester,
        of: find.text('Main Checking'),
        label: 'Delete Main Checking',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleted, isFalse);
      handle.dispose();
    },
  );

  testWidgets(
    'the delete-pocket custom semantic action confirms then deletes, same '
    'as the swipe',
    (tester) async {
      final handle = tester.ensureSemantics();
      var deletedPocket = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountRowTile(
              row: rowWithPocket,
              expanded: true,
              onToggleExpanded: () {},
              onTap: () {},
              onAccountDeleted: () {},
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) => deletedPocket = true,
            ),
          ),
        ),
      );

      await performCustomSemanticsAction(
        tester,
        of: find.text('Rent'),
        label: 'Delete Rent',
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Rent?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedPocket, isTrue);
      handle.dispose();
    },
  );
}
