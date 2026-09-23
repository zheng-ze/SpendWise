import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

const _mlKitChannel = MethodChannel('spendwise/android_text_recognizer');
const _documentScannerChannel = MethodChannel('spendwise/document_scanner');

class _FakePermissionHandler extends PermissionHandlerPlatform {
  _FakePermissionHandler(this.status);
  final PermissionStatus status;
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {permissions.first: status};
  }
}

Map<String, dynamic> _rect(
  double left,
  double top,
  double right,
  double bottom,
) => {'left': left, 'top': top, 'right': right, 'bottom': bottom};

Map<String, dynamic> _line(String text) {
  final rect = _rect(0, 0, 100, 100);
  return {
    'text': text,
    'left': rect['left'],
    'top': rect['top'],
    'right': rect['right'],
    'bottom': rect['bottom'],
    'confidence': 0.9,
  };
}

List<Map<String, dynamic>> _recognizedResult(List<String> lines) => [
  for (final text in lines) _line(text),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  Ledger buildLedger() => Ledger(
    state: LedgerState(
      moneySources: {account.id: MoneySource.account(account)},
    ),
  );

  Future<void> pumpForm(WidgetTester tester, {String? entryId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          scanStripEnabledProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          home: Scaffold(body: EntryForm(entryId: entryId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerFor(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EntryForm)));

  EntryFormViewState stateOf(ProviderContainer container) =>
      container.read(entryFormViewModelProvider(null)).asData!.value;

  Future<void> driveScan(
    WidgetTester tester,
    ProviderContainer container,
    void Function() action,
  ) async {
    await tester.runAsync(() async {
      action();
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!stateOf(container).scanning) return;
      }
      fail('scan did not finish');
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mlKitChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_documentScannerChannel, null);
    PermissionHandlerPlatform.instance = _FakePermissionHandler(
      PermissionStatus.denied,
    );
  });

  group('scan -> prefill through the entry form', () {
    testWidgets('recognizing a camera receipt prefills name, amount and date', (
      tester,
    ) async {
      await pumpForm(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _mlKitChannel,
            (call) async => _recognizedResult([
              'Coffee Shop',
              'Total \$12.50',
              '01/15/2026',
            ]),
          );

      final container = containerFor(tester);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      await driveScan(
        tester,
        container,
        () => viewModel.requestScan(
          ReceiptScanSource.camera,
          preCapturedBytes: Uint8List(0),
        ),
      );

      final state = stateOf(container);
      expect(state.nameText, 'Coffee Shop');
      expect(state.amountText, '12.50');
      expect(state.date, DateTime.utc(2026, 1, 15));
    });

    testWidgets('an uploaded (crop) receipt prefills the same fields', (
      tester,
    ) async {
      await pumpForm(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _mlKitChannel,
            (call) async => _recognizedResult([
              'Coffee Shop',
              'Total \$12.50',
              '01/15/2026',
            ]),
          );

      final container = containerFor(tester);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      await driveScan(
        tester,
        container,
        () => viewModel.applyCroppedDocument(Uint8List.fromList([1, 2, 3])),
      );

      final state = stateOf(container);
      expect(state.nameText, 'Coffee Shop');
      expect(state.amountText, '12.50');
      expect(state.date, DateTime.utc(2026, 1, 15));
    });

    testWidgets('the scanning indicator shows during recognition then hides', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpForm(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, (call) async {
            await gate.future;
            return _recognizedResult([
              'Coffee Shop',
              'Total \$12.50',
              '01/15/2026',
            ]);
          });

      final container = containerFor(tester);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );

      await tester.runAsync(() async {
        viewModel.requestScan(
          ReceiptScanSource.camera,
          preCapturedBytes: Uint8List(0),
        );
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (stateOf(container).scanning) return;
        }
        fail('scanning never went true');
      });
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.runAsync(() async {
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'a scan that ends without prefilling shows the scan-end message',
      (tester) async {
        await pumpForm(tester);
        PermissionHandlerPlatform.instance = _FakePermissionHandler(
          PermissionStatus.denied,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_documentScannerChannel, (call) async {
              if (call.method == 'isAvailable') return false;
              return null;
            });

        final container = containerFor(tester);
        final viewModel = container.read(
          entryFormViewModelProvider(null).notifier,
        );

        await driveScan(
          tester,
          container,
          () => viewModel.requestScan(ReceiptScanSource.camera),
        );
        await tester.pump();

        expect(
          find.text('Camera or photo library access was denied.'),
          findsOneWidget,
        );
      },
    );
  });
}
