import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

const _phoneSize = Size(400, 800);
const _openSize = Size(960, 720);
const _checkingId = 'a0000000-0000-0000-0000-000000000001';
const _coffeeId = 'c0000000-0000-0000-0000-000000000001';
const _probeLabel = 'overview probe';
const _decodeWait = Duration(milliseconds: 500);
const _halfTransition = Duration(milliseconds: 100);

class _RouteRecorder extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  int removals = 0;
  int sheetPushes = 0;

  List<AppSheetRoute<dynamic>> get sheets =>
      routes.whereType<AppSheetRoute<dynamic>>().toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    if (route is AppSheetRoute) sheetPushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removals++;
    routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removals++;
    routes.remove(route);
  }
}

class _CountingForm extends EntryFormNotifier {
  _CountingForm() : super(null);

  int clears = 0;

  @override
  void clearStep() {
    clears++;
    super.clearStep();
  }
}

class _HookedLedger extends Ledger {
  _HookedLedger({super.state});

  VoidCallback? onNextRead;

  @override
  LedgerState get state {
    final hook = onNextRead;
    onNextRead = null;
    hook?.call();
    return super.state;
  }
}

class _Capture extends ConsumerWidget {
  const _Capture({required this.onBuilt, required this.child});

  final void Function(BuildContext context, WidgetRef ref) onBuilt;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt(context, ref);
    return child;
  }
}

class _Harness {
  _Harness(this.container, this.recorder, this.ledger);

  final ProviderContainer container;
  final _RouteRecorder recorder;
  final _HookedLedger ledger;
  late BuildContext context;
  late WidgetRef ref;
  late Future<void> opened;

  _CountingForm get form =>
      container.read(entryFormViewModelProvider(null).notifier)
          as _CountingForm;

  Future<void> open() => openNewEntry(context: context, ref: ref);

  NewEntryPresentation get presentation =>
      container.read(newEntryPresentationProvider);

  Map<String, Object?> get draft {
    final state = container.read(entryFormViewModelProvider(null)).value!;
    return {
      'amount': state.amountText,
      'name': state.nameText,
      'date': state.date,
      'source': state.sourceId,
      'destination': state.destinationId,
      'category': state.categoryId,
      'recurrence': state.recurrence,
      'endDate': state.endDate,
    };
  }
}

_HookedLedger _buildLedger() {
  final checking = Account(
    id: _checkingId,
    name: 'Checking',
    type: AccountType.checking,
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
  return _HookedLedger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
      categories: {coffee.id: coffee},
    ),
  );
}

final _bodies = <ShellDestination, WidgetBuilder>{
  ShellDestination.overview: (_) => ShellPaneHost(
    pageBuilder: (_, _) => const Center(child: Text(_probeLabel)),
  ),
  ShellDestination.trends: (_) => const Center(child: Text('trends probe')),
};

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

  Future<_Harness> pumpShell(
    WidgetTester tester, {
    Size size = _phoneSize,
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recorder = _RouteRecorder();
    final ledger = _buildLedger();
    final container = ProviderContainer(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellPlatformProvider.overrideWithValue((
          isWeb: false,
          targetPlatform: platform,
        )),
        ledgerProvider.overrideWithValue(ledger),
        scanStripEnabledProvider.overrideWith((ref) async => false),
        entryFormViewModelProvider(null).overrideWith(_CountingForm.new),
      ],
    );
    addTearDown(container.dispose);
    final harness = _Harness(container, recorder, ledger);
    final shell = _Capture(
      onBuilt: (context, ref) {
        harness.context = context;
        harness.ref = ref;
      },
      child: AppShell(bodies: _bodies),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: buildShellAppContent,
          navigatorObservers: [recorder],
          home: shell,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> openAdd(WidgetTester tester, _Harness harness) async {
    harness.opened = harness.open();
    await tester.pumpAndSettle();
  }

  VoidCallback addDismiss(WidgetTester tester) =>
      tester.widget<EntryForm>(find.byType(EntryForm)).onDismiss!;

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  Future<void> saveEntry(WidgetTester tester, _Harness harness) async {
    harness.form.setAmount('12.50');
    harness.form.setName('Lunch');
    harness.form.applyPickedSource(_checkingId);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<void> cancelEntry(WidgetTester tester, _Harness harness) async {
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }

  int pickerCount() => find.byType(TwoColumnPickerSheet).evaluate().length;

  group('Add-only dismissal closes the captured Add route', () {
    const modes = {
      'phone': (_phoneSize, TargetPlatform.iOS),
      'open': (_openSize, TargetPlatform.iOS),
      'desktop': (_openSize, TargetPlatform.macOS),
    };
    final actions = {'cancel': cancelEntry, 'save': saveEntry};

    for (final mode in modes.entries) {
      for (final action in actions.entries) {
        testWidgets('${mode.key} ${action.key} keeps the destination', (
          tester,
        ) async {
          final (size, platform) = mode.value;
          final harness = await pumpShell(
            tester,
            size: size,
            platform: platform,
          );
          harness.container.read(selectedDestinationProvider.notifier).state =
              ShellDestination.trends;
          await tester.pumpAndSettle();
          await openAdd(tester, harness);
          expect(harness.recorder.sheets, hasLength(1));

          await action.value(tester, harness);
          await harness.opened;

          expect(harness.recorder.sheets, isEmpty);
          expect(harness.presentation, NewEntryPresentation.closed);
          expect(
            harness.container.read(selectedDestinationProvider),
            ShellDestination.trends,
          );
        });
      }
    }
  });

  group('dismissal beneath a covering route', () {
    testWidgets('removes only Add and discards the picker result', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      final unrelated = MaterialPageRoute<void>(
        builder: (_) => const Text('unrelated'),
      );
      unawaited(
        Navigator.of(harness.context, rootNavigator: true).push(unrelated),
      );
      await tester.pumpAndSettle();
      await openAdd(tester, harness);
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      final picker = harness.recorder.routes.last;
      expect(pickerCount(), 1);
      final before = harness.draft;

      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      expect(pickerCount(), 1);
      expect(unrelated.isActive, isTrue);
      final navigator = picker.navigator!;
      navigator.removeRoute(picker, const PickerChose(_checkingId));
      await tester.pumpAndSettle();
      expect(harness.draft, before);
      expect(unrelated.isActive, isTrue);
    });

    testWidgets('repeated dismissal and route end retire once', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final dismiss = addDismiss(tester);
      final navigator = harness.recorder.sheets.single.navigator!;
      final removalsBefore = harness.recorder.removals;

      dismiss();
      dismiss();
      dismiss();
      navigator.maybePop();
      await tester.pumpAndSettle();
      dismiss();
      await harness.opened;

      expect(harness.recorder.removals, removalsBefore + 1);
      expect(harness.presentation, NewEntryPresentation.closed);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the open page keeps its left half until the route completes', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: _openSize);
    final overview = find.text(_probeLabel);
    final fullPageX = tester.getCenter(overview).dx;
    await openAdd(tester, harness);
    final halfX = tester.getCenter(overview).dx;
    var settled = false;
    unawaited(harness.opened.then((_) => settled = true));

    harness.recorder.sheets.single.navigator!.pop();
    await tester.pump();
    await tester.pump(_halfTransition);

    expect(harness.presentation, NewEntryPresentation.presented);
    expect(tester.getCenter(overview).dx, halfX);
    expect(settled, isFalse);
    var duplicateSettled = false;
    unawaited(harness.open().then((_) => duplicateSettled = true));
    await tester.pump();
    expect(duplicateSettled, isTrue);
    expect(harness.recorder.sheetPushes, 1);

    await tester.pumpAndSettle();

    expect(harness.presentation, NewEntryPresentation.closed);
    expect(settled, isTrue);
    expect(tester.getCenter(overview).dx, fullPageX);
    expect(halfX, lessThan(fullPageX));
    await openAdd(tester, harness);
    expect(harness.recorder.sheetPushes, 2);
    addDismiss(tester)();
    await tester.pumpAndSettle();
    await harness.opened;
  });

  group('session-owned Step consumption', () {
    testWidgets('a Step emitted before the first mounted frame is picked up '
        'once', (tester) async {
      final harness = await pumpShell(tester);
      harness.opened = harness.open();
      await tester.idle();
      expect(harness.presentation, NewEntryPresentation.presented);
      expect(find.byType(EntryForm), findsNothing);
      final form = harness.form;
      final clearsBefore = form.clears;

      form.requestPickSource();
      expect(pickerCount(), 0);
      await tester.pumpAndSettle();

      expect(pickerCount(), 1);
      expect(form.clears, clearsBefore + 1);
      expect(harness.recorder.sheets, hasLength(1));
      harness.recorder.routes.last.navigator!.pop();
      await tester.pumpAndSettle();
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('a replacement emitted during dispatch keeps its own '
        'consumption', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      final clearsBefore = form.clears;
      harness.ledger.onNextRead = form.requestPickDate;

      form.requestPickSource();
      await tester.pumpAndSettle();

      expect(form.clears, clearsBefore + 2);
      expect(pickerCount(), 1);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('the same request repeated after its clear stays valid', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      final clearsBefore = form.clears;

      for (var i = 0; i < 2; i++) {
        form.requestPickSource();
        await tester.pumpAndSettle();
        expect(pickerCount(), 1);
        harness.recorder.routes.last.navigator!.pop();
        await tester.pumpAndSettle();
      }

      expect(form.clears, clearsBefore + 2);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('resizing keeps the session, routes, draft and a picker', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final addRoute = harness.recorder.sheets.single;
      harness.form.setName('Keep');
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      final picker = harness.recorder.routes.last;
      final draft = harness.draft;
      final clears = harness.form.clears;

      for (final size in [_openSize, _phoneSize, _openSize]) {
        await resize(tester, size);
      }

      expect(harness.recorder.sheets.single, same(addRoute));
      expect(harness.recorder.routes.last, same(picker));
      expect(harness.draft, draft);
      expect(harness.form.clears, clears);
      expect(pickerCount(), 1);
      picker.navigator!.pop();
      await tester.pumpAndSettle();
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('a retired subscription neither pushes nor clears', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
      final clears = form.clears;
      final routes = harness.recorder.routes.length;

      form.requestPickSource();
      await tester.pumpAndSettle();

      expect(form.clears, clears);
      expect(harness.recorder.routes, hasLength(routes));
    });
  });

  group('results arriving after close and reopen are discarded', () {
    final markerDate = DateTime.utc(2026, 3, 4);
    final results =
        <String, (void Function(_CountingForm, Uint8List), Object?)>{
          'source': ((f, _) => f.requestPickSource(), const PickerCleared()),
          'destination': (
            (f, _) => f.requestPickDestination(),
            const PickerChose(_checkingId),
          ),
          'category': (
            (f, _) => f.requestPickCategory(),
            const PickerCleared(),
          ),
          'recurrence': ((f, _) => f.requestPickRecurrence(), null),
          'date': ((f, _) => f.requestPickDate(), DateTime.utc(2026, 1, 2)),
          'end date': (
            (f, _) => f.requestPickEndDate(),
            DateTime.utc(2026, 1, 2),
          ),
          'crop': (
            (f, png) => f.requestDocumentCrop(png),
            Uint8List.fromList([1]),
          ),
        };

    void markFreshDraft(_CountingForm form) {
      form.applyPickedSource(_checkingId);
      form.applyPickedCategory(_coffeeId);
      form.applyPickedRecurrence(RecurrenceFrequency.weekly);
      form.applyPickedDate(markerDate);
      form.setEndDateEnabled(true);
      form.applyPickedEndDate(markerDate);
    }

    for (final entry in results.entries) {
      testWidgets('${entry.key} result', (tester) async {
        final (request, result) = entry.value;
        final harness = await pumpShell(tester);
        await openAdd(tester, harness);
        final png = await tester.runAsync(_solidPng);
        request(harness.form, png!);
        await tester.pump();
        await tester.pump(_halfTransition);
        await tester.runAsync(() => Future<void>.delayed(_decodeWait));
        await tester.pump(_halfTransition);
        final covering = harness.recorder.routes.last;
        addDismiss(tester)();
        await tester.pumpAndSettle();
        await harness.opened;
        await openAdd(tester, harness);
        markFreshDraft(harness.form);
        await tester.pumpAndSettle();
        final fresh = harness.draft;
        var scanEvents = 0;
        harness.container.listen(
          receiptEntryCoordinatorProvider(null),
          (_, _) => scanEvents++,
        );

        covering.navigator!.removeRoute(covering, result);
        await tester.pumpAndSettle();

        expect(harness.draft, fresh);
        expect(scanEvents, 0);
        addDismiss(tester)();
        await tester.pumpAndSettle();
        await harness.opened;
      });
    }
  });
}
