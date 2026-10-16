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

    test('keeps one and two fraction digits unchanged', () {
      expect(_positive('1.5'), '1.5');
      expect(_positive('1.55'), '1.55');
    });

    test('keeps a trailing point so a fraction can still be typed', () {
      expect(_positive('12.'), '12.');
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

    test('drops a minus that is not leading', () {
      expect(_signed('12-34'), '1234');
      expect(_signed('12.3-4'), '12.34');
    });

    test('keeps only the first of several leading minuses', () {
      expect(_signed('--12'), '-12');
      expect(_signed('---12'), '-12');
      expect(_positive('--12'), '12');
    });

    test('a minus behind stripped junk still signs the number', () {
      expect(_signed('a-5'), '-5');
      expect(_signed(r'$-5'), '-5');
      expect(_signed(' -5'), '-5');
    });

    test('a minus after a digit is not a sign', () {
      expect(_signed('5-3'), '53');
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

    test('keeps a lone point so a leading fraction can be typed', () {
      expect(_positive('.'), '.');
      expect(_positive('.5'), '.5');
      expect(_signed('-.5'), '-.5');
    });

    test('leaves leading zeros alone rather than normalizing the number', () {
      expect(_positive('007'), '007');
      expect(_positive('0.10'), '0.10');
    });

    test('is unchanged by running it over its own output', () {
      for (final text in [r'-$1,2a3.4567', '..12..34..', '--.', 'SGD 9.999']) {
        for (final allowsNegative in [true, false]) {
          final once = sanitizeAmount(text, allowsNegative: allowsNegative);
          expect(
            sanitizeAmount(once, allowsNegative: allowsNegative),
            once,
            reason: '$text allowsNegative=$allowsNegative',
          );
        }
      }
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

    test('holds the caret inside the sanitized text', () {
      final value = format('1.005', allowsNegative: false);
      expect(value.selection.baseOffset, lessThanOrEqualTo(value.text.length));
      expect(value.selection.baseOffset, greaterThanOrEqualTo(0));
    });

    test('keeps the caret at the end when the tail was typed', () {
      expect(format('12.3', allowsNegative: false).selection.baseOffset, 4);
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

    test('inserts a digit at the end, middle and beginning', () {
      expect(
        applyAmountEdit(current('12', 2), const AmountEdit.insert('3')).text,
        '123',
      );
      expect(
        applyAmountEdit(current('12', 1), const AmountEdit.insert('3')).text,
        '132',
      );
      expect(
        applyAmountEdit(current('12', 0), const AmountEdit.insert('3')).text,
        '312',
      );
    });

    test('replaces the selected range with the insertion', () {
      final value = applyAmountEdit(
        current('123', 1, 3),
        const AmountEdit.insert('9'),
      );
      expect(value.text, '19');
      expect(value.selection.baseOffset, 2);
    });

    test('replaces the selected range with a decimal point', () {
      final value = applyAmountEdit(
        current('123', 1, 2),
        const AmountEdit.insert('.'),
      );
      expect(value.text, '1.3');
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

    test('lands the caret after the inserted text', () {
      final value = applyAmountEdit(
        current('12', 2),
        const AmountEdit.insert('34'),
      );
      expect(value.selection.baseOffset, 4);
      final middle = applyAmountEdit(
        current('12', 1),
        const AmountEdit.insert('34'),
      );
      expect(middle.selection.baseOffset, 3);
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

    test('leaves text and selection alone at offset zero', () {
      const value = TextEditingValue(
        text: '123',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(applyAmountEdit(value, const AmountEdit.delete()), value);
    });

    test('leaves empty text alone', () {
      expect(
        applyAmountEdit(TextEditingValue.empty, const AmountEdit.delete()).text,
        '',
      );
    });
  });

  group('applyAmountEdit parity', () {
    TextEditingValue typed(String text, int offset) {
      final incoming = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
      );
      return const AmountInputFormatter(allowsNegative: false)
          .formatEditUpdate(TextEditingValue.empty, incoming);
    }

    test('pad and typed edits agree on text and selection', () {
      final cases = [
        (current: '12', at: 2, key: '3'),
        (current: '12', at: 1, key: '3'),
        (current: '1.2', at: 3, key: '.'),
        (current: '', at: 0, key: '.'),
        (current: '12', at: 2, key: '-'),
      ];
      for (final entry in cases) {
        final edited = applyAmountEdit(
          TextEditingValue(
            text: entry.current,
            selection: TextSelection.collapsed(offset: entry.at),
          ),
          AmountEdit.insert(entry.key),
        );
        final candidate =
            '${entry.current.substring(0, entry.at)}${entry.key}${entry.current.substring(entry.at)}';
        final formatted = typed(candidate, entry.at + entry.key.length);
        expect(
          edited.text,
          formatted.text,
          reason: '${entry.key} in ${entry.current}',
        );
        expect(
          edited.selection.baseOffset,
          formatted.selection.baseOffset,
          reason: '${entry.key} in ${entry.current}',
        );
      }
    });
  });
}
