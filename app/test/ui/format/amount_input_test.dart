import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/amount_input.dart';

String _positive(String text) => sanitizeAmount(text, allowsNegative: false);

String _signed(String text) => sanitizeAmount(text, allowsNegative: true);

void main() {
  group('sanitizeAmount fraction digits', () {
    test('drops the third fraction digit and leaves the first two intact', () {
      expect(_positive('1.005'), '1.00');
      expect(_positive('1.009'), '1.00');
      expect(_positive('12.3456'), '12.34');
    });

    test('folds later points into the first fraction, still capped at two', () {
      expect(_positive('1.2.3'), '1.23');
      expect(_positive('1.2.3.4'), '1.23');
      expect(_positive('..'), '.');
    });
  });

  group('sanitizeAmount sign', () {
    test('strips a leading minus when negatives are not allowed', () {
      expect(_positive('-12.34'), '12.34');
      expect(_positive('-'), '');
    });

    test('keeps a single leading minus when negatives are allowed', () {
      expect(_signed('-12.34'), '-12.34');
      expect(_signed('-'), '-');
    });
  });

  group('sanitizeAmount junk', () {
    test('removes letters, currency symbols and separators', () {
      expect(_positive(r'$1,234.56'), '1234.56');
      expect(_positive('12abc.3x4'), '12.34');
      expect(_positive('SGD 40'), '40');
      expect(_positive(' 1 2 . 3 '), '12.3');
    });

    test('returns empty for text with nothing to keep', () {
      expect(_positive(''), '');
      expect(_positive('abc'), '');
      expect(_signed(''), '');
    });
  });

  group('AmountInputFormatter', () {
    TextEditingValue format(
      String text, {
      required bool allowsNegative,
      int? selection,
    }) {
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection ?? text.length),
      );
      return AmountInputFormatter(allowsNegative: allowsNegative)
          .formatEditUpdate(TextEditingValue.empty, value);
    }

    test('sanitizes the incoming keystroke', () {
      expect(format('1.005', allowsNegative: false).text, '1.00');
      expect(format(r'-$1,2a3', allowsNegative: false).text, '123');
      expect(format(r'-$1,2a3', allowsNegative: true).text, '-123');
    });

    test('moves the caret back by the characters removed before it', () {
      final value = format('1a2.3', allowsNegative: false, selection: 3);
      expect(value.text, '12.3');
      expect(value.selection.baseOffset, 2);
    });
  });

  group('applyAmountEdit insertion', () {
    TextEditingValue current(String text, int offset, [int? extent]) {
      return TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: offset,
          extentOffset: extent ?? offset,
        ),
      );
    }

    test('replaces the selected range with the insertion', () {
      final value = applyAmountEdit(
        current('123', 1, 3),
        const AmountEdit.insert('9'),
      );
      expect(value.text, '19');
      expect(value.selection.baseOffset, 2);
    });

    test('drops a repeated decimal and excess fraction digits', () {
      expect(
        applyAmountEdit(current('1.2', 3), const AmountEdit.insert('.')).text,
        '1.2',
      );
      expect(
        applyAmountEdit(current('1.23', 4), const AmountEdit.insert('4')).text,
        '1.23',
      );
    });

    test('rejects a minus and strips pasted grouping characters', () {
      expect(
        applyAmountEdit(current('12', 2), const AmountEdit.insert('-')).text,
        '12',
      );
      expect(
        applyAmountEdit(
          current('', 0),
          const AmountEdit.insert(r'$1,234'),
        ).text,
        '1234',
      );
    });

    test('permits transient empty, leading and trailing decimal text', () {
      expect(
        applyAmountEdit(current('', 0), const AmountEdit.insert('.')).text,
        '.',
      );
      expect(
        applyAmountEdit(current('12', 2), const AmountEdit.insert('.')).text,
        '12.',
      );
    });
  });

  group('applyAmountEdit backspace', () {
    TextEditingValue current(String text, int offset, [int? extent]) {
      return TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: offset,
          extentOffset: extent ?? offset,
        ),
      );
    }

    test('deletes the character before the caret', () {
      final value = applyAmountEdit(
        current('123', 3),
        const AmountEdit.delete(),
      );
      expect(value.text, '12');
      expect(value.selection.baseOffset, 2);
    });

    test('deletes the selected range', () {
      final value = applyAmountEdit(
        current('123', 1, 3),
        const AmountEdit.delete(),
      );
      expect(value.text, '1');
      expect(value.selection.baseOffset, 1);
    });
  });
}
