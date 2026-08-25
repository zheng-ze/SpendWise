import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/line_rows.dart';

RecognizedLine lineAt({
  required String text,
  double? top,
  double? bottom,
  double left = 0,
  double right = 100,
}) {
  return RecognizedLine(
    text: text,
    bounds: top == null || bottom == null
        ? null
        : RecognizedLineBounds(
            top: top,
            bottom: bottom,
            left: left,
            right: right,
          ),
  );
}

void main() {
  group('groupIntoRows', () {
    test('labelAndValueOnSameRowGroupTogetherLeftToRight', () {
      final value = lineAt(text: '9.50', top: 0, bottom: 20, left: 80);
      final label = lineAt(text: 'TOTAL', top: 0, bottom: 20, left: 0);

      final rows = groupIntoRows([value, label]);

      expect(rows, [
        [label, value],
      ]);
    });

    test('stackedLinesWithNoOverlapLandInSeparateRowsTopToBottom', () {
      final second = lineAt(text: 'Item B', top: 20, bottom: 40);
      final first = lineAt(text: 'Item A', top: 0, bottom: 20);

      final rows = groupIntoRows([second, first]);

      expect(rows, [
        [first],
        [second],
      ]);
    });

    test('overlapJustUnderThresholdDoesNotGroup', () {
      // Both lines are height 20. Overlap is 14 (top 6-26 against 0-20):
      // 14/20 = 0.7, just under the 75% threshold.
      final first = lineAt(text: 'Line A', top: 0, bottom: 20);
      final second = lineAt(text: 'Line B', top: 6, bottom: 26, left: 50);

      final rows = groupIntoRows([first, second]);

      expect(rows, [
        [first],
        [second],
      ]);
    });

    test('overlapAtThresholdDoesGroup', () {
      // Both lines are height 20. Overlap is 15 (top 5-25 against 0-20):
      // 15/20 = 0.75 exactly, so this must group ('>=', not '>').
      final first = lineAt(text: 'Line A', top: 0, bottom: 20);
      final second = lineAt(text: 'Line B', top: 5, bottom: 25, left: 50);

      final rows = groupIntoRows([first, second]);

      expect(rows, [
        [first, second],
      ]);
    });

    test('nullBoundsLineFallsBackToItsOwnRowWithoutThrowing', () {
      final withBounds = lineAt(text: 'Has bounds', top: 0, bottom: 20);
      final noBounds = lineAt(text: 'No bounds');

      final rows = groupIntoRows([withBounds, noBounds]);

      expect(rows, [
        [withBounds],
        [noBounds],
      ]);
    });

    test('rowAbsorbsMultipleLinesByComparingAgainstRowEnvelope', () {
      // b (5-30) overlaps a (0-20) by 15/20 = 75%, so b joins a's row and
      // the row's envelope grows to 0-30. c (15-35) overlaps that envelope
      // by 15/20 = 75% (groups), but overlaps a alone by only 5/20 = 25%
      // (would wrongly split if a candidate were compared against just the
      // row's first member instead of its full envelope).
      final a = lineAt(text: 'a', top: 0, bottom: 20, left: 0);
      final b = lineAt(text: 'b', top: 5, bottom: 30, left: 40);
      final c = lineAt(text: 'c', top: 15, bottom: 35, left: 80);

      final rows = groupIntoRows([a, b, c]);

      expect(rows, [
        [a, b, c],
      ]);
    });
  });

  group('toReadingOrderText', () {
    test('linearizesRowsTopToBottomAndLeftToRightWithinARow', () {
      final total = lineAt(text: '9.50', top: 40, bottom: 60, left: 80);
      final totalLabel = lineAt(text: 'TOTAL', top: 40, bottom: 60, left: 0);
      final storeName = lineAt(text: 'Kopi Tiam', top: 0, bottom: 20);

      final text = toReadingOrderText([total, storeName, totalLabel]);

      expect(text, 'Kopi Tiam\nTOTAL 9.50');
    });
  });
}
