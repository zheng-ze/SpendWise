import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/source_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';

void main() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
  );
  final archivedAccount = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Closed',
    type: AccountType.checking,
    lifecycle: LifecycleState.archived,
  );
  final travelPocket = SubPocket(
    id: 'p0000000-0000-0000-0000-000000000001',
    name: 'Travel',
  );
  final binnedPocket = SubPocket(
    id: 'p0000000-0000-0000-0000-000000000002',
    name: 'Binned',
    lifecycle: LifecycleState.archived,
  );

  LedgerState state() => LedgerState(
    moneySources: {
      checking.id: MoneySource.account(
        checking.addSubPocket(travelPocket.id).addSubPocket(binnedPocket.id),
      ),
      savings.id: MoneySource.account(savings),
      archivedAccount.id: MoneySource.account(archivedAccount),
      travelPocket.id: MoneySource.pocket(travelPocket),
      binnedPocket.id: MoneySource.pocket(binnedPocket),
    },
  );

  late Future<PickerOutcome?> pendingOutcome;

  Future<void> openSheet(WidgetTester tester, {String? selectedId}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                pendingOutcome = showSourcePickerSheet(
                  context: context,
                  title: 'Account',
                  state: state(),
                  selectedId: selectedId,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows only active accounts as parent rows', (tester) async {
    await openSheet(tester);

    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
  });

  testWidgets('offers no None button', (tester) async {
    await openSheet(tester);

    expect(find.text('None'), findsNothing);
  });

  testWidgets('expanding an account shows only its active pockets', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Binned'), findsNothing);
  });

  testWidgets('a second tap on the expanded account selects the account', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, checking.id);
  });

  testWidgets('a childless account selects on the first tap', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, savings.id);
  });

  testWidgets('tapping a pocket selects that pocket', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, travelPocket.id);
  });
}
