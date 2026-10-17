import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/add_sheet_dismiss.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import '../../../support/ui_test_timeout.dart';

class _LoadException implements Exception {
  _LoadException(this.message);

  final String message;

  @override
  String toString() => 'LoadException: $message';
}

class _InitFaults {
  bool failInit = false;
  Completer<void>? initGate;
  int builds = 0;
  int binds = 0;
  int prefills = 0;
}

class _SessionForm extends EntryFormNotifier {
  _SessionForm(this.faults) : super(null);

  final _InitFaults faults;

  @override
  Future<EntryFormViewState> build() async {
    faults.builds++;
    final gate = faults.initGate;
    if (gate != null) await gate.future;
    if (faults.failInit) throw _LoadException('deliberate init failure');
    return super.build();
  }

  @override
  void bindAddLifetime(bool Function() isCurrent) {
    faults.binds++;
    super.bindAddLifetime(isCurrent);
  }

  @override
  void prefillSource(String? id) {
    faults.prefills++;
    super.prefillSource(id);
  }
}

class _SessionHost extends ConsumerWidget {
  const _SessionHost({required this.sourceId});

  final String? sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: TextButton(
      onPressed: () => unawaited(
        openNewEntry(context: context, ref: ref, sourceId: sourceId),
      ),
      child: const Text('Open Add'),
    ),
  );
}

const _checkingId = 'a0000000-0000-0000-0000-000000000001';
const _savingsId = 'a0000000-0000-0000-0000-000000000002';
const _coffeeId = 'c0000000-0000-0000-0000-000000000001';

Ledger _buildLedger() {
  final checking = Account(
    id: _checkingId,
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: _savingsId,
    name: 'Savings',
    type: AccountType.savings,
  );
  final coffee = TransactionCategory(
    id: _coffeeId,
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );
  return Ledger(
    state: LedgerState(
      moneySources: {
        checking.id: MoneySource.account(checking),
        savings.id: MoneySource.account(savings),
      },
      categories: {coffee.id: coffee},
    ),
  );
}

Future<ProviderContainer> _pumpSession(
  WidgetTester tester,
  _InitFaults faults,
  Ledger ledger, {
  String? sourceId,
}) async {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      scanStripEnabledProvider.overrideWith((ref) async => false),
      entryFormViewModelProvider(null).overrideWith(() => _SessionForm(faults)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _SessionHost(sourceId: sourceId)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.text('Open Add'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _closeAdd(WidgetTester tester) async {
  await dismissAddSheet(tester);
  await tester.pumpAndSettle();
}

Finder _saveAlert() => find.descendant(
  of: find.byType(SheetAlert),
  matching: find.textContaining('Could not save entry'),
);

Future<void> _pickCoffee(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Category'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Category'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Coffee').last);
  await tester.pumpAndSettle();
}

Future<void> _fillAndSave(
  WidgetTester tester,
  String amount,
  String name,
) async {
  await tester.enterText(find.byType(TextField).at(0), amount);
  await tester.enterText(find.byType(TextField).at(1), name);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Checking'));
  await tester.pumpAndSettle();
  await _pickCoffee(tester);
  await tester.tap(find.text('Save entry'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('failed initialization without automatic retry', () {
    testWidgets(
      'a second Add after a save shows the load alert, not stale state',
      (tester) async {
        final faults = _InitFaults();
        final ledger = _buildLedger();
        await _pumpSession(tester, faults, ledger);
        await _openAdd(tester);
        await _fillAndSave(tester, '12.50', 'Lunch');
        expect(ledger.state.entries.length, 1);

        faults.failInit = true;
        await _openAdd(tester);

        expect(find.byType(AppSheet), findsOneWidget);
        expect(find.text("Couldn't load the entry form"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Lunch'), findsNothing);
        expect(tester.takeException(), isNull);

        await _closeAdd(tester);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('a second Add with a held gate shows the loading shell', (
      tester,
    ) async {
      final faults = _InitFaults();
      final ledger = _buildLedger();
      final container = await _pumpSession(tester, faults, ledger);
      await _openAdd(tester);
      await _fillAndSave(tester, '12.50', 'Lunch');
      expect(ledger.state.entries.length, 1);

      faults.initGate = Completer<void>();
      await tester.tap(find.text('Open Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Lunch'), findsNothing);

      faults.initGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Add entry'), findsOneWidget);
      expect(
        container.read(entryFormViewModelProvider(null)).value?.amountText,
        isEmpty,
      );

      await _closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('a custom Exception keeps the shell with a load alert', (
      tester,
    ) async {
      final faults = _InitFaults()..failInit = true;
      await _pumpSession(tester, faults, _buildLedger());
      await _openAdd(tester);

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);
      expect(find.text("Couldn't load the entry form"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(faults.builds, 1);
      expect(faults.binds, 1);
      expect(faults.prefills, 0);

      await tester.pump(const Duration(seconds: 8));

      expect(faults.builds, 1);
      expect(faults.binds, 1);
      expect(faults.prefills, 0);
      expect(find.text("Couldn't load the entry form"), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, timeout: uiTestTimeout);

    testWidgets(
      'explicit Retry hides the alert while pending and recovers once',
      (tester) async {
        final faults = _InitFaults()..failInit = true;
        final container = await _pumpSession(
          tester,
          faults,
          _buildLedger(),
          sourceId: _checkingId,
        );
        await _openAdd(tester);

        faults.failInit = false;
        faults.initGate = Completer<void>();
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();
        expect(faults.builds, 2);
        expect(faults.binds, 2);
        expect(find.text('Retry'), findsNothing);
        expect(find.text("Couldn't load the entry form"), findsNothing);

        await tester.pump(const Duration(milliseconds: 100));
        expect(faults.builds, 2);
        expect(faults.binds, 2);
        expect(faults.prefills, 0);
        expect(find.text('Retry'), findsNothing);

        faults.initGate!.complete();
        await tester.pumpAndSettle();

        expect(faults.prefills, 1);
        expect(
          container.read(entryFormViewModelProvider(null)).value?.sourceId,
          _checkingId,
        );
        expect(find.text("Couldn't load the entry form"), findsNothing);
        expect(find.text('Add entry'), findsOneWidget);

        await _closeAdd(tester);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('dismissing while loading discards the stale completion', (
      tester,
    ) async {
      final faults = _InitFaults()..initGate = Completer<void>();
      final container = await _pumpSession(
        tester,
        faults,
        _buildLedger(),
        sourceId: _checkingId,
      );
      await _openAdd(tester);
      expect(faults.builds, 1);
      expect(faults.binds, 1);

      await _closeAdd(tester);
      faults.initGate!.complete();
      await tester.pumpAndSettle();

      expect(faults.prefills, 0);
      expect(faults.binds, 1);
      expect(find.byType(AppSheet), findsNothing);

      faults.initGate = null;
      await _openAdd(tester);

      expect(find.text('Add entry'), findsOneWidget);
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        _checkingId,
      );
      expect(faults.prefills, 1);

      await _closeAdd(tester);
    }, timeout: uiTestTimeout);

    testWidgets('a stale step from a retired session pushes nothing', (
      tester,
    ) async {
      final faults = _InitFaults();
      final container = await _pumpSession(tester, faults, _buildLedger());
      await _openAdd(tester);
      final form = container.read(entryFormViewModelProvider(null).notifier);
      await _closeAdd(tester);

      form.requestPickSource();
      await tester.pumpAndSettle();

      expect(find.byType(PickerGroupBody), findsNothing);
      expect(tester.takeException(), isNull);
    }, timeout: uiTestTimeout);
  });

  group('two consecutive creations in one container', () {
    testWidgets('the second Add opens fresh and creates a distinct entry', (
      tester,
    ) async {
      final faults = _InitFaults();
      final ledger = _buildLedger();
      final container = await _pumpSession(tester, faults, ledger);

      await _openAdd(tester);
      await _fillAndSave(tester, '12.50', 'Lunch');
      expect(ledger.state.entries.length, 1);
      final firstId = ledger.state.entries.values.single.id;

      await _openAdd(tester);
      expect(find.text('Add entry'), findsOneWidget);
      expect(faults.builds, 2);

      final fresh = container.read(entryFormViewModelProvider(null)).value!;
      expect(fresh.dismissed, isFalse);
      expect(fresh.amountText, isEmpty);
      expect(fresh.nameText, isEmpty);
      expect(fresh.noteText, isEmpty);
      expect(fresh.sourceId, isNull);
      expect(fresh.destinationId, isNull);
      expect(fresh.categoryId, isNull);
      expect(fresh.recurrence, isNull);
      expect(fresh.hasEndDate, isFalse);
      expect(fresh.endDate, isNull);
      expect(fresh.kind, EntryFormKind.expense);
      expect(fresh.includeInAnalysis, isTrue);
      expect(fresh.error, isNull);
      expect(fresh.step, isNull);
      expect(fresh.scanStop, isNull);
      final now = DateTime.now();
      expect(fresh.date, DateTime.utc(now.year, now.month, now.day));

      await _fillAndSave(tester, '9.99', 'Coffee');
      expect(ledger.state.entries.length, 2);
      final ids = ledger.state.entries.values.map((entry) => entry.id);
      expect(ids, contains(firstId));
      expect(ids.toSet(), hasLength(2));
      final second = ledger.state.entries.values.singleWhere(
        (entry) => entry.id != firstId,
      );
      expect(second.name, 'Coffee');
      expect(second.amount, Decimal.parse('-9.99'));
      expect(second.sourceID, _checkingId);
    }, timeout: uiTestTimeout);
  });

  group('save failure alert', () {
    testWidgets('a save failure keeps the draft and recovers on retry', (
      tester,
    ) async {
      final faults = _InitFaults();
      final ledger = _buildLedger();
      await _pumpSession(tester, faults, ledger);
      await _openAdd(tester);
      await tester.enterText(find.byType(TextField).at(0), '12.50');
      await tester.enterText(find.byType(TextField).at(1), 'New expense');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      await _pickCoffee(tester);
      ledger.deleteAccount(_checkingId);

      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSection), findsNothing);
      expect(_saveAlert(), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'New expense',
      );
      expect(ledger.state.entries, isEmpty);

      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(_saveAlert(), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '12.50',
      );

      final container = ProviderScope.containerOf(
        tester.element(find.text('Add entry')),
      );
      container
          .read(entryFormViewModelProvider(null).notifier)
          .applyPickedSource(_savingsId);
      await _pickCoffee(tester);
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.length, 1);
      expect(find.text('Add entry'), findsNothing);
    }, timeout: uiTestTimeout);
  });
}
