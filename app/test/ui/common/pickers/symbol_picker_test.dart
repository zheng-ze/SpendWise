import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _initialSymbol = 'shopping_cart';
const _initialColor = Color(0xFFFF3B30);
const _chosenSymbol = 'restaurant';
const _chosenColor = Color(0xFF5AC8FA);
const _swatches = [_initialColor, _chosenColor];
const _barrierTap = Offset(160, 10);

Future<PickerOpener<SymbolPickerResult>> _openPicker(WidgetTester tester) {
  return openPicker<SymbolPickerResult>(
    tester,
    size: phoneTallSize,
    open: (context) => showSymbolPickerSheet(
      context: context,
      presentation: presentationFor(phoneTallSize),
      symbol: _initialSymbol,
      color: _initialColor,
      swatches: _swatches,
    ),
  );
}

Future<void> _chooseSymbolAndColor(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _chosenSymbol);
  await tester.pumpAndSettle();
  final icon = find.byWidgetPredicate(
    (widget) => widget is CategoryIcon && widget.symbolName == _chosenSymbol,
  );
  await tester.tap(icon.first);
  await tester.tap(find.byKey(const ValueKey(_chosenColor)));
  await tester.pumpAndSettle();
}

void main() {
  group('SymbolPicker', () {
    testWidgets('Done returns the chosen icon and colour', (tester) async {
      final opener = await _openPicker(tester);

      await _chooseSymbolAndColor(tester);
      await tester.tap(find.byKey(pickerDoneKey));
      await tester.pumpAndSettle();

      expect(opener.result?.symbol, _chosenSymbol);
      expect(opener.result?.color, _chosenColor);
    }, timeout: uiTestTimeout);

    testWidgets('Done without changes returns the initial values', (
      tester,
    ) async {
      final opener = await _openPicker(tester);

      await tester.tap(find.byKey(pickerDoneKey));
      await tester.pumpAndSettle();

      expect(opener.result?.symbol, _initialSymbol);
      expect(opener.result?.color, _initialColor);
    }, timeout: uiTestTimeout);

    testWidgets('dismissing by tapping outside discards the draft', (
      tester,
    ) async {
      final opener = await _openPicker(tester);

      await _chooseSymbolAndColor(tester);
      await tester.tapAt(_barrierTap);
      await tester.pumpAndSettle();

      expect(opener.completed, isTrue);
      expect(opener.result, isNull);
    }, timeout: uiTestTimeout);

    testWidgets('searching narrows the icon grid', (tester) async {
      await _openPicker(tester);

      await tester.enterText(find.byType(TextField), _chosenSymbol);
      await tester.pumpAndSettle();

      final names = tester
          .widgetList<CategoryIcon>(find.byType(CategoryIcon))
          .map((icon) => icon.symbolName);
      expect(names, everyElement(contains(_chosenSymbol)));
      expect(names, isNotEmpty);
    }, timeout: uiTestTimeout);
  });

  group('filterSymbolSections', () {
    const sections = {
      'Food & Drink': ['restaurant', 'local_cafe'],
      'Transport': ['directions_car', 'flight'],
      'Money': ['savings', 'attach_money'],
    };

    test('empty query returns every section unchanged', () {
      expect(filterSymbolSections(sections, ''), sections);
    });

    test('a trimmed case-insensitive term returns only matching symbols', () {
      final result = filterSymbolSections(sections, '  CAr  ');
      expect(result.keys, ['Transport']);
      expect(result['Transport'], ['directions_car']);
    });

    test('a query matching nothing returns no sections', () {
      expect(filterSymbolSections(sections, 'zzz'), isEmpty);
    });
  });

  group('symbolDisplayName', () {
    test('converts snake_case to sentence case', () {
      expect(symbolDisplayName('shopping_cart'), 'Shopping cart');
    });

    test('capitalises a single word', () {
      expect(symbolDisplayName('cart'), 'Cart');
    });

    test('returns an empty string for an empty name', () {
      expect(symbolDisplayName(''), '');
    });
  });
}
