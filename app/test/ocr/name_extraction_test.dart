import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/name_extraction.dart';

RecognizedLineBounds boundsOf(double height) {
  return RecognizedLineBounds(top: 0, bottom: height, left: 0, right: 100);
}

RecognizedText textOf(
  List<String> lines, {
  List<double?> heights = const [],
  List<double?> confidences = const [],
}) {
  final recognizedLines = <RecognizedLine>[];
  for (var i = 0; i < lines.length; i++) {
    final height = i < heights.length ? heights[i] : null;
    final confidence = i < confidences.length ? confidences[i] : null;
    recognizedLines.add(
      RecognizedLine(
        text: lines[i],
        bounds: height == null ? null : boundsOf(height),
        confidence: confidence,
      ),
    );
  }
  return RecognizedText(recognizedLines);
}

void main() {
  test('skipsAddressAndPhoneLinesBeforeFindingCandidate', () {
    final text = textOf(['123 Main Street', '(555) 123-4567', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('skipsBoilerplateAndGreetingLinesBeforeFindingCandidate', () {
    final text = textOf(['WELCOME TO', 'STORE #4521', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('skipsUrlAndHandleLinesBeforeFindingCandidate', () {
    final text = textOf(['www.kopitiam.example.com', '@kopitiam', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('tallestSurvivingLineWinsWhenBoundsAvailable', () {
    final text = textOf(
      ['Coffee Corner', 'Grand Bazaar Cafe'],
      heights: [20, 40],
    );

    expect(extractName(text), 'Grand Bazaar Cafe');
  });

  test('firstSurvivingLineWinsWhenBoundsUnavailable', () {
    final text = textOf(['Coffee Corner', 'Grand Bazaar Cafe']);

    expect(extractName(text), 'Coffee Corner');
  });

  test('threeOrMoreConsecutiveSkipsBeforeCandidateLeavesNameBlank', () {
    final text = textOf([
      '123 Main Street',
      '(555) 123-4567',
      'STORE #4521',
      'REG 4',
      'Kopi Tiam',
    ]);

    expect(extractName(text), isNull);
  });

  test('fewerThanThreeConsecutiveSkipsStillFindsCandidate', () {
    final text = textOf(['123 Main Street', '(555) 123-4567', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('threeOrMoreConsecutiveSkipsAfterCandidateStillReturnsIt', () {
    final text = textOf([
      'Kopi Tiam',
      '123 Main Street',
      '(555) 123-4567',
      'STORE #4521',
      'REG 4',
    ]);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('allFiveLinesSkippedLeavesNameBlank', () {
    final text = textOf([
      'WELCOME TO',
      '123 Main Street',
      '(555) 123-4567',
      'STORE #4521',
      'CUSTOMER COPY',
    ]);

    expect(extractName(text), isNull);
  });

  test('noCandidateWithinScanDepthLeavesNameBlank', () {
    final text = textOf([
      'WELCOME TO',
      '123 Main Street',
      '(555) 123-4567',
      'STORE #4521',
      'REG 4',
      'Kopi Tiam',
    ]);

    expect(extractName(text), isNull);
  });

  test('rejectsLineOverDigitDensityThreshold', () {
    final text = textOf(['12345678', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('rejectsLineWithNoAlphabeticCharacter', () {
    final text = textOf(['----------', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('rejectsLineOverSixWords', () {
    final text = textOf([
      'this line has way too many words in it',
      'Kopi Tiam',
    ]);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('rejectsLineOutsideLengthBounds', () {
    final text = textOf(['ab', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('emptyReceiptLeavesNameBlank', () {
    final text = textOf([]);

    expect(extractName(text), isNull);
  });

  test('stripsTrailingStoreNumberFromMerchantNameLine', () {
    final text = textOf([
      'STARBUCKS Store #10208',
      '11302 Euclid Avenue',
      'Cleveland, OH (216) 229-0749',
    ]);

    expect(extractName(text), 'STARBUCKS');
  });

  test('lineThatIsOnlyAStoreNumberStaysSkippable', () {
    final text = textOf(['STORE #10208', 'Kopi Tiam']);

    expect(extractName(text), 'Kopi Tiam');
  });

  test('skipsManagerNameLineWhenLogoFailsToOcrAsText', () {
    final text = textOf([
      'Save money. Live better.',
      '(330) 339-3991',
      'MANAGER DIANA EARNEST',
      '231 BLUEBELL DR SW',
      'NEW PHILADELPHIA OH 44663',
    ]);

    expect(extractName(text), 'Save money. Live better.');
  });

  test(
    'rejectsATallLowConfidenceLogoLineThatWouldOtherwiseWinOnHeight',
    () {
      final text = textOf(
        ['aiMafit 4...', 'Save money. Live better.'],
        heights: [60, 26],
        confidences: [0, 0.95],
      );

      expect(extractName(text), 'Save money. Live better.');
    },
  );

  test('keepsALegibleShortNameEvenAtModerateConfidence', () {
    final text = textOf(['Kopi Tiam'], confidences: [0.5]);

    expect(extractName(text), 'Kopi Tiam');
  });
}
