import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/add_sheet_dismiss.dart';

import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/document_crop/document_crop_screen.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../../support/ui_test_timeout.dart';

const _mlKitChannel = MethodChannel('spendwise/android_text_recognizer');
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

class _DeniedPermissions extends PermissionHandlerPlatform {
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {permissions.first: PermissionStatus.denied};
  }
}

class _InitFailure implements Exception {
  const _InitFailure();
}

class _ThrowOnceFormNotifier extends EntryFormNotifier {
  _ThrowOnceFormNotifier(this.shouldThrow) : super(null);

  final bool Function() shouldThrow;

  @override
  Future<EntryFormViewState> build() async {
    if (shouldThrow()) throw const _InitFailure();
    return super.build();
  }
}

Future<Uint8List> _solidPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 20, 20),
    Paint()..color = const Color(0xFF0000FF),
  );
  final image = await recorder.endRecording().toImage(20, 20);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Decimal dec(String value) => Decimal.parse(value);

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
    Size? size,
    bool scanStripEnabled = true,
  }) async {
    registerSheetTearDown(tester);
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
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

  group('opening through TransactionsFlow', () {
    testWidgets('unscoped Add opens the sheet with no source prefill', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Save entry'), findsOneWidget);
      expect(
        containerOf(tester)
            .read(entryFormViewModelProvider(null))
            .value
            ?.sourceId,
        isNull,
      );

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('Cancel dismisses without creating an entry', (tester) async {
      final ledger = buildLedger();
      await pumpFlow(tester, ledger: ledger);
      await openAdd(tester);

      await closeAdd(tester);

      expect(find.text('Add entry'), findsNothing);
      expect(ledger.state.entries, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('the ViewModel cancel closes the sheet without an entry', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpFlow(tester, ledger: ledger);
      await openAdd(tester);

      containerOf(tester)
          .read(entryFormViewModelProvider(null).notifier)
          .cancel();
      await tester.pumpAndSettle();

      expect(find.text('Add entry'), findsNothing);
      expect(ledger.state.entries, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('barrier dismissal closes the sheet without an entry', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpFlow(tester, ledger: ledger);
      await openAdd(tester);
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 30));
      await tester.pumpAndSettle();

      expect(find.text('Add entry'), findsNothing);
      expect(ledger.state.entries, isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets(
      'one source step pushes one picker above the sheet and applies it',
      (tester) async {
        await pumpFlow(tester, ledger: buildLedger());
        await openAdd(tester);

        await revealRow(tester, 'Account');
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();

        expect(find.byType(PickerGroupBody), findsOneWidget);
        expect(find.byType(AppSheet), findsNWidgets(2));

        await tester.tap(find.text('Checking'));
        await tester.pumpAndSettle();

        expect(find.byType(PickerGroupBody), findsNothing);
        expect(find.byType(AppSheet), findsOneWidget);
        expect(
          containerOf(tester)
              .read(entryFormViewModelProvider(null))
              .value
              ?.sourceId,
          checking.id,
        );

        await closeAdd(tester);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('picker Back keeps the sheet with the field unchanged', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);

      await revealRow(tester, 'Account');
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byType(PickerGroupBody), findsOneWidget);

      await popTopSheet(tester, PickerGroupBody);

      expect(find.byType(PickerGroupBody), findsNothing);
      expect(find.text('Add entry'), findsOneWidget);
      expect(find.text('Select'), findsWidgets);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('destination, category and recurrence open above the sheet', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);
      final container = containerOf(tester);
      container
          .read(entryFormViewModelProvider(null).notifier)
          .setKind(EntryFormKind.transfer);
      await tester.pumpAndSettle();

      await revealRow(tester, 'To');
      await tester.tap(find.text('To'));
      await tester.pumpAndSettle();
      expect(find.byType(PickerGroupBody), findsOneWidget);
      expect(find.byType(AppSheet), findsNWidgets(2));
      await popTopSheet(tester, PickerGroupBody);

      container
          .read(entryFormViewModelProvider(null).notifier)
          .setKind(EntryFormKind.expense);
      await tester.pumpAndSettle();
      await revealRow(tester, 'Category');
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.categoryId,
        coffee.id,
      );

      await revealRow(tester, 'Date');
      await tester.tap(find.byTooltip('Repeat'));
      await tester.pumpAndSettle();
      expect(find.text('Repeat'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Monthly'));
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.recurrence,
        RecurrenceFrequency.monthly,
      );

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('the date picker opens above the sheet and cancels cleanly', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);

      await revealRow(tester, 'Date');
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerSheet), findsOneWidget);
      expect(find.byType(AppSheet), findsNWidgets(2));

      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerSheet),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerSheet), findsNothing);
      expect(find.text('Add entry'), findsOneWidget);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('the end-date picker opens once recurrence has an end', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);
      final container = containerOf(tester);
      final viewModel = container.read(
        entryFormViewModelProvider(null).notifier,
      );
      viewModel.applyPickedRecurrence(RecurrenceFrequency.monthly);
      viewModel.setEndDateEnabled(true);
      await tester.pumpAndSettle();

      await revealRow(tester, 'End date');
      await tester.tap(find.text('End date'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerSheet),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('a crop request pushes the crop screen above the sheet', (
      tester,
    ) async {
      await pumpFlow(tester, ledger: buildLedger());
      await openAdd(tester);
      final container = containerOf(tester);

      final png = await tester.runAsync<Uint8List>(() => _solidPng());
      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestDocumentCrop(png!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DocumentCropScreen), findsOneWidget);
      expect(find.text('Add entry', skipOffstage: false), findsOneWidget);

      await popTopSheet(tester, DocumentCropScreen);
      expect(find.byType(DocumentCropScreen), findsNothing);
      expect(find.text('Add entry'), findsOneWidget);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('a valid save adds one entry and dismisses the sheet', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpFlow(tester, ledger: ledger);
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
      final added = ledger.state.entries.values.first;
      expect(added.name, 'New expense');
      expect(added.amount, dec('-12.50'));
      expect(find.text('Add entry'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a save failure keeps the form with its error section', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpFlow(tester, ledger: ledger);
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
      ledger.deleteAccount(checking.id);

      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSection), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SheetAlert),
          matching: find.textContaining('Could not save entry'),
        ),
        findsOneWidget,
      );
      expect(find.text('Add entry'), findsOneWidget);
      expect(ledger.state.entries, isEmpty);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets(
      'edit-form pickers stay nested while Add pickers use the root navigator',
      (tester) async {
        final savings = Account(
          id: 'b0000000-0000-0000-0000-000000000002',
          name: 'Savings',
          type: AccountType.savings,
        );
        final today = DateTime.now();
        final entry = Entry(
          amount: dec('-5'),
          name: 'Coffee run',
          sourceID: savings.id,
          date: DateTime.utc(today.year, today.month, 1),
        );
        final ledger = Ledger(
          state: LedgerState(
            moneySources: {
              checking.id: MoneySource.account(checking),
              savings.id: MoneySource.account(savings),
            },
            categories: {coffee.id: coffee},
            entries: {entry.id: entry},
          ),
        );
        await pumpFlow(tester, ledger: ledger);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransactionsFlow)),
        );

        await tester.tap(find.text('Coffee run'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await revealRow(tester, 'Account');
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();

        expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
        final nestedPicker = tester.element(find.byType(TwoColumnPickerSheet));
        expect(
          identical(
            Navigator.of(nestedPicker),
            Navigator.of(nestedPicker, rootNavigator: true),
          ),
          isFalse,
        );

        await tester.tap(find.text('Checking'));
        await tester.pumpAndSettle();
        expect(
          container.read(entryFormViewModelProvider(entry.id)).value?.sourceId,
          checking.id,
        );

        await revealRow(tester, 'Delete Entry');
        await tester.tap(find.text('Delete Entry'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Entry'), findsNothing);

        await openAdd(tester);
        await revealRow(tester, 'Account');
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();

        expect(find.byType(PickerGroupBody), findsOneWidget);
        final rootPicker = tester.element(find.byType(PickerGroupBody));
        expect(
          identical(
            Navigator.of(rootPicker),
            Navigator.of(rootPicker, rootNavigator: true),
          ),
          isTrue,
        );

        await popTopSheet(tester, PickerGroupBody);
        await closeAdd(tester);
      },
      timeout: uiTestTimeout,
    );
  });

  group('presentation follows the layout mode at one size', () {
    const size = Size(600, 800);

    testWidgets('phone mode spans the bottom at full width', (tester) async {
      await pumpFlow(
        tester,
        ledger: buildLedger(),
        mode: ShellLayoutMode.phone,
        size: size,
      );
      await openAdd(tester);

      final rect = tester.getRect(find.byType(AppSheet));
      expect(rect.left, 0);
      expect(rect.right, size.width);
      expect(rect.bottom, size.height);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('desktop mode centres a dialog no wider than 440', (
      tester,
    ) async {
      await pumpFlow(
        tester,
        ledger: buildLedger(),
        mode: ShellLayoutMode.desktop,
        size: size,
      );
      await openAdd(tester);

      final rect = tester.getRect(find.byType(AppSheet));
      expect(rect.center, Offset(size.width / 2, size.height / 2));
      expect(rect.width, lessThanOrEqualTo(440));

      await closeAdd(tester);
    }, timeout: uiTestTimeout);
  });

  group('reset, guard and subscription cleanup', () {
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

    testWidgets('reopening after save starts with a fresh form', (
      tester,
    ) async {
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
        expect(
          find.byType(PickerGroupBody, skipOffstage: false),
          findsOneWidget,
        );
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
      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickDate();
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }, timeout: uiTestTimeout);

    testWidgets('a failed presentation is reported and releases the guard', (
      tester,
    ) async {
      registerSheetTearDown(tester);
      WidgetRef? stashedRef;
      BuildContext? stashedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerProvider.overrideWithValue(buildLedger()),
            scanStripEnabledProvider.overrideWith((ref) async => true),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              stashedContext = context;
              stashedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final reported = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = reported.add;
      try {
        await openNewEntry(context: stashedContext!, ref: stashedRef!);
      } finally {
        FlutterError.onError = originalOnError;
      }
      expect(reported, hasLength(1));

      final container = ProviderScope.containerOf(stashedContext!);
      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickDate();
      await tester.pump();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.step,
        isNotNull,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ledgerProvider.overrideWithValue(buildLedger()),
            scanStripEnabledProvider.overrideWith((ref) async => true),
          ],
          child: const MaterialApp(home: _PresenterHost()),
        ),
      );
      await tester.pumpAndSettle();
      await openAdd(tester);

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);

      await closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets(
      'a failed initialization keeps the shell with a load alert and Retry',
      (tester) async {
        registerSheetTearDown(tester);
        var shouldThrow = true;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ledgerProvider.overrideWithValue(buildLedger()),
              scanStripEnabledProvider.overrideWith((ref) async => true),
              entryFormViewModelProvider(
                null,
              ).overrideWith(() => _ThrowOnceFormNotifier(() => shouldThrow)),
            ],
            child: MaterialApp(home: _PresenterHost()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Add'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.byType(AppSheet), findsOneWidget);
        expect(find.text('Add entry'), findsOneWidget);
        expect(find.text("Couldn't load the entry form"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(tester.takeException(), isNull);

        shouldThrow = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSheet), findsOneWidget);
        expect(find.text('Add entry'), findsOneWidget);
        expect(find.text("Couldn't load the entry form"), findsNothing);

        await closeAdd(tester);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('reopening resets a finished receipt session', (tester) async {
      final originalPermissions = PermissionHandlerPlatform.instance;
      PermissionHandlerPlatform.instance = _DeniedPermissions();
      addTearDown(() {
        PermissionHandlerPlatform.instance = originalPermissions;
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
        stopAfterScan = container
            .read(receiptEntryCoordinatorProvider(null))
            .scanStop;
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
  });

  group('receipt coordinator disposal', () {
    Map<String, dynamic> line(String text) => {
      'text': text,
      'left': 0.0,
      'top': 0.0,
      'right': 100.0,
      'bottom': 100.0,
      'confidence': 0.9,
    };

    test(
      'a stale scan finishing after a newer scan starts writes nothing',
      () async {
        final gates = <Completer<void>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_mlKitChannel, (call) async {
              final gate = Completer<void>();
              gates.add(gate);
              await gate.future;
              return [
                line('Coffee Shop'),
                line('Total \$12.50'),
                line('01/15/2026'),
              ];
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_mlKitChannel, null);
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
        expect(draft['amount'], dec('12.50'));
        expect(draft['date'], isA<DateTime>());
      },
    );
  });
}
