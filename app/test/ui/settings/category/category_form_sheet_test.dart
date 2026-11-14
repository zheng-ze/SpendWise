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
const _saveErrorTitle = 'Could not save category';

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
}
