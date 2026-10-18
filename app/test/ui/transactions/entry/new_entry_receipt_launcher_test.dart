import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _recognizerChannel = MethodChannel('spendwise/android_text_recognizer');
const _scannerChannel = MethodChannel('spendwise/document_scanner');
const _focusSettle = Duration(milliseconds: 150);
const _frameStep = Duration(milliseconds: 16);
const _scanPoll = Duration(milliseconds: 10);
const _scanPollLimit = 200;
const _permissionMessage = 'Camera or photo library access was denied.';
const _hint = 'Saving creates a plan. Review it in Money, Plans.';
const _noteText = 'keep this note';

final _launcher = find.byKey(const ValueKey('new-entry-receipt'));
final _strip = find.byType(ReceiptScanStrip);
final _noteField = find.byKey(const ValueKey('new-entry-note'));
final _amountField = find.descendant(
  of: find.byType(AddAmountBlock),
  matching: find.byType(TextField),
);

class _FakePermissions extends PermissionHandlerPlatform {
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {permissions.first: PermissionStatus.denied};
}

Map<String, dynamic> _line(String text) => {
  'text': text,
  'left': 0.0,
  'top': 0.0,
  'right': 100.0,
  'bottom': 100.0,
  'confidence': 0.9,
};

Finder _action(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<OutlinedButton>(),
);

EntryFormViewState _state(EntryHarness harness) =>
    harness.container.read(entryFormViewModelProvider(null)).value!;

Future<EntryHarness> _openAdd(
  WidgetTester tester, {
  bool scanEnabled = true,
}) async {
  final harness = await pumpShell(tester, scanEnabled: scanEnabled);
  await openAdd(tester, harness);
  return harness;
}

List<double> _scrollOffsets(WidgetTester tester) {
  final scrollables = find.descendant(
    of: find.byType(AppSheet),
    matching: find.byType(Scrollable),
  );
  return [
    for (final element in scrollables.evaluate())
      ((element as StatefulElement).state as ScrollableState).position.pixels,
  ];
}

Future<void> _activate(WidgetTester tester) async {
  await tester.ensureVisible(_launcher);
  await tester.tap(_launcher);
  await tester.pumpAndSettle(_frameStep);
}

Future<void> _waitForScan(
  WidgetTester tester,
  EntryHarness harness, {
  required bool scanning,
}) async {
  await tester.runAsync(() async {
    for (var i = 0; i < _scanPollLimit; i++) {
      await Future<void>.delayed(_scanPoll);
      if (_state(harness).scanning == scanning) return;
    }
    fail('scanning never became $scanning');
  });
  await tester.pump();
}

void _mockRecognizer(Future<Object?> Function() reply) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_recognizerChannel, (_) => reply());
  addTearDown(
    () => messenger.setMockMethodCallHandler(_recognizerChannel, null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('launcher', () {
    testWidgets('the strip stays hidden until Add receipt is activated', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      expect(_launcher, findsOneWidget);
      expect(_strip, findsNothing);
      expect(find.text('Scan receipt'), findsNothing);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('repeated activation shows one strip and starts no scan', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await _activate(tester);
      await _activate(tester);
      await _activate(tester);

      expect(_strip, findsOneWidget);
      expect(find.text('Scan receipt'), findsOneWidget);
      expect(find.text('Upload photo'), findsOneWidget);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('activation dismisses the pad', (tester) async {
      await _openAdd(tester);
      expect(find.byType(NumberPad), findsOneWidget);

      await _activate(tester);

      final amount = tester.widget<TextField>(_amountField).focusNode!;
      expect(find.byType(NumberPad), findsNothing);
      expect(amount.hasFocus, isFalse);
    }, timeout: uiTestTimeout);

    testWidgets('activation unfocuses the Note field', (tester) async {
      await _openAdd(tester);
      await tester.ensureVisible(_noteField);
      await tester.tap(_noteField);
      await tester.pumpAndSettle();
      final note = tester.widget<TextField>(_noteField).focusNode!;
      expect(note.hasFocus, isTrue);

      await _activate(tester);

      expect(note.hasFocus, isFalse);
      expect(_strip, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the strip survives kind, repeat and window changes', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      await _activate(tester);

      harness.form.setKind(EntryFormKind.income);
      await tester.pumpAndSettle();
      expect(_strip, findsOneWidget);

      harness.form.applyPickedRecurrence(RecurrenceFrequency.monthly);
      await tester.pumpAndSettle();
      expect(_strip, findsOneWidget);
      final hintTop = tester.getTopLeft(find.text(_hint)).dy;
      expect(hintTop, greaterThan(tester.getBottomLeft(_strip).dy));

      await resize(tester, openSize);
      expect(_strip, findsOneWidget);
      await resize(tester, phoneSize);
      expect(_strip, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('focusing Note before the reveal delay cancels the scroll', (
      tester,
    ) async {
      await _openAdd(tester);
      await tester.ensureVisible(_launcher);
      await tester.tap(_launcher);
      await tester.pump();
      await tester.ensureVisible(_noteField);
      await tester.tap(_noteField);
      await tester.pump(_focusSettle);
      final before = _scrollOffsets(tester);

      await tester.pumpAndSettle(_frameStep);

      expect(_scrollOffsets(tester), before);
    }, timeout: uiTestTimeout);

    testWidgets('closing Add before the reveal delay leaves no timer', (
      tester,
    ) async {
      await _openAdd(tester);
      await tester.ensureVisible(_launcher);
      await tester.tap(_launcher);
      await tester.pump();

      await tester.pumpWidget(const SizedBox());

      expect(find.byType(AppSheet), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a new Add starts collapsed', (tester) async {
      final harness = await _openAdd(tester);
      await _activate(tester);
      await cancelEntry(tester, harness);

      await openAdd(tester, harness);

      expect(_launcher, findsOneWidget);
      expect(_strip, findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a disabled preference hides the launcher and the strip', (
      tester,
    ) async {
      await _openAdd(tester, scanEnabled: false);

      expect(_launcher, findsNothing);
      expect(_strip, findsNothing);
      expect(find.text('Add receipt'), findsNothing);
    }, timeout: uiTestTimeout);
  });

  group('expanded actions', () {
    testWidgets('Scan receipt and Upload photo each start one scan', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _activate(tester);

      await tester.tap(find.text('Scan receipt'));
      await tester.pump();
      await tester.tap(find.text('Upload photo'));
      await tester.pump();

      expect(harness.faults.scans, [
        ReceiptScanSource.camera,
        ReceiptScanSource.gallery,
      ]);
    }, timeout: uiTestTimeout);

    testWidgets('scanning disables both actions and shows progress', (
      tester,
    ) async {
      final gate = Completer<void>();
      _mockRecognizer(() async {
        await gate.future;
        return [_line('Coffee Shop')];
      });
      final harness = await _openAdd(tester);
      await _activate(tester);

      harness.form.requestScan(
        ReceiptScanSource.gallery,
        preCapturedBytes: Uint8List(0),
      );
      await _waitForScan(tester, harness, scanning: true);

      for (final label in ['Scan receipt', 'Upload photo']) {
        final button = tester.widget<OutlinedButton>(_action(label));
        expect(button.onPressed, isNull, reason: label);
      }
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await _waitForScan(tester, harness, scanning: false);
    }, timeout: uiTestTimeout);

    testWidgets('a denied permission shows the exact message once', (
      tester,
    ) async {
      PermissionHandlerPlatform.instance = _FakePermissions();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_scannerChannel, (call) async {
            return call.method == 'isAvailable' ? false : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_scannerChannel, null),
      );
      final harness = await _openAdd(tester);
      await _activate(tester);

      await tester.tap(find.text('Scan receipt'));
      await _waitForScan(tester, harness, scanning: false);
      await tester.pump();

      expect(find.text(_permissionMessage), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a scan fills Name, Amount and Date and keeps the rest', (
      tester,
    ) async {
      _mockRecognizer(
        () async => [
          _line('Coffee Shop'),
          _line('Total \$12.50'),
          _line('01/15/2026'),
        ],
      );
      final harness = await _openAdd(tester);
      await _activate(tester);
      harness.form.setNote(_noteText);
      harness.form.setIncludeInAnalysis(false);
      harness.form.applyPickedRecurrence(RecurrenceFrequency.weekly);
      await tester.pumpAndSettle();

      harness.form.requestScan(
        ReceiptScanSource.camera,
        preCapturedBytes: Uint8List(0),
      );
      await _waitForScan(tester, harness, scanning: false);

      final state = _state(harness);
      expect(state.nameText, 'Coffee Shop');
      expect(state.amountText, '12.50');
      expect(state.date, DateTime.utc(2026, 1, 15));
      expect(state.noteText, _noteText);
      expect(state.includeInAnalysis, isFalse);
      expect(state.recurrence, RecurrenceFrequency.weekly);
    }, timeout: uiTestTimeout);
  });
}
