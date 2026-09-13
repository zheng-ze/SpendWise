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
}
