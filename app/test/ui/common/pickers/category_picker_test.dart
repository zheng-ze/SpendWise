import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/category_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';

void main() {
  final food = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final groceries = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Groceries',
    kind: CategoryKind.expense,
    colorHex: '#00FF00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'shopping_cart',
  );
  final coffee = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000003',
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#00FF00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'coffee',
  );
  final bills = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000004',
    name: 'Bills',
    kind: CategoryKind.expense,
    colorHex: '#0000FF',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'receipt',
  );
  final salary = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000005',
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#FFFF00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'work',
  );
  final binnedExpense = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000006',
    name: 'Retired',
    kind: CategoryKind.expense,
    colorHex: '#FFFFFF',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'archive',
    lifecycle: LifecycleState.archived,
  );

  LedgerState state() => LedgerState(
    categories: {
      for (final category in [
        food,
        groceries,
        coffee,
        bills,
        salary,
        binnedExpense,
      ])
        category.id: category,
    },
  );

  late Future<PickerOutcome?> pendingOutcome;

  Future<void> openSheet(
    WidgetTester tester, {
    CategoryKind kind = CategoryKind.expense,
    String? selectedId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                pendingOutcome = showCategoryPickerSheet(
                  context: context,
                  state: state(),
                  kind: kind,
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

  testWidgets('shows only parents of the requested kind', (tester) async {
    await openSheet(tester, kind: CategoryKind.expense);

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Retired'), findsNothing);
  });

  testWidgets('orders parents alphabetically', (tester) async {
    await openSheet(tester, kind: CategoryKind.expense);

    final billsCenter = tester.getCenter(find.text('Bills'));
    final foodCenter = tester.getCenter(find.text('Food'));
    expect(billsCenter.dy, lessThan(foodCenter.dy));
  });

  testWidgets('orders children alphabetically under the expanded parent', (
    tester,
  ) async {
    await openSheet(tester, kind: CategoryKind.expense);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    final coffeeCenter = tester.getCenter(find.text('Coffee'));
    final groceriesCenter = tester.getCenter(find.text('Groceries'));
    expect(coffeeCenter.dy, lessThan(groceriesCenter.dy));
  });

  testWidgets('offers a None option', (tester) async {
    await openSheet(tester);

    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('tapping None clears the selection', (tester) async {
    await openSheet(tester, selectedId: groceries.id);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerCleared>());
  });

  testWidgets('a childless parent selects on the first tap', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, bills.id);
  });

  testWidgets('a second tap on the expanded parent selects the parent', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, food.id);
  });

  testWidgets('tapping a child selects that child', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    final result = await pendingOutcome;
    expect(result, isA<PickerChose>());
    expect((result as PickerChose).id, groceries.id);
  });
}
