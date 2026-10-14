import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

const _phoneSize = Size(400, 800);
const _openSize = Size(960, 720);

class _RouteRecorder extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  List<AppSheetRoute<dynamic>> get sheets =>
      routes.whereType<AppSheetRoute<dynamic>>().toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) routes.remove(oldRoute);
    if (newRoute != null) routes.add(newRoute);
  }
}

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

class _BuildProbe extends ConsumerWidget {
  const _BuildProbe({required this.onBuilt, required this.child});

  final void Function(BuildContext context, WidgetRef ref) onBuilt;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt(context, ref);
    return child;
  }
}

Map<ShellDestination, WidgetBuilder> _probeBodies() => {
  ShellDestination.overview: (_) => const _Probe('overview probe'),
  ShellDestination.history: (_) => const _Probe('history probe'),
  ShellDestination.trends: (_) => const _Probe('trends probe'),
  ShellDestination.money: (_) => const _Probe('money probe'),
  ShellDestination.settings: (_) => const _Probe('settings probe'),
};

Ledger _buildLedger() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'b0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const checkingId = 'a0000000-0000-0000-0000-000000000001';
  const savingsId = 'b0000000-0000-0000-0000-000000000002';
  const coffeeId = 'c0000000-0000-0000-0000-000000000001';

  Future<ProviderContainer> pumpLiveShell(
    WidgetTester tester, {
    required Size size,
    required _RouteRecorder recorder,
    TargetPlatform platform = TargetPlatform.iOS,
    Ledger? ledger,
    String? Function()? moneySourceId,
    void Function(BuildContext context, WidgetRef ref)? onBuilt,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellPlatformProvider.overrideWithValue((
          isWeb: false,
          targetPlatform: platform,
        )),
        ledgerProvider.overrideWithValue(ledger ?? _buildLedger()),
        scanStripEnabledProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      while (find.byType(AppSheet, skipOffstage: false).evaluate().isNotEmpty) {
        Navigator.of(
          tester.element(find.byType(AppSheet, skipOffstage: false).last),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: buildShellAppContent,
          navigatorObservers: [recorder],
          home: _BuildProbe(
            onBuilt: onBuilt ?? (_, _) {},
            child: AppShell(
              bodies: _probeBodies(),
              moneySourceId: moneySourceId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  ProviderContainer containerOfSheet(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.text('Add entry')));

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Future<void> closeAdd(WidgetTester tester) async {
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  Future<void> revealRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> tapSegment(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  ShellLayoutMode scopeMode(WidgetTester tester) =>
      ShellLayoutModeScope.of(tester.element(find.text('Add entry')));

  Map<String, Object?> draftSnapshot(ProviderContainer container) {
    final state = container.read(entryFormViewModelProvider(null)).value!;
    return {
      'kind': state.kind,
      'amount': state.amountText,
      'name': state.nameText,
      'date': state.date,
      'source': state.sourceId,
      'destination': state.destinationId,
      'category': state.categoryId,
      'recurrence': state.recurrence,
      'included': state.includeInAnalysis,
    };
  }

  group('live Add presentation across phone and open', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform draft survives phone-open-phone crossings', (
        tester,
      ) async {
        final recorder = _RouteRecorder();
        await pumpLiveShell(
          tester,
          size: _phoneSize,
          recorder: recorder,
          platform: platform,
        );
        await openAdd(tester);

        await tester.enterText(find.byType(TextField).at(0), '12.50');
        await tester.enterText(find.byType(TextField).at(1), 'New expense');
        await tester.pumpAndSettle();
        await tapSegment(tester, 'Transfer');
        await revealRow(tester, 'From');
        await tester.tap(find.text('From'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checking'));
        await tester.pumpAndSettle();
        await revealRow(tester, 'To');
        await tester.tap(find.text('To'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Savings'));
        await tester.pumpAndSettle();

        final container = containerOfSheet(tester);
        final transferDraft = draftSnapshot(container);
        expect(transferDraft['source'], checkingId);
        expect(transferDraft['destination'], savingsId);
        expect(recorder.sheets, hasLength(1));
        final route = recorder.sheets.single;

        await resize(tester, _openSize);
        expect(scopeMode(tester), ShellLayoutMode.open);
        expect(find.text('Add entry'), findsOneWidget);
        expect(draftSnapshot(containerOfSheet(tester)), transferDraft);
        expect(recorder.sheets.single, same(route));

        await resize(tester, _phoneSize);
        expect(scopeMode(tester), ShellLayoutMode.phone);
        expect(find.text('Add entry'), findsOneWidget);
        expect(draftSnapshot(containerOfSheet(tester)), transferDraft);
        expect(recorder.sheets.single, same(route));

        await tapSegment(tester, 'Expense');
        await revealRow(tester, 'Category');
        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Coffee'));
        await tester.pumpAndSettle();
        await revealRow(tester, 'Date');
        await tester.tap(find.byTooltip('Repeat'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Monthly'));
        await tester.pumpAndSettle();
        await revealRow(tester, 'Include in Analysis');
        await tester.tap(find.text('Include in Analysis'));
        await tester.pumpAndSettle();

        final expenseDraft = draftSnapshot(containerOfSheet(tester));
        expect(expenseDraft['category'], coffeeId);
        expect(expenseDraft['recurrence'], RecurrenceFrequency.monthly);
        expect(expenseDraft['included'], isFalse);

        await resize(tester, _openSize);
        expect(find.text('Add entry'), findsOneWidget);
        expect(draftSnapshot(containerOfSheet(tester)), expenseDraft);
        expect(recorder.sheets.single, same(route));

        await resize(tester, _phoneSize);
        expect(find.text('Add entry'), findsOneWidget);
        expect(draftSnapshot(containerOfSheet(tester)), expenseDraft);
        expect(recorder.sheets.single, same(route));

        await closeAdd(tester);
      });
    }

    testWidgets('form state, controllers, selection and focus survive a '
        'phone-to-open-to-phone crossing', (tester) async {
      final recorder = _RouteRecorder();
      await pumpLiveShell(tester, size: _phoneSize, recorder: recorder);
      await openAdd(tester);

      await tester.enterText(find.byType(TextField).at(0), '12.50');
      await tester.enterText(find.byType(TextField).at(1), 'New expense');
      await tester.pumpAndSettle();
      final nameController = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller!;
      nameController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.tap(find.byType(TextField).at(0));
      await tester.pump();
      await revealRow(tester, 'Include in Analysis');

      final formStateBefore = tester.state(find.byType(EntryFields));
      final amountControllerBefore = tester
          .widget<TextField>(find.byType(TextField).at(0))
          .controller;
      final focusedBefore = FocusManager.instance.primaryFocus;
      expect(focusedBefore, isNotNull);
      final scroller = Scrollable.of(
        tester.element(find.text('Include in Analysis')),
      );

      await resize(tester, _openSize);
      expect(scopeMode(tester), ShellLayoutMode.open);

      expect(tester.state(find.byType(EntryFields)), same(formStateBefore));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller,
        same(amountControllerBefore),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller,
        same(nameController),
      );
      expect(nameController.selection.baseOffset, 0);
      expect(nameController.selection.extentOffset, 3);
      expect(FocusManager.instance.primaryFocus, same(focusedBefore));
      expect(
        Scrollable.of(tester.element(find.text('Include in Analysis'))),
        same(scroller),
      );

      await resize(tester, _phoneSize);
      expect(tester.state(find.byType(EntryFields)), same(formStateBefore));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller,
        same(nameController),
      );
      expect(FocusManager.instance.primaryFocus, same(focusedBefore));

      await closeAdd(tester);
    });

    testWidgets('Add opened in open mode keeps one route and one step '
        'subscription across crossings', (tester) async {
      final recorder = _RouteRecorder();
      await pumpLiveShell(tester, size: _openSize, recorder: recorder);
      await openAdd(tester);
      expect(scopeMode(tester), ShellLayoutMode.open);

      final container = containerOfSheet(tester);
      final coordinatorBefore = container.read(
        receiptEntryCoordinatorProvider(null),
      );
      expect(recorder.sheets, hasLength(1));
      final route = recorder.sheets.single;
      final selectionBefore = container.read(selectedDestinationProvider);

      await tester.enterText(find.byType(TextField).at(0), '12.50');
      await tester.pumpAndSettle();

      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickSource();
      await tester.pumpAndSettle();
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        checkingId,
      );

      await resize(tester, _phoneSize);
      expect(recorder.sheets.single, same(route));
      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickSource();
      await tester.pumpAndSettle();
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      await tester.tap(find.text('Savings'));
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        savingsId,
      );

      await resize(tester, _openSize);
      expect(recorder.sheets.single, same(route));
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        savingsId,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '12.50',
      );
      expect(
        container.read(receiptEntryCoordinatorProvider(null)),
        same(coordinatorBefore),
      );
      expect(container.read(selectedDestinationProvider), selectionBefore);

      await closeAdd(tester);
    });

    testWidgets('an open picker keeps its route and its result reaches the '
        'same draft across resize', (tester) async {
      final recorder = _RouteRecorder();
      await pumpLiveShell(tester, size: _phoneSize, recorder: recorder);
      await openAdd(tester);

      await revealRow(tester, 'Account');
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      final pickerRoute = ModalRoute.of(
        tester.element(find.byType(TwoColumnPickerSheet)),
      );
      final sheetRoute = recorder.sheets.single;

      await resize(tester, _openSize);
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(TwoColumnPickerSheet))),
        same(pickerRoute),
      );
      expect(recorder.sheets.single, same(sheetRoute));

      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(find.byType(TwoColumnPickerSheet), findsNothing);
      expect(
        containerOfSheet(tester)
            .read(entryFormViewModelProvider(null))
            .value
            ?.sourceId,
        checkingId,
      );

      await closeAdd(tester);
    });

    testWidgets('a Money scoped source is captured once and survives resize', (
      tester,
    ) async {
      final recorder = _RouteRecorder();
      await pumpLiveShell(
        tester,
        size: _phoneSize,
        recorder: recorder,
        moneySourceId: () => checkingId,
      );

      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
      await openAdd(tester);
      final container = containerOfSheet(tester);
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        checkingId,
      );
      final coordinatorBefore = container.read(
        receiptEntryCoordinatorProvider(null),
      );

      await resize(tester, _openSize);
      expect(
        containerOfSheet(tester)
            .read(entryFormViewModelProvider(null))
            .value
            ?.sourceId,
        checkingId,
      );

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.trends;
      await tester.pumpAndSettle();
      expect(
        containerOfSheet(tester)
            .read(entryFormViewModelProvider(null))
            .value
            ?.sourceId,
        checkingId,
      );
      expect(
        containerOfSheet(tester).read(receiptEntryCoordinatorProvider(null)),
        same(coordinatorBefore),
      );

      await resize(tester, _phoneSize);
      expect(
        containerOfSheet(tester)
            .read(entryFormViewModelProvider(null))
            .value
            ?.sourceId,
        checkingId,
      );

      await closeAdd(tester);
    });
  });

  group('presenter guard and teardown under resize', () {
    testWidgets('duplicate requests across a resize open a single sheet', (
      tester,
    ) async {
      final recorder = _RouteRecorder();
      late BuildContext stashedContext;
      late WidgetRef stashedRef;
      await pumpLiveShell(
        tester,
        size: _phoneSize,
        recorder: recorder,
        onBuilt: (context, ref) {
          stashedContext = context;
          stashedRef = ref;
        },
      );

      final firstOpen = openNewEntry(context: stashedContext, ref: stashedRef);
      final duplicateOpen = openNewEntry(
        context: stashedContext,
        ref: stashedRef,
      );
      tester.view.physicalSize = _openSize;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet, skipOffstage: false), findsOneWidget);
      expect(recorder.sheets, hasLength(1));
      expect(
        containerOfSheet(tester).read(newEntryPresentationProvider),
        NewEntryPresentation.presented,
      );

      await closeAdd(tester);
      await firstOpen;
      expect(recorder.sheets, isEmpty);
      await duplicateOpen;

      await openAdd(tester);
      expect(find.byType(AppSheet), findsOneWidget);
      await closeAdd(tester);
    });

    testWidgets('repeated crossings add no form, coordinator, prefill or '
        'subscription work', (tester) async {
      final recorder = _RouteRecorder();
      await pumpLiveShell(tester, size: _phoneSize, recorder: recorder);
      await openAdd(tester);

      final container = containerOfSheet(tester);
      final formBefore = container.read(entryFormViewModelProvider(null)).value;
      final coordinatorBefore = container.read(
        receiptEntryCoordinatorProvider(null),
      );

      for (var i = 0; i < 3; i++) {
        await resize(tester, _openSize);
        await resize(tester, _phoneSize);
      }
      expect(find.text('Add entry'), findsOneWidget);
      expect(recorder.sheets, hasLength(1));
      expect(
        container.read(entryFormViewModelProvider(null)).value,
        same(formBefore),
      );
      expect(
        container.read(receiptEntryCoordinatorProvider(null)),
        same(coordinatorBefore),
      );
      expect(
        container.read(newEntryPresentationProvider),
        NewEntryPresentation.presented,
      );

      container
          .read(entryFormViewModelProvider(null).notifier)
          .requestPickSource();
      await tester.pumpAndSettle();
      expect(find.byType(TwoColumnPickerSheet), findsOneWidget);
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        checkingId,
      );

      await closeAdd(tester);
      expect(
        ProviderScope.containerOf(tester.element(find.text('Money')))
            .read(newEntryPresentationProvider),
        NewEntryPresentation.closed,
      );
    });

    testWidgets('a failed save retains values and error across resize', (
      tester,
    ) async {
      final recorder = _RouteRecorder();
      final ledger = _buildLedger();
      await pumpLiveShell(
        tester,
        size: _phoneSize,
        recorder: recorder,
        ledger: ledger,
      );

      await openAdd(tester);
      await tester.enterText(find.byType(TextField).at(0), '12.50');
      await tester.enterText(find.byType(TextField).at(1), 'New expense');
      await tester.pumpAndSettle();
      await revealRow(tester, 'Account');
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      ledger.deleteAccount(checkingId);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save entry'), findsOneWidget);

      await resize(tester, _openSize);
      expect(find.text('Add entry'), findsOneWidget);
      expect(find.textContaining('Could not save entry'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '12.50',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'New expense',
      );

      await resize(tester, _phoneSize);
      expect(find.textContaining('Could not save entry'), findsOneWidget);

      await closeAdd(tester);
    });
  });
}
