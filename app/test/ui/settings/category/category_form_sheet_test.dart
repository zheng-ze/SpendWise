import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category/category_form.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

import '../../../support/category_form_launcher.dart';
import '../../../support/ui_test_timeout.dart';

const _typedName = 'Groceries';
const _saveLabel = 'Save';
const _retryLabel = 'Try again';
const _loadErrorMessage =
    "Couldn't load this category\nBad state: Data unavailable";
const _moveToBinLabel = 'Move to recycle bin';
const _moreOptionsLabel = 'More options';
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

  testWidgets('cancelling the Move confirmation keeps the sheet open', (
    tester,
  ) async {
    final root = _root('Food');
    final ledger = Ledger(state: LedgerState(categories: {root.id: root}));
    await openCategoryFormSheet(tester, ledger, category: root);

    await tester.ensureVisible(find.text(_moveToBinLabel));
    await tester.tap(find.text(_moveToBinLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryForm), findsOneWidget);
    expect(ledger.state.categories[root.id]?.lifecycle, LifecycleState.active);
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
