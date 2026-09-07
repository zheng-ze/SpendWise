import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart'
    show EntryFormMode, EntryFormNotifier, EntryFormViewState,
    entryFormViewModelProvider;
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

/// Hand-written fake for the [entryFormViewModelProvider] seam. The strip reads
/// this notifier to start a scan; recording [scanSources] lets a test observe
/// which source a button requested without a mocking library.
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

  // The strip only starts scans. Recording the source here captures the call
  // the button makes without running a real scan or touching a permission
  // handler or image picker.
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          scanStripEnabledProvider.overrideWith((ref) async => enabled),
          if (recorder != null)
            entryFormViewModelProvider.overrideWith2((formKey) => recorder),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ReceiptScanStrip(formKey: null)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both buttons when the setting is on', (tester) async {
    await pumpStrip(tester, enabled: true);

    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
  });

  testWidgets('renders nothing when the setting is off', (tester) async {
    await pumpStrip(tester, enabled: false);

    expect(find.text('Scan receipt'), findsNothing);
    expect(find.text('Upload photo'), findsNothing);
  });

  testWidgets('tapping Upload photo starts a gallery scan', (
    tester,
  ) async {
    final recorder = _RecordingEntryFormNotifier();
    await pumpStrip(tester, enabled: true, recorder: recorder);

    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();

    expect(recorder.scanSources, contains(ReceiptScanSource.gallery));
  });
}
