import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

import '../../../support/category_form_launcher.dart';
import '../../../support/ui_test_timeout.dart';

const _typedName = 'Groceries';
const _saveLabel = 'Save';
const _retryLabel = 'Try again';
const _loadErrorMessage =
    "Couldn't load this category\nBad state: Data unavailable";
const _saveErrorTitle = 'Could not save category';
const _addFooterLabel = 'Save category';
const _moveToBinLabel = 'Move to recycle bin';
const _moveConfirmLabel = 'Move';
const _parentPickerTitle = 'Inside which category?';
const _insideLabel = 'Inside';
const _moreOptionsLabel = 'More options';
const _closedSubtitle = 'Count in Trends and budgets';
const _typeLabel = 'Type';
const _typeCaption = 'The type is fixed once entries use this category.';
const _subcategoryCountHint = 'Include this subcategory in totals';
const _symbolRowLabel = 'Icon and colour';
const _chosenSymbol = 'restaurant';
const _chosenSymbolName = 'Restaurant';
const _initialSymbolName = 'Tag';
const _chosenColor = Color(0xFF34C759);
const _barrierTap = Offset(160, 10);

final _nameField = find.descendant(
  of: find.byType(CategoryForm),
  matching: find.byType(TextField),
);
final _saveButton = find.widgetWithText(TextButton, _saveLabel);

class _FlakyCategoryFormNotifier extends CategoryFormNotifier {
  _FlakyCategoryFormNotifier(super.args, this._shouldFail);

  final bool Function() _shouldFail;

  @override
  Future<CategoryFormViewState> build() {
    if (_shouldFail()) throw StateError('Data unavailable');
    return super.build();
  }
}

TransactionCategory _root(String name) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

TransactionCategory _child(String name, String parentID) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: parentID,
  symbol: 'tag',
);

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(_saveButton).onPressed != null;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_nameField, text);
  await tester.pumpAndSettle();
}

Future<void> _chooseSymbolAndColor(WidgetTester tester) async {
  await tester.tap(find.text(_symbolRowLabel));
  await tester.pumpAndSettle();
  final symbolTile = find.byKey(const ValueKey(_chosenSymbol));
  await tester.ensureVisible(symbolTile);
  await tester.tap(symbolTile);
  final swatch = find.byKey(const ValueKey(_chosenColor));
  await tester.ensureVisible(swatch);
  await tester.tap(swatch);
  await tester.pumpAndSettle();
}

Future<void> _openMoreOptions(WidgetTester tester) async {
  await tester.tap(find.text(_moreOptionsLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save is disabled for a blank name and enabled once typed', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    expect(_saveEnabled(tester), isFalse);

    await _type(tester, _typedName);

    expect(_saveEnabled(tester), isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('saving a valid form closes the sheet', (tester) async {
    final ledger = Ledger();
    await openCategoryFormSheet(tester, ledger);
    await _type(tester, _typedName);

    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsNothing);
    expect(
      ledger.state.categories.values.map((c) => c.name),
      contains(_typedName),
    );
  }, timeout: uiTestTimeout);

  testWidgets('a save failure keeps the sheet open with the typed name', (
    tester,
  ) async {
    final root = _root('Food');
    final child = _child('Snacks', root.id);
    final ledger = Ledger(
      state: LedgerState(categories: {root.id: root, child.id: child}),
    );
    await openCategoryFormSheet(tester, ledger, presetParentID: child.id);
    await _type(tester, _typedName);

    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
    expect(find.textContaining(_saveErrorTitle), findsOneWidget);
    expect(find.text(_typedName), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a load error shows the reason and Try again recovers', (
    tester,
  ) async {
    var shouldFail = true;
    const args = CategoryFormArgs();
    final overrides = <Override>[
      categoryFormViewModelProvider(
        args,
      ).overrideWith(() => _FlakyCategoryFormNotifier(args, () => shouldFail)),
    ];
    await openCategoryFormSheet(tester, Ledger(), overrides: overrides);

    expect(find.text(_loadErrorMessage), findsOneWidget);
    expect(find.text(_saveLabel), findsNothing);

    shouldFail = false;
    await tester.tap(find.text(_retryLabel));
    await tester.pumpAndSettle();

    expect(find.text(_loadErrorMessage), findsNothing);
    expect(find.text(_saveLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the Add category footer saves the typed category', (
    tester,
  ) async {
    final ledger = Ledger();
    await openCategoryFormSheet(tester, ledger);
    await _type(tester, _typedName);

    await tester.tap(find.text(_addFooterLabel));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsNothing);
    expect(
      ledger.state.categories.values.map((c) => c.name),
      contains(_typedName),
    );
  }, timeout: uiTestTimeout);

  testWidgets(
    'the edit Move to recycle bin button confirms and moves the category to the bin',
    (tester) async {
      final root = _root('Food');
      final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
      await openCategoryFormSheet(tester, ledger, category: root);

      await tester.tap(find.text(_moveToBinLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_moveConfirmLabel));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryForm), findsNothing);
      expect(
        ledger.state.categories[root.id]?.lifecycle,
        isNot(LifecycleState.active),
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets('the Add category form has no Move to recycle bin button', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    expect(find.text(_moveToBinLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('the edit form has no Save category footer', (tester) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    expect(find.text(_moveToBinLabel), findsOneWidget);
    expect(find.text(_addFooterLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('cancelling the Move confirmation keeps the sheet open', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    await tester.tap(find.text(_moveToBinLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
    expect(ledger.state.categories[root.id]?.lifecycle, LifecycleState.active);
  }, timeout: uiTestTimeout);

  testWidgets('the preset parent Inside row does not open the picker', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, presetParentID: root.id);

    await tester.tap(find.text(_insideLabel));
    await tester.pumpAndSettle();

    expect(find.text(_parentPickerTitle), findsNothing);
    expect(find.text('Food'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('More options starts closed and hides the analysis switch', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    expect(find.text(_moreOptionsLabel), findsOneWidget);
    expect(find.text(_closedSubtitle), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('tapping More options toggles the analysis switch', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    await _openMoreOptions(tester);
    expect(find.byType(Switch), findsOneWidget);

    await _openMoreOptions(tester);
    expect(find.byType(Switch), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('turning the analysis switch off is saved', (tester) async {
    final ledger = Ledger();
    await openCategoryFormSheet(tester, ledger);
    await _type(tester, _typedName);
    await _openMoreOptions(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    final saved = ledger.state.categories.values.single;
    expect(saved.includeInAnalysis, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('an add form shows no Type row under More options', (
    tester,
  ) async {
    await openCategoryFormSheet(tester, Ledger());

    await _openMoreOptions(tester);

    expect(find.text(_typeLabel), findsNothing);
    expect(find.text(_typeCaption), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('an edit form shows the switch and Type without any tap', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    expect(find.byType(Switch), findsOneWidget);
    expect(find.text(_typeLabel), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('an edit category always shows the fixed type hint', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    expect(find.text(_typeCaption), findsOneWidget);
    expect(find.text(_subcategoryCountHint), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('an edit subcategory shows Set by parent and the count hint', (
    tester,
  ) async {
    final root = _root('Dining');
    final child = _child('Cafes', root.id);
    final ledger = Ledger(
      state: LedgerState(categories: {root.id: root, child.id: child}),
    );
    await openCategoryFormSheet(tester, ledger, category: child);

    expect(find.text('Set by Dining'), findsOneWidget);
    expect(find.text(_typeCaption), findsNothing);
    expect(find.text(_subcategoryCountHint), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('an add subcategory shows the count hint and no Type row', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, presetParentID: root.id);

    await _openMoreOptions(tester);

    expect(find.text(_subcategoryCountHint), findsOneWidget);
    expect(find.text(_typeLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('an add category shows no count hint', (tester) async {
    await openCategoryFormSheet(tester, Ledger());

    await _openMoreOptions(tester);

    expect(find.text(_subcategoryCountHint), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets(
    'Done in the Icon and colour picker updates the row and is saved',
    (tester) async {
      final root = _root('Food');
      final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
      await openCategoryFormSheet(tester, ledger, category: root);

      await _chooseSymbolAndColor(tester);
      await tester.tap(find.byKey(pickerDoneKey));
      await tester.pumpAndSettle();

      expect(find.text(_chosenSymbolName), findsOneWidget);
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();
      final saved = ledger.state.categories[root.id];
      expect(saved?.symbol, _chosenSymbol);
      expect(saved?.colorHex, toColorHex(_chosenColor));
    },
    timeout: uiTestTimeout,
  );

  testWidgets('dismissing the Icon and colour picker discards the change', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    await _chooseSymbolAndColor(tester);
    await tester.tapAt(_barrierTap);
    await tester.pumpAndSettle();

    expect(find.text(_initialSymbolName), findsOneWidget);
    expect(find.text(_chosenSymbolName), findsNothing);
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();
    final saved = ledger.state.categories[root.id];
    expect(saved?.symbol, 'tag');
    expect(saved?.colorHex, root.colorHex);
  }, timeout: uiTestTimeout);
}
