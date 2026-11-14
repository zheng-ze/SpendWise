import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';

import '../../../support/category_form_launcher.dart';
import '../../../support/ui_test_timeout.dart';

const _sectionLabel = 'SUBCATEGORIES';
const _addLabel = 'Add subcategory';

TransactionCategory _category(
  String name, {
  String? parentID,
  LifecycleState lifecycle = LifecycleState.active,
}) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: parentID,
  symbol: 'tag',
  lifecycle: lifecycle,
);

Ledger _ledgerOf(List<TransactionCategory> categories) => Ledger(
  state: LedgerState(categories: {for (final c in categories) c.id: c}),
);

void main() {
  testWidgets('the edit category form lists its active subcategories', (
    tester,
  ) async {
    final root = _category('Food');
    final cafes = _category('Cafes', parentID: root.id);
    final binned = _category(
      'Takeaway',
      parentID: root.id,
      lifecycle: LifecycleState.archived,
    );
    final ledger = _ledgerOf([root, cafes, binned]);

    await openCategoryFormSheet(tester, ledger, category: root);

    expect(find.text(_sectionLabel), findsOneWidget);
    expect(find.text('Cafes'), findsOneWidget);
    expect(find.text('Takeaway'), findsNothing);
    expect(find.text(_addLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a category without subcategories still offers Add', (
    tester,
  ) async {
    final root = _category('Food');

    await openCategoryFormSheet(tester, _ledgerOf([root]), category: root);

    expect(find.text(_sectionLabel), findsOneWidget);
    expect(find.text(_addLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the add category form has no Subcategories section', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    expect(find.text(_sectionLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('the edit subcategory form has no Subcategories section', (
    tester,
  ) async {
    final root = _category('Food');
    final cafes = _category('Cafes', parentID: root.id);

    await openCategoryFormSheet(
      tester,
      _ledgerOf([root, cafes]),
      category: cafes,
    );

    expect(find.text(_sectionLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('the add subcategory form has no Subcategories section', (
    tester,
  ) async {
    final root = _category('Food');

    await openCategoryFormSheet(
      tester,
      _ledgerOf([root]),
      presetParentID: root.id,
    );

    expect(find.text(_sectionLabel), findsNothing);
  }, timeout: uiTestTimeout);
}
