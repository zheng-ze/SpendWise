import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';

import '../../../support/category_form_launcher.dart';
import '../../../support/ui_test_timeout.dart';

const _sectionLabel = 'SUBCATEGORIES';
const _addLabel = 'Add subcategory';
const _editSubTitle = 'Edit subcategory';
const _editTitle = 'Edit category';
const _draftName = 'Food and drink';
const _newSubName = 'Bakery';
const _saveLabel = 'Save';
const _barrierTap = Offset(160, 10);

final _parentNameField = find.byType(TextField).first;
final _childNameField = find.byType(TextField).last;
final _childSave = find.widgetWithText(TextButton, _saveLabel).last;

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

  testWidgets(
    'tapping a subcategory opens its form and keeps the parent draft',
    (tester) async {
      final root = _category('Food');
      final cafes = _category('Cafes', parentID: root.id);
      await openCategoryFormSheet(
        tester,
        _ledgerOf([root, cafes]),
        category: root,
      );
      await tester.enterText(_parentNameField, _draftName);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cafes'));
      await tester.pumpAndSettle();

      expect(find.text(_editSubTitle), findsOneWidget);

      await tester.tapAt(_barrierTap);
      await tester.pumpAndSettle();

      expect(find.text(_editSubTitle), findsNothing);
      expect(find.text(_editTitle), findsOneWidget);
      expect(find.byType(CategoryForm), findsOneWidget);
      expect(find.text(_draftName), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Add subcategory opens the add form inside this category', (
    tester,
  ) async {
    final root = _category('Food');
    final ledger = _ledgerOf([root]);
    await openCategoryFormSheet(tester, ledger, category: root);

    await tester.tap(find.text(_addLabel));
    await tester.pumpAndSettle();
    await tester.enterText(_childNameField, _newSubName);
    await tester.pumpAndSettle();
    await tester.tap(_childSave);
    await tester.pumpAndSettle();

    final added = ledger.state.categories.values.singleWhere(
      (category) => category.name == _newSubName,
    );
    expect(added.parentID, root.id);
  }, timeout: uiTestTimeout);

  testWidgets(
    'a saved subcategory appears in the parent list and draft stays',
    (tester) async {
      final root = _category('Food');
      await openCategoryFormSheet(tester, _ledgerOf([root]), category: root);
      await tester.enterText(_parentNameField, _draftName);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_addLabel));
      await tester.pumpAndSettle();
      await tester.enterText(_childNameField, _newSubName);
      await tester.pumpAndSettle();
      await tester.tap(_childSave);
      await tester.pumpAndSettle();

      expect(find.text(_newSubName), findsOneWidget);
      expect(find.text(_draftName), findsOneWidget);
      expect(find.text(_editTitle), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'removing the parent form also closes its open subcategory sheet',
    (tester) async {
      final root = _category('Food');
      final cafes = _category('Cafes', parentID: root.id);
      await openCategoryFormSheet(
        tester,
        _ledgerOf([root, cafes]),
        category: root,
      );
      await tester.tap(find.text('Cafes'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryForm), findsNWidgets(2));

      final parentContext = tester.element(find.byType(CategoryForm).first);
      final parentRoute = ModalRoute.of(parentContext)!;
      parentRoute.navigator!.removeRoute(parentRoute);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryForm), findsNothing);
    },
    timeout: uiTestTimeout,
  );
}
