import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mlKitChannel = MethodChannel('google_mlkit_text_recognizer');
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
  });

  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(mlKitChannel, null);
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
