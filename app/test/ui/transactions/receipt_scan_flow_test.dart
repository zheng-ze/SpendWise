import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ocr/field_extraction_failure.dart';
import 'package:spendwise/ocr/field_extractor.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/receipt_scan_flow.dart';

Ledger _buildLedger() {
  final account = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {account.id: MoneySource.account(account)},
    ),
  );
}

RecognizedText _textOf(List<String> lines) {
  return RecognizedText(
    lines.map((line) => RecognizedLine(text: line)).toList(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mlKitChannel = MethodChannel('google_mlkit_text_recognizer');
  const nanoChannel = MethodChannel('spendwise/nano_field_extractor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late EntryFormController controller;

  setUp(() {
    controller = EntryFormController(ledger: _buildLedger());
    messenger.setMockMethodCallHandler(mlKitChannel, (call) async {
      if (call.method == 'vision#startTextRecognizer') {
        return {'text': '', 'blocks': <Object?>[]};
      }
      return null;
    });
    // Unavailable status, so field-extractor selection resolves to null
    // rather than reaching the real (unmocked) Gemini Nano SDK.
    messenger.setMockMethodCallHandler(nanoChannel, (call) async => 0);
  });

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(mlKitChannel, null);
    messenger.setMockMethodCallHandler(nanoChannel, null);
  });

  test('populates name and amount from a fake FieldExtractor', () async {
    final fake = _FakeFieldExtractor(
      name: 'Kopi Tiam',
      amount: Decimal.parse('9.50'),
    );

    await applyExtractedFields(
      _textOf(['Kopi Tiam', 'TOTAL 9.50']),
      controller,
      selectExtractor: () async => fake,
    );

    expect(controller.nameController.text, 'Kopi Tiam');
    expect(controller.amountController.text, '9.50');
  });

  test('leaves name and amount blank when selection returns null', () async {
    await applyExtractedFields(
      _textOf(['Kopi Tiam', 'TOTAL 9.50']),
      controller,
      selectExtractor: () async => null,
    );

    expect(controller.nameController.text, isEmpty);
    expect(controller.amountController.text, isEmpty);
  });

  test('leaves name and amount blank when selection itself throws', () async {
    await applyExtractedFields(
      _textOf(['Kopi Tiam', 'TOTAL 9.50']),
      controller,
      selectExtractor: () async =>
          throw PlatformException(code: 'checkFeatureStatus'),
    );

    expect(controller.nameController.text, isEmpty);
    expect(controller.amountController.text, isEmpty);
  });

  test('leaves name and amount blank when the extractor throws', () async {
    await applyExtractedFields(
      _textOf(['Kopi Tiam', 'TOTAL 9.50']),
      controller,
      selectExtractor: () async => _ThrowingFieldExtractor(),
    );

    expect(controller.nameController.text, isEmpty);
    expect(controller.amountController.text, isEmpty);
  });

  test('disposes the extractor after use', () async {
    final fake = _FakeFieldExtractor(name: 'Kopi Tiam', amount: null);

    await applyExtractedFields(
      _textOf(['Kopi Tiam']),
      controller,
      selectExtractor: () async => fake,
    );

    expect(fake.disposed, isTrue);
  });

  test('runs recognition on preCapturedBytes without requesting permission or using the picker', () async {
    ReceiptScanStop? stop;

    await runReceiptScan(
      source: ReceiptScanSource.camera,
      controller: controller,
      preCapturedBytes: Uint8List(0),
      onStop: (value) => stop = value,
    );

    expect(stop, isNull);
  });
}

class _FakeFieldExtractor implements FieldExtractor {
  _FakeFieldExtractor({required this.name, required this.amount});

  final String? name;
  final Decimal? amount;
  bool disposed = false;

  @override
  Future<String?> extractName(String readingOrderText) async => name;

  @override
  Future<Decimal?> extractAmount(String readingOrderText) async => amount;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _ThrowingFieldExtractor implements FieldExtractor {
  @override
  Future<String?> extractName(String readingOrderText) {
    throw const FieldExtractionFailure('boom');
  }

  @override
  Future<Decimal?> extractAmount(String readingOrderText) {
    throw const FieldExtractionFailure('boom');
  }

  @override
  Future<void> dispose() async {}
}
