import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a stale scan finishing after a newer scan starts writes nothing',
    () async {
      final gates = <Completer<void>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('spendwise/android_text_recognizer'),
            (call) async {
              final gate = Completer<void>();
              gates.add(gate);
              await gate.future;
              return [
                _line('Coffee Shop'),
                _line(r'Total $12.50'),
                _line('01/15/2026'),
              ];
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('spendwise/android_text_recognizer'),
              null,
            );
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      ReceiptOrchestrationState read() =>
          container.read(receiptEntryCoordinatorProvider(null));
      final draft = <String, Object?>{
        'name': 'fresh',
        'amount': '',
        'date': null,
      };

      Future<void> scan() async {
        final expected = gates.length + 1;
        container
            .read(receiptEntryCoordinatorProvider(null).notifier)
            .requestScan(
              ReceiptScanSource.camera,
              preCapturedBytes: Uint8List(0),
              onPrefill: ({name, amount, required date}) {
                draft['name'] = name;
                draft['amount'] = amount;
                draft['date'] = date;
              },
            );
        for (var i = 0; i < 200 && gates.length < expected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(gates, hasLength(expected));
      }

      await scan();
      container.invalidate(receiptEntryCoordinatorProvider(null));
      await scan();
      expect(read().scanning, isTrue);

      gates[0].complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(read().scanning, isTrue);
      expect(draft, {'name': 'fresh', 'amount': '', 'date': null});

      gates[1].complete();
      for (var i = 0; i < 200 && read().scanning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(read().scanning, isFalse);
      expect(draft['name'], 'Coffee Shop');
      expect(draft['amount'], Decimal.parse('12.50'));
      expect(draft['date'], isA<DateTime>());
    },
  );
}

Map<String, dynamic> _line(String text) => {
  'text': text,
  'left': 0.0,
  'top': 0.0,
  'right': 100.0,
  'bottom': 100.0,
  'confidence': 0.9,
};
