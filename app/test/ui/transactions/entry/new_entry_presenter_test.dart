import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../../support/add_sheet_dismiss.dart';
import '../../../support/image_picker_channel.dart';
import '../../../support/ui_test_timeout.dart';

const _mlKitChannel = MethodChannel('spendwise/android_text_recognizer');
const _cameraDenied = 'camera_access_denied';
const _documentScannerChannel = MethodChannel('spendwise/document_scanner');

class _PresenterHost extends ConsumerWidget {
  const _PresenterHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => unawaited(openNewEntry(context: context, ref: ref)),
          child: const Text('Open Add'),
        ),
        const Expanded(child: TransactionsFlow()),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final coffee = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {checking.id: MoneySource.account(checking)},
        categories: {coffee.id: coffee},
        entries: entries,
      ),
    );
  }

  void registerSheetTearDown(WidgetTester tester) {
    addTearDown(() async {
      final sheets = find.byType(AppSheet, skipOffstage: false);
      while (sheets.evaluate().isNotEmpty) {
        Navigator.of(tester.element(sheets.last), rootNavigator: true).pop();
        await tester.pumpAndSettle();
      }
    });
  }

  Future<void> pumpFlow(
    WidgetTester tester, {
    required Ledger ledger,
    ShellLayoutMode? mode,
    bool scanStripEnabled = true,
  }) async {
    registerSheetTearDown(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          scanStripEnabledProvider.overrideWith(
            (ref) async => scanStripEnabled,
          ),
          if (mode != null) shellLayoutModeProvider.overrideWithValue(mode),
        ],
        child: const MaterialApp(home: _PresenterHost()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();
  }

  Future<void> closeAdd(WidgetTester tester) async {
    await dismissAddSheet(tester);
    await tester.pumpAndSettle();
  }

  Future<void> revealRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> pickCoffee(WidgetTester tester) async {
    await revealRow(tester, 'Category');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.text('Add entry')));

  Future<void> popTopSheet(WidgetTester tester, Type content) async {
    await Navigator.of(tester.element(find.byType(content))).maybePop();
    await tester.pumpAndSettle();
  }

  Future<void> saveOneEntry(WidgetTester tester, Ledger ledger) async {
    await openAdd(tester);
    await tester.enterText(find.byType(TextField).at(0), '12.50');
    await tester.enterText(find.byType(TextField).at(1), 'New expense');
    await tester.pumpAndSettle();
    await revealRow(tester, 'Account');
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await pickCoffee(tester);
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(ledger.state.entries.length, 1);
  }

  testWidgets('reopening after save starts with a fresh form', (tester) async {
    final ledger = buildLedger();
    await pumpFlow(tester, ledger: ledger);
    await saveOneEntry(tester, ledger);

    await openAdd(tester);
    final state = containerOf(tester)
        .read(entryFormViewModelProvider(null))
        .value!;
    expect(state.dismissed, isFalse);
    expect(state.amountText, isEmpty);
    expect(state.nameText, isEmpty);
    expect(state.sourceId, isNull);

    await closeAdd(tester);
  }, timeout: uiTestTimeout);

  testWidgets('reopening after cancel starts with a fresh form', (
    tester,
  ) async {
    await pumpFlow(tester, ledger: buildLedger());
    await openAdd(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Draft name');
    await tester.pumpAndSettle();
    await closeAdd(tester);

    await openAdd(tester);
    final state = containerOf(tester)
        .read(entryFormViewModelProvider(null))
        .value!;
    expect(state.nameText, isEmpty);

    await closeAdd(tester);
  }, timeout: uiTestTimeout);

  testWidgets('duplicate requests open a single sheet', (tester) async {
    registerSheetTearDown(tester);
    late WidgetRef stashedRef;
    late BuildContext stashedContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          scanStripEnabledProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              stashedContext = context;
              stashedRef = ref;
              return TransactionsFlow();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstOpen = openNewEntry(context: stashedContext, ref: stashedRef);
    final duplicateOpen = openNewEntry(
      context: stashedContext,
      ref: stashedRef,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet, skipOffstage: false), findsOneWidget);
    await duplicateOpen;

    final form = containerOf(tester)
        .read(entryFormViewModelProvider(null).notifier);
    for (var i = 0; i < 2; i++) {
      form.requestPickSource();
      await tester.pumpAndSettle();
      expect(find.byType(PickerGroupBody, skipOffstage: false), findsOneWidget);
      await popTopSheet(tester, PickerGroupBody);
      expect(find.byType(PickerGroupBody, skipOffstage: false), findsNothing);
    }

    await closeAdd(tester);
    await firstOpen;
    expect(find.text('Add entry'), findsNothing);

    final reopened = openNewEntry(context: stashedContext, ref: stashedRef);
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet, skipOffstage: false), findsOneWidget);

    await closeAdd(tester);
    await reopened;
  }, timeout: uiTestTimeout);

  testWidgets('a step emitted after close pushes nothing', (tester) async {
    await pumpFlow(tester, ledger: buildLedger());
    await openAdd(tester);
    await closeAdd(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TransactionsFlow)),
    );
    container.read(entryFormViewModelProvider(null).notifier).requestPickDate();
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerSheet), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('reopening resets a finished receipt session', (tester) async {
    mockImagePickerResult(errorCode: _cameraDenied);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_mlKitChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_documentScannerChannel, null);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_documentScannerChannel, (call) async {
          if (call.method == 'isAvailable') return false;
          return null;
        });

    await pumpFlow(
      tester,
      ledger: buildLedger(),
      mode: ShellLayoutMode.phone,
      scanStripEnabled: false,
    );
    await openAdd(tester);
    final container = containerOf(tester);
    ReceiptScanStop? stopAfterScan;
    container.listen(receiptEntryCoordinatorProvider(null), (_, next) {
      stopAfterScan = next.scanStop ?? stopAfterScan;
    });
    await tester.runAsync(() async {
      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestScan(ReceiptScanSource.camera);
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(receiptEntryCoordinatorProvider(null)).scanning) {
          break;
        }
      }
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!container.read(receiptEntryCoordinatorProvider(null)).scanning) {
          break;
        }
      }
    });
    expect(stopAfterScan, ReceiptScanStop.permissionDenied);
    await closeAdd(tester);

    await openAdd(tester);
    final fresh = containerOf(tester)
        .read(receiptEntryCoordinatorProvider(null));
    expect(fresh.scanning, isFalse);
    expect(fresh.scanStop, isNull);

    await closeAdd(tester);
  }, timeout: uiTestTimeout);

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
