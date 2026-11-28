import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/import/import_file_picker_service.dart';
import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ledger_fixtures.dart';
import '../../support/phone_shell.dart';
import '../../support/xlsx_fixture.dart';

const _flowTimeout = Timeout(Duration(seconds: 30));
const _importRowTitle = 'Import from Money Manager';
const _replaceLabel = 'Replace';
const _cancelLabel = 'Cancel';
const _errorsSheetTitle = "Couldn't import";
const _invalidCurrency = 'USD';
const _outsideSheetTap = Offset(160, 10);
const _viewSize = Size(320, 760);
const _devicePixelRatio = 1.0;

class _CountingPicker implements ImportFilePicker {
  final Completer<Uint8List?> result = Completer<Uint8List?>();
  int pickCalls = 0;

  @override
  Future<Uint8List?> pick() {
    pickCalls++;
    return result.future;
  }
}

class _Harness {
  _Harness._(this.picker, this.ledger, this.container);

  factory _Harness() {
    final picker = _CountingPicker();
    final ledger = Ledger();
    ledger.addAccount(testAccount(name: 'Pre-import'));
    final importer = MoneyManagerImporter(
      ledger: ledger,
      flush: () async {},
      runner: syncImportBuildRunner,
    );
    final container = ProviderContainer(
      overrides: [
        importFilePickerProvider.overrideWithValue(picker),
        moneyManagerImporterProvider.overrideWithValue(importer),
      ],
    );
    addTearDown(container.dispose);
    return _Harness._(picker, ledger, container);
  }

  final _CountingPicker picker;
  final Ledger ledger;
  final ProviderContainer container;

  SettingsRootViewState get state =>
      container.read(settingsRootViewModelProvider);
  SettingsRootNotifier get notifier =>
      container.read(settingsRootViewModelProvider.notifier);
}

Future<void> _pumpFlow(WidgetTester tester, _Harness harness) async {
  tester.view.devicePixelRatio = _devicePixelRatio;
  tester.view.physicalSize = _viewSize;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: buildSpendWiseTheme(Brightness.light),
    home: phoneShell(const SettingsFlow()),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: harness.container, child: app),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapImportRow(WidgetTester tester) async {
  await tester.tap(find.text(_importRowTitle));
}

Future<void> _pickAndOpenConfirmation(
  WidgetTester tester,
  _Harness harness,
  Uint8List bytes,
) async {
  await _tapImportRow(tester);
  harness.picker.result.complete(bytes);
  await tester.pumpAndSettle();
}

Uint8List _invalidFile() {
  return buildMoneyManagerXlsx(
    rows: [moneyManagerRow(currency: _invalidCurrency)],
  );
}

void main() {
  group('SettingsFlow import', () {
    testWidgets('two quick taps while a pick is pending pick once', (
      tester,
    ) async {
      final harness = _Harness();
      await _pumpFlow(tester, harness);

      await _tapImportRow(tester);
      await _tapImportRow(tester);
      await tester.pumpAndSettle();

      expect(harness.picker.pickCalls, 1);
      harness.picker.result.complete(null);
      await tester.pumpAndSettle();
      expect(harness.state.importStatus, ImportStatus.idle);
    }, timeout: _flowTimeout);

    testWidgets('cancelling the confirmation leaves the ledger unchanged', (
      tester,
    ) async {
      final harness = _Harness();
      final revision = harness.ledger.revision;
      await _pumpFlow(tester, harness);
      await _pickAndOpenConfirmation(tester, harness, buildMoneyManagerXlsx());

      await tester.tap(find.text(_cancelLabel));
      await tester.pumpAndSettle();

      expect(harness.ledger.revision, revision);
      expect(harness.state.importStatus, ImportStatus.idle);
    }, timeout: _flowTimeout);

    testWidgets('dismissing the errors sheet clears the import errors', (
      tester,
    ) async {
      final harness = _Harness();
      await _pumpFlow(tester, harness);
      await _pickAndOpenConfirmation(tester, harness, _invalidFile());
      await tester.tap(find.text(_replaceLabel));
      await tester.pumpAndSettle();
      expect(find.text(_errorsSheetTitle), findsOneWidget);
      expect(harness.state.importErrors, isNotEmpty);

      await tester.tapAt(_outsideSheetTap);
      await tester.pumpAndSettle();

      expect(find.text(_errorsSheetTitle), findsNothing);
      expect(harness.state.importErrors, isEmpty);
    }, timeout: _flowTimeout);

    testWidgets('a held errors step shows once when the flow mounts', (
      tester,
    ) async {
      final harness = _Harness();
      final hold = harness.container.listen(
        settingsRootViewModelProvider,
        (_, _) {},
      );
      addTearDown(hold.close);
      harness.notifier.requestImport();
      harness.notifier.applyPickedFile(pickerError: StateError('no picker'));
      expect(harness.state.step, isA<ImportErrorsRequested>());

      await _pumpFlow(tester, harness);

      expect(find.text(_errorsSheetTitle), findsOneWidget);
      expect(harness.state.step, isNull);
      await tester.tapAt(_outsideSheetTap);
      await tester.pumpAndSettle();
      expect(find.text(_errorsSheetTitle), findsNothing);
    }, timeout: _flowTimeout);
  });
}
