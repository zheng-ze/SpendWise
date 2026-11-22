import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';

import '../../../support/category_form_launcher.dart';
import '../../../support/ui_test_timeout.dart';

const _insideLabel = 'Inside';
const _pickerTitle = 'Inside which category?';
const _barrierTap = Offset(160, 10);

TransactionCategory _root(String name) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

Future<void> _openForm(WidgetTester tester, Ledger ledger) async {
  await openCategoryFormSheet(tester, ledger);
}

Future<void> _pickParentRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text(_insideLabel));
  await tester.pumpAndSettle();
}

void main() {
  final food = _root('Food');
  final travel = _root('Travel');
  final ledger = Ledger(
    state: LedgerState(categories: {food.id: food, travel.id: travel}),
  );

  group('CategoryForm parent picker', () {
    testWidgets('Top level clears the chosen parent', (tester) async {
      await _openForm(tester, ledger);
      await _openPicker(tester);
      await _pickParentRow(tester, food.name);

      await _openPicker(tester);
      await _pickParentRow(tester, topLevelLabel);

      expect(find.text(topLevelLabel), findsOneWidget);
      expect(find.text(food.name), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('dismissing the picker keeps the chosen parent', (
      tester,
    ) async {
      await _openForm(tester, ledger);
      await _openPicker(tester);
      await _pickParentRow(tester, food.name);

      await _openPicker(tester);
      await tester.tapAt(_barrierTap);
      await tester.pumpAndSettle();

      expect(find.text(_pickerTitle), findsNothing);
      expect(find.text(food.name), findsOneWidget);
    }, timeout: uiTestTimeout);
  });
}
