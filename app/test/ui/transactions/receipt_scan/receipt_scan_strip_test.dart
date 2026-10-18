import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart'
    show
        EntryFormMode,
        EntryFormNotifier,
        EntryFormViewState,
        entryFormViewModelProvider;
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

import '../../../support/ui_test_timeout.dart';

const _wideWidth = 400.0;
const _narrowWidth = 182.0;
const _largeText = 1.5;

class _RecordingEntryFormNotifier extends EntryFormNotifier {
  _RecordingEntryFormNotifier() : super(null);

  final List<ReceiptScanSource> scanSources = [];

  @override
  Future<EntryFormViewState> build() async => EntryFormViewState(
    mode: EntryFormMode.newEntry,
    kind: EntryFormKind.expense,
    amountText: '',
    nameText: '',
    date: DateTime.utc(2026, 1, 1),
    sourceId: null,
    destinationId: null,
    categoryId: null,
    includeInAnalysis: true,
    recurrence: null,
    hasEndDate: false,
    endDate: null,
    isSystemEntry: false,
    entryId: null,
  );

  @override
  void requestScan(ReceiptScanSource source, {Uint8List? preCapturedBytes}) {
    scanSources.add(source);
  }
}

void main() {
  Ledger buildLedger() {
    final account = Account(name: 'Checking', type: AccountType.checking);
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
  }

  Future<void> pumpStrip(
    WidgetTester tester, {
    required bool enabled,
    _RecordingEntryFormNotifier? recorder,
    bool compactActions = false,
    double width = _wideWidth,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          scanStripEnabledProvider.overrideWith((ref) async => enabled),
          if (recorder != null)
            entryFormViewModelProvider.overrideWith2((formKey) => recorder),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ReceiptScanStrip(
                  formKey: null,
                  compactActions: compactActions,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both buttons when the setting is on', (tester) async {
    await pumpStrip(tester, enabled: true);

    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('renders nothing when the setting is off', (tester) async {
    await pumpStrip(tester, enabled: false);

    expect(find.text('Scan receipt'), findsNothing);
    expect(find.text('Upload photo'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('tapping Upload photo starts a gallery scan', (tester) async {
    final recorder = _RecordingEntryFormNotifier();
    await pumpStrip(tester, enabled: true, recorder: recorder);

    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();

    expect(recorder.scanSources, contains(ReceiptScanSource.gallery));
  }, timeout: uiTestTimeout);

  testWidgets(
    'compact actions stack at 182 dp and 1.5x text without overflow',
    (tester) async {
      await pumpStrip(
        tester,
        enabled: true,
        compactActions: true,
        width: _narrowWidth,
        textScale: _largeText,
      );

      expect(tester.takeException(), isNull);
      final scan = tester.getRect(find.text('Scan receipt'));
      final upload = tester.getRect(find.text('Upload photo'));
      expect(upload.top, greaterThan(scan.bottom));
      expect(upload.right, lessThanOrEqualTo(_narrowWidth));
    },
    timeout: uiTestTimeout,
  );

  testWidgets('the default actions share one row', (tester) async {
    await pumpStrip(tester, enabled: true);

    final scan = tester.getRect(find.text('Scan receipt'));
    final upload = tester.getRect(find.text('Upload photo'));
    expect(upload.top, scan.top);
  }, timeout: uiTestTimeout);
}
