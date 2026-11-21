import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/navigation/compact_labelled_fab.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';

import '../../../support/ledger_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _barrierTap = Offset(160, 10);
const _addSubcategoryTooltip = 'Add subcategory';
const _addSubcategoryTitle = 'Add subcategory';
const _launchLabel = 'Open categories';

class _ListLauncher extends StatelessWidget {
  const _ListLauncher();

  @override
  Widget build(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const CategoryListScreen(),
    );
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(route),
        child: const Text(_launchLabel),
      ),
    );
  }
}

final _addCategoryButton = find.byType(CompactLabelledFab);

TransactionCategory _category(
  String name, {
  CategoryKind kind = CategoryKind.expense,
  String? parentID,
  bool includeInAnalysis = true,
}) => testCategory(
  name: name,
  kind: kind,
  colorHex: '#FF0000',
  includeInAnalysis: includeInAnalysis,
  parentID: parentID,
);

Ledger _ledgerOf(List<TransactionCategory> categories) => Ledger(
  state: LedgerState(categories: {for (final c in categories) c.id: c}),
);

Future<void> _pumpList(WidgetTester tester, List<TransactionCategory> all) =>
    pumpApp(tester, const CategoryListScreen(), ledger: _ledgerOf(all));

void main() {
  testWidgets(
    'a second open request while the form is open does not stack a second form',
    (tester) async {
      await pumpApp(tester, const CategoryListScreen(), ledger: Ledger());
      await tester.tap(_addCategoryButton);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryForm), findsOneWidget);

      final scope = tester.element(find.byType(CategoryListScreen));
      ProviderScope.containerOf(scope)
          .read(categoryListViewModelProvider.notifier)
          .requestNewCategory();
      await tester.pumpAndSettle();

      expect(find.byType(CategoryForm), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('the form opens again after it was dismissed', (tester) async {
    await pumpApp(tester, const CategoryListScreen(), ledger: Ledger());
    await tester.tap(_addCategoryButton);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryForm), findsOneWidget);

    await tester.tapAt(_barrierTap);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryForm), findsNothing);

    await tester.tap(_addCategoryButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a root shows its subcategory count as meta', (tester) async {
    final dining = _category('Dining');
    final groceries = _category('Groceries');
    final all = [
      dining,
      _category('Cafes', parentID: dining.id),
      _category('Takeaway', parentID: dining.id),
      groceries,
      _category('Supermarket', parentID: groceries.id),
      _category('Transport'),
    ];

    await _pumpList(tester, all);

    expect(find.text('2 subcategories'), findsOneWidget);
    expect(find.text('1 subcategory'), findsOneWidget);
    expect(find.textContaining('0 subcategor'), findsNothing);
  }, timeout: uiTestTimeout);

  test('the subcategory meta is absent for zero, singular for one', () {
    expect(categorySubcategoriesMeta(0), isNull);
    expect(categorySubcategoriesMeta(1), '1 subcategory');
    expect(categorySubcategoriesMeta(3), '3 subcategories');
  });

  testWidgets('the excluded-from-analysis badge shows only when excluded', (
    tester,
  ) async {
    await _pumpList(tester, [
      _category('Dining'),
      _category('Gifts', includeInAnalysis: false),
    ]);

    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('only root rows offer add subcategory', (tester) async {
    final dining = _category('Dining');

    await _pumpList(tester, [dining, _category('Cafes', parentID: dining.id)]);

    expect(find.byTooltip(_addSubcategoryTooltip), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('add subcategory opens the form with the parent preset', (
    tester,
  ) async {
    await _pumpList(tester, [_category('Dining')]);

    await tester.tap(find.byTooltip(_addSubcategoryTooltip));
    await tester.pumpAndSettle();

    expect(find.text(_addSubcategoryTitle), findsOneWidget);
    expect(find.text('Dining'), findsWidgets);
  }, timeout: uiTestTimeout);

  testWidgets('tapping a row opens the edit form for that category', (
    tester,
  ) async {
    await _pumpList(tester, [_category('Dining')]);

    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();

    expect(find.text('Edit category'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the floating Add category button opens the add form', (
    tester,
  ) async {
    await _pumpList(tester, [_category('Dining')]);

    await tester.tap(_addCategoryButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'the header shows the title and a Settings back control that pops',
    (tester) async {
      await pumpApp(tester, const _ListLauncher(), ledger: Ledger());
      await tester.tap(find.text(_launchLabel));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryListScreen), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );
}
