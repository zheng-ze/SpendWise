import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _recognizerChannel = MethodChannel('spendwise/android_text_recognizer');
const _scannerChannel = MethodChannel('spendwise/document_scanner');
const _scanPoll = Duration(milliseconds: 16);
const _scanPollLimit = 200;
const _permissionMessage = 'Camera or photo library access was denied.';
const _chooserHint = 'Scanning fills in a draft. You check it before saving.';
const _dragDown = Offset(0, 600);
const _outsideTap = Offset(5, 5);
const _noteText = 'keep this note';
const _keyboardHeight = 300.0;

final _launcher = find.byKey(const ValueKey('new-entry-receipt'));
final _chooserHeader = find.byType(AppPickerHeader);
final _analysis = find.byKey(const ValueKey('new-entry-analysis'));

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

Future<void> _openChooser(WidgetTester tester) async {
  await tester.ensureVisible(_launcher);
  await tester.tap(_launcher);
  await tester.pumpAndSettle();
}

Future<void> _waitForScan(
  WidgetTester tester,
  EntryHarness harness, {
  required bool scanning,
}) async {
  await tester.pump();
  for (var i = 0; i < _scanPollLimit; i++) {
    if (_state(harness).scanning == scanning) {
      await tester.pump();
      return;
    }
    await tester.pump(_scanPoll);
  }
  fail('scanning never became $scanning');
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

  group('Add receipt row', () {
    testWidgets('is the last row after Include in analysis', (tester) async {
      await _openAdd(tester);

      expect(_launcher, findsOneWidget);
      final analysis = tester.getTopLeft(_analysis).dy;
      expect(tester.getTopLeft(_launcher).dy, greaterThan(analysis));
    }, timeout: uiTestTimeout);

    testWidgets('is hidden when the preference is off', (tester) async {
      await _openAdd(tester, scanEnabled: false);

      expect(_launcher, findsNothing);
      expect(find.text('Add receipt'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('opening the chooser dismisses the pad for good', (
      tester,
    ) async {
      await _openAdd(tester);
      expect(find.byType(NumberPad), findsOneWidget);

      await _openChooser(tester);
      expect(find.byType(NumberPad), findsNothing);
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsNothing);
    }, timeout: uiTestTimeout);

    for (final field in ['name', 'note']) {
      testWidgets(
        'opening from $field dismisses the IME without restoring it',
        (tester) async {
          await _openAdd(tester);
          final input = find.byKey(ValueKey('new-entry-$field'));
          await tester.ensureVisible(input);
          await tester.tap(input);
          tester.view.viewInsets = const FakeViewPadding(
            bottom: _keyboardHeight,
          );
          await tester.pumpAndSettle();

          await _openChooser(tester);
          expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tester.tapAt(_outsideTap);
          await tester.pumpAndSettle();

          expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
          expect(find.byType(NumberPad), findsNothing);
        },
        timeout: uiTestTimeout,
      );
    }
  });

  group('chooser', () {
    testWidgets('shows the header, hint and two rows with no Cancel', (
      tester,
    ) async {
      final harness = await _openAdd(tester);

      await _openChooser(tester);

      expect(_chooserHeader, findsOneWidget);
      expect(
        tester.widget<AppPickerHeader>(_chooserHeader).title,
        'Add receipt',
      );
      expect(find.text(_chooserHint), findsOneWidget);
      expect(find.text('Scan receipt'), findsOneWidget);
      expect(find.text('Choose photo'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('a drag down dismisses it without a scan', (tester) async {
      final harness = await _openAdd(tester);
      await _openChooser(tester);

      await tester.drag(_chooserHeader, _dragDown);
      await tester.pumpAndSettle();

      expect(find.text('Choose photo'), findsNothing);
      expect(find.text('Add entry'), findsOneWidget);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('an outside tap dismisses it without a scan', (tester) async {
      final harness = await _openAdd(tester);
      await _openChooser(tester);

      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(find.text('Choose photo'), findsNothing);
      expect(find.text('Add entry'), findsOneWidget);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('Scan receipt requests one camera scan and closes', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _openChooser(tester);

      await tester.tap(find.text('Scan receipt'));
      await tester.pumpAndSettle();

      expect(harness.faults.scans, [ReceiptScanSource.camera]);
      expect(find.text('Choose photo'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('Choose photo requests one gallery scan and closes', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _openChooser(tester);

      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      expect(harness.faults.scans, [ReceiptScanSource.gallery]);
      expect(find.text('Scan receipt'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a retired Add leaves no route and starts no scan', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _openChooser(tester);

      addDismiss(tester)();
      await tester.pumpAndSettle();

      expect(harness.faults.scans, isEmpty);
      expect(find.text('Scan receipt'), findsNothing);
      expect(find.byType(AppSheet), findsNothing);
      final sheets = harness.recorder.routes
          .whereType<AppSheetRoute<Object?>>();
      expect(sheets, isEmpty);
      await harness.opened;
    }, timeout: uiTestTimeout);

    testWidgets('retiring before a choice resumes starts no scan', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _openChooser(tester);
      final dismiss = addDismiss(tester);
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Scan receipt'),
      );

      tile.onTap!();
      dismiss();
      await tester.pumpAndSettle();

      expect(harness.faults.scans, isEmpty);
      expect(find.byType(AppSheet), findsNothing);
      await harness.opened;
    }, timeout: uiTestTimeout);

    testWidgets('the chooser retains its root route through live resizing', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      await _openChooser(tester);
      final route = harness.recorder.pickerRoutes.single;

      await resize(tester, openSize);
      expect(harness.recorder.pickerRoutes, [route]);
      final openSheet = tester.getRect(find.byType(AppSheet).last);
      expect(openSheet.left, openSize.width / 2);
      await resize(tester, phoneSize);
      expect(harness.recorder.pickerRoutes, [route]);
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(harness.faults.scans, isEmpty);
      expect(find.byType(NumberPad), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a removed shell leaves the open chooser harmless', (
      tester,
    ) async {
      final harness = await _openAdd(tester);
      harness.faults.swallowScans = true;
      await _openChooser(tester);

      harness.showShell.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan receipt').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.faults.scans, isEmpty);
    }, timeout: uiTestTimeout);
  });

  group('scan results', () {
    testWidgets('the row reads Reading receipt and ignores taps', (
      tester,
    ) async {
      final gate = Completer<void>();
      _mockRecognizer(() async {
        await gate.future;
        return [_line('Coffee Shop')];
      });
      final harness = await _openAdd(tester);

      harness.form.requestScan(
        ReceiptScanSource.gallery,
        preCapturedBytes: Uint8List(0),
      );
      await _waitForScan(tester, harness, scanning: true);
      await tester.ensureVisible(_launcher);
      await tester.tap(_launcher);
      await tester.pump();

      expect(find.text('Reading receipt'), findsOneWidget);
      expect(find.text('Add receipt'), findsNothing);
      final spinner = find.descendant(
        of: _launcher,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(find.text('Choose photo'), findsNothing);
      expect(harness.faults.scans, [ReceiptScanSource.gallery]);

      gate.complete();
      await _waitForScan(tester, harness, scanning: false);
      expect(find.text('Add receipt'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a denied permission shows the exact message once', (
      tester,
    ) async {
      final permissions = PermissionHandlerPlatform.instance;
      PermissionHandlerPlatform.instance = _FakePermissions();
      addTearDown(() => PermissionHandlerPlatform.instance = permissions);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_scannerChannel, (call) async {
            return call.method == 'isAvailable' ? false : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_scannerChannel, null),
      );
      final harness = await _openAdd(tester);
      await _openChooser(tester);

      await tester.tap(find.text('Scan receipt'));
      await _waitForScan(tester, harness, scanning: false);
      await tester.pump();

      expect(find.text(_permissionMessage), findsOneWidget);
      expect(_state(harness).scanStop, isNull);
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
