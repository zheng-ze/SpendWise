import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category_form.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    Ledger ledger, {
    TransactionCategory? category,
    String? presetParentID,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: MaterialApp(
          home: Scaffold(
            body: CategoryForm(
              category: category,
              presetParentID: presetParentID,
            ),
          ),
        ),
      ),
    );
    // Flushes CategoryFormNotifier.build()'s Future so the form's initial
    // AsyncData state is in place before a test interacts with it.
    await tester.pump();
  }

  TransactionCategory category({
    String? id,
    required String name,
    CategoryKind kind = CategoryKind.expense,
    String? parentID,
  }) => TransactionCategory(
    id: id,
    name: name,
    kind: kind,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: parentID,
    symbol: 'tag',
  );

  testWidgets('saving a new category adds it to the ledger', (tester) async {
    final ledger = Ledger();
    await pumpForm(tester, ledger);

    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.categories.values, hasLength(1));
    expect(ledger.state.categories.values.single.name, 'Groceries');
  });

  testWidgets('kind is locked when a parent is preset', (tester) async {
    final parent = category(name: 'Food');
    final ledger = Ledger(state: LedgerState(categories: {parent.id: parent}));
    await pumpForm(tester, ledger, presetParentID: parent.id);

    final segmented = tester.widget<SegmentedButton<CategoryKind>>(
      find.byType(SegmentedButton<CategoryKind>),
    );
    expect(segmented.onSelectionChanged, isNull);
    expect(find.text('New Subcategory'), findsOneWidget);
  });

  testWidgets('editing shows the delete button', (tester) async {
    final existing = category(name: 'Food');
    final ledger = Ledger(
      state: LedgerState(categories: {existing.id: existing}),
    );
    await pumpForm(tester, ledger, category: existing);

    expect(find.text('Delete Category'), findsOneWidget);
    expect(find.text('Edit Category'), findsOneWidget);
  });

  testWidgets('deleting a category asks for confirmation, then removes it', (
    tester,
  ) async {
    final existing = category(name: 'Food');
    final ledger = Ledger(
      state: LedgerState(categories: {existing.id: existing}),
    );
    await pumpForm(tester, ledger, category: existing);

    await tester.tap(find.text('Delete Category'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Food?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.categories[existing.id]?.lifecycle,
      LifecycleState.archived,
    );
  });

  testWidgets('backing out of the delete confirmation keeps the category', (
    tester,
  ) async {
    final existing = category(name: 'Food');
    final ledger = Ledger(
      state: LedgerState(categories: {existing.id: existing}),
    );
    await pumpForm(tester, ledger, category: existing);

    await tester.tap(find.text('Delete Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(ledger.state.categories, hasLength(1));
  });

  testWidgets('picking a parent updates the parent label', (tester) async {
    final parent = category(name: 'Food');
    final ledger = Ledger(state: LedgerState(categories: {parent.id: parent}));
    await pumpForm(tester, ledger);

    expect(find.text('Parent'), findsOneWidget);

    await tester.tap(find.text('Parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
  });
}
