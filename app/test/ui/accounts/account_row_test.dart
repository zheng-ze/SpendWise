import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';

import '../../support/semantics_test_support.dart';
import '../../support/ui_test_timeout.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final plainRow = AccountRow(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
    amount: SingleTotal(dec('-120.50')),
    totalBalance: dec('-120.50'),
    ownBalance: dec('-120.50'),
    pockets: const [],
  );

  final rowWithPocket = AccountRow(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Wallet',
    type: AccountType.cash,
    amount: SingleTotal(dec('300')),
    totalBalance: dec('300'),
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
              onAccountEdit: () {},
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) {},
              onPocketEdit: (_) {},
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
    timeout: uiTestTimeout,
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
              onAccountEdit: () {},
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) {},
              onPocketEdit: (_) {},
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
    timeout: uiTestTimeout,
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
              onAccountEdit: () {},
              onOpenAccountAlone: () {},
              onOpenPocket: (_) {},
              onPocketDeleted: (_) => deletedPocket = true,
              onPocketEdit: (_) {},
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
    timeout: uiTestTimeout,
  );

  testWidgets('row and pocket amounts render bare without the symbol', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountRowTile(
            row: rowWithPocket,
            expanded: true,
            onToggleExpanded: () {},
            onTap: () {},
            onAccountDeleted: () {},
            onAccountEdit: () {},
            onOpenAccountAlone: () {},
            onOpenPocket: (_) {},
            onPocketDeleted: (_) {},
            onPocketEdit: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('300.00'), findsOneWidget);
    expect(find.text('S\$300.00'), findsNothing);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('S\$50.00'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('account Edit semantic action invokes edit without dismissing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountRowTile(
            row: plainRow,
            expanded: false,
            onToggleExpanded: null,
            onTap: () {},
            onAccountDeleted: () {},
            onAccountEdit: () => edited = true,
            onOpenAccountAlone: () {},
            onOpenPocket: (_) {},
            onPocketDeleted: (_) {},
            onPocketEdit: (_) {},
          ),
        ),
      ),
    );

    await performCustomSemanticsAction(
      tester,
      of: find.text('Main Checking'),
      label: 'Edit Main Checking',
    );
    await tester.pumpAndSettle();

    expect(edited, isTrue);
    expect(find.text('Main Checking'), findsOneWidget);
    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.horizontal);
    semantics.dispose();
  }, timeout: uiTestTimeout);

  testWidgets('pocket Edit semantic action targets that pocket', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    PocketRow? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountRowTile(
            row: rowWithPocket,
            expanded: true,
            onToggleExpanded: () {},
            onTap: () {},
            onAccountDeleted: () {},
            onAccountEdit: () {},
            onOpenAccountAlone: () {},
            onOpenPocket: (_) {},
            onPocketDeleted: (_) {},
            onPocketEdit: (pocket) => edited = pocket,
          ),
        ),
      ),
    );

    await performCustomSemanticsAction(
      tester,
      of: find.text('Rent'),
      label: 'Edit Rent',
    );

    expect(edited?.id, rowWithPocket.pockets.single.id);
    expect(find.text('Rent'), findsOneWidget);
    semantics.dispose();
  }, timeout: uiTestTimeout);

  for (final testCase in [
    (
      label: 'LTR rightward',
      direction: TextDirection.ltr,
      offset: const Offset(500, 0),
    ),
    (
      label: 'RTL leftward',
      direction: TextDirection.rtl,
      offset: const Offset(-500, 0),
    ),
  ]) {
    testWidgets('${testCase.label} swipe edits the account and keeps its row', (
      tester,
    ) async {
      var edited = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: testCase.direction,
            child: Scaffold(
              body: AccountRowTile(
                row: plainRow,
                expanded: false,
                onToggleExpanded: null,
                onTap: () {},
                onAccountDeleted: () {},
                onAccountEdit: () => edited = true,
                onOpenAccountAlone: () {},
                onOpenPocket: (_) {},
                onPocketDeleted: (_) {},
                onPocketEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Main Checking'), testCase.offset);
      await tester.pumpAndSettle();

      expect(edited, isTrue);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('Delete Main Checking?'), findsNothing);
    }, timeout: uiTestTimeout);
  }

  testWidgets('Delete-only SwipeRow retains end-to-start deletion', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeRow(
            itemKey: const ValueKey('delete-only'),
            itemName: 'Plain row',
            onDeleted: () => deleted = true,
            child: const Text('Plain row'),
          ),
        ),
      ),
    );

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.endToStart);
    expect(dismissible.secondaryBackground, isNull);

    await tester.drag(find.text('Plain row'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete Plain row?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  }, timeout: uiTestTimeout);
}
