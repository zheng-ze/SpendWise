import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _initialSymbol = 'shopping_cart';
const _initialColor = Color(0xFFFF9500);
const _chosenSymbol = 'restaurant';
const _chosenColor = Color(0xFF63E6BE);
const _categoryName = 'Groceries';
const _swatches = [_initialColor, _chosenColor];
const _barrierTap = Offset(160, 10);

Future<PickerOpener<SymbolPickerResult>> _openPicker(
  WidgetTester tester, {
  String categoryName = '',
}) {
  return openPicker<SymbolPickerResult>(
    tester,
    size: phoneTallSize,
    open: (context) => showSymbolPickerSheet(
      context: context,
      presentation: presentationFor(phoneTallSize),
      symbol: _initialSymbol,
      color: _initialColor,
      swatches: _swatches,
      categoryName: categoryName,
    ),
  );
}

Future<void> _chooseSymbolAndColor(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey(_chosenSymbol));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  final swatch = find.byKey(const ValueKey(_chosenColor));
  await tester.ensureVisible(swatch);
  await tester.tap(swatch);
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
  });

  group('SymbolPicker preview', () {
    testWidgets('shows the entered category name', (tester) async {
      await _openPicker(tester, categoryName: _categoryName);

      expect(find.text(_categoryName), findsOneWidget);
      expect(find.text(symbolDisplayName(_initialSymbol)), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('falls back to the icon name when the name is empty', (
      tester,
    ) async {
      await _openPicker(tester);

      expect(find.text(symbolDisplayName(_initialSymbol)), findsOneWidget);
    }, timeout: uiTestTimeout);
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
