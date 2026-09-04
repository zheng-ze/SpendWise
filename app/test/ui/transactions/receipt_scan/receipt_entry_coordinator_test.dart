import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart' show Decimal;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

const _mlKitChannel = MethodChannel('google_mlkit_text_recognizer');
const _documentScannerChannel = MethodChannel('spendwise/document_scanner');

/// Ignored [ScanResultHandler] for scans whose prefill a test does not inspect.
void _ignorePrefill({
  String? name,
  Decimal? amount,
  required DateTime date,
}) {}

/// Freezes [vision#startTextRecognizer] until [gate] completes, so a test can
/// observe the coordinator mid-recognition, then returns a recognized result.
Future<Map<String, dynamic>?> _freezeRecognizer(Completer<void>? gate) async {
  await gate?.future;
  return _recognizedResult(['Coffee Shop', 'Total \$12.50', '01/15/2026']);
}

Map<String, dynamic> _rect(double left, double top, double right, double bottom) =>
      {'left': left, 'top': top, 'right': right, 'bottom': bottom};

Map<String, dynamic> _symbol(String text) => {
      'text': text,
      'rect': _rect(0, 0, 100, 12),
      'recognizedLanguages': ['en'],
      'points': <dynamic>[],
      'confidence': 0.9,
      'angle': 0.0,
    };

Map<String, dynamic> _element(String text) => {
      'text': text,
      'rect': _rect(0, 0, 100, 16),
      'recognizedLanguages': ['en'],
      'points': <dynamic>[],
      'confidence': 0.9,
      'angle': 0.0,
      'symbols': <dynamic>[_symbol(text)],
    };

Map<String, dynamic> _line(String text) => {
      'text': text,
      'rect': _rect(0, 0, 100, 20),
      'recognizedLanguages': ['en'],
      'points': <dynamic>[],
      'confidence': 0.9,
      'angle': 0.0,
      'elements': <dynamic>[_element(text)],
    };

Map<String, dynamic> _recognizedResult(List<String> lines) => {
      'text': lines.join('\n'),
      'blocks': [
        {
          'text': lines.join(' '),
          'rect': _rect(0, 0, 100, 100),
          'recognizedLanguages': ['en'],
          'points': <dynamic>[],
          'lines': <dynamic>[for (final text in lines) _line(text)],
        },
      ],
    };

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Completer<void>? gate;
  late PermissionHandlerPlatform originalPermissionHandler;

  setUp(() {
    gate = null;
    originalPermissionHandler = PermissionHandlerPlatform.instance;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mlKitChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_documentScannerChannel, null);
    PermissionHandlerPlatform.instance = originalPermissionHandler;
    container.dispose();
  });

  ProviderContainer startContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  ReceiptEntryCoordinator coordinator() =>
      container.read(receiptEntryCoordinatorProvider(null).notifier);

  ReceiptOrchestrationState state() =>
      container.read(receiptEntryCoordinatorProvider(null));

  /// Waits for the coordinator to reach a non-scanning state by polling, since
  /// the Notifier exposes no observable stream.
  Future<void> idle() async {
    for (var i = 0; i < 200; i++) {
      if (!state().scanning) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('coordinator did not finish recognition');
  }

  group('recognition state', () {
    test('scanning is true during recognition, then returns to false', () async {
      container = startContainer();
      gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, (call) async =>
              await _freezeRecognizer(gate));

      coordinator().requestScan(
        ReceiptScanSource.camera,
        preCapturedBytes: Uint8List(0),
        onPrefill: _ignorePrefill,
      );

      // _runScan sets scanning true synchronously before its first await.
      expect(state().scanning, isTrue);

      gate!.complete();
      await idle();

      expect(state().scanning, isFalse);
    });

    test('calls onPrefill once with the extracted fields after recognition',
        () async {
      container = startContainer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, (call) async =>
              _recognizedResult(['Coffee Shop', 'Total \$12.50', '01/15/2026']));

      DateTime? capturedDate;
      Decimal? capturedAmount;

      coordinator().requestScan(
        ReceiptScanSource.camera,
        preCapturedBytes: Uint8List(0),
        onPrefill: ({name, amount, required date}) {
          capturedDate = date;
          capturedAmount = amount;
        },
      );

      await idle();

      expect(capturedDate, DateTime.utc(2026, 1, 15));
      expect(capturedAmount, Decimal.parse('12.50'));
    });
  });

  group('scanStop', () {
    test('is set exactly once on a scan that ends without prefilling', () async {
      container = startContainer();
      PermissionHandlerPlatform.instance =
          _FakePermissionHandler(PermissionStatus.denied);
      var isAvailableCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, (call) async {
        if (call.method == 'isAvailable') {
          isAvailableCalled = true;
          return false; // native scanner unavailable -> fall through to picker
        }
        return null;
      });

      var prefillCalls = 0;
      coordinator().requestScan(
        ReceiptScanSource.camera,
        onPrefill: ({name, amount, required date}) => prefillCalls++,
      );

      await idle();

      expect(state().scanStop, ReceiptScanStop.permissionDenied);
      expect(prefillCalls, 0);
      expect(isAvailableCalled, isTrue);
    });

    test('clearScanStop clears a previously set scanStop exactly once',
        () async {
      container = startContainer();
      PermissionHandlerPlatform.instance =
          _FakePermissionHandler(PermissionStatus.denied);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, (call) async {
        if (call.method == 'isAvailable') return false;
        return null;
      });

      coordinator().requestScan(
        ReceiptScanSource.camera,
        onPrefill: _ignorePrefill,
      );
      await idle();
      expect(state().scanStop, ReceiptScanStop.permissionDenied);

      coordinator().clearScanStop();
      expect(state().scanStop, isNull);

      // A second clear is a no-op: the single-shot state never re-arms.
      coordinator().clearScanStop();
      expect(state().scanStop, isNull);
    });
  });

  group('native document scanner routing', () {
    setUp(() {
      // iOS selects the scanner without the Android eligibility channel, so
      // only scanDocument is exercised.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('a cancelled capture returns early without falling through', () async {
      container = startContainer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, (call) async {
        if (call.method == 'scanDocument') return null; // user backed out
        return null;
      });

      var prefillCalls = 0;
      coordinator().requestScan(
        ReceiptScanSource.camera,
        onPrefill: ({name, amount, required date}) => prefillCalls++,
      );

      await idle();

      expect(state().scanStop, isNull);
      expect(prefillCalls, 0);
    });

    test('an unavailable scanner falls through to the plain picker', () async {
      container = startContainer();
      PermissionHandlerPlatform.instance =
          _FakePermissionHandler(PermissionStatus.denied);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, (call) async {
        if (call.method == 'scanDocument') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });

      var prefillCalls = 0;
      coordinator().requestScan(
        ReceiptScanSource.camera,
        onPrefill: ({name, amount, required date}) => prefillCalls++,
      );

      await idle();

      // Reached the picker path, which denied permission -> scanStop set.
      expect(state().scanStop, ReceiptScanStop.permissionDenied);
      expect(prefillCalls, 0);
    });

    test('a captured native scan recognizes the captured bytes', () async {
      container = startContainer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, (call) async =>
              _recognizedResult(['Coffee Shop', 'Total \$12.50', '01/15/2026']));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, (call) async =>
              Uint8List.fromList([1, 2, 3]));

      DateTime? capturedDate;
      coordinator().requestScan(
        ReceiptScanSource.camera,
        onPrefill: ({name, amount, required date}) => capturedDate = date,
      );

      await idle();

      expect(capturedDate, DateTime.utc(2026, 1, 15));
    });
  });

  group('applyCroppedDocument', () {
    test('recognizes the uploaded bytes as a gallery scan', () async {
      container = startContainer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, (call) async =>
              _recognizedResult(['Coffee Shop', 'Total \$12.50', '01/15/2026']));

      DateTime? capturedDate;
      coordinator().applyCroppedDocument(
        Uint8List.fromList([4, 5, 6]),
        onPrefill: ({name, amount, required date}) => capturedDate = date,
      );

      await idle();

      expect(capturedDate, DateTime.utc(2026, 1, 15));
      expect(state().scanStop, isNull);
    });
  });
}
